# Get Known Model Costs

Returns a named list of model pricing (per 1M tokens).

## Usage

``` r
model_costs()
```

## Value

A named list where each element has `input` and `output` prices.

## Examples

``` r
costs <- model_costs()
names(costs)
#> [1] "claude-opus-4-6"   "claude-sonnet-4-5" "claude-haiku-4-5" 
#> [4] "gpt-4o"            "gpt-4o-mini"       "my-local-model"   
costs[["gpt-4o"]]
#> $input
#> [1] 2.5
#> 
#> $output
#> [1] 10
#> 
```
