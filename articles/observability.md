# Core Observability Concepts

securetrace provides structured observability for R-based LLM agent
workflows. This vignette covers the core building blocks – traces,
spans, events, and metrics – and shows how they compose to give you full
visibility into agent behavior. For exporting traces to files and
external systems, see
[`vignette("exporters")`](https://ian-flores.github.io/securetrace/articles/exporters.md).

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

Together, these three primitives let you represent arbitrarily complex
agent workflows as structured data. A trace is the “story” of an agent
run; spans are the “chapters”; events are the “sentences” within each
chapter.

## Creating Traces and Spans

The simplest way to instrument code is with the
[`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md)
and
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
context managers. These handle the lifecycle for you: creating the
object, starting the clock, evaluating your code, and ending the object
when the block completes (even if an error occurs).

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

Agent workflows are hierarchical. A planning step might invoke a tool,
which itself makes a sub-call. Spans nest naturally to capture this
structure. When you call
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
inside another
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md),
the inner span automatically records the outer span’s ID as its
`parent_id`:

    Trace: "nested-workflow"
    |
    |-- Span: "planning" (type: llm)
    |   |-- tokens: 2000 in / 500 out
    |   |
    |   '-- Span: "calculator" (type: tool)    <-- child of "planning"
    |       '-- result: 4
    |
    '-- Span: "summarize" (type: llm)          <-- sibling of "planning"
        '-- tokens: 1000 in / 200 out

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

The context-manager style (`with_trace` / `with_span`) is convenient for
most cases, but sometimes you need full control – for example, when
spans are created in one function and ended in another, or when you are
building traces from recorded data rather than live execution.

For these cases, use the R6 classes directly:

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
#> [1] 0.006780624
length(tr$spans)
#> [1] 2
```

## Recording Events

Events capture discrete occurrences within a span – things that happen
at a specific moment in time rather than spanning a duration. Common
examples include model selection, prompt dispatch, streaming start, and
tool invocation.

Events are S7 objects created with
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
versus `$` for R6 fields on Trace and Span objects. This reflects the
design principle: events and exporters are value objects (S7), while
traces and spans are stateful objects (R6).

## Token and Cost Accounting

Token tracking is at the heart of AI agent observability. Without it,
you cannot answer the most basic production question: “How much did this
run cost?”

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

Beyond tokens, you may want to track domain-specific measurements like
rows processed, cache hit rates, or response quality scores. Use
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
trace, including span count, total tokens, and estimated cost. This is
the quickest way to understand what happened in an agent run without
parsing export files:

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

## Error Handling

Traces and spans capture errors gracefully. When an error occurs inside
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md),
the span’s status is set to `"error"` and the error message is recorded.
The error then propagates to the enclosing
[`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md),
which marks itself as `"error"` and exports before re-raising.

This means you always get trace data, even for failed runs – which is
exactly when you need it most.

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

## Putting It All Together

Here is a complete example of an instrumented multi-step agent workflow.
It combines everything covered in this vignette: nested spans, token
recording, events, custom metrics, and error-safe execution.

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
#> [1] "Processed 250 rows, mean = -0.04"

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

## Next Steps

- [`vignette("exporters")`](https://ian-flores.github.io/securetrace/articles/exporters.md)
  – JSONL export, console and custom exporters, the trace schema, and
  serialization details.
- [`vignette("cloud-native")`](https://ian-flores.github.io/securetrace/articles/cloud-native.md)
  – OTLP export, Prometheus metrics, and W3C Trace Context for
  distributed tracing.
- [`vignette("orchestr-integration")`](https://ian-flores.github.io/securetrace/articles/orchestr-integration.md)
  – Automatic tracing of orchestr graph executions and agent
  invocations.
