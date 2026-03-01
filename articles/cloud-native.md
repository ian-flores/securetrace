# Cloud-Native Observability

Integrate securetrace with OTLP collectors, Prometheus, and distributed
tracing via W3C Trace Context. For core tracing, see
[`vignette("observability")`](https://ian-flores.github.io/securetrace/articles/observability.md).

## OTLP Export

Inspect the OTLP payload locally with
[`otlp_format_trace()`](https://ian-flores.github.io/securetrace/reference/otlp_format_trace.md).

``` r
library(securetrace)

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

Point
[`otlp_exporter()`](https://ian-flores.github.io/securetrace/reference/otlp_exporter.md)
at any OTLP-HTTP endpoint.

``` r
exp <- otlp_exporter(endpoint = "http://localhost:4318")
with_trace("data-pipeline", exporter = exp, {
  with_span("fetch", type = "tool", { record_latency(0.25) })
  with_span("analyze", type = "llm", {
    record_tokens(2000, 500, model = "claude-sonnet-4-5")
  })
})
```

Pass headers for authenticated collectors.

``` r
exp <- otlp_exporter(
  endpoint = "https://tempo.example.com:4318",
  headers = list(Authorization = "Bearer <token>"),
  service_name = "my-r-agent"
)
```

Buffer traces with `batch_size`; call
[`flush_otlp()`](https://ian-flores.github.io/securetrace/reference/flush_otlp.md)
at exit to drain.

``` r
exp <- otlp_exporter("http://localhost:4318", batch_size = 10, max_retries = 3)
for (i in seq_len(5)) {
  with_trace(paste0("run-", i), exporter = exp, {
    with_span("work", type = "tool", { i })
  })
}
flush_otlp(exp)
```

## Prometheus

Create a registry, feed it a trace, render text format.

``` r
reg <- prometheus_registry()
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
prometheus_metrics(tr, reg)
cat(format_prometheus(reg))
#> # HELP securetrace_cost_total Total cost by model in USD
#> # TYPE securetrace_cost_total counter
#> securetrace_cost_total{model="claude-sonnet-4-5"} 0.021
#> # HELP securetrace_spans_total Total spans by type and status
#> # TYPE securetrace_spans_total counter
#> securetrace_spans_total{type="llm",status="ok"} 1
#> securetrace_spans_total{type="tool",status="ok"} 1
#> # HELP securetrace_tokens_total Total tokens by direction and model
#> # TYPE securetrace_tokens_total counter
#> securetrace_tokens_total{direction="input",model="claude-sonnet-4-5"} 3000
#> securetrace_tokens_total{direction="output",model="claude-sonnet-4-5"} 800
#> # HELP securetrace_traces_total Total traces by status
#> # TYPE securetrace_traces_total counter
#> securetrace_traces_total{status="completed"} 1
#> # HELP securetrace_span_duration_seconds Span duration histogram
#> # TYPE securetrace_span_duration_seconds histogram
#> securetrace_span_duration_seconds_bucket{type="llm",le="0.01"} 1
#> securetrace_span_duration_seconds_bucket{type="llm",le="0.05"} 1
#> securetrace_span_duration_seconds_bucket{type="llm",le="0.1"} 1
#> securetrace_span_duration_seconds_bucket{type="llm",le="0.5"} 1
#> securetrace_span_duration_seconds_bucket{type="llm",le="1"} 1
#> securetrace_span_duration_seconds_bucket{type="llm",le="5"} 1
#> securetrace_span_duration_seconds_bucket{type="llm",le="10"} 1
#> securetrace_span_duration_seconds_bucket{type="llm",le="30"} 1
#> securetrace_span_duration_seconds_bucket{type="llm",le="60"} 1
#> securetrace_span_duration_seconds_bucket{type="llm",le="120"} 1
#> securetrace_span_duration_seconds_bucket{type="llm",le="300"} 1
#> securetrace_span_duration_seconds_bucket{type="llm",le="+Inf"} 1
#> securetrace_span_duration_seconds_sum{type="llm"} 0.001614332
#> securetrace_span_duration_seconds_count{type="llm"} 1
#> securetrace_span_duration_seconds_bucket{type="tool",le="0.01"} 1
#> securetrace_span_duration_seconds_bucket{type="tool",le="0.05"} 1
#> securetrace_span_duration_seconds_bucket{type="tool",le="0.1"} 1
#> securetrace_span_duration_seconds_bucket{type="tool",le="0.5"} 1
#> securetrace_span_duration_seconds_bucket{type="tool",le="1"} 1
#> securetrace_span_duration_seconds_bucket{type="tool",le="5"} 1
#> securetrace_span_duration_seconds_bucket{type="tool",le="10"} 1
#> securetrace_span_duration_seconds_bucket{type="tool",le="30"} 1
#> securetrace_span_duration_seconds_bucket{type="tool",le="60"} 1
#> securetrace_span_duration_seconds_bucket{type="tool",le="120"} 1
#> securetrace_span_duration_seconds_bucket{type="tool",le="300"} 1
#> securetrace_span_duration_seconds_bucket{type="tool",le="+Inf"} 1
#> securetrace_span_duration_seconds_sum{type="tool"} 0.0005252361
#> securetrace_span_duration_seconds_count{type="tool"} 1
```

Use
[`prometheus_exporter()`](https://ian-flores.github.io/securetrace/reference/prometheus_exporter.md)
so completed traces auto-populate the registry.

``` r
reg <- prometheus_registry()
prom_exp <- prometheus_exporter(reg)
with_trace("run-1", exporter = prom_exp, {
  with_span("llm", type = "llm", {
    record_tokens(1000, 200, model = "claude-haiku-4-5")
    "done"
  })
})
#> [1] "done"
with_trace("run-2", exporter = prom_exp, {
  with_span("llm", type = "llm", {
    record_tokens(2000, 400, model = "claude-sonnet-4-5")
    "done"
  })
})
#> [1] "done"
cat(format_prometheus(reg))
#> # HELP securetrace_cost_total Total cost by model in USD
#> # TYPE securetrace_cost_total counter
#> securetrace_cost_total{model="claude-haiku-4-5"} 0.0016
#> securetrace_cost_total{model="claude-sonnet-4-5"} 0.012
#> # HELP securetrace_spans_total Total spans by type and status
#> # TYPE securetrace_spans_total counter
#> securetrace_spans_total{type="llm",status="ok"} 2
#> # HELP securetrace_tokens_total Total tokens by direction and model
#> # TYPE securetrace_tokens_total counter
#> securetrace_tokens_total{direction="input",model="claude-haiku-4-5"} 1000
#> securetrace_tokens_total{direction="input",model="claude-sonnet-4-5"} 2000
#> securetrace_tokens_total{direction="output",model="claude-haiku-4-5"} 200
#> securetrace_tokens_total{direction="output",model="claude-sonnet-4-5"} 400
#> # HELP securetrace_traces_total Total traces by status
#> # TYPE securetrace_traces_total counter
#> securetrace_traces_total{status="completed"} 2
#> # HELP securetrace_span_duration_seconds Span duration histogram
#> # TYPE securetrace_span_duration_seconds histogram
#> securetrace_span_duration_seconds_bucket{type="llm",le="0.01"} 2
#> securetrace_span_duration_seconds_bucket{type="llm",le="0.05"} 2
#> securetrace_span_duration_seconds_bucket{type="llm",le="0.1"} 2
#> securetrace_span_duration_seconds_bucket{type="llm",le="0.5"} 2
#> securetrace_span_duration_seconds_bucket{type="llm",le="1"} 2
#> securetrace_span_duration_seconds_bucket{type="llm",le="5"} 2
#> securetrace_span_duration_seconds_bucket{type="llm",le="10"} 2
#> securetrace_span_duration_seconds_bucket{type="llm",le="30"} 2
#> securetrace_span_duration_seconds_bucket{type="llm",le="60"} 2
#> securetrace_span_duration_seconds_bucket{type="llm",le="120"} 2
#> securetrace_span_duration_seconds_bucket{type="llm",le="300"} 2
#> securetrace_span_duration_seconds_bucket{type="llm",le="+Inf"} 2
#> securetrace_span_duration_seconds_sum{type="llm"} 0.0001018047
#> securetrace_span_duration_seconds_count{type="llm"} 2
```

Serve `/metrics` for Prometheus to scrape.

``` r
srv <- serve_prometheus(reg, host = "0.0.0.0", port = 9090)
# ... run traced workloads ...
httpuv::stopServer(srv)
```

## W3C Trace Context

Generate and parse W3C `traceparent` headers.

``` r
tp <- traceparent(
  trace_id = "4bf92f3577b34da6a3ce929d0e0e4736",
  span_id = "00f067aa0ba902b7"
)
tp
#> [1] "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
traceparent("4bf92f3577b34da6a3ce929d0e0e4736", "00f067aa0ba902b7", sampled = FALSE)
#> [1] "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-00"
```

``` r
ctx <- parse_traceparent("00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01")
ctx$trace_id
#> [1] "4bf92f3577b34da6a3ce929d0e0e4736"
ctx$span_id
#> [1] "00f067aa0ba902b7"
ctx$sampled
#> [1] TRUE
parse_traceparent("invalid-header")
#> Warning: Invalid traceparent header format: "invalid-header"
#> NULL
```

Inject `traceparent` into outgoing requests from inside an active trace.

``` r
with_trace("http-client", {
  with_span("api-call", type = "tool", {
    headers <- inject_headers(list("Content-Type" = "application/json"))
    headers$traceparent
  })
})
#> [1] "00-ec379768f898282ec0ee6483eaae57b6-2b7b2f7b71619fb0-01"
```

Extract trace context from incoming headers (case-insensitive).

``` r
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

Server: extract parent context and create child spans.

``` r
library(securetrace)
library(plumber)

#* @post /analyze
function(req, res) {
  ctx <- extract_trace_context(list(traceparent = req$HTTP_TRACEPARENT))
  tr <- Trace$new("plumber-analyze")
  tr$start()
  s <- Span$new("analyze", type = "llm", parent_id = ctx$span_id)
  s$start()
  s$set_model("claude-sonnet-4-5")
  s$set_tokens(input = 2000L, output = 500L)
  result <- list(status = "ok", answer = 42)
  s$end()
  tr$add_span(s)
  tr$end()
  export_trace(otlp_exporter("http://localhost:4318"), tr)
  res$setHeader("traceparent", traceparent(tr$trace_id, s$span_id))
  result
}
```

Client: inject context so both sides share one trace.

``` r
with_trace("client-workflow", {
  with_span("call-plumber", type = "tool", {
    resp <- httr2::request("http://localhost:8000/analyze") |>
      httr2::req_headers(!!!inject_headers()) |>
      httr2::req_method("POST") |>
      httr2::req_perform()
    httr2::resp_body_json(resp)
  })
})
```
