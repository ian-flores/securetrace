# Format Prometheus Text Exposition

Renders a registry into the Prometheus text exposition format string.
This is a pure function with no network side-effects.

## Usage

``` r
format_prometheus(registry)
```

## Arguments

- registry:

  A `securetrace_prometheus_registry`.

## Value

A single character string in Prometheus exposition format.

## Examples

``` r
reg <- prometheus_registry()
tr <- Trace$new("demo")
tr$start()
s <- Span$new("step", type = "llm")
s$start()
s$end()
tr$add_span(s)
tr$end()
prometheus_metrics(tr, reg)
cat(format_prometheus(reg))
#> # HELP securetrace_spans_total Total spans by type and status
#> # TYPE securetrace_spans_total counter
#> securetrace_spans_total{type="llm",status="ok"} 1
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
#> securetrace_span_duration_seconds_sum{type="llm"} 0.0003859997
#> securetrace_span_duration_seconds_count{type="llm"} 1
```
