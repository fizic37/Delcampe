# Deduplication Fixed - Duplicate Check in Wrong Observer

**Date:** October 13, 2025  
**Status:** ✅ **FIXED** - Moved duplicate check to correct location

## The Bug

The duplicate check code was placed in the **grid update observer** (triggered by changing rows/cols inputs) instead of the **upload observer** (triggered by file upload).

### Why It Didn't Work

When a user uploaded the same image twice:
1. ✅ Image was tracked in database with hash
2. ✅ Extraction was tracked with crop paths
3. ❌ Duplicate check code never ran because it was in wrong observer

The grid update observer only fires when the user **manually changes** the grid rows/cols inputs. On a second upload, the grid is auto-detected but the user doesn't change the inputs, so the observer with the duplicate check never fired.

## The Fix

**Moved duplicate check from grid update observer to upload observer**

### Location

`R/mod_postal_card_processor.R` ~line 417

Now runs immediately after:
- File is uploaded
- Image is tracked in database
- Grid is detected by Python
- Controls are shown

### Code

```r
# Check for duplicate image AFTER upload and grid detection
cat("   🔍 Checking for duplicates with hash:", rv$current_image_hash, "\n")
if (!is.null(rv$current_image_hash)) {
  existing <- find_existing_processing(rv$current_image_hash, card_type)
  cat("   📋 Duplicate check result:", if(is.null(existing)) "NONE" else "FOUND", "\n")
  
  if (!is.null(existing)) {
    validation <- validate_existing_crops(existing$cropped_paths)
    
    if (validation$all_exist) {
      cat("   ✅ Duplicate with valid crops found - showing modal\n")
      message("Duplicate image detected - showing modal")
      
      # Store data for potential reuse
      rv$pending_existing_data <- existing
      
      # Show modal asking user if they want to reuse previous processing
      showModal(modalDialog(
        title = "Duplicate Image Detected",
        HTML(paste0(
          "<p>This image was previously processed on <strong>",
          format_timestamp(existing$processed_at),
          "</strong></p>",
          "<p>Would you like to reuse the previous crops?</p>",
          "<ul>",
          "<li><strong>Use Existing:</strong> Instantly restore ", length(existing$cropped_paths), " crops</li>",
          "<li><strong>Process Anyway:</strong> Continue with current detection</li>",
          "</ul>"
        )),
        footer = tagList(
          actionButton(NS(id, "use_existing_crops"), "Use Existing", class = "btn-primary"),
          actionButton(NS(id, "process_anyway"), "Process Anyway", class = "btn-secondary"),
          modalButton("Cancel")
        ),
        size = "m",
        easyClose = FALSE
      ))
    } else {
      cat("   ⚠️ Duplicate found but crops don't exist - processing normally\n")
    }
  }
} else {
  cat("   ⚠️ No hash available for duplicate check\n")
}
```

## Expected Console Output

### First Upload
```
🔐 Image hash calculated: 0a781da17d5ed16fdb3539c4f0df00eb
✅ Image tracked with ID: 13
🔍 Checking for duplicates with hash: 0a781da17d5ed16fdb3539c4f0df00eb
📋 Duplicate check result: NONE
```

### After Extraction
```
✅ Extraction tracked for image ID: 13
📂 Saved 3 crop paths
```

### Second Upload (Same Image)
```
🔐 Image hash calculated: 0a781da17d5ed16fdb3539c4f0df00eb
✅ Image tracked with ID: 15
🔍 Checking for duplicates with hash: 0a781da17d5ed16fdb3539c4f0df00eb
📋 Duplicate check result: FOUND
✅ Duplicate with valid crops found - showing modal
```

Then the modal appears!

## Testing

1. Restart the app
2. Upload an image (face or verso)
3. Extract crops
4. Upload the SAME image again
5. **Expected:** See modal with "Duplicate Image Detected"
6. Test both buttons:
   - "Use Existing" - should restore crops instantly
   - "Process Anyway" - should allow normal processing

## Status

**Bug Fix: COMPLETE**  
**Testing: Ready for user**  
**Should work now: YES!**