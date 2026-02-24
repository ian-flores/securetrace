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

## Thread Safety

The context stack is process-global, following R's standard
single-threaded assumption. Parallel workers spawned via future, callr,
or parallel receive isolated copies of the stack, so spans created in
those workers will **not** appear in the parent trace. This is
consistent with how [`options()`](https://rdrr.io/r/base/options.html),
[`par()`](https://rdrr.io/r/graphics/par.html), and
[`Sys.setenv()`](https://rdrr.io/r/base/Sys.setenv.html) behave in base
R.

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
