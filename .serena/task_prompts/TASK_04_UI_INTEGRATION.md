# TASK 04: UI Integration for Deduplication

**Estimated Time:** 1.5 hours  
**Priority:** MEDIUM  
**Status:** 🔴 Not Started  
**Depends On:** TASK_03 complete

---

## Goal
Add the deduplication modal to the Shiny app UI so users can reuse existing crops.

---

## Background
Reference implementation: `Delcampe_BACKUP/examples/modules/mod_postal_cards_face.R` (lines 123-268)

The UI should:
1. Check for duplicates after image upload
2. Show a modal if duplicate found
3. Let user choose: "Reuse crops" or "Process again"
4. If reuse: Copy crops and restore boundaries
5. If process: Continue normal workflow

---

## What You Need to Do

### Step 1: Find the Upload Handler

Locate where images are uploaded in your app. This is likely in:
- `R/mod_delcampe_export.R` or
- `R/mod_postal_cards_processor.R` or similar

Look for code that handles file upload, something like:
```r
observeEvent(input$upload_image, {
  # Image upload logic
})
```

### Step 2: Add Deduplication Check

After image upload, add deduplication check:

```r
observeEvent(input$upload_image, {
  req(input$upload_image)
  
  # Existing upload code...
  uploaded_path <- input$upload_image$datapath
  
  # NEW: Calculate hash and check for duplicates
  hash <- calculate_image_hash(uploaded_path)
  existing <- find_existing_processing(hash, "face")  # or "back"
  
  if (!is.null(existing)) {
    # Store info for potential reuse
    rv$pending_reuse <- existing
    rv$current_hash <- hash
    
    # Show modal
    showModal(modalDialog(
      title = "Duplicate Image Detected",
      HTML(sprintf("
        <p>This image was processed previously on <strong>%s</strong>.</p>
        <p>Would you like to reuse the existing crops?</p>
        <ul>
          <li><strong>Reuse crops:</strong> Instantly restore previous boundaries (faster)</li>
          <li><strong>Process again:</strong> Start fresh with new cropping</li>
        </ul>
      ", format(existing$processed_at, "%Y-%m-%d %H:%M"))),
      footer = tagList(
        actionButton("reuse_crops_yes", "Reuse Crops", class = "btn-success"),
        actionButton("reuse_crops_no", "Process Again", class = "btn-primary"),
        modalButton("Cancel")
      ),
      easyClose = FALSE
    ))
  } else {
    # No duplicate, continue normal processing
    # Existing processing code...
  }
})
```

### Step 3: Handle "Reuse Crops" Button

```r
observeEvent(input$reuse_crops_yes, {
  req(rv$pending_reuse)
  
  existing <- rv$pending_reuse
  
  # 1. Validate that crop files still exist
  validation <- validate_existing_crops(existing$cropped_paths)
  
  if (!validation$all_exist) {
    showNotification(
      "Some crop files are missing. Processing from scratch.",
      type = "warning"
    )
    removeModal()
    rv$pending_reuse <- NULL
    return()
  }
  
  # 2. Create new session directory for this image
  new_session_dir <- file.path(
    "inst/app/data/sessions",
    session$token,
    "crops"
  )
  dir.create(new_session_dir, recursive = TRUE, showWarnings = FALSE)
  
  # 3. Copy existing crops
  copy_result <- copy_existing_crops(
    source_paths = existing$cropped_paths,
    dest_dir = new_session_dir,
    new_session_id = session$token
  )
  
  # 4. Restore boundaries in reactive values
  rv$h_boundaries <- existing$h_boundaries
  rv$v_boundaries <- existing$v_boundaries
  rv$cropped_paths <- copy_result$new_paths
  
  # 5. Mark as reused in database
  mark_processing_reused(
    current_session_id = session$token,
    source_session_id = existing$session_id,
    image_id = rv$current_image_id,
    source_image_id = existing$image_id
  )
  
  # 6. Update UI to show crops
  # (Your existing code to display crops)
  
  showNotification(
    "Crops reused successfully!",
    type = "message"
  )
  
  removeModal()
  rv$pending_reuse <- NULL
})
```

### Step 4: Handle "Process Again" Button

```r
observeEvent(input$reuse_crops_no, {
  # User chose to process again
  removeModal()
  rv$pending_reuse <- NULL
  
  # Continue with normal processing
  # (Your existing processing code)
})
```

### Step 5: Store Hash After Upload

Make sure to store the hash in the database:

```r
observeEvent(input$upload_image, {
  # After creating image record
  image_id <- track_image_upload(session$token, filename, image_type)
  
  # Calculate and store hash
  hash <- calculate_image_hash(uploaded_path)
  store_image_hash(image_id, hash)
  
  rv$current_image_id <- image_id
  rv$current_hash <- hash
})
```

### Step 6: Add Reactive Values

At the top of your module, add these reactive values:

```r
rv <- reactiveValues(
  current_image_id = NULL,
  current_hash = NULL,
  pending_reuse = NULL,
  h_boundaries = NULL,
  v_boundaries = NULL,
  cropped_paths = NULL
  # ... other existing reactive values
)
```

---

## Testing the UI

### Manual Test 1: First Upload
1. Upload an image
2. Process it (crop, extract, etc.)
3. Verify hash is stored in database

### Manual Test 2: Duplicate Detection
1. Upload the SAME image again
2. Modal should appear showing duplicate detected
3. Click "Reuse Crops"
4. Verify crops are copied and boundaries restored
5. Verify UI shows the crops immediately

### Manual Test 3: Process Again
1. Upload the same image a third time
2. Modal appears
3. Click "Process Again"
4. Verify normal processing happens

### Manual Test 4: Missing Crops
1. Upload an image and process it
2. Manually delete the crop files
3. Upload same image again
4. Click "Reuse Crops"
5. Should show warning and fall back to normal processing

---

## Key Points

1. **Where to integrate:**
   - After image upload
   - Before any processing starts

2. **What to store in reactive values:**
   - `pending_reuse` - The existing processing data
   - `current_hash` - Hash of current upload
   - `h_boundaries`, `v_boundaries` - For restoration

3. **User experience:**
   - Clear modal with timestamp
   - Two clear options: Reuse or Process
   - Success notification
   - Graceful fallback if files missing

---

## Deliverables

- ✅ Modal appears for duplicate images
- ✅ "Reuse Crops" works and restores boundaries
- ✅ "Process Again" allows fresh processing
- ✅ Hash stored in database on upload
- ✅ Manual testing completed

---

## Next Steps
Once this task is complete, proceed to **TASK_05_LLM_TRACKING.md**
