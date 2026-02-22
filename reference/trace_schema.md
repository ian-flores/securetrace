# JSONL Trace Schema

Returns a list describing the expected JSONL trace format, including
field names, types, and descriptions for all top-level and span-level
fields.

## Usage

``` r
trace_schema()
```

## Value

A named list where each element describes a field with `type` and
`description`. The `spans` element additionally contains a `fields` list
describing the span sub-structure.

## Examples

``` r
schema <- trace_schema()
names(schema)
#> [1] "trace_id"   "name"       "status"     "start_time" "end_time"  
#> [6] "duration"   "spans"     
schema$trace_id
#> $type
#> [1] "character"
#> 
#> $description
#> [1] "Unique identifier for the trace (UUID)"
#> 
names(schema$spans$fields)
#>  [1] "span_id"       "name"          "type"          "status"       
#>  [5] "start_time"    "end_time"      "duration_secs" "parent_id"    
#>  [9] "model"         "input_tokens"  "output_tokens"
```
