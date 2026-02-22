# Record Latency on the Current Span

Records a latency metric on the currently active span.

## Usage

``` r
record_latency(duration_secs)
```

## Arguments

- duration_secs:

  Duration in seconds.

## Value

Invisible `NULL`.

## Examples

``` r
# Record latency on the active span
with_trace("latency-demo", {
  with_span("api-call", type = "custom", {
    record_latency(0.45)
  })
})
#> NULL
```
