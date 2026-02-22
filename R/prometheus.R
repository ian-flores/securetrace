#' Prometheus Metrics for securetrace
#'
#' Collect and expose Prometheus-format metrics from securetrace traces.
#' Provides counters for spans, tokens, cost, and traces, plus histograms
#' for span durations.
#'
#' @name prometheus
NULL

# -- Internal helpers ----------------------------------------------------------

#' Increment a counter in the registry
#' @noRd
registry_increment <- function(registry, metric_name, labels, value = 1) {
  if (is.null(registry$counters[[metric_name]])) {
    registry$counters[[metric_name]] <- list()
  }
  key <- labels
  current <- registry$counters[[metric_name]][[key]]
  if (is.null(current)) current <- 0

  registry$counters[[metric_name]][[key]] <- current + value
}

#' Record a histogram observation in the registry
#' @noRd
registry_observe <- function(registry, metric_name, labels, value) {
  if (is.null(registry$histograms[[metric_name]])) {
    registry$histograms[[metric_name]] <- list()
  }
  key <- labels
  entry <- registry$histograms[[metric_name]][[key]]
  if (is.null(entry)) {
    buckets <- c(0.01, 0.05, 0.1, 0.5, 1, 5, 10, 30, 60, 120, 300)
    entry <- list(
      buckets = buckets,
      counts = integer(length(buckets) + 1L), # +1 for +Inf
      sum = 0,
      count = 0L
    )
  }
  # Update bucket counts (cumulative)
  for (i in seq_along(entry$buckets)) {
    if (value <= entry$buckets[i]) {
      entry$counts[i] <- entry$counts[i] + 1L
    }
  }
  # +Inf bucket always gets incremented

  entry$counts[length(entry$counts)] <- entry$counts[length(entry$counts)] + 1L
  entry$sum <- entry$sum + value
  entry$count <- entry$count + 1L
  registry$histograms[[metric_name]][[key]] <- entry
}

# -- Public API ----------------------------------------------------------------

#' Create a Prometheus Metrics Registry
#'
#' Creates a new registry environment for holding counters and histograms
#' collected from securetrace traces.
#'
#' @return An environment of class `securetrace_prometheus_registry` with
#'   `$counters` and `$histograms` lists.
#' @examples
#' reg <- prometheus_registry()
#' reg$counters
#' reg$histograms
#' @export
prometheus_registry <- function() {
  reg <- new.env(parent = emptyenv())
  reg$counters <- list()
  reg$histograms <- list()
  class(reg) <- "securetrace_prometheus_registry"
  reg
}

#' Extract Prometheus Metrics from a Trace
#'
#' Walks a completed trace and increments counters / records histogram
#' observations in the given registry.
#'
#' @param trace A `Trace` R6 object.
#' @param registry A `securetrace_prometheus_registry`, or `NULL` to create one.
#' @return The registry (invisibly).
#' @examples
#' tr <- Trace$new("demo")
#' tr$start()
#' s <- Span$new("step", type = "llm")
#' s$start()
#' s$set_model("gpt-4o")
#' s$set_tokens(input = 100L, output = 50L)
#' s$end()
#' tr$add_span(s)
#' tr$end()
#'
#' reg <- prometheus_metrics(tr)
#' format_prometheus(reg)
#' @export
prometheus_metrics <- function(trace, registry = NULL) {
  if (is.null(registry)) {
    registry <- prometheus_registry()
  }

  trace_list <- trace$to_list()

  # Trace-level counter
  trace_status <- trace_list$status %||% "unknown"
  registry_increment(registry, "securetrace_traces_total",
                     sprintf('status="%s"', trace_status))

  # Span-level metrics
  for (span in trace_list$spans) {
    span_type <- span$type %||% "custom"
    span_status <- span$status %||% "unknown"

    # spans_total counter
    registry_increment(registry, "securetrace_spans_total",
                       sprintf('type="%s",status="%s"', span_type, span_status))

    # span duration histogram
    duration <- span$duration_secs
    if (!is.null(duration) && is.numeric(duration)) {
      registry_observe(registry, "securetrace_span_duration_seconds",
                       sprintf('type="%s"', span_type), duration)
    }

    # Token counters
    input_tok <- span$input_tokens
    output_tok <- span$output_tokens
    model_name <- span$model %||% "unknown"

    if (!is.null(input_tok) && input_tok > 0) {
      registry_increment(registry, "securetrace_tokens_total",
                         sprintf('direction="input",model="%s"', model_name),
                         input_tok)
    }
    if (!is.null(output_tok) && output_tok > 0) {
      registry_increment(registry, "securetrace_tokens_total",
                         sprintf('direction="output",model="%s"', model_name),
                         output_tok)
    }

    # Cost counter
    if (!is.null(span$model)) {
      cost <- calculate_cost(span$model, input_tok %||% 0L, output_tok %||% 0L)
      if (cost > 0) {
        registry_increment(registry, "securetrace_cost_total",
                           sprintf('model="%s"', span$model), cost)
      }
    }
  }

  invisible(registry)
}

#' Prometheus Exporter
#'
#' Returns a `securetrace_exporter` S7 object that feeds traces into a
#' Prometheus registry on each export call.
#'
#' @param registry A `securetrace_prometheus_registry`, or `NULL` to create one.
#' @return An S7 `securetrace_exporter` object. The registry is accessible
#'   via the exporter's closure environment.
#' @examples
#' exp <- prometheus_exporter()
#' tr <- Trace$new("demo")
#' tr$start()
#' tr$end()
#' export_trace(exp, tr)
#' @export
prometheus_exporter <- function(registry = NULL) {
  if (is.null(registry)) {
    registry <- prometheus_registry()
  }
  new_exporter(function(trace_list) {
    # Reconstruct a minimal Trace-like call:
    # export_fn receives trace_list (already serialized), but
    # prometheus_metrics() expects a Trace R6 object.
    # Instead, we work directly with the trace_list here.
    trace_status <- trace_list$status %||% "unknown"
    registry_increment(registry, "securetrace_traces_total",
                       sprintf('status="%s"', trace_status))

    for (span in trace_list$spans) {
      span_type <- span$type %||% "custom"
      span_status <- span$status %||% "unknown"

      registry_increment(registry, "securetrace_spans_total",
                         sprintf('type="%s",status="%s"', span_type, span_status))

      duration <- span$duration_secs
      if (!is.null(duration) && is.numeric(duration)) {
        registry_observe(registry, "securetrace_span_duration_seconds",
                         sprintf('type="%s"', span_type), duration)
      }

      input_tok <- span$input_tokens
      output_tok <- span$output_tokens
      model_name <- span$model %||% "unknown"

      if (!is.null(input_tok) && input_tok > 0) {
        registry_increment(registry, "securetrace_tokens_total",
                           sprintf('direction="input",model="%s"', model_name),
                           input_tok)
      }
      if (!is.null(output_tok) && output_tok > 0) {
        registry_increment(registry, "securetrace_tokens_total",
                           sprintf('direction="output",model="%s"', model_name),
                           output_tok)
      }

      if (!is.null(span$model)) {
        cost <- calculate_cost(span$model, input_tok %||% 0L, output_tok %||% 0L)
        if (cost > 0) {
          registry_increment(registry, "securetrace_cost_total",
                             sprintf('model="%s"', span$model), cost)
        }
      }
    }
  })
}

#' Format Prometheus Text Exposition
#'
#' Renders a registry into the Prometheus text exposition format string.
#' This is a pure function with no network side-effects.
#'
#' @param registry A `securetrace_prometheus_registry`.
#' @return A single character string in Prometheus exposition format.
#' @examples
#' reg <- prometheus_registry()
#' tr <- Trace$new("demo")
#' tr$start()
#' s <- Span$new("step", type = "llm")
#' s$start()
#' s$end()
#' tr$add_span(s)
#' tr$end()
#' prometheus_metrics(tr, reg)
#' cat(format_prometheus(reg))
#' @export
format_prometheus <- function(registry) {
  lines <- character(0)

  # Counter help/type metadata
  counter_meta <- list(
    securetrace_spans_total = "Total spans by type and status",
    securetrace_tokens_total = "Total tokens by direction and model",
    securetrace_cost_total = "Total cost by model in USD",
    securetrace_traces_total = "Total traces by status"
  )

  # Emit counters

for (metric_name in sort(names(registry$counters))) {
    entries <- registry$counters[[metric_name]]
    if (length(entries) == 0) next

    help_text <- counter_meta[[metric_name]] %||% metric_name
    lines <- c(lines,
               sprintf("# HELP %s %s", metric_name, help_text),
               sprintf("# TYPE %s counter", metric_name))

    for (label_key in sort(names(entries))) {
      val <- entries[[label_key]]
      # Format integers without decimal, floats with precision
      if (val == floor(val)) {
        val_str <- as.character(as.integer(val))
      } else {
        val_str <- format(val, scientific = FALSE)
      }
      lines <- c(lines,
                 sprintf("%s{%s} %s", metric_name, label_key, val_str))
    }
  }

  # Emit histograms
  histogram_meta <- list(
    securetrace_span_duration_seconds = "Span duration histogram"
  )

  for (metric_name in sort(names(registry$histograms))) {
    entries <- registry$histograms[[metric_name]]
    if (length(entries) == 0) next

    help_text <- histogram_meta[[metric_name]] %||% metric_name
    lines <- c(lines,
               sprintf("# HELP %s %s", metric_name, help_text),
               sprintf("# TYPE %s histogram", metric_name))

    for (label_key in sort(names(entries))) {
      entry <- entries[[label_key]]
      buckets <- entry$buckets
      counts <- entry$counts

      # counts are already cumulative from registry_observe
      for (i in seq_along(buckets)) {
        le_str <- if (buckets[i] == floor(buckets[i])) {
          as.character(as.integer(buckets[i]))
        } else {
          as.character(buckets[i])
        }
        lines <- c(lines,
                   sprintf('%s_bucket{%s,le="%s"} %d',
                           metric_name, label_key, le_str, counts[i]))
      }
      # +Inf bucket = total count
      lines <- c(lines,
                 sprintf('%s_bucket{%s,le="+Inf"} %d',
                         metric_name, label_key, entry$count))
      # Sum and count
      sum_str <- format(entry$sum, scientific = FALSE)
      lines <- c(lines,
                 sprintf("%s_sum{%s} %s", metric_name, label_key, sum_str),
                 sprintf("%s_count{%s} %d", metric_name, label_key, entry$count))
    }
  }

  paste(lines, collapse = "\n")
}

#' Serve Prometheus Metrics via HTTP
#'
#' Starts an httpuv server that serves the `/metrics` endpoint in
#' Prometheus text exposition format.
#'
#' @param registry A `securetrace_prometheus_registry`.
#' @param host Host to bind to. Default `"0.0.0.0"`.
#' @param port Port to listen on. Default `9090`.
#' @return The httpuv server object (can be stopped with `httpuv::stopServer()`).
#' @examples
#' \dontrun{
#' reg <- prometheus_registry()
#' srv <- serve_prometheus(reg, port = 9091)
#' # Scrape http://localhost:9091/metrics
#' httpuv::stopServer(srv)
#' }
#' @export
serve_prometheus <- function(registry, host = "0.0.0.0", port = 9090) {
  rlang::check_installed("httpuv",
                         reason = "to serve Prometheus metrics over HTTP")

  httpuv::startServer(host, port, list(
    call = function(req) {
      if (req$PATH_INFO == "/metrics") {
        body <- format_prometheus(registry)
        list(
          status = 200L,
          headers = list(
            "Content-Type" = "text/plain; version=0.0.4; charset=utf-8"
          ),
          body = body
        )
      } else {
        list(
          status = 404L,
          headers = list("Content-Type" = "text/plain"),
          body = "Not Found\n"
        )
      }
    }
  ))
}
