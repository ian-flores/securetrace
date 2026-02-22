#' Exporter Class (S7)
#'
#' Wraps an export function as an S7 exporter object.
#'
#' @param export_fn A function that accepts a trace list.
#'
#' @examples
#' # Create a custom exporter
#' exp <- securetrace_exporter(export_fn = function(trace_list) {
#'   cat("Exported:", trace_list$name, "\n")
#' })
#' exp@export_fn
#' @export
securetrace_exporter <- new_class("securetrace_exporter", properties = list(
  export_fn = class_function
))

#' Create a New Exporter
#'
#' Factory function for creating exporter objects.
#'
#' @param export_fn A function that accepts a trace list (from `trace$to_list()`).
#' @return An S7 object of class `securetrace_exporter`.
#' @examples
#' # Create an exporter that counts traces
#' counter <- new.env(parent = emptyenv())
#' counter$n <- 0L
#' exp <- new_exporter(function(trace_list) {
#'   counter$n <- counter$n + 1L
#' })
#' @export
new_exporter <- function(export_fn) {
  if (!is.function(export_fn)) {
    cli::cli_abort("{.arg export_fn} must be a function.")
  }
  securetrace_exporter(export_fn = export_fn)
}

#' JSONL Exporter
#'
#' Creates an exporter that writes completed traces as JSONL
#' (one JSON object per line) to a file.
#'
#' @param path File path for the JSONL output.
#' @return An S3 `securetrace_exporter` object.
#' @examples
#' # Write traces to a temporary JSONL file
#' tmp <- tempfile(fileext = ".jsonl")
#' exp <- jsonl_exporter(tmp)
#'
#' tr <- Trace$new("demo")
#' tr$start()
#' tr$end()
#' export_trace(exp, tr)
#'
#' readLines(tmp)
#' unlink(tmp)
#' @export
jsonl_exporter <- function(path) {
  new_exporter(function(trace_list) {
    json_line <- jsonlite::toJSON(trace_list, auto_unbox = TRUE, null = "null")
    write(json_line, file = path, append = TRUE)
  })
}

#' Console Exporter
#'
#' Creates an exporter that prints trace summaries to the console.
#'
#' @param verbose If `TRUE`, print detailed span information.
#' @return An S3 `securetrace_exporter` object.
#' @examples
#' exp <- console_exporter(verbose = TRUE)
#'
#' tr <- Trace$new("demo-run")
#' tr$start()
#' span <- Span$new("step1", type = "custom")
#' span$start()
#' span$end()
#' tr$add_span(span)
#' tr$end()
#' export_trace(exp, tr)
#' @export
console_exporter <- function(verbose = TRUE) {
  new_exporter(function(trace_list) {
    cat(sprintf("--- Trace: %s ---\n", trace_list$name))
    cat(sprintf("Status: %s\n", trace_list$status))
    if (!is.null(trace_list$duration_secs)) {
      cat(sprintf("Duration: %.2fs\n", trace_list$duration_secs))
    }
    cat(sprintf("Spans: %d\n", length(trace_list$spans)))
    if (verbose && length(trace_list$spans) > 0) {
      cat("-- Spans --\n")
      for (s in trace_list$spans) {
        dur <- if (!is.null(s$duration_secs)) sprintf("%.3fs", s$duration_secs) else "N/A"
        cat(sprintf("  * %s [%s] (%s) - %s\n", s$name, s$type, s$status, dur))
      }
    }
  })
}

#' Export a Trace
#'
#' Calls the exporter's export function with the serialized trace.
#'
#' @param exporter An S3 `securetrace_exporter` object.
#' @param trace A `Trace` object.
#' @return Invisible `NULL`.
#' @examples
#' exp <- console_exporter(verbose = FALSE)
#' tr <- Trace$new("test-trace")
#' tr$start()
#' tr$end()
#' export_trace(exp, tr)
#' @export
export_trace <- function(exporter, trace) {
  if (!S7_inherits(exporter, securetrace_exporter)) {
    cli::cli_abort("{.arg exporter} must be a {.cls securetrace_exporter} object.")
  }
  trace_list <- trace$to_list()
  exporter@export_fn(trace_list)
  invisible(NULL)
}

#' Multi-Exporter
#'
#' Combines multiple exporters into one. When a trace is exported,
#' it is sent to all contained exporters.
#'
#' @param ... Exporter objects to combine.
#' @return An S3 `securetrace_exporter` object.
#' @examples
#' # Export to both console and JSONL
#' tmp <- tempfile(fileext = ".jsonl")
#' combined <- multi_exporter(
#'   console_exporter(verbose = FALSE),
#'   jsonl_exporter(tmp)
#' )
#'
#' tr <- Trace$new("multi-demo")
#' tr$start()
#' tr$end()
#' export_trace(combined, tr)
#' unlink(tmp)
#' @export
multi_exporter <- function(...) {
  exporters <- list(...)
  for (e in exporters) {
    if (!S7_inherits(e, securetrace_exporter)) {
      cli::cli_abort("All arguments must be {.cls securetrace_exporter} objects.")
    }
  }
  new_exporter(function(trace_list) {
    for (e in exporters) {
      e@export_fn(trace_list)
    }
  })
}

method(print, securetrace_exporter) <- function(x, ...) {
  cat("<securetrace_exporter>\n")
  invisible(x)
}

#' JSONL Trace Schema
#'
#' Returns a list describing the expected JSONL trace format, including
#' field names, types, and descriptions for all top-level and span-level fields.
#'
#' @return A named list where each element describes a field with `type` and
#'   `description`. The `spans` element additionally contains a `fields` list
#'   describing the span sub-structure.
#' @examples
#' schema <- trace_schema()
#' names(schema)
#' schema$trace_id
#' names(schema$spans$fields)
#' @export
trace_schema <- function() {
  list(
    trace_id = list(
      type = "character",
      description = "Unique identifier for the trace (UUID)"
    ),
    name = list(
      type = "character",
      description = "Human-readable name for the trace"
    ),
    status = list(
      type = "character",
      description = "Trace status: 'running', 'completed', or 'error'"
    ),
    start_time = list(
      type = "character",
      description = "ISO 8601 timestamp when the trace started"
    ),
    end_time = list(
      type = "character",
      description = "ISO 8601 timestamp when the trace ended"
    ),
    duration = list(
      type = "numeric",
      description = "Total trace duration in seconds"
    ),
    spans = list(
      type = "array",
      description = "Array of span objects representing individual operations",
      fields = list(
        span_id = list(
          type = "character",
          description = "Unique identifier for the span (UUID)"
        ),
        name = list(
          type = "character",
          description = "Human-readable name for the span"
        ),
        type = list(
          type = "character",
          description = "Span type: 'llm', 'tool', 'guardrail', or 'custom'"
        ),
        status = list(
          type = "character",
          description = "Span status: 'running', 'ok', 'completed', or 'error'"
        ),
        start_time = list(
          type = "character",
          description = "ISO 8601 timestamp when the span started"
        ),
        end_time = list(
          type = "character",
          description = "ISO 8601 timestamp when the span ended"
        ),
        duration_secs = list(
          type = "numeric",
          description = "Span duration in seconds"
        ),
        parent_id = list(
          type = "character",
          description = "Span ID of the parent span, or NULL if root"
        ),
        model = list(
          type = "character",
          description = "LLM model name (e.g., 'gpt-4o'), NULL for non-LLM spans"
        ),
        input_tokens = list(
          type = "integer",
          description = "Number of input tokens consumed"
        ),
        output_tokens = list(
          type = "integer",
          description = "Number of output tokens generated"
        )
      )
    )
  )
}
