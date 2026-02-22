# Add a Model Alias

Register a custom alias mapping from a provider-specific model ID to a
canonical model name. This is useful for cloud provider variants or
custom deployment names.

## Usage

``` r
add_model_alias(alias, canonical)
```

## Arguments

- alias:

  The provider-specific model ID string (e.g., a Bedrock or Vertex AI
  model ID, or a custom deployment name).

- canonical:

  The canonical model name that `alias` should resolve to. This should
  match a name in the cost registry.

## Value

Invisible `NULL`.

## Examples

``` r
# Map a custom deployment to a known model
add_model_alias("my-azure-gpt4o-deployment", "gpt-4o")
resolve_model("my-azure-gpt4o-deployment")
#> [1] "gpt-4o"
```
