# Create a New Exporter

Factory function for creating exporter objects.

## Usage

``` r
new_exporter(export_fn)
```

## Arguments

- export_fn:

  A function that accepts a trace list (from `trace$to_list()`).

## Value

An S7 object of class `securetrace_exporter`.

## Examples

``` r
# Create an exporter that counts traces
counter <- new.env(parent = emptyenv())
counter$n <- 0L
exp <- new_exporter(function(trace_list) {
  counter$n <- counter$n + 1L
})
```
