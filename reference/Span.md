# Span Class

Span Class

Span Class

## Value

An R6 object of class `Span`.

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

- [`Span$set_attribute()`](#method-Span-set_attribute)

- [`Span$duration()`](#method-Span-duration)

- [`Span$add_metric()`](#method-Span-add_metric)

- [`Span$print()`](#method-Span-print)

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

### Method `set_attribute()`

Set a span attribute (key-value pair).

#### Usage

    Span$set_attribute(key, value)

#### Arguments

- `key`:

  Character string attribute name.

- `value`:

  Attribute value (scalar or vector).

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

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print a concise representation of the span.

#### Usage

    Span$print(...)

#### Arguments

- `...`:

  Ignored.

#### Returns

The `Span` object, invisibly.

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

## Examples

``` r
# Create a span for an LLM call
span <- Span$new("gpt-call", type = "llm")
span$start()
span$set_model("gpt-4o")
span$set_tokens(input = 500L, output = 200L)
span$add_metric("latency", 1.23, unit = "seconds")

# Add an event
evt <- trace_event("prompt_sent", data = list(length = 42L))
span$add_event(evt)

span$end()
span$status
#> [1] "ok"
span$duration()
#> [1] 0.002936363
span$to_list()
#> $span_id
#> [1] "c6be45eee35844e7"
#> 
#> $name
#> [1] "gpt-call"
#> 
#> $type
#> [1] "llm"
#> 
#> $status
#> [1] "ok"
#> 
#> $parent_id
#> NULL
#> 
#> $metadata
#> list()
#> 
#> $attributes
#> list()
#> 
#> $start_time
#> [1] "2026-04-28T08:18:40.640Z"
#> 
#> $end_time
#> [1] "2026-04-28T08:18:40.643Z"
#> 
#> $duration_secs
#> [1] 0.002936363
#> 
#> $input_tokens
#> [1] 500
#> 
#> $output_tokens
#> [1] 200
#> 
#> $model
#> [1] "gpt-4o"
#> 
#> $error
#> NULL
#> 
#> $events
#> $events[[1]]
#> $events[[1]]$name
#> [1] "prompt_sent"
#> 
#> $events[[1]]$data
#> $events[[1]]$data$length
#> [1] 42
#> 
#> 
#> $events[[1]]$timestamp
#> [1] "2026-04-28T08:18:40.642Z"
#> 
#> 
#> 
#> $metrics
#> $metrics[[1]]
#> $metrics[[1]]$name
#> [1] "latency"
#> 
#> $metrics[[1]]$value
#> [1] 1.23
#> 
#> $metrics[[1]]$unit
#> [1] "seconds"
#> 
#> 
#> 
```
