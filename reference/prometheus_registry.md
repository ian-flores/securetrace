# Create a Prometheus Metrics Registry

Creates a new registry environment for holding counters and histograms
collected from securetrace traces.

## Usage

``` r
prometheus_registry()
```

## Value

An environment of class `securetrace_prometheus_registry` with
`$counters` and `$histograms` lists.

## Examples

``` r
reg <- prometheus_registry()
reg$counters
#> list()
reg$histograms
#> list()
```
