#' Trace an LLM Call
#'
#' Wraps an ellmer chat call with automatic span and token recording.
#' Requires the ellmer package.
#'
#' When the `chat` object supports ellmer's `get_model()` and `get_tokens()`
#' methods, the model name and token usage are automatically extracted and
#' recorded on the span. Model names are resolved through [resolve_model()]
#' for proper cost calculation with cloud provider model IDs.
#'
#' Auto-extraction is best-effort: if the chat object does not support these
#' methods (e.g., a non-ellmer Chat object), the span will still be created
#' with latency recorded but without model or token data.
#'
#' @param chat An ellmer chat object.
#' @param prompt The prompt string to send.
#' @param ... Additional arguments passed to the chat method.
#' @param stream Logical. If `TRUE`, calls `chat$stream(prompt, ...)` instead
#'   of `chat$chat(prompt, ...)`. Default `FALSE`.
#' @return The chat response.
#' @examples
#' \dontrun{
#' # Requires ellmer package
#' chat <- ellmer::chat_openai(model = "gpt-4o")
#' with_trace("llm-demo", {
#'   response <- trace_llm_call(chat, "What is 2 + 2?")
#' })
#' }
#' @export
trace_llm_call <- function(chat, prompt, ..., stream = FALSE) {
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg ellmer} is required for {.fn trace_llm_call}.")
  }

  # Capture token state before the call for delta computation
  tokens_before <- tryCatch(
    {
      if ("get_tokens" %in% names(chat)) chat$get_tokens() else NULL
    },
    error = function(e) NULL
  )

  with_span("llm_call", type = "llm", {
    start_time <- Sys.time()
    if (isTRUE(stream) && "stream" %in% names(chat)) {
      result <- chat$stream(prompt, ...)
    } else {
      result <- chat$chat(prompt, ...)
    }
    end_time <- Sys.time()

    span <- current_span()
    if (!is.null(span)) {
      record_latency(as.numeric(difftime(end_time, start_time, units = "secs")))

      # Record streaming event
      if (isTRUE(stream)) {
        span$add_event(trace_event("streaming", data = list(enabled = TRUE)))
      }

      # Auto-extract model name
      tryCatch(
        {
          if ("get_model" %in% names(chat)) {
            model_name <- chat$get_model()
            if (!is.null(model_name) && nzchar(model_name)) {
              span$set_model(resolve_model(model_name))
            }
          }
        },
        error = function(e) NULL
      )

      # Auto-extract token usage (delta from before/after the call)
      tryCatch(
        {
          if ("get_tokens" %in% names(chat)) {
            tokens_after <- chat$get_tokens()
            if (!is.null(tokens_after) && nrow(tokens_after) > 0) {
              if (is.null(tokens_before) || nrow(tokens_before) == 0) {
                # All rows are new
                delta_input <- sum(tokens_after$input, na.rm = TRUE)
                delta_output <- sum(tokens_after$output, na.rm = TRUE)
              } else {
                # New rows = rows after minus rows before
                new_rows <- tokens_after[seq(nrow(tokens_before) + 1, nrow(tokens_after), by = 1), , drop = FALSE]
                if (nrow(new_rows) > 0) {
                  delta_input <- sum(new_rows$input, na.rm = TRUE)
                  delta_output <- sum(new_rows$output, na.rm = TRUE)
                } else {
                  delta_input <- 0L
                  delta_output <- 0L
                }
              }
              span$set_tokens(input = delta_input, output = delta_output)
            }
          }
        },
        error = function(e) NULL
      )

      # Best-effort: extract tool calls from last_turn()
      tryCatch(
        {
          if ("last_turn" %in% names(chat)) {
            turn <- chat$last_turn()
            if (!is.null(turn) && !is.null(turn$contents)) {
              for (content in turn$contents) {
                if (inherits(content, "ContentToolRequest")) {
                  tool_name <- content$name %||% "unknown"
                  tool_args <- content$arguments %||% list()
                  span$add_event(trace_event("tool_call", data = list(
                    tool_name = tool_name,
                    arguments = tool_args
                  )))
                }
              }
            }
          }
        },
        error = function(e) NULL
      )
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
#' @examples
#' # Trace a tool function call
#' with_trace("tool-demo", {
#'   result <- trace_tool_call("add", function(a, b) a + b, 3, 4)
#'   result
#' })
#' @export
trace_tool_call <- function(name, fn, ...) {
  with_span(name, type = "tool", {
    fn(...)
  })
}

#' Trace a Guardrail Check
#'
#' Wraps a secureguard guardrail check with a span. If `guardrail` is a
#' secureguard Guard object (S7 class `secureguard`), its `check_fn` is
#' called and structured result metadata (pass/fail, score, guard name)
#' is recorded as span events. Otherwise, `guardrail` is called as a
#' plain function (backward-compatible behavior).
#'
#' @param name Name of the guardrail.
#' @param guardrail The guardrail object or function.
#' @param x Input to check.
#' @return The guardrail result.
#' @examples
#' # Trace a guardrail check function
#' check_length <- function(x) nchar(x) < 1000
#' with_trace("guard-demo", {
#'   result <- trace_guardrail("length_check", check_length, "short input")
#'   result
#' })
#' @export
trace_guardrail <- function(name, guardrail, x) {
  with_span(name, type = "guardrail", {
    # Detect secureguard Guard object
    is_secureguard <- tryCatch(
      {
        requireNamespace("secureguard", quietly = TRUE) &&
          S7_inherits(guardrail, secureguard::secureguard_class)
      },
      error = function(e) FALSE
    )

    if (is_secureguard) {
      result <- secureguard::run_guardrail(guardrail, x)
      span <- current_span()
      if (!is.null(span)) {
        event_data <- list(
          pass = result@pass,
          guard_name = guardrail@name,
          guard_type = guardrail@type
        )
        if (!is.null(result@reason)) {
          event_data$reason <- result@reason
        }
        span$add_event(trace_event("guardrail.result", data = event_data))
      }
      result
    } else if (is.function(guardrail)) {
      guardrail(x)
    } else {
      cli::cli_abort("{.arg guardrail} must be a function or secureguard object.")
    }
  })
}

#' Trace a Secure Code Execution
#'
#' Wraps a securer session execution with a span. Records the submitted code,
#' captured stdout/stderr, and sets span status to error on execution failure.
#' Requires the securer package.
#'
#' @param session A securer SecureSession object.
#' @param code Code string to execute.
#' @param ... Additional arguments passed to `session$execute()`.
#' @return The execution result.
#' @examples
#' \dontrun{
#' # Requires securer package
#' session <- securer::SecureSession$new()
#' with_trace("exec-demo", {
#'   result <- trace_execution(session, "1 + 1")
#' })
#' session$close()
#' }
#' @export
trace_execution <- function(session, code, ...) {
  if (!requireNamespace("securer", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg securer} is required for {.fn trace_execution}.")
  }

  with_span("secure_execution", type = "tool", {
    span <- current_span()

    # Record the submitted code before execution
    if (!is.null(span)) {
      span$add_event(trace_event("code.submitted", data = list(code = code)))
    }

    result <- session$execute(code, ...)

    # Extract stdout/stderr from the output attribute
    if (!is.null(span)) {
      output_lines <- attr(result, "output")
      if (!is.null(output_lines) && length(output_lines) > 0) {
        span$add_event(trace_event("execution.stdout", data = list(
          lines = output_lines
        )))
      }
    }

    result
  })
}
