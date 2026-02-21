#' Record Token Usage on the Current Span
#'
#' Convenience wrapper that records input and output token counts
#' on the currently active span from the trace context.
#'
#' @param input_tokens Number of input tokens.
#' @param output_tokens Number of output tokens.
#' @param model Optional model name string.
#' @return Invisible `NULL`.
#' @export
record_tokens <- function(input_tokens, output_tokens, model = NULL) {
  span <- current_span()
  if (is.null(span)) {
    cli::cli_warn("No active span -- token recording ignored.")
    return(invisible(NULL))
  }
  span$set_tokens(input = input_tokens, output = output_tokens)
  if (!is.null(model)) {
    span$set_model(model)
  }
  invisible(NULL)
}

#' Record Latency on the Current Span
#'
#' Records a latency metric on the currently active span.
#'
#' @param duration_secs Duration in seconds.
#' @return Invisible `NULL`.
#' @export
record_latency <- function(duration_secs) {
  span <- current_span()
  if (is.null(span)) {
    cli::cli_warn("No active span -- latency recording ignored.")
    return(invisible(NULL))
  }

  span$add_metric("latency", duration_secs, unit = "seconds")
  invisible(NULL)
}

#' Record a Custom Metric on the Current Span
#'
#' @param name Metric name.
#' @param value Metric value.
#' @param unit Optional unit string.
#' @return Invisible `NULL`.
#' @export
record_metric <- function(name, value, unit = NULL) {
  span <- current_span()
  if (is.null(span)) {
    cli::cli_warn("No active span -- metric recording ignored.")
    return(invisible(NULL))
  }
  span$add_metric(name, value, unit)
  invisible(NULL)
}
