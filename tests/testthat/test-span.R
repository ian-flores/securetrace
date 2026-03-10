test_that("Span creation sets fields correctly", {
  s <- Span$new("test-span", type = "llm", metadata = list(key = "val"))
  expect_equal(s$name, "test-span")
  expect_equal(s$type, "llm")
  expect_equal(s$status, "running")
  expect_equal(s$input_tokens, 0L)
  expect_equal(s$output_tokens, 0L)
  expect_null(s$model)
  expect_null(s$parent_id)
  expect_type(s$span_id, "character")
  expect_equal(nchar(s$span_id), 16)
})

test_that("Span type must be valid", {
  expect_error(Span$new("bad", type = "invalid"))
})

test_that("Span start/end lifecycle works", {
  s <- Span$new("lifecycle", type = "tool")
  expect_null(s$duration())

  s$start()
  Sys.sleep(0.05)
  s$end()

  expect_equal(s$status, "ok")
  expect_true(s$duration() > 0)
})

test_that("Span set_tokens records values", {
  s <- Span$new("tokens", type = "llm")
  s$set_tokens(input = 500, output = 200)

  expect_equal(s$input_tokens, 500L)
  expect_equal(s$output_tokens, 200L)
})

test_that("Span set_model records model name", {
  s <- Span$new("model", type = "llm")
  s$set_model("claude-opus-4-6")
  expect_equal(s$model, "claude-opus-4-6")
})

test_that("Span set_error sets status to error", {
  s <- Span$new("errored", type = "tool")
  s$set_error("something went wrong")
  expect_equal(s$status, "error")

  # Also test with a condition object
  s2 <- Span$new("errored2", type = "tool")
  cond <- simpleError("a real error")
  s2$set_error(cond)
  expect_equal(s2$status, "error")
})

test_that("Span end does not override error status", {
  s <- Span$new("err-end", type = "tool")
  s$start()
  s$set_error("fail")
  s$end(status = "ok")
  expect_equal(s$status, "error")
})

test_that("Span add_event works", {
  s <- Span$new("events", type = "custom")
  ev <- trace_event("test-event", data = list(x = 1))
  s$add_event(ev)
  expect_length(s$events, 1)
  expect_equal(s$events[[1]]@name, "test-event")
})

test_that("Span add_event rejects non-events", {
  s <- Span$new("bad-event", type = "custom")
  expect_error(s$add_event("not an event"))
})

test_that("Span add_metric records metrics", {
  s <- Span$new("metrics", type = "custom")
  s$add_metric("latency", 1.5, unit = "seconds")
  lst <- s$to_list()
  expect_length(lst$metrics, 1)
  expect_equal(lst$metrics[[1]]$name, "latency")
  expect_equal(lst$metrics[[1]]$value, 1.5)
  expect_equal(lst$metrics[[1]]$unit, "seconds")
})

test_that("Span to_list serializes correctly", {
  s <- Span$new("serial", type = "llm", parent_id = "abc123")
  s$start()
  s$set_tokens(input = 10, output = 20)
  s$set_model("gpt-4o")
  s$add_event(trace_event("started"))
  s$end()

  lst <- s$to_list()
  expect_equal(lst$name, "serial")
  expect_equal(lst$type, "llm")
  expect_equal(lst$parent_id, "abc123")
  expect_equal(lst$input_tokens, 10L)
  expect_equal(lst$output_tokens, 20L)
  expect_equal(lst$model, "gpt-4o")
  expect_length(lst$events, 1)
})

test_that("span set_attribute works", {
  s <- Span$new("test", type = "custom")
  s$start()
  s$set_attribute("http.method", "GET")
  s$set_attribute("http.status_code", 200L)
  s$end()

  l <- s$to_list()
  expect_equal(l$attributes$http.method, "GET")
  expect_equal(l$attributes$http.status_code, 200L)
})

test_that("set_attribute validates key", {
  s <- Span$new("test", type = "custom")
  expect_error(s$set_attribute(123, "value"))
  expect_error(s$set_attribute(c("a", "b"), "value"))
})
