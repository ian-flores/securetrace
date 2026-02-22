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
