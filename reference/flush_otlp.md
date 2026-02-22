# Flush Buffered OTLP Traces

Forces immediate sending of any traces buffered in an OTLP exporter.

## Usage

``` r
flush_otlp(exporter)
```

## Arguments

- exporter:

  An OTLP exporter created by
  [`otlp_exporter()`](https://ian-flores.github.io/securetrace/reference/otlp_exporter.md).

## Value

Invisible `NULL`.

## Examples

``` r
if (FALSE) { # \dontrun{
exp <- otlp_exporter(batch_size = 50L)
# ... export some traces ...
flush_otlp(exp)
} # }
```
