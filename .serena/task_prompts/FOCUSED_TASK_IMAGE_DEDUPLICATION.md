# TASK: Image Deduplication with Reuse Modal

**Goal:** When a user uploads an image that was already processed, show a modal asking if they want to reuse the existing crops.

**Time Estimate:** 2-3 hours  
**Priority:** HIGH  
**Status:** 🔴 Not Started

---

## What We're Building

```
User uploads image
    ↓
Calculate hash
    ↓
Check database for this hash
    ↓
If found → Show modal: "This image was processed on [date]. Reuse crops?"
    ├─ Yes → Copy crops, restore boundaries
    └─ No → Process normally
```

---

## Step-by-Step Implementation

### STEP 1: Add Hash Storage to Database (if not exists)

Check if `images` table has `file_hash` column:

```r
library(DBI)
library(RSQLite)

con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")

# Check schema
dbGetQuery(con, "PRAGMA table_info(images)")

# If file_hash doesn't exist, add it:
dbExecute(con, "ALTER TABLE images ADD COLUMN file_hash TEXT")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_file_hash ON images(file_hash)")

dbDisconnect(con)
```

---

### STEP 2: Create Hash Calculation Function

Create or add to `R/tracking_deduplication.R`:

```r
#' Calculate MD5 hash of an image file
#' 
#' @param image_path Character: Path to image file
#' @return Character: MD5 hash
calculate_image_hash <- function(image_path) {
  if (!file.exists(image_path)) {
    stop("Image file not found: ", image_path)
  }
  
  # Use tools::md5sum for file hash
  hash <- tools::md5sum(image_path)
  return(as.character(hash))
}
```

**Test it:**
```r
source("R/tracking_deduplication.R")
test_hash <- calculate_image_hash("path/to/any/image.jpg")
print(test_hash)
```

---

### STEP 3: Create Function to Find Existing Processing

Add to `R/tracking_deduplication.R`:

```r
#' Find existing processing for an image hash
#' 
#' @param image_hash Character: Hash from calculate_image_hash()
#' @param image_type Character: "face" or "back" (optional)
#' @return List with existing data, or NULL if not found
find_existing_processing <- function(image_hash, image_type = NULL) {
  library(DBI)
  library(RSQLite)
  
  con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
  on.exit(dbDisconnect(con))
  
  # Build query
  query <- "
    SELECT 
      i.image_id,
      i.session_id,
      i.upload_path,
      i.image_type,
      i.upload_timestamp,
      p.details,
      p.timestamp as processed_at
    FROM images i
    LEFT JOIN processing_log p 
      ON i.image_id = p.image_id 
      AND p.action = 'extraction_complete'
    WHERE i.file_hash = ?
  "
  
  params <- list(image_hash)
  
  # Add image type filter if provided
  if (!is.null(image_type)) {
    query <- paste(query, "AND i.image_type = ?")
    params <- list(image_hash, image_type)
  }
  
  query <- paste(query, "ORDER BY i.upload_timestamp DESC LIMIT 1")
  
  result <- dbGetQuery(con, query, params)
  
  if (nrow(result) == 0 || is.na(result$processed_at)) {
    return(NULL)  # No previous processing found
  }
  
  # Parse JSON from details column
  details <- tryCatch({
    jsonlite::fromJSON(result$details)
  }, error = function(e) {
    return(list())
  })
  
  return(list(
    image_id = result$image_id,
    session_id = result$session_id,
    source_path = result$upload_path,
    image_type = result$image_type,
    uploaded_at = result$upload_timestamp,
    processed_at = result$processed_at,
    h_boundaries = details$h_boundaries,
    v_boundaries = details$v_boundaries,
    cropped_paths = details$cropped_paths
  ))
}
```

**Test it:**
```r
# Should return NULL for random hash
result <- find_existing_processing("fake_hash_12345", "face")
print(result)  # Should be NULL
```

---

### STEP 4: Create Function to Store Hash

Add to `R/tracking_deduplication.R`:

```r
#' Store image hash in database
#' 
#' @param image_id Integer: Image ID from database
#' @param file_hash Character: Hash from calculate_image_hash()
#' @return TRUE if successful
store_image_hash <- function(image_id, file_hash) {
  library(DBI)
  library(RSQLite)
  
  con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
  on.exit(dbDisconnect(con))
  
  dbExecute(con, "
    UPDATE images 
    SET file_hash = ?
    WHERE image_id = ?
  ", list(file_hash, image_id))
  
  return(TRUE)
}
```

---

### STEP 5: Create Crop Copy Functions

Add to `R/tracking_deduplication.R`:

```r
#' Validate that crop files exist
#' 
#' @param crop_paths Character vector: Paths to crop files
#' @return List with all_exist (logical) and missing_files (vector)
validate_existing_crops <- function(crop_paths) {
  if (is.null(crop_paths) || length(crop_paths) == 0) {
    return(list(all_exist = FALSE, missing_files = character()))
  }
  
  existing <- file.exists(crop_paths)
  
  return(list(
    all_exist = all(existing),
    missing_files = crop_paths[!existing]
  ))
}

#' Copy existing crops to new session directory
#' 
#' @param source_paths Character vector: Original crop paths
#' @param dest_dir Character: Destination directory
#' @return List with new_paths and success
copy_existing_crops <- function(source_paths, dest_dir) {
  if (!dir.exists(dest_dir)) {
    dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  new_paths <- character(length(source_paths))
  
  for (i in seq_along(source_paths)) {
    source_file <- source_paths[i]
    filename <- basename(source_file)
    dest_file <- file.path(dest_dir, filename)
    
    success <- file.copy(source_file, dest_file, overwrite = TRUE)
    
    if (!success) {
      warning("Failed to copy: ", source_file)
      return(list(new_paths = NULL, success = FALSE))
    }
    
    new_paths[i] <- dest_file
  }
  
  return(list(new_paths = new_paths, success = TRUE))
}

#' Mark processing as reused in database
#' 
#' @param current_session_id Character: Current session
#' @param source_session_id Character: Source session
#' @param image_id Integer: Current image ID
#' @param source_image_id Integer: Source image ID
#' @return TRUE if successful
mark_processing_reused <- function(current_session_id, source_session_id, 
                                   image_id, source_image_id) {
  library(DBI)
  library(RSQLite)
  
  con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
  on.exit(dbDisconnect(con))
  
  dbExecute(con, "
    INSERT INTO processing_log (session_id, image_id, action, details, timestamp)
    VALUES (?, ?, 'crops_reused', ?, datetime('now'))
  ", list(
    current_session_id,
    image_id,
    jsonlite::toJSON(list(
      source_session_id = source_session_id,
      source_image_id = source_image_id,
      reused_at = as.character(Sys.time())
    ), auto_unbox = TRUE)
  ))
  
  return(TRUE)
}
```

---

### STEP 6: Integrate into Upload Handler

**Find your image upload handler.** This is probably in a file like:
- `R/mod_delcampe_export.R`
- `R/mod_postal_cards_processor.R`

Look for something like:
```r
observeEvent(input$upload_image, {
  # Image upload code here
})
```

**Modify it to add deduplication check:**

```r
# Source the deduplication functions
source("R/tracking_deduplication.R")

observeEvent(input$upload_image, {
  req(input$upload_image)
  
  # Get uploaded file path
  uploaded_path <- input$upload_image$datapath
  filename <- input$upload_image$name
  
  # YOUR EXISTING CODE to save the file...
  # final_path <- ...
  
  # STEP 6.1: Track image in database (your existing function)
  image_id <- track_image_upload(
    session_id = session$token,
    filename = filename,
    image_type = "face"  # or however you determine this
  )
  
  # STEP 6.2: NEW - Calculate and store hash
  hash <- calculate_image_hash(uploaded_path)
  store_image_hash(image_id, hash)
  
  # STEP 6.3: NEW - Check for existing processing
  existing <- find_existing_processing(hash, "face")
  
  if (!is.null(existing)) {
    # DUPLICATE FOUND!
    # Store in reactive values for modal handlers
    rv$pending_reuse <- existing
    rv$current_image_id <- image_id
    rv$current_image_path <- uploaded_path
    
    # Show modal
    showModal(modalDialog(
      title = "Duplicate Image Detected",
      HTML(sprintf("
        <div style='padding: 15px;'>
          <p><strong>This image was previously processed:</strong></p>
          <ul style='margin-top: 10px;'>
            <li>Processed on: <strong>%s</strong></li>
            <li>Session: <code>%s</code></li>
          </ul>
          <hr>
          <p><strong>Would you like to reuse the existing crops?</strong></p>
          <ul style='margin-top: 10px;'>
            <li>✅ <strong>Reuse crops:</strong> Instantly restore previous boundaries (saves time)</li>
            <li>🔄 <strong>Process again:</strong> Start fresh with new cropping</li>
          </ul>
        </div>
      ", 
        format(as.POSIXct(existing$processed_at), "%Y-%m-%d %H:%M:%S"),
        substr(existing$session_id, 1, 8)
      )),
      footer = tagList(
        actionButton("reuse_crops_yes", "✅ Reuse Crops", class = "btn-success"),
        actionButton("reuse_crops_no", "🔄 Process Again", class = "btn-primary"),
        modalButton("Cancel")
      ),
      size = "m",
      easyClose = FALSE
    ))
  } else {
    # No duplicate, continue with normal processing
    # YOUR EXISTING PROCESSING CODE...
  }
})
```

---

### STEP 7: Add Modal Button Handlers

Add these observers in your server function:

```r
# Handler for "Reuse Crops" button
observeEvent(input$reuse_crops_yes, {
  req(rv$pending_reuse, rv$current_image_id)
  
  existing <- rv$pending_reuse
  
  # Validate crop files still exist
  validation <- validate_existing_crops(existing$cropped_paths)
  
  if (!validation$all_exist) {
    showNotification(
      paste("Some crop files are missing:", 
            paste(validation$missing_files, collapse = ", "),
            "Processing from scratch instead."),
      type = "warning",
      duration = 5
    )
    removeModal()
    rv$pending_reuse <- NULL
    return()
  }
  
  # Create destination directory for this session
  crop_dest_dir <- file.path(
    "inst/app/data/sessions",
    session$token,
    "crops"
  )
  
  # Copy crops
  copy_result <- copy_existing_crops(existing$cropped_paths, crop_dest_dir)
  
  if (!copy_result$success) {
    showNotification(
      "Failed to copy crop files. Processing from scratch.",
      type = "error",
      duration = 5
    )
    removeModal()
    rv$pending_reuse <- NULL
    return()
  }
  
  # Restore boundaries and paths in reactive values
  rv$h_boundaries <- existing$h_boundaries
  rv$v_boundaries <- existing$v_boundaries
  rv$cropped_paths <- copy_result$new_paths
  
  # Mark as reused in database
  mark_processing_reused(
    current_session_id = session$token,
    source_session_id = existing$session_id,
    image_id = rv$current_image_id,
    source_image_id = existing$image_id
  )
  
  # Update UI to show the crops
  # (Your existing code to display crops - this depends on your app structure)
  # For example:
  # output$crop_images <- renderUI({ ... })
  
  showNotification(
    "✅ Crops reused successfully!",
    type = "message",
    duration = 3
  )
  
  removeModal()
  rv$pending_reuse <- NULL
})

# Handler for "Process Again" button
observeEvent(input$reuse_crops_no, {
  # User chose to process again
  removeModal()
  rv$pending_reuse <- NULL
  
  # Continue with your normal processing workflow
  # YOUR EXISTING PROCESSING CODE...
})
```

---

### STEP 8: Add Required Reactive Values

At the top of your server function, make sure you have:

```r
rv <- reactiveValues(
  pending_reuse = NULL,
  current_image_id = NULL,
  current_image_path = NULL,
  h_boundaries = NULL,
  v_boundaries = NULL,
  cropped_paths = NULL
  # ... your other reactive values
)
```

---

## Testing the Feature

### Test 1: First Upload (No Duplicate)
1. Start the app
2. Upload an image
3. Should NOT show modal
4. Process normally

### Test 2: Re-upload Same Image (Duplicate)
1. Upload the same image again
2. Should show modal with date
3. Click "Reuse Crops"
4. Should show crops immediately
5. Check database: crops_reused action should be logged

### Test 3: Process Again
1. Upload the same image a third time
2. Modal appears
3. Click "Process Again"
4. Should process normally (no modal)

### Test 4: Missing Crop Files
1. Upload and process an image
2. Manually delete the crop files
3. Upload same image again
4. Click "Reuse Crops"
5. Should show warning and fall back to normal processing

---

## Where to Find Examples

**Reference implementation:**
- `Delcampe_BACKUP/examples/modules/mod_postal_cards_face.R` (lines 123-268)
- Shows full working example of this exact feature

**Your current app structure:**
- Look in `R/` directory for files starting with `mod_`
- Find where `observeEvent(input$upload_image, ...)` is located

---

## Success Criteria

- ✅ Hash calculated and stored on upload
- ✅ Database lookup works
- ✅ Modal appears for duplicates
- ✅ "Reuse Crops" button works
- ✅ "Process Again" button works
- ✅ Crops copied correctly
- ✅ Boundaries restored
- ✅ Database logs reuse action
- ✅ Graceful handling of missing files

---

## If You Get Stuck

**Can't find upload handler:**
```r
# Search for it
grep -r "observeEvent.*upload" R/
# or in R:
list.files("R", pattern = "mod_.*\\.R$", full.names = TRUE)
```

**Database errors:**
```r
# Check database
con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
dbListTables(con)
dbGetQuery(con, "PRAGMA table_info(images)")
dbDisconnect(con)
```

**Want to see it working:**
```r
# Run the reference app
shiny::runApp("Delcampe_BACKUP/examples")
```

---

## Deliverables

1. `R/tracking_deduplication.R` - All deduplication functions
2. Modified upload handler with hash check
3. Modal dialog implementation
4. Button handlers for reuse/process again
5. Working feature that can be tested

---

**This is ONE focused feature. Complete this first, then we can tackle the next feature!**
