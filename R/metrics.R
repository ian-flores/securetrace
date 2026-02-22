#' Record Token Usage on the Current Span
#'
#' Convenience wrapper that records input and output token counts
#' on the currently active span from the trace context.
#'
#' @param input_tokens Number of input tokens.
#' @param output_tokens Number of output tokens.
#' @param model Optional model name string.
#' @return Invisible `NULL`.
#' @examples
#' # Record tokens on the active span inside a trace
#' with_trace("token-demo", {
#'   with_span("llm-step", type = "llm", {
#'     record_tokens(500, 200, model = "gpt-4o")
#'     current_span()$input_tokens
#'   })
#' })
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
#' @examples
#' # Record latency on the active span
#' with_trace("latency-demo", {
#'   with_span("api-call", type = "custom", {
#'     record_latency(0.45)
#'   })
#' })
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
#' @examples
#' # Record a custom metric on the active span
#' with_trace("metric-demo", {
#'   with_span("scoring", type = "custom", {
#'     record_metric("confidence", 0.95)
#'     record_metric("temperature", 0.7, unit = "degrees")
#'   })
#' })
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
