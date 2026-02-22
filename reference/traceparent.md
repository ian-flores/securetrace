# Generate a W3C Traceparent Header

Creates a W3C Trace Context `traceparent` header string from trace and
span identifiers. The format follows the [W3C Trace Context
specification](https://www.w3.org/TR/trace-context/).

## Usage

``` r
traceparent(trace_id, span_id, sampled = TRUE)
```

## Arguments

- trace_id:

  Character. A 32 lowercase hex character trace identifier.

- span_id:

  Character. A 16 lowercase hex character span identifier.

- sampled:

  Logical. Whether the trace is sampled. `TRUE` sets flags to `"01"`,
  `FALSE` sets flags to `"00"`. Default `TRUE`.

## Value

A character string in the format `"00-{trace_id}-{span_id}-{flags}"`.

## Examples

``` r
traceparent(
  "4bf92f3577b34da6a3ce929d0e0e4736",
  "00f067aa0ba902b7"
)
#> [1] "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"

traceparent(
  "4bf92f3577b34da6a3ce929d0e0e4736",
  "00f067aa0ba902b7",
  sampled = FALSE
)
#> [1] "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-00"
```
