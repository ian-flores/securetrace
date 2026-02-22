# securetrace

> [!CAUTION]
> **Alpha software.** This package is part of a broader effort by [Ian Flores Siaca](https://github.com/ian-flores) to develop proper AI infrastructure for the R ecosystem. It is under active development and should **not** be used in production until an official release is published. APIs may change without notice.

Observability and tracing for R LLM agent workflows. Structured traces with spans,
token/cost accounting, latency monitoring, and JSONL export.

## Part of the secure-r-dev Ecosystem

securetrace is part of a 7-package ecosystem for building governed AI agents in R:

```
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
```

securetrace provides the observability layer at the bottom of the stack. It instruments LLM calls, tool executions, and guardrail checks with structured traces, token/cost accounting, and JSONL export -- giving visibility into what your agents are doing and how much it costs.

| Package | Role |
|---------|------|
| [securer](https://github.com/ian-flores/securer) | Sandboxed R execution with tool-call IPC |
| [securetools](https://github.com/ian-flores/securetools) | Pre-built security-hardened tool definitions |
| [secureguard](https://github.com/ian-flores/secureguard) | Input/code/output guardrails (injection, PII, secrets) |
| [orchestr](https://github.com/ian-flores/orchestr) | Graph-based agent orchestration |
| [securecontext](https://github.com/ian-flores/securecontext) | Document chunking, embeddings, RAG retrieval |
| [securetrace](https://github.com/ian-flores/securetrace) | Structured tracing, token/cost accounting, JSONL export |
| [securebench](https://github.com/ian-flores/securebench) | Guardrail benchmarking with precision/recall/F1 metrics |

## Installation

```r
# install.packages("pak")
pak::pak("ian-flores/securetrace")
```

## Quick Start

```r
library(securetrace)

result <- with_trace("my-agent", exporter = jsonl_exporter("traces.jsonl"), {
  with_span("llm-call", type = "llm", {
    record_tokens(1500, 300, model = "claude-sonnet-4-5")
    "The answer is 42"
  })
})
```

## Features

- **Structured traces** -- OpenTelemetry-inspired traces and spans for R
- **Token accounting** -- Track input/output tokens per span
- **Cost calculation** -- Built-in pricing for Claude and GPT models
- **JSONL export** -- Write traces to structured log files
- **Context management** -- Automatic trace/span stacking with `with_trace()` / `with_span()`
- **Integration helpers** -- Wrappers for LLM calls, tool executions, and guardrail checks

## License

MIT
