# TASK PRP: Fix Database Tracking Issues

## Task Overview
Fix two critical database tracking issues in the Delcampe postal card processor:
1. **Verso upload tracking** - Verso images don't create proper database entries for deduplication
2. **AI extraction UI population** - Previously extracted AI data doesn't auto-populate the UI fields

## Context

### Documentation References
```yaml
context:
  docs:
    - file: .serena/memories/DEDUPLICATION_FINAL_STATUS_20251013.md
      focus: Working face upload deduplication pattern
    - file: .serena/memories/SESSION_SUMMARY_DEDUPLICATION_20251013.md
      focus: 3-layer architecture and critical bug fixes (NULL vs NA)
    - file: PRPs/Initial_fix_tracking.md
      focus: Problem specification and success criteria

  patterns:
    - file: R/mod_postal_card_processor.R
      lines: 183-209
      copy: Face upload tracking pattern (upload observer)
    - file: R/mod_postal_card_processor.R
      lines: 147-182
      copy: Duplicate detection and modal display pattern
    - file: R/mod_ai_extraction.R
      lines: 31-83
      copy: Existing AI data detection pattern
    - file: R/tracking_database.R
      lines: 228-282
      copy: get_or_create_card() implementation
    - file: R/tracking_database.R
      lines: 454-514
      copy: find_card_processing() implementation

  gotchas:
    - issue: "Using NULL in SQL parameters causes 'does not have length 1' error"
      fix: "Always use NA_integer_, NA_character_, NA_real_ instead of NULL"
      file: R/tracking_database.R:254-256
    - issue: "Property access on NULL objects crashes (dimensions$width when dimensions is NULL)"
      fix: "Always check parent exists first: if (!is.null(obj) && !is.null(obj$property))"
      file: R/tracking_database.R:255
    - issue: "Module namespacing requires careful reactive dependencies"
      fix: "Use observe() with req() for reactive triggers, check that parent session is available"
    - issue: "UI updates need updateTextInput/updateTextAreaInput to populate fields"
      fix: "Can't just set rv values - must explicitly call update* functions"
```

## Task Breakdown

### ISSUE 1: Verso Upload Tracking is Broken

**Root Cause Analysis:**
The verso module (`mod_postal_card_processor_server` with `card_type = "verso"`) follows the same upload pattern as face, but there may be an issue with how `card_type` is passed through to database functions or how the duplicate check works for verso images.

**Expected Behavior:**
- Verso upload → `calculate_image_hash()` → `get_or_create_card(image_type = "verso")` → card_id stored
- Duplicate verso → `find_card_processing(hash, "verso")` → modal appears if crops exist
- "Use Existing" → crops restore instantly

**Current Behavior:**
- Verso uploads may not create proper database entries
- Deduplication fails for verso images
- Modal doesn't appear for duplicate verso uploads

### ISSUE 2: AI Extraction Data Doesn't Populate UI Fields

**Root Cause Analysis:**
The `mod_ai_extraction_server` module detects existing AI data (lines 31-83) and stores it in `rv$existing_card_data`, but there's NO UI component or update mechanism to populate text input fields with this data.

**Expected Behavior:**
- Combined image with existing AI data → Fields auto-populate (title, description, condition, price)
- User sees notification: "Previous AI extraction found!"
- User can edit pre-populated data
- User can run new extraction to overwrite

**Current Behavior:**
- Detection works (notification shows)
- Data is available in `rv$existing_card_data`
- BUT: UI fields remain empty (no `updateTextInput` calls)

---

## Implementation Tasks

### Task 1: Verify Verso Upload Database Tracking

**FILE:** R/mod_postal_card_processor.R

**ANALYSIS STEPS:**
1. READ lines 183-209 (face upload tracking pattern)
2. SEARCH for verso module instantiation in app_server.R
3. VERIFY `card_type = "verso"` is correctly passed through
4. CHECK if upload observer creates database entry for verso

**VALIDATE:**
```r
# In R console after verso upload:
library(DBI)
con <- dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
dbGetQuery(con, "SELECT * FROM postal_cards WHERE image_type = 'verso'")
dbDisconnect(con)
# Should show verso entries
```

**IF_FAIL:** Check that `card_type` variable is used (not hardcoded "face")

**ROLLBACK:** No changes needed if only analysis

---

### Task 2: Fix Verso Duplicate Detection (if broken)

**FILE:** R/mod_postal_card_processor.R (lines 147-182)

**ACTION:** Verify duplicate detection works for verso
- Ensure `find_card_processing(rv$current_image_hash, card_type)` uses correct card_type
- Confirm modal appears for verso duplicates

**CHANGE:**
```r
# Line ~148: Ensure card_type is used, not hardcoded "face"
existing <- find_card_processing(rv$current_image_hash, card_type)  # ✓ CORRECT
# NOT: find_card_processing(rv$current_image_hash, "face")  # ✗ WRONG
```

**VALIDATE:**
1. Upload verso image twice
2. Second upload should show modal: "Duplicate Image Detected"
3. Check console for: "Duplicate image detected - showing modal"

**IF_FAIL:**
- Add debug message: `message("Checking for duplicate: ", card_type, " hash: ", substr(rv$current_image_hash, 1, 8))`
- Check database: `find_card_processing(hash, "verso")` returns data
- Verify `validation$all_exist` is TRUE

**ROLLBACK:** Revert R/mod_postal_card_processor.R to git HEAD

---

### Task 3: Create AI Extraction UI Component (NEW FILE)

**WHY:** The module currently has server logic but NO UI to show/edit AI extraction data

**FILE:** R/mod_delcampe_export.R or R/app_server.R (where AI extraction module is used)

**RESEARCH FIRST:**
1. FIND where `mod_ai_extraction_server` is called
2. CHECK if there's a UI component with text inputs for title/description/condition/price
3. IDENTIFY the input IDs for these fields

**SEARCH PATTERN:**
```r
# Use Grep to find:
Grep: "mod_ai_extraction"
Grep: "textInput.*title"
Grep: "textAreaInput.*description"
```

**IF UI EXISTS:** Proceed to Task 4 (add update calls)
**IF NO UI:** This is the blocker - need to create UI first or find existing one

---

### Task 4: Add UI Update Mechanism for Existing AI Data

**FILE:** R/mod_ai_extraction.R

**PREREQUISITE:** Task 3 must identify the UI input IDs

**ACTION:** Add observe() block to populate UI fields when existing data is detected

**IMPLEMENTATION:**
```r
# Add after line 83 (end of existing data detection observe block):

# Observe changes to existing data and update UI fields
observe({
  req(rv$loaded_existing_data)
  req(rv$existing_card_data)

  # Get the data
  data <- rv$existing_card_data

  # Update UI fields (requires knowing the input IDs from parent)
  # NOTE: This requires the parent module to pass input IDs or
  # the UI to be part of this module

  if (!is.null(data$ai_title)) {
    updateTextInput(session_inner, "ai_title", value = data$ai_title)
  }
  if (!is.null(data$ai_description)) {
    updateTextAreaInput(session_inner, "ai_description", value = data$ai_description)
  }
  if (!is.null(data$ai_condition)) {
    updateSelectInput(session_inner, "ai_condition", selected = data$ai_condition)
  }
  if (!is.null(data$ai_price)) {
    updateNumericInput(session_inner, "ai_price", value = data$ai_price)
  }

  message("✅ UI fields populated with existing AI data")
})
```

**GOTCHA:** Input IDs must match actual UI elements. If they don't exist in this module's namespace, this won't work. May need to return reactive data and let parent module handle UI updates.

**ALTERNATIVE APPROACH (if UI is in parent module):**
```r
# In module's return list (line 524), add:
existing_data_trigger = reactive({
  if (isTRUE(rv$loaded_existing_data)) {
    list(
      timestamp = Sys.time(),
      data = rv$existing_card_data
    )
  } else {
    NULL
  }
})

# Then in parent module (mod_delcampe_export.R), observe this trigger:
observe({
  existing <- ai_extraction_module$existing_data_trigger()
  req(existing)

  data <- existing$data
  updateTextInput(session, ns("export_title"), value = data$ai_title)
  # ... etc for other fields
})
```

**VALIDATE:**
1. Upload and process combined image with AI extraction
2. Save card_id and close app
3. Reopen app and upload the SAME combined image
4. Fields should auto-populate with previous extraction data
5. Check console for: "✅ UI fields populated with existing AI data"

**IF_FAIL:**
- Verify `rv$loaded_existing_data` is TRUE: `message("Loaded existing: ", rv$loaded_existing_data)`
- Check data content: `message("Data: ", jsonlite::toJSON(rv$existing_card_data))`
- Verify input IDs exist in UI: check browser console for Shiny input errors
- Test manual update: `updateTextInput(session_inner, "ai_title", value = "TEST")`

**ROLLBACK:** Remove observe() block and existing_data_trigger from return list

---

### Task 5: Integration Testing - Full Workflow

**SCENARIO 1: Verso Upload Deduplication**
1. Upload verso image (new)
   - ✓ Database entry created with `image_type = "verso"`
   - ✓ `rv$current_card_id` is set
2. Extract crops from verso
   - ✓ Processing saved to database
3. Upload SAME verso image again
   - ✓ Modal appears: "Duplicate Image Detected"
   - ✓ Click "Use Existing" → crops restore instantly
4. Check database:
   ```sql
   SELECT * FROM postal_cards WHERE image_type = 'verso';
   SELECT * FROM card_processing WHERE card_id IN (SELECT card_id FROM postal_cards WHERE image_type = 'verso');
   ```
   - ✓ Only ONE postal_cards entry per unique verso hash
   - ✓ card_processing entry exists with valid crop_paths

**SCENARIO 2: AI Extraction Data Population**
1. Upload face + verso, combine into single image
   - ✓ Combined image created
2. Run AI extraction (first time)
   - ✓ Title, description, condition, price extracted
   - ✓ Data saved to database in `card_processing.ai_*` fields
3. Close and reopen app
4. Upload SAME combined image
   - ✓ Notification: "Previous AI extraction found!"
   - ✓ Title field auto-populated
   - ✓ Description field auto-populated
   - ✓ Condition field auto-populated
   - ✓ Price field auto-populated
5. Edit title and run new extraction
   - ✓ New data overwrites old data
   - ✓ Database updated with new values

**SCENARIO 3: Verso + AI Combined Workflow**
1. Upload new verso → extract crops
2. Upload new face → extract crops
3. Combine face + verso → AI extraction
4. Close app
5. Reopen, upload same verso
   - ✓ Modal appears for verso
   - ✓ Click "Use Existing" → verso crops restore
6. Upload same face
   - ✓ Modal appears for face
   - ✓ Click "Use Existing" → face crops restore
7. Combine same images
   - ✓ Combined image recognized
   - ✓ AI fields auto-populate
   - ✓ No need to re-extract

**VALIDATE ALL:**
```bash
# In R console:
source("tests/test_tracking_system.R")  # If test file exists
# OR manual verification as described above
```

**IF_FAIL:** Review individual task validations, check console messages, examine database state

---

## Validation Strategy

### Level 1: Syntax & Style
```r
# In R console:
devtools::load_all()
# Should load without errors
```

**PASS CRITERIA:**
- No R syntax errors
- All functions load successfully
- No namespace conflicts

### Level 2: Unit Testing
```r
# Test database functions:
hash_test <- calculate_image_hash("path/to/test/image.jpg")
card_id <- get_or_create_card(hash_test, "verso", "test.jpg", 1000, NULL)
existing <- find_card_processing(hash_test, "verso")

# Expectations:
stopifnot(!is.null(card_id))
stopifnot(is.integer(card_id))
```

**PASS CRITERIA:**
- `get_or_create_card()` returns valid card_id for verso
- `find_card_processing()` returns data for existing verso processing
- No SQL errors in console
IMPORTANT : use golem framework for tests

### Level 3: Integration Testing
**Run Scenario 1 and Scenario 2 from Task 5**

**PASS CRITERIA:**
- Verso uploads create database entries
- Verso duplicates trigger modal
- AI data auto-populates UI fields
- No errors in R console
- No errors in browser console

### Level 4: User Acceptance
**Have user test:**
1. Upload verso → extract → reupload → modal appears
2. AI extract combined → close → reopen → fields populated

**PASS CRITERIA:**
- User confirms verso deduplication works
- User confirms AI data appears in UI without re-extraction
- No regressions in face upload workflow

---

## Debug Strategies

### Issue: Verso uploads don't create database entries
**DEBUG:**
```r
# In upload observer:
message("Upload event triggered for card_type: ", card_type)
message("Hash calculated: ", substr(image_hash, 1, 8))
message("Calling get_or_create_card with image_type: ", card_type)
```

**CHECK DATABASE:**
```r
con <- dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
dbGetQuery(con, "SELECT card_id, image_type, file_hash, original_filename FROM postal_cards ORDER BY card_id DESC LIMIT 5")
dbDisconnect(con)
```

**LIKELY CAUSES:**
- `card_type` variable scope issue (not accessible in observer)
- Hardcoded "face" somewhere in upload flow
- Error in `get_or_create_card()` that's silently caught

---

### Issue: Modal doesn't appear for verso duplicates
**DEBUG:**
```r
# In duplicate check observer (line ~147):
message("🔍 Checking for duplicates: card_type=", card_type, " hash=", substr(rv$current_image_hash, 1, 8))
existing <- find_card_processing(rv$current_image_hash, card_type)
message("📋 Duplicate check result: ", if (is.null(existing)) "NONE" else "FOUND")

if (!is.null(existing)) {
  message("Existing data: ", jsonlite::toJSON(existing, auto_unbox = TRUE))
  validation <- validate_existing_crops(existing$crop_paths)
  message("Validation: all_exist=", validation$all_exist)
}
```

**LIKELY CAUSES:**
- `find_card_processing()` not finding verso entries (check image_type parameter)
- Crop files don't exist (`validation$all_exist = FALSE`)
- Modal logic has condition that excludes verso

---

### Issue: AI fields don't populate
**DEBUG:**
```r
# In mod_ai_extraction.R after line 78:
message("Existing card data detected:")
message("  - has ai_title: ", !is.null(existing_card$ai_title))
message("  - has ai_description: ", !is.null(existing_card$ai_description))
message("  - rv$loaded_existing_data = ", rv$loaded_existing_data)

# After adding update observer:
observe({
  message("Update observer triggered, loaded_existing_data = ", rv$loaded_existing_data)
  if (isTRUE(rv$loaded_existing_data)) {
    message("Attempting to update UI fields...")
    message("  - ai_title: ", rv$existing_card_data$ai_title)
  }
})
```

**CHECK UI:**
```javascript
// In browser console:
console.log(Shiny.shinyapp.$inputValues);
// Look for ai_title, ai_description, ai_condition, ai_price inputs
```

**LIKELY CAUSES:**
- UI input IDs don't match update calls (wrong namespace)
- UI inputs don't exist in mod_ai_extraction module (they're in parent)
- Reactive dependency not triggering (observe block not running)
- `session_inner` vs `notification_session` scope issue

---

## Success Criteria Checklist

- [ ] Verso uploads create entries in `postal_cards` table with `image_type = "verso"`
- [ ] Duplicate verso uploads trigger the reuse modal
- [ ] "Use Existing" button works for verso images (crops restore instantly)
- [ ] AI extraction fields (title, description, condition, price) auto-populate when existing data is found
- [ ] Users can edit pre-populated AI data
- [ ] Users can run new AI extraction to overwrite existing data
- [ ] No regression in face upload/deduplication functionality
- [ ] No regression in combined image creation
- [ ] Database maintains referential integrity (no orphaned records)
- [ ] Console messages confirm all tracking operations

---

## Rollback Plan

### If Verso Tracking Breaks:
```bash
git checkout R/mod_postal_card_processor.R
```

### If AI Population Breaks Extraction:
```bash
git checkout R/mod_ai_extraction.R
```

### If Database Schema Issues:
```bash
# Backup database
cp inst/app/data/tracking.sqlite inst/app/data/tracking.sqlite.backup

# Reinitialize
rm inst/app/data/tracking.sqlite
# Restart app (will recreate schema)
```

### Full Rollback:
```bash
git stash
# Or:
git reset --hard HEAD
```

---

## Performance Considerations

- Hash calculation is fast (<10ms per image)
- Database lookups are indexed (< 5ms per query)
- UI updates are instant (synchronous)
- No impact on Python extraction performance
- Modal display adds <50ms overhead to duplicate uploads

---

## Security Considerations

- No new external inputs introduced
- Database queries use parameterized statements (SQL injection safe)
- File hash uses MD5 (sufficient for deduplication, not cryptographic)
- No sensitive data exposed in console messages (only hash prefixes)

---

## Next Steps After Completion

1. Update `.serena/memories/` with solution details
2. Create memory file: `tracking_fixes_complete_YYYYMMDD.md`
3. Update `PRPs/Initial_fix_tracking.md` status to COMPLETE
4. Consider implementing:
   - Task 08: AI extraction for combined images (if not already done)
   - Task 09: Auto-trigger combine after "Use Existing" for both modules
5. User testing and feedback collection

---

## Estimated Effort

- **Task 1 (Analysis):** 15 minutes
- **Task 2 (Fix Verso):** 30 minutes (if broken)
- **Task 3 (Find UI):** 20 minutes
- **Task 4 (UI Updates):** 45 minutes
- **Task 5 (Testing):** 30 minutes
- **Total:** ~2.5 hours

---

## Related Files

**Core Implementation:**
- `R/mod_postal_card_processor.R` - Upload and deduplication logic
- `R/mod_ai_extraction.R` - AI extraction and data loading
- `R/tracking_database.R` - Database functions
- `R/app_server.R` - Module instantiation

**Documentation:**
- `.serena/memories/DEDUPLICATION_FINAL_STATUS_20251013.md`
- `.serena/memories/SESSION_SUMMARY_DEDUPLICATION_20251013.md`
- `PRPs/Initial_fix_tracking.md`

**Tests:**
- `tests/test_tracking_system.R` (if exists)
- `tests/manual/verify_deduplication.R` (to be created)
