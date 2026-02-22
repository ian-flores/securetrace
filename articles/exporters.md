# Exporting and Analyzing Traces

## Getting Traces Out of R

A trace is only valuable if it can be analyzed. During development you
might print traces to the console to see what an agent did. In
production you want traces written to files for post-hoc analysis or
piped to an observability platform. securetrace separates trace
*collection* from trace *export* so that the same instrumentation code
works everywhere – only the exporter changes.

The export pipeline looks like this:

    with_trace("run", exporter = exp, {
      ...your agent code...
    })
        |
        v
    Trace$to_list()            # Serialize R6 object to plain list
        |
        v
    exporter@export(trace_list) # Deliver to destination
        |
        +---> jsonl_exporter    --> append JSON line to file
        +---> console_exporter  --> print summary to console
        +---> multi_exporter    --> fan out to N exporters
        +---> new_exporter(fn)  --> your custom logic

Every exporter receives the same serialized trace list, so they are
fully composable. You can wrap any combination of exporters in a
[`multi_exporter()`](https://ian-flores.github.io/securetrace/reference/multi_exporter.md)
and every trace goes to every destination.

## JSONL Export

The
[`jsonl_exporter()`](https://ian-flores.github.io/securetrace/reference/jsonl_exporter.md)
writes each completed trace as a single JSON line to a file. This is the
workhorse exporter for production use – it produces a compact,
append-only log that is easy to parse with `jsonlite`, `jq`, or any data
pipeline tool.

``` r
library(securetrace)

# Create a temporary file for this example
trace_file <- tempfile(fileext = ".jsonl")

exp <- jsonl_exporter(trace_file)

# Traces are exported automatically when with_trace() completes
with_trace("exported-run", exporter = exp, {
  with_span("llm-call", type = "llm", {
    record_tokens(1500, 300, model = "claude-sonnet-4-5")
    "response"
  })

  with_span("tool-call", type = "tool", {
    42
  })
})
#> [1] 42

# Read back the exported data
lines <- readLines(trace_file)
length(lines)  # 1 line per trace
#> [1] 1

# Parse and inspect
trace_data <- jsonlite::fromJSON(lines[[1]])
trace_data$name
#> [1] "exported-run"
trace_data$status
#> [1] "completed"
length(trace_data$spans$span_id)
#> [1] 2

# Clean up
unlink(trace_file)
```

Each JSONL line contains the full trace structure: trace ID, name,
status, timestamps, duration, and all spans with their tokens, events,
and metrics.

## Console Exporter

The
[`console_exporter()`](https://ian-flores.github.io/securetrace/reference/console_exporter.md)
prints trace summaries directly to the console. This is the fastest way
to see what an agent did during interactive development, without writing
any files.

``` r
debug_exp <- console_exporter(verbose = TRUE)

with_trace("debug-run", exporter = debug_exp, {
  with_span("planning", type = "llm", {
    record_tokens(2000, 500, model = "claude-sonnet-4-5")
    "plan"
  })

  with_span("execution", type = "tool", {
    100
  })
})
#> --- Trace: debug-run ---
#> Status: completed
#> Duration: 0.00s
#> Spans: 2
#> -- Spans --
#>   * planning [llm] (ok) - 0.000s
#>   * execution [tool] (ok) - 0.000s
#> [1] 100
```

Set `verbose = FALSE` to print only the trace header without individual
span details. This is useful in loops or batch runs where you want
confirmation that traces completed without flooding the console.

## Multi-Exporter Setup

In practice you usually want traces going to more than one place – a
file for the audit trail, the console for visibility, and perhaps a
cloud exporter for production monitoring.
[`multi_exporter()`](https://ian-flores.github.io/securetrace/reference/multi_exporter.md)
fans out to any number of exporters:

``` r
trace_file <- tempfile(fileext = ".jsonl")

# Combine a file exporter and a console exporter
file_exp <- jsonl_exporter(trace_file)
console_exp <- console_exporter(verbose = TRUE)
combined <- multi_exporter(file_exp, console_exp)

with_trace("multi-export-run", exporter = combined, {
  with_span("llm-call", type = "llm", {
    record_tokens(3000, 600, model = "claude-opus-4-6")
    "result"
  })
})
#> --- Trace: multi-export-run ---
#> Status: completed
#> Duration: 0.00s
#> Spans: 1
#> -- Spans --
#>   * llm-call [llm] (ok) - 0.000s
#> [1] "result"

# The trace was written to the file AND printed to console
lines <- readLines(trace_file)
length(lines)
#> [1] 1

unlink(trace_file)
```

## Default Exporter

Rather than passing an exporter to every
[`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md)
call, set a session-wide default. This is especially useful in
production scripts where every trace should go to the same destination.

``` r
trace_file <- tempfile(fileext = ".jsonl")
set_default_exporter(jsonl_exporter(trace_file))

# All subsequent traces are automatically exported
with_trace("auto-exported-1", {
  with_span("work", type = "tool", { 1 + 1 })
})
#> [1] 2

with_trace("auto-exported-2", {
  with_span("more-work", type = "tool", { 2 + 2 })
})
#> [1] 4

lines <- readLines(trace_file)
length(lines)  # 2 traces exported
#> [1] 2

unlink(trace_file)
```

## Custom Exporters

The built-in exporters cover the most common cases, but you can build
your own for any destination. Pass a function to
[`new_exporter()`](https://ian-flores.github.io/securetrace/reference/new_exporter.md)
– the function receives the serialized trace list (from `$to_list()`) as
its single argument.

This makes it straightforward to integrate with databases, message
queues, HTTP APIs, or any custom logging system:

``` r
# A simple exporter that counts spans per trace
span_counter <- new_exporter(function(trace_list) {
  cat(sprintf(
    "Trace '%s' completed with %d spans\n",
    trace_list$name,
    length(trace_list$spans)
  ))
})

with_trace("custom-export", exporter = span_counter, {
  with_span("a", type = "tool", { 1 })
  with_span("b", type = "tool", { 2 })
  with_span("c", type = "llm", {
    record_tokens(100, 50, model = "claude-haiku-4-5")
    3
  })
})
#> Trace 'custom-export' completed with 3 spans
#> [1] 3
```

## Serialization

Every trace and span can be serialized to a plain R list with
`$to_list()`. This is what exporters receive internally, and it is the
right format for programmatic analysis – you get standard R data
structures instead of R6 reference objects.

``` r
tr <- Trace$new("serialize-demo")
tr$start()

s <- Span$new("work", type = "custom")
s$start()
s$add_metric("quality", 0.95)
s$end()
tr$add_span(s)

tr$end()

trace_list <- tr$to_list()
names(trace_list)
#> [1] "trace_id"      "name"          "status"        "metadata"     
#> [5] "start_time"    "end_time"      "duration_secs" "spans"
trace_list$name
#> [1] "serialize-demo"
trace_list$spans[[1]]$metrics
#> [[1]]
#> [[1]]$name
#> [1] "quality"
#> 
#> [[1]]$value
#> [1] 0.95
```

## trace_schema() – JSONL Format Reference

When building parsers, dashboards, or validation pipelines for exported
trace data, you need to know exactly what fields to expect.
[`trace_schema()`](https://ian-flores.github.io/securetrace/reference/trace_schema.md)
returns a list describing every field in the JSONL export format,
including types and descriptions for both trace-level and span-level
fields:

``` r
schema <- trace_schema()
names(schema)
#> [1] "trace_id"   "name"       "status"     "start_time" "end_time"  
#> [6] "duration"   "spans"
#> [1] "trace_id" "name" "status" "start_time" "end_time" "duration" "spans"

# Inspect span-level fields
names(schema$spans$fields)
#>  [1] "span_id"       "name"          "type"          "status"       
#>  [5] "start_time"    "end_time"      "duration_secs" "parent_id"    
#>  [9] "model"         "input_tokens"  "output_tokens"
#> [1] "span_id" "name" "type" "status" "start_time" "end_time"
#> [7] "duration_secs" "parent_id" "model" "input_tokens" "output_tokens"
```

## Next Steps

- [`vignette("cloud-native")`](https://ian-flores.github.io/securetrace/articles/cloud-native.md)
  – OTLP export to Jaeger/Tempo, Prometheus metrics, and W3C Trace
  Context propagation for distributed tracing.
- [`vignette("orchestr-integration")`](https://ian-flores.github.io/securetrace/articles/orchestr-integration.md)
  – Automatic tracing of orchestr graph executions and agent
  invocations.
