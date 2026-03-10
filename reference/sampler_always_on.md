# Always-On Sampler

Records every trace. This is the default.

## Usage

``` r
sampler_always_on()
```

## Value

A `securetrace_sampler` that always returns `TRUE`.

## Examples

``` r
s <- sampler_always_on()
s@should_sample("test", list())
#> [1] TRUE
```
