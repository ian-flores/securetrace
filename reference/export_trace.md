# Export a Trace

Calls the exporter's export function with the serialized trace.

## Usage

``` r
export_trace(exporter, trace)
```

## Arguments

- exporter:

  An S7 `securetrace_exporter` object.

- trace:

  A `Trace` object.

## Value

Invisible `NULL`.

## Examples

``` r
exp <- exporter_console(verbose = FALSE)
tr <- Trace$new("test-trace")
tr$start()
tr$end()
export_trace(exp, tr)
#> --- Trace: test-trace ---
#> Status: completed
#> Duration: 0.00s
#> Spans: 0
```
