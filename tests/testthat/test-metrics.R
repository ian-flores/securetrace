test_that("record_tokens warns with no active span", {
  reset_context()
  expect_warning(record_tokens(100, 50), "No active span")
})

test_that("record_latency warns with no active span", {
  reset_context()
  expect_warning(record_latency(1.5), "No active span")
})

test_that("record_metric warns with no active span", {
  reset_context()
  expect_warning(record_metric("foo", 42), "No active span")
})

test_that("record_tokens works within a span context", {
  reset_context()
  result <- with_trace("metrics-test", {
    with_span("llm", type = "llm", {
      record_tokens(500, 200, model = "gpt-4o")
      span <- current_span()
      expect_equal(span$input_tokens, 500L)
      expect_equal(span$output_tokens, 200L)
      expect_equal(span$model, "gpt-4o")
      "done"
    })
  })
  expect_equal(result, "done")
  reset_context()
})

test_that("record_latency works within a span context", {
  reset_context()
  with_trace("latency-test", {
    with_span("op", type = "custom", {
      record_latency(2.5)
      span <- current_span()
      lst <- span$to_list()
      expect_length(lst$metrics, 1)
      expect_equal(lst$metrics[[1]]$name, "latency")
    })
  })
  reset_context()
})

test_that("record_metric works within a span context", {
  reset_context()
  with_trace("custom-metric-test", {
    with_span("op", type = "custom", {
      record_metric("accuracy", 0.95, unit = "ratio")
      span <- current_span()
      lst <- span$to_list()
      expect_length(lst$metrics, 1)
      expect_equal(lst$metrics[[1]]$value, 0.95)
    })
  })
  reset_context()
})
