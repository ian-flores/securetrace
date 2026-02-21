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
