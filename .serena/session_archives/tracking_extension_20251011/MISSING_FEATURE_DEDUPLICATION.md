# CRITICAL MISSING FEATURE: Image Deduplication & Crop Reuse

**Date:** October 10, 2025  
**Status:** ⚠️ MISSING FROM OUR IMPLEMENTATION

---

## What We Missed

The existing tracking system has a **deduplication feature** that:

### 1. **Image Hash-Based Deduplication**
- Calculates MD5 hash of uploaded images
- Stores hash in `images` table (`file_hash` column - already in our schema ✅)
- Checks if same image was processed before

### 2. **Crop Reuse System**
When user uploads an image that was already processed:
- **Detects** duplicate via image hash
- **Validates** that previous crop files still exist
- **Shows modal** asking user to reuse or process new
- **Copies crops** from previous extraction if user chooses reuse
- **Restores exact grid boundaries** from original processing

### 3. **Grid Configuration Restoration**
Two levels of restoration:
- **Exact boundaries:** Restores precise grid line positions from original
- **Approximate boundaries:** Falls back to evenly-spaced grid if exact boundaries not stored

---

## Functions We Need to Add

Looking at the code in `mod_postal_cards_face.R`, we need:

### 1. `calculate_image_hash()` ✅ Already used in our code
```r
# Already in tracking_database.R at line ~60
file_hash <- digest::digest(file = full_path, algo = "md5")
```

### 2. `find_existing_processing()` ❌ MISSING
```r
#' Find existing processing for an image by hash
#' @param image_hash MD5 hash of the image
#' @param image_type Type of image ('face' or 'verso')
#' @return List with existing processing details or NULL
#' @export
find_existing_processing <- function(image_hash, image_type = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con))
    
    # Find images with matching hash
    query <- "
      SELECT 
        i.image_id,
        i.session_id,
        i.upload_path,
        i.upload_timestamp,
        i.processing_status,
        p.details
      FROM images i
      LEFT JOIN processing_log p ON i.image_id = p.image_id 
        AND p.action = 'extraction_complete'
      WHERE i.file_hash = ?
    "
    
    params <- list(as.character(image_hash))
    
    if (!is.null(image_type)) {
      query <- paste(query, "AND i.image_type LIKE ?")
      params <- append(params, paste0("%", image_type, "%"))
    }
    
    query <- paste(query, "ORDER BY i.upload_timestamp DESC LIMIT 1")
    
    result <- DBI::dbGetQuery(con, query, params)
    
    if (nrow(result) == 0) {
      return(NULL)
    }
    
    # Parse extraction details from JSON
    extraction_details <- if (!is.na(result$details[1])) {
      jsonlite::fromJSON(result$details[1])
    } else {
      list()
    }
    
    return(list(
      image_id = result$image_id[1],
      session_id = result$session_id[1],
      upload_path = result$upload_path[1],
      upload_time = result$upload_timestamp[1],
      grid_config = extraction_details$grid_config,
      cropped_paths = extraction_details$cropped_paths,
      h_boundaries = extraction_details$h_boundaries,
      v_boundaries = extraction_details$v_boundaries,
      extraction_dir = extraction_details$extraction_dir
    ))
    
  }, error = function(e) {
    message("❌ Error finding existing processing: ", e$message)
    return(NULL)
  })
}
```

### 3. `validate_existing_crops()` ❌ MISSING
```r
#' Validate that crop files from previous processing still exist
#' @param cropped_paths Vector of file paths to validate
#' @return List with existing_paths and missing_paths
#' @export
validate_existing_crops <- function(cropped_paths) {
  if (is.null(cropped_paths) || length(cropped_paths) == 0) {
    return(list(
      existing_paths = character(0),
      missing_paths = character(0)
    ))
  }
  
  # Convert to character vector if it's a list
  if (is.list(cropped_paths)) {
    cropped_paths <- unlist(cropped_paths)
  }
  
  existing <- character(0)
  missing <- character(0)
  
  for (path in cropped_paths) {
    if (file.exists(path)) {
      existing <- c(existing, path)
    } else {
      missing <- c(missing, path)
    }
  }
  
  return(list(
    existing_paths = existing,
    missing_paths = missing
  ))
}
```

### 4. `copy_existing_crops()` ❌ MISSING
```r
#' Copy existing crop files to a new directory
#' @param existing_paths Vector of paths to copy from
#' @param target_dir Directory to copy to
#' @return Vector of new file paths
#' @export
copy_existing_crops <- function(existing_paths, target_dir) {
  if (length(existing_paths) == 0) {
    return(character(0))
  }
  
  # Create target directory
  dir.create(target_dir, showWarnings = FALSE, recursive = TRUE)
  
  copied_paths <- character(0)
  
  for (path in existing_paths) {
    if (file.exists(path)) {
      filename <- basename(path)
      target_path <- file.path(target_dir, filename)
      
      success <- file.copy(path, target_path, overwrite = TRUE)
      
      if (success && file.exists(target_path)) {
        copied_paths <- c(copied_paths, target_path)
      } else {
        warning(paste("Failed to copy:", path))
      }
    }
  }
  
  return(copied_paths)
}
```

### 5. `mark_processing_reused()` ❌ MISSING
```r
#' Mark that processing was reused from a previous session
#' @param session_id Current session ID
#' @param image_type Type of image
#' @param source_session_id Session ID of original processing
#' @return Success status
#' @export
mark_processing_reused <- function(session_id, image_type, source_session_id) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con))
    
    # Find current image
    image_record <- DBI::dbGetQuery(con, "
      SELECT image_id, user_id FROM images 
      WHERE session_id = ? AND image_type LIKE ?
      ORDER BY upload_timestamp DESC
      LIMIT 1
    ", list(session_id, paste0("%", image_type, "%")))
    
    if (nrow(image_record) == 0) {
      warning("No image found to mark as reused")
      return(FALSE)
    }
    
    image_id <- image_record$image_id[1]
    user_id <- image_record$user_id[1]
    
    # Log the reuse action
    DBI::dbExecute(con, "
      INSERT INTO processing_log (image_id, action, user_id, details)
      VALUES (?, ?, ?, ?)
    ", list(
      image_id,
      "processing_reused",
      user_id,
      jsonlite::toJSON(list(source_session_id = source_session_id), auto_unbox = TRUE)
    ))
    
    return(TRUE)
    
  }, error = function(e) {
    message("❌ Error marking processing as reused: ", e$message)
    return(FALSE)
  })
}
```

### 6. `format_timestamp()` ❌ MISSING (utility)
```r
#' Format timestamp for display
#' @param timestamp POSIXct or character timestamp
#' @return Formatted string
#' @export
format_timestamp <- function(timestamp) {
  if (is.null(timestamp)) {
    return("Unknown")
  }
  
  tryCatch({
    if (is.character(timestamp)) {
      timestamp <- as.POSIXct(timestamp)
    }
    
    format(timestamp, "%Y-%m-%d %H:%M:%S")
  }, error = function(e) {
    return(as.character(timestamp))
  })
}
```

### 7. `create_web_paths()` ❌ MISSING (utility)
```r
#' Convert file system paths to web-accessible paths
#' @param file_paths Vector of absolute file paths
#' @param session_temp_dir Session temporary directory base path
#' @param resource_prefix Shiny resource path prefix
#' @return Vector of web paths
#' @export
create_web_paths <- function(file_paths, session_temp_dir, resource_prefix) {
  if (length(file_paths) == 0) {
    return(character(0))
  }
  
  abs_paths <- normalizePath(file_paths, winslash = "/")
  abs_sess_dir <- normalizePath(session_temp_dir, winslash = "/")
  
  # Remove session directory prefix
  rel_paths <- gsub(paste0("^", gsub("\\\\", "\\\\\\\\", abs_sess_dir), "[/\\\\]*"), 
                    "", abs_paths)
  rel_paths <- sub("^[/\\\\]+", "", rel_paths)
  
  # Add resource prefix
  file.path(resource_prefix, rel_paths)
}
```

---

## How It Works in the UI

When user uploads an image:

```r
# 1. Calculate hash
image_hash <- calculate_image_hash(local_image_path)

# 2. Check for existing processing
existing_processing <- find_existing_processing(image_hash, "face")

if (!is.null(existing_processing)) {
  # 3. Validate crops still exist
  crop_validation <- validate_existing_crops(existing_processing$cropped_paths)
  
  if (length(crop_validation$existing_paths) > 0) {
    # 4. Show modal asking user
    showModal(modalDialog(
      title = "Existing Processing Found",
      # ... show comparison UI ...
      footer = tagList(
        actionButton(ns("reuse_existing"), "Use Existing Crops"),
        actionButton(ns("process_new"), "Process New"),
        modalButton("Cancel")
      )
    ))
  }
}

# If user clicks "reuse_existing":
observeEvent(input$reuse_existing, {
  # 5. Copy existing crops
  copied_paths <- copy_existing_crops(validation$existing_paths, py_out_dir)
  
  # 6. Restore grid configuration
  rv$h_boundaries <- existing$h_boundaries
  rv$v_boundaries <- existing$v_boundaries
  rv$current_grid_rows <- existing$grid_config$rows
  rv$current_grid_cols <- existing$grid_config$cols
  
  # 7. Track the reuse
  mark_processing_reused(session_id, "face", existing$session_id)
  
  # 8. Display reused crops
  rv$extracted_paths_web <- create_web_paths(copied_paths, ...)
})
```

---

## Why This is Important

### Benefits:
1. **Saves processing time** - No need to re-run Python extraction
2. **Preserves user's work** - Exact grid configuration from original
3. **User choice** - Can reuse or process fresh
4. **Disk space optimization** - Can reuse existing crop files
5. **Better UX** - Shows user they've processed this before

### Use Cases:
- User accidentally uploads same image twice
- User wants to try different combinations in Delcampe export
- User closed app and reopens with same images
- Testing/debugging with same test images

---

## Integration with AI Extraction & eBay Tracking

The deduplication system **should also check AI extractions**:

```r
#' Find existing AI extraction for an image
#' @param image_hash Image hash
#' @return List with AI extraction data or NULL
#' @export
find_existing_ai_extraction <- function(image_hash) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con))
    
    result <- DBI::dbGetQuery(con, "
      SELECT 
        ae.extraction_id,
        ae.model,
        ae.title,
        ae.description,
        ae.condition,
        ae.recommended_price,
        ae.extracted_at
      FROM ai_extractions ae
      JOIN images i ON ae.image_id = i.image_id
      WHERE i.file_hash = ?
        AND ae.success = 1
      ORDER BY ae.extracted_at DESC
      LIMIT 1
    ", list(as.character(image_hash)))
    
    if (nrow(result) == 0) {
      return(NULL)
    }
    
    return(as.list(result[1, ]))
    
  }, error = function(e) {
    message("❌ Error finding existing AI extraction: ", e$message)
    return(NULL)
  })
}
```

**Use case:** If user uploads same postcard again, we can suggest:
- "We've already extracted this postcard with Claude"
- "Would you like to reuse the previous title/description?"

---

## What to Do Now

### Option 1: Add Full Deduplication Feature ✅
- Add all 7 missing functions to `tracking_database.R`
- Update integration guide
- Test deduplication workflow

### Option 2: Document as Future Enhancement 📋
- Add to documentation as "Advanced Feature"
- Note that hash column exists in schema
- Implement when needed

### Option 3: Minimal Implementation 🔄
- Add just `find_existing_processing()` 
- Add simple modal in UI
- Basic "already processed" notification

---

## Recommendation

**Add the deduplication functions to `tracking_database.R`** because:

1. ✅ The `file_hash` column already exists in our schema
2. ✅ The infrastructure is there (it's just functions we're missing)
3. ✅ It's a killer feature that saves user time
4. ✅ Clean integration point with AI extraction system
5. ✅ Relatively simple to implement (~200 lines of code)

**Status:** Ready to implement as an enhancement to our current work! 🚀

---

**Files to Update:**
- `R/tracking_database.R` - Add 7 new functions
- `QUICK_REFERENCE.md` - Add deduplication section
- `test_database_tracking.R` - Add deduplication tests
