# TASK PRP: Simple Tracking Viewer - Last 20 Images

## Task Overview

Build a minimalist tracking interface showing the 20 most recent processed images with status indicators and click-to-view-details modal. This implements the PRP specification in `PRPs/PRP_SIMPLE_TRACKING_VIEWER.md`.

**Status:** Ready for implementation
**Priority:** Medium (enhances user visibility into processing history)
**Estimated Effort:** 1-2 hours
**Difficulty:** Easy (no database changes, simple query and UI)

---

## Context

### Documentation References

```yaml
context:
  docs:
    - file: PRPs/PRP_SIMPLE_TRACKING_VIEWER.md
      focus: Complete feature specification, database schema, implementation strategy

    - file: .serena/memories/three_layer_architecture_complete_20251013.md
      focus: 3-layer database architecture (postal_cards, card_processing, session_activity)

    - file: R/tracking_database.R
      focus: Existing database functions and schema

    - file: R/mod_delcampe_export.R
      lines: 28-509
      focus: WORKING PATTERN for bslib modals with conditional content sections

    - file: CLAUDE.md
      focus: |
        - Use bslib over custom JavaScript (module namespace issues)
        - Keep files under 400 lines
        - Follow Golem conventions

  patterns:
    - file: R/mod_delcampe_export.R
      lines: 67-107
      copy: |
        # Status badge creation pattern
        get_status_badge <- function(status) {
          badge_data <- switch(status,
            "ready" = list(label = "Ready", color = "#1971c2", bg = "#e7f5ff"),
            "sent" = list(label = "Sent", color = "#2f9e44", bg = "#d3f9d8"),
            # ... more statuses
          )
          span(style = paste0("background: ", badge_data$bg, "; color: ", badge_data$color),
               badge_data$label)
        }

    - file: R/mod_delcampe_export.R
      lines: 386-507
      copy: |
        # Modal with conditional sections pattern
        showModal(modalDialog(
          title = sprintf("Card #%d Details", row$card_id),
          tagList(
            h4("Image Information"),
            tags$table(...),

            # Conditional section (only if processed)
            if (!is.na(row$last_processed)) {
              tagList(hr(), h4("Processing Details"), ...)
            },

            # Conditional section (only if AI extracted)
            if (!is.na(row$ai_title)) {
              tagList(hr(), h4("AI Extraction"), ...)
            }
          ),
          size = "l",
          easyClose = TRUE,
          footer = modalButton("Close")
        ))

  gotchas:
    - issue: "DT::dataTable complexity not needed"
      fix: "Use simple bslib cards with renderUI for lightweight display"
      reference: PRPs/PRP_SIMPLE_TRACKING_VIEWER.md lines 254-370

    - issue: "Existing mod_tracking_viewer.R is over-engineered"
      fix: "Replace entire file with simpler version (no filters, no export, no DT)"
      reference: PRPs/PRP_SIMPLE_TRACKING_VIEWER.md lines 99-101

    - issue: "Crop images use inst/app/ paths in database"
      fix: "Convert to web paths with gsub('^inst/app/', '', path)"
      reference: PRPs/PRP_SIMPLE_TRACKING_VIEWER.md lines 426-432

    - issue: "JSON fields need parsing"
      fix: "Use jsonlite::fromJSON() with error handling"
      reference: PRPs/PRP_SIMPLE_TRACKING_VIEWER.md lines 388-391
```

---

## Problem Analysis

### Current State

**What Exists:**
1. ✅ 3-layer database architecture (`postal_cards`, `card_processing`, `ebay_listings`)
2. ✅ Database query functions in `R/tracking_database.R`
3. ✅ Existing `mod_tracking_viewer.R` module (but over-engineered)
4. ✅ Complete tracking data for processed images

**What's Needed:**
1. ❌ Simple query function to get last 20 images with JOIN
2. ❌ Lightweight UI showing image list (no DT::dataTable)
3. ❌ Click handler to open detail modal
4. ❌ Modal builder with conditional sections
5. ❌ Helper functions for relative time and status badges

### Why Simplify?

**Current module problems:**
- Uses DT::dataTable (overkill for 20 rows)
- Has filters and export (YAGNI)
- Shows session data, not image data
- 318 lines for basic display

**New approach benefits:**
- Direct image focus (not sessions)
- Fast query (< 100ms)
- Simple bslib cards
- ~250 lines total
- No learning curve

---

## Technical Architecture

### Database Query

```sql
-- Single query with LEFT JOINs (already in 3-layer architecture)
SELECT
  pc.card_id, pc.original_filename, pc.image_type,
  pc.file_size, pc.width, pc.height, pc.first_seen,
  cp.crop_paths, cp.grid_rows, cp.grid_cols,
  cp.ai_title, cp.ai_description, cp.ai_condition, cp.ai_price, cp.ai_model,
  cp.last_processed,
  el.status as ebay_status, el.listing_url, el.error_message
FROM postal_cards pc
LEFT JOIN card_processing cp ON pc.card_id = cp.card_id
LEFT JOIN ebay_listings el ON pc.card_id = el.card_id
ORDER BY pc.first_seen DESC
LIMIT 20
```

**Performance:** ~5ms (indexed JOIN, LIMIT 20)

### Module Structure

```
mod_tracking_viewer_ui()
  └── bslib::card
      └── uiOutput("image_list")

mod_tracking_viewer_server()
  ├── recent_images <- reactive({ get_recent_images(20) })
  ├── output$image_list <- renderUI({ ... })
  ├── observe({ lapply(images, create_button_observer) })
  └── show_detail_modal <- function(row) { ... }
```

### Helper Functions (R/tracking_database.R)

```r
get_recent_images(limit = 20)           # Query with JOINs
format_relative_time(timestamp)         # "2 hours ago"
get_image_status(row)                   # "Uploaded" / "Processed" / "AI Extracted" / "eBay Posted"
```

---

## Implementation Tasks

### TASK 1: Add Helper Functions to R/tracking_database.R

**FILE:** R/tracking_database.R (append at end)

**OBJECTIVE:** Add 3 utility functions for tracking viewer

**LOCATION:** After existing functions (~line 500+)

**CODE TO ADD:**

```r
#' Get recent images with processing status
#'
#' @description Retrieves the N most recent images with their processing data
#'
#' @param limit Number of recent images (default 20)
#' @return Data frame with image data from postal_cards, card_processing, ebay_listings
#' @export
get_recent_images <- function(limit = 20) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    result <- DBI::dbGetQuery(con, "
      SELECT
        pc.card_id,
        pc.original_filename,
        pc.image_type,
        pc.file_size,
        pc.width,
        pc.height,
        pc.first_seen,
        pc.last_updated,
        cp.crop_paths,
        cp.grid_rows,
        cp.grid_cols,
        cp.ai_title,
        cp.ai_description,
        cp.ai_condition,
        cp.ai_price,
        cp.ai_model,
        cp.last_processed,
        el.status as ebay_status,
        el.listing_url,
        el.error_message
      FROM postal_cards pc
      LEFT JOIN card_processing cp ON pc.card_id = cp.card_id
      LEFT JOIN ebay_listings el ON pc.card_id = el.card_id
      ORDER BY pc.first_seen DESC
      LIMIT ?
    ", list(as.integer(limit)))

    return(result)

  }, error = function(e) {
    message("Error getting recent images: ", e$message)
    return(data.frame())
  })
}

#' Format relative time (e.g., "2 hours ago")
#'
#' @description Converts timestamp to human-readable relative time
#'
#' @param timestamp POSIXct timestamp
#' @return Character string like "2 hours ago", "1 day ago"
#' @export
format_relative_time <- function(timestamp) {
  if (is.null(timestamp) || is.na(timestamp)) return("Unknown")

  tryCatch({
    diff_secs <- as.numeric(difftime(Sys.time(), as.POSIXct(timestamp), units = "secs"))

    if (diff_secs < 60) return("Just now")
    if (diff_secs < 3600) return(paste(floor(diff_secs / 60), "minutes ago"))
    if (diff_secs < 86400) return(paste(floor(diff_secs / 3600), "hours ago"))
    if (diff_secs < 604800) return(paste(floor(diff_secs / 86400), "days ago"))
    if (diff_secs < 2592000) return(paste(floor(diff_secs / 604800), "weeks ago"))
    return(paste(floor(diff_secs / 2592000), "months ago"))

  }, error = function(e) {
    return(as.character(timestamp))
  })
}

#' Get status for an image
#'
#' @description Determines display status based on processing state
#'
#' @param row Data frame row with image data
#' @return Character status: "Uploaded", "Processed", "AI Extracted", "eBay Posted"
#' @export
get_image_status <- function(row) {
  # Check eBay first (highest priority)
  if (!is.na(row$ebay_status) && row$ebay_status != "") {
    return("eBay Posted")
  }
  # Then AI extraction
  else if (!is.na(row$ai_title) && !is.null(row$ai_title) && nchar(as.character(row$ai_title)) > 0) {
    return("AI Extracted")
  }
  # Then basic processing
  else if (!is.na(row$last_processed) && !is.null(row$last_processed)) {
    return("Processed")
  }
  # Default: just uploaded
  else {
    return("Uploaded")
  }
}
```

**VALIDATE:**
```r
# In R console:
source("R/tracking_database.R")

# Test get_recent_images
test_data <- get_recent_images(5)
nrow(test_data)  # Should be > 0 if database has images

# Test format_relative_time
format_relative_time(Sys.time() - 3600)  # Should return "1 hours ago"

# Test get_image_status
if (nrow(test_data) > 0) {
  get_image_status(test_data[1,])  # Should return status string
}
```

**IF_FAIL:**
- Check database path: `file.exists("inst/app/data/tracking.sqlite")`
- Verify tables exist: `DBI::dbListTables(con)`
- Check SQL syntax: copy query to DB browser

**ROLLBACK:**
```bash
# Remove the 3 functions added to R/tracking_database.R
git diff R/tracking_database.R
git checkout R/tracking_database.R
```

---

### TASK 2: Replace R/mod_tracking_viewer.R with Simple Version

**FILE:** R/mod_tracking_viewer.R (REPLACE ENTIRE FILE)

**OBJECTIVE:** Create simple tracking viewer with image list and modal

**BACKUP FIRST:**
```bash
cp R/mod_tracking_viewer.R ~/Documents/R_Projects/Delcampe_BACKUP/mod_tracking_viewer.R.backup_$(date +%Y%m%d_%H%M%S)
```

**NEW CONTENT (246 lines - under 400 limit):**

```r
#' Simple Tracking Viewer UI
#'
#' @description Shows last 20 processed images with status and details on demand
#'
#' @param id Module ID
#' @export
#' @importFrom shiny NS tagList
mod_tracking_viewer_ui <- function(id) {
  ns <- NS(id)

  tagList(
    shinyjs::useShinyjs(),

    bslib::card(
      header = bslib::card_header(
        "Recent Images (Last 20)",
        class = "bg-primary text-white"
      ),
      div(
        style = "padding: 20px;",
        uiOutput(ns("image_list"))
      )
    )
  )
}

#' Simple Tracking Viewer Server
#'
#' @description Server logic for tracking viewer
#'
#' @param id Module ID
#' @export
mod_tracking_viewer_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive: fetch recent images
    recent_images <- reactive({
      get_recent_images(20)
    })

    # Render image list
    output$image_list <- renderUI({
      data <- recent_images()

      if (is.null(data) || nrow(data) == 0) {
        return(div(
          style = "text-align: center; padding: 40px; color: #868e96;",
          icon("image", style = "font-size: 48px; margin-bottom: 16px;"),
          h4("No images yet"),
          p("Upload and process some images to see them here.")
        ))
      }

      # Create card for each image
      cards <- lapply(1:nrow(data), function(i) {
        row <- data[i,]
        status <- get_image_status(row)

        # Status badge styling
        badge_class <- switch(status,
          "eBay Posted" = "bg-success",
          "AI Extracted" = "bg-info",
          "Processed" = "bg-primary",
          "Uploaded" = "bg-secondary",
          "bg-light"
        )

        bslib::card(
          style = "margin-bottom: 15px;",
          div(
            style = "display: flex; align-items: center; gap: 15px; padding: 10px;",

            # Thumbnail placeholder
            div(
              style = "flex-shrink: 0; width: 60px; height: 60px; background: #e9ecef; border-radius: 4px; display: flex; align-items: center; justify-content: center; font-weight: bold; color: #6c757d;",
              toupper(substr(row$image_type, 1, 1))
            ),

            # Info section
            div(
              style = "flex: 1;",
              div(
                style = "font-weight: 600; margin-bottom: 5px;",
                substr(row$original_filename, 1, 40),
                if (nchar(row$original_filename) > 40) "..." else ""
              ),
              div(
                style = "font-size: 14px; color: #6c757d;",
                format_relative_time(row$first_seen),
                " • ",
                tools::toTitleCase(row$image_type)
              )
            ),

            # Status and button
            div(
              style = "flex-shrink: 0; display: flex; align-items: center; gap: 10px;",
              span(
                class = paste("badge", badge_class),
                status
              ),
              actionButton(
                inputId = ns(paste0("view_", row$card_id)),
                label = "View Details",
                class = "btn-sm btn-outline-primary"
              )
            )
          )
        )
      })

      tagList(cards)
    })

    # Handle view details buttons
    observe({
      data <- recent_images()
      if (is.null(data) || nrow(data) == 0) return()

      lapply(1:nrow(data), function(i) {
        card_id <- data$card_id[i]
        observeEvent(input[[paste0("view_", card_id)]], {
          show_detail_modal(data[i,])
        }, ignoreInit = TRUE)
      })
    })

    # Modal builder
    show_detail_modal <- function(row) {
      # Parse JSON fields
      crop_paths <- tryCatch(
        jsonlite::fromJSON(row$crop_paths),
        error = function(e) NULL
      )

      # Build modal content
      content <- tagList(
        # Image Information
        h4("Image Information"),
        tags$table(
          class = "table table-sm",
          tags$tr(tags$th("Filename:"), tags$td(row$original_filename)),
          tags$tr(tags$th("Type:"), tags$td(tools::toTitleCase(row$image_type))),
          tags$tr(tags$th("Dimensions:"), tags$td(sprintf("%d × %d px", row$width, row$height))),
          tags$tr(tags$th("File Size:"), tags$td(sprintf("%.1f KB", row$file_size / 1024))),
          tags$tr(tags$th("Uploaded:"), tags$td(format(as.POSIXct(row$first_seen), "%Y-%m-%d %H:%M:%S")))
        ),

        # Processing section (if processed)
        if (!is.na(row$last_processed) && !is.null(row$last_processed)) {
          tagList(
            hr(),
            h4("Processing Details"),
            tags$table(
              class = "table table-sm",
              tags$tr(tags$th("Grid Layout:"), tags$td(sprintf("%d × %d", row$grid_rows, row$grid_cols))),
              tags$tr(tags$th("Crops Generated:"), tags$td(length(crop_paths))),
              tags$tr(tags$th("Processed:"), tags$td(format(as.POSIXct(row$last_processed), "%Y-%m-%d %H:%M:%S")))
            ),

            # Crop thumbnails
            if (!is.null(crop_paths) && length(crop_paths) > 0) {
              div(
                style = "margin-top: 15px;",
                h5("Generated Crops:"),
                div(
                  style = "display: grid; grid-template-columns: repeat(auto-fill, minmax(100px, 1fr)); gap: 10px; margin-top: 10px;",
                  lapply(crop_paths, function(path) {
                    web_path <- gsub("^inst/app/", "", path)
                    div(
                      tags$img(
                        src = web_path,
                        style = "width: 100%; height: 80px; object-fit: cover; border: 1px solid #dee2e6; border-radius: 4px;"
                      )
                    )
                  })
                )
              )
            }
          )
        },

        # AI section (if extracted)
        if (!is.na(row$ai_title) && !is.null(row$ai_title) && nchar(as.character(row$ai_title)) > 0) {
          tagList(
            hr(),
            h4("AI Extraction"),
            tags$table(
              class = "table table-sm",
              tags$tr(tags$th("Title:"), tags$td(row$ai_title)),
              tags$tr(tags$th("Condition:"), tags$td(row$ai_condition)),
              tags$tr(tags$th("Price:"), tags$td(sprintf("€%.2f", row$ai_price))),
              tags$tr(tags$th("Model:"), tags$td(row$ai_model))
            ),
            div(
              style = "margin-top: 10px;",
              h5("Description:"),
              div(
                style = "padding: 10px; background: #f8f9fa; border-radius: 4px; border: 1px solid #dee2e6;",
                p(row$ai_description, style = "margin: 0;")
              )
            )
          )
        },

        # eBay section (if posted)
        if (!is.na(row$ebay_status) && !is.null(row$ebay_status) && row$ebay_status != "") {
          tagList(
            hr(),
            h4("eBay Listing"),
            tags$table(
              class = "table table-sm",
              tags$tr(
                tags$th("Status:"),
                tags$td(
                  span(
                    class = paste0("badge bg-", if(row$ebay_status == "listed") "success" else "warning"),
                    tools::toTitleCase(row$ebay_status)
                  )
                )
              ),
              if (!is.na(row$listing_url) && !is.null(row$listing_url)) {
                tags$tr(
                  tags$th("Listing:"),
                  tags$td(tags$a(href = row$listing_url, target = "_blank", "View on eBay"))
                )
              },
              if (!is.na(row$error_message) && !is.null(row$error_message)) {
                tags$tr(
                  tags$th("Error:"),
                  tags$td(div(class = "alert alert-danger", style = "margin: 5px 0;", row$error_message))
                )
              }
            )
          )
        }
      )

      # Show modal
      showModal(
        modalDialog(
          title = sprintf("Card #%d Details", row$card_id),
          content,
          size = "l",
          easyClose = TRUE,
          footer = modalButton("Close")
        )
      )
    }
  })
}
```

**VALIDATE:**
```r
# Check syntax
devtools::load_all()
# Should load without errors

# Check module exists
exists("mod_tracking_viewer_ui")  # TRUE
exists("mod_tracking_viewer_server")  # TRUE

# Test in app
golem::run_dev()
# Navigate to Tracking tab
# Should see list of images or "No images yet"
```

**IF_FAIL:**
- Syntax error: Check for missing braces, commas
- Module not found: Check file is in R/ directory
- Empty display: Check `get_recent_images()` returns data
- Modal error: Check `showModal()` syntax and namespace

**ROLLBACK:**
```bash
# Restore from backup
cp ~/Documents/R_Projects/Delcampe_BACKUP/mod_tracking_viewer.R.backup_* R/mod_tracking_viewer.R
```

---

### TASK 3: Manual Testing - Complete Workflow

**OBJECTIVE:** Test tracking viewer end-to-end

**SCENARIO 1: Empty Database**

**TEST STEPS:**
1. Start app: `golem::run_dev()`
2. Navigate to "Tracking" tab
3. **EXPECTED:** See "No images yet" message with icon
4. **VERIFY:** Message is centered and friendly

**PASS CRITERIA:**
- [ ] Empty state shows centered message
- [ ] Icon displays correctly
- [ ] No errors in console

---

**SCENARIO 2: Database with Images**

**SETUP:**
```r
# Process some images first
# 1. Upload face image → extract
# 2. Upload verso image → extract
# 3. Combine and process
```

**TEST STEPS:**
1. Navigate to "Tracking" tab
2. **EXPECTED:** See list of images (up to 20)
3. **VERIFY LIST:**
   - [ ] Images in reverse chronological order (newest first)
   - [ ] Each image shows:
     - [ ] Type indicator (F/V/C letter)
     - [ ] Filename (truncated at 40 chars)
     - [ ] Relative time ("2 hours ago")
     - [ ] Image type label ("Face", "Verso", "Combined")
     - [ ] Status badge (correct color)
     - [ ] "View Details" button

**PASS CRITERIA:**
- [ ] All list items render correctly
- [ ] Status badges show correct color:
  - `bg-secondary` (gray) for "Uploaded"
  - `bg-primary` (blue) for "Processed"
  - `bg-info` (cyan) for "AI Extracted"
  - `bg-success` (green) for "eBay Posted"
- [ ] Filenames truncate properly
- [ ] Times are accurate

---

**SCENARIO 3: View Details Modal**

**TEST STEPS:**
1. Click "View Details" on uploaded-only image
2. **EXPECTED:** Modal opens showing:
   - [ ] Title: "Card #X Details"
   - [ ] Image Information section
   - [ ] No Processing section (not processed yet)
   - [ ] No AI section
   - [ ] No eBay section
   - [ ] Close button works

3. Click "View Details" on processed image with crops
4. **EXPECTED:** Modal shows:
   - [ ] Image Information section
   - [ ] Processing Details section
   - [ ] Grid layout (e.g., "2 × 3")
   - [ ] Crop count matches actual crops
   - [ ] Crop thumbnails grid displays
   - [ ] Images load correctly

5. Click "View Details" on AI-extracted image
6. **EXPECTED:** Modal shows:
   - [ ] Image Information
   - [ ] Processing Details
   - [ ] AI Extraction section
   - [ ] Title field populated
   - [ ] Description field populated
   - [ ] Condition field populated
   - [ ] Price field formatted (€X.XX)
   - [ ] Model name displayed

7. Click "View Details" on eBay-posted image (if available)
8. **EXPECTED:** Modal shows:
   - [ ] All previous sections
   - [ ] eBay Listing section
   - [ ] Status badge (color-coded)
   - [ ] Clickable listing URL (opens in new tab)
   - [ ] Error message (if present)

**PASS CRITERIA:**
- [ ] Modal opens in < 500ms
- [ ] All sections render conditionally
- [ ] Data is accurate
- [ ] Images display correctly
- [ ] Links work
- [ ] Close button works
- [ ] No console errors

---

**SCENARIO 4: Edge Cases**

**TEST: Partial AI Data**
```r
# Manually remove some AI fields
library(DBI)
con <- dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
dbExecute(con, "UPDATE card_processing SET ai_description = NULL WHERE card_id = 1")
dbDisconnect(con)

# Refresh tracking tab
# Click "View Details" on card #1
# EXPECTED: Title shows, description missing, no error
```

**TEST: JSON Parsing Error**
```r
# Corrupt crop_paths JSON
dbExecute(con, "UPDATE card_processing SET crop_paths = 'invalid json' WHERE card_id = 1")

# EXPECTED: No crop thumbnails, but no crash
```

**TEST: Very Long Filename**
```r
# Image with 100+ character filename
# EXPECTED: Truncates at 40 chars with "..."
```

**PASS CRITERIA:**
- [ ] Handles NULL values gracefully
- [ ] Invalid JSON doesn't crash modal
- [ ] Long filenames truncate properly
- [ ] No uncaught errors

---

**SCENARIO 5: Performance**

**TEST:**
1. Check query time:
```r
system.time(get_recent_images(20))
# Should be < 0.1 seconds
```

2. Check UI render time:
```r
# In browser dev tools → Network tab
# Navigate to Tracking tab
# Check total load time
# Should be < 1 second
```

3. Check modal open time:
```r
# Click "View Details"
# Observe time to modal display
# Should be < 500ms
```

**PASS CRITERIA:**
- [ ] Query completes in < 100ms
- [ ] List renders in < 1 second
- [ ] Modal opens in < 500ms
- [ ] No lag or freezing

---

### TASK 4: Documentation and Cleanup

**OBJECTIVE:** Update documentation and create memory

**FILE:** .serena/memories/simple_tracking_viewer_complete_YYYYMMDD.md

**CONTENT:**

```markdown
# Simple Tracking Viewer Implementation - COMPLETE

**Date:** [Current Date]
**Status:** ✅ Implemented and Tested
**Files Modified:** R/tracking_database.R, R/mod_tracking_viewer.R

## What Was Built

A minimalist tracking interface showing the 20 most recent processed images with:
- Status badges (Uploaded/Processed/AI Extracted/eBay Posted)
- Relative timestamps ("2 hours ago")
- Click-to-view details modal with conditional sections

## Implementation Summary

### Helper Functions Added (R/tracking_database.R)

**get_recent_images(limit = 20)**
- Single query with LEFT JOINs across 3 tables
- Returns complete image data with processing and eBay status
- Performance: ~5ms for 20 rows

**format_relative_time(timestamp)**
- Converts POSIXct to human-readable format
- Handles edge cases (NULL, NA)

**get_image_status(row)**
- Determines status from data state
- Priority: eBay > AI > Processed > Uploaded

### Module Replacement (R/mod_tracking_viewer.R)

**Replaced:**
- Old: 318 lines with DT::dataTable, filters, export
- New: 246 lines with simple bslib cards

**UI Pattern:**
- Single bslib::card with header
- renderUI for image list
- Empty state for no images

**Server Pattern:**
- `recent_images()` reactive
- `renderUI()` for card list
- `observe()` for button handlers
- `show_detail_modal()` for details

### Modal Pattern

**Conditional Sections:**
```r
# Always show
h4("Image Information")
tags$table(...)

# Show if processed
if (!is.na(row$last_processed)) {
  tagList(hr(), h4("Processing Details"), ...)
}

# Show if AI extracted
if (!is.na(row$ai_title)) {
  tagList(hr(), h4("AI Extraction"), ...)
}

# Show if posted to eBay
if (!is.na(row$ebay_status)) {
  tagList(hr(), h4("eBay Listing"), ...)
}
```

## Testing Results

### Scenarios Tested
- ✅ Empty database (friendly message)
- ✅ List of 1-20 images
- ✅ Status badges (all 4 states)
- ✅ Relative timestamps
- ✅ Modal with basic info
- ✅ Modal with processing data
- ✅ Modal with AI data
- ✅ Modal with eBay data
- ✅ Partial data (NULL fields)
- ✅ JSON parsing errors
- ✅ Long filenames

### Performance
- Query time: ~5ms
- List render: <1 second
- Modal open: <500ms

## Key Decisions

**Why Replace vs Extend:**
- Existing module was over-engineered for requirements
- Simpler to replace than refactor
- New module is 72 lines shorter

**Why No DT::dataTable:**
- Overkill for 20 rows
- Slower to render
- More dependencies
- Harder to style

**Why bslib Cards:**
- Native Shiny/bslib (no custom JS)
- Handles module namespaces correctly
- Easy to style
- Mobile-friendly

**Why Conditional Sections:**
- Follows working pattern from mod_delcampe_export.R
- Clean and readable
- No JavaScript required
- Easy to extend

## Lessons Learned

1. **YAGNI Principle:** Don't build features on speculation
   - No need for filters (only 20 rows)
   - No need for export (users can screenshot)
   - No need for refresh button (auto-updates on navigation)

2. **bslib > Custom JS:** Always check bslib first
   - Avoids module namespace issues
   - Better maintainability
   - Consistent styling

3. **Pattern Reuse:** Copy working patterns
   - Modal structure from mod_delcampe_export.R worked perfectly
   - Status badge pattern easily adapted
   - Saved hours of debugging

4. **Simplicity Wins:**
   - Simpler code = fewer bugs
   - Easier to understand
   - Faster to implement

## Future Enhancements (If Needed)

- Add pagination if > 20 images needed
- Add search/filter (only if user requests)
- Add "Mark as Favorite" feature
- Add export to CSV (only if user requests)
- Add delete functionality (with confirmation)

## References

- PRP: PRPs/PRP_SIMPLE_TRACKING_VIEWER.md
- Pattern: R/mod_delcampe_export.R (modal structure)
- Architecture: .serena/memories/three_layer_architecture_complete_20251013.md
```

**SAVE AS:** `.serena/memories/simple_tracking_viewer_complete_YYYYMMDD.md`

**UPDATE:** `.serena/memories/INDEX.md` (add entry for new memory)

**VALIDATE:**
```bash
# Check memory file created
ls -la .serena/memories/simple_tracking_viewer_complete_*.md

# Verify content
head -20 .serena/memories/simple_tracking_viewer_complete_*.md
```

---

## Validation Strategy

### Level 1: Code Loading

```r
# R console
devtools::load_all()
# Expected: No errors

# Check functions exist
exists("get_recent_images")  # TRUE
exists("format_relative_time")  # TRUE
exists("get_image_status")  # TRUE
exists("mod_tracking_viewer_ui")  # TRUE
exists("mod_tracking_viewer_server")  # TRUE
```

**PASS CRITERIA:**
- ✅ All functions load
- ✅ No syntax errors
- ✅ No namespace conflicts

---

### Level 2: Unit Testing

```r
# Test helper functions
test_that("get_recent_images returns data frame", {
  result <- get_recent_images(5)
  expect_true(is.data.frame(result))
  expect_lte(nrow(result), 5)
})

test_that("format_relative_time handles edge cases", {
  expect_equal(format_relative_time(NULL), "Unknown")
  expect_equal(format_relative_time(NA), "Unknown")
  expect_match(format_relative_time(Sys.time() - 3600), "hour")
})

test_that("get_image_status returns valid status", {
  row <- data.frame(
    ebay_status = NA,
    ai_title = "Test",
    last_processed = Sys.time()
  )
  expect_equal(get_image_status(row), "AI Extracted")
})
```

**PASS CRITERIA:**
- ✅ All tests pass
- ✅ Edge cases handled
- ✅ No errors

---

### Level 3: Integration Testing

**Manual test from TASK 3**

**PASS CRITERIA:**
- ✅ All scenarios pass
- ✅ No console errors
- ✅ Performance meets targets

---

### Level 4: User Acceptance

**Ask User:**
1. Does the tracking viewer show useful information?
2. Is the modal detailed enough?
3. Are 20 images sufficient or need more?
4. Any missing information?

**PASS CRITERIA:**
- ✅ User confirms functionality meets needs
- ✅ No critical missing features
- ✅ Performance acceptable

---

## Files Modified Summary

### R/tracking_database.R
**Action:** APPEND 3 functions at end
**Lines Added:** ~80
**Functions:**
- `get_recent_images(limit = 20)`
- `format_relative_time(timestamp)`
- `get_image_status(row)`

**Validation:**
```bash
grep -c "get_recent_images" R/tracking_database.R  # Should be 2+ (definition + export)
```

---

### R/mod_tracking_viewer.R
**Action:** REPLACE entire file
**Lines:** 246 (was 318)
**Reduction:** 72 lines removed
**Functions:**
- `mod_tracking_viewer_ui(id)`
- `mod_tracking_viewer_server(id)`

**Validation:**
```bash
wc -l R/mod_tracking_viewer.R  # Should be ~246
grep -c "DT::dataTable" R/mod_tracking_viewer.R  # Should be 0 (removed)
```

---

## Common Issues & Solutions

### Issue: No images showing

**Debug:**
```r
# Check database
library(DBI)
con <- dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
dbGetQuery(con, "SELECT COUNT(*) FROM postal_cards")
dbDisconnect(con)
```

**Fix:** Process some images first

---

### Issue: Modal not opening

**Debug:**
```r
# Check console for errors
# Look for namespace issues
# Verify button ID pattern: paste0("view_", card_id)
```

**Fix:** Ensure `observeEvent` uses `ns()` correctly

---

### Issue: Crop images not displaying

**Debug:**
```r
# Check path conversion
crop_paths <- jsonlite::fromJSON(row$crop_paths)
web_path <- gsub("^inst/app/", "", crop_paths[1])
print(web_path)  # Should NOT start with "inst/app/"
```

**Fix:** Verify `gsub()` pattern in modal builder

---

### Issue: JSON parsing error

**Debug:**
```r
# Check database content
dbGetQuery(con, "SELECT crop_paths FROM card_processing LIMIT 1")
# Should be valid JSON array: ["path1", "path2"]
```

**Fix:** Wrapped in `tryCatch()` to handle gracefully

---

## Performance Considerations

### Query Optimization

**Current:** Single query with 2 LEFT JOINs, LIMIT 20
**Indexes:** `card_id` is indexed (PRIMARY KEY)
**Performance:** ~5ms

**No optimization needed** - query is already fast

---

### UI Rendering

**Current:** `renderUI()` with `lapply()` over 20 rows
**Performance:** <1 second

**No optimization needed** - acceptable for user

---

### Modal Display

**Current:** Build tagList on demand
**Performance:** <500ms

**No optimization needed** - user doesn't notice delay

---

## Security Checklist

- ✅ No SQL injection (uses parameterized query: `list(as.integer(limit))`)
- ✅ No XSS (Shiny escapes all text)
- ✅ No path traversal (uses database paths, not user input)
- ✅ No sensitive data exposure (shows user's own data only)

---

## Rollback Plan

### Quick Rollback

```bash
# Restore backup
cp ~/Documents/R_Projects/Delcampe_BACKUP/mod_tracking_viewer.R.backup_* R/mod_tracking_viewer.R

# Remove helper functions from tracking_database.R
# (manually delete last ~80 lines)

# Reload
devtools::load_all()
```

---

### Full Rollback

```bash
# Stash changes
git stash save "WIP: Simple tracking viewer implementation"

# Or hard reset
git reset --hard HEAD

# Verify
git status
```

---

## Success Criteria Checklist

**Code Quality:**
- [ ] No syntax errors
- [ ] Follows Golem conventions
- [ ] Under 400 lines per file
- [ ] Uses bslib (no custom JS)
- [ ] Proper error handling

**Functionality:**
- [ ] Shows last 20 images
- [ ] Status badges correct
- [ ] Relative times accurate
- [ ] Modal shows complete data
- [ ] Conditional sections work
- [ ] Crop thumbnails display

**User Experience:**
- [ ] Empty state is friendly
- [ ] List is easy to scan
- [ ] Modal is informative
- [ ] No learning curve
- [ ] Fast and responsive

**Testing:**
- [ ] All scenarios pass
- [ ] Edge cases handled
- [ ] No console errors
- [ ] Performance meets targets

**Documentation:**
- [ ] Memory file created
- [ ] INDEX.md updated
- [ ] PRP marked complete

---

## Estimated Effort

| Task | Estimated | Actual | Notes |
|------|-----------|--------|-------|
| Task 1: Helper functions | 15 min | | Simple utilities |
| Task 2: Module replacement | 45 min | | Copy/adapt patterns |
| Task 3: Testing | 30 min | | Manual scenarios |
| Task 4: Documentation | 15 min | | Memory file |
| **Total** | **~2 hours** | | |

---

## Next Steps

1. **Implement Tasks 1-2** (code changes)
2. **Run Task 3** (manual testing)
3. **Complete Task 4** (documentation)
4. **Get user feedback**
5. **Mark PRP as complete**

---

## End of Task PRP

**Status:** Ready for implementation
**Last Updated:** 2025-10-16
**Created By:** Claude (Task Analysis Agent)
**Ready for:** User approval and execution
