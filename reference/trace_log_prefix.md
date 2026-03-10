# Get Trace Context Prefix for Log Messages

Returns a formatted string containing the current trace and span IDs,
suitable for prepending to log messages. If no trace is active, returns
an empty string.

## Usage

``` r
trace_log_prefix()
```

## Value

Character string like `"[trace_id=X span_id=Y] "` or `""`.

## Examples

``` r
# Outside a trace, returns empty string
trace_log_prefix()
#> [1] ""

# Inside a trace with a span
with_trace("demo", {
  with_span("step", type = "custom", {
    trace_log_prefix()
  })
})
#> [1] "[trace_id=a022f98472cdfb0ad5981b7b59f3826f span_id=bf12a93589edeecd] "
```
