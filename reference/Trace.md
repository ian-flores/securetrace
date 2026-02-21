# Trace Class

Trace Class

Trace Class

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
