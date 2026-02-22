# Trace a Tool Execution

Wraps a tool function call with a span.

## Usage

``` r
trace_tool_call(name, fn, ...)
```

## Arguments

- name:

  Name of the tool.

- fn:

  Function to execute.

- ...:

  Arguments passed to `fn`.

## Value

The result of `fn(...)`.

## Examples

``` r
# Trace a tool function call
with_trace("tool-demo", {
  result <- trace_tool_call("add", function(a, b) a + b, 3, 4)
  result
})
#> [1] 7
```
