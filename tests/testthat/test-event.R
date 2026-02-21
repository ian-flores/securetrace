test_that("trace_event creates correct S3 class", {
  ev <- trace_event("test-event")
  expect_true(is_trace_event(ev))
  expect_s3_class(ev, "securetrace_event")
  expect_equal(ev$name, "test-event")
  expect_equal(ev$data, list())
  expect_s3_class(ev$timestamp, "POSIXct")
})

test_that("trace_event stores data", {
  ev <- trace_event("with-data", data = list(x = 1, y = "hello"))
  expect_equal(ev$data$x, 1)
  expect_equal(ev$data$y, "hello")
})

test_that("trace_event accepts custom timestamp", {
  ts <- as.POSIXct("2026-01-01 00:00:00", tz = "UTC")
  ev <- trace_event("timed", timestamp = ts)
  expect_equal(ev$timestamp, ts)
})

test_that("is_trace_event returns FALSE for non-events", {
  expect_false(is_trace_event("not an event"))
  expect_false(is_trace_event(42))
  expect_false(is_trace_event(list(name = "fake")))
})

test_that("trace_event prints without error", {
  ev <- trace_event("printable", data = list(a = 1))
  expect_output(print(ev))
})
