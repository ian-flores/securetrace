test_that("exporter creates exporter object", {
  exp <- exporter(function(trace_list) NULL)
  expect_true(S7::S7_inherits(exp, securetrace_exporter))
})

test_that("exporter rejects non-functions", {
  expect_error(exporter("not a function"))
})

test_that("exporter_jsonl writes valid JSONL", {
  tmp <- tempfile(fileext = ".jsonl")
  on.exit(unlink(tmp), add = TRUE)

  exp <- exporter_jsonl(tmp)
  tr <- Trace$new("jsonl-test")
  tr$start()
  tr$end()

  export_trace(exp, tr)

  lines <- readLines(tmp)
  expect_length(lines, 1)
  parsed <- jsonlite::fromJSON(lines[[1]])
  expect_equal(parsed$name, "jsonl-test")
})

test_that("exporter_console produces output", {
  exp <- exporter_console(verbose = TRUE)
  tr <- Trace$new("console-test")
  tr$start()
  s <- Span$new("child", type = "tool")
  s$start()
  s$end()
  tr$add_span(s)
  tr$end()

  expect_output(export_trace(exp, tr))
})

test_that("export_trace rejects non-exporters", {
  tr <- Trace$new("test")
  expect_error(export_trace("not an exporter", tr))
})

test_that("exporter_multi calls all exporters", {
  called <- integer(0)
  e1 <- exporter(function(tl) called[[1]] <<- 1L)
  e2 <- exporter(function(tl) called[[2]] <<- 2L)

  me <- exporter_multi(e1, e2)
  tr <- Trace$new("multi-test")
  tr$start()
  tr$end()
  export_trace(me, tr)

  expect_equal(called, c(1L, 2L))
})

test_that("exporter_multi rejects non-exporters", {
  expect_error(exporter_multi("not an exporter"))
})

test_that("exporter print works", {
  exp <- exporter(function(x) NULL)
  expect_output(print(exp), "securetrace_exporter")
})

# -- Deprecated wrapper tests --------------------------------------------------

test_that("new_exporter warns about deprecation", {
  lifecycle::expect_deprecated(new_exporter(function(x) NULL))
})

test_that("jsonl_exporter warns about deprecation", {
  lifecycle::expect_deprecated(jsonl_exporter(tempfile()))
})

test_that("console_exporter warns about deprecation", {
  lifecycle::expect_deprecated(console_exporter())
})

test_that("multi_exporter warns about deprecation", {
  e1 <- exporter(function(x) NULL)
  lifecycle::expect_deprecated(multi_exporter(e1))
})

test_that("json_stdout_exporter warns about deprecation", {
  lifecycle::expect_deprecated(json_stdout_exporter())
})

# -- trace_schema() tests -------------------------------------------------------

test_that("trace_schema returns a list with expected top-level keys", {
  schema <- trace_schema()
  expect_type(schema, "list")

  expected_keys <- c("trace_id", "name", "status", "start_time", "end_time",
                     "duration", "spans")
  for (key in expected_keys) {
    expect_true(key %in% names(schema), info = paste("Missing key:", key))
  }
})

test_that("trace_schema span fields include expected entries", {
  schema <- trace_schema()
  span_fields <- schema$spans$fields

  expected_span_keys <- c("span_id", "name", "type", "status", "start_time",
                          "end_time", "duration_secs", "parent_id", "model",
                          "input_tokens", "output_tokens")
  for (key in expected_span_keys) {
    expect_true(key %in% names(span_fields),
                info = paste("Missing span field:", key))
  }
})

test_that("trace_schema fields have type and description", {
  schema <- trace_schema()
  # Check a top-level field
  expect_true("type" %in% names(schema$trace_id))
  expect_true("description" %in% names(schema$trace_id))
  # Check a span field
  expect_true("type" %in% names(schema$spans$fields$span_id))
  expect_true("description" %in% names(schema$spans$fields$span_id))
})
