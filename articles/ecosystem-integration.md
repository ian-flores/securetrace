# Ecosystem Integration: how sibling packages emit spans

## Overview

securetrace is the observability backbone for the secure-r-dev
ecosystem. Each sibling package (`securer`, `securetools`,
`secureguard`, `securecontext`, `orchestr`, `securebench`) can emit
structured spans into any trace context you open with \[with_trace()\] —
no plumbing required on your side. This vignette documents **the
contract** the siblings use so you know what to expect and how to
instrument your own code the same way.

## The contract

securetrace ships a single private helper that every sibling calls:

``` r
.trace_active()  # TRUE iff there is a current_trace() on the stack
```

Each sibling guards every instrumented operation with this helper. If a
trace is active, the operation is wrapped in
`securetrace::with_span(name, type, { ... })` and one or more
`.span_event()` attributes are attached. If no trace is active, the
operation runs unchanged — zero overhead.

That means:

- The sibling packages only **Suggest** securetrace (soft dependency).
- Nothing emits spans unless *you* opened a trace with \[with_trace()\]
  (or one of the convenience helpers like \[trace_graph()\] or
  \[trace_agent()\]).
- Cross-package traces work naturally: if you open a trace and call code
  that crosses package boundaries, each package’s spans nest under
  yours.

## Span taxonomy by package

The table below is the canonical list of spans emitted by each sibling
as of the current release. Span names follow `package.operation` and
`type` follows the \[Span\] taxonomy (`llm`, `tool`, `guardrail`,
`custom`).

| Package         | Span name                            | `type`      | Triggered by                                                                                                     |
|-----------------|--------------------------------------|-------------|------------------------------------------------------------------------------------------------------------------|
| `securer`       | `securer.execute`                    | `custom`    | `SecureSession$execute()`, `execute_r()`                                                                         |
| `securer`       | `securer.tool_call`                  | `tool`      | Tool invocation inside a secure session                                                                          |
| `securetools`   | `tool.<tool_name>`                   | `tool`      | `tool_calculator()`, `tool_query_sql()`, …                                                                       |
| `secureguard`   | `guardrail.<name>`                   | `guardrail` | `run_guardrail()`, `check_all()`                                                                                 |
| `secureguard`   | `pipeline.check_{input,code,output}` | `guardrail` | `secure_pipeline()` stages                                                                                       |
| `securecontext` | `context.embed_tfidf`                | `custom`    | `embed_tfidf()`                                                                                                  |
| `securecontext` | `context.embed_texts`                | `custom`    | `embed_texts()`                                                                                                  |
| `securecontext` | `context.vector_add`                 | `custom`    | `vector_store$add()`                                                                                             |
| `securecontext` | `context.vector_search`              | `custom`    | `vector_store$search()`                                                                                          |
| `securecontext` | `context.context_for_chat`           | `custom`    | `context_for_chat()`                                                                                             |
| `orchestr`      | `agent.invoke`                       | `custom`    | `Agent$invoke()` under [`trace_agent()`](https://ian-flores.github.io/securetrace/reference/trace_agent.md)      |
| `orchestr`      | `graph.node.<name>`                  | `custom`    | `AgentGraph$invoke()` under [`trace_graph()`](https://ian-flores.github.io/securetrace/reference/trace_graph.md) |
| `securebench`   | `bench.guardrail_eval`               | `custom`    | `guardrail_eval()`, `benchmark_guardrail()`                                                                      |
| `securebench`   | `bench.guardrail_metrics`            | `custom`    | `guardrail_metrics()`                                                                                            |

If a span you expect is missing, check that (a) the sibling package is
installed, and (b) you actually opened a trace around the call. The
simplest smoke-test is:

``` r
result <- securetrace::with_trace("smoke", {
  securetools::tool_calculator()@fn("2 + 2")
})
length(result$spans)  # should be > 0 if securetools is installed
```

## Writing siblings of your own

If you build a package on top of the ecosystem and want to emit spans
into the same traces, follow the same pattern the siblings use:

``` r
#' @keywords internal
.trace_active <- function() {
  requireNamespace("securetrace", quietly = TRUE) &&
    !is.null(securetrace::current_trace())
}

my_operation <- function(args) {
  .do <- function() {
    # ... real work ...
  }
  if (.trace_active()) {
    securetrace::with_span("mypkg.operation", type = "custom", {
      result <- .do()
      securetrace:::.span_event("mypkg.operation.complete", list(
        size = length(result)
      ))
      result
    })
  } else {
    .do()
  }
}
```

This keeps securetrace a Suggests-only dependency and avoids any
overhead when consumers are not tracing.

## See also

- [`vignette("orchestr-integration")`](https://ian-flores.github.io/securetrace/articles/orchestr-integration.md)
  — deeper dive on the orchestr-only helpers
  [`trace_graph()`](https://ian-flores.github.io/securetrace/reference/trace_graph.md)
  and
  [`trace_agent()`](https://ian-flores.github.io/securetrace/reference/trace_agent.md).
- [`vignette("exporters")`](https://ian-flores.github.io/securetrace/articles/exporters.md)
  — how to ship spans to JSONL, OTLP, or Prometheus once they’ve been
  collected.
- [`vignette("cloud-native")`](https://ian-flores.github.io/securetrace/articles/cloud-native.md)
  — distributed tracing with W3C traceparent headers.
