# securetrace -- Development Guide

## What This Is

An R package for observability and tracing of LLM agent workflows. Structured traces with spans, token/cost accounting, latency monitoring, and JSONL export.

## Architecture

```
Trace (R6) -- root container for a full agent run
  Span (R6) -- single operation (LLM call, tool use, guardrail check)
    Event (S3) -- discrete point-in-time within a span
    Metrics -- token counts, latency, custom values
  Cost -- model pricing tables + calculation
  Exporter (S3) -- JSONL, console, multi-exporter
  Context -- trace/span stack via module-level environment
  Integration -- auto-instrumentation for ellmer/securer/secureguard
```

## Key Files

- `R/trace.R` -- Trace R6 class
- `R/span.R` -- Span R6 class
- `R/event.R` -- trace_event() S3 constructor
- `R/metrics.R` -- record_tokens(), record_latency(), record_metric()
- `R/cost.R` -- model_costs(), calculate_cost(), add_model_cost()
- `R/exporter.R` -- jsonl_exporter(), console_exporter(), multi_exporter()
- `R/context.R` -- with_trace(), with_span(), current_trace(), current_span()
- `R/integration.R` -- trace_llm_call(), trace_tool_call(), trace_guardrail(), trace_execution()

## Development Commands

```bash
Rscript -e "devtools::test('.')"
Rscript -e "devtools::check('.')"
Rscript -e "devtools::document('.')"
```

## Test Structure

- `test-trace.R` -- Trace lifecycle, serialization, summary
- `test-span.R` -- Span lifecycle, tokens, events, metrics
- `test-event.R` -- Event creation, S3 class
- `test-metrics.R` -- Convenience metric recording
- `test-cost.R` -- Model pricing, cost calculation
- `test-exporter.R` -- JSONL, console, multi-exporter
- `test-context.R` -- Trace/span context stacking, cleanup
- `test-integration.R` -- Integration wrapper functions
