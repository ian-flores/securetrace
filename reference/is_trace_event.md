# Test if an Object is a Trace Event

Test if an Object is a Trace Event

## Usage

``` r
is_trace_event(x)
```

## Arguments

- x:

  Object to test.

## Value

Logical scalar.

## Examples

``` r
evt <- trace_event("test_event")
is_trace_event(evt)
#> [1] TRUE
is_trace_event("not an event")
#> [1] FALSE
```
