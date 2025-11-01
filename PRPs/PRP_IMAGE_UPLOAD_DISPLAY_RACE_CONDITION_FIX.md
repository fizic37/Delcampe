# PRP: Image Upload Display Race Condition - Complete Fix

**Status:** 🔴 READY FOR IMPLEMENTATION
**Priority:** 🔥 HIGH (User Experience Issue)
**Created:** 2025-10-29
**Module:** `R/mod_postal_card_processor.R`

---

## Problem Statement

### Current Broken Behavior

When users upload images (face or verso), the image preview frequently fails to display, showing only a broken image icon instead of the actual uploaded image. This occurs despite:
- Previous fix attempt (2025-10-20) adding file verification and retry logic
- Adding delays in image processing
- Multiple attempts to address the issue

**Screenshot Evidence:**
```
Upload Face image: [Browse... 5a.jpg] [Upload complete]
Grid Rows: 3    Grid Columns: 1

Display Area: [🖼️] ← Broken image icon, no actual image
              "No cards extracted yet"
```

### Impact on Users

- **Frustration:** Users can't see what they uploaded
- **Confusion:** Is the upload working? Should they try again?
- **Abandonment Risk:** Users may give up on the app
- **Trust Issue:** Looks like a broken/buggy application
- **Workflow Disruption:** Can't verify correct image before extraction

### Why Previous Fix Didn't Work

**Previous Fix (2025-10-20):** Added file copy verification and readability checks
- **What it fixed:** File system race conditions (file not ready)
- **What it didn't fix:** UI rendering race condition (data not ready)

**The Real Problem:** File being ready ≠ Image being displayable

---

## Root Cause Analysis

### Current Code Flow Timeline

```
Time    Action                          State                           UI State
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
0ms     User uploads image              -                               Uploading...
10ms    File copy + verification ✓      file_ready = true               -
20ms    Database tracking ✓             hash, card_id set               -
30ms    URL CREATED ⚠️                  image_url_display SET           -
30ms    images_panel renderUI triggers  wrapper div created             -
30ms    image_with_draggable_grid       BLOCKS: waiting for deps        🔴 BROKEN ICON
        tries to render but can't
40ms    Grid detection STARTS           Python processing...            🔴 BROKEN ICON
...     (grid detection running)        ...                             🔴 BROKEN ICON
500ms   Grid detection COMPLETES ✓      dims, boundaries set            -
500ms   image_with_draggable_grid       req() check passes              -
        can NOW render
510ms   Image actually displays         All data ready                  ✅ IMAGE SHOWS
```

**The Gap:** 480ms (30-510ms) where UI is in inconsistent state

### The Race Condition

**File:** `R/mod_postal_card_processor.R`

**Line 274 (THE PROBLEM):**
```r
rv$image_url_display <- paste0(resource_prefix, "/", rel_path, "?v=", cache_buster)
```

**Line 646 (THE REQUIREMENT):**
```r
output$image_with_draggable_grid <- renderUI({
  req(rv$image_url_display,        # ✓ Set at line 274
      rv$image_dims_original,      # ✗ Set during grid detection (lines 283-394)
      length(rv$h_boundaries) >= 2, # ✗ Set during grid detection
      length(rv$v_boundaries) >= 2) # ✗ Set during grid detection
  # ...
})
```

**Data Dependencies:**
1. ✅ `rv$image_url_display` - Set immediately (line 274)
2. ❌ `rv$image_dims_original` - Set during grid detection (line 318+)
3. ❌ `rv$h_boundaries` - Set during grid detection (line 335+)
4. ❌ `rv$v_boundaries` - Set during grid detection (line 339+)
5. ❌ `rv$current_grid_rows` - Set during grid detection (line 343+)
6. ❌ `rv$current_grid_cols` - Set during grid detection (line 344+)

**The Problem:** Setting the URL triggers UI rendering before data dependencies are ready.

### Why This Happens

1. **Premature URL Creation:** URL is created before grid detection (line 274)
2. **Async UI Rendering:** Shiny tries to render `images_panel` immediately
3. **Blocked Sub-Component:** `image_with_draggable_grid` blocks on `req()` waiting for grid data
4. **Browser Behavior:** Browser sees incomplete `<img>` tag or broken state
5. **Visual Artifact:** User sees broken image icon during the wait

### Code Locations

| Line | Current Behavior | Issue |
|------|------------------|-------|
| 165 | Reset `image_url_display = NULL` | ✓ OK |
| 232-273 | Database tracking | ✓ OK |
| **274** | **SET `image_url_display`** | **⚠️ TOO EARLY** |
| 283-394 | Grid detection (Python) | Takes 200-500ms |
| 396-398 | Show controls | ✓ OK |
| 630-644 | `images_panel` renderUI | Triggers on URL set |
| 646-737 | `image_with_draggable_grid` renderUI | Blocks until grid data ready |

---

## Proposed Solution

### Strategy: Delay URL Creation Until All Data Ready

**Core Principle:** Only set `rv$image_url_display` AFTER all data dependencies exist.

### Implementation Plan

#### **Phase 1: Add Processing Status Tracking**

Create new reactive value to track upload/processing state:

```r
rv <- reactiveValues(
  # ... existing values ...
  processing_status = "idle",  # NEW: "idle" | "uploading" | "verifying" | "detecting" | "ready" | "error"
  processing_message = NULL    # NEW: User-friendly status message
)
```

#### **Phase 2: Restructure Upload Observer**

**Current Flow:**
```
File Copy → Database → URL Creation → Grid Detection → Show Controls → Duplicate Check
```

**New Flow:**
```
Status: Uploading → File Copy → Verifying → Database
                 ↓
Status: Detecting → Grid Detection → URL Creation → Ready
                 ↓
Show Controls → Duplicate Check
```

**Code Changes:**

```r
observeEvent(input$image_upload, {
  # ... existing skip logic ...

  # Set uploading status
  rv$processing_status <- "uploading"
  rv$processing_message <- "Uploading image..."

  # ... file copy logic ...

  # Set verifying status
  rv$processing_status <- "verifying"
  rv$processing_message <- "Verifying file integrity..."

  # ... file readability check ...

  # Database tracking
  rv$processing_status <- "tracking"
  rv$processing_message <- "Tracking upload..."

  # ... database operations ...

  # Grid detection BEFORE URL creation
  rv$processing_status <- "detecting"
  rv$processing_message <- "Detecting postal cards..."

  # ... grid detection logic (lines 283-394) ...

  # ONLY create URL after grid detection succeeds
  if (!is.null(rv$image_dims_original) &&
      length(rv$h_boundaries) >= 2 &&
      length(rv$v_boundaries) >= 2) {

    # NOW it's safe to create URL and trigger UI
    norm_session_dir <- normalizePath(session_temp_dir, winslash = "/")
    norm_upload_path <- normalizePath(upload_path, winslash = "/")
    rel_path <- sub(paste0("^", gsub("/", "\\\\/", norm_session_dir), "/*"), "", norm_upload_path)
    rel_path <- sub("^/*", "", rel_path)
    cache_buster <- format(Sys.time(), "%Y%m%d%H%M%OS6")

    rv$image_url_display <- paste0(resource_prefix, "/", rel_path, "?v=", cache_buster)
    rv$processing_status <- "ready"
    rv$processing_message <- NULL

    # Show controls
    shinyjs::show("rows_control")
    shinyjs::show("cols_control")
    shinyjs::show("extract_control")
  } else {
    # Grid detection failed
    rv$processing_status <- "error"
    rv$processing_message <- "Could not detect postal cards in image"
    showNotification(
      paste("Failed to detect grid in", card_type, "image. Please check image quality."),
      type = "error",
      duration = 5
    )
    return()
  }

  # Duplicate check (if applicable)
  # ... existing duplicate check logic ...
})
```

#### **Phase 3: Add Loading UI**

Replace empty state with informative loading indicator:

```r
output$images_panel <- renderUI({
  # NEW: Show loading state during processing
  if (rv$processing_status %in% c("uploading", "verifying", "detecting", "tracking")) {
    return(div(
      style = "width:100%; height:500px; display:flex; flex-direction: column; align-items:center; justify-content:center; background-color: #f8f9fa; border: 2px dashed #dee2e6; border-radius: 8px;",
      div(
        style = "text-align: center;",
        # Spinner (CSS animation)
        div(
          style = "width: 48px; height: 48px; border: 4px solid #e0e0e0; border-top-color: #0d6efd; border-radius: 50%; animation: spin 1s linear infinite; margin: 0 auto 16px;",
          tags$style(HTML("@keyframes spin { to { transform: rotate(360deg); } }"))
        ),
        # Status message
        h5(rv$processing_message %||% "Processing...", style = "color: #495057; margin-bottom: 8px;"),
        p(paste("Preparing", card_type, "image for display"), style = "color: #6c757d; font-size: 14px; margin: 0;")
      )
    ))
  }

  # NEW: Show error state
  if (rv$processing_status == "error") {
    return(div(
      style = "width:100%; height:500px; display:flex; flex-direction: column; align-items:center; justify-content:center; background-color: #fff3cd; border: 2px solid #ffc107; border-radius: 8px;",
      div(
        style = "text-align: center; padding: 20px;",
        icon("exclamation-triangle", style = "font-size: 48px; color: #856404; margin-bottom: 16px;"),
        h5("Processing Failed", style = "color: #856404; margin-bottom: 8px;"),
        p(rv$processing_message %||% "An error occurred during image processing",
          style = "color: #856404; font-size: 14px; margin: 0;"),
        actionButton(ns("retry_upload"), "Try Again", class = "btn-warning", style = "margin-top: 16px;")
      )
    ))
  }

  # Original empty state
  if (is.null(rv$image_url_display)) {
    return(div(
      style = "width:100%; height:500px; display:flex; align-items:center; justify-content:center; color:#aaa; font-style:italic;",
      paste("Upload a", card_type, "image to start.")
    ))
  }

  # Original grid UI (only renders when status = "ready")
  tags$div(
    id = ns("grid_ui_wrapper"),
    `data-draggrid` = "true",
    style = "position:relative; width:100%; height:500px; overflow:visible; border:1px solid #eee; margin-bottom:8px; background-color: #f5f5f5;",
    uiOutput(ns("image_with_draggable_grid"))
  )
})
```

#### **Phase 4: Handle Edge Cases**

**Edge Case 1: Duplicate Image (Use Existing)**
```r
observeEvent(input$use_existing_crops, {
  req(rv$pending_existing_data)
  removeModal()

  # ... existing copy logic ...

  # URL already created, status already "ready"
  # Just update UI directly (no need to recreate URL)
})
```

**Edge Case 2: Duplicate Image (Process Anyway)**
```r
observeEvent(input$process_anyway, {
  removeModal()
  rv$pending_existing_data <- NULL

  # URL already created, grid detection already done
  # Just show notification and proceed
  showNotification("Processing with current grid boundaries", type = "message", duration = 2)
  rv$trigger_extraction <- rv$trigger_extraction + 1
})
```

**Edge Case 3: Grid Detection Failure**
```r
# In grid detection block (lines 283-394)
if (!is.null(py_results)) {
  # ... existing success logic ...
  rv$processing_status <- "ready"
} else {
  # Grid detection failed completely
  rv$processing_status <- "error"
  rv$processing_message <- "Python grid detection failed"

  # Don't create URL if detection failed
  # User will see error UI with retry button
  return()
}
```

**Edge Case 4: Python Not Available**
```r
# In fallback block (lines 396-442)
if (is.null(rv$image_dims_original)) {
  # Try fallback methods...

  if (!is.null(dims_result)) {
    # Fallback succeeded
    rv$image_dims_original <- dims_result
    # ... set default grid ...
    rv$processing_status <- "ready"

    # NOW create URL (after fallback success)
    rv$image_url_display <- paste0(...)
  } else {
    # Complete failure
    rv$processing_status <- "error"
    rv$processing_message <- "Could not read image dimensions"
    showNotification(...)
    return()  # Don't create URL
  }
}
```

---

## Success Criteria

### Functional Requirements

- [ ] **No broken image icons:** Image never displays as broken during upload
- [ ] **Clear loading feedback:** User sees spinner and status messages
- [ ] **Smooth transition:** Image appears fully formed, no flicker
- [ ] **Error handling:** Clear error messages if processing fails
- [ ] **Retry capability:** User can retry failed uploads
- [ ] **Duplicate handling:** "Use Existing" and "Process Anyway" still work
- [ ] **Grid detection:** Automatic detection still functions correctly
- [ ] **Manual grid adjustment:** Draggable lines still work
- [ ] **Extraction:** Crop extraction still works as expected

### User Experience Requirements

- [ ] **Visual consistency:** Loading state matches app design language
- [ ] **Progress indication:** User knows what's happening at each step
- [ ] **Error recovery:** Clear path to resolve upload failures
- [ ] **Performance:** No noticeable delay beyond actual processing time
- [ ] **Reliability:** Works consistently across multiple uploads
- [ ] **Responsiveness:** UI updates reflect actual processing state

### Technical Requirements

- [ ] **No new dependencies:** Uses only existing Shiny/bslib components
- [ ] **Module namespace safe:** All IDs properly namespaced
- [ ] **Backward compatible:** Doesn't break existing functionality
- [ ] **Memory efficient:** No resource leaks from status tracking
- [ ] **Error handling:** Graceful degradation on failures
- [ ] **Testable:** Changes enable automated testing

---

## Testing Plan

### Critical Tests (Must Pass)

#### Test 1: Normal Upload Flow
```
Action: Upload new face image (3x1 postal card grid)
Expected:
  1. Shows "Uploading..." spinner (< 100ms)
  2. Shows "Detecting grid..." spinner (100-500ms)
  3. Image displays correctly with grid overlay
  4. Grid controls show: Rows=3, Cols=1
  5. NO broken image icon at any point
```

#### Test 2: Large File Upload
```
Action: Upload 10MB+ face image
Expected:
  1. Spinner appears immediately
  2. Status messages update during processing
  3. Longer wait time (1-2 seconds) but smooth
  4. Image displays correctly after processing
  5. NO timeout errors
```

#### Test 3: Duplicate Image (Use Existing)
```
Action:
  1. Upload face image
  2. Extract crops
  3. Close app
  4. Restart app
  5. Upload SAME face image
  6. Click "Use Existing"
Expected:
  1. Modal appears with previous processing date
  2. Click "Use Existing" closes modal
  3. Image displays immediately (no broken icon)
  4. Existing crops display in grid
  5. Grid controls show previous rows/cols
```

#### Test 4: Duplicate Image (Process Anyway)
```
Action:
  1. Upload duplicate image
  2. Click "Process Anyway"
Expected:
  1. Modal closes
  2. Image ALREADY displayed (no re-processing)
  3. Current grid detection preserved
  4. Can adjust grid and extract normally
```

#### Test 5: Grid Detection Failure
```
Action: Upload non-postal card image (e.g., abstract art)
Expected:
  1. Spinner appears during processing
  2. Error UI displays with clear message
  3. "Try Again" button appears
  4. NO broken image icon
  5. Can retry with different image
```

#### Test 6: Python Not Available
```
Action:
  1. Set Python detection to fail (mock)
  2. Upload image
Expected:
  1. Falls back to magick/jpeg/png packages
  2. Sets default 1x1 grid
  3. Image displays correctly
  4. Can manually adjust grid
```

#### Test 7: WSL2 Filesystem Lag
```
Action: Upload image on WSL2 environment
Expected:
  1. File verification retry logic works
  2. Grid detection completes despite lag
  3. Image displays without broken state
  4. Processing takes slightly longer but succeeds
```

#### Test 8: Rapid Sequential Uploads
```
Action:
  1. Upload face image (wait for complete)
  2. Upload verso image immediately after
Expected:
  1. Both images display correctly
  2. No interference between modules
  3. Each shows proper loading state
  4. Both grids detected independently
```

#### Test 9: Start Over Functionality
```
Action:
  1. Upload face and verso
  2. Extract crops
  3. Click "Start Over"
  4. Upload new images
Expected:
  1. Previous images cleared
  2. New uploads work correctly
  3. No leftover broken image states
  4. Processing status resets properly
```

### Discovery Tests (Edge Cases)

#### Test 10: Double-Click Upload
```
Action: Double-click file in upload dialog
Expected:
  1. First upload processes normally
  2. Second upload either queued or ignored
  3. No crash or broken state
  4. Final image displays correctly
```

#### Test 11: Cancel During Processing
```
Action:
  1. Start upload
  2. Immediately click browser back/refresh
Expected:
  1. Cleanup handlers run
  2. Temp files cleaned up
  3. No orphaned processing state
```

#### Test 12: Very Slow System
```
Action: Upload on system with slow disk I/O
Expected:
  1. Extended spinner duration (up to 5 seconds)
  2. Eventually displays correctly
  3. No timeout errors
  4. Retry logic handles delays
```

---

## Implementation Checklist

### Pre-Implementation

- [ ] Read this PRP completely
- [ ] Review `R/mod_postal_card_processor.R` current state
- [ ] Backup current file to `Delcampe_BACKUP/`
- [ ] Read previous fix memory: `image_upload_race_condition_fix_20251020`
- [ ] Understand why previous fix was insufficient

### Core Changes

- [ ] Add `processing_status` and `processing_message` to `rv` reactiveValues
- [ ] Move URL creation AFTER grid detection (relocate line 274)
- [ ] Add status updates throughout upload observer
- [ ] Implement loading UI in `images_panel` renderUI
- [ ] Implement error UI in `images_panel` renderUI
- [ ] Add retry button handler for error state
- [ ] Update grid detection success path to set status "ready"
- [ ] Update grid detection failure path to set status "error"
- [ ] Update fallback logic to set status appropriately

### Edge Cases

- [ ] Verify "Use Existing" doesn't re-trigger loading state
- [ ] Verify "Process Anyway" preserves existing URL
- [ ] Handle Python unavailable scenario
- [ ] Handle magick package unavailable scenario
- [ ] Add proper cleanup on upload cancellation
- [ ] Test reset_module() function compatibility

### Testing

- [ ] Run critical tests 1-9 manually
- [ ] Run discovery tests 10-12 manually
- [ ] Test on WSL2 environment specifically
- [ ] Test with various image sizes (100KB - 10MB)
- [ ] Test with various grid complexities (1x1 to 5x5)
- [ ] Verify no console errors during any test

### Documentation

- [ ] Update Serena memory: `image_upload_race_condition_fix_FINAL_20251029.md`
- [ ] Document new `processing_status` values and transitions
- [ ] Add code comments explaining status flow
- [ ] Update any affected documentation in `docs/`

### Verification

- [ ] Code parses without errors (`R CMD CHECK`)
- [ ] App starts successfully
- [ ] No breaking changes to existing features
- [ ] All critical tests pass (100%)
- [ ] Discovery tests provide insights (no blocking failures)

---

## Rollback Plan

### If Issues Arise

**Quick Rollback:**
```bash
cd /mnt/c/Users/mariu/Documents/R_Projects/Delcampe
cp R/mod_postal_card_processor.R R/mod_postal_card_processor.R.failed_attempt
cp /mnt/c/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/mod_postal_card_processor.R.backup_[timestamp] R/mod_postal_card_processor.R
```

**Partial Rollback (Keep Some Changes):**
If loading UI works but URL timing doesn't:
- Keep `processing_status` tracking
- Keep loading/error UI
- Revert URL creation timing to previous location
- Use `later::later()` as temporary fix

### Alternative Approaches

If this fix doesn't work:

#### **Alt 1: Pre-render Image**
- Load image in hidden div during grid detection
- Show div only after detection complete
- Ensures image cached before display

#### **Alt 2: Two-Stage UI**
- Stage 1: Show image without grid overlay (faster)
- Stage 2: Add grid overlay after detection (progressive)

#### **Alt 3: Server-Side Rendering**
- Generate preview image server-side with grid overlay
- Send single complete image to browser
- Eliminates client-side race conditions

---

## Related Issues

### Previous Fix Attempts

1. **2025-10-20:** File readability race condition
   - **Status:** ✅ FIXED
   - **Memory:** `image_upload_race_condition_fix_20251020`
   - **Issue:** File not ready before browser loads
   - **Solution:** Retry logic with byte read verification

2. **2025-10-14:** AI UI population timing
   - **Status:** ✅ FIXED
   - **Memory:** `ai_ui_population_timing_fix_20251014`
   - **Issue:** Form fields empty despite data loaded
   - **Solution:** `later::later()` delay for UI updates

3. **Current Issue:** Image display race condition
   - **Status:** 🔴 OPEN
   - **Issue:** Broken image icon due to premature URL creation
   - **Solution:** This PRP

### Similar Patterns in Codebase

**Pattern:** Delay UI updates until data ready
- **File:** `R/mod_delcampe_export.R` lines 390-459
- **Technique:** `later::later()` with 150ms delay
- **Use case:** Pre-populate AI extraction fields

**Pattern:** Progressive UI rendering
- **File:** `R/mod_delcampe_export.R` lines 46-72
- **Technique:** Accordion renders after data reactive
- **Use case:** Combined images display

### Dependencies

**This fix enables:**
- Better user retention (reduced abandonment)
- Professional app appearance
- Easier debugging (clear status messages)
- Foundation for future progress indicators

**This fix blocks:**
- None (pure enhancement)

**This fix depends on:**
- Existing file verification logic (already working)
- Grid detection functionality (already working)
- Shiny reactive system (core framework)

---

## Design Principles Applied

From `CLAUDE.md`:

### ✅ Simplicity First
- Uses native Shiny reactive patterns (no custom JS)
- Clear status flow: uploading → detecting → ready
- Simple state machine (5 states)

### ✅ Fail Fast
- Checks grid detection success before creating URL
- Shows error UI immediately on failure
- Provides retry mechanism

### ✅ Single Responsibility
- `processing_status`: tracks state only
- `image_url_display`: triggers render only when safe
- Loading UI: shows progress only

### ✅ Library Usage Hierarchy
- **First:** Base Shiny (renderUI, reactive values)
- **Second:** CSS for loading spinner (no bslib needed)
- **No custom JS:** Uses Shiny reactivity

### ✅ User Feedback
- Clear messages at each stage
- Visual loading indicator
- Error states with recovery path

---

## Success Metrics

### User Experience Metrics

- **Broken Image Occurrences:** 0 (currently: intermittent)
- **User Confusion Reports:** 0 (currently: high)
- **Upload Abandonment Rate:** < 5% (currently: unknown but likely high)
- **Retry Attempts:** Track how often users use retry button

### Technical Metrics

- **Processing Time:** No increase (just better feedback)
- **Error Rate:** Same or lower (better error handling)
- **Memory Usage:** Minimal increase (~2 reactive values)
- **Code Complexity:** Slight increase (status tracking) but worth it

### Validation

After implementation:
1. Monitor Shiny logs for `processing_status` transitions
2. Track time spent in each status (should be: uploading < 100ms, detecting 200-500ms)
3. Confirm zero console errors related to image rendering
4. User testing: 5+ people upload images, observe broken image occurrences

**Target:** 0 broken image reports in first week after deployment

---

## Notes for Implementation

### Critical Constraints

From `CLAUDE.md`:
- ✅ No modification to R-Python integration (we're not changing that)
- ✅ Backups go to `Delcampe_BACKUP/` (not R/ directory)
- ✅ Run critical tests before commit
- ✅ Use Serena for code operations

### Code Style

- Use `%||%` operator for NULL coalescing
- Follow existing error message patterns
- Maintain consistent logging format
- Keep console messages with emoji indicators (✅ ✗ ⚠️ 🔄)

### Performance Considerations

- Status updates are lightweight (string assignment)
- Loading UI is pure HTML/CSS (no complex rendering)
- No additional file operations (just reordering existing code)
- Memory impact: ~100 bytes for status tracking

### Security Considerations

- No new file operations (no new attack surface)
- No new user input validation needed
- Status messages don't expose sensitive paths
- Error messages remain user-friendly (no internal details)

---

## Timeline Estimate

- **Reading/Understanding:** 20 minutes
- **Core Implementation:** 60 minutes
- **Edge Case Handling:** 30 minutes
- **Testing (Critical):** 40 minutes
- **Testing (Discovery):** 30 minutes
- **Documentation:** 20 minutes

**Total:** ~3 hours for complete, tested implementation

**Recommended Approach:**
1. Implement core changes (Phase 1-2)
2. Test basic functionality
3. Add loading UI (Phase 3)
4. Test edge cases (Phase 4)
5. Document and finalize

---

## Questions for Clarification

Before implementation, consider:

1. **Loading spinner style:** Should it match any existing loading indicators in the app?
2. **Error retry:** Should retry button re-upload or reprocess current file?
3. **Status visibility:** Should status messages be logged to console, shown to user, or both?
4. **Duplicate modal timing:** Should it appear during "detecting" or wait until "ready"?

**Recommended Answers:**
1. Use simple CSS spinner (proven in many Shiny apps)
2. Retry should clear state and require new upload (safer)
3. Both: console for debugging, UI for user feedback
4. Wait until "ready" (current behavior, less confusing)

---

## Final Notes

This PRP represents a **complete architectural fix** for the image upload display race condition, not a workaround or band-aid solution.

**Key Insight:** The issue isn't about file system timing (that was fixed). It's about **data dependency timing** in the UI layer.

**The Fix:** Align URL creation with data availability = No more broken images.

**The Bonus:** Better UX through clear loading states and error handling.

**Expected Outcome:** Smooth, professional image upload experience that builds user trust and confidence in the application.

---

**Status:** 🟢 READY FOR CLAUDE TO IMPLEMENT

**Approval:** Awaiting user confirmation to proceed with implementation.
