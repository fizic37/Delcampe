# PRP: Simple Tracking Viewer for Recent Images

name: "Simple Tracking Viewer - Last 20 Images with Modal Details"
description: |
  Build a minimalist tracking interface showing the 20 most recent processed images
  with status indicators and click-to-view-details modal. No filters, no export, 
  no statistics - just simple visibility into what's been processed.

---

## Goal

**Feature Goal**: Provide simple visibility into recently processed images

**Deliverable**: Lightweight tracking viewer showing last 20 images with status and details on demand

**Success Definition**: User can quickly see what they've uploaded recently, check processing status, and view details with one click

## User Persona

**Target User**: You - processing postcards for eBay listing

**Use Case**: Quick check on recent processing activity

**User Journey**: 
1. User uploads and processes several postcards
2. User navigates to Tracking tab
3. User sees list of last 20 images with status badges
4. User clicks "View Details" to see crops, AI data, eBay status
5. User closes modal and continues working

**Pain Points Addressed**: 
- ✅ "Did I already process this image?"
- ✅ "What did the AI extract?"
- ✅ "Is it posted to eBay yet?"
- ✅ Quick visual confirmation of recent work

## Why

- **Simplicity**: Just what you need, nothing more
- **Speed**: Single query, fast load
- **Usability**: No learning curve - just a list
- **Maintenance**: Minimal code to maintain

## What

### Simple Image List
Chronological list of last 20 images showing:
- Thumbnail placeholder (type indicator)
- Filename (truncated)
- Upload timestamp (relative: "2 hours ago")
- Status badge (color-coded: Uploaded → Processed → AI → eBay)
- "View Details" button

### Detail Modal (on click)
Shows complete information:
- **Image Info**: filename, size, dimensions, upload time
- **Processing** (if done): grid layout, crop count, extraction directory
- **Crop Thumbnails** (if exist): grid of generated crops
- **AI Data** (if extracted): title, description, condition, price, model
- **eBay Status** (if posted): listing URL, status, errors

### Success Criteria

UI:
- [ ] List shows 20 most recent images
- [ ] Status badges are color-coded and clear
- [ ] Relative timestamps ("2 hours ago", "1 day ago")
- [ ] Modal opens on button click
- [ ] Modal shows all available data

Functionality:
- [ ] Loads in < 1 second (simple query)
- [ ] Modal displays correct data for clicked card
- [ ] Status accurately reflects processing state
- [ ] Works with existing database (no changes)

Data Accuracy:
- [ ] Shows most recent first
- [ ] Crop thumbnails display correctly
- [ ] AI data matches extraction
- [ ] eBay status is current

## All Needed Context

### Documentation & References

```yaml
- file: R/tracking_database.R
  why: Database schema and existing functions
  pattern: 3-layer architecture already working
  critical: |
    - postal_cards: unique images
    - card_processing: processing results and AI data
    - ebay_listings: eBay posting status
  gotcha: Use existing tables, no schema changes needed

- file: R/mod_tracking_viewer.R
  why: Existing module to replace
  pattern: Already has basic structure
  critical: Will replace entire file with simpler version

- file: R/mod_delcampe_export.R
  why: Example of modal usage with bslib
  pattern: modalDialog with conditional sections
  gotcha: Remember to use ns() for all IDs

- file: CLAUDE.md
  why: Core principles
  critical: bslib over JavaScript, < 400 lines per file
  gotcha: Module namespace issues with custom JS

- package: bslib
  docs: https://rstudio.github.io/bslib/
  critical: card(), card_header(), modalDialog()

- package: DBI/RSQLite
  why: Database queries
  critical: Simple SELECT with LEFT JOINs
```

### Current Database Schema

```sql
-- Already exists, no changes needed
postal_cards (
  card_id, file_hash, original_filename, image_type,
  file_size, width, height, first_seen, last_updated
)

card_processing (
  card_id, crop_paths, grid_rows, grid_cols,
  ai_title, ai_description, ai_condition, ai_price,
  last_processed
)

ebay_listings (
  card_id, status, listing_url, error_message
)
```

### Simple Architecture

```
mod_tracking_viewer_ui:
  └── bslib::card
      └── List of 20 cards (each with View Details button)

mod_tracking_viewer_server:
  ├── get_recent_images() → Simple query
  ├── renderUI() → Generate card list
  └── observeEvent(view_details) → Show modal
```

## How - Implementation Strategy

### Phase 1: Simple Query Function (15 min)

**Add to R/tracking_database.R** (append at end):

```r
#' Get recent images with processing status
#' @param limit Number of recent images (default 20)
#' @return Data frame with image data
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
#' @param timestamp POSIXct timestamp
#' @return Character string
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
#' @param row Data frame row with image data
#' @return Character status
#' @export
get_image_status <- function(row) {
  if (!is.na(row$ebay_status) && row$ebay_status != "") {
    return("eBay Posted")
  } else if (!is.na(row$ai_title)) {
    return("AI Extracted")
  } else if (!is.na(row$last_processed)) {
    return("Processed")
  } else {
    return("Uploaded")
  }
}
```

**VALIDATE**:
```r
source("R/tracking_database.R")
test_data <- get_recent_images(5)
nrow(test_data) > 0  # Should be TRUE if database has data
```

### Phase 2: Simple UI (30 min)

**REPLACE R/mod_tracking_viewer.R** entirely:

```r
#' Simple Tracking Viewer UI
#'
#' @description Shows last 20 processed images with status
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
          style = "text-align: center; padding: 40px; color: #6c757d;",
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
        if (!is.na(row$last_processed)) {
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
        if (!is.na(row$ai_title)) {
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
        if (!is.na(row$ebay_status) && row$ebay_status != "") {
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
              if (!is.na(row$listing_url)) {
                tags$tr(
                  tags$th("Listing:"),
                  tags$td(tags$a(href = row$listing_url, target = "_blank", "View on eBay"))
                )
              },
              if (!is.na(row$error_message)) {
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

**VALIDATE**:
```r
golem::run_dev()
# Navigate to Tracking tab
# Should see list of images
# Click "View Details" → modal appears
```

### Phase 3: Polish (15 min)

**Test all scenarios:**
- [ ] Empty database shows friendly message
- [ ] Images display in reverse chronological order
- [ ] Status badges are correct colors
- [ ] Relative times are accurate
- [ ] Modal shows all available data
- [ ] Modal closes properly

## Validation Gates

### Gate 1: Query Works
```bash
VALIDATE: R -e "source('R/tracking_database.R'); nrow(get_recent_images()) > 0"
EXPECT: TRUE if database has images
FIX: Check database path, verify tables exist
```

### Gate 2: UI Renders
```bash
VALIDATE: Run app, navigate to Tracking tab
EXPECT: See list of recent images or empty state
FIX: Check for syntax errors, ns() usage
```

### Gate 3: Modal Works
```bash
VALIDATE: Click "View Details" button
EXPECT: Modal opens with image data
FIX: Check observeEvent, button IDs, ns()
```

## Test Plan

### Manual Testing

1. **Empty State**
   - [ ] Fresh database shows "No images yet" message
   - [ ] Message is friendly and centered

2. **Image List**
   - [ ] Shows up to 20 most recent images
   - [ ] Most recent at top
   - [ ] Status badges show correct status
   - [ ] Relative times are accurate
   - [ ] Filenames truncate at 40 characters

3. **Modal - Basic Image**
   - [ ] Click "View Details" → modal opens
   - [ ] Shows image information
   - [ ] No processing section if not processed
   - [ ] Close button works

4. **Modal - Processed Image**
   - [ ] Shows processing section
   - [ ] Grid layout displays correctly
   - [ ] Crop thumbnails appear (if exist)
   - [ ] Images load correctly

5. **Modal - AI Extracted**
   - [ ] Shows AI section
   - [ ] Title, description, condition, price all present
   - [ ] Description formatted nicely

6. **Modal - eBay Posted**
   - [ ] Shows eBay section
   - [ ] Status badge displays
   - [ ] Listing URL is clickable
   - [ ] Error message shows if present

## Files Modified

### R/tracking_database.R
**Action**: APPEND (add at end)
**Lines Added**: ~80
**New Functions**:
- `get_recent_images()`
- `format_relative_time()`
- `get_image_status()`

### R/mod_tracking_viewer.R
**Action**: REPLACE entire file
**Lines**: ~250 (well under 400 limit)
**Functions**:
- `mod_tracking_viewer_ui()`
- `mod_tracking_viewer_server()`

## Common Issues & Solutions

### Issue: No images showing
**Debug**: Check database has data
```r
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
DBI::dbGetQuery(con, "SELECT COUNT(*) FROM postal_cards")
DBI::dbDisconnect(con)
```
**Fix**: Process some images first

### Issue: Modal not opening
**Debug**: Check browser console for errors
**Fix**: Ensure `observeEvent` uses correct button ID with `ns()`

### Issue: Crop images not displaying
**Debug**: Check paths in database
**Fix**: Ensure paths are converted from `inst/app/...` to web paths

## Performance

**Query Time**: < 100ms (single JOIN, LIMIT 20)
**Load Time**: < 1 second total
**Modal Open**: < 500ms

## Success Metrics

**Technical**:
- [ ] Query returns data in < 100ms
- [ ] UI renders in < 1 second
- [ ] Modal opens in < 500ms
- [ ] No errors in console
- [ ] All buttons work

**User**:
- [ ] Can quickly see recent activity
- [ ] Status is immediately clear
- [ ] Details are accessible with one click
- [ ] Interface is intuitive (no learning curve)

**Code Quality**:
- [ ] < 400 lines total
- [ ] No complex logic
- [ ] Easy to maintain
- [ ] Follows Golem conventions

---

**Total Implementation Time**: 1-2 hours
**Difficulty**: Easy
**Dependencies**: DBI, RSQLite, jsonlite, bslib, shinyjs
**Risk**: Low (no database changes, minimal code)
