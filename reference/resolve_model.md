# Resolve a Model Name

Maps cloud provider model IDs (e.g., AWS Bedrock, Google Vertex AI) to
canonical model names used in the cost registry. Also passes through
names that are already canonical or unknown.

## Usage

``` r
resolve_model(model)
```

## Arguments

- model:

  A model name or provider-specific model ID string.

## Value

The canonical model name string.

## Details

Resolution order:

1.  Check the alias registry for an exact match

2.  Check if already a canonical model name

3.  Try regex normalization for Bedrock pattern
    (`provider.model-version:N`)

4.  Try regex normalization for Vertex pattern
    (`publishers/.../models/model@date`)

5.  Fall back to returning the original string unchanged

## Examples

``` r
# Already canonical -- returned as-is
resolve_model("gpt-4o")
#> [1] "gpt-4o"

# Bedrock alias
resolve_model("anthropic.claude-3-sonnet-20240229-v1:0")
#> [1] "claude-3-sonnet-20240229"

# Unknown model -- returned as-is
resolve_model("my-custom-model")
#> [1] "my-custom-model"
```
