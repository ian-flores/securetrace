# Create a Trace Event

Discrete point-in-time event within a span.

## Usage

``` r
trace_event(name, data = list(), timestamp = Sys.time())
```

## Arguments

- name:

  Name of the event.

- data:

  Optional named list of event data.

- timestamp:

  Timestamp for the event. Defaults to current time.

## Value

An S3 object of class `securetrace_event`.
