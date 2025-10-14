# TASK 03: Implement Deduplication System

**Estimated Time:** 2 hours  
**Priority:** HIGH  
**Status:** 🔴 Not Started  
**Depends On:** TASK_02 complete

---

## Goal
Copy and adapt the deduplication functions from Test_Delcampe to work with our SQLite database.

---

## What You Need to Do

### Step 1: Copy Base File

Copy `Test_Delcampe/R/tracking_deduplication.R` to `Delcampe/R/tracking_deduplication.R`

```r
# In R console
file.copy(
  from = "Test_Delcampe/R/tracking_deduplication.R",
  to = "R/tracking_deduplication.R"
)
```

### Step 2: Adapt Core Functions

Modify these functions to use SQLite instead of JSON:

#### 2.1: Update `calculate_image_hash()`
Check if it needs any changes, or if it's database-agnostic.

#### 2.2: Rewrite `find_existing_processing()`

Replace JSON lookup with SQLite query:

```r
find_existing_processing <- function(image_hash, image_type = NULL) {
  con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
  on.exit(dbDisconnect(con))
  
  # Build query
  query <- "
    SELECT 
      i.image_id,
      i.session_id,
      i.upload_path,
      i.image_type,
      p.details,
      p.timestamp as processed_at
    FROM images i
    LEFT JOIN processing_log p 
      ON i.image_id = p.image_id 
      AND p.action = 'extraction_complete'
    WHERE i.file_hash = ?
  "
  
  params <- list(image_hash)
  
  # Add image_type filter if provided
  if (!is.null(image_type)) {
    query <- paste(query, "AND i.image_type LIKE ?")
    params <- list(image_hash, paste0("%", image_type, "%"))
  }
  
  query <- paste(query, "ORDER BY i.upload_timestamp DESC LIMIT 1")
  
  result <- dbGetQuery(con, query, params)
  
  if (nrow(result) == 0) {
    return(NULL)
  }
  
  # Parse JSON from details column
  details <- jsonlite::fromJSON(result$details)
  
  return(list(
    image_id = result$image_id,
    session_id = result$session_id,
    source_path = result$upload_path,
    h_boundaries = details$h_boundaries,
    v_boundaries = details$v_boundaries,
    cropped_paths = details$cropped_paths,
    processed_at = result$processed_at
  ))
}
```

#### 2.3: Update `mark_processing_reused()`

Change to log in SQLite:

```r
mark_processing_reused <- function(current_session_id, source_session_id, image_id, source_image_id) {
  con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
  on.exit(dbDisconnect(con))
  
  # Log reuse action
  dbExecute(con, "
    INSERT INTO processing_log (session_id, image_id, action, details, timestamp)
    VALUES (?, ?, 'crops_reused', ?, datetime('now'))
  ", list(
    current_session_id,
    image_id,
    jsonlite::toJSON(list(
      source_session_id = source_session_id,
      source_image_id = source_image_id,
      reused_at = Sys.time()
    ), auto_unbox = TRUE)
  ))
  
  return(TRUE)
}
```

#### 2.4: Keep These Functions (probably don't need changes)
- `validate_existing_crops()` - File system check, database-agnostic
- `copy_existing_crops()` - File operations, database-agnostic

### Step 3: Add Helper Function for Hash Storage

Add function to store hash when image is uploaded:

```r
#' Store image hash in database
store_image_hash <- function(image_id, file_hash, content_hash = NULL) {
  con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
  on.exit(dbDisconnect(con))
  
  # Update the images table with hash
  dbExecute(con, "
    UPDATE images 
    SET file_hash = ?,
        content_hash = ?
    WHERE image_id = ?
  ", list(file_hash, content_hash, image_id))
  
  return(TRUE)
}
```

### Step 4: Test Each Function

Create `test_deduplication.R`:

```r
library(testthat)
source("R/tracking_database.R")
source("R/tracking_deduplication.R")

# Test 1: Calculate hash
test_that("Hash calculation works", {
  # Use a test image
  hash <- calculate_image_hash("inst/app/data/test_image.jpg")
  expect_type(hash, "character")
  expect_true(nchar(hash) > 0)
})

# Test 2: Find existing (when none exists)
test_that("Find existing returns NULL for new hash", {
  result <- find_existing_processing("fake_hash_12345", "face")
  expect_null(result)
})

# Test 3: Store and retrieve hash
test_that("Can store and find hash", {
  # Create test session and image
  session_id <- create_tracking_session("test_user")
  image_id <- track_image_upload(session_id, "test.jpg", "face")
  
  # Calculate and store hash
  hash <- calculate_image_hash("inst/app/data/test_image.jpg")
  store_image_hash(image_id, hash)
  
  # Simulate processing completion
  track_processing_step(
    image_id = image_id,
    action = "extraction_complete",
    details = list(
      h_boundaries = c(0.25, 0.75),
      v_boundaries = c(0.1, 0.9),
      cropped_paths = c("crop1.jpg", "crop2.jpg")
    )
  )
  
  # Try to find it
  result <- find_existing_processing(hash, "face")
  expect_false(is.null(result))
  expect_equal(result$image_id, image_id)
  expect_equal(result$h_boundaries, c(0.25, 0.75))
})

# Test 4: Validate crops
test_that("Validate existing crops detects missing files", {
  paths <- c("nonexistent1.jpg", "nonexistent2.jpg")
  result <- validate_existing_crops(paths)
  expect_false(result$all_exist)
})
```

Run tests:
```r
source("test_deduplication.R")
```

---

## Key Points

1. **Database Columns Used:**
   - `images.file_hash` - Store the hash
   - `images.content_hash` - Optional second hash
   - `processing_log.details` - JSON with boundaries and crop paths

2. **Processing Flow:**
   ```
   Upload image → Calculate hash → Check for existing → 
   If found: Show modal → User chooses → 
   If reuse: Copy crops + Restore boundaries + Mark reused
   If not found: Normal processing
   ```

3. **JSON Structure in details:**
   ```json
   {
     "h_boundaries": [0.25, 0.75],
     "v_boundaries": [0.1, 0.9],
     "cropped_paths": ["path/to/crop1.jpg", "path/to/crop2.jpg"]
   }
   ```

---

## Deliverables

- ✅ `R/tracking_deduplication.R` adapted for SQLite
- ✅ `test_deduplication.R` with passing tests
- ✅ All functions working with database

---

## Next Steps
Once this task is complete, proceed to **TASK_04_UI_INTEGRATION.md**
