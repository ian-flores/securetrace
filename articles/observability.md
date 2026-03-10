# Traces, Spans, and Events

The R6 API gives you direct access to events, custom metrics, nested
spans, error handling, and integration helpers. For
[`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md)
basics and token tracking, see
[`vignette("securetrace")`](https://ian-flores.github.io/securetrace/articles/securetrace.md).

``` r
library(securetrace)
```

## Span types

| Type          | Use for                   | Example                                     |
|---------------|---------------------------|---------------------------------------------|
| `"llm"`       | Language model calls      | `Span$new("plan", type = "llm")`            |
| `"tool"`      | Tool / function execution | `Span$new("calc", type = "tool")`           |
| `"guardrail"` | Input/output validation   | `Span$new("pii-check", type = "guardrail")` |
| `"custom"`    | Anything else             | `Span$new("transform", type = "custom")`    |

## Nested spans

Inner spans record the outer span’s ID as `parent_id`:

    Trace: "pipeline"
    |-- Span: "planning" (llm)
    |   '-- Span: "calculator" (tool)   <- child
    '-- Span: "summarize" (llm)         <- sibling

``` r
result <- with_trace("pipeline", {
  with_span("planning", type = "llm", {
    record_tokens(2000, 500, model = "claude-sonnet-4-5")
    with_span("calculator", type = "tool", { 2 + 2 })
  })
  with_span("summarize", type = "llm", {
    record_tokens(1000, 200, model = "claude-haiku-4-5")
    "done"
  })
})
```

Parent-child relationships persist in exported JSON via `parent_id`
fields.

## Manual construction

Use the R6 classes when spans are created in one function and ended in
another, or when building traces from recorded data.

``` r
tr <- Trace$new("manual-trace", metadata = list(user = "analyst"))
tr$start()
s1 <- Span$new("llm-call", type = "llm")
s1$start()
s1$set_model("claude-opus-4-6")
s1$set_tokens(input = 5000L, output = 1000L)
s1$end()
tr$add_span(s1)
s2 <- Span$new("tool-use", type = "tool", parent_id = s1$span_id)
s2$start()
s2$add_metric("rows_processed", 150, unit = "rows")
s2$end()
tr$add_span(s2)
tr$end()
```

``` r
tr$status
#> [1] "completed"
tr$duration()
#> [1] 0.006675005
length(tr$spans)
#> [1] 2
```

## Events

Create with
[`trace_event()`](https://ian-flores.github.io/securetrace/reference/trace_event.md),
attach with `$add_event()`, access with `@`:

``` r
tr <- Trace$new("event-demo")
tr$start()
s <- Span$new("llm-call", type = "llm")
s$start()
s$add_event(trace_event("model_selected", data = list(model = "claude-sonnet-4-5")))
s$add_event(trace_event("prompt_sent", data = list(length = 1500L)))
s$set_tokens(input = 1500L, output = 300L)
s$end()
tr$add_span(s)
tr$end()
```

``` r
length(s$events)
#> [1] 2
s$events[[1]]@name
#> [1] "model_selected"
s$events[[1]]@data
#> $model
#> [1] "claude-sonnet-4-5"
```

## Custom metrics

Use
[`record_metric()`](https://ian-flores.github.io/securetrace/reference/record_metric.md)
/
[`record_latency()`](https://ian-flores.github.io/securetrace/reference/record_latency.md)
inside
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md),
or `$add_metric()` on the R6 object:

``` r
result <- with_trace("metrics-demo", {
  with_span("data-processing", type = "tool", {
    record_metric("rows_processed", 1500, unit = "rows")
    record_latency(0.42)
    "processed"
  })
})
```

``` r
s <- Span$new("manual-metrics", type = "tool")
s$start()
s$add_metric("cache_hits", 42, unit = "count")
s$end()
s$metrics
#> NULL
```

## Error handling

Errors inside
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
set status to `"error"` and record the message. The trace still exports,
then re-raises.

``` r
trace_file <- tempfile(fileext = ".jsonl")
exp <- jsonl_exporter(trace_file)
with_trace("error-run", exporter = exp, {
  with_span("failing-step", type = "tool", {
    stop("something went wrong")
  })
})
#> Error in `doTryCatch()`:
#> ! something went wrong
```

``` r
lines <- readLines(trace_file)
trace_data <- jsonlite::fromJSON(lines[[1]])
trace_data$status
#> [1] "error"
trace_data$spans$status
#> [1] "error"
trace_data$spans$error
#> [1] "something went wrong"
unlink(trace_file)
```

## Integration helpers

[`trace_tool_call()`](https://ian-flores.github.io/securetrace/reference/trace_tool_call.md)
and
[`trace_guardrail()`](https://ian-flores.github.io/securetrace/reference/trace_guardrail.md)
create typed spans automatically. Both require an active
[`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md).

``` r
with_trace("tool-integration", {
  trace_tool_call("calculator", function(x) x * 2, 21)
})
#> [1] 42
```

``` r
with_trace("guard-integration", {
  trace_guardrail("length-check", function(x) nchar(x) < 1000, "short text")
})
#> [1] TRUE
```

### Secure execution

[`trace_execution()`](https://ian-flores.github.io/securetrace/reference/trace_execution.md)
wraps `securer::SecureSession$execute()` with a span, recording code and
stdout as events:

``` r
session <- securer::SecureSession$new()
with_trace("sandboxed-run", {
  trace_execution(session, "cat('hello'); 1 + 1")
})
session$close()
```

### secureguard integration

Pass a Guard object to
[`trace_guardrail()`](https://ian-flores.github.io/securetrace/reference/trace_guardrail.md)
for structured result metadata:

``` r
guard <- secureguard::guard_code_analysis()
with_trace("guarded-input", {
  trace_guardrail("code-safety", guard, "system('rm -rf /')")
})
```

## Full example

Multi-step workflow: nested spans, tokens, events, metrics, and JSONL
export.

``` r
trace_file <- tempfile(fileext = ".jsonl")
exp <- multi_exporter(jsonl_exporter(trace_file), console_exporter(verbose = TRUE))
result <- with_trace("full-workflow", exporter = exp, {
  with_span("planning", type = "llm", {
    record_tokens(3000, 800, model = "claude-sonnet-4-5")
    current_span()$add_event(trace_event("model_selected",
      data = list(model = "claude-sonnet-4-5")))
    list(steps = c("fetch", "compute", "summarize"))
  })
  data <- with_span("fetch-data", type = "tool", {
    record_metric("rows_fetched", 250, unit = "rows")
    data.frame(x = 1:250, y = rnorm(250))
  })
  with_span("compute", type = "custom", {
    with_span("validate", type = "guardrail", { nrow(data) > 0 })
    with_span("transform", type = "tool", { mean(data$y) })
  })
  with_span("summarize", type = "llm", {
    record_tokens(1500, 400, model = "claude-haiku-4-5")
    sprintf("Processed %d rows, mean = %.2f", nrow(data), mean(data$y))
  })
})
#> --- Trace: full-workflow ---
#> Status: completed
#> Duration: 0.00s
#> Spans: 6
#> -- Spans --
#>   * planning [llm] (ok) - 0.000s
#>   * fetch-data [tool] (ok) - 0.000s
#>   * compute [custom] (ok) - 0.000s
#>   * validate [guardrail] (ok) - 0.000s
#>   * transform [tool] (ok) - 0.000s
#>   * summarize [llm] (ok) - 0.000s
lines <- readLines(trace_file)
trace_data <- jsonlite::fromJSON(lines[[1]])
sprintf("Trace '%s': %d spans, status = %s",
        trace_data$name, length(trace_data$spans$span_id), trace_data$status)
#> [1] "Trace 'full-workflow': 6 spans, status = completed"
unlink(trace_file)
```

## Next steps

- [`vignette("exporters")`](https://ian-flores.github.io/securetrace/articles/exporters.md):
  JSONL, console, custom exporters, and trace schema.
- [`vignette("cloud-native")`](https://ian-flores.github.io/securetrace/articles/cloud-native.md):
  OTLP, Prometheus, W3C Trace Context.
- [`vignette("orchestr-integration")`](https://ian-flores.github.io/securetrace/articles/orchestr-integration.md):
  automatic tracing of orchestr graphs.
