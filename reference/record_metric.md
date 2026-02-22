# Record a Custom Metric on the Current Span

Record a Custom Metric on the Current Span

## Usage

``` r
record_metric(name, value, unit = NULL)
```

## Arguments

- name:

  Metric name.

- value:

  Metric value.

- unit:

  Optional unit string.

## Value

Invisible `NULL`.

## Examples

``` r
# Record a custom metric on the active span
with_trace("metric-demo", {
  with_span("scoring", type = "custom", {
    record_metric("confidence", 0.95)
    record_metric("temperature", 0.7, unit = "degrees")
  })
})
#> NULL
```
