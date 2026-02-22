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

# --- Multi-provider model registry tests ---

test_that("Gemini models exist with correct pricing", {
  reset_costs()
  costs <- model_costs()
  expect_true("gemini-2.0-flash" %in% names(costs))
  expect_true("gemini-1.5-pro" %in% names(costs))
  expect_true("gemini-1.5-flash" %in% names(costs))
  expect_true("gemini-1.5-flash-8b" %in% names(costs))

  # Verify specific pricing

  expect_equal(costs[["gemini-1.5-pro"]]$input, 1.25)
  expect_equal(costs[["gemini-1.5-pro"]]$output, 5)
  expect_equal(costs[["gemini-2.0-flash"]]$input, 0.10)
})

test_that("extended OpenAI models exist", {
  reset_costs()
  costs <- model_costs()
  expect_true("o1" %in% names(costs))
  expect_true("o1-mini" %in% names(costs))
  expect_true("o3-mini" %in% names(costs))
  expect_true("gpt-4-turbo" %in% names(costs))
  expect_true("gpt-4" %in% names(costs))
  expect_true("gpt-3.5-turbo" %in% names(costs))
  expect_true("gpt-4o-2024-11-20" %in% names(costs))
})

test_that("Mistral and DeepSeek models exist", {
  reset_costs()
  costs <- model_costs()
  expect_true("mistral-large-latest" %in% names(costs))
  expect_true("mistral-small-latest" %in% names(costs))
  expect_true("codestral-latest" %in% names(costs))
  expect_true("deepseek-chat" %in% names(costs))
  expect_true("deepseek-reasoner" %in% names(costs))

  # Spot-check pricing
  expect_equal(costs[["deepseek-chat"]]$input, 0.27)
  expect_equal(costs[["mistral-large-latest"]]$output, 6)
})

# --- Alias resolution tests ---

test_that("resolve_model resolves Bedrock IDs to canonical names", {
  reset_costs()
  expect_equal(
    resolve_model("anthropic.claude-3-5-sonnet-20241022-v2:0"),
    "claude-3-5-sonnet-20241022"
  )
  expect_equal(
    resolve_model("anthropic.claude-3-opus-20240229-v1:0"),
    "claude-3-opus-20240229"
  )
  expect_equal(
    resolve_model("anthropic.claude-3-haiku-20240307-v1:0"),
    "claude-3-haiku-20240307"
  )
})

test_that("resolve_model resolves Vertex IDs to canonical names", {
  reset_costs()
  expect_equal(
    resolve_model("publishers/anthropic/models/claude-3-5-sonnet-v2@20241022"),
    "claude-3-5-sonnet-20241022"
  )
  expect_equal(
    resolve_model("publishers/anthropic/models/claude-3-opus@20240229"),
    "claude-3-opus-20240229"
  )
  expect_equal(
    resolve_model("publishers/anthropic/models/claude-3-haiku@20240307"),
    "claude-3-haiku-20240307"
  )
})

test_that("resolve_model passes through known model names unchanged", {
  reset_costs()
  expect_equal(resolve_model("gpt-4o"), "gpt-4o")
  expect_equal(resolve_model("claude-opus-4-6"), "claude-opus-4-6")
  expect_equal(resolve_model("gemini-1.5-pro"), "gemini-1.5-pro")
})

test_that("resolve_model passes through unknown names unchanged", {
  reset_costs()
  expect_equal(resolve_model("my-custom-model"), "my-custom-model")
  expect_equal(resolve_model("totally-unknown-v99"), "totally-unknown-v99")
})

test_that("calculate_cost works with Bedrock model IDs via alias resolution", {
  reset_costs()
  bedrock_id <- "anthropic.claude-3-sonnet-20240229-v1:0"
  canonical <- "claude-3-sonnet-20240229"

  cost_bedrock <- calculate_cost(bedrock_id, 1e6, 1e6)
  cost_canonical <- calculate_cost(canonical, 1e6, 1e6)

  expect_equal(cost_bedrock, cost_canonical)
  expect_true(cost_bedrock > 0)
})

test_that("add_model_alias works for custom aliases", {
  reset_costs()
  # Add a custom alias

  add_model_alias("my-azure-deployment", "gpt-4o")
  expect_equal(resolve_model("my-azure-deployment"), "gpt-4o")

  # Cost calculation works through the alias
  cost_alias <- calculate_cost("my-azure-deployment", 1000, 500)
  cost_direct <- calculate_cost("gpt-4o", 1000, 500)
  expect_equal(cost_alias, cost_direct)

  # Reset clears custom aliases
  reset_costs()
  expect_equal(resolve_model("my-azure-deployment"), "my-azure-deployment")
})

# --- Existing tests ---

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
