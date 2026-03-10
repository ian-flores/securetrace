# Resource Attributes

Resource attributes describe the entity producing telemetry data –
typically the service name, version, and deployment environment. Once
set, resource attributes are attached to all exported traces.

## Usage

``` r
resource(
  service_name,
  service_version = NULL,
  deployment_environment = NULL,
  ...
)
```

## Arguments

- service_name:

  Name of the service producing traces.

- service_version:

  Optional version string.

- deployment_environment:

  Optional environment name (e.g. "production", "staging").

- ...:

  Additional key-value attributes.

## Value

A named list of class `securetrace_resource`.

## Examples

``` r
res <- resource("my-agent", service_version = "1.0.0",
                deployment_environment = "production")
res$service.name
#> [1] "my-agent"
```
