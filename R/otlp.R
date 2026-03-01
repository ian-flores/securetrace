#' OTLP JSON Exporter
#'
#' Creates an exporter that converts traces to OpenTelemetry Protocol (OTLP)
#' JSON format and sends them to an OTLP-compatible collector such as
#' Jaeger, Grafana Tempo, or any OpenTelemetry Collector.
#'
#' @param endpoint OTLP HTTP endpoint URL. Defaults to the
#'   `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable, or
#'   `"http://localhost:4318"` if unset.
#' @param headers Named list of HTTP headers to include in requests
#'   (e.g., authentication tokens).
#' @param service_name Service name reported in the resource attributes.
#'   Defaults to the `OTEL_SERVICE_NAME` environment variable, or
#'   `"r-agent"` if unset.
#' @param batch_size Maximum number of traces to buffer before sending
#'   (default `100L`). Traces are accumulated and sent when the buffer
#'   reaches this size. Use [flush_otlp()] to force-send buffered traces.
#' @param max_retries Maximum number of retry attempts for transient HTTP
#'   errors (429, 5xx). Default `3L`. Uses exponential backoff (1s, 2s, 4s).
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
#' flush_otlp(exp)
#' }
#' @export
otlp_exporter <- function(endpoint = Sys.getenv("OTEL_EXPORTER_OTLP_ENDPOINT",
                                                              "http://localhost:4318"),
                           headers = list(),
                           service_name = Sys.getenv("OTEL_SERVICE_NAME",
                                                     "r-agent"),
                           batch_size = 100L,
                           max_retries = 3L) {
  buffer <- new.env(parent = emptyenv())
  buffer$traces <- list()

  exp <- new_exporter(function(trace_list) {
    payload <- otlp_format_trace(trace_list, service_name = service_name)
    buffer$traces <- c(buffer$traces, list(payload))

    if (length(buffer$traces) >= batch_size) {
      otlp_send_batch(buffer$traces, endpoint = endpoint, headers = headers,
                       max_retries = max_retries)
      buffer$traces <- list()
    }
  })

  # Attach buffer env for flush_otlp()
  attr(exp, "otlp_buffer") <- buffer
  attr(exp, "otlp_endpoint") <- endpoint
  attr(exp, "otlp_headers") <- headers
  attr(exp, "otlp_max_retries") <- max_retries

  exp
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
            otlp_attr("service.name", service_name),
            otlp_attr("telemetry.sdk.name", "securetrace"),
            otlp_attr("telemetry.sdk.version", pkg_version),
            otlp_attr("telemetry.sdk.language", "R")
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


#' Flush Buffered OTLP Traces
#'
#' Forces immediate sending of any traces buffered in an OTLP exporter.
#'
#' @param exporter An OTLP exporter created by [otlp_exporter()].
#' @return Invisible `NULL`.
#' @examples
#' \dontrun{
#' exp <- otlp_exporter(batch_size = 50L)
#' # ... export some traces ...
#' flush_otlp(exp)
#' }
#' @export
flush_otlp <- function(exporter) {
  buffer <- attr(exporter, "otlp_buffer")
  if (is.null(buffer)) {
    cli::cli_abort("{.arg exporter} is not an OTLP exporter with a buffer.")
  }
  if (length(buffer$traces) > 0) {
    endpoint <- attr(exporter, "otlp_endpoint")
    headers <- attr(exporter, "otlp_headers")
    max_retries <- attr(exporter, "otlp_max_retries")
    otlp_send_batch(buffer$traces, endpoint = endpoint, headers = headers,
                     max_retries = max_retries)
    buffer$traces <- list()
  }
  invisible(NULL)
}

#' Send a batch of OTLP payloads
#' @param payloads List of OTLP payload lists.
#' @param endpoint Collector endpoint URL.
#' @param headers Named list of HTTP headers.
#' @param max_retries Maximum retry attempts.
#' @keywords internal
#' @noRd
otlp_send_batch <- function(payloads, endpoint, headers = list(),
                             max_retries = 3L) {
  for (payload in payloads) {
    otlp_send(payload, endpoint = endpoint, headers = headers,
              max_retries = max_retries)
  }
}

#' Send OTLP JSON payload to a collector
#'
#' Sends a single OTLP payload with retry logic for transient HTTP errors
#' (429, 500, 502, 503, 504). Uses exponential backoff.
#'
#' @param payload OTLP JSON payload (list).
#' @param endpoint Collector endpoint URL.
#' @param headers Named list of HTTP headers.
#' @param max_retries Maximum number of retry attempts (default `3L`).
#' @keywords internal
#' @noRd
otlp_send <- function(payload, endpoint, headers = list(), max_retries = 3L) {
  rlang::check_installed("httr2", reason = "to send OTLP trace data")

  transient_codes <- c(429L, 500L, 502L, 503L, 504L)
  delay <- 1

  for (attempt in seq_len(max_retries)) {
    resp <- tryCatch(
      {
        httr2::request(endpoint) |>
          httr2::req_url_path_append("/v1/traces") |>
          httr2::req_headers(!!!headers) |>
          httr2::req_body_json(payload, auto_unbox = TRUE) |>
          httr2::req_error(is_error = function(resp) FALSE) |>
          httr2::req_perform()
      },
      error = function(e) {
        e
      }
    )

    # If we got an error condition (network error), retry
    if (inherits(resp, "error")) {
      if (attempt < max_retries) {
        Sys.sleep(delay)
        delay <- delay * 2
        next
      }
      rlang::abort(conditionMessage(resp))
    }

    status <- httr2::resp_status(resp)
    if (!(status %in% transient_codes)) {
      return(invisible(resp))
    }

    # Transient error: retry with backoff
    if (attempt < max_retries) {
      Sys.sleep(delay)
      delay <- delay * 2
    }
  }

  # Final attempt also failed
  cli::cli_warn("OTLP send failed after {max_retries} attempts (HTTP {status}).")
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
