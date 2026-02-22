# Inject Trace Context into HTTP Headers

Adds a `traceparent` header to an existing set of HTTP headers using the
current active trace and span context.

## Usage

``` r
inject_headers(headers = list())
```

## Arguments

- headers:

  A named list of HTTP headers. Default
  [`list()`](https://rdrr.io/r/base/list.html).

## Value

The headers list with `traceparent` added, or unchanged if no active
trace/span context exists.

## Examples

``` r
# Inside an active trace and span
with_trace("http-call", {
  with_span("request", type = "tool", {
    headers <- inject_headers(list("Content-Type" = "application/json"))
    headers$traceparent
  })
})
#> [1] "00-d14452077d57df21eebfba769479e4f2-30c8c16c2e9720e0-01"
```
