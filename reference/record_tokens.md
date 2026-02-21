# Record Token Usage on the Current Span

Convenience wrapper that records input and output token counts on the
currently active span from the trace context.

## Usage

``` r
record_tokens(input_tokens, output_tokens, model = NULL)
```

## Arguments

- input_tokens:

  Number of input tokens.

- output_tokens:

  Number of output tokens.

- model:

  Optional model name string.

## Value

Invisible `NULL`.
