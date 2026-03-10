# Changelog

## securetrace 0.2.0

### New features

- **Sampling**: Control which traces are recorded with pluggable
  samplers.
  [`sampler_always_on()`](https://ian-flores.github.io/securetrace/reference/sampler_always_on.md),
  [`sampler_always_off()`](https://ian-flores.github.io/securetrace/reference/sampler_always_off.md),
  [`sampler_probability()`](https://ian-flores.github.io/securetrace/reference/sampler_probability.md),
  and
  [`sampler_rate_limiting()`](https://ian-flores.github.io/securetrace/reference/sampler_rate_limiting.md)
  cover common strategies. Set the default with
  [`set_default_sampler()`](https://ian-flores.github.io/securetrace/reference/set_default_sampler.md).

- **Span attributes**: `Span$set_attribute(key, value)` provides a typed
  key-value attribute API, separate from the freeform `metadata` field.
  Attributes are included in `to_list()` and all exporters.

- **Resource attributes**:
  [`resource()`](https://ian-flores.github.io/securetrace/reference/resource.md)
  and
  [`set_resource()`](https://ian-flores.github.io/securetrace/reference/set_resource.md)
  attach service-level metadata (service name, version, deployment
  environment) to all traces. Resources appear in exported trace data.

### Ecosystem integration

- All ecosystem packages (secureguard, securetools, securer,
  securecontext, securebench) now emit spans automatically when
  securetrace is installed and a trace is active. No manual
  instrumentation needed.

- Pre-built Grafana dashboard and docker-compose setup for turnkey
  observability with Prometheus metrics.

## securetrace 0.1.0

- Initial CRAN release.
- Core tracing: `Trace` and `Span` R6 classes for structured
  observability.
- Trace events via S7-based `securetrace_event` class.
- Token and cost accounting with built-in pricing for OpenAI, Anthropic,
  Google Gemini, Mistral, and DeepSeek models.
- Cloud provider model alias resolution (AWS Bedrock, Google Vertex AI).
- Exporters: JSONL, console, multi-exporter, and OTLP JSON for
  OpenTelemetry-compatible collectors (Jaeger, Grafana Tempo).
- OTLP batching with configurable buffer size and retry with exponential
  backoff for transient HTTP errors.
- Prometheus metrics: registry, text exposition format, and HTTP
  `/metrics` endpoint via httpuv.
- W3C Trace Context propagation:
  [`traceparent()`](https://ian-flores.github.io/securetrace/reference/traceparent.md),
  [`parse_traceparent()`](https://ian-flores.github.io/securetrace/reference/parse_traceparent.md),
  [`inject_headers()`](https://ian-flores.github.io/securetrace/reference/inject_headers.md),
  and
  [`extract_trace_context()`](https://ian-flores.github.io/securetrace/reference/extract_trace_context.md).
- Integration helpers for ellmer
  ([`trace_llm_call()`](https://ian-flores.github.io/securetrace/reference/trace_llm_call.md)),
  securer
  ([`trace_execution()`](https://ian-flores.github.io/securetrace/reference/trace_execution.md)),
  secureguard
  ([`trace_guardrail()`](https://ian-flores.github.io/securetrace/reference/trace_guardrail.md)),
  and orchestr
  ([`trace_graph()`](https://ian-flores.github.io/securetrace/reference/trace_graph.md),
  [`trace_agent()`](https://ian-flores.github.io/securetrace/reference/trace_agent.md)).
- Context management:
  [`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md),
  [`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md),
  [`current_trace()`](https://ian-flores.github.io/securetrace/reference/current_trace.md),
  [`current_span()`](https://ian-flores.github.io/securetrace/reference/current_span.md),
  and
  [`set_default_exporter()`](https://ian-flores.github.io/securetrace/reference/set_default_exporter.md).
