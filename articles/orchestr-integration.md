# Tracing orchestr Workflows

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
exp <- jsonl_exporter("graph-traces.jsonl")
result <- trace_graph(graph, list(data = NULL, summary = NULL), exporter = exp)

# Or set a default exporter for all traces
set_default_exporter(exp)
result <- trace_graph(graph, list(data = NULL, summary = NULL))
```

## Cost Tracking

When graph nodes make LLM calls that record model and token information,
[`trace_total_cost()`](https://ian-flores.github.io/securetrace/reference/trace_total_cost.md)
aggregates costs across all spans:

``` r
chat <- ellmer::chat_openai(model = "gpt-4o")
graph <- react_graph(agent("analyst", chat))

result <- trace_graph(graph, list(messages = list("Analyze sales trends.")))
tr <- current_trace()
trace_total_cost(tr)
#> [1] 0.00045
```

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
```

This lets you control span names, types, and metadata at each step, and
is useful when you need to trace sub-operations within a single node.
