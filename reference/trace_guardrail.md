# Trace a Guardrail Check

Wraps a secureguard guardrail check with a span. If `guardrail` is a
secureguard Guard object (S7 class `secureguard`), its `check_fn` is
called and structured result metadata (pass/fail, score, guard name) is
recorded as span events. Otherwise, `guardrail` is called as a plain
function (backward-compatible behavior).

## Usage

``` r
trace_guardrail(name, guardrail, x)
```

## Arguments

- name:

  Name of the guardrail.

- guardrail:

  The guardrail object or function.

- x:

  Input to check.

## Value

The guardrail result.

## Examples

``` r
# Trace a guardrail check function
check_length <- function(x) nchar(x) < 1000
with_trace("guard-demo", {
  result <- trace_guardrail("length_check", check_length, "short input")
  result
})
#> [1] TRUE
```
