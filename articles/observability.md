# Observability Integration

securetrace provides structured observability for R-based LLM agent
workflows. This vignette covers how to instrument your agents with
traces and spans, record token and cost data, and export traces for
analysis.

## Core Concepts

securetrace follows an OpenTelemetry-inspired model with three
primitives:

- **Trace** – A root container representing a complete agent run. Each
  trace has a unique ID, a name, metadata, and a collection of spans.
- **Span** – A single operation within a trace. Spans have types
  (`"llm"`, `"tool"`, `"guardrail"`, `"custom"`), can record token
  usage, and can nest inside each other via parent IDs.
- **Event** – A discrete point-in-time occurrence within a span, such as
  a model selection or a prompt being sent.

## Creating Traces and Spans

The simplest way to instrument code is with the
[`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md)
and
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
context managers:

``` r
library(securetrace)

result <- with_trace("my-agent-run", {
  with_span("planning", type = "llm", {
    record_tokens(1500, 300, model = "claude-sonnet-4-5")
    "The plan is ready"
  })
})

result
#> [1] "The plan is ready"
```

[`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md)
creates a `Trace` object, starts it, evaluates the expression, ends the
trace, and optionally exports it. Inside the trace,
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
creates child spans the same way. The current trace and span are
available via
[`current_trace()`](https://ian-flores.github.io/securetrace/reference/current_trace.md)
and
[`current_span()`](https://ian-flores.github.io/securetrace/reference/current_span.md)
at any point during evaluation.

## Span Nesting

Spans can nest to represent hierarchical operations. When you call
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
inside another
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md),
the inner span automatically records the outer span’s ID as its
`parent_id`:

``` r
result <- with_trace("nested-workflow", {

  # Outer span: planning step

  with_span("planning", type = "llm", {
    record_tokens(2000, 500, model = "claude-sonnet-4-5")

    # Inner span: a tool call within the planning step
    with_span("calculator", type = "tool", {
      2 + 2
    })
  })

  # Sibling span: summarization step
  with_span("summarize", type = "llm", {
    record_tokens(1000, 200, model = "claude-haiku-4-5")
    "Summary complete"
  })

  # Capture the trace while still inside with_trace()
  tr <- current_trace()
})
```

Each span knows its parent. When the trace is serialized with
`$to_list()`, the parent-child relationships are preserved through
`parent_id` fields, letting you reconstruct the full call tree.

## Manual Trace and Span Construction

For full control, you can use the R6 classes directly instead of the
context-manager wrappers:

``` r
# Create a trace manually
tr <- Trace$new("manual-trace", metadata = list(user = "analyst"))
tr$start()

# Create and configure a span
s1 <- Span$new("llm-call", type = "llm")
s1$start()
s1$set_model("claude-opus-4-6")
s1$set_tokens(input = 5000L, output = 1000L)
s1$end()
tr$add_span(s1)

# Create a second span with a parent
s2 <- Span$new("tool-use", type = "tool", parent_id = s1$span_id)
s2$start()
s2$add_metric("rows_processed", 150, unit = "rows")
s2$end()
tr$add_span(s2)

tr$end()

tr$status
#> [1] "completed"
tr$duration()
#> [1] 0.00678277
length(tr$spans)
#> [1] 2
```

## Recording Events

Events capture discrete occurrences within a span. They are S7 objects
created with
[`trace_event()`](https://ian-flores.github.io/securetrace/reference/trace_event.md)
and attached to spans with `$add_event()`:

``` r
tr <- Trace$new("event-demo")
tr$start()

s <- Span$new("llm-call", type = "llm")
s$start()

# Record events during the span
evt1 <- trace_event("model_selected", data = list(model = "claude-sonnet-4-5"))
s$add_event(evt1)

evt2 <- trace_event("prompt_sent", data = list(length = 1500L))
s$add_event(evt2)

s$set_tokens(input = 1500L, output = 300L)
s$end()
tr$add_span(s)
tr$end()

# Events are accessible on the span
length(s$events)
#> [1] 2
s$events[[1]]@name
#> [1] "model_selected"
s$events[[1]]@data
#> $model
#> [1] "claude-sonnet-4-5"
```

Note the `@` accessor for S7 properties on events (and exporters),
versus `$` for R6 fields on Trace and Span objects.

## Token and Cost Accounting

### Recording Tokens

Inside a
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
block, use
[`record_tokens()`](https://ian-flores.github.io/securetrace/reference/record_tokens.md)
to log token usage on the current span:

``` r
result <- with_trace("token-tracking", {
  with_span("step-1", type = "llm", {
    record_tokens(2000, 500, model = "claude-sonnet-4-5")
    "Step 1 done"
  })

  with_span("step-2", type = "llm", {
    record_tokens(1000, 200, model = "claude-haiku-4-5")
    "Step 2 done"
  })
})
```

When using the R6 API directly, call `$set_tokens()` and `$set_model()`
on the span object:

``` r
s <- Span$new("direct-span", type = "llm")
s$start()
s$set_tokens(input = 3000L, output = 800L)
s$set_model("gpt-4o")
s$end()
```

### Built-in Model Pricing

securetrace ships with per-1M-token pricing for common models:

``` r
# View all known model prices
costs <- model_costs()
names(costs)
#>  [1] "claude-opus-4-6"            "claude-sonnet-4-5"         
#>  [3] "claude-haiku-4-5"           "claude-3-5-sonnet-20241022"
#>  [5] "claude-3-5-haiku-20241022"  "claude-3-opus-20240229"    
#>  [7] "claude-3-sonnet-20240229"   "claude-3-haiku-20240307"   
#>  [9] "gpt-4o"                     "gpt-4o-mini"               
#> [11] "gpt-4o-2024-11-20"          "gpt-4-turbo"               
#> [13] "gpt-4"                      "gpt-3.5-turbo"             
#> [15] "o1"                         "o1-mini"                   
#> [17] "o3-mini"                    "gemini-2.0-flash"          
#> [19] "gemini-1.5-pro"             "gemini-1.5-flash"          
#> [21] "gemini-1.5-flash-8b"        "mistral-large-latest"      
#> [23] "mistral-small-latest"       "codestral-latest"          
#> [25] "deepseek-chat"              "deepseek-reasoner"
costs[["claude-sonnet-4-5"]]
#> $input
#> [1] 3
#> 
#> $output
#> [1] 15
```

### Calculating Costs

Use
[`calculate_cost()`](https://ian-flores.github.io/securetrace/reference/calculate_cost.md)
for a single model call, or
[`trace_total_cost()`](https://ian-flores.github.io/securetrace/reference/trace_total_cost.md)
for an entire trace:

``` r
# Cost of a single call
calculate_cost("claude-opus-4-6", input_tokens = 5000, output_tokens = 1000)
#> [1] 0.15

# Build a trace with multiple LLM spans
tr <- Trace$new("cost-demo")
tr$start()

s1 <- Span$new("expensive-call", type = "llm")
s1$start()
s1$set_model("claude-opus-4-6")
s1$set_tokens(input = 10000L, output = 2000L)
s1$end()
tr$add_span(s1)

s2 <- Span$new("cheap-call", type = "llm")
s2$start()
s2$set_model("claude-haiku-4-5")
s2$set_tokens(input = 5000L, output = 1000L)
s2$end()
tr$add_span(s2)

tr$end()

# Total cost across all spans
trace_total_cost(tr)
#> [1] 0.308
```

### Custom Model Pricing

Register pricing for models not in the built-in table:

``` r
add_model_cost("my-fine-tuned-model", input_price = 5, output_price = 20)
calculate_cost("my-fine-tuned-model", input_tokens = 1000, output_tokens = 500)
#> [1] 0.015
```

### Custom Metrics

Record arbitrary metrics on spans with
[`record_metric()`](https://ian-flores.github.io/securetrace/reference/record_metric.md)
(inside a
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md))
or `$add_metric()` (on the R6 object):

``` r
result <- with_trace("metrics-demo", {
  with_span("data-processing", type = "tool", {
    record_metric("rows_processed", 1500, unit = "rows")
    record_latency(0.42)
    "processed"
  })
})
```

## Trace Summary

The `$summary()` method prints a formatted overview of a completed
trace, including span count, total tokens, and estimated cost:

``` r
tr <- Trace$new("summary-demo")
tr$start()

s <- Span$new("llm-call", type = "llm")
s$start()
s$set_model("claude-opus-4-6")
s$set_tokens(input = 5000L, output = 1000L)
s$end()
tr$add_span(s)

tr$end()
tr$summary()
#> Trace: summary-demo (completed) ID: 5dc7de2b9f9ba19663bcbf69189b5c91 Duration:
#> 0.00s Spans: 1 Tokens: 5000 input, 1000 output Cost: $0.150000
```

## JSONL Export

The
[`jsonl_exporter()`](https://ian-flores.github.io/securetrace/reference/jsonl_exporter.md)
writes each completed trace as a single JSON line to a file. This is
ideal for post-hoc analysis, dashboards, or feeding into observability
platforms:

``` r
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
prints trace summaries directly to the console, useful for debugging and
interactive development:

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
span details.

## Multi-Exporter Setup

Use
[`multi_exporter()`](https://ian-flores.github.io/securetrace/reference/multi_exporter.md)
to send traces to multiple destinations at once. A common pattern is
logging to both a file and the console:

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
call, set a session-wide default:

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

Build your own exporter by passing a function to
[`new_exporter()`](https://ian-flores.github.io/securetrace/reference/new_exporter.md).
The function receives the serialized trace list (from `$to_list()`) as
its single argument:

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

## Error Handling

Traces and spans capture errors gracefully. When an error occurs inside
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md),
the span’s status is set to `"error"` and the error message is recorded.
The error then propagates to the enclosing
[`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md),
which marks itself as `"error"` and exports before re-raising:

``` r
trace_file <- tempfile(fileext = ".jsonl")
exp <- jsonl_exporter(trace_file)

with_trace("error-run", exporter = exp, {
  with_span("failing-step", type = "tool", {
    stop("something went wrong")
  })
})
#> Error in `doTryCatch()`:
#> ! something went wrong
```

``` r
# The trace was still exported despite the error
lines <- readLines(trace_file)
trace_data <- jsonlite::fromJSON(lines[[1]])
trace_data$status
#> [1] "error"
trace_data$spans$status
#> [1] "error"
trace_data$spans$error
#> [1] "something went wrong"

unlink(trace_file)
```

## Serialization

Every trace and span can be serialized to a plain R list with
`$to_list()`. This is what exporters receive, and it is useful for
programmatic analysis:

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

## Integration Helpers

securetrace provides convenience wrappers for common instrumentation
patterns. These require
[`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md)
to be active:

``` r
# Wrap tool calls
result <- with_trace("tool-integration", {
  trace_tool_call("calculator", function(x) x * 2, 21)
})
result
#> [1] 42

# Wrap guardrail checks
result <- with_trace("guard-integration", {
  trace_guardrail("length-check", function(x) nchar(x) < 1000, "short text")
})
result
#> [1] TRUE
```

### trace_execution() – Secure Code Execution

[`trace_execution()`](https://ian-flores.github.io/securetrace/reference/trace_execution.md)
wraps a securer `SecureSession$execute()` call with a span. The
submitted code is recorded as a `code.submitted` event, and any captured
stdout is recorded as an `execution.stdout` event:

``` r
session <- securer::SecureSession$new()

with_trace("sandboxed-run", {
  result <- trace_execution(session, "cat('hello'); 1 + 1")
})
session$close()

# The span contains two events:
#   1. code.submitted  -- data: list(code = "cat('hello'); 1 + 1")
#   2. execution.stdout -- data: list(lines = "hello")
```

### trace_guardrail() – secureguard Integration

When you pass a secureguard Guard object (not just a plain function),
[`trace_guardrail()`](https://ian-flores.github.io/securetrace/reference/trace_guardrail.md)
calls
[`secureguard::run_guardrail()`](https://ian-flores.github.io/secureguard/reference/run_guardrail.html)
and records structured result metadata as a `guardrail.result` event on
the span:

``` r
guard <- secureguard::guard_code_analysis()

with_trace("guarded-input", {
  result <- trace_guardrail("code-safety", guard, "system('rm -rf /')")
})

# The span event "guardrail.result" contains:
#   pass       -- TRUE/FALSE
#   guard_name -- name from the Guard object
#   guard_type -- type from the Guard object
#   reason     -- explanation string (if the check failed)
```

### trace_schema() – JSONL Format Reference

[`trace_schema()`](https://ian-flores.github.io/securetrace/reference/trace_schema.md)
returns a list describing every field in the JSONL export format,
including types and descriptions for both trace-level and span-level
fields. This is useful for building parsers or validating exported data:

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

## Putting It All Together

Here is a complete example of an instrumented multi-step agent workflow
with file export:

``` r
trace_file <- tempfile(fileext = ".jsonl")

combined_exp <- multi_exporter(
  jsonl_exporter(trace_file),
  console_exporter(verbose = TRUE)
)

result <- with_trace("full-agent-workflow", exporter = combined_exp, {

  # Step 1: Planning (LLM call)
  plan <- with_span("planning", type = "llm", {
    record_tokens(3000, 800, model = "claude-sonnet-4-5")
    evt <- trace_event("model_selected", data = list(model = "claude-sonnet-4-5"))
    current_span()$add_event(evt)
    list(steps = c("fetch", "compute", "summarize"))
  })

  # Step 2: Tool execution
  data <- with_span("fetch-data", type = "tool", {
    record_metric("rows_fetched", 250, unit = "rows")
    record_latency(0.15)
    data.frame(x = 1:250, y = rnorm(250))
  })

  # Step 3: Nested computation
  with_span("compute", type = "custom", {

    with_span("validate", type = "guardrail", {
      nrow(data) > 0
    })

    with_span("transform", type = "tool", {
      mean(data$y)
    })
  })

  # Step 4: Summarization (LLM call)
  with_span("summarize", type = "llm", {
    record_tokens(1500, 400, model = "claude-haiku-4-5")
    sprintf("Processed %d rows, mean = %.2f", nrow(data), mean(data$y))
  })
})
#> --- Trace: full-agent-workflow ---
#> Status: completed
#> Duration: 0.00s
#> Spans: 6
#> -- Spans --
#>   * planning [llm] (ok) - 0.000s
#>   * fetch-data [tool] (ok) - 0.000s
#>   * compute [custom] (ok) - 0.000s
#>   * validate [guardrail] (ok) - 0.000s
#>   * transform [tool] (ok) - 0.000s
#>   * summarize [llm] (ok) - 0.000s

result
#> [1] "Processed 250 rows, mean = -0.10"

# Verify export
lines <- readLines(trace_file)
trace_data <- jsonlite::fromJSON(lines[[1]])
sprintf("Trace '%s': %d spans, status = %s",
        trace_data$name,
        length(trace_data$spans$span_id),
        trace_data$status)
#> [1] "Trace 'full-agent-workflow': 6 spans, status = completed"

unlink(trace_file)
```
