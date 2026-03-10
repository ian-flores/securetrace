#' Resource Attributes
#'
#' Resource attributes describe the entity producing telemetry data --
#' typically the service name, version, and deployment environment.
#' Once set, resource attributes are attached to all exported traces.
#'
#' @name resource
NULL

#' Create a Resource
#'
#' @param service_name Name of the service producing traces.
#' @param service_version Optional version string.
#' @param deployment_environment Optional environment name (e.g. "production",
#'   "staging").
#' @param ... Additional key-value attributes.
#' @return A named list of class `securetrace_resource`.
#' @examples
#' res <- resource("my-agent", service_version = "1.0.0",
#'                 deployment_environment = "production")
#' res$service.name
#' @export
resource <- function(service_name,
                     service_version = NULL,
                     deployment_environment = NULL,
                     ...) {
  attrs <- list(service.name = service_name)
  if (!is.null(service_version)) {
    attrs[["service.version"]] <- service_version
  }
  if (!is.null(deployment_environment)) {
    attrs[["deployment.environment"]] <- deployment_environment
  }
  extra <- list(...)
  attrs <- c(attrs, extra)
  structure(attrs, class = "securetrace_resource")
}

#' Set the Default Resource
#'
#' Sets resource attributes that will be attached to all traces created
#' via [with_trace()].
#'
#' @param res A `securetrace_resource` object from [resource()].
#' @return Invisible `NULL`.
#' @examples
#' set_resource(resource("my-agent", service_version = "1.0.0"))
#'
#' # Traces now include resource attributes
#' with_trace("test", {
#'   tr <- current_trace()
#'   tr$resource
#' })
#' @export
set_resource <- function(res) {
  if (!inherits(res, "securetrace_resource")) {
    cli::cli_abort("{.arg res} must be a {.cls securetrace_resource} object.")
  }
  .trace_context$default_resource <- res
  invisible(NULL)
}

#' Get the Current Resource
#'
#' @return The current `securetrace_resource`, or `NULL` if none set.
#' @export
current_resource <- function() {
  .trace_context$default_resource
}
