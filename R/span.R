#' Span Class
#'
#' Represents a single operation within a trace, such as an LLM call,
#' tool execution, guardrail check, or custom operation.
#'
#' @return An R6 object of class `Span`.
#' @examples
#' # Create a span for an LLM call
#' span <- Span$new("gpt-call", type = "llm")
#' span$start()
#' span$set_model("gpt-4o")
#' span$set_tokens(input = 500L, output = 200L)
#' span$add_metric("latency", 1.23, unit = "seconds")
#'
#' # Add an event
#' evt <- trace_event("prompt_sent", data = list(length = 42L))
#' span$add_event(evt)
#'
#' span$end()
#' span$status
#' span$duration()
#' span$to_list()
#' @export
Span <- R6::R6Class(
  "Span",
  public = list(
    #' @field name Name of the span.
    name = NULL,

    #' @field span_id Unique identifier for the span.
    span_id = NULL,

    #' @field type Type of operation: "llm", "tool", "guardrail", or "custom".
    type = NULL,

    #' @field parent_id ID of the parent span, if any.
    parent_id = NULL,

    #' @field metadata Arbitrary metadata attached to the span.
    metadata = NULL,

    #' @field status Current status: "running", "ok", or "error".
    status = NULL,

    #' @field input_tokens Number of input tokens recorded.
    input_tokens = 0L,

    #' @field output_tokens Number of output tokens recorded.
    output_tokens = 0L,

    #' @field model Model name used for this span (if LLM).
    model = NULL,

    #' @description Create a new span.
    #' @param name Name of the span.
    #' @param type Type of operation. One of "llm", "tool", "guardrail", "custom".
    #' @param parent_id Optional parent span ID.
    #' @param metadata Optional named list of metadata.
    #' @return A new `Span` object.
    initialize = function(name,
                          type = c("llm", "tool", "guardrail", "custom"),
                          parent_id = NULL,
                          metadata = list()) {
      self$name <- name
      self$type <- match.arg(type)
      self$parent_id <- parent_id
      self$metadata <- metadata
      self$span_id <- private$generate_id()
      self$status <- "running"
      self$input_tokens <- 0L
      self$output_tokens <- 0L
      private$.events <- list()
      private$.metrics <- list()
      private$.attributes <- list()
      private$.start_time <- NULL
      private$.end_time <- NULL
      private$.error <- NULL
    },

    #' @description Record the start time.
    start = function() {
      private$.start_time <- Sys.time()
      invisible(self)
    },

    #' @description Record the end time and set status.
    #' @param status Final status. Default "ok".
    end = function(status = "ok") {
      private$.end_time <- Sys.time()
      if (self$status != "error") {
        self$status <- status
      }
      invisible(self)
    },

    #' @description Add an event to this span.
    #' @param event A `securetrace_event` object.
    add_event = function(event) {
      if (!is_trace_event(event)) {
        cli::cli_abort("{.arg event} must be a {.cls securetrace_event} object.")
      }
      private$.events <- c(private$.events, list(event))
      invisible(self)
    },

    #' @description Record token usage.
    #' @param input Number of input tokens.
    #' @param output Number of output tokens.
    set_tokens = function(input = 0L, output = 0L) {
      self$input_tokens <- as.integer(input)
      self$output_tokens <- as.integer(output)
      invisible(self)
    },

    #' @description Record which model was used.
    #' @param model Model name string.
    set_model = function(model) {
      self$model <- model
      invisible(self)
    },

    #' @description Record an error and set status to "error".
    #' @param error The error condition or message string.
    set_error = function(error) {
      private$.error <- conditionMessage_safe(error)
      self$status <- "error"
      invisible(self)
    },

    #' @description Set a span attribute (key-value pair).
    #' @param key Character string attribute name.
    #' @param value Attribute value (scalar or vector).
    set_attribute = function(key, value) {
      if (!is.character(key) || length(key) != 1L) {
        cli::cli_abort("{.arg key} must be a scalar character string.")
      }
      private$.attributes[[key]] <- value
      invisible(self)
    },

    #' @description Get the duration in seconds.
    #' @return Numeric duration, or `NULL` if not started/ended.
    duration = function() {
      if (is.null(private$.start_time) || is.null(private$.end_time)) {
        return(NULL)
      }
      as.numeric(difftime(private$.end_time, private$.start_time, units = "secs"))
    },

    #' @description Record a custom metric.
    #' @param name Metric name.
    #' @param value Metric value.
    #' @param unit Optional unit string.
    add_metric = function(name, value, unit = NULL) {
      metric <- list(name = name, value = value)
      if (!is.null(unit)) metric$unit <- unit
      private$.metrics <- c(private$.metrics, list(metric))
      invisible(self)
    },

    #' @description Serialize the span to a list.
    #' @return A named list representation.
    to_list = function() {
      result <- list(
        span_id = self$span_id,
        name = self$name,
        type = self$type,
        status = self$status,
        parent_id = self$parent_id,
        metadata = self$metadata,
        attributes = private$.attributes,
        start_time = format(private$.start_time, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
        end_time = if (!is.null(private$.end_time)) {
          format(private$.end_time, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
        },
        duration_secs = self$duration(),
        input_tokens = self$input_tokens,
        output_tokens = self$output_tokens,
        model = self$model,
        error = private$.error,
        events = lapply(private$.events, function(e) {
          list(
            name = e@name,
            data = e@data,
            timestamp = format(e@timestamp, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
          )
        }),
        metrics = private$.metrics
      )
      result
    }
  ),

  active = list(
    #' @field events List of events (read-only).
    events = function() {
      private$.events
    }
  ),

  private = list(
    .events = NULL,
    .metrics = NULL,
    .attributes = NULL,
    .start_time = NULL,
    .end_time = NULL,
    .error = NULL,

    generate_id = function() {
      paste(
        sample(c(0:9, letters[1:6]), 16, replace = TRUE),
        collapse = ""
      )
    }
  )
)

#' Extract error message safely
#'
#' @param error An error condition or character string.
#' @return Character string with the error message.
#' @noRd
conditionMessage_safe <- function(error) {
  if (inherits(error, "condition")) {
    conditionMessage(error)
  } else {
    as.character(error)
  }
}
