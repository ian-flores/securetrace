# securetrace

> \[!NOTE\] Experimental release. APIs may change before the 1.0
> stabilization; track the lifecycle badge above for the current tier.

Observability and tracing for R LLM agent workflows. Structured traces
with spans, token/cost accounting, latency monitoring, and JSONL export.

## Why securetrace?

AI agent workflows are opaque by default – you can’t see which tools
ran, how long they took, how many tokens they consumed, or what they
cost. securetrace gives you structured tracing with nested spans,
automatic token/cost accounting, and export to JSONL or Prometheus – so
you get full visibility into every agent step.

## Part of the secure-r-dev Ecosystem

securetrace is part of a 7-package ecosystem for building governed AI
agents in R:

                        ┌─────────────┐
                        │   securer    │
                        └──────┬──────┘
              ┌────────────────┼─────────────────┐
              │                │                  │
       ┌──────▼──────┐  ┌─────▼──────┐  ┌───────▼────────┐
       │ securetools  │  │ secureguard│  │ securecontext   │
       └──────┬───────┘  └─────┬──────┘  └───────┬────────┘
              └────────────────┼─────────────────┘
                        ┌──────▼───────┐
                        │   orchestr   │
                        └──────┬───────┘
              ┌────────────────┼─────────────────┐
              │                                  │
      ┌───────▼────────┐                  ┌──────▼──────┐
      │>>> securetrace<<<│                 │ securebench  │
      └────────────────┘                  └─────────────┘

securetrace provides the observability layer at the bottom of the stack.
It instruments LLM calls, tool executions, and guardrail checks with
structured traces, token/cost accounting, and JSONL export – giving
visibility into what your agents are doing and how much it costs.

| Package                                                      | Role                                                    |
|--------------------------------------------------------------|---------------------------------------------------------|
| [securer](https://github.com/ian-flores/securer)             | Sandboxed R execution with tool-call IPC                |
| [securetools](https://github.com/ian-flores/securetools)     | Pre-built security-hardened tool definitions            |
| [secureguard](https://github.com/ian-flores/secureguard)     | Input/code/output guardrails (injection, PII, secrets)  |
| [orchestr](https://github.com/ian-flores/orchestr)           | Graph-based agent orchestration                         |
| [securecontext](https://github.com/ian-flores/securecontext) | Document chunking, embeddings, RAG retrieval            |
| [securetrace](https://github.com/ian-flores/securetrace)     | Structured tracing, token/cost accounting, JSONL export |
| [securebench](https://github.com/ian-flores/securebench)     | Guardrail benchmarking with precision/recall/F1 metrics |

## Installation

``` r
# install.packages("pak")
pak::pak("ian-flores/securetrace")
```

## Quick Start

``` r
library(securetrace)

result <- with_trace("my-agent", exporter = jsonl_exporter("traces.jsonl"), {
  with_span("llm-call", type = "llm", {
    record_tokens(1500, 300, model = "claude-sonnet-4-5")
    "The answer is 42"
  })
})
```

## Features

- **Structured traces** – OpenTelemetry-inspired traces and spans for R
- **Token accounting** – Track input/output tokens per span
- **Cost calculation** – Built-in pricing for Claude and GPT models
- **JSONL export** – Write traces to structured log files
- **Context management** – Automatic trace/span stacking with
  [`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md)
  /
  [`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
- **Integration helpers** – Wrappers for LLM calls, tool executions, and
  guardrail checks
- **Prometheus metrics** – Counters, histograms, and an HTTP `/metrics`
  endpoint

### Cost Tracking

securetrace ships with built-in pricing for Claude and GPT models.
Record tokens per span and calculate costs automatically:

``` r
library(securetrace)

# Record tokens and compute cost within a trace
result <- with_trace("cost-demo", {
  with_span("llm-call", type = "llm", {
    record_tokens(1500, 300, model = "claude-sonnet-4-5")
    "response text"
  })
})

# Calculate cost for a single call (price per 1M tokens)
calculate_cost("gpt-4o", input_tokens = 1000, output_tokens = 500)

# Register custom model pricing
add_model_cost("my-local-model", input_price = 0, output_price = 0)

# Sum costs across all spans in a trace
tr <- current_trace()
trace_total_cost(tr)
```

### Integration Helpers

securetrace provides wrappers that auto-instrument calls to ellmer,
securer, and secureguard:

``` r
# Trace an ellmer LLM call (requires ellmer)
chat <- ellmer::chat_openai(model = "gpt-4o")
with_trace("agent-run", {
  response <- trace_llm_call(chat, "What is 2 + 2?")
})

# Trace a tool function call
with_trace("tool-run", {
  result <- trace_tool_call("add", function(a, b) a + b, 3, 4)
})

# Trace a guardrail check
with_trace("guard-run", {
  result <- trace_guardrail("length_check", function(x) nchar(x) < 1000, "input")
})

# Trace a securer sandbox execution (requires securer)
session <- securer::SecureSession$new()
with_trace("sandbox-run", {
  result <- trace_execution(session, "1 + 1")
})
session$close()
```

### Exporters

Write traces to JSONL files, print to console, or combine multiple
exporters:

``` r
# JSONL exporter -- one JSON object per line
exp <- jsonl_exporter("traces.jsonl")
with_trace("my-run", exporter = exp, {
  with_span("step-1", type = "tool", { 42 })
})

# Console exporter -- human-readable summary
with_trace("my-run", exporter = console_exporter(verbose = TRUE), {
  with_span("step-1", type = "tool", { 42 })
})

# Multi-exporter -- fan out to several destinations
combined <- multi_exporter(
  console_exporter(verbose = FALSE),
  jsonl_exporter("traces.jsonl")
)
with_trace("my-run", exporter = combined, {
  with_span("step-1", type = "tool", { 42 })
})

# Set a default exporter for all with_trace() calls
set_default_exporter(jsonl_exporter("all-traces.jsonl"))
```

### Prometheus

Expose trace metrics in Prometheus text exposition format for scraping
by Prometheus, Grafana, or any compatible monitoring system:

``` r
# Collect metrics from a trace into a registry
reg <- prometheus_registry()
tr <- Trace$new("demo")
tr$start()
s <- Span$new("llm-step", type = "llm")
s$start()
s$set_model("gpt-4o")
s$set_tokens(input = 100L, output = 50L)
s$end()
tr$add_span(s)
tr$end()

prometheus_metrics(tr, reg)
cat(format_prometheus(reg))

# Or use the prometheus_exporter() with with_trace()
exp <- prometheus_exporter()
with_trace("agent-run", exporter = exp, {
  with_span("call", type = "llm", {
    record_tokens(500, 200, model = "gpt-4o")
  })
})

# Serve a /metrics HTTP endpoint (requires httpuv)
srv <- serve_prometheus(reg, port = 9090)
# Scrape http://localhost:9090/metrics
httpuv::stopServer(srv)
```

## Documentation

securetrace includes three vignettes:

- [`vignette("securetrace")`](https://ian-flores.github.io/securetrace/articles/securetrace.md)
  – Getting Started with securetrace
- [`vignette("observability")`](https://ian-flores.github.io/securetrace/articles/observability.md)
  – Observability Integration
- [`vignette("cloud-native")`](https://ian-flores.github.io/securetrace/articles/cloud-native.md)
  – Cloud-Native Observability

Full reference documentation is available at the pkgdown site:
<https://ian-flores.github.io/securetrace/>

## Contributing

Contributions are welcome! Please file issues on GitHub and submit pull
requests.

## License

MIT
