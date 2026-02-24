# Tracing orchestr Workflows

``` r
library(securetrace)
library(orchestr)
```

## trace_graph()

Auto-instrument every node in a compiled graph – one span per node, zero
handler changes.

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

## trace_agent()

Wrap a single agent invocation; model name and token deltas are
extracted from the ellmer chat object automatically.

``` r
chat <- ellmer::chat_openai(model = "gpt-4o")
assistant <- agent("assistant", chat)
response <- trace_agent(assistant, "Summarize the iris dataset.")
```

## With exporters

Pass an exporter to persist the trace as JSONL.

``` r
exp <- jsonl_exporter(tempfile(fileext = ".jsonl"))
result <- trace_graph(graph, list(data = NULL, summary = NULL), exporter = exp)

# Or set a default for all traces
set_default_exporter(jsonl_exporter(tempfile(fileext = ".jsonl")))
result <- trace_graph(graph, list(data = NULL, summary = NULL))
```

## Cost tracking

Aggregate costs across all spans. Useful for ReAct loops where call
count is unpredictable.

``` r
chat <- ellmer::chat_openai(model = "gpt-4o")
graph <- react_graph(agent("analyst", chat))
result <- trace_graph(graph, list(messages = list("Analyze sales trends.")))
trace_total_cost(current_trace())
```

## Manual spans in nodes

Add
[`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
inside a handler for sub-node detail. Combine with
[`trace_graph()`](https://ian-flores.github.io/securetrace/reference/trace_graph.md)
freely.

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

with_trace("custom-graph-run", {
  gb$compile()$invoke(list(result = NULL))
})
#> $result
#> [1] "analysis complete"
```
