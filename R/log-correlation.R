#' Get Trace Context Prefix for Log Messages
#'
#' Returns a formatted string containing the current trace and span IDs,
#' suitable for prepending to log messages. If no trace is active, returns
#' an empty string.
#'
#' @return Character string like `"[trace_id=X span_id=Y] "` or `""`.
#' @examples
#' # Outside a trace, returns empty string
#' trace_log_prefix()
#'
#' # Inside a trace with a span
#' with_trace("demo", {
#'   with_span("step", type = "custom", {
#'     trace_log_prefix()
#'   })
#' })
#' @export
trace_log_prefix <- function() {
  tr <- current_trace()
  if (is.null(tr)) return("")

  span <- current_span()
  span_id <- if (!is.null(span)) span$span_id else ""

  sprintf("[trace_id=%s span_id=%s] ", tr$trace_id, span_id)
}

#' Execute Expression with Trace-Correlated Logging
#'
#' Wraps message handlers to prepend trace context (trace ID and span ID)
#' to log messages emitted via [message()]. This makes it easy to correlate
#' log output with distributed traces.
#'
#' @param expr Expression to evaluate.
#' @return Result of evaluating `expr`.
#' @examples
#' with_trace("demo", {
#'   with_span("step", type = "custom", {
#'     with_trace_logging({
#'       message("hello from inside a span")
#'     })
#'   })
#' })
#' @export
with_trace_logging <- function(expr) {
  withCallingHandlers(
    expr,
    message = function(cnd) {
      prefix <- trace_log_prefix()
      if (nzchar(prefix)) {
        msg <- conditionMessage(cnd)
        # Remove trailing newline added by message(), re-add after prefix
        msg <- sub("\n$", "", msg)
        message(prefix, msg)
        invokeRestart("muffleMessage")
      }
    }
  )
}
