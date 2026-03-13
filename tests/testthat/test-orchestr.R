# Tests for orchestr auto-instrumentation (trace_graph, trace_agent)

# --- trace_graph tests ---

test_that("trace_graph wraps graph$invoke in a trace with correct name", {
  reset_context()

  # Build a simple graph via orchestr's GraphBuilder
  skip_if_not_installed("orchestr")

  gb <- orchestr::graph_builder()
  gb$add_node("double", function(state, config) list(x = state$x * 2))
  gb$add_edge("double", orchestr::END)
  gb$set_entry_point("double")
  graph <- gb$compile()

  captured <- new.env(parent = emptyenv())
  captured$trace <- NULL
  capture_exporter <- exporter(function(trace_list) {
    captured$trace <- trace_list
  })

  result <- trace_graph(graph, list(x = 5), exporter = capture_exporter)

  # Should return the graph result

  expect_equal(result$x, 10)

  # Trace should exist with correct name
  tr <- captured$trace
  expect_true(!is.null(tr))
  expect_true(grepl("graph:", tr$name))

  reset_context()
})

test_that("trace_graph creates child spans for each node execution", {
  reset_context()
  skip_if_not_installed("orchestr")

  gb <- orchestr::graph_builder()
  gb$add_node("step1", function(state, config) list(x = state$x + 1))
  gb$add_node("step2", function(state, config) list(x = state$x * 2))
  gb$add_edge("step1", "step2")
  gb$add_edge("step2", orchestr::END)
  gb$set_entry_point("step1")
  graph <- gb$compile()

  captured <- new.env(parent = emptyenv())
  captured$trace <- NULL
  capture_exporter <- exporter(function(trace_list) {
    captured$trace <- trace_list
  })

  result <- trace_graph(graph, list(x = 3), exporter = capture_exporter)
  expect_equal(result$x, 8) # (3 + 1) * 2

  tr <- captured$trace
  expect_true(length(tr$spans) >= 2)

  # Check node span names
  span_names <- vapply(tr$spans, `[[`, character(1), "name")
  expect_true("node:step1" %in% span_names)
  expect_true("node:step2" %in% span_names)

  reset_context()
})

test_that("trace_graph propagates errors from graph execution", {
  reset_context()
  skip_if_not_installed("orchestr")

  gb <- orchestr::graph_builder()
  gb$add_node("fail", function(state, config) stop("graph boom"))
  gb$add_edge("fail", orchestr::END)
  gb$set_entry_point("fail")
  graph <- gb$compile()

  expect_error(
    trace_graph(graph, list()),
    "graph boom"
  )

  reset_context()
})

test_that("trace_graph sets error status on trace when graph errors", {
  reset_context()
  skip_if_not_installed("orchestr")

  gb <- orchestr::graph_builder()
  gb$add_node("fail", function(state, config) stop("graph error"))
  gb$add_edge("fail", orchestr::END)
  gb$set_entry_point("fail")
  graph <- gb$compile()

  captured <- new.env(parent = emptyenv())
  captured$trace <- NULL
  capture_exporter <- exporter(function(trace_list) {
    captured$trace <- trace_list
  })

  expect_error(
    trace_graph(graph, list(), exporter = capture_exporter),
    "graph error"
  )

  tr <- captured$trace
  expect_true(!is.null(tr))
  expect_equal(tr$status, "error")

  reset_context()
})

test_that("trace_graph works without orchestr installed (graceful skip)", {
  reset_context()

  # If orchestr IS installed, we can't truly test the "not installed" path

  # in a meaningful way. Instead, verify that trace_graph checks for orchestr
  # by passing a mock object that lacks the AgentGraph class.
  mock_graph <- list(
    invoke = function(state, ...) list(x = 42)
  )

  expect_error(
    trace_graph(mock_graph, list(x = 1)),
    "AgentGraph"
  )

  reset_context()
})

# --- trace_agent tests ---

test_that("trace_agent wraps agent$invoke in a trace with correct name", {
  reset_context()
  skip_if_not_installed("orchestr")

  # Create a mock chat object that satisfies the Agent constructor
  mock_chat <- list(
    chat = function(prompt, ...) paste("Reply:", prompt),
    get_turns = function() list(),
    set_turns = function(turns) invisible(NULL),
    clone = function(deep = FALSE) mock_chat
  )

  ag <- orchestr::agent("test-agent", mock_chat)

  captured <- new.env(parent = emptyenv())
  captured$trace <- NULL
  capture_exporter <- exporter(function(trace_list) {
    captured$trace <- trace_list
  })

  result <- trace_agent(ag, "hello", exporter = capture_exporter)

  # Should return the agent response
  expect_equal(result, "Reply: hello")

  # Trace should exist with correct name
  tr <- captured$trace
  expect_true(!is.null(tr))
  expect_true(grepl("agent:test-agent", tr$name))

  reset_context()
})

test_that("trace_agent creates a span for the invocation", {
  reset_context()
  skip_if_not_installed("orchestr")

  mock_chat <- list(
    chat = function(prompt, ...) "response",
    get_turns = function() list(),
    set_turns = function(turns) invisible(NULL),
    clone = function(deep = FALSE) mock_chat
  )

  ag <- orchestr::agent("my-agent", mock_chat)

  captured <- new.env(parent = emptyenv())
  captured$trace <- NULL
  capture_exporter <- exporter(function(trace_list) {
    captured$trace <- trace_list
  })

  trace_agent(ag, "test prompt", exporter = capture_exporter)

  tr <- captured$trace
  expect_true(length(tr$spans) >= 1)

  # Check that a span with type "custom" exists for the invocation
  span_types <- vapply(tr$spans, `[[`, character(1), "type")
  expect_true("custom" %in% span_types)

  reset_context()
})

test_that("trace_agent propagates errors from agent invocation", {
  reset_context()
  skip_if_not_installed("orchestr")

  mock_chat <- list(
    chat = function(prompt, ...) stop("agent boom"),
    get_turns = function() list(),
    set_turns = function(turns) invisible(NULL),
    clone = function(deep = FALSE) mock_chat
  )

  ag <- orchestr::agent("fail-agent", mock_chat)

  expect_error(
    trace_agent(ag, "test"),
    "agent boom"
  )

  reset_context()
})

test_that("trace_agent rejects non-Agent objects", {
  reset_context()

  mock_agent <- list(
    invoke = function(prompt, ...) "fake"
  )

  expect_error(
    trace_agent(mock_agent, "test"),
    "Agent"
  )

  reset_context()
})

test_that("trace_agent auto-extracts model and tokens from chat", {
  reset_context()
  skip_if_not_installed("orchestr")
  skip_if_not_installed("ellmer")

  env <- new.env(parent = emptyenv())
  env$call_count <- 0L

  mock_chat <- list(
    chat = function(prompt, ...) paste("Echo:", prompt),
    get_turns = function() list(),
    set_turns = function(turns) invisible(NULL),
    clone = function(deep = FALSE) mock_chat,
    get_model = function() "claude-sonnet-4-20250514",
    get_tokens = function() {
      if (env$call_count == 0L) {
        env$call_count <- env$call_count + 1L
        data.frame(input = integer(0), output = integer(0))
      } else {
        data.frame(input = 200L, output = 100L)
      }
    }
  )

  ag <- orchestr::agent("smart-agent", mock_chat)

  captured <- new.env(parent = emptyenv())
  captured$trace <- NULL
  capture_exporter <- exporter(function(trace_list) {
    captured$trace <- trace_list
  })

  result <- trace_agent(ag, "hello", exporter = capture_exporter)
  expect_equal(result, "Echo: hello")

  tr <- captured$trace
  # Should have at least one span with token data
  has_tokens <- FALSE
  for (s in tr$spans) {
    if (s$input_tokens > 0 || s$output_tokens > 0) {
      has_tokens <- TRUE
      break
    }
  }
  expect_true(has_tokens)

  reset_context()
})
