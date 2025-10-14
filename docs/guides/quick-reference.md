# Quick Reference: Database Tracking Functions

## New Functions Cheat Sheet

### Track AI Extraction Success
```r
extraction_id <- track_ai_extraction(
  image_id = 123,
  model = "claude-sonnet-4-5-20250929",  # or "gpt-4o"
  title = "Vintage Postcard",
  description = "Beautiful vintage postcard...",
  condition = "good",                     # excellent/good/fair/poor/used
  recommended_price = 5.50,               # Euros
  success = TRUE
)
```

### Track AI Extraction Failure
```r
track_ai_extraction(
  image_id = 123,
  model = "claude-sonnet-4-5-20250929",
  success = FALSE,
  error_message = "API rate limit exceeded"
)
```

### Track eBay Post (Pending)
```r
post_id <- track_ebay_post(
  image_id = 123,
  title = "Vintage Postcard",
  description = "Detailed description...",
  price = 5.50,
  condition = "good",
  status = "pending"
)
```

### Track eBay Post (Success)
```r
track_ebay_post(
  image_id = 123,
  title = "Vintage Postcard",
  description = "Detailed description...",
  price = 5.50,
  condition = "good",
  ebay_listing_id = "EBAY123456789",
  status = "success"
)
```

### Track eBay Post (Failed)
```r
track_ebay_post(
  image_id = 123,
  title = "Vintage Postcard",
  description = "Detailed description...",
  price = 5.50,
  condition = "good",
  status = "failed",
  error_message = "Authentication failed"
)
```

### Find Image ID from Path
```r
image_id <- get_image_by_path(
  file_path = "combined_session_images/postcard_001.jpg",
  session_id = session$token  # optional filter
)
```

### Get Extraction History
```r
history <- get_ai_extraction_history(image_id = 123)
# Returns data.frame with columns:
#   extraction_id, model, title, description, condition,
#   recommended_price, extracted_at, success, error_message
```

### Get Statistics
```r
# Overall stats
stats <- get_posting_statistics()

# Session-specific stats
stats <- get_posting_statistics(session_id = "session_123")

# Access results:
stats$ebay_posts$total
stats$ebay_posts$successful
stats$ebay_posts$failed
stats$ebay_posts$pending
stats$ai_extractions$total
stats$ai_extractions$successful
stats$ai_extractions$failed
```

---

## Database Queries

### View Recent AI Extractions
```r
library(DBI)
library(RSQLite)

con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")

dbGetQuery(con, "
  SELECT 
    e.extraction_id,
    e.model,
    e.title,
    e.recommended_price,
    e.success,
    e.extracted_at,
    i.original_filename
  FROM ai_extractions e
  JOIN images i ON e.image_id = i.image_id
  ORDER BY e.extracted_at DESC
  LIMIT 10
")

dbDisconnect(con)
```

### View Recent eBay Posts
```r
con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")

dbGetQuery(con, "
  SELECT 
    p.post_id,
    p.title,
    p.price,
    p.status,
    p.ebay_listing_id,
    p.posted_at,
    i.original_filename
  FROM ebay_posts p
  JOIN images i ON p.image_id = i.image_id
  ORDER BY p.posted_at DESC
  LIMIT 10
")

dbDisconnect(con)
```

### Compare Model Performance
```r
con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")

dbGetQuery(con, "
  SELECT 
    model,
    COUNT(*) as total_extractions,
    SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) as successful,
    ROUND(AVG(recommended_price), 2) as avg_price,
    MIN(recommended_price) as min_price,
    MAX(recommended_price) as max_price
  FROM ai_extractions
  GROUP BY model
")

dbDisconnect(con)
```

### View Failed Operations
```r
con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")

# Failed AI extractions
dbGetQuery(con, "
  SELECT * FROM ai_extractions 
  WHERE success = 0
  ORDER BY extracted_at DESC
")

# Failed eBay posts
dbGetQuery(con, "
  SELECT * FROM ebay_posts 
  WHERE status = 'failed'
  ORDER BY posted_at DESC
")

dbDisconnect(con)
```

---

## Integration Code Snippets

### After Successful AI Extraction
```r
if (result$success) {
  parsed <- parse_enhanced_ai_response(result$content)
  
  # Track in database
  tryCatch({
    image_id <- get_image_by_path(current_path, session$token)
    if (!is.null(image_id)) {
      track_ai_extraction(
        image_id = image_id,
        model = if(selected_model == "claude") "claude-sonnet-4-5-20250929" else "gpt-4o",
        title = parsed$title,
        description = parsed$description,
        condition = parsed$condition,
        recommended_price = parsed$price,
        success = TRUE
      )
    }
  }, error = function(e) {
    cat("⚠️ Tracking failed:", e$message, "\n")
  })
}
```

### On Send to eBay Button Click
```r
observeEvent(input$send_to_ebay_1, {
  title <- input$item_title_1
  description <- input$item_description_1
  price <- input$starting_price_1
  condition <- input$condition_1
  
  tryCatch({
    image_id <- get_image_by_path(paths[1], session$token)
    if (!is.null(image_id)) {
      post_id <- track_ebay_post(
        image_id = image_id,
        title = title,
        description = description,
        price = price,
        condition = condition,
        status = "pending"
      )
    }
  }, error = function(e) {
    cat("⚠️ Tracking failed:", e$message, "\n")
  })
})
```

---

## Testing

### Run Full Test Suite
```r
source("test_database_tracking.R")
```

### Quick Database Check
```r
# Initialize database
initialize_tracking_db("inst/app/data/tracking.sqlite")

# Check tables exist
con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
dbListTables(con)  # Should include: ai_extractions, ebay_posts
dbDisconnect(con)

# Get statistics
stats <- get_posting_statistics()
print(stats)
```

---

## Troubleshooting

### "Could not find image_id"
```r
# Check what images are in database
con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
dbGetQuery(con, "
  SELECT image_id, original_filename, upload_path 
  FROM images 
  ORDER BY upload_timestamp DESC 
  LIMIT 10
")
dbDisconnect(con)
```

### "Parameter X error"
```r
# Ensure all parameters are single values
image_id <- as.integer(image_id)[1]
model <- as.character(model)[1]
title <- as.character(title)[1]
# etc.
```

### "Database locked"
```r
# Check if database connection is open
# Always use on.exit(dbDisconnect(con))
con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
on.exit(dbDisconnect(con))
# ... do work ...
```

---

## File Locations

- **Database:** `inst/app/data/tracking.sqlite`
- **Functions:** `R/tracking_database.R`
- **Tests:** `test_database_tracking.R`
- **Integration Guide:** `INTEGRATION_GUIDE.md`
- **Full Documentation:** `.serena/memories/database_extension_20251010.md`

---

## Quick Tips

✅ Always wrap tracking in `tryCatch()` - don't break app flow if tracking fails  
✅ Use `get_image_by_path()` before tracking - need image_id  
✅ Track failures too - valuable for debugging  
✅ Use `session$token` for session filtering  
✅ Check console output - tracking prints confirmation messages  
✅ Query database directly to verify - `dbGetQuery(con, "SELECT ...")`  

---

**For complete documentation, see:**
- `TASK_COMPLETION_SUMMARY.md` - Overview of what was delivered
- `INTEGRATION_GUIDE.md` - Step-by-step integration instructions
- `.serena/memories/database_extension_20251010.md` - Complete technical docs
