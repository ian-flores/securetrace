# Exporters

## JSONL exporter

Write each trace as one JSON line to an append-only file.

``` r
library(securetrace)
trace_file <- tempfile(fileext = ".jsonl")
exp <- exporter_jsonl(trace_file)
with_trace("exported-run", exporter = exp, {
  with_span("llm-call", type = "llm", {
    record_tokens(1500, 300, model = "claude-sonnet-4-5")
    "response"
  })
  with_span("tool-call", type = "tool", { 42 })
})
#> [1] 42
```

Read back with `jsonlite`:

``` r
lines <- readLines(trace_file)
length(lines)
#> [1] 1
trace_data <- jsonlite::fromJSON(lines[[1]])
trace_data$name
#> [1] "exported-run"
length(trace_data$spans$span_id)
#> [1] 2
unlink(trace_file)
```

## Console exporter

Print trace summaries during interactive development.

``` r
debug_exp <- exporter_console(verbose = TRUE)
with_trace("debug-run", exporter = debug_exp, {
  with_span("planning", type = "llm", {
    record_tokens(2000, 500, model = "claude-sonnet-4-5")
    "plan"
  })
  with_span("execution", type = "tool", { 100 })
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

Set `verbose = FALSE` for headers only.

## Multiple exporters

Fan out to N destinations with
[`exporter_multi()`](https://ian-flores.github.io/securetrace/reference/exporter_multi.md).

``` r
trace_file <- tempfile(fileext = ".jsonl")
combined <- exporter_multi(
  exporter_jsonl(trace_file),
  exporter_console(verbose = TRUE)
)
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
readLines(trace_file) |> length()
#> [1] 1
unlink(trace_file)
```

## Default exporter

Set a session-wide exporter instead of passing one per
[`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md)
call.

``` r
trace_file <- tempfile(fileext = ".jsonl")
set_default_exporter(exporter_jsonl(trace_file))
with_trace("auto-1", { with_span("work", type = "tool", { 1 + 1 }) })
#> [1] 2
with_trace("auto-2", { with_span("more-work", type = "tool", { 2 + 2 }) })
#> [1] 4
readLines(trace_file) |> length()
#> [1] 2
unlink(trace_file)
```

## Custom exporters

Pass any function to
[`exporter()`](https://ian-flores.github.io/securetrace/reference/exporter.md).
It receives the serialized trace list.

``` r
span_counter <- exporter(function(trace_list) {
  cat(sprintf("Trace '%s': %d spans\n",
              trace_list$name, length(trace_list$spans)))
})
with_trace("custom-export", exporter = span_counter, {
  with_span("a", type = "tool", { 1 })
  with_span("b", type = "tool", { 2 })
  with_span("c", type = "llm", {
    record_tokens(100, 50, model = "claude-haiku-4-5")
    3
  })
})
#> Trace 'custom-export': 3 spans
#> [1] 3
```

## Serialization

Convert any trace to a plain list with `$to_list()` – this is what
exporters receive.

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
#> [5] "resource"      "start_time"    "end_time"      "duration_secs"
#> [9] "spans"
trace_list$spans[[1]]$metrics
#> [[1]]
#> [[1]]$name
#> [1] "quality"
#> 
#> [[1]]$value
#> [1] 0.95
```

Discover all JSONL fields with
[`trace_schema()`](https://ian-flores.github.io/securetrace/reference/trace_schema.md):

``` r
schema <- trace_schema()
names(schema)
#> [1] "trace_id"   "name"       "status"     "start_time" "end_time"  
#> [6] "duration"   "spans"
names(schema$spans$fields)
#>  [1] "span_id"       "name"          "type"          "status"       
#>  [5] "start_time"    "end_time"      "duration_secs" "parent_id"    
#>  [9] "model"         "input_tokens"  "output_tokens"
```
