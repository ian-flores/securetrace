# JSONL Exporter

Creates an exporter that writes completed traces as JSONL (one JSON
object per line) to a file.

## Usage

``` r
jsonl_exporter(path)
```

## Arguments

- path:

  File path for the JSONL output.

## Value

An S3 `securetrace_exporter` object.

## Examples

``` r
# Write traces to a temporary JSONL file
tmp <- tempfile(fileext = ".jsonl")
exp <- jsonl_exporter(tmp)

tr <- Trace$new("demo")
tr$start()
tr$end()
export_trace(exp, tr)

readLines(tmp)
#> [1] "{\"trace_id\":\"19a7134dbb6c3332de454f2bddb38d45\",\"name\":\"demo\",\"status\":\"completed\",\"metadata\":[],\"start_time\":\"2026-02-22T14:43:18.023Z\",\"end_time\":\"2026-02-22T14:43:18.024Z\",\"duration_secs\":0.0004,\"spans\":[]}"
unlink(tmp)
```
