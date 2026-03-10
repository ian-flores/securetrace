test_that("resource creates correct structure", {
  res <- resource("my-service", service_version = "1.0.0",
                  deployment_environment = "prod")
  expect_s3_class(res, "securetrace_resource")
  expect_equal(res$service.name, "my-service")
  expect_equal(res$service.version, "1.0.0")
  expect_equal(res$deployment.environment, "prod")
})

test_that("resource includes extra attributes", {
  res <- resource("svc", custom_key = "custom_value")
  expect_equal(res$custom_key, "custom_value")
})

test_that("set_resource validates input", {
  expect_error(set_resource("not a resource"))
})

test_that("resource appears in trace to_list", {
  reset_context()
  on.exit(reset_context())

  set_resource(resource("test-svc", service_version = "0.1.0"))

  result <- with_trace("test", {
    tr <- current_trace()
    tr$to_list()
  })

  expect_equal(result$resource$service.name, "test-svc")
})
