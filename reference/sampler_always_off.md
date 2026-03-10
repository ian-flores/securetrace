# Always-Off Sampler

Drops every trace. Useful for disabling tracing entirely.

## Usage

``` r
sampler_always_off()
```

## Value

A `securetrace_sampler` that always returns `FALSE`.

## Examples

``` r
s <- sampler_always_off()
s@should_sample("test", list())
#> [1] FALSE
```
