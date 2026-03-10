# Helper functions for securetrace tests

# Reset trace context between tests
reset_context <- function() {
  .trace_context <- securetrace:::.trace_context
  .trace_context$trace_stack <- list()
  .trace_context$span_stack <- list()
  .trace_context$default_exporter <- NULL
  .trace_context$default_sampler <- NULL
  .trace_context$default_resource <- NULL
}

# Reset cost registry to defaults
reset_costs <- function() {
  securetrace:::.init_default_costs()
}
