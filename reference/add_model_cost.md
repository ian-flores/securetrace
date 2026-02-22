# Add or Update Model Pricing

Register custom model pricing (per 1M tokens).

## Usage

``` r
add_model_cost(model, input_price, output_price)
```

## Arguments

- model:

  Model name string.

- input_price:

  Price per 1M input tokens in USD.

- output_price:

  Price per 1M output tokens in USD.

## Value

Invisible `NULL`.

## Examples

``` r
# Register a custom model's pricing
add_model_cost("my-local-model", input_price = 0, output_price = 0)
calculate_cost("my-local-model", 1000, 500)
#> [1] 0
```
