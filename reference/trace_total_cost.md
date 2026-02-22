# Calculate Total Cost for a Trace

Sums the cost of all spans in a trace that have a model recorded.

## Usage

``` r
trace_total_cost(trace)
```

## Arguments

- trace:

  A `Trace` object.

## Value

Numeric total cost in USD.

## Examples

``` r
tr <- Trace$new("cost-demo")
tr$start()

s1 <- Span$new("call1", type = "llm")
s1$set_model("gpt-4o")
s1$set_tokens(input = 1000L, output = 500L)
tr$add_span(s1)

s2 <- Span$new("call2", type = "llm")
s2$set_model("gpt-4o-mini")
s2$set_tokens(input = 2000L, output = 1000L)
tr$add_span(s2)

tr$end()
trace_total_cost(tr)
#> [1] 0.0084
```
