test_that("sampler_always_on records all traces", {
  s <- sampler_always_on()
  expect_true(s@should_sample("test", list()))
})

test_that("sampler_always_off drops all traces", {
  s <- sampler_always_off()
  expect_false(s@should_sample("test", list()))
})

test_that("sampler_probability validates rate", {
  expect_error(sampler_probability(-0.1))
  expect_error(sampler_probability(1.5))
  s <- sampler_probability(0)
  expect_false(s@should_sample("test", list()))
  s <- sampler_probability(1)
  expect_true(s@should_sample("test", list()))
})

test_that("sampler_rate_limiting respects limit", {
  s <- sampler_rate_limiting(2)
  expect_true(s@should_sample("a", list()))
  expect_true(s@should_sample("b", list()))
  expect_false(s@should_sample("c", list()))
})

test_that("set_default_sampler validates input", {
  expect_error(set_default_sampler("not a sampler"))
})

test_that("with_trace respects sampler", {
  reset_context()
  on.exit(reset_context())

  set_default_sampler(sampler_always_off())
  # Should execute code but not create trace
  result <- with_trace("sampled-out", {
    42
  })
  expect_equal(result, 42)
})
