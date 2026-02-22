#' Trace an orchestr Graph Execution
#'
#' Wraps an orchestr `AgentGraph`'s `$invoke()` call with automatic tracing.
#' Each node execution is captured as a child span named `"node:{name}"`.
#' Requires the orchestr package.
#'
#' @param graph An orchestr `AgentGraph` object.
#' @param input Named list of initial state passed to `graph$invoke()`.
#' @param ... Additional arguments passed to `graph$invoke()`.
#' @param exporter Optional exporter for the trace. If `NULL`, uses the default
#'   exporter (if set via [set_default_exporter()]).
#' @return The graph result (final state as a named list).
#' @examples
#' \dontrun{
#' # Requires orchestr package
#' gb <- orchestr::graph_builder()
#' gb$add_node("step", function(state, config) list(x = state$x + 1))
#' gb$add_edge("step", orchestr::END)
#' gb$set_entry_point("step")
#' graph <- gb$compile()
#'
#' result <- trace_graph(graph, list(x = 1))
#' }
#' @export
trace_graph <- function(graph, input, ..., exporter = NULL) {
  if (!requireNamespace("orchestr", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg orchestr} is required for {.fn trace_graph}.")
  }
  if (!inherits(graph, "AgentGraph")) {
    cli::cli_abort("{.arg graph} must be an orchestr {.cls AgentGraph} object.")
  }

  # Derive a name from the graph's node list

  graph_nodes <- graph$get_nodes()
  graph_label <- paste(graph_nodes, collapse = ",")
  trace_name <- paste0("graph:", graph_label)

  with_trace(trace_name, {
    tr <- current_trace()
    result <- graph$invoke(state = input, ..., trace = tr)
    result
  }, exporter = exporter)
}


#' Trace an orchestr Agent Invocation
#'
#' Wraps an orchestr `Agent`'s `$invoke()` call with automatic tracing.
#' Creates a span for the agent invocation and auto-extracts model and token
#' information from the underlying chat object when available.
#' Requires the orchestr package.
#'
#' @param agent An orchestr `Agent` object.
#' @param prompt Character string prompt to send to the agent.
#' @param ... Additional arguments passed to `agent$invoke()`.
#' @param exporter Optional exporter for the trace. If `NULL`, uses the default
#'   exporter (if set via [set_default_exporter()]).
#' @return The agent's text response.
#' @examples
#' \dontrun{
#' # Requires orchestr and ellmer packages
#' chat <- ellmer::chat_openai(model = "gpt-4o")
#' ag <- orchestr::agent("assistant", chat)
#' response <- trace_agent(ag, "What is 2 + 2?")
#' }
#' @export
trace_agent <- function(agent, prompt, ..., exporter = NULL) {
  if (!requireNamespace("orchestr", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg orchestr} is required for {.fn trace_agent}.")
  }
  if (!inherits(agent, "Agent")) {
    cli::cli_abort("{.arg agent} must be an orchestr {.cls Agent} object.")
  }

  agent_name <- agent$name
  trace_name <- paste0("agent:", agent_name)

  # Capture token state before the call for delta computation
  chat <- agent$get_chat()
  tokens_before <- tryCatch(
    {
      if ("get_tokens" %in% names(chat)) chat$get_tokens() else NULL
    },
    error = function(e) NULL
  )

  with_trace(trace_name, {
    with_span("invoke", type = "custom", {
      start_time <- Sys.time()
      result <- agent$invoke(prompt, ...)
      end_time <- Sys.time()

      span <- current_span()
      if (!is.null(span)) {
        record_latency(as.numeric(difftime(end_time, start_time, units = "secs")))

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

        # Auto-extract token usage (delta from before/after)
        tryCatch(
          {
            if ("get_tokens" %in% names(chat)) {
              tokens_after <- chat$get_tokens()
              if (!is.null(tokens_after) && nrow(tokens_after) > 0) {
                if (is.null(tokens_before) || nrow(tokens_before) == 0) {
                  delta_input <- sum(tokens_after$input, na.rm = TRUE)
                  delta_output <- sum(tokens_after$output, na.rm = TRUE)
                } else {
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
      }

      result
    })
  }, exporter = exporter)
}
