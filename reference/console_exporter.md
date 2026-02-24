# Console Exporter

Creates an exporter that prints trace summaries to the console.

## Usage

``` r
console_exporter(verbose = TRUE)
```

## Arguments

- verbose:

  If `TRUE`, print detailed span information.

## Value

An S3 `securetrace_exporter` object.

## Examples

``` r
exp <- console_exporter(verbose = TRUE)

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
#>   * step1 [custom] (ok) - 0.001s
```
