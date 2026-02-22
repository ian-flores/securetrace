# Format a Trace as OTLP JSON

Pure function that converts a trace list (from `trace$to_list()`) into
the OTLP JSON structure expected by OpenTelemetry collectors.

## Usage

``` r
otlp_format_trace(trace_list, service_name = "r-agent")
```

## Arguments

- trace_list:

  A list produced by `Trace$to_list()`.

- service_name:

  Service name for the OTLP resource (default `"r-agent"`).

## Value

A named list matching the OTLP `ExportTraceServiceRequest` JSON
structure.

## Examples

``` r
tr <- Trace$new("format-demo")
tr$start()
s <- Span$new("step", type = "tool")
s$start()
s$end()
tr$add_span(s)
tr$end()
otlp <- otlp_format_trace(tr$to_list())
str(otlp, max.level = 3)
#> List of 1
#>  $ resourceSpans:List of 1
#>   ..$ :List of 2
#>   .. ..$ resource  :List of 1
#>   .. ..$ scopeSpans:List of 1
```
