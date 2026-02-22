#' Generate a W3C Traceparent Header
#'
#' Creates a W3C Trace Context `traceparent` header string from trace and
#' span identifiers. The format follows the
#' [W3C Trace Context specification](https://www.w3.org/TR/trace-context/).
#'
#' @param trace_id Character. A 32 lowercase hex character trace identifier.
#' @param span_id Character. A 16 lowercase hex character span identifier.
#' @param sampled Logical. Whether the trace is sampled. `TRUE` sets flags to
#'   `"01"`, `FALSE` sets flags to `"00"`. Default `TRUE`.
#' @return A character string in the format
#'   `"00-{trace_id}-{span_id}-{flags}"`.
#'
#' @examples
#' traceparent(
#'   "4bf92f3577b34da6a3ce929d0e0e4736",
#'   "00f067aa0ba902b7"
#' )
#'
#' traceparent(
#'   "4bf92f3577b34da6a3ce929d0e0e4736",
#'   "00f067aa0ba902b7",
#'   sampled = FALSE
#' )
#' @export
traceparent <- function(trace_id, span_id, sampled = TRUE) {
  if (!is.character(trace_id) || length(trace_id) != 1 ||
      !grepl("^[0-9a-f]{32}$", trace_id)) {
    cli::cli_abort(
      "{.arg trace_id} must be a 32 lowercase hex character string."
    )
  }
  if (trace_id == strrep("0", 32)) {
    cli::cli_abort("{.arg trace_id} must not be all zeros.")
  }

  if (!is.character(span_id) || length(span_id) != 1 ||
      !grepl("^[0-9a-f]{16}$", span_id)) {
    cli::cli_abort(
      "{.arg span_id} must be a 16 lowercase hex character string."
    )
  }
  if (span_id == strrep("0", 16)) {
    cli::cli_abort("{.arg span_id} must not be all zeros.")
  }

  flags <- if (isTRUE(sampled)) "01" else "00"
  sprintf("00-%s-%s-%s", trace_id, span_id, flags)
}

#' Parse a W3C Traceparent Header
#'
#' Parses a `traceparent` header string into its component fields according
#' to the W3C Trace Context specification.
#'
#' @param header Character. A traceparent header string.
#' @return A named list with elements `version`, `trace_id`, `span_id`, and
#'   `sampled` (logical), or `NULL` if the header is invalid.
#'
#' @examples
#' parsed <- parse_traceparent(
#'   "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
#' )
#' parsed$trace_id
#' parsed$sampled
#'
#' # Invalid header returns NULL
#' parse_traceparent("invalid")
#' @export
parse_traceparent <- function(header) {
  if (!is.character(header) || length(header) != 1) {
    cli::cli_warn("Invalid {.arg header}: must be a single character string.")
    return(NULL)
  }

  pattern <- "^([0-9a-f]{2})-([0-9a-f]{32})-([0-9a-f]{16})-([0-9a-f]{2})$"
  if (!grepl(pattern, header)) {
    cli::cli_warn(
      "Invalid traceparent header format: {.val {header}}"
    )
    return(NULL)
  }

  parts <- regmatches(header, regexec(pattern, header))[[1]]
  version <- parts[2]
  trace_id <- parts[3]
  span_id <- parts[4]
  flags <- parts[5]

  if (trace_id == strrep("0", 32) || span_id == strrep("0", 16)) {
    cli::cli_warn(
      "Invalid traceparent: trace_id and span_id must not be all zeros."
    )
    return(NULL)
  }

  list(
    version = version,
    trace_id = trace_id,
    span_id = span_id,
    sampled = flags == "01"
  )
}

#' Inject Trace Context into HTTP Headers
#'
#' Adds a `traceparent` header to an existing set of HTTP headers using
#' the current active trace and span context.
#'
#' @param headers A named list of HTTP headers. Default `list()`.
#' @return The headers list with `traceparent` added, or unchanged if no
#'   active trace/span context exists.
#'
#' @examples
#' # Inside an active trace and span
#' with_trace("http-call", {
#'   with_span("request", type = "tool", {
#'     headers <- inject_headers(list("Content-Type" = "application/json"))
#'     headers$traceparent
#'   })
#' })
#' @export
inject_headers <- function(headers = list()) {
  span <- current_span()
  trace <- current_trace()

  if (is.null(span) || is.null(trace)) {
    cli::cli_warn(
      "No active trace/span context. Headers returned unchanged."
    )
    return(headers)
  }

  headers$traceparent <- traceparent(trace$trace_id, span$span_id)
  headers
}

#' Extract Trace Context from HTTP Headers
#'
#' Looks for a `traceparent` header (case-insensitive) in a named list of
#' HTTP headers and parses it.
#'
#' @param headers A named list of HTTP headers.
#' @return A parsed trace context (named list with `version`, `trace_id`,
#'   `span_id`, `sampled`), or `NULL` if no valid traceparent is found.
#'
#' @examples
#' headers <- list(
#'   "Content-Type" = "application/json",
#'   traceparent = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
#' )
#' ctx <- extract_trace_context(headers)
#' ctx$trace_id
#' @export
extract_trace_context <- function(headers) {
  if (!is.list(headers) || length(headers) == 0) {
    return(NULL)
  }

  names_lower <- tolower(names(headers))
  idx <- which(names_lower == "traceparent")

  if (length(idx) == 0) {
    return(NULL)
  }

  parse_traceparent(headers[[idx[1]]])
}
