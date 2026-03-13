# Flush Buffered OTLP Traces

Forces immediate sending of any traces buffered in an OTLP exporter.

## Usage

``` r
flush_otlp(exporter)
```

## Arguments

- exporter:

  An OTLP exporter created by
  [`exporter_otlp()`](https://ian-flores.github.io/securetrace/reference/exporter_otlp.md).

## Value

Invisible `NULL`.

## Examples

``` r
if (FALSE) { # \dontrun{
exp <- exporter_otlp(batch_size = 50L)
# ... export some traces ...
flush_otlp(exp)
} # }
```
