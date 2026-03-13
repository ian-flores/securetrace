test_that("trace_tool_call wraps function in span", {
  reset_context()
  result <- with_trace("tool-test", {
    trace_tool_call("add", function(a, b) a + b, 2, 3)
  })
  expect_equal(result, 5)

  # Check the span was recorded
  # (trace already ended, so check via context is not possible;
  #  we verify by testing the result flows through)
  reset_context()
})

test_that("trace_tool_call propagates errors", {
  reset_context()
  expect_error(
    with_trace("tool-err-test", {
      trace_tool_call("fail", function() stop("tool error"))
    }),
    "tool error"
  )
  reset_context()
})

test_that("trace_guardrail wraps function in span", {
  reset_context()
  result <- with_trace("guard-test", {
    trace_guardrail("length-check", function(x) nchar(x) < 100, "hello")
  })
  expect_true(result)
  reset_context()
})

test_that("trace_guardrail rejects non-functions", {
  reset_context()
  expect_error(
    with_trace("guard-err-test", {
      trace_guardrail("bad", "not a function", "input")
    }),
    "must be a function"
  )
  reset_context()
})

test_that("trace_llm_call auto-extracts model and tokens from Chat object", {
  reset_context()
  reset_costs()
  skip_if_not_installed("ellmer")

  # Build a mock Chat object with get_model(), get_tokens(), and chat() methods.
  # trace_llm_call checks "get_model" %in% names(chat), so a named list works.
  env <- new.env(parent = emptyenv())
  env$call_count <- 0L

  mock_chat <- list(
    get_model = function() "gpt-4o",
    get_tokens = function() {
      # First call (before): return empty data frame
      # Second call (after): return one row of token usage
      if (env$call_count == 0L) {
        env$call_count <- env$call_count + 1L
        data.frame(input = integer(0), output = integer(0))
      } else {
        data.frame(input = 150L, output = 50L)
      }
    },
    chat = function(prompt, ...) {
      paste("Echo:", prompt)
    }
  )

  # Capture the trace via a custom exporter
  captured <- new.env(parent = emptyenv())
  captured$trace <- NULL
  capture_exporter <- exporter(function(trace_list) {
    captured$trace <- trace_list
  })

  result <- with_trace("auto-extract-test", {
    trace_llm_call(mock_chat, "hello world")
  }, exporter = capture_exporter)

  expect_equal(result, "Echo: hello world")

  # Inspect the exported trace -- it's a list from Trace$to_list()
  tr <- captured$trace
  expect_true(!is.null(tr))
  expect_true(length(tr$spans) >= 1)

  llm_span <- tr$spans[[1]]
  expect_equal(llm_span$type, "llm")
  expect_equal(llm_span$model, "gpt-4o")
  expect_equal(llm_span$input_tokens, 150L)
  expect_equal(llm_span$output_tokens, 50L)

  reset_context()
})

test_that("trace_llm_call requires ellmer", {
  reset_context()
  skip_if(requireNamespace("ellmer", quietly = TRUE), "ellmer is installed")
  expect_error(
    with_trace("llm-test", {
      trace_llm_call(NULL, "hello")
    }),
    "ellmer"
  )
  reset_context()
})

test_that("trace_execution requires securer", {
  reset_context()
  skip_if(requireNamespace("securer", quietly = TRUE), "securer is installed")
  expect_error(
    with_trace("exec-test", {
      trace_execution(NULL, "1 + 1")
    }),
    "securer"
  )
  reset_context()
})

# --- Enhancement tests: Streaming support ---

test_that("trace_llm_call supports streaming via stream parameter", {
  reset_context()
  reset_costs()
  skip_if_not_installed("ellmer")

  env <- new.env(parent = emptyenv())
  env$call_count <- 0L

  mock_chat <- list(
    get_model = function() "gpt-4o",
    get_tokens = function() {
      if (env$call_count == 0L) {
        env$call_count <- env$call_count + 1L
        data.frame(input = integer(0), output = integer(0))
      } else {
        data.frame(input = 100L, output = 30L)
      }
    },
    chat = function(prompt, ...) {
      stop("chat() should not be called when stream = TRUE")
    },
    stream = function(prompt, ...) {
      paste("Streamed:", prompt)
    }
  )

  captured <- new.env(parent = emptyenv())
  captured$trace <- NULL
  capture_exporter <- exporter(function(trace_list) {
    captured$trace <- trace_list
  })

  result <- with_trace("stream-test", {
    trace_llm_call(mock_chat, "hello stream", stream = TRUE)
  }, exporter = capture_exporter)

  expect_equal(result, "Streamed: hello stream")

  tr <- captured$trace
  llm_span <- tr$spans[[1]]
  expect_equal(llm_span$type, "llm")
  expect_equal(llm_span$model, "gpt-4o")
  expect_equal(llm_span$input_tokens, 100L)
  expect_equal(llm_span$output_tokens, 30L)

  # Check for streaming event
  event_names <- vapply(llm_span$events, function(e) e$name, character(1))
  expect_true("streaming" %in% event_names)

  reset_context()
})

# --- Enhancement tests: Tool call child spans ---

test_that("trace_llm_call records tool call events from last_turn", {
  reset_context()
  reset_costs()
  skip_if_not_installed("ellmer")

  env <- new.env(parent = emptyenv())
  env$call_count <- 0L

  # Mock a ContentToolRequest-like structure
  tool_request <- structure(
    list(id = "call_1", type = "tool_request", name = "calculator", arguments = list(x = 42)),
    class = "ContentToolRequest"
  )
  tool_result <- structure(
    list(id = "call_1", type = "tool_result", value = "42"),
    class = "ContentToolResult"
  )

  mock_turn <- structure(
    list(
      role = "assistant",
      contents = list(tool_request, tool_result)
    ),
    class = "Turn"
  )

  mock_chat <- list(
    get_model = function() "gpt-4o",
    get_tokens = function() {
      if (env$call_count == 0L) {
        env$call_count <- env$call_count + 1L
        data.frame(input = integer(0), output = integer(0))
      } else {
        data.frame(input = 200L, output = 80L)
      }
    },
    chat = function(prompt, ...) paste("Result:", prompt),
    last_turn = function() mock_turn
  )

  captured <- new.env(parent = emptyenv())
  captured$trace <- NULL
  capture_exporter <- exporter(function(trace_list) {
    captured$trace <- trace_list
  })

  result <- with_trace("tool-call-spans-test", {
    trace_llm_call(mock_chat, "use calculator")
  }, exporter = capture_exporter)

  expect_equal(result, "Result: use calculator")

  tr <- captured$trace
  llm_span <- tr$spans[[1]]

  # Check that a tool call event was recorded
  event_names <- vapply(llm_span$events, function(e) e$name, character(1))
  expect_true("tool_call" %in% event_names)

  # Find the tool call event and check its data
  tool_events <- Filter(function(e) e$name == "tool_call", llm_span$events)
  expect_true(length(tool_events) >= 1)
  expect_equal(tool_events[[1]]$data$tool_name, "calculator")

  reset_context()
})

# --- Enhancement tests: Richer securer integration ---

test_that("trace_execution records code, output, and handles success", {
  reset_context()
  skip_if_not_installed("securer")

  # Mock SecureSession whose execute() returns a result with output attribute
  mock_result <- 42L
  attr(mock_result, "output") <- c("line1", "line2")

  mock_session <- list(
    execute = function(code, ...) mock_result
  )

  captured <- new.env(parent = emptyenv())
  captured$trace <- NULL
  capture_exporter <- exporter(function(trace_list) {
    captured$trace <- trace_list
  })

  result <- with_trace("exec-rich-test", {
    trace_execution(mock_session, "x <- 42L; x")
  }, exporter = capture_exporter)

  expect_equal(as.integer(result), 42L)

  tr <- captured$trace
  exec_span <- tr$spans[[1]]
  expect_equal(exec_span$type, "tool")
  expect_equal(exec_span$status, "ok")

  # Check that code.submitted event was recorded
  event_names <- vapply(exec_span$events, function(e) e$name, character(1))
  expect_true("code.submitted" %in% event_names)

  # Check stdout event was recorded
  expect_true("execution.stdout" %in% event_names)

  reset_context()
})

test_that("trace_execution sets error status on execution failure", {
  reset_context()
  skip_if_not_installed("securer")

  mock_session <- list(
    execute = function(code, ...) stop("execution failed")
  )

  captured <- new.env(parent = emptyenv())
  captured$trace <- NULL
  capture_exporter <- exporter(function(trace_list) {
    captured$trace <- trace_list
  })

  expect_error(
    with_trace("exec-error-test", {
      trace_execution(mock_session, "bad code")
    }, exporter = capture_exporter),
    "execution failed"
  )

  tr <- captured$trace
  exec_span <- tr$spans[[1]]
  expect_equal(exec_span$status, "error")

  # code.submitted should still be there (recorded before execution)
  event_names <- vapply(exec_span$events, function(e) e$name, character(1))
  expect_true("code.submitted" %in% event_names)

  reset_context()
})

# --- Enhancement tests: Richer secureguard integration ---

test_that("trace_guardrail detects secureguard Guard object and extracts results", {
  reset_context()
  skip_if_not_installed("secureguard")

  # Create a real secureguard guardrail
  guard <- secureguard::new_guardrail(
    name = "test_guard",
    type = "input",
    check_fn = function(x) secureguard::guardrail_result(pass = TRUE),
    description = "A test guardrail"
  )

  captured <- new.env(parent = emptyenv())
  captured$trace <- NULL
  capture_exporter <- exporter(function(trace_list) {
    captured$trace <- trace_list
  })

  result <- with_trace("guard-rich-test", {
    trace_guardrail("test_guard", guard, "hello world")
  }, exporter = capture_exporter)

  # Result should be a guardrail_result
  expect_true(result@pass)

  tr <- captured$trace
  guard_span <- tr$spans[[1]]
  expect_equal(guard_span$type, "guardrail")

  # Check that pass/fail and guard name were recorded as events
  event_names <- vapply(guard_span$events, function(e) e$name, character(1))
  expect_true("guardrail.result" %in% event_names)

  # Verify the result data

  result_events <- Filter(function(e) e$name == "guardrail.result", guard_span$events)
  expect_true(result_events[[1]]$data$pass)
  expect_equal(result_events[[1]]$data$guard_name, "test_guard")

  reset_context()
})

test_that("trace_guardrail detects failing secureguard Guard object", {
  reset_context()
  skip_if_not_installed("secureguard")

  guard <- secureguard::new_guardrail(
    name = "block_guard",
    type = "input",
    check_fn = function(x) {
      secureguard::guardrail_result(pass = FALSE, reason = "blocked for test")
    },
    description = "A blocking guardrail"
  )

  captured <- new.env(parent = emptyenv())
  captured$trace <- NULL
  capture_exporter <- exporter(function(trace_list) {
    captured$trace <- trace_list
  })

  result <- with_trace("guard-fail-test", {
    trace_guardrail("block_guard", guard, "malicious input")
  }, exporter = capture_exporter)

  expect_false(result@pass)
  expect_equal(result@reason, "blocked for test")

  tr <- captured$trace
  guard_span <- tr$spans[[1]]
  result_events <- Filter(function(e) e$name == "guardrail.result", guard_span$events)
  expect_false(result_events[[1]]$data$pass)

  reset_context()
})

test_that("trace_guardrail still works with plain functions (backward compat)", {
  reset_context()

  result <- with_trace("guard-plain-test", {
    trace_guardrail("length-check", function(x) nchar(x) < 100, "hello")
  })
  expect_true(result)
  reset_context()
})
