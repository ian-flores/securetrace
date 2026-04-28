# JSONL Exporter

Creates an exporter that writes completed traces as JSONL (one JSON
object per line) to a file.

## Usage

``` r
exporter_jsonl(path)

jsonl_exporter(...)
```

## Arguments

- path:

  File path for the JSONL output.

- ...:

  Arguments passed to `exporter_jsonl()`.

## Value

An S7 `securetrace_exporter` object.

## Examples

``` r
# Write traces to a temporary JSONL file
tmp <- tempfile(fileext = ".jsonl")
exp <- exporter_jsonl(tmp)

tr <- Trace$new("demo")
tr$start()
tr$end()
export_trace(exp, tr)

readLines(tmp)
#> [1] "{\"trace_id\":\"b88c9ae35eb1e9ed1991423dd1445207\",\"name\":\"demo\",\"status\":\"completed\",\"metadata\":[],\"resource\":null,\"start_time\":\"2026-04-28T07:54:20.549Z\",\"end_time\":\"2026-04-28T07:54:20.549Z\",\"duration_secs\":0.0004,\"spans\":[]}"
unlink(tmp)
```
