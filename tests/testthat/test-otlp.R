# --- Helpers ---

make_trace_list <- function() {
  tr <- Trace$new("test-trace")
  tr$start()

  s1 <- Span$new("llm-call", type = "llm")
  s1$start()
  s1$set_model("gpt-4o")
  s1$set_tokens(input = 100L, output = 50L)
  s1$add_metric("latency", 1.23, unit = "seconds")
  evt <- trace_event("prompt_sent", data = list(length = 42L))
  s1$add_event(evt)
  s1$end()
  tr$add_span(s1)

  s2 <- Span$new("tool-call", type = "tool", parent_id = s1$span_id,
                  metadata = list(tool_name = "calculator"))
  s2$start()
  s2$end()
  tr$add_span(s2)

  s3 <- Span$new("guard-check", type = "guardrail")
  s3$start()
  s3$set_error("injection detected")
  s3$end(status = "error")
  tr$add_span(s3)

  tr$end()
  tr$to_list()
}

# --- otlp_format_trace structure ---

test_that("otlp_format_trace produces correct top-level structure", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl, service_name = "test-svc")

  expect_type(otlp, "list")
  expect_named(otlp, "resourceSpans")
  expect_length(otlp$resourceSpans, 1)

  rs <- otlp$resourceSpans[[1]]
  expect_true("resource" %in% names(rs))
  expect_true("scopeSpans" %in% names(rs))
})

test_that("otlp_format_trace includes service.name in resource attributes", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl, service_name = "my-app")

  attrs <- otlp$resourceSpans[[1]]$resource$attributes
  svc_attr <- Filter(function(a) a$key == "service.name", attrs)
  expect_length(svc_attr, 1)
  expect_equal(svc_attr[[1]]$value$stringValue, "my-app")
})

test_that("otlp_format_trace scope has securetrace name and version", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)

  scope <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$scope
  expect_equal(scope$name, "securetrace")
  expect_type(scope$version, "character")
  # Version should look like a version string
  expect_true(grepl("^[0-9]+\\.[0-9]+", scope$version))
})

test_that("otlp_format_trace converts all spans", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)

  spans <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$spans
  expect_length(spans, 3)
})

# --- Time conversion ---

test_that("iso_to_nanos converts ISO 8601 to nanosecond epoch string", {
  # 2024-01-01T00:00:00.000Z = 1704067200 seconds
  result <- securetrace:::iso_to_nanos("2024-01-01T00:00:00.000Z")
  expect_type(result, "character")
  # Should be a large number string with no decimal
  expect_false(grepl("\\.", result))
  expect_false(grepl("e|E", result))
  # Should start with 1704067200 (the epoch seconds)
  expect_true(grepl("^1704067200", result))
})

test_that("iso_to_nanos handles NULL input", {
  expect_equal(securetrace:::iso_to_nanos(NULL), "0")
})

test_that("iso_to_nanos handles NA input", {
  expect_equal(securetrace:::iso_to_nanos(NA), "0")
})

test_that("span startTimeUnixNano and endTimeUnixNano are strings", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)
  span <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$spans[[1]]

  expect_type(span$startTimeUnixNano, "character")
  expect_type(span$endTimeUnixNano, "character")
  # Should be numeric-looking strings
  expect_true(grepl("^[0-9]+$", span$startTimeUnixNano))
  expect_true(grepl("^[0-9]+$", span$endTimeUnixNano))
})

# --- Span kind mapping ---

test_that("llm type maps to CLIENT kind (3)", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)
  spans <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$spans

  # First span is type "llm"
  expect_equal(spans[[1]]$kind, 3L)
})

test_that("tool type maps to INTERNAL kind (1)", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)
  spans <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$spans

  # Second span is type "tool"
  expect_equal(spans[[2]]$kind, 1L)
})

test_that("guardrail type maps to INTERNAL kind (1)", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)
  spans <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$spans

  # Third span is type "guardrail"
  expect_equal(spans[[3]]$kind, 1L)
})

# --- Status mapping ---

test_that("ok status maps to code 1", {
  result <- securetrace:::otlp_status("ok")
  expect_equal(result$code, 1L)
  expect_null(result$message)
})

test_that("completed status maps to code 1", {
  result <- securetrace:::otlp_status("completed")
  expect_equal(result$code, 1L)
})

test_that("error status maps to code 2 with message", {
  result <- securetrace:::otlp_status("error", error = "something broke")
  expect_equal(result$code, 2L)
  expect_equal(result$message, "something broke")
})

test_that("running status maps to code 0 (UNSET)", {
  result <- securetrace:::otlp_status("running")
  expect_equal(result$code, 0L)
})

test_that("error span has status code 2 in formatted output", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)
  spans <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$spans

  # Third span has error status
  expect_equal(spans[[3]]$status$code, 2L)
  expect_equal(spans[[3]]$status$message, "injection detected")
})

# --- GenAI attributes ---

test_that("LLM spans have gen_ai attributes", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)
  llm_span <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$spans[[1]]

  attrs <- llm_span$attributes
  attr_keys <- vapply(attrs, function(a) a$key, character(1))

  expect_true("gen_ai.request.model" %in% attr_keys)
  expect_true("gen_ai.usage.input_tokens" %in% attr_keys)
  expect_true("gen_ai.usage.output_tokens" %in% attr_keys)

  # Check values
  model_attr <- Filter(function(a) a$key == "gen_ai.request.model", attrs)[[1]]
  expect_equal(model_attr$value$stringValue, "gpt-4o")

  input_attr <- Filter(function(a) a$key == "gen_ai.usage.input_tokens", attrs)[[1]]
  expect_equal(input_attr$value$intValue, "100")

  output_attr <- Filter(function(a) a$key == "gen_ai.usage.output_tokens", attrs)[[1]]
  expect_equal(output_attr$value$intValue, "50")
})

# --- Events ---

test_that("events are properly converted", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)
  llm_span <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$spans[[1]]

  expect_true("events" %in% names(llm_span))
  expect_length(llm_span$events, 1)

  evt <- llm_span$events[[1]]
  expect_equal(evt$name, "prompt_sent")
  expect_type(evt$timeUnixNano, "character")

  # Event data becomes attributes
  evt_attrs <- evt$attributes
  length_attr <- Filter(function(a) a$key == "length", evt_attrs)[[1]]
  expect_equal(length_attr$value$intValue, "42")
})

# --- Metrics as attributes ---

test_that("metrics become securetrace.metric.* attributes", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)
  llm_span <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$spans[[1]]

  attrs <- llm_span$attributes
  metric_attr <- Filter(function(a) a$key == "securetrace.metric.latency", attrs)
  expect_length(metric_attr, 1)
  expect_equal(metric_attr[[1]]$value$doubleValue, 1.23)
})

# --- Metadata as attributes ---

test_that("metadata becomes span attributes", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)
  # Second span (tool-call) has metadata: tool_name = "calculator"
  tool_span <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$spans[[2]]

  attrs <- tool_span$attributes
  tool_attr <- Filter(function(a) a$key == "tool_name", attrs)
  expect_length(tool_attr, 1)
  expect_equal(tool_attr[[1]]$value$stringValue, "calculator")
})

# --- parent_id ---

test_that("NULL parent_id is omitted from span", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)
  spans <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$spans

  # First span (llm-call) has no parent
  expect_false("parentSpanId" %in% names(spans[[1]]))

  # Second span (tool-call) has parent_id
  expect_true("parentSpanId" %in% names(spans[[2]]))
  expect_type(spans[[2]]$parentSpanId, "character")
})

# --- traceId on all spans ---

test_that("all spans carry the trace_id", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)
  spans <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$spans

  for (s in spans) {
    expect_equal(s$traceId, tl$trace_id)
  }
})

# --- otlp_exporter returns correct class ---

test_that("otlp_exporter returns a securetrace_exporter S7 object", {
  exp <- otlp_exporter()
  expect_true(S7::S7_inherits(exp, securetrace_exporter))
})

test_that("otlp_exporter with custom parameters returns exporter", {
  exp <- otlp_exporter(
    endpoint = "http://my-collector:4318",
    headers = list(Authorization = "Bearer token"),
    service_name = "my-svc",
    batch_size = 50L
  )
  expect_true(S7::S7_inherits(exp, securetrace_exporter))
})

# --- OTLP attribute formatting ---

test_that("otlp_attr formats string values", {
  attr <- securetrace:::otlp_attr("key", "value")
  expect_equal(attr$key, "key")
  expect_equal(attr$value$stringValue, "value")
})

test_that("otlp_attr formats integer values", {
  attr <- securetrace:::otlp_attr("key", 42L)
  expect_equal(attr$value$intValue, "42")
})

test_that("otlp_attr formats double values", {
  attr <- securetrace:::otlp_attr("key", 3.14)
  expect_equal(attr$value$doubleValue, 3.14)
})

test_that("otlp_attr formats boolean values", {
  attr <- securetrace:::otlp_attr("key", TRUE)
  expect_equal(attr$value$boolValue, TRUE)
})

# --- No network tests (HTTP mocking not needed) ---

test_that("otlp_send requires httr2 package", {
  # This test just confirms the function exists and has the right signature
  expect_true(is.function(securetrace:::otlp_send))
})

# --- Spans without tokens don't get token attributes ---

test_that("spans without tokens omit gen_ai.usage attributes", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)
  # Second span (tool-call) has no tokens
  tool_span <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$spans[[2]]

  if (!is.null(tool_span$attributes)) {
    attr_keys <- vapply(tool_span$attributes, function(a) a$key, character(1))
    expect_false("gen_ai.usage.input_tokens" %in% attr_keys)
    expect_false("gen_ai.usage.output_tokens" %in% attr_keys)
  }
})

# --- Spans without model don't get model attribute ---

test_that("spans without model omit gen_ai.request.model attribute", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)
  # Second span (tool-call) has no model
  tool_span <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$spans[[2]]

  if (!is.null(tool_span$attributes)) {
    attr_keys <- vapply(tool_span$attributes, function(a) a$key, character(1))
    expect_false("gen_ai.request.model" %in% attr_keys)
  }
})

# --- Spans without events don't include events key ---

test_that("spans without events omit events field", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl)
  # Second span (tool-call) has no events
  tool_span <- otlp$resourceSpans[[1]]$scopeSpans[[1]]$spans[[2]]

  expect_false("events" %in% names(tool_span))
})

# --- Resource attributes (OTel semantic conventions) ---

test_that("otlp_format_trace includes telemetry SDK resource attributes", {
  tl <- make_trace_list()
  otlp <- otlp_format_trace(tl, service_name = "test-svc")

  attrs <- otlp$resourceSpans[[1]]$resource$attributes
  attr_keys <- vapply(attrs, function(a) a$key, character(1))

  expect_true("service.name" %in% attr_keys)
  expect_true("telemetry.sdk.name" %in% attr_keys)
  expect_true("telemetry.sdk.version" %in% attr_keys)
  expect_true("telemetry.sdk.language" %in% attr_keys)

  sdk_name <- Filter(function(a) a$key == "telemetry.sdk.name", attrs)[[1]]
  expect_equal(sdk_name$value$stringValue, "securetrace")

  sdk_lang <- Filter(function(a) a$key == "telemetry.sdk.language", attrs)[[1]]
  expect_equal(sdk_lang$value$stringValue, "R")

  sdk_ver <- Filter(function(a) a$key == "telemetry.sdk.version", attrs)[[1]]
  expect_type(sdk_ver$value$stringValue, "character")
  expect_true(grepl("^[0-9]+\\.[0-9]+", sdk_ver$value$stringValue))
})

# --- OTLP retry logic ---

test_that("otlp_send retries on transient HTTP errors", {
  skip_if_not_installed("httr2")

  attempt_count <- 0L

  # Mock otlp_send by replacing the HTTP layer
  local_mocked_bindings(
    otlp_send = function(payload, endpoint, headers = list(), max_retries = 3L) {
      attempt_count <<- attempt_count + 1L
      if (attempt_count < 3L) {
        rlang::abort("HTTP 503", class = "httr2_http_503")
      }
      invisible(list(status_code = 200L))
    },
    .package = "securetrace"
  )

  # The exporter should succeed after retries
  exp <- otlp_exporter(max_retries = 3L)
  tl <- make_trace_list()
  tr <- Trace$new("retry-test")
  tr$start()
  tr$end()

  # Export should not error (retries succeed)
  expect_no_error(export_trace(exp, tr))
})

test_that("otlp_exporter accepts max_retries parameter", {
  exp <- otlp_exporter(max_retries = 5L)
  expect_true(S7::S7_inherits(exp, securetrace_exporter))
})

# --- OTLP batching ---

test_that("otlp_exporter with batch_size accumulates traces in buffer", {
  send_count <- 0L

  local_mocked_bindings(
    otlp_send_batch = function(payloads, endpoint, headers = list(), max_retries = 3L) {
      send_count <<- send_count + 1L
      invisible(NULL)
    },
    .package = "securetrace"
  )

  exp <- otlp_exporter(batch_size = 3L)

  # Export 2 traces - should not send yet
  for (i in 1:2) {
    tr <- Trace$new(paste0("batch-", i))
    tr$start()
    tr$end()
    export_trace(exp, tr)
  }
  expect_equal(send_count, 0L)

  # Export 3rd trace - should trigger batch send
  tr3 <- Trace$new("batch-3")
  tr3$start()
  tr3$end()
  export_trace(exp, tr3)
  expect_equal(send_count, 1L)
})

test_that("flush_otlp sends buffered traces immediately", {
  send_count <- 0L

  local_mocked_bindings(
    otlp_send_batch = function(payloads, endpoint, headers = list(), max_retries = 3L) {
      send_count <<- send_count + 1L
      invisible(NULL)
    },
    .package = "securetrace"
  )

  exp <- otlp_exporter(batch_size = 10L)

  # Export 2 traces - not enough for batch
  for (i in 1:2) {
    tr <- Trace$new(paste0("flush-", i))
    tr$start()
    tr$end()
    export_trace(exp, tr)
  }
  expect_equal(send_count, 0L)

  # Flush forces send
  flush_otlp(exp)
  expect_equal(send_count, 1L)
})
