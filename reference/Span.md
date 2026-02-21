# Span Class

Span Class

Span Class

## Details

Represents a single operation within a trace, such as an LLM call, tool
execution, guardrail check, or custom operation.

## Public fields

- `name`:

  Name of the span.

- `span_id`:

  Unique identifier for the span.

- `type`:

  Type of operation: "llm", "tool", "guardrail", or "custom".

- `parent_id`:

  ID of the parent span, if any.

- `metadata`:

  Arbitrary metadata attached to the span.

- `status`:

  Current status: "running", "ok", or "error".

- `input_tokens`:

  Number of input tokens recorded.

- `output_tokens`:

  Number of output tokens recorded.

- `model`:

  Model name used for this span (if LLM).

## Active bindings

- `events`:

  List of events (read-only).

## Methods

### Public methods

- [`Span$new()`](#method-Span-new)

- [`Span$start()`](#method-Span-start)

- [`Span$end()`](#method-Span-end)

- [`Span$add_event()`](#method-Span-add_event)

- [`Span$set_tokens()`](#method-Span-set_tokens)

- [`Span$set_model()`](#method-Span-set_model)

- [`Span$set_error()`](#method-Span-set_error)

- [`Span$duration()`](#method-Span-duration)

- [`Span$add_metric()`](#method-Span-add_metric)

- [`Span$to_list()`](#method-Span-to_list)

- [`Span$clone()`](#method-Span-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new span.

#### Usage

    Span$new(
      name,
      type = c("llm", "tool", "guardrail", "custom"),
      parent_id = NULL,
      metadata = list()
    )

#### Arguments

- `name`:

  Name of the span.

- `type`:

  Type of operation. One of "llm", "tool", "guardrail", "custom".

- `parent_id`:

  Optional parent span ID.

- `metadata`:

  Optional named list of metadata.

#### Returns

A new `Span` object.

------------------------------------------------------------------------

### Method [`start()`](https://rdrr.io/r/stats/start.html)

Record the start time.

#### Usage

    Span$start()

------------------------------------------------------------------------

### Method [`end()`](https://rdrr.io/r/stats/start.html)

Record the end time and set status.

#### Usage

    Span$end(status = "ok")

#### Arguments

- `status`:

  Final status. Default "ok".

------------------------------------------------------------------------

### Method `add_event()`

Add an event to this span.

#### Usage

    Span$add_event(event)

#### Arguments

- `event`:

  A `securetrace_event` object.

------------------------------------------------------------------------

### Method `set_tokens()`

Record token usage.

#### Usage

    Span$set_tokens(input = 0L, output = 0L)

#### Arguments

- `input`:

  Number of input tokens.

- `output`:

  Number of output tokens.

------------------------------------------------------------------------

### Method `set_model()`

Record which model was used.

#### Usage

    Span$set_model(model)

#### Arguments

- `model`:

  Model name string.

------------------------------------------------------------------------

### Method `set_error()`

Record an error and set status to "error".

#### Usage

    Span$set_error(error)

#### Arguments

- `error`:

  The error condition or message string.

------------------------------------------------------------------------

### Method `duration()`

Get the duration in seconds.

#### Usage

    Span$duration()

#### Returns

Numeric duration, or `NULL` if not started/ended.

------------------------------------------------------------------------

### Method `add_metric()`

Record a custom metric.

#### Usage

    Span$add_metric(name, value, unit = NULL)

#### Arguments

- `name`:

  Metric name.

- `value`:

  Metric value.

- `unit`:

  Optional unit string.

------------------------------------------------------------------------

### Method `to_list()`

Serialize the span to a list.

#### Usage

    Span$to_list()

#### Returns

A named list representation.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Span$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
