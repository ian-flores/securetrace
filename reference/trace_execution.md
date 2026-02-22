# Trace a Secure Code Execution

Wraps a securer session execution with a span. Records the submitted
code, captured stdout/stderr, and sets span status to error on execution
failure. Requires the securer package.

## Usage

``` r
trace_execution(session, code, ...)
```

## Arguments

- session:

  A securer SecureSession object.

- code:

  Code string to execute.

- ...:

  Additional arguments passed to `session$execute()`.

## Value

The execution result.

## Examples

``` r
if (FALSE) { # \dontrun{
# Requires securer package
session <- securer::SecureSession$new()
with_trace("exec-demo", {
  result <- trace_execution(session, "1 + 1")
})
session$close()
} # }
```
