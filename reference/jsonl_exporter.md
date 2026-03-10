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
#> [1] "{\"trace_id\":\"454f2bddb38d45e66954b7affa19a715\",\"name\":\"demo\",\"status\":\"completed\",\"metadata\":[],\"resource\":null,\"start_time\":\"2026-03-10T16:23:40.608Z\",\"end_time\":\"2026-03-10T16:23:40.608Z\",\"duration_secs\":0.0005,\"spans\":[]}"
unlink(tmp)
```
