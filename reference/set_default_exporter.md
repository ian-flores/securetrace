# Set the Default Exporter

Set the Default Exporter

## Usage

``` r
set_default_exporter(exporter)
```

## Arguments

- exporter:

  An S3 `securetrace_exporter` object.

## Value

Invisible `NULL`.

## Examples

``` r
# Set a default exporter for all with_trace() calls
set_default_exporter(console_exporter(verbose = FALSE))

# Now with_trace() auto-exports without specifying exporter
with_trace("auto-exported", {
  1 + 1
})
#> --- Trace: auto-exported ---
#> Status: completed
#> Duration: 0.00s
#> Spans: 0
#> [1] 2

# Reset by setting a no-op exporter
set_default_exporter(new_exporter(function(trace_list) invisible(NULL)))
```
