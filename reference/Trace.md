# Trace Class

Trace Class

Trace Class

## Value

An R6 object of class `Trace`.

## Details

Root container for a full agent run. A trace contains multiple spans
representing individual operations like LLM calls, tool executions, and
guardrail checks.

## Public fields

- `name`:

  Name of the trace.

- `trace_id`:

  Unique identifier for the trace.

- `metadata`:

  Arbitrary metadata attached to the trace.

- `status`:

  Current status: "running", "completed", or "error".

- `resource`:

  Resource attributes for this trace.

## Active bindings

- `spans`:

  List of child spans (read-only).

## Methods

### Public methods

- [`Trace$new()`](#method-Trace-new)

- [`Trace$start()`](#method-Trace-start)

- [`Trace$end()`](#method-Trace-end)

- [`Trace$add_span()`](#method-Trace-add_span)

- [`Trace$duration()`](#method-Trace-duration)

- [`Trace$to_list()`](#method-Trace-to_list)

- [`Trace$print()`](#method-Trace-print)

- [`Trace$summary()`](#method-Trace-summary)

- [`Trace$clone()`](#method-Trace-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new trace.

#### Usage

    Trace$new(name, metadata = list())

#### Arguments

- `name`:

  Name for the trace.

- `metadata`:

  Optional named list of metadata.

#### Returns

A new `Trace` object.

------------------------------------------------------------------------

### Method [`start()`](https://rdrr.io/r/stats/start.html)

Record the start time.

#### Usage

    Trace$start()

------------------------------------------------------------------------

### Method [`end()`](https://rdrr.io/r/stats/start.html)

Record the end time and mark as completed.

#### Usage

    Trace$end()

------------------------------------------------------------------------

### Method `add_span()`

Add a child span to this trace.

#### Usage

    Trace$add_span(span)

#### Arguments

- `span`:

  A `Span` object.

------------------------------------------------------------------------

### Method `duration()`

Get the total duration in seconds.

#### Usage

    Trace$duration()

#### Returns

Numeric duration, or `NULL` if not started/ended.

------------------------------------------------------------------------

### Method `to_list()`

Serialize the trace to a list.

#### Usage

    Trace$to_list()

#### Returns

A named list representation.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print a concise representation of the trace.

#### Usage

    Trace$print(...)

#### Arguments

- `...`:

  Ignored.

#### Returns

The `Trace` object, invisibly.

------------------------------------------------------------------------

### Method [`summary()`](https://rdrr.io/r/base/summary.html)

Print a formatted summary of the trace.

#### Usage

    Trace$summary()

#### Returns

The trace summary as a character string, invisibly.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Trace$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
# Create and use a trace
tr <- Trace$new("my-agent-run", metadata = list(user = "test"))
tr$start()

# Add a span to the trace
span <- Span$new("llm-call", type = "llm")
span$start()
span$set_tokens(input = 100L, output = 50L)
span$end()
tr$add_span(span)

tr$end()
tr$status
#> [1] "completed"
tr$duration()
#> [1] 0.002937317
tr$summary()
#> Trace: my-agent-run (completed) ID: ec1d6ada44bc15ee3f1285a6f4585e9f Duration:
#> 0.00s Spans: 1 Tokens: 100 input, 50 output Cost: $0.000000

# Serialize to list for export
trace_list <- tr$to_list()
trace_list$name
#> [1] "my-agent-run"
```
