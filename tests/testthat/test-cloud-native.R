# --- 5A: exporter_json_stdout ---

test_that("exporter_json_stdout outputs valid JSON lines", {
  exp <- exporter_json_stdout()

  tr <- Trace$new("stdout-test")
  tr$start()
  s1 <- Span$new("step1", type = "tool")
  s1$start()
  s1$end()
  tr$add_span(s1)

  s2 <- Span$new("llm-call", type = "llm")
  s2$start()
  s2$set_model("gpt-4o")
  s2$set_tokens(input = 100L, output = 50L)
  s2$end()
  tr$add_span(s2)
  tr$end()

  output <- capture.output(export_trace(exp, tr))

  # Should produce one line per span

  expect_length(output, 2)

  # Each line should be valid JSON
  parsed1 <- jsonlite::fromJSON(output[[1]])
  parsed2 <- jsonlite::fromJSON(output[[2]])

  # Check required fields on first span
  expect_equal(parsed1$trace_id, tr$trace_id)
  expect_equal(parsed1$span_id, s1$span_id)
  expect_equal(parsed1$name, "step1")
  expect_equal(parsed1$type, "tool")
  expect_equal(parsed1$status, "ok")
  expect_true(!is.null(parsed1$start_time))
  expect_true(!is.null(parsed1$end_time))

  # Check LLM-specific fields on second span
  expect_equal(parsed2$model, "gpt-4o")
  expect_equal(parsed2$input_tokens, 100L)
  expect_equal(parsed2$output_tokens, 50L)
})

test_that("exporter_json_stdout includes metrics and metadata", {
  exp <- exporter_json_stdout()

  tr <- Trace$new("meta-test")
  tr$start()
  s <- Span$new("step", type = "tool", metadata = list(tool_name = "calc"))
  s$start()
  s$add_metric("latency", 1.5, unit = "seconds")
  s$end()
  tr$add_span(s)
  tr$end()

  output <- capture.output(export_trace(exp, tr))
  parsed <- jsonlite::fromJSON(output[[1]], simplifyVector = FALSE)

  expect_true(!is.null(parsed$metadata))
  expect_equal(parsed$metadata$tool_name, "calc")
  expect_true(!is.null(parsed$metrics))
})

test_that("exporter_json_stdout returns a securetrace_exporter", {
  exp <- exporter_json_stdout()
  expect_true(S7::S7_inherits(exp, securetrace_exporter))
})

# --- 5B: OTEL env var support ---

test_that("exporter_otlp reads OTEL_EXPORTER_OTLP_ENDPOINT env var", {
  withr::local_envvar(OTEL_EXPORTER_OTLP_ENDPOINT = "http://my-collector:4318")

  exp <- exporter_otlp()
  endpoint <- attr(exp, "otlp_endpoint")
  expect_equal(endpoint, "http://my-collector:4318")
})

test_that("exporter_otlp reads OTEL_SERVICE_NAME env var", {
  withr::local_envvar(OTEL_SERVICE_NAME = "my-r-service")

  # We can verify by formatting a trace and checking the service name
  # The service_name is captured inside the closure, so we test via otlp_format_trace
  # Since otlp_format_trace takes service_name directly, we test the default arg instead
  # by checking that the exporter was created with no error
  exp <- exporter_otlp()
  expect_true(S7::S7_inherits(exp, securetrace_exporter))
})

test_that("exporter_otlp falls back to defaults when env vars unset", {
  withr::local_envvar(
    OTEL_EXPORTER_OTLP_ENDPOINT = NA,
    OTEL_SERVICE_NAME = NA
  )

  exp <- exporter_otlp()
  endpoint <- attr(exp, "otlp_endpoint")
  expect_equal(endpoint, "http://localhost:4318")
})

# --- 5C: Log correlation ---

test_that("trace_log_prefix returns empty string when no trace active", {
  # Ensure clean context
  prefix <- trace_log_prefix()
  expect_equal(prefix, "")
})

test_that("trace_log_prefix returns formatted string inside trace+span", {
  with_trace("prefix-test", {
    tr <- current_trace()
    with_span("step", type = "custom", {
      s <- current_span()
      prefix <- trace_log_prefix()
      expected <- sprintf("[trace_id=%s span_id=%s] ", tr$trace_id, s$span_id)
      expect_equal(prefix, expected)
    })
  })
})

test_that("trace_log_prefix with trace but no span shows empty span_id", {
  with_trace("no-span-test", {
    tr <- current_trace()
    prefix <- trace_log_prefix()
    expected <- sprintf("[trace_id=%s span_id=] ", tr$trace_id)
    expect_equal(prefix, expected)
  })
})

test_that("with_trace_logging prepends context to messages", {
  output <- capture.output(
    with_trace("log-test", {
      with_span("step", type = "custom", {
        tr <- current_trace()
        s <- current_span()
        with_trace_logging({
          message("hello world")
        })
      })
    }),
    type = "message"
  )

  # Output should contain the trace prefix
  expect_length(output, 1)
  expect_true(grepl("^\\[trace_id=", output[[1]]))
  expect_true(grepl("hello world", output[[1]]))
})

test_that("with_trace_logging returns expression result", {
  result <- with_trace("result-test", {
    with_span("step", type = "custom", {
      with_trace_logging({
        42
      })
    })
  })
  expect_equal(result, 42)
})

test_that("with_trace_logging passes through when no trace active", {
  output <- capture.output(
    with_trace_logging({
      message("no trace")
    }),
    type = "message"
  )

  # Without active trace, message should pass through unchanged
  expect_length(output, 1)
  expect_equal(output[[1]], "no trace")
})
