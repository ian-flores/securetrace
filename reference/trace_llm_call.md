# Trace an LLM Call

Wraps an ellmer chat call with automatic span and token recording.
Requires the ellmer package.

## Usage

``` r
trace_llm_call(chat, prompt, ..., stream = FALSE)
```

## Arguments

- chat:

  An ellmer chat object.

- prompt:

  The prompt string to send.

- ...:

  Additional arguments passed to the chat method.

- stream:

  Logical. If `TRUE`, calls `chat$stream(prompt, ...)` instead of
  `chat$chat(prompt, ...)`. Default `FALSE`.

## Value

The chat response.

## Details

When the `chat` object supports ellmer's `get_model()` and
`get_tokens()` methods, the model name and token usage are automatically
extracted and recorded on the span. Model names are resolved through
[`resolve_model()`](https://ian-flores.github.io/securetrace/reference/resolve_model.md)
for proper cost calculation with cloud provider model IDs.

Auto-extraction is best-effort: if the chat object does not support
these methods (e.g., a non-ellmer Chat object), the span will still be
created with latency recorded but without model or token data.

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
