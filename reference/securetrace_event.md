# Trace Event Class (S7)

Discrete point-in-time event within a span.

## Usage

``` r
securetrace_event(name = character(0), data = NULL, timestamp = NULL)
```

## Arguments

- name:

  Character string naming the event.

- data:

  Arbitrary data associated with the event.

- timestamp:

  Timestamp for the event (POSIXct).

## Examples

``` r
# Create an event directly
evt <- securetrace_event(
  name = "model_selected",
  data = list(model = "gpt-4o"),
  timestamp = Sys.time()
)
evt@name
#> [1] "model_selected"
evt@data
#> $model
#> [1] "gpt-4o"
#> 
```
