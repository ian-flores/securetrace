# Create a New Exporter

Factory function for creating exporter objects.

## Usage

``` r
exporter(export_fn)

new_exporter(...)
```

## Arguments

- export_fn:

  A function that accepts a trace list (from `trace$to_list()`).

- ...:

  Arguments passed to `exporter()`.

## Value

An S7 object of class `securetrace_exporter`.

## Examples

``` r
# Create an exporter that counts traces
counter <- new.env(parent = emptyenv())
counter$n <- 0L
exp <- exporter(function(trace_list) {
  counter$n <- counter$n + 1L
})
```
