# JSON stdout Exporter

Creates an exporter that writes one structured JSON line per span to
standard output. This is useful for cloud-native environments where
structured logs are collected from stdout by a log aggregator (e.g.,
Fluentd, Vector, CloudWatch Logs).

## Usage

``` r
exporter_json_stdout()

json_stdout_exporter(...)
```

## Arguments

- ...:

  Arguments passed to `exporter_json_stdout()`.

## Value

An S7 `securetrace_exporter` object.

## Details

Each line is a self-contained JSON object containing span-level fields:
`trace_id`, `span_id`, `parent_id`, `name`, `type`, `start_time`,
`end_time`, `status`, `duration_secs`, plus any token/cost data and
attributes.

## Examples

``` r
exp <- exporter_json_stdout()

tr <- Trace$new("demo")
tr$start()
s <- Span$new("step1", type = "tool")
s$start()
s$end()
tr$add_span(s)
tr$end()
export_trace(exp, tr)
#> {"trace_id":"c0ee6483eaae57b62b7b2f7b71619fb0","span_id":"49188a0f6beaf3a0","parent_id":null,"name":"step1","type":"tool","start_time":"2026-04-23T12:54:49.977Z","end_time":"2026-04-23T12:54:49.977Z","status":"ok","duration_secs":0.0004,"input_tokens":0,"output_tokens":0,"model":null,"error":null}
```
