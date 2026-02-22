# Multi-Exporter

Combines multiple exporters into one. When a trace is exported, it is
sent to all contained exporters.

## Usage

``` r
multi_exporter(...)
```

## Arguments

- ...:

  Exporter objects to combine.

## Value

An S3 `securetrace_exporter` object.

## Examples

``` r
# Export to both console and JSONL
tmp <- tempfile(fileext = ".jsonl")
combined <- multi_exporter(
  console_exporter(verbose = FALSE),
  jsonl_exporter(tmp)
)

tr <- Trace$new("multi-demo")
tr$start()
tr$end()
export_trace(combined, tr)
#> --- Trace: multi-demo ---
#> Status: completed
#> Duration: 0.00s
#> Spans: 0
unlink(tmp)
```
