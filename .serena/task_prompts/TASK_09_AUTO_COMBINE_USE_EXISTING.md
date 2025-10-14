# TASK: Fix "Use Existing" to Auto-Trigger Combine

## Context

When a user uploads duplicate images and clicks "Use Existing" for BOTH face and verso, the crops are restored instantly. However, the "Combine Images" button doesn't appear automatically, even though we have all the necessary data to combine.

## Current Behavior

### What Happens Now:
1. Upload face image → Modal appears → Click "Use Existing"
2. Face crops restore ✅
3. Upload verso image → Modal appears → Click "Use Existing"  
4. Verso crops restore ✅
5. **Problem:** User must manually click "Combine Images" button

### Expected Behavior:
1. Upload face image → Modal appears → Click "Use Existing"
2. Face crops restore ✅
3. Upload verso image → Modal appears → Click "Use Existing"
4. Verso crops restore ✅
5. **Automatic:** Combine process triggers, combined images appear

## Why This Matters

User experience issue:
- If the user is reusing existing crops, they clearly want to see the combined images
- Making them click "Combine" is an unnecessary extra step
- We already have all the data needed (face crops + verso crops)

## Technical Analysis

### Current State Detection

In `app_server.R`, the combined_image_output_display uses these flags:
```r
face_extraction_complete: TRUE/FALSE
verso_extraction_complete: TRUE/FALSE
images_processed: TRUE/FALSE
```

### The Problem

When "Use Existing" is clicked:
- Crops are restored
- `extraction_complete` flags are set to TRUE
- **But `images_processed` stays FALSE**
- So it shows "STATE 2: Ready to combine" with the button
- Instead of automatically processing

### Current Logic

```r
output$combined_image_output_display <- renderUI({
  if (face_extracted && verso_extracted && !images_processed) {
    # STATE 2: Ready to combine
    # Shows "Combine Images" button
  } else if (images_processed) {
    # STATE 3: Show combined images
  }
})
```

### The Fix Needed

When BOTH face and verso use existing crops:
1. Set `images_processed = TRUE`
2. Trigger the combine process automatically
3. Skip showing the "Combine Images" button

## Implementation Plan

### Location: R/mod_postal_card_processor.R

In the "Use Existing" button observer (~line 540):

**Current code:**
```r
observeEvent(input$use_existing_crops, {
  req(rv$pending_existing_data)
  removeModal()
  
  # Copy crops
  copy_result <- copy_existing_crops(...)
  
  # Restore boundaries and grid
  rv$h_boundaries <- existing$h_boundaries
  rv$v_boundaries <- existing$v_boundaries
  rv$current_grid_rows <- existing$grid_rows
  rv$current_grid_cols <- existing$grid_cols
  
  # Create web URLs for crops
  rv$extracted_paths_web <- ...
  
  # Track as reused
  track_session_activity(...)
  
  # Force UI update
  rv$force_grid_redraw <- rv$force_grid_redraw + 1
  
  # END - User must click combine
})
```

**Needed addition:**
```r
observeEvent(input$use_existing_crops, {
  # ... all existing code ...
  
  # NEW: Check if both face AND verso are now complete
  # If yes, auto-trigger combine
  
  # Call the on_extraction_complete callback if provided
  if (!is.null(on_extraction_complete)) {
    on_extraction_complete(length(rv$extracted_paths_web), extraction_dir)
  }
  
  rv$pending_existing_data <- NULL
})
```

### In app_server.R

The on_extraction_complete callback should trigger the combine check:

```r
on_extraction_complete = function(n_crops, extract_dir) {
  # Update module state
  if (module_id == "face_processor") {
    rv$face_extraction_complete <- TRUE
  } else {
    rv$verso_extraction_complete <- TRUE
  }
  
  # NEW: If BOTH are complete, trigger combine automatically
  if (rv$face_extraction_complete && rv$verso_extraction_complete) {
    # Trigger combine process
    # (This might already exist, just needs to be called here)
  }
}
```

## Alternative Approach: Detect "Both Used Existing"

Instead of calling on_extraction_complete, add a flag specifically for "used existing":

```r
# In module
rv$used_existing_crops <- TRUE

# In app_server
if (rv$face_used_existing && rv$verso_used_existing) {
  # Both used existing - trigger combine automatically
  rv$images_processed <- TRUE
  # Trigger combine render
}
```

## Key Decision Point

**Which approach?**

**Option A:** Call on_extraction_complete from "Use Existing"
- Pros: Reuses existing callback mechanism
- Cons: May confuse logic (not technically "extracted")

**Option B:** Add separate "used_existing" flag and detection
- Pros: Clearer separation of concerns
- Cons: More state variables to manage

**Recommendation:** Option A - simpler, reuses existing infrastructure

## Implementation Steps

### Step 1: Add callback to "Use Existing"

In `mod_postal_card_processor.R`, "Use Existing" observer:
```r
# After crops are restored and state is updated
if (!is.null(on_extraction_complete)) {
  on_extraction_complete(
    length(rv$extracted_paths_web),
    dirname(copy_result$new_paths[1])
  )
}
```

### Step 2: Verify callback triggers combine check

In `app_server.R`, ensure the callback checks both modules:
```r
on_extraction_complete = function(n_crops, extract_dir) {
  # Set extraction flag
  if (module_id == "face") {
    rv$face_extraction_complete <- TRUE
    rv$face_extraction_dir <- extract_dir
  } else {
    rv$verso_extraction_complete <- TRUE  
    rv$verso_extraction_dir <- extract_dir
  }
  
  # NEW: Check if both complete
  if (rv$face_extraction_complete && rv$verso_extraction_complete) {
    # Auto-trigger combine
    # The renderUI for combined_output should detect this and process
  }
}
```

### Step 3: Update combined_output render logic

Make sure the render detects the state and processes automatically:
```r
output$combined_image_output_display <- renderUI({
  req(rv$face_extraction_complete, rv$verso_extraction_complete)
  
  # If not processed yet, process automatically
  if (!rv$images_processed) {
    # Run combine process
    result <- combine_face_verso_images(...)
    rv$images_processed <- TRUE
    rv$combined_result <- result
  }
  
  # Display combined images
  # ...
})
```

## Testing Checklist

Test Case 1: **Both Use Existing**
1. Upload face → Extract → Upload verso → Extract → Combine
2. Start over
3. Upload face → "Use Existing" ✓
4. Upload verso → "Use Existing" ✓
5. **Expected:** Combined images appear automatically ✅

Test Case 2: **One Use Existing, One Process**
1. Upload face → "Use Existing" ✓
2. Upload verso → "Process Anyway" → Extract
3. **Expected:** Show "Combine Images" button (manual trigger)

Test Case 3: **Both Process Anyway**
1. Upload face → "Process Anyway" → Extract
2. Upload verso → "Process Anyway" → Extract
3. **Expected:** Show "Combine Images" button (existing behavior)

## Edge Cases

1. **What if face uses existing but verso is new?**
   → Don't auto-combine, show button

2. **What if crops from existing are invalid?**
   → Should have been caught by validate_existing_crops()

3. **What if extraction directories don't match expectations?**
   → Track extract_dir when restoring existing crops

## Files to Modify

1. **R/mod_postal_card_processor.R** (~line 560)
   - Add on_extraction_complete call in "Use Existing" observer

2. **R/app_server.R** (~line 150)
   - Update on_extraction_complete callback to trigger combine check

3. **R/app_server.R** (~line 300)
   - Update combined_output render to auto-process when both complete

## Success Criteria

✅ Click "Use Existing" for face, then "Use Existing" for verso → Combined images appear automatically  
✅ No extra button click required  
✅ Works seamlessly with the existing extraction flow  
✅ Doesn't break the "Process Anyway" path  

## Next Steps

1. Add the on_extraction_complete call in "Use Existing"
2. Test the auto-combine trigger
3. Verify edge cases work correctly
4. Update UI feedback (maybe show "Combining images..." briefly)

---

**Ready to implement?** Start with Step 1: Add the callback to the "Use Existing" observer.
