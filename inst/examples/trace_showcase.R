#!/usr/bin/env Rscript
# trace_showcase.R -- Self-contained demo of the securetrace full pipeline
#
# Run from repo root:
#   Rscript securetrace/inst/demo/trace_showcase.R
#
# No API keys needed. All "LLM responses" are simulated with Sys.sleep()
# and direct token recording.

library(securetrace)

cat("=== securetrace showcase ===\n\n")

# ---- Setup: export to a temp JSONL file ----
jsonl_path <- tempfile("trace_showcase_", fileext = ".jsonl")
exp <- jsonl_exporter(jsonl_path)

# ---- Build a realistic multi-step agent trace ----
.result <- with_trace("research-agent", exporter = exp, task = "summarize paper", user = "demo", {

  # Step 1: Planning -- LLM decides what tools to call
  with_span("planning", type = "llm", {
    Sys.sleep(0.05)  # simulate LLM latency
    s <- current_span()
    s$set_model("claude-sonnet-4-5")
    s$set_tokens(input = 1200L, output = 350L)
    s$add_event(trace_event("prompt_sent", data = list(
      system_prompt_len = 800L,
      user_prompt_len = 400L
    )))
    s$add_metric("temperature", 0.3, unit = "degrees")
    "plan: fetch paper, check safety, summarize"
  })

  # Step 2: Tool use -- fetch a document
  with_span("fetch-document", type = "tool", {
    Sys.sleep(0.03)  # simulate HTTP fetch
    s <- current_span()
    s$add_event(trace_event("http_request", data = list(
      url = "https://example.com/paper.pdf",
      status = 200L
    )))
    s$add_metric("response_bytes", 45000L, unit = "bytes")
    "fetched 15 pages of content"
  })

  # Step 3: Guardrail -- check content for PII/injection
  with_span("content-safety", type = "guardrail", {
    Sys.sleep(0.02)  # simulate guardrail analysis
    s <- current_span()
    s$add_event(trace_event("guard_result", data = list(
      guard_name = "pii_detector",
      pass = TRUE,
      score = 0.99
    )))
    s$add_event(trace_event("guard_result", data = list(
      guard_name = "injection_detector",
      pass = TRUE,
      score = 1.0
    )))
    s$add_metric("pii_score", 0.99)
    s$add_metric("injection_score", 1.0)
    TRUE
  })

  # Step 4: Summarization -- LLM generates the final answer
  with_span("summarization", type = "llm", {
    Sys.sleep(0.06)  # simulate longer LLM call
    parent_id <- current_span()$span_id

    # Record tokens and model on the summarization span
    s <- current_span()
    s$set_model("claude-sonnet-4-5")
    s$set_tokens(input = 4000L, output = 800L)
    s$add_event(trace_event("response_received", data = list(
      finish_reason = "end_turn",
      output_tokens = 800L
    )))
    s$add_metric("latency", 0.06, unit = "seconds")

    # Nested span: output formatting inside summarization
    with_span("format-markdown", type = "custom", {
      Sys.sleep(0.01)
      child <- current_span()
      child$add_event(trace_event("formatting_applied", data = list(
        format = "markdown",
        sections = 4L
      )))
      child$add_metric("output_chars", 3200L, unit = "chars")
    })

    "## Summary\n\nThe paper presents..."
  })

  # Step 5: Post-processing custom span
  with_span("cache-result", type = "custom", {
    Sys.sleep(0.01)
    s <- current_span()
    s$add_event(trace_event("cache_write", data = list(
      key = "paper-abc123",
      ttl_secs = 3600L
    )))
    s$add_metric("cache_size_kb", 12.5, unit = "KB")
  })

  invisible(NULL)
})

cat("Trace completed.\n\n")

# ---- Print trace summary ----
cat("--- Trace Summary (from summary method) ---\n")
# Re-read from JSONL to show export/import roundtrip
lines <- readLines(jsonl_path)
parsed <- jsonlite::fromJSON(lines[[1]], simplifyVector = FALSE)
spans <- parsed$spans

# Reconstruct summary manually from parsed data
total_input <- 0L
total_output <- 0L
for (sp in spans) {
  total_input  <- total_input  + sp$input_tokens
  total_output <- total_output + sp$output_tokens
}

# Calculate cost from the parsed data
total_cost <- 0
for (sp in spans) {
  if (!is.null(sp$model)) {
    total_cost <- total_cost + calculate_cost(sp$model, sp$input_tokens, sp$output_tokens)
  }
}

cat(sprintf("Trace: %s (%s)\n", parsed$name, parsed$status))
cat(sprintf("  ID:       %s\n", parsed$trace_id))
cat(sprintf("  Duration: %.2fs\n", parsed$duration_secs))
cat(sprintf("  Spans:    %d\n", length(spans)))
cat(sprintf("  Tokens:   %d input, %d output\n", total_input, total_output))
cat(sprintf("  Cost:     $%.6f\n", total_cost))
cat("\n")

# ---- Print span tree visualization ----
cat("--- Span Tree ---\n")

# Build parent-child lookup
span_children <- list()
root_spans <- list()
for (sp in spans) {
  if (is.null(sp$parent_id)) {
    root_spans <- c(root_spans, list(sp))
  } else {
    pid <- sp$parent_id
    if (is.null(span_children[[pid]])) {
      span_children[[pid]] <- list()
    }
    span_children[[pid]] <- c(span_children[[pid]], list(sp))
  }
}

# Recursive tree printer
print_span <- function(sp, indent = "") {
  dur_str <- if (!is.null(sp$duration_secs)) sprintf("%.3fs", sp$duration_secs) else "N/A"
  model_str <- if (!is.null(sp$model)) paste0(" model=", sp$model) else ""
  token_str <- ""
  if (sp$input_tokens > 0 || sp$output_tokens > 0) {
    token_str <- sprintf(" tokens=%d/%d", sp$input_tokens, sp$output_tokens)
  }
  event_count <- length(sp$events)
  metric_count <- length(sp$metrics)
  extras <- paste0(
    if (event_count > 0) sprintf(" events=%d", event_count) else "",
    if (metric_count > 0) sprintf(" metrics=%d", metric_count) else ""
  )
  cat(sprintf("%s[%s] %s (%s) %s%s%s%s\n",
              indent, sp$type, sp$name, dur_str,
              model_str, token_str, extras, ""))

  # Print children
  children <- span_children[[sp$span_id]]
  if (!is.null(children)) {
    for (child in children) {
      print_span(child, paste0(indent, "  "))
    }
  }
}

for (sp in root_spans) {
  print_span(sp, "  ")
}
cat("\n")

# ---- Validation assertions ----
cat("--- Validation ---\n")
errors <- character(0)

# 1. Parent-child links are valid
all_ids <- vapply(spans, `[[`, character(1), "span_id")
for (sp in spans) {
  if (!is.null(sp$parent_id)) {
    if (!sp$parent_id %in% all_ids) {
      errors <- c(errors, sprintf("Span '%s' has invalid parent_id '%s'", sp$name, sp$parent_id))
    }
  }
}

# 2. Timing monotonicity: end >= start for every span
for (sp in spans) {
  start_t <- as.POSIXct(sp$start_time, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  end_t   <- as.POSIXct(sp$end_time,   format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  if (end_t < start_t) {
    errors <- c(errors, sprintf("Span '%s' has end_time before start_time", sp$name))
  }
  if (sp$duration_secs < 0) {
    errors <- c(errors, sprintf("Span '%s' has negative duration", sp$name))
  }
}

# 3. Trace-level timing
trace_start <- as.POSIXct(parsed$start_time, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
trace_end   <- as.POSIXct(parsed$end_time,   format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
if (trace_end < trace_start) {
  errors <- c(errors, "Trace end_time is before start_time")
}

# 4. Cost correctness: manually recompute and compare
recomputed_cost <- 0
for (sp in spans) {
  if (!is.null(sp$model)) {
    recomputed_cost <- recomputed_cost + calculate_cost(sp$model, sp$input_tokens, sp$output_tokens)
  }
}
if (abs(total_cost - recomputed_cost) > 1e-10) {
  errors <- c(errors, sprintf("Cost mismatch: displayed $%.6f vs recomputed $%.6f",
                               total_cost, recomputed_cost))
}

# 5. All spans should be status "ok"
for (sp in spans) {
  if (sp$status != "ok") {
    errors <- c(errors, sprintf("Span '%s' has unexpected status '%s'", sp$name, sp$status))
  }
}

# 6. Trace should be "completed"
if (parsed$status != "completed") {
  errors <- c(errors, sprintf("Trace status is '%s', expected 'completed'", parsed$status))
}

# 7. Span IDs are unique
if (length(unique(all_ids)) != length(all_ids)) {
  errors <- c(errors, "Duplicate span IDs detected")
}

# 8. Expected span count
if (length(spans) != 6) {
  errors <- c(errors, sprintf("Expected 6 spans, got %d", length(spans)))
}

# 9. Token totals match expectations
expected_input  <- 1200L + 4000L  # planning + summarization
expected_output <- 350L + 800L
if (total_input != expected_input) {
  errors <- c(errors, sprintf("Input tokens: expected %d, got %d", expected_input, total_input))
}
if (total_output != expected_output) {
  errors <- c(errors, sprintf("Output tokens: expected %d, got %d", expected_output, total_output))
}

# 10. Cost must be positive (we used known models)
if (total_cost <= 0) {
  errors <- c(errors, "Total cost should be > 0 for known models")
}

# Report
if (length(errors) == 0) {
  cat("All validations passed.\n")
} else {
  cat(sprintf("FAILURES (%d):\n", length(errors)))
  for (err in errors) {
    cat(sprintf("  - %s\n", err))
  }
  quit(status = 1)
}

# Cleanup
unlink(jsonl_path)
cat("\nShowcase complete.\n")
