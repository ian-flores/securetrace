# Parse a W3C Traceparent Header

Parses a `traceparent` header string into its component fields according
to the W3C Trace Context specification.

## Usage

``` r
parse_traceparent(header)
```

## Arguments

- header:

  Character. A traceparent header string.

## Value

A named list with elements `version`, `trace_id`, `span_id`, and
`sampled` (logical), or `NULL` if the header is invalid.

## Examples

``` r
parsed <- parse_traceparent(
  "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
)
parsed$trace_id
#> [1] "4bf92f3577b34da6a3ce929d0e0e4736"
parsed$sampled
#> [1] TRUE

# Invalid header returns NULL
parse_traceparent("invalid")
#> Warning: Invalid traceparent header format: "invalid"
#> NULL
```
