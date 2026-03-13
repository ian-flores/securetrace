#' Trace Sampling
#'
#' Samplers control which traces are recorded, allowing production systems
#' to reduce overhead by only recording a fraction of traces.
#'
#' @name sampling
NULL

#' S7 class: securetrace_sampler
#'
#' @param should_sample A function taking `name` and `metadata` arguments,
#'   returning `TRUE` to record or `FALSE` to drop the trace.
#' @return An S7 object of class `securetrace_sampler`.
#' @export
securetrace_sampler <- new_class("securetrace_sampler", properties = list(
  should_sample = class_function
))

method(print, securetrace_sampler) <- function(x, ...) {
  # Try to infer the sampler strategy from the function environment
  fn_env <- environment(x@should_sample)
  strategy <- "custom"
  if (is.null(fn_env)) {
    # Inline function; check if it always returns TRUE or FALSE
    test_val <- tryCatch(x@should_sample("__test__", list()), error = function(e) NULL)
    if (isTRUE(test_val)) strategy <- "always_on"
    else if (isFALSE(test_val)) strategy <- "always_off"
  } else {
    if (exists("rate", envir = fn_env, inherits = FALSE)) {
      strategy <- sprintf("probability (rate = %s)", fn_env$rate)
    } else if (exists("max_per_second", envir = fn_env, inherits = FALSE)) {
      strategy <- sprintf("rate_limiting (max = %s/s)", fn_env$max_per_second)
    }
  }
  cat(sprintf("<securetrace_sampler> strategy: %s\n", strategy))
  invisible(x)
}

#' Always-On Sampler
#'
#' Records every trace. This is the default.
#'
#' @return A `securetrace_sampler` that always returns `TRUE`.
#' @examples
#' s <- sampler_always_on()
#' s@should_sample("test", list())
#' @export
sampler_always_on <- function() {
  securetrace_sampler(should_sample = function(name, metadata) TRUE)
}

#' Always-Off Sampler
#'
#' Drops every trace. Useful for disabling tracing entirely.
#'
#' @return A `securetrace_sampler` that always returns `FALSE`.
#' @examples
#' s <- sampler_always_off()
#' s@should_sample("test", list())
#' @export
sampler_always_off <- function() {
  securetrace_sampler(should_sample = function(name, metadata) FALSE)
}

#' Probability Sampler
#'
#' Records traces with a given probability.
#'
#' @param rate Sampling rate between 0 and 1. Default 1.0 (all traces).
#' @return A `securetrace_sampler`.
#' @examples
#' # Record 10% of traces
#' s <- sampler_probability(0.1)
#' @export
sampler_probability <- function(rate = 1.0) {
  if (!is.numeric(rate) || length(rate) != 1 || rate < 0 || rate > 1) {
    cli::cli_abort("{.arg rate} must be a single number between 0 and 1, not {.val {rate}}.")
  }
  securetrace_sampler(should_sample = function(name, metadata) {
    stats::runif(1) < rate
  })
}

#' Rate-Limiting Sampler
#'
#' Records at most N traces per second.
#'
#' @param max_per_second Maximum traces per second. Default 10.
#' @return A `securetrace_sampler`.
#' @examples
#' s <- sampler_rate_limiting(5)
#' @export
sampler_rate_limiting <- function(max_per_second = 10) {
  if (!is.numeric(max_per_second) || length(max_per_second) != 1 || max_per_second <= 0) {
    cli::cli_abort("{.arg max_per_second} must be a single positive number, not {.val {max_per_second}}.")
  }
  state <- new.env(parent = emptyenv())
  state$count <- 0L
  state$window_start <- Sys.time()

  securetrace_sampler(should_sample = function(name, metadata) {
    now <- Sys.time()
    elapsed <- as.numeric(difftime(now, state$window_start, units = "secs"))
    if (elapsed >= 1.0) {
      state$count <- 0L
      state$window_start <- now
    }
    if (state$count >= max_per_second) {
      return(FALSE)
    }
    state$count <- state$count + 1L
    TRUE
  })
}

#' Set the Default Sampler
#'
#' @param sampler A `securetrace_sampler` object.
#' @return Invisible `NULL`.
#' @examples
#' # Only record 50% of traces
#' set_default_sampler(sampler_probability(0.5))
#'
#' # Reset to record everything
#' set_default_sampler(sampler_always_on())
#' @export
set_default_sampler <- function(sampler) {
  if (!S7_inherits(sampler, securetrace_sampler)) {
    cli::cli_abort("{.arg sampler} must be a {.cls securetrace_sampler} object.")
  }
  .trace_context$default_sampler <- sampler
  invisible(NULL)
}
