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
