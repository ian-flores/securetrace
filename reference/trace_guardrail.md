# Trace a Guardrail Check

Wraps a secureguard guardrail check with a span. Requires the
secureguard package.

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
