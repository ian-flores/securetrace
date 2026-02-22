# Calculate Cost for a Model Call

Calculate Cost for a Model Call

## Usage

``` r
calculate_cost(model, input_tokens, output_tokens)
```

## Arguments

- model:

  Model name string.

- input_tokens:

  Number of input tokens.

- output_tokens:

  Number of output tokens.

## Value

Numeric cost in USD.

## Examples

``` r
# Calculate cost for a GPT-4o call
calculate_cost("gpt-4o", input_tokens = 1000, output_tokens = 500)
#> [1] 0.0075

# Unknown models return 0
calculate_cost("unknown-model", 1000, 500)
#> [1] 0
```
