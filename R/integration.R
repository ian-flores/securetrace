#' Trace an LLM Call
#'
#' Wraps an ellmer chat call with automatic span and token recording.
#' Requires the ellmer package.
#'
#' @param chat An ellmer chat object.
#' @param prompt The prompt string to send.
#' @param ... Additional arguments passed to the chat method.
#' @return The chat response.
#' @export
trace_llm_call <- function(chat, prompt, ...) {
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg ellmer} is required for {.fn trace_llm_call}.")
  }

  with_span("llm_call", type = "llm", {
    start_time <- Sys.time()
    result <- chat$chat(prompt, ...)
    end_time <- Sys.time()

    span <- current_span()
    if (!is.null(span)) {
      record_latency(as.numeric(difftime(end_time, start_time, units = "secs")))
    }
    result
  })
}

#' Trace a Tool Execution
#'
#' Wraps a tool function call with a span.
#'
#' @param name Name of the tool.
#' @param fn Function to execute.
#' @param ... Arguments passed to `fn`.
#' @return The result of `fn(...)`.
#' @export
trace_tool_call <- function(name, fn, ...) {
  with_span(name, type = "tool", {
    fn(...)
  })
}

#' Trace a Guardrail Check
#'
#' Wraps a secureguard guardrail check with a span.
#' Requires the secureguard package.
#'
#' @param name Name of the guardrail.
#' @param guardrail The guardrail object or function.
#' @param x Input to check.
#' @return The guardrail result.
#' @export
trace_guardrail <- function(name, guardrail, x) {
  with_span(name, type = "guardrail", {
    if (is.function(guardrail)) {
      guardrail(x)
    } else {
      cli::cli_abort("{.arg guardrail} must be a function.")
    }
  })
}

#' Trace a Secure Code Execution
#'
#' Wraps a securer session execution with a span.
#' Requires the securer package.
#'
#' @param session A securer SecureSession object.
#' @param code Code string to execute.
#' @param ... Additional arguments passed to `session$execute()`.
#' @return The execution result.
#' @export
trace_execution <- function(session, code, ...) {
  if (!requireNamespace("securer", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg securer} is required for {.fn trace_execution}.")
  }

  with_span("secure_execution", type = "tool", {
    session$execute(code, ...)
  })
}
