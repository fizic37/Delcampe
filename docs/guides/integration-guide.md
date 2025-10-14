# Integration Guide: AI Extraction & eBay Tracking in mod_delcampe_export.R

**Date:** October 10, 2025  
**Purpose:** Step-by-step guide to integrate database tracking into the export module  
**Estimated Time:** 30 minutes

---

## Prerequisites

✅ Database extension completed (`tracking_database.R` updated)  
✅ Test script passes (`test_database_tracking.R`)  
✅ New tables created in `inst/app/data/tracking.sqlite`

## Integration Steps

### Step 1: Add Database Tracking for AI Extractions

**Location:** `R/mod_delcampe_export.R`, inside the `later::later()` function after successful AI extraction

**Find this code (around line 470):**
```r
if (result$success) {
  # Debug: Log raw AI response
  cat("\n   📄 Raw AI Response:\n")
  cat("   ", paste(rep("-", 60), collapse=""), "\n")
  cat(result$content, "\n")
  cat("   ", paste(rep("-", 60), collapse=""), "\n\n")
  
  # Parse enhanced response with price
  parsed <- parse_enhanced_ai_response(result$content)
  
  cat("   ✅ Parsing successful\n")
  cat("      Title:", substr(parsed$title, 1, 50), "...\n")
  cat("      Description:", substr(parsed$description, 1, 100), "...\n")
  cat("      Condition:", parsed$condition, "\n")
  cat("      Price: €", parsed$price, "\n")
```

**Add this code IMMEDIATELY AFTER the parsing:**
```r
  # ========== NEW: Track AI Extraction in Database ==========
  tryCatch({
    cat("   💾 Tracking AI extraction in database...\n")
    
    # Get image_id from database using file path
    image_id <- get_image_by_path(
      file_path = current_path,
      session_id = session$token
    )
    
    if (!is.null(image_id)) {
      # Determine model name
      model_name <- if (selected_model == "claude") {
        "claude-sonnet-4-5-20250929"
      } else {
        "gpt-4o"
      }
      
      # Track the extraction
      extraction_id <- track_ai_extraction(
        image_id = image_id,
        model = model_name,
        title = parsed$title,
        description = parsed$description,
        condition = parsed$condition,
        recommended_price = parsed$price,
        success = TRUE
      )
      
      cat("      ✅ AI extraction tracked with ID:", extraction_id, "\n")
    } else {
      cat("      ⚠️  Could not find image_id for tracking\n")
    }
  }, error = function(e) {
    cat("      ⚠️  Failed to track AI extraction:", e$message, "\n")
    # Don't stop execution - tracking failure shouldn't break AI extraction
  })
  # ========== END: Database Tracking ==========
```

**Result:** Every successful AI extraction will be logged to the database with full details.

---

### Step 2: Track Failed AI Extractions

**Location:** Same file, in the error handler

**Find this code (around line 520):**
```r
} else {
  # Show error
  cat("   ❌ API error:", result$error, "\n")
  output[[paste0("ai_status_", i)]] <- renderUI({
    div(
      style = "padding: 12px; background: #ffebee; border-left: 4px solid #f44336; margin-top: 10px;",
      icon("exclamation-circle", style = "color: #c62828;"),
      paste(" Error:", result$error)
    )
  })
}
```

**Add this code BEFORE showing the error UI:**
```r
} else {
  # Show error
  cat("   ❌ API error:", result$error, "\n")
  
  # ========== NEW: Track Failed Extraction ==========
  tryCatch({
    image_id <- get_image_by_path(current_path, session$token)
    
    if (!is.null(image_id)) {
      model_name <- if (selected_model == "claude") {
        "claude-sonnet-4-5-20250929"
      } else {
        "gpt-4o"
      }
      
      track_ai_extraction(
        image_id = image_id,
        model = model_name,
        success = FALSE,
        error_message = result$error
      )
      
      cat("      💾 Failed extraction tracked in database\n")
    }
  }, error = function(e) {
    # Silently fail - don't break error display
  })
  # ========== END: Database Tracking ==========
  
  output[[paste0("ai_status_", i)]] <- renderUI({
    div(
      style = "padding: 12px; background: #ffebee; border-left: 4px solid #f44336; margin-top: 10px;",
      icon("exclamation-circle", style = "color: #c62828;"),
      paste(" Error:", result$error)
    )
  })
}
```

**Result:** Failed AI extractions will also be tracked for debugging and analytics.

---

### Step 3: Track eBay Posting Intent

**Location:** After the "Send to eBay" button observers section

**Find the section where Send to eBay buttons are defined (currently they don't have observers).** 

**Add this new observer block AFTER the AI extraction observers:**
```r
# ========== NEW: eBay Posting Tracking ==========
# Track when user clicks "Send to eBay" button
observe({
  req(image_paths())
  paths <- image_paths()
  
  lapply(seq_along(paths), function(i) {
    observeEvent(input[[paste0("send_to_ebay_", i)]], {
      
      cat("\n🚀 Send to eBay button clicked for image", i, "\n")
      
      # Get form data
      title <- input[[paste0("item_title_", i)]] %||% ""
      description <- input[[paste0("item_description_", i)]] %||% ""
      price <- input[[paste0("starting_price_", i)]] %||% 2.50
      condition <- input[[paste0("condition_", i)]] %||% "used"
      
      cat("   Title:", substr(title, 1, 50), "...\n")
      cat("   Price: €", price, "\n")
      cat("   Condition:", condition, "\n")
      
      # Get image_id from database
      tryCatch({
        image_id <- get_image_by_path(
          file_path = paths[i],
          session_id = session$token
        )
        
        if (!is.null(image_id)) {
          # Track the posting intent
          post_id <- track_ebay_post(
            image_id = image_id,
            title = title,
            description = description,
            price = price,
            condition = condition,
            status = "pending"
          )
          
          cat("   ✅ eBay post tracked with ID:", post_id, "\n")
          
          # Mark as pending
          isolate({
            rv$pending_images <- c(rv$pending_images, paths[i])
          })
          
          # Show notification
          showNotification(
            "Tracked for eBay posting (API not yet implemented)",
            type = "message",
            duration = 3
          )
          
          # TODO: When eBay API is implemented, add here:
          # 1. Call eBay API with title, description, price, condition
          # 2. On success, update database:
          #    UPDATE ebay_posts 
          #    SET status = 'success', ebay_listing_id = ? 
          #    WHERE post_id = ?
          # 3. On failure, update database:
          #    UPDATE ebay_posts 
          #    SET status = 'failed', error_message = ? 
          #    WHERE post_id = ?
          
        } else {
          cat("   ⚠️  Could not find image_id for eBay tracking\n")
          
          showNotification(
            "Warning: Could not track in database",
            type = "warning",
            duration = 3
          )
        }
      }, error = function(e) {
        cat("   ❌ Error tracking eBay post:", e$message, "\n")
        
        showNotification(
          paste("Error tracking post:", e$message),
          type = "error",
          duration = 5
        )
      })
    })
  })
})
# ========== END: eBay Posting Tracking ==========
```

**Result:** Every click on "Send to eBay" will create a pending post record in the database.

---

## Testing the Integration

### Test Procedure

1. **Start the Shiny app:**
   ```r
   source("dev/run_dev.R")
   ```

2. **Process some images:**
   - Upload face and verso images
   - Extract postcards
   - Navigate to export module

3. **Test AI Extraction Tracking:**
   - Click "Extract with AI" on an image
   - Wait for extraction to complete
   - Check console output for tracking confirmation
   - Verify in database:
     ```r
     library(DBI)
     library(RSQLite)
     con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
     dbGetQuery(con, "SELECT * FROM ai_extractions ORDER BY extracted_at DESC LIMIT 5")
     dbDisconnect(con)
     ```

4. **Test eBay Posting Tracking:**
   - Fill out form fields (or use AI-extracted data)
   - Click "Send to eBay"
   - Check console output
   - Verify in database:
     ```r
     con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
     dbGetQuery(con, "SELECT * FROM ebay_posts ORDER BY posted_at DESC LIMIT 5")
     dbDisconnect(con)
     ```

5. **Test Statistics:**
   ```r
   stats <- get_posting_statistics()
   print(stats)
   ```

### Expected Console Output

**After AI Extraction:**
```
🎯 Extract AI button clicked for image 1
   Path: combined_session_images/postcard_001.jpg
   Model: claude
   ✅ API key found, length: 32

🔍 Starting AI extraction in later::later()
   API call complete, success: TRUE

   📄 Raw AI Response:
   ----------------------------------------------------------------
   [AI response text]
   ----------------------------------------------------------------

   ✅ Parsing successful
      Title: Vintage Postcard - Paris Eiffel Tower
      Description: Beautiful vintage postcard showing...
      Condition: good
      Price: € 5.5
   
   💾 Tracking AI extraction in database...
      ✅ AI extraction tracked with ID: 1
   
   📝 Updating form fields...
      Title updated (length: 45)
      Description updated (length: 156)
      Price updated
      Condition updated
   💾 Draft saved
   🏁 AI extraction complete
```

**After Send to eBay:**
```
🚀 Send to eBay button clicked for image 1
   Title: Vintage Postcard - Paris Eiffel Tower
   Price: € 5.5
   Condition: good
   ✅ eBay post tracked with ID: 1
```

### Troubleshooting

**Issue:** "Could not find image_id for tracking"
- **Cause:** Image path doesn't match database records
- **Fix:** Check that images are properly uploaded through the app's upload mechanism
- **Debug:** 
  ```r
  con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
  dbGetQuery(con, "SELECT image_id, upload_path FROM images ORDER BY upload_timestamp DESC LIMIT 10")
  dbDisconnect(con)
  ```

**Issue:** "Error in track_ai_extraction: ..."
- **Cause:** Database connection or parameter issue
- **Fix:** Check database file exists and is writable
- **Debug:** Run test script: `source("test_database_tracking.R")`

**Issue:** Tracking works but statistics show 0
- **Cause:** Query filtering by wrong session_id
- **Fix:** Check session$token matches database records
- **Debug:**
  ```r
  con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
  dbGetQuery(con, "SELECT DISTINCT session_id FROM images")
  dbDisconnect(con)
  ```

---

## Verification Checklist

After integration, verify:

- [ ] AI extractions tracked successfully
- [ ] Failed extractions also tracked
- [ ] eBay button creates pending post
- [ ] Console shows tracking confirmations
- [ ] Database records visible via SQL queries
- [ ] `get_posting_statistics()` returns correct counts
- [ ] No errors in console
- [ ] App functionality unchanged (tracking is transparent)
- [ ] Test script still passes

---

## Future eBay API Integration

When eBay posting API is implemented, update the tracking:

```r
# After eBay API call succeeds:
con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
dbExecute(con, "
  UPDATE ebay_posts 
  SET status = 'success',
      ebay_listing_id = ?,
      posted_at = CURRENT_TIMESTAMP
  WHERE post_id = ?
", list(ebay_response$listing_id, post_id))
dbDisconnect(con)

# Update UI state
isolate({
  rv$sent_images <- c(rv$sent_images, paths[i])
  rv$pending_images <- setdiff(rv$pending_images, paths[i])
})

showNotification(
  paste("Successfully posted to eBay! Listing ID:", ebay_response$listing_id),
  type = "message",
  duration = 5
)
```

```r
# After eBay API call fails:
con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
dbExecute(con, "
  UPDATE ebay_posts 
  SET status = 'failed',
      error_message = ?
  WHERE post_id = ?
", list(ebay_response$error, post_id))
dbDisconnect(con)

# Update UI state
isolate({
  rv$failed_images <- c(rv$failed_images, paths[i])
  rv$pending_images <- setdiff(rv$pending_images, paths[i])
})

showNotification(
  paste("Failed to post to eBay:", ebay_response$error),
  type = "error",
  duration = 10
)
```

---

## Summary

**What was added:**
- AI extraction tracking (success + failure)
- eBay posting intent tracking
- Error handling for all tracking operations

**What's next:**
- Implement actual eBay API calls
- Update post status after eBay response
- Add retry logic for failed posts
- Create analytics dashboard

**Time investment:** ~30 minutes for integration + 15 minutes for testing = **45 minutes total**

---

**Status:** Ready for integration ✅
