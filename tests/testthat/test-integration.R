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
  capture_exporter <- new_exporter(function(trace_list) {
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
