test_that("new_exporter creates exporter object", {
  exp <- new_exporter(function(trace_list) NULL)
  expect_true(S7::S7_inherits(exp, securetrace_exporter))
})

test_that("new_exporter rejects non-functions", {
  expect_error(new_exporter("not a function"))
})

test_that("jsonl_exporter writes valid JSONL", {
  tmp <- tempfile(fileext = ".jsonl")
  on.exit(unlink(tmp), add = TRUE)

  exp <- jsonl_exporter(tmp)
  tr <- Trace$new("jsonl-test")
  tr$start()
  tr$end()

  export_trace(exp, tr)

  lines <- readLines(tmp)
  expect_length(lines, 1)
  parsed <- jsonlite::fromJSON(lines[[1]])
  expect_equal(parsed$name, "jsonl-test")
})

test_that("console_exporter produces output", {
  exp <- console_exporter(verbose = TRUE)
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

test_that("multi_exporter calls all exporters", {
  called <- integer(0)
  e1 <- new_exporter(function(tl) called[[1]] <<- 1L)
  e2 <- new_exporter(function(tl) called[[2]] <<- 2L)

  me <- multi_exporter(e1, e2)
  tr <- Trace$new("multi-test")
  tr$start()
  tr$end()
  export_trace(me, tr)

  expect_equal(called, c(1L, 2L))
})

test_that("multi_exporter rejects non-exporters", {
  expect_error(multi_exporter("not an exporter"))
})

test_that("exporter print works", {
  exp <- new_exporter(function(x) NULL)
  expect_output(print(exp), "securetrace_exporter")
})
