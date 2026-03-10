# Set the Default Sampler

Set the Default Sampler

## Usage

``` r
set_default_sampler(sampler)
```

## Arguments

- sampler:

  A `securetrace_sampler` object.

## Value

Invisible `NULL`.

## Examples

``` r
# Only record 50% of traces
set_default_sampler(sampler_probability(0.5))

# Reset to record everything
set_default_sampler(sampler_always_on())
```
