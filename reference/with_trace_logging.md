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
#> [trace_id=58157429af86cfc4793d6a395be055a1 span_id=bf57a5cf2c676453] hello from inside a span
#> NULL
```
