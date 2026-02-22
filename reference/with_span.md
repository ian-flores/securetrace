# Execute Code Within a Span

Creates a new span within the current trace, evaluates the expression,
and ends the span. The span is available via
[`current_span()`](https://ian-flores.github.io/securetrace/reference/current_span.md)
during evaluation.

## Usage

``` r
with_span(name, type = "custom", expr, ...)
```

## Arguments

- name:

  Name for the span.

- type:

  Span type. One of "llm", "tool", "guardrail", "custom".

- expr:

  Expression to evaluate.

- ...:

  Additional arguments stored as metadata on the span.

## Value

The result of evaluating `expr`.

## Examples

``` r
# Use with_span inside a trace
with_trace("example", {
  result <- with_span("compute", type = "tool", {
    sqrt(144)
  })
  result
})
#> [1] 12
```
