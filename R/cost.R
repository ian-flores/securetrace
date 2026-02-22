#' Model Cost Registry
#'
#' Module-level environment storing per-model pricing and alias resolution.
#' @noRd
.cost_registry <- new.env(parent = emptyenv())

#' Initialize Default Model Costs and Aliases
#'
#' Sets up the default model pricing registry and alias mappings.
#' Called at package load and can be called from test helpers to reset state.
#' @noRd
.init_default_costs <- function() {
  # Model pricing (per 1M tokens)
  .cost_registry$models <- list(
    # Anthropic -- current generation
    "claude-opus-4-6"              = list(input = 15,     output = 75),
    "claude-sonnet-4-5"            = list(input = 3,      output = 15),
    "claude-haiku-4-5"             = list(input = 0.80,   output = 4),
    # Anthropic -- dated IDs
    "claude-3-5-sonnet-20241022"   = list(input = 3,      output = 15),
    "claude-3-5-haiku-20241022"    = list(input = 0.80,   output = 4),
    "claude-3-opus-20240229"       = list(input = 15,     output = 75),
    "claude-3-sonnet-20240229"     = list(input = 3,      output = 15),
    "claude-3-haiku-20240307"      = list(input = 0.25,   output = 1.25),
    # OpenAI
    "gpt-4o"                       = list(input = 2.50,   output = 10),
    "gpt-4o-mini"                  = list(input = 0.15,   output = 0.60),
    "gpt-4o-2024-11-20"            = list(input = 2.50,   output = 10),
    "gpt-4-turbo"                  = list(input = 10,     output = 30),
    "gpt-4"                        = list(input = 30,     output = 60),
    "gpt-3.5-turbo"                = list(input = 0.50,   output = 1.50),
    "o1"                           = list(input = 15,     output = 60),
    "o1-mini"                      = list(input = 3,      output = 12),
    "o3-mini"                      = list(input = 1.10,   output = 4.40),
    # Google Gemini
    "gemini-2.0-flash"             = list(input = 0.10,   output = 0.40),
    "gemini-1.5-pro"               = list(input = 1.25,   output = 5),
    "gemini-1.5-flash"             = list(input = 0.075,  output = 0.30),
    "gemini-1.5-flash-8b"          = list(input = 0.0375, output = 0.15),
    # Mistral
    "mistral-large-latest"         = list(input = 2,      output = 6),
    "mistral-small-latest"         = list(input = 0.20,   output = 0.60),
    "codestral-latest"             = list(input = 0.30,   output = 0.90),
    # DeepSeek
    "deepseek-chat"                = list(input = 0.27,   output = 1.10),
    "deepseek-reasoner"            = list(input = 0.55,   output = 2.19)
  )

  .init_default_aliases()
}

#' Initialize Default Model Aliases
#'
#' Sets up alias mappings from cloud provider model IDs to canonical names.
#' @noRd
.init_default_aliases <- function() {
  .cost_registry$aliases <- list(
    # AWS Bedrock -- Anthropic
    "anthropic.claude-3-5-sonnet-20241022-v2:0" = "claude-3-5-sonnet-20241022",
    "anthropic.claude-3-5-haiku-20241022-v1:0"  = "claude-3-5-haiku-20241022",
    "anthropic.claude-3-opus-20240229-v1:0"     = "claude-3-opus-20240229",
    "anthropic.claude-3-sonnet-20240229-v1:0"   = "claude-3-sonnet-20240229",
    "anthropic.claude-3-haiku-20240307-v1:0"    = "claude-3-haiku-20240307",
    # Google Vertex AI -- Anthropic
    "publishers/anthropic/models/claude-3-5-sonnet-v2@20241022" = "claude-3-5-sonnet-20241022",
    "publishers/anthropic/models/claude-3-5-haiku@20241022"     = "claude-3-5-haiku-20241022",
    "publishers/anthropic/models/claude-3-opus@20240229"        = "claude-3-opus-20240229",
    "publishers/anthropic/models/claude-3-sonnet@20240229"      = "claude-3-sonnet-20240229",
    "publishers/anthropic/models/claude-3-haiku@20240307"       = "claude-3-haiku-20240307"
  )
}

# Initialize at package load
.init_default_costs()

#' Resolve a Model Name
#'
#' Maps cloud provider model IDs (e.g., AWS Bedrock, Google Vertex AI) to
#' canonical model names used in the cost registry. Also passes through
#' names that are already canonical or unknown.
#'
#' Resolution order:
#' 1. Check the alias registry for an exact match
#' 2. Check if already a canonical model name
#' 3. Try regex normalization for Bedrock pattern (`provider.model-version:N`)
#' 4. Try regex normalization for Vertex pattern (`publishers/.../models/model@date`)
#' 5. Fall back to returning the original string unchanged
#'
#' @param model A model name or provider-specific model ID string.
#' @return The canonical model name string.
#' @examples
#' # Already canonical -- returned as-is
#' resolve_model("gpt-4o")
#'
#' # Bedrock alias
#' resolve_model("anthropic.claude-3-sonnet-20240229-v1:0")
#'
#' # Unknown model -- returned as-is
#' resolve_model("my-custom-model")
#' @export
resolve_model <- function(model) {
  # 1. Check alias registry for exact match
  aliases <- .cost_registry$aliases
  if (!is.null(aliases) && model %in% names(aliases)) {
    return(aliases[[model]])
  }

  # 2. Check if already a canonical model name
  if (model %in% names(.cost_registry$models)) {
    return(model)
  }

  # 3. Try regex for Bedrock pattern: provider.model-name-version:N

  #    e.g., "anthropic.claude-3-sonnet-20240229-v1:0" -> "claude-3-sonnet-20240229"
  bedrock_match <- regmatches(
    model,
    regexec("^[a-z]+\\.(.+)-v[0-9]+:[0-9]+$", model)
  )
  if (length(bedrock_match[[1]]) > 1) {
    candidate <- bedrock_match[[1]][2]
    if (candidate %in% names(.cost_registry$models)) {
      return(candidate)
    }
  }

  # 4. Try regex for Vertex pattern: publishers/.../models/model@date
  #    e.g., "publishers/anthropic/models/claude-3-5-sonnet-v2@20241022"
  vertex_match <- regmatches(
    model,
    regexec("^publishers/[^/]+/models/(.+)@([0-9]+)$", model)
  )
  if (length(vertex_match[[1]]) > 1) {
    base_name <- vertex_match[[1]][2]
    date_part <- vertex_match[[1]][3]
    # Strip version suffixes like "-v2" from the base name
    base_clean <- sub("-v[0-9]+$", "", base_name)
    candidate <- paste0(base_clean, "-", date_part)
    if (candidate %in% names(.cost_registry$models)) {
      return(candidate)
    }
  }

  # 5. Fall back to original string
  model
}

#' Add a Model Alias
#'
#' Register a custom alias mapping from a provider-specific model ID to a
#' canonical model name. This is useful for cloud provider variants or
#' custom deployment names.
#'
#' @param alias The provider-specific model ID string (e.g., a Bedrock or
#'   Vertex AI model ID, or a custom deployment name).
#' @param canonical The canonical model name that `alias` should resolve to.
#'   This should match a name in the cost registry.
#' @return Invisible `NULL`.
#' @examples
#' # Map a custom deployment to a known model
#' add_model_alias("my-azure-gpt4o-deployment", "gpt-4o")
#' resolve_model("my-azure-gpt4o-deployment")
#' @export
add_model_alias <- function(alias, canonical) {
  if (is.null(.cost_registry$aliases)) {
    .cost_registry$aliases <- list()
  }
  .cost_registry$aliases[[alias]] <- canonical
  invisible(NULL)
}

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
  model <- resolve_model(model)
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
