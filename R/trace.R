#' Trace Class
#'
#' Root container for a full agent run. A trace contains multiple spans
#' representing individual operations like LLM calls, tool executions,
#' and guardrail checks.
#'
#' @examples
#' # Create and use a trace
#' tr <- Trace$new("my-agent-run", metadata = list(user = "test"))
#' tr$start()
#'
#' # Add a span to the trace
#' span <- Span$new("llm-call", type = "llm")
#' span$start()
#' span$set_tokens(input = 100L, output = 50L)
#' span$end()
#' tr$add_span(span)
#'
#' tr$end()
#' tr$status
#' tr$duration()
#' tr$summary()
#'
#' # Serialize to list for export
#' trace_list <- tr$to_list()
#' trace_list$name
#' @export
Trace <- R6::R6Class(
  "Trace",
  public = list(
    #' @field name Name of the trace.
    name = NULL,

    #' @field trace_id Unique identifier for the trace.
    trace_id = NULL,

    #' @field metadata Arbitrary metadata attached to the trace.
    metadata = NULL,

    #' @field status Current status: "running", "completed", or "error".
    status = NULL,

    #' @description Create a new trace.
    #' @param name Name for the trace.
    #' @param metadata Optional named list of metadata.
    #' @return A new `Trace` object.
    initialize = function(name, metadata = list()) {
      self$name <- name
      self$trace_id <- private$generate_id()
      self$metadata <- metadata
      self$status <- "running"
      private$.spans <- list()
      private$.start_time <- NULL
      private$.end_time <- NULL
    },

    #' @description Record the start time.
    start = function() {
      private$.start_time <- Sys.time()
      invisible(self)
    },

    #' @description Record the end time and mark as completed.
    end = function() {
      private$.end_time <- Sys.time()
      if (self$status == "running") {
        self$status <- "completed"
      }
      invisible(self)
    },

    #' @description Add a child span to this trace.
    #' @param span A `Span` object.
    add_span = function(span) {
      private$.spans <- c(private$.spans, list(span))
      invisible(self)
    },

    #' @description Get the total duration in seconds.
    #' @return Numeric duration, or `NULL` if not started/ended.
    duration = function() {
      if (is.null(private$.start_time) || is.null(private$.end_time)) {
        return(NULL)
      }
      as.numeric(difftime(private$.end_time, private$.start_time, units = "secs"))
    },

    #' @description Serialize the trace to a list.
    #' @return A named list representation.
    to_list = function() {
      list(
        trace_id = self$trace_id,
        name = self$name,
        status = self$status,
        metadata = self$metadata,
        start_time = format(private$.start_time, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
        end_time = if (!is.null(private$.end_time)) {
          format(private$.end_time, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
        },
        duration_secs = self$duration(),
        spans = lapply(self$spans, function(s) s$to_list())
      )
    },

    #' @description Print a formatted summary of the trace.
    #' @return The trace summary as a character string, invisibly.
    summary = function() {
      total_input <- 0L
      total_output <- 0L
      total_cost <- 0
      for (s in self$spans) {
        total_input <- total_input + s$input_tokens
        total_output <- total_output + s$output_tokens
        if (!is.null(s$model)) {
          total_cost <- total_cost + calculate_cost(s$model, s$input_tokens, s$output_tokens)
        }
      }
      dur <- self$duration()
      dur_str <- if (is.null(dur)) "N/A" else sprintf("%.2fs", dur)

      lines <- c(
        sprintf("Trace: %s (%s)", self$name, self$status),
        sprintf("  ID: %s", self$trace_id),
        sprintf("  Duration: %s", dur_str),
        sprintf("  Spans: %d", length(self$spans)),
        sprintf("  Tokens: %d input, %d output", total_input, total_output),
        sprintf("  Cost: $%.6f", total_cost)
      )
      msg <- paste(lines, collapse = "\n")
      cli::cli_text(msg)
      invisible(msg)
    }
  ),

  active = list(
    #' @field spans List of child spans (read-only).
    spans = function() {
      private$.spans
    }
  ),

  private = list(
    .spans = NULL,
    .start_time = NULL,
    .end_time = NULL,

    generate_id = function() {
      paste(
        sample(c(0:9, letters[1:6]), 32, replace = TRUE),
        collapse = ""
      )
    }
  )
)
