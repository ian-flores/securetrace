# S7 class: securetrace_sampler

S7 class: securetrace_sampler

## Usage

``` r
securetrace_sampler(should_sample = function() NULL)
```

## Arguments

- should_sample:

  A function taking `name` and `metadata` arguments, returning `TRUE` to
  record or `FALSE` to drop the trace.

## Value

An S7 object of class `securetrace_sampler`.
