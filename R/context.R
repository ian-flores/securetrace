#' Trace Context Management
#'
#' Module-level environment maintaining the active trace and span stack.
#' @noRd
.trace_context <- new.env(parent = emptyenv())
.trace_context$trace_stack <- list()
.trace_context$span_stack <- list()
.trace_context$default_exporter <- NULL

#' Execute Code Within a Trace
#'
#' Creates a new trace, evaluates the expression, ends the trace, and
#' optionally exports it. The trace is available via [current_trace()]
#' during evaluation.
#'
#' @param name Name for the trace.
#' @param expr Expression to evaluate.
#' @param ... Additional arguments passed to `Trace$new()` as metadata.
#' @param exporter Optional exporter. If `NULL`, uses the default exporter
#'   (if set).
#' @return The result of evaluating `expr`.
#' @export
with_trace <- function(name, expr, ..., exporter = NULL) {
  dots <- list(...)
  metadata <- if (length(dots) > 0) dots else list()
  tr <- Trace$new(name, metadata = metadata)
  tr$start()

  .trace_context$trace_stack <- c(.trace_context$trace_stack, list(tr))
  on.exit({
    .trace_context$trace_stack <- .trace_context$trace_stack[-length(.trace_context$trace_stack)]
  }, add = TRUE)

  result <- tryCatch(
    expr,
    error = function(e) {
      tr$status <- "error"
      tr$end()
      exp <- exporter %||% .trace_context$default_exporter
      if (!is.null(exp)) export_trace(exp, tr)
      stop(e)
    }
  )

  tr$end()
  exp <- exporter %||% .trace_context$default_exporter
  if (!is.null(exp)) export_trace(exp, tr)
  result
}

#' Execute Code Within a Span
#'
#' Creates a new span within the current trace, evaluates the expression,
#' and ends the span. The span is available via [current_span()]
#' during evaluation.
#'
#' @param name Name for the span.
#' @param type Span type. One of "llm", "tool", "guardrail", "custom".
#' @param expr Expression to evaluate.
#' @param ... Additional arguments stored as metadata on the span.
#' @return The result of evaluating `expr`.
#' @export
with_span <- function(name, type = "custom", expr, ...) {
  tr <- current_trace()
  if (is.null(tr)) {
    cli::cli_abort("No active trace. Use {.fn with_trace} first.")
  }
  dots <- list(...)
  metadata <- if (length(dots) > 0) dots else list()

  parent <- current_span()
  parent_id <- if (!is.null(parent)) parent$span_id else NULL

  s <- Span$new(name, type = type, parent_id = parent_id, metadata = metadata)
  s$start()
  tr$add_span(s)

  .trace_context$span_stack <- c(.trace_context$span_stack, list(s))
  on.exit({
    .trace_context$span_stack <- .trace_context$span_stack[-length(.trace_context$span_stack)]
  }, add = TRUE)

  result <- tryCatch(
    expr,
    error = function(e) {
      s$set_error(e)
      s$end(status = "error")
      stop(e)
    }
  )

  s$end(status = "ok")
  result
}

#' Get the Current Active Trace
#'
#' @return The active `Trace` object, or `NULL` if none.
#' @export
current_trace <- function() {
  stack <- .trace_context$trace_stack
  if (length(stack) == 0) return(NULL)
  stack[[length(stack)]]
}

#' Get the Current Active Span
#'
#' @return The active `Span` object, or `NULL` if none.
#' @export
current_span <- function() {
  stack <- .trace_context$span_stack
  if (length(stack) == 0) return(NULL)
  stack[[length(stack)]]
}

#' Set the Default Exporter
#'
#' @param exporter An S3 `securetrace_exporter` object.
#' @return Invisible `NULL`.
#' @export
set_default_exporter <- function(exporter) {
  if (!inherits(exporter, "securetrace_exporter")) {
    cli::cli_abort("{.arg exporter} must be a {.cls securetrace_exporter} object.")
  }
  .trace_context$default_exporter <- exporter
  invisible(NULL)
}

#' @noRd
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
