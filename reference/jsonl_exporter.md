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
#> [1] "{\"trace_id\":\"504e4bb58ceb0083f17f6df6fa965498\",\"name\":\"demo\",\"status\":\"completed\",\"metadata\":[],\"start_time\":\"2026-03-01T14:42:06.912Z\",\"end_time\":\"2026-03-01T14:42:06.912Z\",\"duration_secs\":0.0004,\"spans\":[]}"
unlink(tmp)
```
