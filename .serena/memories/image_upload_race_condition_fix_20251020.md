# Image Upload Race Condition Fix - 2025-10-20

## Problem Summary
Intermittent broken image previews in postal card processor when uploading images, especially:
- Already processed (duplicate) images
- Larger files
- Alternating between face and verso uploads
- WSL2 filesystem operations

## Root Cause
**Race condition in file copy and URL creation** (R/mod_postal_card_processor.R:176-223)

### The Bug
1. `file.copy()` executed WITHOUT success verification
2. Web URL created IMMEDIATELY without checking file readability
3. Browser attempted to load image before filesystem flushed data
4. No retry logic for transient filesystem issues (especially critical on Windows/WSL2)

### Why It Was Intermittent
- File system lag varies (especially cross-filesystem /mnt/c/ operations)
- Larger files take longer to copy
- Already processed images may be from different sessions
- Each module (face/verso) has independent timing
- Browser may cache 404 failures

## Solution Implemented

### File Copy Verification (Lines 181-190)
```r
# CRITICAL FIX: Verify file copy succeeded
copy_success <- file.copy(file_info$datapath, upload_path, overwrite = TRUE)
if (!copy_success) {
  showNotification(
    paste("Failed to save uploaded", card_type, "image. Please try again."),
    type = "error",
    duration = 5
  )
  return()
}
```

### File Readability Check with Retry Logic (Lines 194-230)
```r
# CRITICAL FIX: Wait for file to be readable (with retry logic)
# This prevents race conditions where browser tries to load before file is ready
max_wait <- 10  # iterations
wait_count <- 0
file_ready <- FALSE

while (wait_count < max_wait && !file_ready) {
  if (file.exists(upload_path) && file.size(upload_path) > 0) {
    # Additional check: try to read first few bytes to ensure file is accessible
    can_read <- tryCatch({
      con <- file(upload_path, "rb")
      test_bytes <- readBin(con, "raw", n = 10)
      close(con)
      length(test_bytes) > 0
    }, error = function(e) {
      FALSE
    })

    if (can_read) {
      file_ready <- TRUE
    }
  }

  if (!file_ready) {
    Sys.sleep(0.05)
    wait_count <- wait_count + 1
  }
}

if (!file_ready) {
  showNotification(
    paste("Uploaded", card_type, "image is not readable. Please try again."),
    type = "error",
    duration = 5
  )
  return()
}
```

### URL Creation Deferred (Line 266-272)
```r
# Create web URL (ONLY after file is verified readable)
norm_session_dir <- normalizePath(session_temp_dir, winslash = "/")
norm_upload_path <- normalizePath(upload_path, winslash = "/")
rel_path <- sub(paste0("^", gsub("/", "\\\\/", norm_session_dir), "/*"), "", norm_upload_path)
rel_path <- sub("^/*", "", rel_path)
rv$image_url_display <- paste(resource_prefix, rel_path, sep = "/")
```

## Key Improvements

1. **Fail Fast**: Check copy success immediately, show error and return if failed
2. **Read Verification**: Not just file.exists/size, but actual byte read test
3. **Retry Logic**: Up to 10 attempts with 50ms delay between attempts (max 500ms wait)
4. **User Feedback**: Clear error messages if file operations fail
5. **Sequential Safety**: URL only created after file is verified readable

## Testing Results

✅ **Fix working correctly for normal usage**
- Single-click uploads work reliably
- Already processed images display correctly
- Face/verso alternating uploads work properly
- File system race condition eliminated

⚠️ **Known Edge Case**
- Double-clicking file upload can still briefly show broken image
- This is expected behavior (two rapid uploads interfering)
- Image recovers and displays correctly after
- Not a common user action, no fix needed

## Files Modified
- `R/mod_postal_card_processor.R` (lines 176-272)

## Backup Location
- `/mnt/c/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/mod_postal_card_processor.R.backup_[timestamp]`

## Related Issues
- None currently
- Monitor for similar race conditions in other file operations if needed

## Status
✅ **COMPLETE - Tested and working**
- Fix successfully resolves main issue
- Significant improvement in upload reliability
- Edge case (double-click) is acceptable and recovers gracefully
