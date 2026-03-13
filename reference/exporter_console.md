# Console Exporter

Creates an exporter that prints trace summaries to the console.

## Usage

``` r
exporter_console(verbose = TRUE)

console_exporter(...)
```

## Arguments

- verbose:

  If `TRUE`, print detailed span information.

- ...:

  Arguments passed to `exporter_console()`.

## Value

An S7 `securetrace_exporter` object.

## Examples

``` r
exp <- exporter_console(verbose = TRUE)

tr <- Trace$new("demo-run")
tr$start()
span <- Span$new("step1", type = "custom")
span$start()
span$end()
tr$add_span(span)
tr$end()
export_trace(exp, tr)
#> --- Trace: demo-run ---
#> Status: completed
#> Duration: 0.00s
#> Spans: 1
#> -- Spans --
#>   * step1 [custom] (ok) - 0.000s
```
