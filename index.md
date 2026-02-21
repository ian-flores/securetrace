# securetrace

> \[!CAUTION\] **Alpha software.** This package is part of a broader
> effort by [Ian Flores Siaca](https://github.com/ian-flores) to develop
> proper AI infrastructure for the R ecosystem. It is under active
> development and should **not** be used in production until an official
> release is published. APIs may change without notice.

Observability and tracing for R LLM agent workflows. Structured traces
with spans, token/cost accounting, latency monitoring, and JSONL export.

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

## License

MIT
