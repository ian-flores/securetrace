# Package index

## Traces and Spans

- [`Trace`](https://ian-flores.github.io/securetrace/reference/Trace.md)
  : Trace Class
- [`Span`](https://ian-flores.github.io/securetrace/reference/Span.md) :
  Span Class
- [`trace_event()`](https://ian-flores.github.io/securetrace/reference/trace_event.md)
  : Create a Trace Event
- [`securetrace_event()`](https://ian-flores.github.io/securetrace/reference/securetrace_event.md)
  : Trace Event Class (S7)
- [`is_trace_event()`](https://ian-flores.github.io/securetrace/reference/is_trace_event.md)
  : Test if an Object is a Trace Event

## Context Management

- [`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md)
  : Execute Code Within a Trace
- [`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
  : Execute Code Within a Span
- [`current_trace()`](https://ian-flores.github.io/securetrace/reference/current_trace.md)
  : Get the Current Active Trace
- [`current_span()`](https://ian-flores.github.io/securetrace/reference/current_span.md)
  : Get the Current Active Span
- [`set_default_exporter()`](https://ian-flores.github.io/securetrace/reference/set_default_exporter.md)
  : Set the Default Exporter

## Metrics

- [`record_tokens()`](https://ian-flores.github.io/securetrace/reference/record_tokens.md)
  : Record Token Usage on the Current Span
- [`record_latency()`](https://ian-flores.github.io/securetrace/reference/record_latency.md)
  : Record Latency on the Current Span
- [`record_metric()`](https://ian-flores.github.io/securetrace/reference/record_metric.md)
  : Record a Custom Metric on the Current Span

## Cost

- [`model_costs()`](https://ian-flores.github.io/securetrace/reference/model_costs.md)
  : Get Known Model Costs
- [`calculate_cost()`](https://ian-flores.github.io/securetrace/reference/calculate_cost.md)
  : Calculate Cost for a Model Call
- [`add_model_cost()`](https://ian-flores.github.io/securetrace/reference/add_model_cost.md)
  : Add or Update Model Pricing
- [`trace_total_cost()`](https://ian-flores.github.io/securetrace/reference/trace_total_cost.md)
  : Calculate Total Cost for a Trace
- [`resolve_model()`](https://ian-flores.github.io/securetrace/reference/resolve_model.md)
  : Resolve a Model Name
- [`add_model_alias()`](https://ian-flores.github.io/securetrace/reference/add_model_alias.md)
  : Add a Model Alias

## Exporters

- [`new_exporter()`](https://ian-flores.github.io/securetrace/reference/new_exporter.md)
  : Create a New Exporter
- [`securetrace_exporter()`](https://ian-flores.github.io/securetrace/reference/securetrace_exporter.md)
  : Exporter Class (S7)
- [`jsonl_exporter()`](https://ian-flores.github.io/securetrace/reference/jsonl_exporter.md)
  : JSONL Exporter
- [`console_exporter()`](https://ian-flores.github.io/securetrace/reference/console_exporter.md)
  : Console Exporter
- [`export_trace()`](https://ian-flores.github.io/securetrace/reference/export_trace.md)
  : Export a Trace
- [`multi_exporter()`](https://ian-flores.github.io/securetrace/reference/multi_exporter.md)
  : Multi-Exporter

## OTLP Export

- [`otlp_exporter()`](https://ian-flores.github.io/securetrace/reference/otlp_exporter.md)
  : OTLP JSON Exporter
- [`otlp_format_trace()`](https://ian-flores.github.io/securetrace/reference/otlp_format_trace.md)
  : Format a Trace as OTLP JSON

## Prometheus

- [`prometheus`](https://ian-flores.github.io/securetrace/reference/prometheus.md)
  : Prometheus Metrics for securetrace
- [`prometheus_registry()`](https://ian-flores.github.io/securetrace/reference/prometheus_registry.md)
  : Create a Prometheus Metrics Registry
- [`prometheus_metrics()`](https://ian-flores.github.io/securetrace/reference/prometheus_metrics.md)
  : Extract Prometheus Metrics from a Trace
- [`prometheus_exporter()`](https://ian-flores.github.io/securetrace/reference/prometheus_exporter.md)
  : Prometheus Exporter
- [`format_prometheus()`](https://ian-flores.github.io/securetrace/reference/format_prometheus.md)
  : Format Prometheus Text Exposition
- [`serve_prometheus()`](https://ian-flores.github.io/securetrace/reference/serve_prometheus.md)
  : Serve Prometheus Metrics via HTTP

## Context Propagation

- [`traceparent()`](https://ian-flores.github.io/securetrace/reference/traceparent.md)
  : Generate a W3C Traceparent Header
- [`parse_traceparent()`](https://ian-flores.github.io/securetrace/reference/parse_traceparent.md)
  : Parse a W3C Traceparent Header
- [`inject_headers()`](https://ian-flores.github.io/securetrace/reference/inject_headers.md)
  : Inject Trace Context into HTTP Headers
- [`extract_trace_context()`](https://ian-flores.github.io/securetrace/reference/extract_trace_context.md)
  : Extract Trace Context from HTTP Headers

## Integrations

- [`trace_llm_call()`](https://ian-flores.github.io/securetrace/reference/trace_llm_call.md)
  : Trace an LLM Call
- [`trace_tool_call()`](https://ian-flores.github.io/securetrace/reference/trace_tool_call.md)
  : Trace a Tool Execution
- [`trace_guardrail()`](https://ian-flores.github.io/securetrace/reference/trace_guardrail.md)
  : Trace a Guardrail Check
- [`trace_execution()`](https://ian-flores.github.io/securetrace/reference/trace_execution.md)
  : Trace a Secure Code Execution
