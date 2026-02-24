# Extract Prometheus Metrics from a Trace

Walks a completed trace and increments counters / records histogram
observations in the given registry.

## Usage

``` r
prometheus_metrics(trace, registry = NULL)
```

## Arguments

- trace:

  A `Trace` R6 object.

- registry:

  A `securetrace_prometheus_registry`, or `NULL` to create one.

## Value

The registry (invisibly).

## Examples

``` r
tr <- Trace$new("demo")
tr$start()
s <- Span$new("step", type = "llm")
s$start()
s$set_model("gpt-4o")
s$set_tokens(input = 100L, output = 50L)
s$end()
tr$add_span(s)
tr$end()

reg <- prometheus_metrics(tr)
format_prometheus(reg)
#> [1] "# HELP securetrace_cost_total Total cost by model in USD\n# TYPE securetrace_cost_total counter\nsecuretrace_cost_total{model=\"gpt-4o\"} 0.00075\n# HELP securetrace_spans_total Total spans by type and status\n# TYPE securetrace_spans_total counter\nsecuretrace_spans_total{type=\"llm\",status=\"ok\"} 1\n# HELP securetrace_tokens_total Total tokens by direction and model\n# TYPE securetrace_tokens_total counter\nsecuretrace_tokens_total{direction=\"input\",model=\"gpt-4o\"} 100\nsecuretrace_tokens_total{direction=\"output\",model=\"gpt-4o\"} 50\n# HELP securetrace_traces_total Total traces by status\n# TYPE securetrace_traces_total counter\nsecuretrace_traces_total{status=\"completed\"} 1\n# HELP securetrace_span_duration_seconds Span duration histogram\n# TYPE securetrace_span_duration_seconds histogram\nsecuretrace_span_duration_seconds_bucket{type=\"llm\",le=\"0.01\"} 1\nsecuretrace_span_duration_seconds_bucket{type=\"llm\",le=\"0.05\"} 1\nsecuretrace_span_duration_seconds_bucket{type=\"llm\",le=\"0.1\"} 1\nsecuretrace_span_duration_seconds_bucket{type=\"llm\",le=\"0.5\"} 1\nsecuretrace_span_duration_seconds_bucket{type=\"llm\",le=\"1\"} 1\nsecuretrace_span_duration_seconds_bucket{type=\"llm\",le=\"5\"} 1\nsecuretrace_span_duration_seconds_bucket{type=\"llm\",le=\"10\"} 1\nsecuretrace_span_duration_seconds_bucket{type=\"llm\",le=\"30\"} 1\nsecuretrace_span_duration_seconds_bucket{type=\"llm\",le=\"60\"} 1\nsecuretrace_span_duration_seconds_bucket{type=\"llm\",le=\"120\"} 1\nsecuretrace_span_duration_seconds_bucket{type=\"llm\",le=\"300\"} 1\nsecuretrace_span_duration_seconds_bucket{type=\"llm\",le=\"+Inf\"} 1\nsecuretrace_span_duration_seconds_sum{type=\"llm\"} 0.001171112\nsecuretrace_span_duration_seconds_count{type=\"llm\"} 1"
```
