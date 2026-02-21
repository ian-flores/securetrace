# Create a New Exporter

Wraps an export function as an S3 exporter object.

## Usage

``` r
new_exporter(export_fn)
```

## Arguments

- export_fn:

  A function that accepts a trace list (from `trace$to_list()`).

## Value

An S3 object of class `securetrace_exporter`.
