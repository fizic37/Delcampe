# TASK 02: Prepare Deduplication Integration

**Estimated Time:** 45 minutes  
**Priority:** HIGH  
**Status:** 🔴 Not Started  
**Depends On:** TASK_01 complete

---

## Goal
Analyze the deduplication system in Test_Delcampe and plan how to adapt it for SQLite.

---

## Background
Test_Delcampe has a working deduplication system that:
- Calculates image hashes (dual-hash: file + content)
- Searches for existing processing across sessions
- Allows reusing previously cropped images
- Saves processing time by avoiding duplicate work

**Current Problem:** It uses JSON files. We need to adapt it for SQLite.

---

## What You Need to Do

### Step 1: Study the Reference Implementation

Read `Test_Delcampe/R/tracking_deduplication.R` and understand these functions:

```r
# Key functions to understand:
1. calculate_image_hash(image_path)
   - Returns list(file_hash, content_hash)
   
2. find_existing_processing(image_hash, image_type)
   - Searches JSON files for previous processing
   - Returns existing boundaries and crop paths
   
3. validate_existing_crops(crop_paths)
   - Checks if crop files still exist
   
4. copy_existing_crops(source_paths, dest_dir, new_session_id)
   - Copies crops to new session directory
   
5. mark_processing_reused(session_id, source_session_id, image_id)
   - Logs that crops were reused
```

### Step 2: See It In Action

Open `Delcampe_BACKUP/examples/modules/mod_postal_cards_face.R` and read lines 123-268.

This shows:
- When to check for duplicates (after image upload)
- How to show the modal asking user
- What happens when user clicks "Yes, reuse crops"
- What happens when user clicks "No, process again"

### Step 3: Plan SQLite Adaptation

For `find_existing_processing()`, we need to change:

**OLD (JSON-based):**
```r
find_existing_processing <- function(image_hash, image_type) {
  data <- load_tracking_data()  # Reads JSON file
  for (session_id in names(data$sessions)) {
    # Loop through JSON structure
  }
}
```

**NEW (SQLite-based):**
```r
find_existing_processing <- function(image_hash, image_type) {
  con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
  
  # Query images table for matching hash
  result <- dbGetQuery(con, "
    SELECT 
      i.image_id,
      i.session_id,
      i.upload_path,
      p.details  -- JSON containing boundaries and crop paths
    FROM images i
    LEFT JOIN processing_log p 
      ON i.image_id = p.image_id 
      AND p.action = 'extraction_complete'
    WHERE i.file_hash = ?
      AND i.image_type LIKE ?
    ORDER BY i.upload_timestamp DESC
    LIMIT 1
  ", list(image_hash, paste0("%", image_type, "%")))
  
  # Parse the JSON from details column
  # Return structured list
}
```

### Step 4: Document Required Changes

Create a file `DEDUPLICATION_ADAPTATION_PLAN.md` that lists:
1. Which functions need to be changed
2. What database columns we'll use
3. How the JSON `details` field will store boundaries/crops
4. Any new database columns needed (if any)

---

## Key Questions to Answer

1. **How is the hash stored?**
   - Current: Images table has `file_hash` column
   - Needed: Do we need both file_hash and content_hash?
   
2. **Where are boundaries stored?**
   - Current: Processing_log has `details` JSON column
   - Needed: Does it contain h_boundaries, v_boundaries, cropped_paths?

3. **How to handle session directories?**
   - Current: Each session has own directory
   - Needed: Verify directory structure matches

---

## Deliverables

Create `DEDUPLICATION_ADAPTATION_PLAN.md` with:
- Function-by-function adaptation notes
- SQL queries for each lookup
- Database schema requirements
- Edge cases to handle

---

## Next Steps
Once this task is complete, proceed to **TASK_03_IMPLEMENT_DEDUPLICATION.md**
