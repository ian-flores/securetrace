#' OTLP JSON Exporter
#'
#' Creates an exporter that converts traces to OpenTelemetry Protocol (OTLP)
#' JSON format and sends them to an OTLP-compatible collector such as
#' Jaeger, Grafana Tempo, or any OpenTelemetry Collector.
#'
#' @param endpoint OTLP HTTP endpoint URL (default `"http://localhost:4318"`).
#' @param headers Named list of HTTP headers to include in requests
#'   (e.g., authentication tokens).
#' @param service_name Service name reported in the resource attributes
#'   (default `"r-agent"`).
#' @param batch_size Maximum number of spans per export batch
#'   (default `100L`). Currently unused; reserved for future batching support.
#' @return An S7 `securetrace_exporter` object.
#'
#' @examples
#' \dontrun{
#' # Export to a local Jaeger instance
#' exp <- otlp_exporter("http://localhost:4318")
#'
#' tr <- Trace$new("my-run")
#' tr$start()
#' s <- Span$new("llm-call", type = "llm")
#' s$start()
#' s$set_model("gpt-4o")
#' s$set_tokens(input = 100L, output = 50L)
#' s$end()
#' tr$add_span(s)
#' tr$end()
#' export_trace(exp, tr)
#' }
#' @export
otlp_exporter <- function(endpoint = "http://localhost:4318",
                           headers = list(),
                           service_name = "r-agent",
                           batch_size = 100L) {
  new_exporter(function(trace_list) {
    payload <- otlp_format_trace(trace_list, service_name = service_name)
    otlp_send(payload, endpoint = endpoint, headers = headers)
  })
}

#' Format a Trace as OTLP JSON
#'
#' Pure function that converts a trace list (from `trace$to_list()`) into
#' the OTLP JSON structure expected by OpenTelemetry collectors.
#'
#' @param trace_list A list produced by `Trace$to_list()`.
#' @param service_name Service name for the OTLP resource
#'   (default `"r-agent"`).
#' @return A named list matching the OTLP `ExportTraceServiceRequest`
#'   JSON structure.
#'
#' @examples
#' tr <- Trace$new("format-demo")
#' tr$start()
#' s <- Span$new("step", type = "tool")
#' s$start()
#' s$end()
#' tr$add_span(s)
#' tr$end()
#' otlp <- otlp_format_trace(tr$to_list())
#' str(otlp, max.level = 3)
#' @export
otlp_format_trace <- function(trace_list, service_name = "r-agent") {
  pkg_version <- tryCatch(
    as.character(utils::packageVersion("securetrace")),
    error = function(e) "0.0.0"
  )

  spans <- lapply(trace_list$spans, function(s) {
    otlp_format_span(s, trace_id = trace_list$trace_id)
  })

  list(
    resourceSpans = list(
      list(
        resource = list(
          attributes = list(
            otlp_attr("service.name", service_name)
          )
        ),
        scopeSpans = list(
          list(
            scope = list(name = "securetrace", version = pkg_version),
            spans = spans
          )
        )
      )
    )
  )
}


#' Format a single span to OTLP structure
#' @param span_list A list from `Span$to_list()`.
#' @param trace_id The parent trace ID.
#' @return A named list matching an OTLP span.
#' @keywords internal
#' @noRd
otlp_format_span <- function(span_list, trace_id) {
  # Build attributes
  attrs <- list()

  # GenAI semantic convention attributes

  if (!is.null(span_list$model)) {
    attrs <- c(attrs, list(otlp_attr("gen_ai.request.model", span_list$model)))
  }

  if (!is.null(span_list$input_tokens) && span_list$input_tokens > 0L) {
    attrs <- c(attrs, list(otlp_attr("gen_ai.usage.input_tokens", span_list$input_tokens)))
  }
  if (!is.null(span_list$output_tokens) && span_list$output_tokens > 0L) {
    attrs <- c(attrs, list(otlp_attr("gen_ai.usage.output_tokens", span_list$output_tokens)))
  }

  # Metrics as securetrace.metric.* attributes
  if (length(span_list$metrics) > 0) {
    for (m in span_list$metrics) {
      key <- paste0("securetrace.metric.", m$name)
      attrs <- c(attrs, list(otlp_attr(key, m$value)))
    }
  }

  # Metadata as attributes
  if (length(span_list$metadata) > 0) {
    for (nm in names(span_list$metadata)) {
      attrs <- c(attrs, list(otlp_attr(nm, span_list$metadata[[nm]])))
    }
  }

  # Events
  events <- lapply(span_list$events, function(evt) {
    evt_attrs <- list()
    if (length(evt$data) > 0) {
      for (nm in names(evt$data)) {
        evt_attrs <- c(evt_attrs, list(otlp_attr(nm, evt$data[[nm]])))
      }
    }
    result <- list(
      timeUnixNano = iso_to_nanos(evt$timestamp),
      name = evt$name
    )
    if (length(evt_attrs) > 0) {
      result$attributes <- evt_attrs
    }
    result
  })

  # Status
  status <- otlp_status(span_list$status, span_list$error)

  # Kind
  kind <- otlp_span_kind(span_list$type)

  # Build span
  span <- list(
    traceId = trace_id,
    spanId = span_list$span_id,
    name = span_list$name,
    kind = kind,
    startTimeUnixNano = iso_to_nanos(span_list$start_time),
    endTimeUnixNano = iso_to_nanos(span_list$end_time),
    status = status
  )

  # Only include parentSpanId if non-NULL

  if (!is.null(span_list$parent_id)) {
    span$parentSpanId <- span_list$parent_id
  }

  if (length(attrs) > 0) {
    span$attributes <- attrs
  }

  if (length(events) > 0) {
    span$events <- events
  }

  span
}


#' Send OTLP JSON payload to a collector
#' @param payload OTLP JSON payload (list).
#' @param endpoint Collector endpoint URL.
#' @param headers Named list of HTTP headers.
#' @keywords internal
#' @noRd
otlp_send <- function(payload, endpoint, headers = list()) {
  rlang::check_installed("httr2", reason = "to send OTLP trace data")

  resp <- httr2::request(endpoint) |>
    httr2::req_url_path_append("/v1/traces") |>
    httr2::req_headers(!!!headers) |>
    httr2::req_body_json(payload, auto_unbox = TRUE) |>
    httr2::req_perform()

  invisible(resp)
}


#' Convert ISO 8601 timestamp to nanosecond epoch string
#' @param iso_string An ISO 8601 timestamp string.
#' @return A character string of the nanosecond epoch value.
#' @keywords internal
#' @noRd
iso_to_nanos <- function(iso_string) {
  if (is.null(iso_string) || is.na(iso_string)) {
    return("0")
  }
  epoch_secs <- as.numeric(as.POSIXct(iso_string, tz = "UTC"))
  format(epoch_secs * 1e9, scientific = FALSE, digits = 19)
}


#' Build an OTLP attribute entry
#' @param key Attribute key string.
#' @param value Attribute value.
#' @return A list with `key` and `value` in OTLP attribute format.
#' @keywords internal
#' @noRd
otlp_attr <- function(key, value) {
  if (is.logical(value)) {
    list(key = key, value = list(boolValue = value))
  } else if (is.integer(value)) {
    list(key = key, value = list(intValue = as.character(value)))
  } else if (is.numeric(value)) {
    list(key = key, value = list(doubleValue = value))
  } else {
    list(key = key, value = list(stringValue = as.character(value)))
  }
}


#' Map securetrace span type to OTLP span kind
#' @param type Span type string ("llm", "tool", "guardrail", "custom").
#' @return Integer OTLP SpanKind value.
#' @keywords internal
#' @noRd
otlp_span_kind <- function(type) {
  switch(type,
    llm = 3L,       # CLIENT
    tool = 1L,      # INTERNAL
    guardrail = 1L, # INTERNAL
    custom = 1L,    # INTERNAL
    1L              # default: INTERNAL
  )
}


#' Map securetrace status to OTLP status
#' @param status Span status string ("ok", "error", "running", "completed").
#' @param error Optional error message string.
#' @return A list with OTLP status code and optional message.
#' @keywords internal
#' @noRd
otlp_status <- function(status, error = NULL) {
  code <- switch(status,
    ok = 1L,
    completed = 1L,
    error = 2L,
    0L  # UNSET for running or unknown
  )
  result <- list(code = code)
  if (code == 2L && !is.null(error)) {
    result$message <- error
  }
  result
}
