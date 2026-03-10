# Probability Sampler

Records traces with a given probability.

## Usage

``` r
sampler_probability(rate = 1)
```

## Arguments

- rate:

  Sampling rate between 0 and 1. Default 1.0 (all traces).

## Value

A `securetrace_sampler`.

## Examples

``` r
# Record 10% of traces
s <- sampler_probability(0.1)
```
