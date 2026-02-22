# Get the Current Active Span

Get the Current Active Span

## Usage

``` r
current_span()
```

## Value

The active `Span` object, or `NULL` if none.

## Examples

``` r
# Outside a span, returns NULL
current_span()
#> NULL

# Inside a span, returns the active Span
with_trace("demo", {
  with_span("step", type = "custom", {
    s <- current_span()
    s$name
  })
})
#> [1] "step"
```
