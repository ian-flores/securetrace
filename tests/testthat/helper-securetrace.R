# Helper functions for securetrace tests

# Reset trace context between tests
reset_context <- function() {
  .trace_context <- securetrace:::.trace_context
  .trace_context$trace_stack <- list()
  .trace_context$span_stack <- list()
  .trace_context$default_exporter <- NULL
}

# Reset cost registry to defaults
reset_costs <- function() {
  reg <- securetrace:::.cost_registry
  reg$models <- list(
    "claude-opus-4-6"   = list(input = 15,    output = 75),
    "claude-sonnet-4-5" = list(input = 3,     output = 15),
    "claude-haiku-4-5"  = list(input = 0.80,  output = 4),
    "gpt-4o"            = list(input = 2.50,  output = 10),
    "gpt-4o-mini"       = list(input = 0.15,  output = 0.60)
  )
}
