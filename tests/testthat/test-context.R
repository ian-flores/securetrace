test_that("current_trace returns NULL with no active trace", {
  reset_context()
  expect_null(current_trace())
})

test_that("current_span returns NULL with no active span", {
  reset_context()
  expect_null(current_span())
})

test_that("with_trace makes trace available via current_trace", {
  reset_context()
  result <- with_trace("ctx-test", {
    tr <- current_trace()
    expect_false(is.null(tr))
    expect_equal(tr$name, "ctx-test")
    42
  })
  expect_equal(result, 42)
  expect_null(current_trace())
  reset_context()
})

test_that("with_span makes span available via current_span", {
  reset_context()
  with_trace("span-ctx-test", {
    result <- with_span("my-span", type = "tool", {
      sp <- current_span()
      expect_false(is.null(sp))
      expect_equal(sp$name, "my-span")
      "ok"
    })
    expect_equal(result, "ok")
    expect_null(current_span())
  })
  reset_context()
})

test_that("with_span errors without active trace", {
  reset_context()
  expect_error(
    with_span("orphan", type = "custom", { 1 }),
    "No active trace"
  )
})

test_that("nested spans set parent_id correctly", {
  reset_context()
  with_trace("nested-test", {
    with_span("parent-span", type = "custom", {
      parent_id <- current_span()$span_id
      with_span("child-span", type = "custom", {
        child <- current_span()
        expect_equal(child$parent_id, parent_id)
      })
    })
  })
  reset_context()
})

test_that("with_trace cleans up on error", {
  reset_context()
  expect_error(
    with_trace("error-trace", {
      stop("boom")
    })
  )
  expect_null(current_trace())
  reset_context()
})

test_that("with_span cleans up on error", {
  reset_context()
  expect_error(
    with_trace("err-span-trace", {
      with_span("err-span", type = "custom", {
        stop("oops")
      })
    })
  )
  expect_null(current_span())
  expect_null(current_trace())
  reset_context()
})

test_that("with_trace exports on completion", {
  reset_context()
  tmp <- tempfile(fileext = ".jsonl")
  on.exit(unlink(tmp), add = TRUE)

  exp <- exporter_jsonl(tmp)
  with_trace("export-test", exporter = exp, {
    with_span("work", type = "custom", { 1 + 1 })
  })

  lines <- readLines(tmp)
  expect_length(lines, 1)
  parsed <- jsonlite::fromJSON(lines[[1]])
  expect_equal(parsed$name, "export-test")
  expect_equal(parsed$status, "completed")
  reset_context()
})

test_that("with_trace exports on error", {
  reset_context()
  tmp <- tempfile(fileext = ".jsonl")
  on.exit(unlink(tmp), add = TRUE)

  exp <- exporter_jsonl(tmp)
  expect_error(
    with_trace("err-export-test", exporter = exp, {
      stop("fail")
    })
  )

  lines <- readLines(tmp)
  expect_length(lines, 1)
  parsed <- jsonlite::fromJSON(lines[[1]])
  expect_equal(parsed$status, "error")
  reset_context()
})

test_that("set_default_exporter works", {
  reset_context()
  tmp <- tempfile(fileext = ".jsonl")
  on.exit(unlink(tmp), add = TRUE)

  exp <- exporter_jsonl(tmp)
  set_default_exporter(exp)

  with_trace("default-exp-test", {
    1 + 1
  })

  lines <- readLines(tmp)
  expect_length(lines, 1)
  reset_context()
})

test_that("set_default_exporter rejects non-exporters", {
  reset_context()
  expect_error(set_default_exporter("not an exporter"))
  reset_context()
})
