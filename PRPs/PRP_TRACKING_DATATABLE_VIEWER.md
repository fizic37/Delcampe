# PRP: Enhanced Tracking Viewer with DT::datatable

**Status:** Draft - Ready for User Review
**Priority:** High
**Created:** 2025-10-16
**Type:** Feature Enhancement

---

## Problem Statement

The current tracking viewer implementation doesn't effectively utilize the rich database schema we have. We track sessions, users, timestamps, and eBay statuses, but none of this information is displayed in a useful way for the user.

### Current Issues

1. **Underutilized Data:** Database contains sessions, users, timestamps, eBay status, but UI shows minimal information
2. **No Filtering:** Users cannot filter by date range or eBay status
3. **No Search:** Users cannot search for specific cards by filename or title
4. **Limited View:** Only shows 20 most recent items without pagination
5. **Poor UX:** Simple card list instead of sortable, filterable table

### User Needs

Users need to:
1. **Search** by time period (default: last 7 days)
2. **Filter** by eBay status (Listed/Draft/Failed/Pending)
3. **Search** by filename or AI-extracted title
4. **Sort** by any column (date, status, price, etc.)
5. **View details** by clicking on a row
6. **(Optional)** See thumbnail preview in table

---

## Solution Overview

Replace the current simple tracking viewer with a proper **DT::datatable** implementation that shows all relevant processing information with advanced filtering and search capabilities.

### Key Features

1. **DT::datatable** with server-side processing
2. **Date range filter** (default: last 7 days, user-selectable)
3. **eBay status dropdown filter** at top of table
4. **Search box** for filenames and titles
5. **Row click handler** to open detailed modal
6. **Sortable columns** for all fields
7. **(Optional)** Thumbnail column with first crop image

---

## Database Schema Review

### Available Tables

```sql
-- postal_cards: Master table (one per unique image hash)
card_id, file_hash, original_filename, image_type,
file_size, width, height, first_seen, last_updated, times_uploaded

-- card_processing: Processing results
processing_id, card_id, crop_paths (JSON), h_boundaries, v_boundaries,
grid_rows, grid_cols, extraction_dir,
ai_title, ai_description, ai_condition, ai_price, ai_model, last_processed

-- ebay_listings: eBay posting tracking
listing_id, card_id, session_id, ebay_item_id, sku,
status, title, price, listing_url,
created_at, listed_at, last_updated, error_message

-- sessions: Session tracking
session_id, user_id, session_start, session_end, status, notes

-- session_activity: Activity log
activity_id, session_id, card_id, action, timestamp, details
```

### Query Strategy

**Main Query:**
```sql
SELECT
  pc.card_id,
  pc.original_filename,
  pc.image_type,
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
  el.created_at as ebay_created_at,
  el.listed_at as ebay_listed_at,
  el.error_message
FROM postal_cards pc
LEFT JOIN card_processing cp ON pc.card_id = cp.card_id
LEFT JOIN ebay_listings el ON pc.card_id = el.card_id
WHERE pc.first_seen >= datetime('now', '-7 days')  -- Default filter
  AND cp.last_processed IS NOT NULL  -- Only show processed cards
ORDER BY pc.first_seen DESC
```

---

## UI/UX Design

### Layout Structure

```
┌─────────────────────────────────────────────────────────────┐
│ Processing History                                          │
├─────────────────────────────────────────────────────────────┤
│ Date Range: [Last 7 days ▼]  eBay Status: [All ▼]         │
├─────────────────────────────────────────────────────────────┤
│ [Search box]                                                │
├─────────────────────────────────────────────────────────────┤
│ Thumbnail | Filename   | Type | Date       | eBay    | ... │
│ ───────────────────────────────────────────────────────────│
│ [img]     | card01.jpg | Comb | 2025-10-16 | Listed  | ... │
│ [img]     | card02.jpg | Face | 2025-10-15 | Draft   | ... │
│ ...                                                         │
└─────────────────────────────────────────────────────────────┘
```

### Table Columns

| Column | Width | Type | Sortable | Searchable | Description |
|--------|-------|------|----------|------------|-------------|
| **Thumbnail** | 80px | Image | No | No | First crop image (optional) |
| **Filename** | 200px | Text | Yes | Yes | Original filename |
| **Type** | 80px | Badge | Yes | Yes | Face/Verso/Combined |
| **Processed** | 120px | DateTime | Yes | No | When processing completed |
| **eBay Status** | 100px | Badge | Yes | Yes | Listed/Draft/Failed/Pending |
| **AI Title** | 250px | Text | Yes | Yes | Title extracted by AI |
| **Price** | 80px | Currency | Yes | No | AI extracted price (€) |
| **Grid** | 60px | Text | Yes | No | Grid layout (e.g., "2×3") |
| **Actions** | 80px | Button | No | No | "View" button |

### Filter Controls

**Date Range Filter (selectInput):**
```r
selectInput(
  ns("date_range"),
  "Show:",
  choices = c(
    "Last 7 days" = "7",
    "Last 30 days" = "30",
    "Last 90 days" = "90",
    "Last 6 months" = "180",
    "Last year" = "365",
    "All time" = "all"
  ),
  selected = "7"  # Default
)
```

**eBay Status Filter (selectInput):**
```r
selectInput(
  ns("ebay_filter"),
  "eBay Status:",
  choices = c(
    "All" = "all",
    "Listed" = "listed",
    "Draft" = "draft",
    "Failed" = "failed",
    "Pending" = "pending",
    "Not Posted" = "none"
  ),
  selected = "all"  # Default
)
```

### Status Badge Styling

```r
get_ebay_status_badge <- function(status) {
  if (is.na(status) || is.null(status) || status == "") {
    return(span(class = "badge bg-secondary", "Not Posted"))
  }

  badge_info <- switch(tolower(status),
    "listed" = list(label = "Listed", class = "bg-success"),
    "draft" = list(label = "Draft", class = "bg-warning"),
    "failed" = list(label = "Failed", class = "bg-danger"),
    "pending" = list(label = "Pending", class = "bg-info"),
    list(label = status, class = "bg-light")
  )

  span(class = paste("badge", badge_info$class), badge_info$label)
}
```

---

## Technical Implementation

### Module Structure

**File:** `R/mod_tracking_viewer.R` (REPLACE existing file)

```r
mod_tracking_viewer_ui <- function(id) {
  ns <- NS(id)

  tagList(
    bslib::card(
      header = bslib::card_header(
        "Processing History",
        class = "bg-primary text-white"
      ),

      # Filter controls
      div(
        style = "padding: 15px; background: #f8f9fa; border-bottom: 1px solid #dee2e6;",
        div(
          style = "display: flex; gap: 15px; align-items: end;",
          div(
            style = "flex: 1;",
            selectInput(
              ns("date_range"),
              "Date Range:",
              choices = c(
                "Last 7 days" = "7",
                "Last 30 days" = "30",
                "Last 90 days" = "90",
                "Last 6 months" = "180",
                "Last year" = "365",
                "All time" = "all"
              ),
              selected = "7"
            )
          ),
          div(
            style = "flex: 1;",
            selectInput(
              ns("ebay_filter"),
              "eBay Status:",
              choices = c(
                "All" = "all",
                "Listed" = "listed",
                "Draft" = "draft",
                "Failed" = "failed",
                "Pending" = "pending",
                "Not Posted" = "none"
              ),
              selected = "all"
            )
          )
        )
      ),

      # DataTable
      div(
        style = "padding: 20px;",
        DT::dataTableOutput(ns("tracking_table"))
      )
    )
  )
}
```

### Server Logic

```r
mod_tracking_viewer_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive: fetch filtered data
    tracking_data <- reactive({
      # Get date filter
      days_back <- input$date_range
      date_filter <- if (days_back == "all") {
        ""
      } else {
        sprintf("AND pc.first_seen >= datetime('now', '-%s days')", days_back)
      }

      # Get eBay filter
      ebay_filter <- input$ebay_filter
      ebay_filter_sql <- if (ebay_filter == "all") {
        ""
      } else if (ebay_filter == "none") {
        "AND (el.status IS NULL OR el.status = '')"
      } else {
        sprintf("AND el.status = '%s'", ebay_filter)
      }

      # Query database
      get_tracking_data(date_filter, ebay_filter_sql)
    })

    # Render DataTable
    output$tracking_table <- DT::renderDataTable({
      data <- tracking_data()

      if (nrow(data) == 0) {
        return(data.frame(Message = "No processed cards found for selected filters"))
      }

      # Format data for display
      display_data <- data.frame(
        Filename = data$original_filename,
        Type = tools::toTitleCase(data$image_type),
        Processed = format(as.POSIXct(data$last_processed), "%Y-%m-%d %H:%M"),
        `eBay Status` = sapply(data$ebay_status, format_ebay_status),
        `AI Title` = ifelse(is.na(data$ai_title), "", substr(data$ai_title, 1, 50)),
        Price = ifelse(is.na(data$ai_price), "", sprintf("€%.2f", data$ai_price)),
        Grid = ifelse(is.na(data$grid_rows), "", sprintf("%dx%d", data$grid_rows, data$grid_cols)),
        check.names = FALSE
      )

      DT::datatable(
        display_data,
        selection = "single",
        options = list(
          pageLength = 25,
          lengthMenu = c(10, 25, 50, 100),
          order = list(list(2, "desc")),  # Sort by Processed date desc
          autoWidth = TRUE,
          columnDefs = list(
            list(width = "200px", targets = 0),  # Filename
            list(width = "80px", targets = 1),   # Type
            list(width = "120px", targets = 2),  # Processed
            list(width = "100px", targets = 3),  # eBay Status
            list(width = "250px", targets = 4),  # AI Title
            list(width = "80px", targets = 5),   # Price
            list(width = "60px", targets = 6)    # Grid
          )
        ),
        escape = FALSE,  # Allow HTML in cells
        rownames = FALSE
      )
    })

    # Handle row click
    observeEvent(input$tracking_table_rows_selected, {
      selected_row <- input$tracking_table_rows_selected
      if (length(selected_row) > 0) {
        data <- tracking_data()
        show_detail_modal(data[selected_row, ])
      }
    })

    # Modal builder (reuse from previous implementation)
    show_detail_modal <- function(row) {
      # ... (same as before, with conditional sections)
    }
  })
}
```

### Helper Functions

**File:** `R/tracking_database.R` (ADD new function)

```r
#' Get tracking data with filters
#'
#' @description Query processing history with date and eBay status filters
#'
#' @param date_filter SQL WHERE clause for date filtering
#' @param ebay_filter SQL WHERE clause for eBay status filtering
#' @return Data frame with tracking data
#' @export
get_tracking_data <- function(date_filter = "", ebay_filter = "") {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    query <- sprintf("
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
      WHERE cp.last_processed IS NOT NULL
        %s
        %s
      ORDER BY pc.first_seen DESC
    ", date_filter, ebay_filter)

    result <- DBI::dbGetQuery(con, query)
    return(result)

  }, error = function(e) {
    message("Error getting tracking data: ", e$message)
    return(data.frame())
  })
}

#' Format eBay status for display
#'
#' @param status eBay status string
#' @return HTML span with badge
#' @export
format_ebay_status <- function(status) {
  if (is.na(status) || is.null(status) || status == "") {
    return('<span class="badge bg-secondary">Not Posted</span>')
  }

  badge_class <- switch(tolower(status),
    "listed" = "bg-success",
    "draft" = "bg-warning",
    "failed" = "bg-danger",
    "pending" = "bg-info",
    "bg-light"
  )

  sprintf('<span class="badge %s">%s</span>', badge_class, tools::toTitleCase(status))
}
```

---

## Optional: Thumbnail Column

### Decision Point

**Question for User:** Should we add a thumbnail column showing the first crop image?

**Pros:**
- Visual identification of cards
- Better UX (easier to recognize cards)
- Professional appearance

**Cons:**
- Slightly slower table rendering
- More complex implementation
- Requires parsing JSON crop_paths

### Implementation (If Approved)

```r
# In get_tracking_data(), add thumbnail extraction:
get_first_thumbnail <- function(crop_paths_json) {
  if (is.na(crop_paths_json) || is.null(crop_paths_json)) {
    return(NA)
  }

  tryCatch({
    paths <- jsonlite::fromJSON(crop_paths_json)
    if (length(paths) > 0) {
      # Convert inst/app/ path to web path
      web_path <- gsub("^inst/app/", "", paths[1])
      return(web_path)
    }
    return(NA)
  }, error = function(e) {
    return(NA)
  })
}

# In display_data preparation:
display_data <- data.frame(
  Thumbnail = sapply(data$crop_paths, function(cp) {
    thumb <- get_first_thumbnail(cp)
    if (is.na(thumb)) {
      '<span class="text-muted">N/A</span>'
    } else {
      sprintf('<img src="%s" style="width:60px;height:60px;object-fit:cover;border-radius:4px;">', thumb)
    }
  }),
  # ... rest of columns
)
```

---

## Testing Strategy

### Unit Tests

```r
# Test data retrieval
test_that("get_tracking_data returns correct structure", {
  result <- get_tracking_data()
  expect_true(is.data.frame(result))
  expect_true("card_id" %in% colnames(result))
  expect_true("ebay_status" %in% colnames(result))
})

# Test date filtering
test_that("date filter works correctly", {
  result_7 <- get_tracking_data("AND pc.first_seen >= datetime('now', '-7 days')", "")
  result_all <- get_tracking_data("", "")
  expect_lte(nrow(result_7), nrow(result_all))
})

# Test eBay filtering
test_that("eBay filter works correctly", {
  result_listed <- get_tracking_data("", "AND el.status = 'listed'")
  if (nrow(result_listed) > 0) {
    expect_true(all(result_listed$ebay_status == "listed", na.rm = TRUE))
  }
})
```

### Manual Testing Scenarios

**Scenario 1: Date Range Filtering**
1. Start app, navigate to Tracking tab
2. Select "Last 7 days" - verify only recent cards shown
3. Select "All time" - verify all processed cards shown
4. Select "Last 30 days" - verify date range is correct

**Scenario 2: eBay Status Filtering**
1. Select "All" - verify all cards shown
2. Select "Listed" - verify only listed cards shown
3. Select "Not Posted" - verify only cards without eBay status shown
4. Select "Failed" - verify only failed postings shown

**Scenario 3: Search and Sort**
1. Use search box to find specific filename
2. Click column headers to sort
3. Verify sorting works for all columns

**Scenario 4: Row Click Modal**
1. Click on any row in table
2. Verify modal opens with full details
3. Verify all sections show correct data
4. Verify crop thumbnails load

**Scenario 5: Edge Cases**
1. Empty database - verify friendly message
2. No matches for filter - verify empty state
3. Very long filename - verify truncation
4. Missing eBay data - verify "Not Posted" badge

---

## Performance Considerations

### Query Optimization

- Use indexed fields for WHERE clauses (pc.first_seen has index)
- Limit result set with date filters
- LEFT JOIN is efficient for optional eBay data

**Expected Performance:**
- < 100ms for 7-day query
- < 500ms for all-time query with 1000+ cards

### DataTable Performance

- Use `pageLength = 25` to limit initial render
- Enable server-side processing if > 1000 rows
- Lazy load thumbnails if implemented

---

## Migration Plan

### Step 1: Backup Current Implementation

```bash
cp R/mod_tracking_viewer.R ~/Documents/R_Projects/Delcampe_BACKUP/mod_tracking_viewer.R.backup_$(date +%Y%m%d_%H%M%S)
```

### Step 2: Remove Previous Helper Functions

Remove the 3 functions added in previous implementation:
- `get_recent_images()`
- `format_relative_time()`
- `get_image_status()`

These are replaced by:
- `get_tracking_data()`
- `format_ebay_status()`

### Step 3: Implement New Module

Replace `R/mod_tracking_viewer.R` with new DT-based implementation.

### Step 4: Add New Helper Functions

Add to `R/tracking_database.R`:
- `get_tracking_data(date_filter, ebay_filter)`
- `format_ebay_status(status)`
- (Optional) `get_first_thumbnail(crop_paths_json)`

### Step 5: Test Thoroughly

Run all manual test scenarios before considering complete.

---

## Success Criteria

### Must Have
- ✅ DT::datatable displays all processed cards
- ✅ Date range filter works (default: 7 days)
- ✅ eBay status filter works
- ✅ Search box filters table
- ✅ Row click opens detail modal
- ✅ All columns sortable
- ✅ Performance < 500ms for typical queries

### Nice to Have
- ⏳ Thumbnail column (awaiting user decision)
- ⏳ Export to CSV button
- ⏳ Refresh button to reload data
- ⏳ Column visibility toggle

### Won't Have (YAGNI)
- Multi-row selection
- Inline editing
- Advanced filters (date range picker)
- Chart/graph visualizations

---

## Open Questions for User

1. **Thumbnails:** Should we add thumbnail column? (Slightly complex, but better UX)

2. **Two Tracking Sections:** You mentioned there are 2 tracking sections in the UI. Where is the second one? Should we remove it or consolidate?

3. **Default Columns:** Are the proposed columns sufficient, or do you want to add/remove any?

4. **Export Feature:** Do you want a "Download CSV" button for the table data?

5. **Refresh Button:** Should we add a manual refresh button, or is reactive updating sufficient?

---

## Implementation Estimate

**Time Estimate:** 2-3 hours

| Task | Time | Notes |
|------|------|-------|
| Remove old functions | 15 min | Clean up previous implementation |
| Implement new module | 60 min | DT::datatable with filters |
| Add helper functions | 30 min | get_tracking_data + format_ebay_status |
| Testing | 45 min | All scenarios |
| Documentation | 30 min | Update memory files |

**Total:** ~3 hours (without thumbnails)
**With Thumbnails:** +30 minutes

---

## Next Steps

1. **User reviews this PRP**
2. **User answers open questions** (especially about thumbnails and 2 tracking sections)
3. **User creates final PRP** with decisions
4. **User executes implementation** (or requests AI assistance)

---

## References

- **Database Schema:** R/tracking_database.R (lines 91-207)
- **DT Documentation:** https://rstudio.github.io/DT/
- **Previous Implementation:** R/mod_tracking_viewer.R (current version)
- **Modal Pattern:** R/mod_delcampe_export.R (lines 386-507)
- **Project Principles:** CLAUDE.md

---

**Status:** ⏸️ Awaiting User Feedback
**Created By:** Claude (AI Assistant)
**Date:** 2025-10-16
