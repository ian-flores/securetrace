# Rate-Limiting Sampler

Records at most N traces per second.

## Usage

``` r
sampler_rate_limiting(max_per_second = 10)
```

## Arguments

- max_per_second:

  Maximum traces per second. Default 10.

## Value

A `securetrace_sampler`.

## Examples

``` r
s <- sampler_rate_limiting(5)
```
