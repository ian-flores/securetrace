# Multi-Exporter

Combines multiple exporters into one. When a trace is exported, it is
sent to all contained exporters.

## Usage

``` r
exporter_multi(...)

multi_exporter(...)
```

## Arguments

- ...:

  For `exporter_multi()`: exporter objects to combine. For
  `multi_exporter()` (deprecated): passed to `exporter_multi()`.

## Value

An S7 `securetrace_exporter` object.

## Examples

``` r
# Export to both console and JSONL
tmp <- tempfile(fileext = ".jsonl")
combined <- exporter_multi(
  exporter_console(verbose = FALSE),
  exporter_jsonl(tmp)
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
