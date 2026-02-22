#' Trace Event Class (S7)
#'
#' Discrete point-in-time event within a span.
#'
#' @param name Character string naming the event.
#' @param data Arbitrary data associated with the event.
#' @param timestamp Timestamp for the event (POSIXct).
#'
#' @examples
#' # Create an event directly
#' evt <- securetrace_event(
#'   name = "model_selected",
#'   data = list(model = "gpt-4o"),
#'   timestamp = Sys.time()
#' )
#' evt@name
#' evt@data
#' @export
securetrace_event <- new_class("securetrace_event", properties = list(
  name = class_character,
  data = class_any,
  timestamp = class_any
))

#' Create a Trace Event
#'
#' Factory function for creating trace events.
#'
#' @param name Name of the event.
#' @param data Optional named list of event data.
#' @param timestamp Timestamp for the event. Defaults to current time.
#' @return An S7 object of class `securetrace_event`.
#' @examples
#' evt <- trace_event("response_received", data = list(tokens = 150L))
#' evt@name
#' evt@data$tokens
#' @export
trace_event <- function(name, data = list(), timestamp = Sys.time()) {
  securetrace_event(name = name, data = data, timestamp = timestamp)
}

#' Test if an Object is a Trace Event
#'
#' @param x Object to test.
#' @return Logical scalar.
#' @examples
#' evt <- trace_event("test_event")
#' is_trace_event(evt)
#' is_trace_event("not an event")
#' @export
is_trace_event <- function(x) {
  S7_inherits(x, securetrace_event)
}

method(print, securetrace_event) <- function(x, ...) {
  cat(sprintf("Event: %s at %s\n", x@name, format(x@timestamp)))
  if (length(x@data) > 0) {
    cat(sprintf("  Data: %s\n", paste(names(x@data), collapse = ", ")))
  }
  invisible(x)
}
