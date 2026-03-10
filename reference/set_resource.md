# Set the Default Resource

Sets resource attributes that will be attached to all traces created via
[`with_trace()`](https://ian-flores.github.io/securetrace/reference/with_trace.md).

## Usage

``` r
set_resource(res)
```

## Arguments

- res:

  A `securetrace_resource` object from
  [`resource()`](https://ian-flores.github.io/securetrace/reference/resource.md).

## Value

Invisible `NULL`.

## Examples

``` r
set_resource(resource("my-agent", service_version = "1.0.0"))

# Traces now include resource attributes
with_trace("test", {
  tr <- current_trace()
  tr$resource
})
#> $service.name
#> [1] "my-agent"
#> 
#> $service.version
#> [1] "1.0.0"
#> 
#> attr(,"class")
#> [1] "securetrace_resource"
```
