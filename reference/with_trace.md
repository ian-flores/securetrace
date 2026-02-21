# Execute Code Within a Trace

Creates a new trace, evaluates the expression, ends the trace, and
optionally exports it. The trace is available via
[`current_trace()`](https://ian-flores.github.io/securetrace/reference/current_trace.md)
during evaluation.

## Usage

``` r
with_trace(name, expr, ..., exporter = NULL)
```

## Arguments

- name:

  Name for the trace.

- expr:

  Expression to evaluate.

- ...:

  Additional arguments passed to `Trace$new()` as metadata.

- exporter:

  Optional exporter. If `NULL`, uses the default exporter (if set).

## Value

The result of evaluating `expr`.
