# Trace an LLM Call

Wraps an ellmer chat call with automatic span and token recording.
Requires the ellmer package.

## Usage

``` r
trace_llm_call(chat, prompt, ...)
```

## Arguments

- chat:

  An ellmer chat object.

- prompt:

  The prompt string to send.

- ...:

  Additional arguments passed to the chat method.

## Value

The chat response.

## Examples

``` r
if (FALSE) { # \dontrun{
# Requires ellmer package
chat <- ellmer::chat_openai(model = "gpt-4o")
with_trace("llm-demo", {
  response <- trace_llm_call(chat, "What is 2 + 2?")
})
} # }
```
