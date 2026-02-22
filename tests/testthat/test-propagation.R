# --- traceparent() ---

test_that("traceparent generates correct format with sampled=TRUE", {
  result <- traceparent(
    "4bf92f3577b34da6a3ce929d0e0e4736",
    "00f067aa0ba902b7"
  )
  expect_equal(result, "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01")
})

test_that("traceparent generates correct format with sampled=FALSE", {
  result <- traceparent(
    "4bf92f3577b34da6a3ce929d0e0e4736",
    "00f067aa0ba902b7",
    sampled = FALSE
  )
  expect_equal(result, "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-00")
})

test_that("traceparent validates trace_id length", {
  expect_error(
    traceparent("abc123", "00f067aa0ba902b7"),
    "trace_id"
  )
})

test_that("traceparent validates trace_id hex characters", {
  expect_error(
    traceparent("4bf92f3577b34da6a3ce929d0e0eXXXX", "00f067aa0ba902b7"),
    "trace_id"
  )
})

test_that("traceparent rejects all-zero trace_id", {
  expect_error(
    traceparent("00000000000000000000000000000000", "00f067aa0ba902b7"),
    "all zeros"
  )
})

test_that("traceparent validates span_id length", {
  expect_error(
    traceparent("4bf92f3577b34da6a3ce929d0e0e4736", "abc123"),
    "span_id"
  )
})

test_that("traceparent validates span_id hex characters", {
  expect_error(
    traceparent("4bf92f3577b34da6a3ce929d0e0e4736", "00f067aa0ba9XXXX"),
    "span_id"
  )
})

test_that("traceparent rejects all-zero span_id", {
  expect_error(
    traceparent("4bf92f3577b34da6a3ce929d0e0e4736", "0000000000000000"),
    "all zeros"
  )
})

# --- parse_traceparent() ---

test_that("parse_traceparent correctly parses valid header", {
  result <- parse_traceparent(
    "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
  )
  expect_type(result, "list")
  expect_equal(result$version, "00")
  expect_equal(result$trace_id, "4bf92f3577b34da6a3ce929d0e0e4736")
  expect_equal(result$span_id, "00f067aa0ba902b7")
  expect_true(result$sampled)
})

test_that("parse_traceparent extracts sampled=FALSE correctly", {
  result <- parse_traceparent(
    "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-00"
  )
  expect_false(result$sampled)
})

test_that("parse_traceparent returns NULL for invalid format", {
  expect_warning(result <- parse_traceparent("invalid"), "Invalid")
  expect_null(result)
})

test_that("parse_traceparent returns NULL for too-short header", {
  expect_warning(result <- parse_traceparent("00-abc-def-01"), "Invalid")
  expect_null(result)
})

test_that("parse_traceparent returns NULL for uppercase hex", {
  expect_warning(
    result <- parse_traceparent(
      "00-4BF92F3577B34DA6A3CE929D0E0E4736-00F067AA0BA902B7-01"
    ),
    "Invalid"
  )
  expect_null(result)
})

test_that("parse_traceparent returns NULL for non-string input", {
  expect_warning(result <- parse_traceparent(42), "Invalid")
  expect_null(result)
})

test_that("parse_traceparent returns NULL for all-zero trace_id", {
  expect_warning(
    result <- parse_traceparent(
      "00-00000000000000000000000000000000-00f067aa0ba902b7-01"
    ),
    "all zeros"
  )
  expect_null(result)
})

# --- inject_headers() ---

test_that("inject_headers adds traceparent when span context exists", {
  reset_context()
  with_trace("inject-test", {
    with_span("http-span", type = "tool", {
      headers <- inject_headers()
      expect_true("traceparent" %in% names(headers))
      # Verify format
      parsed <- parse_traceparent(headers$traceparent)
      expect_false(is.null(parsed))
      # Verify IDs match the active context
      expect_equal(parsed$trace_id, current_trace()$trace_id)
      expect_equal(parsed$span_id, current_span()$span_id)
    })
  })
  reset_context()
})

test_that("inject_headers preserves existing headers", {
  reset_context()
  with_trace("preserve-test", {
    with_span("http-span", type = "tool", {
      existing <- list(
        "Content-Type" = "application/json",
        "Authorization" = "Bearer token123"
      )
      headers <- inject_headers(existing)
      expect_equal(headers[["Content-Type"]], "application/json")
      expect_equal(headers[["Authorization"]], "Bearer token123")
      expect_true("traceparent" %in% names(headers))
    })
  })
  reset_context()
})

test_that("inject_headers warns when no active span", {
  reset_context()
  expect_warning(
    headers <- inject_headers(list("X-Custom" = "value")),
    "No active trace/span"
  )
  expect_equal(headers, list("X-Custom" = "value"))
  reset_context()
})

# --- extract_trace_context() ---

test_that("extract_trace_context finds traceparent header", {
  headers <- list(
    "Content-Type" = "application/json",
    traceparent = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
  )
  ctx <- extract_trace_context(headers)
  expect_false(is.null(ctx))
  expect_equal(ctx$trace_id, "4bf92f3577b34da6a3ce929d0e0e4736")
  expect_equal(ctx$span_id, "00f067aa0ba902b7")
  expect_true(ctx$sampled)
})

test_that("extract_trace_context handles case-insensitive lookup", {
  headers <- list(
    "Content-Type" = "text/html",
    "Traceparent" = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
  )
  ctx <- extract_trace_context(headers)
  expect_false(is.null(ctx))
  expect_equal(ctx$trace_id, "4bf92f3577b34da6a3ce929d0e0e4736")
})

test_that("extract_trace_context returns NULL when no traceparent", {
  headers <- list("Content-Type" = "application/json")
  expect_null(extract_trace_context(headers))
})

test_that("extract_trace_context returns NULL for empty headers", {
  expect_null(extract_trace_context(list()))
})

test_that("extract_trace_context returns NULL for NULL input", {
  expect_null(extract_trace_context(NULL))
})

# --- Round-trip ---

test_that("round-trip: traceparent -> parse_traceparent preserves all fields", {
  tid <- "abcdef1234567890abcdef1234567890"
  sid <- "1234567890abcdef"

  header <- traceparent(tid, sid, sampled = TRUE)
  parsed <- parse_traceparent(header)

  expect_equal(parsed$version, "00")
  expect_equal(parsed$trace_id, tid)
  expect_equal(parsed$span_id, sid)
  expect_true(parsed$sampled)

  header2 <- traceparent(tid, sid, sampled = FALSE)
  parsed2 <- parse_traceparent(header2)
  expect_false(parsed2$sampled)
})
