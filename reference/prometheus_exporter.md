# Prometheus Exporter

Returns a `securetrace_exporter` S7 object that feeds traces into a
Prometheus registry on each export call.

## Usage

``` r
prometheus_exporter(registry = NULL)
```

## Arguments

- registry:

  A `securetrace_prometheus_registry`, or `NULL` to create one.

## Value

An S7 `securetrace_exporter` object. The registry is accessible via the
exporter's closure environment.

## Examples

``` r
exp <- prometheus_exporter()
tr <- Trace$new("demo")
tr$start()
tr$end()
export_trace(exp, tr)
```
