# Execute Expression with Trace-Correlated Logging

Wraps message handlers to prepend trace context (trace ID and span ID)
to log messages emitted via
[`message()`](https://rdrr.io/r/base/message.html). This makes it easy
to correlate log output with distributed traces.

## Usage

``` r
with_trace_logging(expr)
```

## Arguments

- expr:

  Expression to evaluate.

## Value

Result of evaluating `expr`.

## Examples

``` r
with_trace("demo", {
  with_span("step", type = "custom", {
    with_trace_logging({
      message("hello from inside a span")
    })
  })
})
#> [trace_id=c404937460e04b627be2bcb557d2e437 span_id=eb2667dbb73c8c51] hello from inside a span
#> NULL
```
