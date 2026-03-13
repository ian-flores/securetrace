# Prometheus Exporter

Returns a `securetrace_exporter` S7 object that feeds traces into a
Prometheus registry on each export call.

## Usage

``` r
exporter_prometheus(registry = NULL)

prometheus_exporter(...)
```

## Arguments

- registry:

  A `securetrace_prometheus_registry`, or `NULL` to create one.

- ...:

  Arguments passed to `exporter_prometheus()`.

## Value

An S7 `securetrace_exporter` object. The registry is accessible via the
exporter's closure environment.

## Examples

``` r
exp <- exporter_prometheus()
tr <- Trace$new("demo")
tr$start()
tr$end()
export_trace(exp, tr)
```
