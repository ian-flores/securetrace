#' Model Cost Registry
#'
#' Module-level environment storing per-model pricing.
#' @noRd
.cost_registry <- new.env(parent = emptyenv())

# Initialize default costs (per 1M tokens)
.cost_registry$models <- list(
  "claude-opus-4-6"   = list(input = 15,    output = 75),
  "claude-sonnet-4-5" = list(input = 3,     output = 15),
  "claude-haiku-4-5"  = list(input = 0.80,  output = 4),
  "gpt-4o"            = list(input = 2.50,  output = 10),
  "gpt-4o-mini"       = list(input = 0.15,  output = 0.60)
)

#' Get Known Model Costs
#'
#' Returns a named list of model pricing (per 1M tokens).
#'
#' @return A named list where each element has `input` and `output` prices.
#' @examples
#' costs <- model_costs()
#' names(costs)
#' costs[["gpt-4o"]]
#' @export
model_costs <- function() {
  .cost_registry$models
}

#' Calculate Cost for a Model Call
#'
#' @param model Model name string.
#' @param input_tokens Number of input tokens.
#' @param output_tokens Number of output tokens.
#' @return Numeric cost in USD.
#' @examples
#' # Calculate cost for a GPT-4o call
#' calculate_cost("gpt-4o", input_tokens = 1000, output_tokens = 500)
#'
#' # Unknown models return 0
#' calculate_cost("unknown-model", 1000, 500)
#' @export
calculate_cost <- function(model, input_tokens, output_tokens) {
  costs <- .cost_registry$models
  if (!model %in% names(costs)) {
    return(0)
  }
  pricing <- costs[[model]]
  (input_tokens / 1e6) * pricing$input + (output_tokens / 1e6) * pricing$output
}

#' Add or Update Model Pricing
#'
#' Register custom model pricing (per 1M tokens).
#'
#' @param model Model name string.
#' @param input_price Price per 1M input tokens in USD.
#' @param output_price Price per 1M output tokens in USD.
#' @return Invisible `NULL`.
#' @examples
#' # Register a custom model's pricing
#' add_model_cost("my-local-model", input_price = 0, output_price = 0)
#' calculate_cost("my-local-model", 1000, 500)
#' @export
add_model_cost <- function(model, input_price, output_price) {
  .cost_registry$models[[model]] <- list(input = input_price, output = output_price)
  invisible(NULL)
}

#' Calculate Total Cost for a Trace
#'
#' Sums the cost of all spans in a trace that have a model recorded.
#'
#' @param trace A `Trace` object.
#' @return Numeric total cost in USD.
#' @examples
#' tr <- Trace$new("cost-demo")
#' tr$start()
#'
#' s1 <- Span$new("call1", type = "llm")
#' s1$set_model("gpt-4o")
#' s1$set_tokens(input = 1000L, output = 500L)
#' tr$add_span(s1)
#'
#' s2 <- Span$new("call2", type = "llm")
#' s2$set_model("gpt-4o-mini")
#' s2$set_tokens(input = 2000L, output = 1000L)
#' tr$add_span(s2)
#'
#' tr$end()
#' trace_total_cost(tr)
#' @export
trace_total_cost <- function(trace) {
  total <- 0
  for (s in trace$spans) {
    if (!is.null(s$model)) {
      total <- total + calculate_cost(s$model, s$input_tokens, s$output_tokens)
    }
  }
  total
}
