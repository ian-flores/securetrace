# Get the Current Active Trace

Get the Current Active Trace

## Usage

``` r
current_trace()
```

## Value

The active `Trace` object, or `NULL` if none.

## Examples

``` r
# Outside a trace, returns NULL
current_trace()
#> NULL

# Inside a trace, returns the active Trace
with_trace("demo", {
  tr <- current_trace()
  tr$name
})
#> [1] "demo"
```
