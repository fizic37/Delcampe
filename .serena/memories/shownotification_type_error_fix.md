# showNotification Type Error Fix

## Problem Statement
When clicking the "Process Combined Images" button in the Stamps tab, the application threw an error:
```
Processing failed: 'arg' should be one of "default", "message", "warning", "error"
```

## Root Cause Analysis
The error occurred because `showNotification()` in Shiny only accepts specific values for the `type` parameter:
- `"default"` - Plain notification
- `"message"` - Informational (blue)
- `"warning"` - Warning (yellow/orange)
- `"error"` - Error (red)

The code incorrectly used `type = "success"`, which is **not a valid value** in Shiny's `showNotification()` function.

### Where the Error Occurred
1. **Primary location**: `R/app_server.R` line ~264 in the `observeEvent(input$process_combined, ...)` handler
2. **Secondary locations**: `R/mod_delcampe_export.R` lines ~261 and ~432

### Why This Wasn't Caught Earlier
- `type = "success"` seems intuitive (Bootstrap uses it)
- Error only occurs when the button is clicked
- The function was previously just a TODO stub

## Solution Overview

### Fixed Files
1. **R/app_server.R**
   - Changed `type = "success"` to `type = "message"`
   - Implemented full Python function call to `combine_face_verso_images()`
   - Added proper path conversion for web display
   - Enhanced error logging

2. **R/mod_delcampe_export.R**  
   - Changed `type = "success"` to `type = "message"` in two locations

### Implementation Details

#### Before (app_server.R)
```r
observeEvent(input$process_combined, {
  if (app_rv$face_extraction_complete && app_rv$verso_extraction_complete) {
    tryCatch({
      # TODO: Add your Python processing logic here
      app_rv$images_processed <- TRUE
      app_rv$lot_paths <- c("path1.jpg", "path2.jpg")  # Placeholder!
      showNotification("Images processed successfully!", type = "success")  # ❌
    }, error = function(e) {
      showNotification(paste("Processing failed:", e$message), type = "error")
    })
  }
})
```

#### After (app_server.R)
```r
observeEvent(input$process_combined, {
  if (app_rv$face_extraction_complete && app_rv$verso_extraction_complete) {
    tryCatch({
      # Validate Python availability
      if (!exists("combine_face_verso_images", envir = .GlobalEnv)) {
        showNotification("Python functions not available. Please restart the app.", type = "error")
        return()
      }
      
      # Setup output directory
      combined_output_dir <- file.path(session_temp_dir(), "combined_images")
      dir.create(combined_output_dir, showWarnings = FALSE, recursive = TRUE)
      
      # Get grid dimensions
      num_rows <- app_rv$num_rows %||% 1
      num_cols <- app_rv$num_cols %||% 1
      
      # Call Python function
      py_results <- combine_face_verso_images(
        face_dir = app_rv$face_extraction_dir,
        verso_dir = app_rv$verso_extraction_dir,
        output_dir = combined_output_dir,
        num_rows = as.integer(num_rows),
        num_cols = as.integer(num_cols)
      )
      
      # Convert file paths to web URLs
      # ... path conversion logic ...
      
      app_rv$images_processed <- TRUE
      
      showNotification(
        paste("Successfully created", length(app_rv$lot_paths), "lots and", 
              length(app_rv$combined_paths), "combined images!"),
        type = "message"  # ✅ Valid!
      )
    }, error = function(e) {
      cat("❌ ERROR in process_combined:\n")
      cat("   Message:", e$message, "\n")
      showNotification(paste("Processing failed:", e$message), type = "error")
    })
  }
})
```

## Technical Details

### Path Conversion Logic
The fix includes proper conversion from file system paths to web-accessible URLs:

```r
# Convert absolute paths to relative paths
abs_lot_paths <- normalizePath(unlist(py_results$lot_paths), winslash = "/")
abs_session_dir <- normalizePath(session_temp_dir(), winslash = "/")

# Remove session dir prefix
rel_lot_paths <- sub(paste0("^", gsub("/", "\\\\/", abs_session_dir), "/*"), "", abs_lot_paths)
rel_lot_paths <- sub("^/*", "", rel_lot_paths)

# Create web URLs with resource prefix
app_rv$lot_paths <- paste("combined_session_images", rel_lot_paths, sep = "/")
```

### Python Function Integration
The `combine_face_verso_images()` Python function:
- Auto-detects actual grid from file names (e.g., `crop_row0_col1.jpg`)
- Ignores the suggested `num_rows`/`num_cols` if files indicate different dimensions
- Creates two types of output:
  1. **Lot images**: Vertical stacks of face+verso pairs (one per column)
  2. **Combined images**: Individual horizontal face+verso pairs

## Files Modified

| File | Changes | Lines |
|------|---------|-------|
| R/app_server.R | Fixed notification type + implemented Python call | ~249-267 → ~249-318 |
| R/mod_delcampe_export.R | Fixed notification types (2 instances) | ~261, ~432 |

## Testing Instructions

### Test Scenario
1. Run the app: `golem::run_dev()`
2. Go to "Stamps" tab
3. Upload a face image → Extract face cards
4. Upload a verso image → Extract verso cards
5. Click **"Process Combined Images"**

### Expected Results
✅ No error message
✅ Notification: "Successfully created X lots and Y combined images!"
✅ Combined images display in grid
✅ Export options become available
✅ Console shows Python debug output

### Console Output Example
```
🎨 PROCESSING COMBINED IMAGES:
   Face dir: C:/Users/.../shiny_session_images_.../py_extracted/extract_...
   Verso dir: C:/Users/.../shiny_session_images_.../py_extracted/extract_...
   Output dir: C:/Users/.../shiny_combined_images_.../combined_images
   Grid: 2 x 3

PYTHON DEBUG: combine_face_verso_images called
  - Face dir: ...
  - Verso dir: ...
  - Found 6 face files: ['crop_row0_col0.jpg', ...]
  - Found 6 verso files: ['crop_row0_col0.jpg', ...]
  - AUTO-DETECTED grid: 2x3 (from actual files)
  ...
  - SUMMARY:
    - Created 3 lot images
    - Created 6 individual combined images

   Python results:
     Lot paths: 3
     Combined paths: 6
```

## Success Metrics
- ✅ Button click doesn't throw error
- ✅ Combined images are created
- ✅ UI updates with image grid
- ✅ Both lot and individual images are generated
- ✅ Paths are web-accessible

## Related Components

### Affected Modules
- `mod_postal_card_processor` - Provides extraction directories
- `mod_delcampe_export` - Displays and exports combined images

### Python Integration
- `inst/python/extract_postcards.py` - `combine_face_verso_images()` function
- Loads via `reticulate::import_from_path()` in `app_server.R`
- Functions exposed to global environment

## Key Learnings

### Shiny Notification Types
Always use valid notification types:
```r
# ❌ WRONG
showNotification("Success!", type = "success")

# ✅ CORRECT  
showNotification("Success!", type = "message")
```

### Bootstrap vs Shiny
Bootstrap uses `success` class for styling, but Shiny's `showNotification()` doesn't accept it as a type parameter. The function uses its own type system.

### Error Detection
- Type errors like this only appear at runtime
- R's dynamic typing doesn't catch invalid string values
- Test all button click handlers thoroughly

## Prevention Strategies

### Code Review Checklist
- [ ] Verify all `showNotification()` calls use valid types
- [ ] Test button click handlers in development
- [ ] Check console for type-related errors
- [ ] Review notification calls after copying code from Bootstrap examples

### Linting Rule Suggestion
Could add a custom linter to check for invalid notification types:
```r
# In lintr config
linters: linters_with_defaults(
  object_usage_linter(),
  # Add custom check for showNotification type parameter
)
```

## Date Fixed
2025-10-06

## Status
✅ **RESOLVED** - All notification types corrected and Python function integrated

## Related Documentation
- `BUGFIX_PROCESS_COMBINED_IMAGES.md` - User-facing fix documentation
- `.serena/memories/tech_stack_and_architecture.md` - Python integration details
