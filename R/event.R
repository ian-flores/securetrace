#' Create a Trace Event
#'
#' Discrete point-in-time event within a span.
#'
#' @param name Name of the event.
#' @param data Optional named list of event data.
#' @param timestamp Timestamp for the event. Defaults to current time.
#' @return An S3 object of class `securetrace_event`.
#' @export
trace_event <- function(name, data = list(), timestamp = Sys.time()) {
  structure(
    list(
      name = name,
      data = data,
      timestamp = timestamp
    ),
    class = "securetrace_event"
  )
}

#' Test if an Object is a Trace Event
#'
#' @param x Object to test.
#' @return Logical scalar.
#' @export
is_trace_event <- function(x) {
  inherits(x, "securetrace_event")
}

#' @export
print.securetrace_event <- function(x, ...) {
  cat(sprintf("Event: %s at %s\n", x$name, format(x$timestamp)))
  if (length(x$data) > 0) {
    cat(sprintf("  Data: %s\n", paste(names(x$data), collapse = ", ")))
  }
  invisible(x)
}
