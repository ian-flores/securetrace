# End-to-end integration test: full pipeline without mocks
# Exercises: with_trace, with_span (all types), tokens, events, metrics,
#            JSONL export, read-back, and structural validation.

test_that("full pipeline: trace -> nested spans -> export -> read-back -> validate", {
  reset_context()
  reset_costs()

  tmp <- tempfile(fileext = ".jsonl")
  on.exit(unlink(tmp), add = TRUE)

  exp <- jsonl_exporter(tmp)

  # ---------- build a realistic trace ----------
  with_trace("agent-run", exporter = exp, user = "test-user", {

    # 1. LLM span (planning step)
    with_span("planning", type = "llm", {
      Sys.sleep(0.02)
      s <- current_span()
      s$set_model("gpt-4o")
      s$set_tokens(input = 500L, output = 200L)
      s$add_event(trace_event("prompt_sent", data = list(length = 42L)))
      s$add_metric("temperature", 0.7, unit = "degrees")
    })

    # 2. Tool span (calculator)
    with_span("calculator", type = "tool", {
      Sys.sleep(0.01)
      s <- current_span()
      s$add_event(trace_event("tool_invoked", data = list(tool = "calc")))
      s$add_metric("result_size", 1L, unit = "items")
      42
    })

    # 3. Guardrail span (content filter)
    with_span("content-filter", type = "guardrail", {
      Sys.sleep(0.01)
      s <- current_span()
      s$add_event(trace_event("guard_passed", data = list(score = 0.98)))
      s$add_metric("confidence", 0.98)
    })

    # 4. Custom span (post-processing) with a nested child
    with_span("post-process", type = "custom", {
      Sys.sleep(0.01)
      parent_id <- current_span()$span_id

      # nested child inside the custom span
      with_span("format-output", type = "custom", {
        Sys.sleep(0.01)
        child <- current_span()
        child$add_event(trace_event("formatting_done"))
        child$add_metric("char_count", 256L, unit = "chars")
      })
    })

    # 5. Second LLM span (summarization) -- different model
    with_span("summarize", type = "llm", {
      Sys.sleep(0.02)
      s <- current_span()
      s$set_model("claude-sonnet-4-5")
      s$set_tokens(input = 300L, output = 150L)
      s$add_event(trace_event("response_received", data = list(tokens = 150L)))
    })
  })

  # ---------- read back the JSONL ----------
  lines <- readLines(tmp)
  expect_length(lines, 1)

  parsed <- jsonlite::fromJSON(lines[[1]], simplifyVector = FALSE)

  # ---------- trace-level checks ----------
  expect_equal(parsed$name, "agent-run")
  expect_equal(parsed$status, "completed")
  expect_type(parsed$trace_id, "character")
  expect_true(nchar(parsed$trace_id) > 0)
  expect_type(parsed$start_time, "character")
  expect_type(parsed$end_time, "character")
  expect_true(parsed$duration_secs >= 0)

  # metadata forwarded from ... args
  expect_equal(parsed$metadata$user, "test-user")

  # ---------- span count ----------
  spans <- parsed$spans
  expect_length(spans, 6)  # planning, calculator, content-filter, post-process, format-output, summarize

  # Build a lookup by name for easier assertions
  span_by_name <- stats::setNames(spans, vapply(spans, `[[`, character(1), "name"))

  # ---------- span types ----------
  expect_equal(span_by_name$planning$type, "llm")
  expect_equal(span_by_name$calculator$type, "tool")
  expect_equal(span_by_name[["content-filter"]]$type, "guardrail")
  expect_equal(span_by_name[["post-process"]]$type, "custom")
  expect_equal(span_by_name[["format-output"]]$type, "custom")
  expect_equal(span_by_name$summarize$type, "llm")

  # ---------- all spans completed OK ----------
  for (sp in spans) {
    expect_equal(sp$status, "ok", info = paste("span:", sp$name))
  }

  # ---------- parent-child relationships ----------
  # Root spans (no parent): planning, calculator, content-filter, post-process, summarize
  expect_null(span_by_name$planning$parent_id)
  expect_null(span_by_name$calculator$parent_id)
  expect_null(span_by_name[["content-filter"]]$parent_id)
  expect_null(span_by_name[["post-process"]]$parent_id)
  expect_null(span_by_name$summarize$parent_id)

  # format-output is a child of post-process
  expect_equal(
    span_by_name[["format-output"]]$parent_id,
    span_by_name[["post-process"]]$span_id
  )

  # ---------- timing: end >= start for all spans ----------
  for (sp in spans) {
    start_t <- as.POSIXct(sp$start_time, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
    end_t   <- as.POSIXct(sp$end_time,   format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
    expect_true(
      end_t >= start_t,
      info = paste("timing for span:", sp$name)
    )
    expect_true(sp$duration_secs >= 0, info = paste("duration for span:", sp$name))
  }

  # ---------- token totals ----------
  total_input <- 0L
  total_output <- 0L
  for (sp in spans) {
    total_input  <- total_input  + sp$input_tokens
    total_output <- total_output + sp$output_tokens
  }
  expect_equal(total_input,  500L + 300L)
  expect_equal(total_output, 200L + 150L)

  # ---------- model recorded on LLM spans ----------
  expect_equal(span_by_name$planning$model, "gpt-4o")
  expect_equal(span_by_name$summarize$model, "claude-sonnet-4-5")
  # Non-LLM spans should have null model
  expect_null(span_by_name$calculator$model)
  expect_null(span_by_name[["content-filter"]]$model)

  # ---------- cost > 0 ----------
  # Manually compute expected cost to verify
  expected_cost <- calculate_cost("gpt-4o", 500, 200) +
    calculate_cost("claude-sonnet-4-5", 300, 150)
  expect_true(expected_cost > 0)

  # ---------- events ----------
  # planning span should have 1 event ("prompt_sent")
  planning_events <- span_by_name$planning$events
  expect_length(planning_events, 1)
  expect_equal(planning_events[[1]]$name, "prompt_sent")
  expect_equal(planning_events[[1]]$data$length, 42L)

  # calculator span should have 1 event ("tool_invoked")
  calc_events <- span_by_name$calculator$events
  expect_length(calc_events, 1)
  expect_equal(calc_events[[1]]$name, "tool_invoked")

  # content-filter has 1 event ("guard_passed")
  guard_events <- span_by_name[["content-filter"]]$events
  expect_length(guard_events, 1)
  expect_equal(guard_events[[1]]$name, "guard_passed")
  expect_equal(guard_events[[1]]$data$score, 0.98)

  # format-output has 1 event ("formatting_done")
  fmt_events <- span_by_name[["format-output"]]$events
  expect_length(fmt_events, 1)
  expect_equal(fmt_events[[1]]$name, "formatting_done")

  # summarize has 1 event ("response_received")
  sum_events <- span_by_name$summarize$events
  expect_length(sum_events, 1)
  expect_equal(sum_events[[1]]$name, "response_received")
  expect_equal(sum_events[[1]]$data$tokens, 150L)

  # ---------- metrics ----------
  # planning: temperature metric
  planning_metrics <- span_by_name$planning$metrics
  expect_length(planning_metrics, 1)
  expect_equal(planning_metrics[[1]]$name, "temperature")
  expect_equal(planning_metrics[[1]]$value, 0.7)
  expect_equal(planning_metrics[[1]]$unit, "degrees")

  # calculator: result_size metric
  calc_metrics <- span_by_name$calculator$metrics
  expect_length(calc_metrics, 1)
  expect_equal(calc_metrics[[1]]$name, "result_size")
  expect_equal(calc_metrics[[1]]$value, 1L)

  # content-filter: confidence metric
  guard_metrics <- span_by_name[["content-filter"]]$metrics
  expect_length(guard_metrics, 1)
  expect_equal(guard_metrics[[1]]$name, "confidence")
  expect_equal(guard_metrics[[1]]$value, 0.98)

  # format-output: char_count metric
  fmt_metrics <- span_by_name[["format-output"]]$metrics
  expect_length(fmt_metrics, 1)
  expect_equal(fmt_metrics[[1]]$name, "char_count")
  expect_equal(fmt_metrics[[1]]$value, 256L)
  expect_equal(fmt_metrics[[1]]$unit, "chars")

  # ---------- each event has a timestamp ----------
  for (sp in spans) {
    for (evt in sp$events) {
      expect_type(evt$timestamp, "character")
      expect_true(nchar(evt$timestamp) > 0, info = paste("event ts in span:", sp$name))
    }
  }

  # ---------- span IDs are unique ----------
  all_ids <- vapply(spans, `[[`, character(1), "span_id")
  expect_length(unique(all_ids), length(all_ids))

  reset_context()
  reset_costs()
})

test_that("trace summary reflects token and cost totals", {
  reset_context()
  reset_costs()

  with_trace("summary-e2e", {
    with_span("llm-call", type = "llm", {
      s <- current_span()
      s$set_model("gpt-4o")
      s$set_tokens(input = 1000L, output = 500L)
    })

    with_span("tool-call", type = "tool", {
      Sys.sleep(0.01)
    })

    tr <- current_trace()
    msg <- tr$summary()
    expect_match(msg, "summary-e2e")
    expect_match(msg, "1000 input")
    expect_match(msg, "500 output")
    expect_match(msg, "Spans: 2")
    # Cost should be present (non-zero string)
    expect_match(msg, "Cost:")
  })

  reset_context()
  reset_costs()
})

test_that("record_tokens and record_metric convenience wrappers work end-to-end", {
  reset_context()
  reset_costs()

  tmp <- tempfile(fileext = ".jsonl")
  on.exit(unlink(tmp), add = TRUE)

  exp <- jsonl_exporter(tmp)

  with_trace("convenience-api", exporter = exp, {
    with_span("llm-step", type = "llm", {
      record_tokens(800, 400, model = "gpt-4o-mini")
      record_latency(0.55)
      record_metric("confidence", 0.92)
    })
  })

  lines <- readLines(tmp)
  parsed <- jsonlite::fromJSON(lines[[1]], simplifyVector = FALSE)
  sp <- parsed$spans[[1]]

  expect_equal(sp$input_tokens, 800L)
  expect_equal(sp$output_tokens, 400L)
  expect_equal(sp$model, "gpt-4o-mini")

  # Should have 2 metrics: latency and confidence
  expect_length(sp$metrics, 2)
  metric_names <- vapply(sp$metrics, `[[`, character(1), "name")
  expect_true("latency" %in% metric_names)
  expect_true("confidence" %in% metric_names)

  reset_context()
  reset_costs()
})

test_that("error in span sets error status and still exports", {
  reset_context()
  reset_costs()

  tmp <- tempfile(fileext = ".jsonl")
  on.exit(unlink(tmp), add = TRUE)

  exp <- jsonl_exporter(tmp)

  expect_error(
    with_trace("error-e2e", exporter = exp, {
      with_span("ok-span", type = "custom", {
        Sys.sleep(0.01)
      })
      with_span("fail-span", type = "tool", {
        stop("simulated failure")
      })
    }),
    "simulated failure"
  )

  lines <- readLines(tmp)
  expect_length(lines, 1)
  parsed <- jsonlite::fromJSON(lines[[1]], simplifyVector = FALSE)

  # Trace should be in error state

  expect_equal(parsed$status, "error")

  # Should have 2 spans (ok-span completed, fail-span errored)
  expect_length(parsed$spans, 2)

  span_by_name <- stats::setNames(
    parsed$spans,
    vapply(parsed$spans, `[[`, character(1), "name")
  )
  expect_equal(span_by_name[["ok-span"]]$status, "ok")
  expect_equal(span_by_name[["fail-span"]]$status, "error")
  expect_type(span_by_name[["fail-span"]]$error, "character")
  expect_match(span_by_name[["fail-span"]]$error, "simulated failure")

  reset_context()
  reset_costs()
})

test_that("multi_exporter exports to multiple destinations end-to-end", {
  reset_context()
  reset_costs()

  tmp1 <- tempfile(fileext = ".jsonl")
  tmp2 <- tempfile(fileext = ".jsonl")
  on.exit({
    unlink(tmp1)
    unlink(tmp2)
  }, add = TRUE)

  exp <- multi_exporter(jsonl_exporter(tmp1), jsonl_exporter(tmp2))

  with_trace("multi-e2e", exporter = exp, {
    with_span("work", type = "custom", { 1 + 1 })
  })

  lines1 <- readLines(tmp1)
  lines2 <- readLines(tmp2)
  expect_length(lines1, 1)
  expect_length(lines2, 1)

  p1 <- jsonlite::fromJSON(lines1[[1]], simplifyVector = FALSE)
  p2 <- jsonlite::fromJSON(lines2[[1]], simplifyVector = FALSE)
  expect_equal(p1$name, "multi-e2e")
  expect_equal(p2$name, "multi-e2e")
  expect_equal(p1$trace_id, p2$trace_id)

  reset_context()
  reset_costs()
})
