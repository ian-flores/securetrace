# Getting Started with securetrace

securetrace gives you structured tracing, token accounting, and cost
tracking for LLM agent workflows in R.

## Quick start

Wrap your workflow in
[`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md),
break it into spans, and record tokens:

``` r
library(securetrace)

result <- with_trace("my-agent-run", {
  with_span("planning", type = "llm", {
    record_tokens(1500, 300, model = "claude-sonnet-4-5")
    "The answer is 42"
  })
})
```

- [`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md)
  creates a `Trace`, starts the clock, evaluates your code, and ends the
  trace.
- [`with_span()`](https://ian-flores.github.io/securetrace/reference/with_span.md)
  wraps a single operation (LLM call, tool use, etc.).
- [`record_tokens()`](https://ian-flores.github.io/securetrace/reference/record_tokens.md)
  logs input/output tokens and model on the current span.

Use
[`current_trace()`](https://ian-flores.github.io/securetrace/reference/current_trace.md)
and
[`current_span()`](https://ian-flores.github.io/securetrace/reference/current_span.md)
to access active objects anywhere inside the block.

## Token and cost tracking

Built-in pricing covers Anthropic, OpenAI, Gemini, Mistral, and
DeepSeek.

``` r
# All known pricing (per 1M tokens)
costs <- model_costs()
head(names(costs))
#> [1] "claude-opus-4-6"            "claude-sonnet-4-5"         
#> [3] "claude-haiku-4-5"           "claude-3-5-sonnet-20241022"
#> [5] "claude-3-5-haiku-20241022"  "claude-3-opus-20240229"
```

``` r
# Cost for a single call
calculate_cost("claude-sonnet-4-5", input_tokens = 5000, output_tokens = 1000)
#> [1] 0.03
```

Register your own models:

``` r
add_model_cost("my-fine-tuned", input_price = 5, output_price = 20)
calculate_cost("my-fine-tuned", input_tokens = 10000, output_tokens = 2000)
#> [1] 0.09
```

Cloud provider model IDs (Bedrock, Vertex) resolve automatically via
[`resolve_model()`](https://ian-flores.github.io/securetrace/reference/resolve_model.md):

``` r
calculate_cost(
  "anthropic.claude-3-5-sonnet-20241022-v2:0",
  input_tokens = 10000, output_tokens = 2000
)
#> [1] 0.06
```

Map internal deployment names with
[`add_model_alias()`](https://ian-flores.github.io/securetrace/reference/add_model_alias.md):

``` r
add_model_alias("my-company-claude", "claude-sonnet-4-5")
calculate_cost("my-company-claude", input_tokens = 5000, output_tokens = 1000)
#> [1] 0.03
```

## Exporting traces

Write traces to JSONL for downstream analysis:

``` r
exp <- exporter_jsonl(tempfile("traces", fileext = ".jsonl"))

with_trace("exported-run", exporter = exp, {
  with_span("work", type = "tool", { 42 })
})
#> [1] 42
```

Print to console while debugging:

``` r
debug_exp <- exporter_console(verbose = TRUE)

with_trace("debug-run", exporter = debug_exp, {
  with_span("step", type = "custom", { 1 + 1 })
})
#> --- Trace: debug-run ---
#> Status: completed
#> Duration: 0.00s
#> Spans: 1
#> -- Spans --
#>   * step [custom] (ok) - 0.000s
#> [1] 2
```

Set a default exporter so every
[`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md)
auto-exports:

``` r
set_default_exporter(exp)
```

See
[`vignette("exporters")`](https://ian-flores.github.io/securetrace/articles/exporters.md)
for custom exporters,
[`exporter_multi()`](https://ian-flores.github.io/securetrace/reference/exporter_multi.md),
and the JSONL schema reference.

## Trace summary

Call `$summary()` on a completed trace to see duration, span count,
tokens, and cost at a glance:

``` r
tr <- Trace$new("summarized-run")
tr$start()
s <- Span$new("llm", type = "llm")
s$start()
s$set_tokens(input = 5000, output = 1000)
s$set_model("claude-opus-4-6")
s$end()
tr$add_span(s)
tr$end()

tr$summary()
#> Trace: summarized-run (completed) ID: 163a3181d2b2f09bcf64302605ab6a97
#> Duration: 0.00s Spans: 1 Tokens: 5000 input, 1000 output Cost: $0.150000
```

## Next steps

- [`vignette("observability")`](https://ian-flores.github.io/securetrace/articles/observability.md)
  – spans, events, metrics, error handling, nested workflows.
- [`vignette("exporters")`](https://ian-flores.github.io/securetrace/articles/exporters.md)
  – JSONL schema, console exporter, custom exporters.
- [`vignette("cloud-native")`](https://ian-flores.github.io/securetrace/articles/cloud-native.md)
  – OTLP, Prometheus, W3C Trace Context.
