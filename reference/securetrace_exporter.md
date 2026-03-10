# Exporter Class (S7)

Wraps an export function as an S7 exporter object.

## Usage

``` r
securetrace_exporter(export_fn = function() NULL)
```

## Arguments

- export_fn:

  A function that accepts a trace list.

## Value

An S7 object of class `securetrace_exporter`.

## Examples

``` r
# Create a custom exporter
exp <- securetrace_exporter(export_fn = function(trace_list) {
  cat("Exported:", trace_list$name, "\n")
})
exp@export_fn
#> function (trace_list) 
#> {
#>     cat("Exported:", trace_list$name, "\n")
#> }
#> <environment: 0x55a779b0e898>
```
