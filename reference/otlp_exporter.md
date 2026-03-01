# OTLP JSON Exporter

Creates an exporter that converts traces to OpenTelemetry Protocol
(OTLP) JSON format and sends them to an OTLP-compatible collector such
as Jaeger, Grafana Tempo, or any OpenTelemetry Collector.

## Usage

``` r
otlp_exporter(
  endpoint = Sys.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318"),
  headers = list(),
  service_name = Sys.getenv("OTEL_SERVICE_NAME", "r-agent"),
  batch_size = 100L,
  max_retries = 3L
)
```

## Arguments

- endpoint:

  OTLP HTTP endpoint URL. Defaults to the `OTEL_EXPORTER_OTLP_ENDPOINT`
  environment variable, or `"http://localhost:4318"` if unset.

- headers:

  Named list of HTTP headers to include in requests (e.g.,
  authentication tokens).

- service_name:

  Service name reported in the resource attributes. Defaults to the
  `OTEL_SERVICE_NAME` environment variable, or `"r-agent"` if unset.

- batch_size:

  Maximum number of traces to buffer before sending (default `100L`).
  Traces are accumulated and sent when the buffer reaches this size. Use
  [`flush_otlp()`](https://ian-flores.github.io/securetrace/reference/flush_otlp.md)
  to force-send buffered traces.

- max_retries:

  Maximum number of retry attempts for transient HTTP errors (429, 5xx).
  Default `3L`. Uses exponential backoff (1s, 2s, 4s).

## Value

An S7 `securetrace_exporter` object.

## Examples

``` r
if (FALSE) { # \dontrun{
# Export to a local Jaeger instance
exp <- otlp_exporter("http://localhost:4318")

tr <- Trace$new("my-run")
tr$start()
s <- Span$new("llm-call", type = "llm")
s$start()
s$set_model("gpt-4o")
s$set_tokens(input = 100L, output = 50L)
s$end()
tr$add_span(s)
tr$end()
export_trace(exp, tr)
flush_otlp(exp)
} # }
```
