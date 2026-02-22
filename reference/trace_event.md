# Create a Trace Event

Factory function for creating trace events.

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

An S7 object of class `securetrace_event`.

## Examples

``` r
evt <- trace_event("response_received", data = list(tokens = 150L))
evt@name
#> [1] "response_received"
evt@data$tokens
#> [1] 150
```
