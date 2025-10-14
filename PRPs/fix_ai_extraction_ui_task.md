# Fix AI Extraction UI Field Population

## Status: ✅ FIXED (2025-10-14)

**Resolution:** Database bug in `R/tracking_database.R` - combined images couldn't save AI data due to parameter length issue
**Root Cause:**
1. Combined images were tracked in `postal_cards` but had NO `card_processing` records
2. `save_card_processing()` failed when passing NULL values: `as.integer(NULL)` returns `integer(0)` (length 0) instead of scalar NA
3. Database INSERT requires scalar values (length 1) for all parameters

**Fix Applied:**
- Modified `R/tracking_database.R` lines 393-395 to use conditional NA values
- Changed from: `as.integer(grid_rows)` → To: `if (!is.null(grid_rows)) as.integer(grid_rows) else NA_integer_`
- Modified `R/mod_delcampe_export.R` lines 653-753 to query `postal_cards` directly and create `card_processing` records

**Memory:** `.serena/memories/ai_database_save_bug_fixed_20251014.md`
**Test Procedure:** `TASK_PRP/TEST_AI_PREPOPULATION.md`
**Modified Files:**
- `R/tracking_database.R` lines 393-395
- `R/mod_delcampe_export.R` lines 653-753

---

## Problem Description

When users upload duplicate combined images that already have AI-extracted data stored in the database, the AI extraction UI loads but the form fields (title, description, condition, price) remain empty instead of showing the previously extracted values.

**Root Cause (Actual):** Combined images were being tracked in `postal_cards` table, but `card_processing` records were NEVER created for them. When AI extraction tried to save data, `save_card_processing()` failed due to a parameter length bug: `as.integer(NULL)` returns `integer(0)` (length 0) instead of a scalar value, causing database INSERT to reject the parameters. This prevented AI data from ever being saved, so there was nothing to pre-populate.

## Critical Path Context

**IMPORTANT: Pay special attention to combined image paths!**
- Combined images are created by the Python `combine_face_verso_images()` function
- They are stored in a temporary session directory: `tempfile("shiny_combined_images_")`
- Web URLs use the resource prefix: `"combined_session_images"`
- Actual file paths are stored in `app_rv$combined_file_paths` (absolute paths)
- The hash for duplicate detection must be calculated from these actual file paths

## Affected Components

### Primary Issue Location
- `R/mod_ai_extraction.R` - Module loads `rv$existing_card_data` but doesn't update UI inputs
- Missing observers or reactive triggers to populate form fields when data exists

### Related Components  
- `R/mod_delcampe_ui.R` - Shows the AI extraction modal and form fields
- `R/app_server.R` - Creates combined images, stores paths in `app_rv$combined_file_paths`
- `R/tracking_database.R` - `find_card_processing()` retrieves existing AI data correctly

## Technical Details

### Combined Image Flow
1. Face + verso images extracted → crops saved to directories
2. `combine_face_verso_images()` creates combined images in temp session dir
3. Paths stored in:
   - `app_rv$combined_paths` - Web URLs for display (e.g., "combined_session_images/combined_1_1.jpg")
   - `app_rv$combined_file_paths` - Absolute file paths for processing (e.g., "C:/Users/.../Temp/.../combined_1_1.jpg")
4. Hash calculated from `app_rv$combined_file_paths[index]` for duplicate detection
5. Database check via `find_card_processing(hash, "combined")`

### Current State
- `mod_ai_extraction.R` correctly detects duplicates and loads data into `rv$existing_card_data`
- Shows notification "Previous AI extraction found!"
- Returns `get_existing_ai_data()` function that provides the data
- **MISSING:** UI input fields don't update with the loaded data

### Expected Behavior
When `rv$existing_card_data` is populated:
1. Title input field should show `existing_card_data$ai_title`
2. Description textarea should show `existing_card_data$ai_description`
3. Condition select should show `existing_card_data$ai_condition`
4. Price numeric input should show `existing_card_data$ai_price`

## Key Investigation Points

1. **Image Path Handling**
   - Verify hash is calculated from correct file path (not web URL)
   - Ensure `app_rv$combined_file_paths[image_index]` is used for AI extraction
   - Check that combined images exist at the expected paths

2. **UI Update Mechanism**
   - Find where form fields are rendered in `mod_delcampe_ui.R`
   - Check if there's a callback or reactive to populate fields
   - Look for `updateTextInput()`, `updateTextAreaInput()`, etc.

3. **Data Flow**
   - Trace how `ai_extraction$get_existing_ai_data()` is called
   - Check if the returned data reaches the UI module
   - Verify reactive dependencies are properly set up

## Acceptance Criteria

1. ✅ Combined image hash calculated from correct file path (`app_rv$combined_file_paths`)
2. ✅ Duplicate detection works for combined images (type="combined")  
3. ✅ When duplicate found, AI extraction fields auto-populate:
   - Title field shows saved title
   - Description field shows saved description
   - Condition dropdown shows saved condition
   - Price field shows saved price
4. ✅ User can edit pre-populated values
5. ✅ Save button updates existing record (not create duplicate)
6. ✅ Clear indication that fields were pre-populated (notification or visual cue)

## Testing Scenario

1. Upload face and verso images
2. Extract and combine them
3. Perform AI extraction and save data
4. Start new session (or clear UI state)
5. Upload same face and verso images
6. Extract and combine (may use "Use Existing" option)
7. Click on combined image for AI extraction
8. **Expected:** Form fields should be pre-filled with previously extracted data
9. **Current:** Form fields are empty despite data existing

## Code Investigation Hints

### Check mod_delcampe_ui.R for:
```r
# Look for where form inputs are created
textInput(ns("title_input"), ...)
textAreaInput(ns("description_input"), ...)
selectInput(ns("condition_input"), ...)
numericInput(ns("price_input"), ...)

# Look for update functions that should populate fields
updateTextInput(session, "title_input", value = ...)
updateTextAreaInput(session, "description_input", value = ...)
```

### Check mod_ai_extraction.R for:
```r
# This function returns the data correctly
get_existing_ai_data <- function() {
  if (isTRUE(rv$loaded_existing_data) && !is.null(rv$existing_card_data)) {
    return(list(
      has_existing = TRUE,
      title = rv$existing_card_data$ai_title,
      # ... other fields
    ))
  }
}

# Need to find how this data triggers UI updates
```

### Critical Path Issue:
```r
# In app_server.R, combined images stored as:
app_rv$combined_file_paths <- abs_combined_paths  # Use THIS for hash calculation

# Not this:
app_rv$combined_paths  # These are web URLs, not file paths!
```

## Implementation Approach

1. **Verify Path Usage**
   - Ensure AI extraction uses `app_rv$combined_file_paths[index]` not web URLs
   - Confirm hash calculation uses actual file path

2. **Add UI Update Observer**
   - In the module that renders the form, add observer for existing data
   - Use `updateTextInput()` etc. to populate fields when data exists

3. **Test Data Flow**
   - Add debug logging to trace data from database to UI
   - Verify reactive chain isn't broken

## Success Metrics

- Form population happens within 200ms of modal opening
- No regression in manual AI extraction
- Users report improved workflow efficiency
- Reduced API calls due to data reuse