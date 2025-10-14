# TASK 05: LLM API Tracking Integration

**Estimated Time:** 1.5 hours  
**Priority:** HIGH  
**Status:** 🔴 Not Started  
**Depends On:** TASK_01 complete (independent of deduplication tasks)

---

## Goal
Integrate detailed LLM API call tracking to monitor token usage, costs, and performance across Claude and GPT-4.

---

## Background
You already have basic AI extraction tracking in `ai_extractions` table. Now add detailed metrics tracking:
- Token usage (prompt + completion)
- Processing time
- API costs
- Success/failure rates
- Model comparison (Claude vs GPT-4)

---

## What You Need to Do

### Step 1: Copy LLM Tracking Module

```r
file.copy(
  from = "Test_Delcampe/R/tracking_llm.R",
  to = "R/tracking_llm.R"
)
```

### Step 2: Review the Functions

`tracking_llm.R` should contain:

```r
# Main tracking function
track_llm_api_call(
  session_id,
  image_path,
  model,           # "claude-3-5-sonnet" or "gpt-4"
  prompt_type,     # "individual", "batch", "contextual"
  status,          # "pending", "success", "failed"
  response_data,   # Parsed response
  tokens_used,     # List: prompt_tokens, completion_tokens, total_tokens
  processing_time, # Numeric: seconds
  cost_usd,        # Numeric: estimated cost
  error_message    # Character: if failed
)

# Statistics functions
get_llm_usage_stats()
get_llm_usage_stats_by_model(model = NULL)
export_llm_api_call_history(output_file)
```

### Step 3: Find AI Extraction Code

Locate your AI extraction function. This is likely in:
- `R/mod_delcampe_export.R` 
- Look for Claude/GPT-4 API calls

Should look something like:
```r
# Existing code
result <- call_claude_api(
  prompt = enhanced_prompt,
  images = image_data,
  model = config$default_model
)
```

### Step 4: Wrap API Calls with Tracking

Add tracking BEFORE and AFTER each API call:

```r
# BEFORE: Log pending call
call_id <- track_llm_api_call(
  session_id = session$token,
  image_path = current_image_path,
  model = config$default_model,
  prompt_type = "individual",
  status = "pending"
)

# Record start time
start_time <- Sys.time()

# Make API call
result <- call_claude_api(
  prompt = enhanced_prompt,
  images = image_data,
  model = config$default_model
)

# Calculate processing time
processing_time <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

# AFTER SUCCESS: Update with results
if (result$success) {
  parsed <- parse_enhanced_ai_response(result$content)
  
  # Existing tracking (keep this)
  track_ai_extraction(
    image_id = image_id,
    model = config$default_model,
    title = parsed$title,
    description = parsed$description,
    condition = parsed$condition,
    recommended_price = parsed$price,
    success = TRUE
  )
  
  # NEW: Detailed LLM tracking
  track_llm_api_call(
    session_id = session$token,
    image_path = current_image_path,
    model = config$default_model,
    prompt_type = "individual",
    status = "success",
    response_data = parsed,
    tokens_used = list(
      prompt_tokens = result$usage$prompt_tokens,
      completion_tokens = result$usage$completion_tokens,
      total_tokens = result$usage$total_tokens
    ),
    processing_time = processing_time,
    cost_usd = calculate_api_cost(result$usage, config$default_model)
  )
}

# AFTER FAILURE: Log error
if (!result$success) {
  track_llm_api_call(
    session_id = session$token,
    image_path = current_image_path,
    model = config$default_model,
    prompt_type = "individual",
    status = "failed",
    error_message = result$error,
    processing_time = processing_time
  )
  
  # Also track in ai_extractions table
  track_ai_extraction(
    image_id = image_id,
    model = config$default_model,
    success = FALSE,
    error_message = result$error
  )
}
```

### Step 5: Add Cost Calculation Helper

Create a helper function to estimate API costs:

```r
#' Calculate API cost based on token usage
calculate_api_cost <- function(usage, model) {
  if (is.null(usage)) return(0)
  
  # Pricing per 1K tokens (as of Oct 2024, update if needed)
  pricing <- list(
    "claude-3-5-sonnet-20241022" = list(input = 0.003, output = 0.015),
    "claude-3-5-sonnet-20240620" = list(input = 0.003, output = 0.015),
    "claude-sonnet-4-20250514" = list(input = 0.003, output = 0.015),
    "gpt-4-turbo" = list(input = 0.01, output = 0.03),
    "gpt-4" = list(input = 0.03, output = 0.06)
  )
  
  if (!model %in% names(pricing)) {
    return(0)  # Unknown model
  }
  
  rates <- pricing[[model]]
  
  cost <- (usage$prompt_tokens / 1000 * rates$input) +
          (usage$completion_tokens / 1000 * rates$output)
  
  return(round(cost, 4))
}
```

### Step 6: Handle Batch Processing

If you have batch processing (multiple images in one API call):

```r
# Before batch call
track_llm_api_call(
  session_id = session$token,
  image_path = paste(image_paths, collapse = ";"),  # Join paths
  model = config$default_model,
  prompt_type = "batch",
  status = "pending"
)

# After batch call (if successful)
track_llm_api_call(
  session_id = session$token,
  image_path = paste(image_paths, collapse = ";"),
  model = config$default_model,
  prompt_type = "batch",
  status = "success",
  response_data = parsed_batch_results,
  tokens_used = batch_usage,
  processing_time = processing_time,
  cost_usd = calculate_api_cost(batch_usage, config$default_model)
)
```

### Step 7: Create Statistics Dashboard (Optional)

Add a simple UI to view LLM statistics:

```r
# In your UI
tabPanel("LLM Statistics",
  fluidRow(
    column(6,
      h4("Overall Statistics"),
      verbatimTextOutput("llm_stats_overall")
    ),
    column(6,
      h4("By Model"),
      verbatimTextOutput("llm_stats_by_model")
    )
  ),
  downloadButton("download_llm_history", "Export Call History")
)

# In your server
output$llm_stats_overall <- renderPrint({
  stats <- get_llm_usage_stats()
  cat(sprintf("Total Calls: %d\n", stats$total_calls))
  cat(sprintf("Success Rate: %.1f%%\n", stats$success_rate))
  cat(sprintf("Total Tokens: %s\n", format(stats$total_tokens, big.mark = ",")))
  cat(sprintf("Total Cost: $%.2f\n", stats$total_cost))
  cat(sprintf("Avg Time: %.2f seconds\n", stats$avg_processing_time))
})

output$llm_stats_by_model <- renderPrint({
  stats_claude <- get_llm_usage_stats_by_model("claude")
  stats_gpt4 <- get_llm_usage_stats_by_model("gpt-4")
  
  cat("=== Claude ===\n")
  cat(sprintf("Calls: %d\n", stats_claude$total_calls))
  cat(sprintf("Tokens: %s\n", format(stats_claude$total_tokens, big.mark = ",")))
  cat(sprintf("Cost: $%.2f\n\n", stats_claude$total_cost))
  
  cat("=== GPT-4 ===\n")
  cat(sprintf("Calls: %d\n", stats_gpt4$total_calls))
  cat(sprintf("Tokens: %s\n", format(stats_gpt4$total_tokens, big.mark = ",")))
  cat(sprintf("Cost: $%.2f\n", stats_gpt4$total_cost))
})

output$download_llm_history <- downloadHandler(
  filename = function() {
    paste0("llm_history_", Sys.Date(), ".csv")
  },
  content = function(file) {
    export_llm_api_call_history(file)
  }
)
```

---

## Testing

### Test 1: Single API Call Tracking
```r
# Make one AI extraction
# Check that both tables updated:
con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")

# Basic tracking
dbGetQuery(con, "SELECT * FROM ai_extractions ORDER BY extracted_at DESC LIMIT 1")

# Detailed LLM tracking
# (This depends on how tracking_llm.R stores data - JSON or SQLite)
stats <- get_llm_usage_stats()
print(stats)

dbDisconnect(con)
```

### Test 2: Failed Call Tracking
```r
# Trigger an API failure (wrong API key, timeout, etc.)
# Verify error logged in both systems
```

### Test 3: Cost Calculation
```r
# Test cost calculation
usage <- list(prompt_tokens = 1000, completion_tokens = 500, total_tokens = 1500)
cost_claude <- calculate_api_cost(usage, "claude-3-5-sonnet-20241022")
cost_gpt4 <- calculate_api_cost(usage, "gpt-4-turbo")

print(cost_claude)  # Should be around $0.011
print(cost_gpt4)    # Should be around $0.025
```

### Test 4: Statistics Functions
```r
# After several API calls, check statistics
stats_overall <- get_llm_usage_stats()
print(stats_overall)

stats_by_model <- get_llm_usage_stats_by_model("claude")
print(stats_by_model)
```

---

## Key Points

1. **Two-level tracking:**
   - `ai_extractions` table: High-level results (title, description, etc.)
   - LLM tracking: Detailed metrics (tokens, cost, timing)

2. **When to track:**
   - PENDING: Right before API call
   - SUCCESS: After successful response
   - FAILED: After any error

3. **What to track:**
   - Token usage (prompt + completion + total)
   - Processing time (in seconds)
   - Cost (in USD)
   - Model used
   - Prompt type (individual vs batch)

4. **Cost tracking:**
   - Update pricing periodically
   - Track both Claude and GPT-4 separately
   - Useful for budget monitoring

---

## Deliverables

- ✅ `R/tracking_llm.R` copied and working
- ✅ API calls wrapped with tracking
- ✅ Cost calculation implemented
- ✅ Statistics functions tested
- ✅ Optional: Statistics dashboard added

---

## Next Steps
Once this task is complete, proceed to **TASK_06_STATISTICS_AND_REPORTING.md**
