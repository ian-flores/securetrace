#' Create a New Exporter
#'
#' Wraps an export function as an S3 exporter object.
#'
#' @param export_fn A function that accepts a trace list (from `trace$to_list()`).
#' @return An S3 object of class `securetrace_exporter`.
#' @export
new_exporter <- function(export_fn) {
  if (!is.function(export_fn)) {
    cli::cli_abort("{.arg export_fn} must be a function.")
  }
  structure(
    list(export_fn = export_fn),
    class = "securetrace_exporter"
  )
}

#' JSONL Exporter
#'
#' Creates an exporter that writes completed traces as JSONL
#' (one JSON object per line) to a file.
#'
#' @param path File path for the JSONL output.
#' @return An S3 `securetrace_exporter` object.
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
#' @export
export_trace <- function(exporter, trace) {
  if (!inherits(exporter, "securetrace_exporter")) {
    cli::cli_abort("{.arg exporter} must be a {.cls securetrace_exporter} object.")
  }
  trace_list <- trace$to_list()
  exporter$export_fn(trace_list)
  invisible(NULL)
}

#' Multi-Exporter
#'
#' Combines multiple exporters into one. When a trace is exported,
#' it is sent to all contained exporters.
#'
#' @param ... Exporter objects to combine.
#' @return An S3 `securetrace_exporter` object.
#' @export
multi_exporter <- function(...) {
  exporters <- list(...)
  for (e in exporters) {
    if (!inherits(e, "securetrace_exporter")) {
      cli::cli_abort("All arguments must be {.cls securetrace_exporter} objects.")
    }
  }
  new_exporter(function(trace_list) {
    for (e in exporters) {
      e$export_fn(trace_list)
    }
  })
}

#' @export
print.securetrace_exporter <- function(x, ...) {
  cat("<securetrace_exporter>\n")
  invisible(x)
}
