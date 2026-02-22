# Trace an orchestr Graph Execution

Wraps an orchestr `AgentGraph`'s `$invoke()` call with automatic
tracing. Each node execution is captured as a child span named
`"node:{name}"`. Requires the orchestr package.

## Usage

``` r
trace_graph(graph, input, ..., exporter = NULL)
```

## Arguments

- graph:

  An orchestr `AgentGraph` object.

- input:

  Named list of initial state passed to `graph$invoke()`.

- ...:

  Additional arguments passed to `graph$invoke()`.

- exporter:

  Optional exporter for the trace. If `NULL`, uses the default exporter
  (if set via
  [`set_default_exporter()`](https://ian-flores.github.io/securetrace/reference/set_default_exporter.md)).

## Value

The graph result (final state as a named list).

## Examples

``` r
if (FALSE) { # \dontrun{
# Requires orchestr package
gb <- orchestr::graph_builder()
gb$add_node("step", function(state, config) list(x = state$x + 1))
gb$add_edge("step", orchestr::END)
gb$set_entry_point("step")
graph <- gb$compile()

result <- trace_graph(graph, list(x = 1))
} # }
```
