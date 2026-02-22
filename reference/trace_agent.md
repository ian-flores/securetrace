# Trace an orchestr Agent Invocation

Wraps an orchestr `Agent`'s `$invoke()` call with automatic tracing.
Creates a span for the agent invocation and auto-extracts model and
token information from the underlying chat object when available.
Requires the orchestr package.

## Usage

``` r
trace_agent(agent, prompt, ..., exporter = NULL)
```

## Arguments

- agent:

  An orchestr `Agent` object.

- prompt:

  Character string prompt to send to the agent.

- ...:

  Additional arguments passed to `agent$invoke()`.

- exporter:

  Optional exporter for the trace. If `NULL`, uses the default exporter
  (if set via
  [`set_default_exporter()`](https://ian-flores.github.io/securetrace/reference/set_default_exporter.md)).

## Value

The agent's text response.

## Examples

``` r
if (FALSE) { # \dontrun{
# Requires orchestr and ellmer packages
chat <- ellmer::chat_openai(model = "gpt-4o")
ag <- orchestr::agent("assistant", chat)
response <- trace_agent(ag, "What is 2 + 2?")
} # }
```
