# -- Helper to create a test trace with known values --------------------------

make_test_trace <- function(name = "test-trace",
                            spans = list(),
                            status = "completed") {
  tr <- Trace$new(name)
  tr$start()
  for (s in spans) {
    tr$add_span(s)
  }
  tr$end()
  if (status == "error") tr$status <- "error"
  tr
}

make_span <- function(name = "span1",
                      type = "llm",
                      model = NULL,
                      input_tokens = 0L,
                      output_tokens = 0L,
                      duration = 0.5,
                      status = "ok") {
  s <- Span$new(name, type = type)
  s$start()
  if (!is.null(model)) s$set_model(model)
  if (input_tokens > 0L || output_tokens > 0L) {
    s$set_tokens(input = input_tokens, output = output_tokens)
  }
  # Force a known duration by manipulating private times
  start_time <- as.POSIXct("2025-01-01 00:00:00", tz = "UTC")
  end_time <- start_time + duration
  s$.__enclos_env__$private$.start_time <- start_time
  s$.__enclos_env__$private$.end_time <- end_time
  if (status == "error") {
    s$set_error("test error")
  } else {
    s$status <- status
  }
  s
}

# -- prometheus_registry() tests -----------------------------------------------

test_that("prometheus_registry creates proper structure", {
  reg <- prometheus_registry()
  expect_s3_class(reg, "securetrace_prometheus_registry")
  expect_true(is.environment(reg))
  expect_type(reg$counters, "list")
  expect_type(reg$histograms, "list")
  expect_length(reg$counters, 0)
  expect_length(reg$histograms, 0)
})

# -- prometheus_metrics() tests ------------------------------------------------

test_that("prometheus_metrics extracts span counts by type and status", {
  s1 <- make_span("s1", type = "llm", status = "ok")
  s2 <- make_span("s2", type = "tool", status = "ok")
  s3 <- make_span("s3", type = "llm", status = "error")
  tr <- make_test_trace(spans = list(s1, s2, s3))

  reg <- prometheus_metrics(tr)

  spans <- reg$counters[["securetrace_spans_total"]]
  expect_equal(spans[['type="llm",status="ok"']], 1)
  expect_equal(spans[['type="tool",status="ok"']], 1)
  expect_equal(spans[['type="llm",status="error"']], 1)
})

test_that("prometheus_metrics extracts token counts by direction and model", {
  s1 <- make_span("s1", type = "llm", model = "gpt-4o",
                   input_tokens = 100L, output_tokens = 50L)
  s2 <- make_span("s2", type = "llm", model = "gpt-4o",
                   input_tokens = 200L, output_tokens = 100L)
  tr <- make_test_trace(spans = list(s1, s2))

  reg <- prometheus_metrics(tr)

  tokens <- reg$counters[["securetrace_tokens_total"]]
  expect_equal(tokens[['direction="input",model="gpt-4o"']], 300)
  expect_equal(tokens[['direction="output",model="gpt-4o"']], 150)
})

test_that("prometheus_metrics calculates durations", {
  s1 <- make_span("s1", type = "llm", duration = 2.5)
  s2 <- make_span("s2", type = "llm", duration = 0.03)
  tr <- make_test_trace(spans = list(s1, s2))

  reg <- prometheus_metrics(tr)

  hist <- reg$histograms[["securetrace_span_duration_seconds"]]
  entry <- hist[['type="llm"']]
  expect_equal(entry$count, 2L)
  expect_equal(entry$sum, 2.53)
})

test_that("prometheus_metrics counts traces", {
  tr1 <- make_test_trace("t1", status = "completed")
  tr2 <- make_test_trace("t2", status = "error")

  reg <- prometheus_registry()
  prometheus_metrics(tr1, reg)
  prometheus_metrics(tr2, reg)

  traces <- reg$counters[["securetrace_traces_total"]]
  expect_equal(traces[['status="completed"']], 1)
  expect_equal(traces[['status="error"']], 1)
})

test_that("prometheus_metrics creates registry if NULL", {
  tr <- make_test_trace()
  reg <- prometheus_metrics(tr)
  expect_s3_class(reg, "securetrace_prometheus_registry")
})

test_that("counter values accumulate across multiple calls", {
  s1 <- make_span("s1", type = "llm", model = "gpt-4o",
                   input_tokens = 100L, output_tokens = 50L)
  tr1 <- make_test_trace(spans = list(s1))

  s2 <- make_span("s2", type = "llm", model = "gpt-4o",
                   input_tokens = 200L, output_tokens = 100L)
  tr2 <- make_test_trace(spans = list(s2))

  reg <- prometheus_registry()
  prometheus_metrics(tr1, reg)
  prometheus_metrics(tr2, reg)

  tokens <- reg$counters[["securetrace_tokens_total"]]
  expect_equal(tokens[['direction="input",model="gpt-4o"']], 300)
  expect_equal(tokens[['direction="output",model="gpt-4o"']], 150)

  traces <- reg$counters[["securetrace_traces_total"]]
  expect_equal(traces[['status="completed"']], 2)
})

test_that("prometheus_metrics extracts cost by model", {
  s1 <- make_span("s1", type = "llm", model = "gpt-4o",
                   input_tokens = 1000L, output_tokens = 500L)
  tr <- make_test_trace(spans = list(s1))

  reg <- prometheus_metrics(tr)
  cost <- reg$counters[["securetrace_cost_total"]]
  expected_cost <- calculate_cost("gpt-4o", 1000L, 500L)
  expect_equal(cost[['model="gpt-4o"']], expected_cost)
})

# -- format_prometheus() tests -------------------------------------------------

test_that("format_prometheus produces valid exposition format", {
  s1 <- make_span("s1", type = "llm", model = "gpt-4o",
                   input_tokens = 100L, output_tokens = 50L, duration = 1.5)
  tr <- make_test_trace(spans = list(s1))

  reg <- prometheus_metrics(tr)
  output <- format_prometheus(reg)

  expect_type(output, "character")
  expect_match(output, "# HELP securetrace_spans_total")
  expect_match(output, "# TYPE securetrace_spans_total counter")
  expect_match(output, 'securetrace_spans_total\\{type="llm",status="ok"\\} 1')
})

test_that("format_prometheus includes HELP and TYPE lines", {
  s1 <- make_span("s1", type = "llm", duration = 0.5)
  tr <- make_test_trace(spans = list(s1))

  reg <- prometheus_metrics(tr)
  output <- format_prometheus(reg)

  # Check all metric families have HELP and TYPE
  expect_match(output, "# HELP securetrace_spans_total")
  expect_match(output, "# TYPE securetrace_spans_total counter")
  expect_match(output, "# HELP securetrace_traces_total")
  expect_match(output, "# TYPE securetrace_traces_total counter")
  expect_match(output, "# HELP securetrace_span_duration_seconds")
  expect_match(output, "# TYPE securetrace_span_duration_seconds histogram")
})

test_that("histogram buckets are correctly populated", {
  # Duration of 0.03 should go into 0.05, 0.1, 0.5, ..., +Inf buckets
  s1 <- make_span("s1", type = "tool", duration = 0.03)
  tr <- make_test_trace(spans = list(s1))

  reg <- prometheus_metrics(tr)
  output <- format_prometheus(reg)

  # 0.03 is > 0.01 so le="0.01" should be 0
  expect_match(output, 'securetrace_span_duration_seconds_bucket\\{type="tool",le="0.01"\\} 0')
  # 0.03 <= 0.05 so le="0.05" should be 1
  expect_match(output, 'securetrace_span_duration_seconds_bucket\\{type="tool",le="0.05"\\} 1')
  # 0.03 <= 0.1 so le="0.1" should be 1
  expect_match(output, 'securetrace_span_duration_seconds_bucket\\{type="tool",le="0.1"\\} 1')
  # +Inf is always total count
  expect_match(output, 'securetrace_span_duration_seconds_bucket\\{type="tool",le="\\+Inf"\\} 1')
  # sum (may have floating point imprecision) and count
  expect_match(output, 'securetrace_span_duration_seconds_sum\\{type="tool"\\} 0\\.0[23]')
  expect_match(output, 'securetrace_span_duration_seconds_count\\{type="tool"\\} 1')
})

test_that("empty registry produces valid (empty) output", {
  reg <- prometheus_registry()
  output <- format_prometheus(reg)
  expect_equal(output, "")
})

# -- prometheus_exporter() tests -----------------------------------------------

test_that("prometheus_exporter returns correct S7 exporter class", {
  exp <- prometheus_exporter()
  expect_true(S7::S7_inherits(exp, securetrace_exporter))
})

test_that("prometheus_exporter feeds registry on export", {
  reg <- prometheus_registry()
  exp <- prometheus_exporter(registry = reg)

  tr <- Trace$new("exporter-test")
  tr$start()
  s <- Span$new("step", type = "llm")
  s$start()
  s$set_tokens(input = 100L, output = 50L)
  s$set_model("gpt-4o")
  s$end()
  tr$add_span(s)
  tr$end()

  export_trace(exp, tr)

  expect_true(length(reg$counters) > 0)
  spans <- reg$counters[["securetrace_spans_total"]]
  expect_equal(spans[['type="llm",status="ok"']], 1)
})

# -- Multiple span types -------------------------------------------------------

test_that("multiple span types are tracked separately", {
  s1 <- make_span("llm1", type = "llm", duration = 1.0)
  s2 <- make_span("tool1", type = "tool", duration = 0.5)
  s3 <- make_span("guard1", type = "guardrail", duration = 0.2)
  tr <- make_test_trace(spans = list(s1, s2, s3))

  reg <- prometheus_metrics(tr)
  output <- format_prometheus(reg)

  expect_match(output, 'type="llm",status="ok"')
  expect_match(output, 'type="tool",status="ok"')
  expect_match(output, 'type="guardrail",status="ok"')

  # Histogram entries for each type
  hist <- reg$histograms[["securetrace_span_duration_seconds"]]
  expect_equal(hist[['type="llm"']]$count, 1L)
  expect_equal(hist[['type="tool"']]$count, 1L)
  expect_equal(hist[['type="guardrail"']]$count, 1L)
})

# -- Token direction tracking ---------------------------------------------------

test_that("tokens with different models tracked separately", {
  s1 <- make_span("s1", type = "llm", model = "gpt-4o",
                   input_tokens = 100L, output_tokens = 50L)
  s2 <- make_span("s2", type = "llm", model = "gpt-4o-mini",
                   input_tokens = 200L, output_tokens = 100L)
  tr <- make_test_trace(spans = list(s1, s2))

  reg <- prometheus_metrics(tr)
  tokens <- reg$counters[["securetrace_tokens_total"]]

  expect_equal(tokens[['direction="input",model="gpt-4o"']], 100)
  expect_equal(tokens[['direction="input",model="gpt-4o-mini"']], 200)
  expect_equal(tokens[['direction="output",model="gpt-4o"']], 50)
  expect_equal(tokens[['direction="output",model="gpt-4o-mini"']], 100)
})

# -- serve_prometheus() HTTP test -----------------------------------------------

test_that("serve_prometheus serves /metrics via HTTP", {
  skip_if_not_installed("httpuv")

  reg <- prometheus_registry()

  # Record some data
  s1 <- make_span("s1", type = "llm", model = "gpt-4o",
                   input_tokens = 100L, output_tokens = 50L, duration = 1.5)
  tr <- make_test_trace(spans = list(s1))
  prometheus_metrics(tr, reg)

  # Find an available port
  port <- httpuv::randomPort()

  srv <- serve_prometheus(reg, host = "127.0.0.1", port = port)
  on.exit(httpuv::stopServer(srv), add = TRUE)

  # Use httpuv's built-in request mechanism via curl
  # We need to service the event loop for httpuv to respond
  url <- sprintf("http://127.0.0.1:%d/metrics", port)

  # Use a raw socket connection via curl to avoid readLines blocking
  skip_if_not_installed("curl")

  # Make async-friendly request: start, service httpuv, collect
  pool <- curl::new_pool()
  result <- NULL
  curl::curl_fetch_multi(url, done = function(resp) {
    result <<- resp
  }, fail = function(msg) {
    result <<- NULL
  }, pool = pool)

  # Service httpuv event loop while curl works
  deadline <- Sys.time() + 5
  while (is.null(result) && Sys.time() < deadline) {
    httpuv::service(100)
    curl::multi_run(timeout = 0.1, pool = pool)
  }

  expect_false(is.null(result))
  expect_equal(result$status_code, 200L)
  body <- rawToChar(result$content)

  # Verify Prometheus exposition format
  expect_match(body, "securetrace_spans_total")
  expect_match(body, "securetrace_tokens_total")
  expect_match(body, "securetrace_traces_total")
  expect_match(body, "# HELP")
  expect_match(body, "# TYPE")
})
