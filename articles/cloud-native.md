# Cloud-Native Observability

securetrace ships with cloud-native observability features that
integrate R agent workflows into modern infrastructure stacks. This
vignette covers OTLP export (Jaeger, Grafana Tempo), Prometheus metrics,
and W3C Trace Context propagation for distributed tracing.

For core tracing concepts (traces, spans, events, exporters), see
[`vignette("observability")`](https://ian-flores.github.io/securetrace/articles/observability.md).

## OTLP Export

The OpenTelemetry Protocol (OTLP) is the standard wire format for
sending traces to collectors like Jaeger, Grafana Tempo, and the
OpenTelemetry Collector. securetrace provides two functions for OTLP
integration.

### Sending Traces to a Collector

[`otlp_exporter()`](https://ian-flores.github.io/securetrace/reference/otlp_exporter.md)
creates an exporter that converts traces to OTLP JSON and POSTs them to
a collector endpoint:

``` r
library(securetrace)

# Export to a local Jaeger instance (default OTLP HTTP port)
exp <- otlp_exporter(endpoint = "http://localhost:4318")

with_trace("data-pipeline", exporter = exp, {
  with_span("fetch", type = "tool", {
    record_latency(0.25)
    data.frame(x = 1:100)
  })

  with_span("analyze", type = "llm", {
    record_tokens(2000, 500, model = "claude-sonnet-4-5")
    "analysis complete"
  })
})
#> Trace exported to http://localhost:4318/v1/traces
```

For authenticated collectors, pass headers:

``` r
exp <- otlp_exporter(
  endpoint = "https://tempo.example.com:4318",
  headers = list(Authorization = "Bearer <token>"),
  service_name = "my-r-agent"
)
```

The `service_name` parameter sets the `service.name` resource attribute
in the OTLP payload, which is how Jaeger and Tempo group traces by
service.

### Inspecting OTLP Output

[`otlp_format_trace()`](https://ian-flores.github.io/securetrace/reference/otlp_format_trace.md)
is the pure function underneath the exporter. It converts a trace list
into the OTLP `ExportTraceServiceRequest` JSON structure without sending
anything:

``` r
tr <- Trace$new("format-demo")
tr$start()

s <- Span$new("llm-call", type = "llm")
s$start()
s$set_model("claude-sonnet-4-5")
s$set_tokens(input = 1500L, output = 300L)
s$end()
tr$add_span(s)

tr$end()

otlp <- otlp_format_trace(tr$to_list(), service_name = "my-agent")
str(otlp, max.level = 3)
#> List of 1
#>  $ resourceSpans:List of 1
#>   ..$ :List of 2
#>   .. ..$ resource  :List of 1
#>   .. ..$ scopeSpans:List of 1
```

This is useful for debugging OTLP payloads or writing them to files for
offline import.

## Prometheus Metrics

Prometheus is a pull-based monitoring system. securetrace can expose
agent metrics (span counts, token usage, cost, duration histograms) in
Prometheus text exposition format.

### Creating a Registry

A registry holds counters and histograms. Create one and feed traces
into it:

``` r
reg <- prometheus_registry()

# Build a trace
tr <- Trace$new("agent-run")
tr$start()

s1 <- Span$new("planning", type = "llm")
s1$start()
s1$set_model("claude-sonnet-4-5")
s1$set_tokens(input = 3000L, output = 800L)
s1$end()
tr$add_span(s1)

s2 <- Span$new("execute", type = "tool")
s2$start()
s2$end()
tr$add_span(s2)

tr$end()

# Extract metrics from the trace into the registry
prometheus_metrics(tr, reg)
```

### Viewing Metrics

[`format_prometheus()`](https://ian-flores.github.io/securetrace/reference/format_prometheus.md)
renders the registry as a Prometheus-compatible text string:

``` r
cat(format_prometheus(reg))
#> # HELP securetrace_spans_total Total spans by type and status
#> # TYPE securetrace_spans_total counter
#> securetrace_spans_total{type="llm",status="completed"} 1
#> securetrace_spans_total{type="tool",status="completed"} 1
#> # HELP securetrace_tokens_total Total tokens by direction and model
#> # TYPE securetrace_tokens_total counter
#> securetrace_tokens_total{direction="input",model="claude-sonnet-4-5"} 3000
#> securetrace_tokens_total{direction="output",model="claude-sonnet-4-5"} 800
#> # HELP securetrace_traces_total Total traces by status
#> # TYPE securetrace_traces_total counter
#> securetrace_traces_total{status="completed"} 1
```

The registry is cumulative – each call to
[`prometheus_metrics()`](https://ian-flores.github.io/securetrace/reference/prometheus_metrics.md)
adds to the existing counters and histograms. This lets you track
metrics across multiple agent runs.

### Using the Prometheus Exporter

[`prometheus_exporter()`](https://ian-flores.github.io/securetrace/reference/prometheus_exporter.md)
returns a securetrace exporter that automatically feeds each completed
trace into a registry:

``` r
reg <- prometheus_registry()
prom_exp <- prometheus_exporter(reg)

# Traces auto-populate the registry on completion
with_trace("run-1", exporter = prom_exp, {
  with_span("llm", type = "llm", {
    record_tokens(1000, 200, model = "claude-haiku-4-5")
    "done"
  })
})

with_trace("run-2", exporter = prom_exp, {
  with_span("llm", type = "llm", {
    record_tokens(2000, 400, model = "claude-sonnet-4-5")
    "done"
  })
})

# Registry now has cumulative metrics from both runs
cat(format_prometheus(reg))
```

### Serving a /metrics Endpoint

[`serve_prometheus()`](https://ian-flores.github.io/securetrace/reference/serve_prometheus.md)
starts an httpuv HTTP server that Prometheus can scrape:

``` r
reg <- prometheus_registry()
prom_exp <- prometheus_exporter(reg)

# Start the metrics server
srv <- serve_prometheus(reg, host = "0.0.0.0", port = 9090)

# Run your agent -- metrics accumulate automatically
with_trace("production-run", exporter = prom_exp, {
  with_span("work", type = "llm", {
    record_tokens(5000, 1000, model = "claude-opus-4-6")
    "result"
  })
})

# Prometheus scrapes http://localhost:9090/metrics

# When done, stop the server
httpuv::stopServer(srv)
```

Add the scrape target to your `prometheus.yml`:

``` yaml
scrape_configs:
  - job_name: "r-agent"
    static_configs:
      - targets: ["localhost:9090"]
```

## W3C Trace Context Propagation

When R agents call external services (or are called by them), trace
context must propagate across process boundaries. securetrace implements
the [W3C Trace Context](https://www.w3.org/TR/trace-context/) standard
for this.

### Generating Traceparent Headers

[`traceparent()`](https://ian-flores.github.io/securetrace/reference/traceparent.md)
builds a W3C-compliant header string from trace and span IDs:

``` r
tp <- traceparent(
  trace_id = "4bf92f3577b34da6a3ce929d0e0e4736",
  span_id = "00f067aa0ba902b7"
)
tp
#> [1] "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
```

The `sampled` parameter controls the trace flags:

``` r
traceparent(
  "4bf92f3577b34da6a3ce929d0e0e4736",
  "00f067aa0ba902b7",
  sampled = FALSE
)
#> [1] "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-00"
```

### Parsing Incoming Headers

[`parse_traceparent()`](https://ian-flores.github.io/securetrace/reference/parse_traceparent.md)
extracts the components from a traceparent string:

``` r
ctx <- parse_traceparent(
  "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
)
ctx$trace_id
#> [1] "4bf92f3577b34da6a3ce929d0e0e4736"
ctx$span_id
#> [1] "00f067aa0ba902b7"
ctx$sampled
#> [1] TRUE

# Invalid headers return NULL
parse_traceparent("invalid-header")
#> NULL
```

### Injecting Context into Outgoing Requests

Inside an active trace,
[`inject_headers()`](https://ian-flores.github.io/securetrace/reference/inject_headers.md)
adds the `traceparent` header automatically from the current trace and
span context:

``` r
with_trace("http-client", {
  with_span("api-call", type = "tool", {
    headers <- inject_headers(list("Content-Type" = "application/json"))
    headers$traceparent
    #> [1] "00-<trace_id>-<span_id>-01"

    # Use these headers in your HTTP request
    # httr2::req_headers(req, !!!headers)
  })
})
```

### Extracting Context from Incoming Requests

[`extract_trace_context()`](https://ian-flores.github.io/securetrace/reference/extract_trace_context.md)
finds and parses the traceparent header from a named list
(case-insensitive lookup):

``` r
# Simulate incoming HTTP headers
incoming <- list(
  "Content-Type" = "application/json",
  traceparent = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
)

ctx <- extract_trace_context(incoming)
ctx$trace_id
#> [1] "4bf92f3577b34da6a3ce929d0e0e4736"
ctx$span_id
#> [1] "00f067aa0ba902b7"
```

## Distributed Tracing with Plumber

Here is a complete example of a Plumber API endpoint that extracts
incoming trace context and creates a child trace for its work:

``` r
library(securetrace)
library(plumber)

#* @post /analyze
function(req, res) {
  # Extract parent trace context from incoming request
  headers <- list(traceparent = req$HTTP_TRACEPARENT)
  ctx <- extract_trace_context(headers)

  # Create a trace that continues the parent context
  tr <- Trace$new("plumber-analyze")
  tr$start()

  # Create a span linked to the parent
  s <- Span$new("analyze", type = "llm",
                parent_id = ctx$span_id)
  s$start()
  s$set_model("claude-sonnet-4-5")
  s$set_tokens(input = 2000L, output = 500L)

  # Do work...
  result <- list(status = "ok", answer = 42)

  s$end()
  tr$add_span(s)
  tr$end()

  # Export to the same collector as the caller
  exp <- otlp_exporter("http://localhost:4318")
  export_trace(exp, tr)

  # Inject context into response headers for downstream
  res$setHeader(
    "traceparent",
    traceparent(tr$trace_id, s$span_id)
  )

  result
}
```

On the client side, inject context into your requests:

``` r
with_trace("client-workflow", {
  with_span("call-plumber", type = "tool", {
    headers <- inject_headers()

    resp <- httr2::request("http://localhost:8000/analyze") |>
      httr2::req_headers(!!!headers) |>
      httr2::req_method("POST") |>
      httr2::req_perform()

    httr2::resp_body_json(resp)
  })
})
```

Both the client and server traces share the same `trace_id`, so they
appear as a single distributed trace in Jaeger or Tempo.

## Multi-Exporter Setup

In production, you typically want traces going to multiple destinations.
Use
[`multi_exporter()`](https://ian-flores.github.io/securetrace/reference/multi_exporter.md)
to combine OTLP, Prometheus, and JSONL export:

``` r
# Set up all three exporters
reg <- prometheus_registry()

combined <- multi_exporter(
  otlp_exporter("http://localhost:4318", service_name = "r-agent"),
  prometheus_exporter(reg),
  jsonl_exporter("traces.jsonl")
)

# Start Prometheus scrape endpoint
srv <- serve_prometheus(reg, port = 9090)

# All traces go to Jaeger + Prometheus + local file
set_default_exporter(combined)

with_trace("production-workflow", {
  with_span("planning", type = "llm", {
    record_tokens(3000, 800, model = "claude-sonnet-4-5")
    "plan ready"
  })

  with_span("execution", type = "tool", {
    record_latency(1.2)
    42
  })
})

# Clean up
httpuv::stopServer(srv)
```

This gives you:

- **Jaeger/Tempo** – full distributed traces with span hierarchy
- **Prometheus** – time-series metrics for dashboards and alerting
- **JSONL** – local audit trail for compliance and post-hoc analysis
