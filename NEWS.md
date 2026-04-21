# securetrace 0.2.1

## Documentation

* New vignette `ecosystem-integration.Rmd` — the canonical reference
  for how sibling packages (securer, securetools, secureguard,
  securecontext, orchestr, securebench) emit spans into a securetrace
  context. Includes the span taxonomy table and a template for writing
  your own sibling-style instrumentation.

# securetrace 0.2.0

## New features

* **Sampling**: Control which traces are recorded with pluggable samplers.
  `sampler_always_on()`, `sampler_always_off()`, `sampler_probability()`,
  and `sampler_rate_limiting()` cover common strategies. Set the default
  with `set_default_sampler()`.

* **Span attributes**: `Span$set_attribute(key, value)` provides a typed
  key-value attribute API, separate from the freeform `metadata` field.
  Attributes are included in `to_list()` and all exporters.

* **Resource attributes**: `resource()` and `set_resource()` attach
  service-level metadata (service name, version, deployment environment)
  to all traces. Resources appear in exported trace data.

## Ecosystem integration

* All ecosystem packages (secureguard, securetools, securer, securecontext,
  securebench) now emit spans automatically when securetrace is installed
  and a trace is active. No manual instrumentation needed.

* Pre-built Grafana dashboard and docker-compose setup for turnkey
  observability with Prometheus metrics.

# securetrace 0.1.0

* Initial CRAN release.
* Core tracing: `Trace` and `Span` R6 classes for structured observability.
* Trace events via S7-based `securetrace_event` class.
* Token and cost accounting with built-in pricing for OpenAI, Anthropic,
  Google Gemini, Mistral, and DeepSeek models.
* Cloud provider model alias resolution (AWS Bedrock, Google Vertex AI).
* Exporters: JSONL, console, multi-exporter, and OTLP JSON for
  OpenTelemetry-compatible collectors (Jaeger, Grafana Tempo).
* OTLP batching with configurable buffer size and retry with exponential
  backoff for transient HTTP errors.
* Prometheus metrics: registry, text exposition format, and HTTP `/metrics`
  endpoint via httpuv.
* W3C Trace Context propagation: `traceparent()`, `parse_traceparent()`,
  `inject_headers()`, and `extract_trace_context()`.
* Integration helpers for ellmer (`trace_llm_call()`), securer
  (`trace_execution()`), secureguard (`trace_guardrail()`), and orchestr
  (`trace_graph()`, `trace_agent()`).
* Context management: `with_trace()`, `with_span()`, `current_trace()`,
  `current_span()`, and `set_default_exporter()`.
