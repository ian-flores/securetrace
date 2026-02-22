# Extract Trace Context from HTTP Headers

Looks for a `traceparent` header (case-insensitive) in a named list of
HTTP headers and parses it.

## Usage

``` r
extract_trace_context(headers)
```

## Arguments

- headers:

  A named list of HTTP headers.

## Value

A parsed trace context (named list with `version`, `trace_id`,
`span_id`, `sampled`), or `NULL` if no valid traceparent is found.

## Examples

``` r
headers <- list(
  "Content-Type" = "application/json",
  traceparent = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
)
ctx <- extract_trace_context(headers)
ctx$trace_id
#> [1] "4bf92f3577b34da6a3ce929d0e0e4736"
```
