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
