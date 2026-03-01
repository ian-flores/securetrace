# JSON stdout Exporter

Creates an exporter that writes one structured JSON line per span to
standard output. This is useful for cloud-native environments where
structured logs are collected from stdout by a log aggregator (e.g.,
Fluentd, Vector, CloudWatch Logs).

## Usage

``` r
json_stdout_exporter()
```

## Value

An S7 `securetrace_exporter` object.

## Details

Each line is a self-contained JSON object containing span-level fields:
`trace_id`, `span_id`, `parent_id`, `name`, `type`, `start_time`,
`end_time`, `status`, `duration_secs`, plus any token/cost data and
attributes.

## Examples

``` r
exp <- json_stdout_exporter()

tr <- Trace$new("demo")
tr$start()
s <- Span$new("step1", type = "tool")
s$start()
s$end()
tr$add_span(s)
tr$end()
export_trace(exp, tr)
#> {"trace_id":"19a7134dbb6c3332de454f2bddb38d45","span_id":"e66954b7affa19a7","parent_id":null,"name":"step1","type":"tool","start_time":"2026-03-01T20:36:18.090Z","end_time":"2026-03-01T20:36:18.090Z","status":"ok","duration_secs":0.0004,"input_tokens":0,"output_tokens":0,"model":null,"error":null}
```
