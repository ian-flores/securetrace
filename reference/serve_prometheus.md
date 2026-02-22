# Serve Prometheus Metrics via HTTP

Starts an httpuv server that serves the `/metrics` endpoint in
Prometheus text exposition format.

## Usage

``` r
serve_prometheus(registry, host = "0.0.0.0", port = 9090)
```

## Arguments

- registry:

  A `securetrace_prometheus_registry`.

- host:

  Host to bind to. Default `"0.0.0.0"`.

- port:

  Port to listen on. Default `9090`.

## Value

The httpuv server object (can be stopped with
[`httpuv::stopServer()`](https://rdrr.io/pkg/httpuv/man/stopServer.html)).

## Examples

``` r
if (FALSE) { # \dontrun{
reg <- prometheus_registry()
srv <- serve_prometheus(reg, port = 9091)
# Scrape http://localhost:9091/metrics
httpuv::stopServer(srv)
} # }
```
