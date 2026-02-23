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
