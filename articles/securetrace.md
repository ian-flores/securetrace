# Getting Started with securetrace

## Why Observability for AI Agents?

Traditional software is deterministic: the same input produces the same
output, and when something goes wrong you can reproduce the failure. AI
agents break this contract. A language model might return a different
plan each time it runs, choose different tools, consume wildly different
numbers of tokens, and produce outputs that are plausible but wrong.
Without structured observability, debugging an agent workflow becomes
guesswork.

Observability means capturing what happened *inside* an agent run – not
just the final answer, but every LLM call, every tool invocation, every
guardrail check, along with the tokens consumed, latency incurred, and
costs accrued. With this data you can answer questions that matter in
production: Why did this run cost \$2.40 instead of \$0.15? Why did the
agent call the same tool four times? Where did the guardrail reject a
valid input?

securetrace brings this discipline to R. It provides structured traces
with nested spans, automatic token and cost accounting, and multiple
export formats so you can feed trace data into whatever analysis
pipeline you already use – from a simple JSONL file to Jaeger,
Prometheus, or Grafana Tempo.

## Trace Anatomy

Every securetrace observation follows a hierarchical model inspired by
OpenTelemetry, adapted for the specific needs of AI agent workflows:

    Trace: "agent-run-042"
    |
    |-- Span: "planning" (type: llm)
    |   |-- tokens: 2000 in / 500 out
    |   |-- model: claude-sonnet-4-5
    |   |-- cost: $0.0135
    |   |-- Event: "model_selected"
    |   |-- Event: "prompt_sent"
    |   |
    |   '-- Span: "calculator" (type: tool)     <-- nested child
    |       '-- metric: rows_processed = 150
    |
    |-- Span: "guardrail" (type: guardrail)
    |   '-- Event: "guardrail.result" { pass: TRUE }
    |
    '-- Span: "summarize" (type: llm)
        |-- tokens: 1000 in / 200 out
        |-- model: claude-haiku-4-5
        '-- cost: $0.0013

- **Trace** – The root container for a complete agent run. Holds
  metadata, timing, and a collection of spans.
- **Span** – A single operation: an LLM call, a tool invocation, a
  guardrail check, or any custom step. Spans nest to represent
  parent-child relationships.
- **Event** – A discrete point-in-time occurrence within a span (model
  selection, prompt dispatch, guardrail result).
- **Metrics** – Numeric measurements attached to spans: token counts,
  latency, cost, or any custom value you define.

## Basic Usage

Create a trace with spans to track an agent workflow:

``` r
library(securetrace)

# Wrap your workflow in a trace
result <- with_trace("my-agent-run", {

  # Each operation gets its own span
  with_span("llm-call", type = "llm", {
    record_tokens(1500, 300, model = "claude-sonnet-4-5")
    "The answer is 42"
  })
})
```

[`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md)
handles the lifecycle for you: it creates a Trace object, starts the
clock, evaluates your code, ends the trace, and optionally exports it.
Inside,
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
works the same way for individual operations. At any point during
evaluation,
[`current_trace()`](https://ian-flores.github.io/securetrace/reference/current_trace.md)
and
[`current_span()`](https://ian-flores.github.io/securetrace/reference/current_span.md)
give you access to the active objects so you can record tokens, events,
or metrics.

## Token and Cost Tracking

Understanding token consumption is critical for managing AI agent costs.
securetrace includes built-in pricing for popular LLM models so you can
see exactly how much each operation costs without maintaining your own
pricing tables.

``` r
# View known model pricing (per 1M tokens)
model_costs()

# Calculate cost for a specific call
calculate_cost("claude-opus-4-6", input_tokens = 5000, output_tokens = 1000)

# Register custom model pricing
add_model_cost("my-fine-tuned-model", input_price = 5, output_price = 20)
```

### Multi-Provider Support

Real-world agent systems rarely use a single model. A planning step
might use a powerful model like Claude Opus, while a simple
classification step uses a cheaper model like Haiku. securetrace ships
with pricing for models across Anthropic, OpenAI, Google Gemini,
Mistral, and DeepSeek, so you can track costs across providers without
manual configuration.

``` r
# View all known model pricing (per 1M tokens)
costs <- model_costs()
head(costs)
#>                  model input_price output_price
#> 1     claude-opus-4-6       15.00        75.00
#> 2   claude-sonnet-4-5        3.00        15.00
#> 3              gpt-4o        2.50        10.00
#> 4      gemini-1.5-pro        1.25         5.00
#> 5      gemini-2.0-flash      0.10         0.40
#> 6  deepseek-reasoner        0.55         2.19
```

When your infrastructure runs models through a cloud provider gateway,
the model IDs look different from the canonical names. securetrace
resolves cloud provider model IDs (AWS Bedrock, Google Vertex)
automatically via built-in aliases, so you do not need to maintain a
mapping yourself:

``` r
# Bedrock model ID works transparently
calculate_cost(
  "anthropic.claude-3-5-sonnet-20241022-v2:0",
  input_tokens = 10000,
  output_tokens = 2000
)

# Vertex model ID also resolves
calculate_cost(
  "publishers/anthropic/models/claude-3-5-sonnet-v2@20241022",
  input_tokens = 10000,
  output_tokens = 2000
)
```

For custom or self-hosted deployments, register your own aliases to map
internal names to known pricing:

``` r
# Map an internal deployment name to a known model
add_model_alias("my-company-claude", "claude-sonnet-4-5")
calculate_cost("my-company-claude", input_tokens = 5000, output_tokens = 1000)
```

When using
[`trace_llm_call()`](https://ian-flores.github.io/securetrace/reference/trace_llm_call.md)
with an ellmer Chat object, the model name and token counts are
extracted automatically – you do not need to call
[`record_tokens()`](https://ian-flores.github.io/securetrace/reference/record_tokens.md)
manually:

``` r
result <- with_trace("auto-instrumented", {
  trace_llm_call("analysis", chat, "Summarize the data.")
})
# Model and token counts are set on the span without manual recording
```

## Exporting Traces

Traces are only useful if you can get them out of R and into your
analysis pipeline. securetrace provides several built-in exporters that
cover the most common scenarios, from quick debugging to production
observability.

``` r
# JSONL file export
exp <- jsonl_exporter("traces.jsonl")

with_trace("exported-run", exporter = exp, {
  with_span("work", type = "tool", {
    42
  })
})

# Console export for debugging
debug_exp <- console_exporter(verbose = TRUE)

# Combine multiple exporters
both <- multi_exporter(exp, debug_exp)

# Or set a default exporter for all traces
set_default_exporter(exp)
```

For a deep dive into exporters – JSONL format, console output, custom
exporters, and the trace schema – see
[`vignette("exporters")`](https://ian-flores.github.io/securetrace/articles/exporters.md).

## Integration Helpers

Instrumenting every LLM call and tool invocation manually would be
tedious. securetrace provides convenience wrappers that create
properly-typed spans, record the right metadata, and handle errors
automatically.

``` r
# Wrap tool calls
result <- with_trace("tools", {
  trace_tool_call("calculator", function(x) x * 2, 21)
})

# Wrap guardrail checks
with_trace("guarded", {
  trace_guardrail("length-check", function(x) nchar(x) < 1000, user_input)
})
```

### Streaming LLM Calls

[`trace_llm_call()`](https://ian-flores.github.io/securetrace/reference/trace_llm_call.md)
supports streaming responses via the `stream` parameter. When
`stream = TRUE`, the chat object’s `$stream()` method is called instead
of `$chat()`, and a `streaming` event is recorded on the span:

``` r
# Stream responses with automatic tracing
with_trace("streaming-example", {
  response <- trace_llm_call(chat, "Explain R6 classes", stream = TRUE)
})
# The span records: model, tokens, latency, and a "streaming" event
```

### Tool Call Tracking

When the LLM invokes tools during a chat,
[`trace_llm_call()`](https://ian-flores.github.io/securetrace/reference/trace_llm_call.md)
automatically inspects the response turn and records each tool
invocation as a `tool_call` event on the span. No extra instrumentation
is needed:

``` r
# Register tools on the chat object, then trace the call
chat <- ellmer::chat_openai(model = "gpt-4o")
chat$register_tool(ellmer::tool(
  function(x, y) x + y,
  "Adds two numbers", x = "First number", y = "Second number"
))

with_trace("agent-with-tools", {
  response <- trace_llm_call(chat, "What is 3 + 4?")
})
# Each tool invocation appears as a "tool_call" event with name and arguments
```

## Nested Spans

Agent workflows are rarely flat. A planning step might invoke a tool,
which itself calls an LLM for sub-reasoning. Spans nest naturally to
capture this hierarchy – inner spans record the outer span’s ID as their
`parent_id`, preserving the full call tree when the trace is serialized.

``` r
with_trace("complex-workflow", {
  with_span("planning", type = "llm", {
    record_tokens(2000, 500, model = "claude-sonnet-4-5")

    with_span("tool-use", type = "tool", {
      # Tool execution within the planning step
      42
    })
  })

  with_span("summarize", type = "llm", {
    record_tokens(1000, 200, model = "claude-haiku-4-5")
    "Summary complete"
  })
})
```

## Trace Summary

Get a formatted summary of any trace to quickly understand what
happened:

``` r
tr <- Trace$new("manual-trace")
tr$start()
s <- Span$new("llm", type = "llm")
s$start()
s$set_tokens(input = 5000, output = 1000)
s$set_model("claude-opus-4-6")
s$end()
tr$add_span(s)
tr$end()

tr$summary()
# Trace: manual-trace (completed)
#   Duration: 0.01s
#   Spans: 1
#   Tokens: 5000 input, 1000 output
#   Cost: $0.150000
```

## Next Steps

- [`vignette("observability")`](https://ian-flores.github.io/securetrace/articles/observability.md)
  – Core concepts: traces, spans, events, metrics, error handling, and a
  full “Putting It All Together” example.
- [`vignette("exporters")`](https://ian-flores.github.io/securetrace/articles/exporters.md)
  – JSONL export, console exporter, custom exporters, and the trace
  schema reference.
- [`vignette("cloud-native")`](https://ian-flores.github.io/securetrace/articles/cloud-native.md)
  – OTLP export to Jaeger/Tempo, Prometheus metrics, W3C Trace Context
  propagation.
- [`vignette("orchestr-integration")`](https://ian-flores.github.io/securetrace/articles/orchestr-integration.md)
  – Automatic tracing of orchestr graph executions and agent
  invocations.
