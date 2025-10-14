# TASK 07: Documentation and Testing

**Estimated Time:** 1 hour  
**Priority:** MEDIUM  
**Status:** 🔴 Not Started  
**Depends On:** All previous tasks complete

---

## Goal
Update documentation and create comprehensive tests for all new functionality.

---

## What You Need to Do

### Step 1: Update INTEGRATION_GUIDE.md

Add sections for new features:

```markdown
## Deduplication Workflow

### How It Works
1. User uploads image
2. System calculates hash: `calculate_image_hash(path)`
3. System checks database: `find_existing_processing(hash, type)`
4. If duplicate found:
   - Modal appears asking user
   - User chooses: Reuse or Process Again
   - If reuse: Crops copied, boundaries restored
5. Processing continues

### Integration Points
- **Upload handler:** Add hash calculation and duplicate check
- **Modal handlers:** Add "Reuse" and "Process Again" buttons
- **Database:** Store hash in `images.file_hash` column

### Example Code
[Include code examples from TASK_04]

---

## LLM API Tracking

### How It Works
1. Before API call: Log pending status
2. Make API call
3. After success/failure: Update with results
4. Track: tokens, cost, processing time, model

### Integration Points
- **AI extraction function:** Wrap API calls with tracking
- **Cost calculation:** Use `calculate_api_cost()` helper
- **Statistics:** Use `get_llm_usage_stats()` to view metrics

### Example Code
[Include code examples from TASK_05]

---

## Statistics Functions

### Available Functions
1. `calculate_session_stats(session_id)` - Session-level metrics
2. `calculate_overall_stats(start_date, end_date)` - System-wide metrics
3. `export_statistics_report(file, format)` - Export to CSV/JSON
4. `compare_periods(...)` - Compare time periods

### Usage Examples
[Include code examples from TASK_06]
```

### Step 2: Update QUICK_REFERENCE.md

Add all new functions to the quick reference guide. See the detailed function signatures in the previous task files.

### Step 3: Create Comprehensive Test Suite

Create `test_all_tracking.R`:

```r
library(testthat)

# Source all tracking modules
source("R/tracking_database.R")
source("R/tracking_deduplication.R")
source("R/tracking_llm.R")
source("R/fct_tracking.R")

cat("Starting comprehensive tracking system tests...\n\n")

# Test Suite 1: Database Functions
cat("=== Test Suite 1: Database Functions ===\n")
source("test_database_tracking.R")

# Test Suite 2: Deduplication
cat("\n=== Test Suite 2: Deduplication ===\n")

test_that("Hash calculation works", {
  # Need a test image
  test_image <- "inst/app/data/test_image.jpg"
  if (file.exists(test_image)) {
    hash <- calculate_image_hash(test_image)
    expect_type(hash, "character")
    expect_true(nchar(hash) > 0)
  } else {
    skip("Test image not found")
  }
})

test_that("Deduplication workflow - full cycle", {
  # Create session and upload first image
  session_id_1 <- create_tracking_session("test_user")
  image_id_1 <- track_image_upload(session_id_1, "test_first.jpg", "face")
  
  # Calculate and store hash
  hash <- "test_hash_abc123"
  store_image_hash(image_id_1, hash)
  
  # Simulate processing completion
  track_processing_step(
    image_id = image_id_1,
    action = "extraction_complete",
    details = list(
      h_boundaries = c(0.2, 0.8),
      v_boundaries = c(0.1, 0.9),
      cropped_paths = c("crop1.jpg", "crop2.jpg")
    )
  )
  
  # Try to find existing processing (should find it)
  existing <- find_existing_processing(hash, "face")
  expect_false(is.null(existing))
  expect_equal(existing$image_id, image_id_1)
  expect_equal(existing$h_boundaries, c(0.2, 0.8))
  
  # Create second session (simulating re-upload)
  session_id_2 <- create_tracking_session("test_user")
  image_id_2 <- track_image_upload(session_id_2, "test_second.jpg", "face")
  
  # Mark as reused
  result <- mark_processing_reused(session_id_2, session_id_1, image_id_2, image_id_1)
  expect_true(result)
})

test_that("Find existing returns NULL for new hash", {
  result <- find_existing_processing("nonexistent_hash_xyz", "face")
  expect_null(result)
})

# Test Suite 3: LLM Tracking
cat("\n=== Test Suite 3: LLM Tracking ===\n")

test_that("LLM API call tracking", {
  session_id <- create_tracking_session("test_user")
  
  # Track pending call
  call_id <- track_llm_api_call(
    session_id = session_id,
    image_path = "test.jpg",
    model = "claude-3-5-sonnet",
    prompt_type = "individual",
    status = "pending"
  )
  
  expect_true(!is.null(call_id))
  
  # Track success
  track_llm_api_call(
    session_id = session_id,
    image_path = "test.jpg",
    model = "claude-3-5-sonnet",
    prompt_type = "individual",
    status = "success",
    tokens_used = list(prompt = 1000, completion = 500, total = 1500),
    processing_time = 2.5,
    cost_usd = 0.011
  )
})

test_that("API cost calculation", {
  usage <- list(prompt_tokens = 1000, completion_tokens = 500, total_tokens = 1500)
  
  cost_claude <- calculate_api_cost(usage, "claude-3-5-sonnet-20241022")
  expect_type(cost_claude, "double")
  expect_true(cost_claude > 0)
  
  cost_gpt4 <- calculate_api_cost(usage, "gpt-4-turbo")
  expect_type(cost_gpt4, "double")
  expect_true(cost_gpt4 > cost_claude)  # GPT-4 should be more expensive
})

test_that("LLM usage statistics", {
  stats <- get_llm_usage_stats()
  expect_type(stats, "list")
  expect_true("total_calls" %in% names(stats))
})

# Test Suite 4: Statistics
cat("\n=== Test Suite 4: Statistics ===\n")

test_that("Session statistics calculation", {
  session_id <- create_tracking_session("test_user")
  image_id <- track_image_upload(session_id, "test.jpg", "face")
  
  track_ai_extraction(
    image_id = image_id,
    model = "claude-3-5-sonnet",
    title = "Test Title",
    description = "Test Description",
    success = TRUE
  )
  
  stats <- calculate_session_stats(session_id)
  
  expect_type(stats, "list")
  expect_equal(stats$images_uploaded, 1)
  expect_equal(stats$ai_extractions$total, 1)
  expect_true(stats$duration_minutes >= 0)
})

test_that("Overall statistics calculation", {
  stats <- calculate_overall_stats()
  
  expect_type(stats, "list")
  expect_true("sessions" %in% names(stats))
  expect_true("images" %in% names(stats))
  expect_true("ai_extractions" %in% names(stats))
  expect_true(stats$sessions$total >= 0)
})

test_that("Statistics export to JSON", {
  temp_file <- tempfile(fileext = ".json")
  
  export_statistics_report(temp_file, format = "json")
  
  expect_true(file.exists(temp_file))
  
  # Verify JSON is valid
  data <- jsonlite::fromJSON(temp_file)
  expect_true("sessions" %in% names(data))
  
  unlink(temp_file)
})

test_that("Statistics export to CSV", {
  temp_file <- tempfile(fileext = ".csv")
  
  export_statistics_report(temp_file, format = "csv")
  
  expect_true(file.exists(temp_file))
  
  # Verify CSV is valid
  data <- read.csv(temp_file)
  expect_true(nrow(data) >= 0)
  
  unlink(temp_file)
})

cat("\n=== All Tests Complete ===\n")
cat("Run this file with: source('test_all_tracking.R')\n")
```

Run the full test suite:
```r
source("test_all_tracking.R")
```

### Step 4: Create README for Tracking System

Create `TRACKING_SYSTEM_README.md`:

```markdown
# Tracking System Documentation

Complete tracking system for the Delcampe R Shiny application.

## Overview

The tracking system monitors and records:
- User sessions and activity
- Image uploads and processing
- AI extractions (Claude/GPT-4)
- eBay posting attempts
- Image deduplication (crop reuse)
- LLM API usage (tokens, costs, performance)

## Architecture

```
tracking_database.R      - Core database functions (SQLite)
tracking_deduplication.R - Image hash and crop reuse
tracking_llm.R          - Detailed LLM API tracking
fct_tracking.R          - Statistics and reporting
```

### Database Schema

**Tables:**
- `users` - User information
- `sessions` - User sessions with timestamps
- `images` - Uploaded images with hashes
- `processing_log` - Processing steps and actions
- `ai_extractions` - AI extraction results
- `ebay_posts` - eBay posting attempts

## Quick Start

### 1. Initialize Database

```r
source("R/tracking_database.R")
init_tracking_database()
```

### 2. Create Session

```r
session_id <- create_tracking_session("user123")
```

### 3. Track Image Upload

```r
image_id <- track_image_upload(session_id, "postcard.jpg", "face")

# Calculate and store hash for deduplication
hash <- calculate_image_hash("path/to/postcard.jpg")
store_image_hash(image_id, hash)
```

### 4. Check for Duplicates

```r
existing <- find_existing_processing(hash, "face")

if (!is.null(existing)) {
  # Image was processed before
  # Show modal to user: reuse or process again?
}
```

### 5. Track AI Extraction

```r
# Before API call
track_llm_api_call(
  session_id = session_id,
  image_path = "postcard.jpg",
  model = "claude-3-5-sonnet",
  prompt_type = "individual",
  status = "pending"
)

# After success
track_ai_extraction(
  image_id = image_id,
  model = "claude-3-5-sonnet",
  title = "Vintage Paris Postcard",
  description = "...",
  success = TRUE
)

track_llm_api_call(
  session_id = session_id,
  image_path = "postcard.jpg",
  model = "claude-3-5-sonnet",
  prompt_type = "individual",
  status = "success",
  tokens_used = list(prompt = 1200, completion = 300, total = 1500),
  processing_time = 2.3,
  cost_usd = 0.011
)
```

### 6. Track eBay Posting

```r
track_ebay_post(
  image_id = image_id,
  title = "Vintage Paris Postcard",
  price = 15.99,
  status = "success",
  ebay_listing_id = "123456789"
)
```

### 7. View Statistics

```r
# Session statistics
session_stats <- calculate_session_stats(session_id)
print(session_stats)

# Overall statistics
overall_stats <- calculate_overall_stats()
print(overall_stats)

# LLM usage
llm_stats <- get_llm_usage_stats()
print(paste("Total API cost:", llm_stats$total_cost))
```

## Features

### Image Deduplication

Automatically detects when the same image is uploaded multiple times and offers to reuse existing crops.

**Benefits:**
- Saves processing time (no re-cropping needed)
- Consistent results across sessions
- Reduced workload

**How it works:**
1. Hash calculated for each uploaded image
2. Database checked for matching hash
3. If found, modal shows previous processing date
4. User chooses: reuse crops or process again
5. If reuse: crops copied, boundaries restored

### LLM API Tracking

Detailed tracking of every API call to Claude or GPT-4.

**Metrics tracked:**
- Token usage (prompt + completion)
- Processing time
- API costs
- Success/failure rates
- Model comparison

**Use cases:**
- Monitor API spending
- Compare Claude vs GPT-4 performance
- Optimize prompt efficiency
- Budget planning

### Statistics & Reporting

Comprehensive statistics at session and system levels.

**Available reports:**
- Session summary (images, extractions, duration)
- Overall system statistics
- Time period comparisons
- LLM usage by model
- Export to CSV/JSON

## File Structure

```
R/
├── tracking_database.R        # Core database functions
├── tracking_deduplication.R   # Deduplication logic
├── tracking_llm.R             # LLM API tracking
└── fct_tracking.R             # Statistics functions

inst/app/data/
└── tracking.sqlite            # SQLite database

tests/
├── test_database_tracking.R   # Database tests
├── test_deduplication.R       # Deduplication tests
└── test_all_tracking.R        # Comprehensive test suite

docs/
├── INTEGRATION_GUIDE.md       # Integration instructions
├── QUICK_REFERENCE.md         # Function reference
└── TRACKING_SYSTEM_README.md  # This file
```

## Testing

Run all tests:
```r
source("test_all_tracking.R")
```

Run specific test suites:
```r
source("test_database_tracking.R")
source("test_deduplication.R")
```

## Troubleshooting

### Database locked error
```r
# Close all connections
lapply(dbListConnections(SQLite()), dbDisconnect)
```

### Hash not found for duplicate
```r
# Verify hash was stored
con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
dbGetQuery(con, "SELECT image_id, file_hash FROM images WHERE file_hash IS NOT NULL")
dbDisconnect(con)
```

### Statistics returning zero
```r
# Check if data exists
con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
dbGetQuery(con, "SELECT COUNT(*) FROM sessions")
dbGetQuery(con, "SELECT COUNT(*) FROM images")
dbDisconnect(con)
```

## Best Practices

1. **Always close database connections** - Use `on.exit(dbDisconnect(con))`
2. **Store hashes immediately** - After image upload, before processing
3. **Track both systems** - Use both `track_ai_extraction()` and `track_llm_api_call()`
4. **Validate before reuse** - Use `validate_existing_crops()` before copying
5. **Export statistics regularly** - For backup and analysis

## API Cost Tracking

Current pricing (update as needed):

```r
# Claude 3.5 Sonnet
# Input: $0.003 per 1K tokens
# Output: $0.015 per 1K tokens

# GPT-4 Turbo
# Input: $0.01 per 1K tokens
# Output: $0.03 per 1K tokens
```

Update pricing in `calculate_api_cost()` function when rates change.

## Future Enhancements

Potential additions:
- [ ] Real-time dashboard with charts
- [ ] Email alerts for high API costs
- [ ] Automatic backup of statistics
- [ ] Image similarity matching (beyond exact hash)
- [ ] Batch processing optimization suggestions
- [ ] User-specific cost tracking

## Support

For questions or issues:
1. Check INTEGRATION_GUIDE.md for integration help
2. Check QUICK_REFERENCE.md for function usage
3. Run tests to verify system state
4. Check database directly with SQL queries

## Version History

- **v2.0.0** (Oct 2025) - Added deduplication, LLM tracking, statistics
- **v1.0.0** (Oct 2025) - Initial tracking system with database extension
```

### Step 5: Create Visual Documentation

Create `TRACKING_WORKFLOW_DIAGRAM.md`:

```markdown
# Tracking System Workflow Diagrams

## 1. Image Upload Workflow

```
User uploads image
       â†"
Calculate hash
       â†"
Store in database
       â†"
Check for duplicate â"€â"€â"€â"€â"¬â"€â"€â"€â"€ Not found
       â†"                  â†"
    Found             Continue normal
       â†"              processing
  Show modal
       â†"
  User chooses
   /        \
Reuse      Process
crops      again
  â†"            â†"
Copy       Normal
files    processing
  â†"            â†"
Restore      â†"
boundaries   â†"
  â†"â"€â"€â"€â"€â"€â"€â"€â"€â"˜
       â†"
  Continue workflow
```

## 2. AI Extraction Tracking

```
Start AI extraction
       â†"
Log "pending" status
       â†"
Call API (Claude/GPT-4)
       â†"
  API response
   /        \
Success    Failure
  â†"            â†"
Parse        â†"
response     â†"
  â†"            â†"
  â"œâ"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"˜
  â†"
Log detailed metrics:
- Title, description
- Tokens used
- Processing time
- Cost
- Status
  â†"
Update database
  â†"
Return to user
```

## 3. Statistics Generation

```
User requests statistics
       â†"
   Choose scope
   /    |    \
Session | Overall
  â†"     â†"     â†"
Query   â†"   Query all
single  â†"   sessions
session â†"      â†"
  â†"     â†"      â†"
  â""â"€â"€â"€â"€â"¼â"€â"€â"€â"€â"€â"˜
       â†"
Calculate metrics:
- Images processed
- AI extractions
- Success rates
- Costs
- Time saved
       â†"
Format output
       â†"
Display/Export
```

## 4. Database Schema Relationships

```
users
  â"‚
  â""â"€â"€â"€ sessions
         â"‚
         â"œâ"€â"€â"€ images
         â"‚      â"‚
         â"‚      â"œâ"€â"€â"€ processing_log
         â"‚      â"‚
         â"‚      â"œâ"€â"€â"€ ai_extractions
         â"‚      â"‚
         â"‚      â""â"€â"€â"€ ebay_posts
         â"‚
         â""â"€â"€â"€ (session-level LLM tracking)
```

## 5. Deduplication Decision Flow

```
Image uploaded
      â†"
Calculate hash: ABC123
      â†"
Query: SELECT * FROM images WHERE file_hash = 'ABC123'
      â†"
   Found?
   /    \
 Yes     No
  â†"       â†"
Check    Store
date     hash
  â†"       â†"
Was it   â""â"€â"€â"€â"€â"€â"€> Continue
recent?              processing
 /   \
Yes   No
 â†"     â†"
Show  Process
modal  again
 â†"
User
choice
```
```

### Step 6: Final Checklist

Create `INTEGRATION_CHECKLIST.md`:

```markdown
# Tracking System Integration Checklist

Use this checklist to verify complete integration.

## Phase 1: Setup âœ…
- [ ] All reference files located
- [ ] Current implementation verified (tests pass)
- [ ] Database schema confirmed
- [ ] Documentation reviewed

## Phase 2: Deduplication âœ…
- [ ] `tracking_deduplication.R` copied
- [ ] `calculate_image_hash()` working
- [ ] `find_existing_processing()` adapted for SQLite
- [ ] `store_image_hash()` implemented
- [ ] `mark_processing_reused()` adapted
- [ ] Tests created and passing
- [ ] UI modal implemented
- [ ] "Reuse crops" button working
- [ ] "Process again" button working
- [ ] Crops copied correctly
- [ ] Boundaries restored correctly

## Phase 3: LLM Tracking âœ…
- [ ] `tracking_llm.R` copied
- [ ] `track_llm_api_call()` implemented
- [ ] API calls wrapped with tracking
- [ ] `calculate_api_cost()` implemented
- [ ] Token usage tracked
- [ ] Processing time tracked
- [ ] Success/failure logged
- [ ] Statistics functions working
- [ ] Cost tracking accurate

## Phase 4: Statistics âœ…
- [ ] `fct_tracking.R` copied
- [ ] `calculate_session_stats()` adapted
- [ ] `calculate_overall_stats()` adapted
- [ ] `export_statistics_report()` working (CSV)
- [ ] `export_statistics_report()` working (JSON)
- [ ] `compare_periods()` implemented
- [ ] Optional: Statistics UI added

## Phase 5: Documentation âœ…
- [ ] INTEGRATION_GUIDE.md updated
- [ ] QUICK_REFERENCE.md updated
- [ ] TRACKING_SYSTEM_README.md created
- [ ] TRACKING_WORKFLOW_DIAGRAM.md created
- [ ] All function signatures documented
- [ ] Examples provided for each function

## Phase 6: Testing âœ…
- [ ] `test_all_tracking.R` created
- [ ] Database tests passing
- [ ] Deduplication tests passing
- [ ] LLM tracking tests passing
- [ ] Statistics tests passing
- [ ] Manual UI testing completed
- [ ] Edge cases tested

## Phase 7: Validation âœ…
- [ ] Upload same image twice - duplicate detected
- [ ] Reuse crops - works correctly
- [ ] AI extraction - both tracking systems logging
- [ ] eBay post - logged correctly
- [ ] Statistics - accurate and complete
- [ ] Export - CSV and JSON working
- [ ] No database locking issues
- [ ] No errors in console

## Final Sign-off âœ…
- [ ] All tests passing
- [ ] All documentation complete
- [ ] Code reviewed
- [ ] Ready for production use

---

**Date Completed:** __________  
**Completed By:** __________  
**Notes:** __________
```

---

## Deliverables

- ✅ INTEGRATION_GUIDE.md updated with new sections
- ✅ QUICK_REFERENCE.md updated with all new functions
- ✅ TRACKING_SYSTEM_README.md created
- ✅ TRACKING_WORKFLOW_DIAGRAM.md created
- ✅ INTEGRATION_CHECKLIST.md created
- ✅ `test_all_tracking.R` comprehensive test suite
- ✅ All tests passing
- ✅ Documentation complete and accurate

---

## Next Steps
This is the final task! Once complete, the tracking system integration is finished. Review the INTEGRATION_CHECKLIST.md to ensure everything is complete.
