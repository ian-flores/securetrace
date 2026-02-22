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
#>  [1] "claude-opus-4-6"            "claude-sonnet-4-5"         
#>  [3] "claude-haiku-4-5"           "claude-3-5-sonnet-20241022"
#>  [5] "claude-3-5-haiku-20241022"  "claude-3-opus-20240229"    
#>  [7] "claude-3-sonnet-20240229"   "claude-3-haiku-20240307"   
#>  [9] "gpt-4o"                     "gpt-4o-mini"               
#> [11] "gpt-4o-2024-11-20"          "gpt-4-turbo"               
#> [13] "gpt-4"                      "gpt-3.5-turbo"             
#> [15] "o1"                         "o1-mini"                   
#> [17] "o3-mini"                    "gemini-2.0-flash"          
#> [19] "gemini-1.5-pro"             "gemini-1.5-flash"          
#> [21] "gemini-1.5-flash-8b"        "mistral-large-latest"      
#> [23] "mistral-small-latest"       "codestral-latest"          
#> [25] "deepseek-chat"              "deepseek-reasoner"         
#> [27] "my-local-model"            
costs[["gpt-4o"]]
#> $input
#> [1] 2.5
#> 
#> $output
#> [1] 10
#> 
```
