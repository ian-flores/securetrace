test_that("model_costs returns known models", {
  reset_costs()
  costs <- model_costs()
  expect_type(costs, "list")
  expect_true("claude-opus-4-6" %in% names(costs))
  expect_true("claude-sonnet-4-5" %in% names(costs))
  expect_true("claude-haiku-4-5" %in% names(costs))
  expect_true("gpt-4o" %in% names(costs))
  expect_true("gpt-4o-mini" %in% names(costs))
})

test_that("model_costs has correct pricing", {
  reset_costs()
  costs <- model_costs()
  expect_equal(costs[["claude-opus-4-6"]]$input, 15)
  expect_equal(costs[["claude-opus-4-6"]]$output, 75)
  expect_equal(costs[["gpt-4o"]]$input, 2.50)
  expect_equal(costs[["gpt-4o-mini"]]$output, 0.60)
})

test_that("calculate_cost computes correctly", {
  reset_costs()
  # 1M input tokens of claude-opus-4-6 = $15
  cost <- calculate_cost("claude-opus-4-6", 1e6, 0)
  expect_equal(cost, 15)

  # 1M output tokens of claude-opus-4-6 = $75
  cost <- calculate_cost("claude-opus-4-6", 0, 1e6)
  expect_equal(cost, 75)

  # Mixed: 1000 input + 500 output of gpt-4o
  cost <- calculate_cost("gpt-4o", 1000, 500)
  expect_equal(cost, (1000 / 1e6) * 2.50 + (500 / 1e6) * 10)
})

test_that("calculate_cost returns 0 for unknown model", {
  reset_costs()
  cost <- calculate_cost("unknown-model", 1000, 500)
  expect_equal(cost, 0)
})

test_that("add_model_cost registers custom pricing", {
  reset_costs()
  add_model_cost("my-model", input_price = 1, output_price = 2)
  costs <- model_costs()
  expect_true("my-model" %in% names(costs))
  expect_equal(costs[["my-model"]]$input, 1)

  cost <- calculate_cost("my-model", 1e6, 1e6)
  expect_equal(cost, 1 + 2)
  reset_costs()
})

test_that("trace_total_cost sums span costs", {
  reset_costs()
  tr <- Trace$new("cost-test")

  s1 <- Span$new("llm1", type = "llm")
  s1$set_tokens(input = 1000, output = 500)
  s1$set_model("gpt-4o")
  tr$add_span(s1)

  s2 <- Span$new("llm2", type = "llm")
  s2$set_tokens(input = 2000, output = 1000)
  s2$set_model("gpt-4o")
  tr$add_span(s2)

  s3 <- Span$new("tool1", type = "tool")
  # No model -- should contribute 0

  tr$add_span(s3)

  expected <- calculate_cost("gpt-4o", 1000, 500) +
    calculate_cost("gpt-4o", 2000, 1000)
  expect_equal(trace_total_cost(tr), expected)
})
