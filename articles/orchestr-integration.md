# Tracing orchestr Workflows

## Why Auto-Instrument orchestr?

Graph-based agent orchestration (pipelines, ReAct loops, supervisor
routing) involves many moving parts: nodes invoke LLMs, call tools,
check guardrails, and route to other nodes based on conditions. When
something goes wrong – unexpected cost, wrong routing, a node that runs
longer than expected – you need to see exactly which nodes executed, in
what order, and what each one did.

Manually wrapping every node handler in
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
calls is tedious and error-prone. securetrace’s orchestr integration
solves this by automatically creating a span for each node execution
when you use
[`trace_graph()`](https://ian-flores.github.io/securetrace/reference/trace_graph.md).
One function call gives you full per-node visibility without modifying
any node handlers.

    trace_graph(graph, initial_state)

    Execution flow with automatic spans:
    ================================================

    Trace: "graph-execution"
    |
    |-- Span: "node:fetch"       (step 1)
    |   '-- metadata: {node: "fetch", step: 1}
    |
    |-- Span: "node:analyze"     (step 2)
    |   |-- tokens: 2000 in / 500 out
    |   '-- metadata: {node: "analyze", step: 2}
    |
    |-- Span: "node:summarize"   (step 3)
    |   |-- tokens: 1000 in / 200 out
    |   '-- metadata: {node: "summarize", step: 3}
    |
    '-- (END)

Each node gets its own span named `"node:{name}"`, with metadata
recording the node name and step number. If nodes make LLM calls that
record tokens, those tokens appear on the correct span automatically.

## Setup

securetrace integrates with
[orchestr](https://github.com/ian-flores/orchestr) to automatically
trace graph executions and agent invocations. Install both packages to
use these features:

``` r
library(securetrace)
library(orchestr)
```

## Tracing a Graph

[`trace_graph()`](https://ian-flores.github.io/securetrace/reference/trace_graph.md)
wraps `graph$invoke()` and creates a child span for each node that
executes. Build a graph with
[`graph_builder()`](https://ian-flores.github.io/orchestr/reference/graph_builder.html),
then pass the compiled graph and initial state:

``` r
gb <- graph_builder()
gb$add_node("fetch", function(state, config) list(data = mtcars[1:5, ]))
gb$add_node("summarize", function(state, config) list(summary = summary(state$data)))
gb$add_edge("fetch", "summarize")
gb$add_edge("summarize", END)
gb$set_entry_point("fetch")
graph <- gb$compile()

result <- trace_graph(graph, list(data = NULL, summary = NULL))
```

Each node execution is captured as a span named `"node:{name}"`, with
metadata recording the node name and step number.

## Tracing an Agent

[`trace_agent()`](https://ian-flores.github.io/securetrace/reference/trace_agent.md)
wraps a single `agent$invoke()` call. It auto-extracts the model name
and token usage from the underlying ellmer Chat object:

``` r
chat <- ellmer::chat_openai(model = "gpt-4o")
assistant <- agent("assistant", chat)

response <- trace_agent(assistant, "Summarize the iris dataset.")
```

Token deltas are computed by comparing the chat’s token state before and
after the invocation, so multi-turn agents report only the tokens used
per call.

## Combining with Exporters

Pass an exporter to
[`trace_graph()`](https://ian-flores.github.io/securetrace/reference/trace_graph.md)
to persist the full trace as JSONL:

``` r
exp <- jsonl_exporter(tempfile(fileext = ".jsonl"))
result <- trace_graph(graph, list(data = NULL, summary = NULL), exporter = exp)

# Or set a default exporter for all traces
exp2 <- jsonl_exporter(tempfile(fileext = ".jsonl"))
set_default_exporter(exp2)
result <- trace_graph(graph, list(data = NULL, summary = NULL))
```

## Cost Tracking

When graph nodes make LLM calls that record model and token information,
[`trace_total_cost()`](https://ian-flores.github.io/securetrace/reference/trace_total_cost.md)
aggregates costs across all spans. This is particularly valuable for
ReAct loops where the number of LLM calls is unpredictable:

``` r
chat <- ellmer::chat_openai(model = "gpt-4o")
graph <- react_graph(agent("analyst", chat))

result <- trace_graph(graph, list(messages = list("Analyze sales trends.")))
tr <- current_trace()
trace_total_cost(tr)
#> [1] 0.00045
```

## When to Use trace_graph vs Manual Spans

Both approaches give you trace data, but they serve different needs:

**Use
[`trace_graph()`](https://ian-flores.github.io/securetrace/reference/trace_graph.md)**
when you want automatic, zero-effort instrumentation of an entire graph
execution. Every node gets a span without any changes to your node
handlers. This is the right choice for production monitoring, cost
tracking, and general observability where you want to see the full
picture with minimal code.

**Use manual
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
inside node handlers** when you need finer-grained control: custom span
names, sub-spans within a single node, domain-specific metrics, or when
you want to trace only certain nodes. This is common during development
when you are debugging a specific node’s behavior.

You can combine both approaches: use
[`trace_graph()`](https://ian-flores.github.io/securetrace/reference/trace_graph.md)
for the overall structure and add manual
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
calls inside specific nodes that need extra detail.

## Manual Instrumentation

For finer control, use
[`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md)
and
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
directly inside graph node handlers instead of
[`trace_graph()`](https://ian-flores.github.io/securetrace/reference/trace_graph.md):

``` r
analyze_node <- function(state, config) {
  with_span("llm-call", type = "llm", {
    record_tokens(500, 120, model = "claude-sonnet-4-5")
    list(result = "analysis complete")
  })
}

gb <- graph_builder()
gb$add_node("analyze", analyze_node)
gb$add_edge("analyze", END)
gb$set_entry_point("analyze")
graph <- gb$compile()

with_trace("custom-graph-run", {
  graph$invoke(list(result = NULL))
})
#> $result
#> [1] "analysis complete"
```

This lets you control span names, types, and metadata at each step, and
is useful when you need to trace sub-operations within a single node.
