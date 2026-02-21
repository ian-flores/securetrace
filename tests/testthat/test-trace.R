test_that("Trace creation sets fields correctly", {
  tr <- Trace$new("test-trace", metadata = list(env = "test"))
  expect_equal(tr$name, "test-trace")
  expect_equal(tr$status, "running")
  expect_type(tr$trace_id, "character")
  expect_equal(nchar(tr$trace_id), 32)
  expect_equal(tr$metadata, list(env = "test"))
  expect_length(tr$spans, 0)
})

test_that("Trace start/end lifecycle works", {
  tr <- Trace$new("lifecycle")
  expect_null(tr$duration())

  tr$start()
  Sys.sleep(0.05)
  tr$end()

  expect_equal(tr$status, "completed")
  expect_true(tr$duration() > 0)
})

test_that("Trace add_span works", {
  tr <- Trace$new("with-spans")
  s1 <- Span$new("span1", type = "custom")
  s2 <- Span$new("span2", type = "llm")

  tr$add_span(s1)
  tr$add_span(s2)

  expect_length(tr$spans, 2)
  expect_equal(tr$spans[[1]]$name, "span1")
  expect_equal(tr$spans[[2]]$name, "span2")
})

test_that("Trace to_list serializes correctly", {
  tr <- Trace$new("serial")
  tr$start()
  s <- Span$new("child", type = "tool")
  s$start()
  s$end()
  tr$add_span(s)
  tr$end()

  lst <- tr$to_list()
  expect_equal(lst$name, "serial")
  expect_equal(lst$status, "completed")
  expect_equal(lst$trace_id, tr$trace_id)
  expect_length(lst$spans, 1)
  expect_true(lst$duration_secs > 0 || lst$duration_secs == 0)
})

test_that("Trace summary produces output", {
  tr <- Trace$new("summary-test")
  tr$start()
  s <- Span$new("llm-call", type = "llm")
  s$start()
  s$set_tokens(input = 100, output = 50)
  s$set_model("claude-sonnet-4-5")
  s$end()
  tr$add_span(s)
  tr$end()

  msg <- tr$summary()
  expect_type(msg, "character")
  expect_match(msg, "summary-test")
  expect_match(msg, "100 input")
})
