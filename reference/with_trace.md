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
# Trace a block of code
result <- with_trace("my-operation", {
  Sys.sleep(0.01)
  1 + 1
})
result
#> [1] 2

# With an exporter
result <- with_trace("traced-op", {
  10 * 2
}, exporter = console_exporter(verbose = FALSE))
#> --- Trace: traced-op ---
#> Status: completed
#> Duration: 0.00s
#> Spans: 0
```
