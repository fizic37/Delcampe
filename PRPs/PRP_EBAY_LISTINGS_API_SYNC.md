# PRP: eBay Listings Menu - API-Only Sync with Database Cache

**Date**: 2025-11-03
**Status**: DRAFT - Ready for Implementation
**Priority**: HIGH
**Complexity**: MEDIUM
**Related**: PRP_EBAY_LISTINGS_VIEWER.md (predecessor implementation)

## Executive Summary

Transform the eBay Listings Viewer into a pure API-driven interface that queries eBay Trading API on-demand, caches results in a dedicated database table, and enforces strict rate limiting per eBay documentation. The focus is on **Active listings** and **Sold items** as the most critical status information.

## Context & Motivation

### Current State (Issues)
The existing `mod_ebay_listings.R` implementation (from PRP_EBAY_LISTINGS_VIEWER.md) has the following issues:
1. **Mixed data sources**: Shows both locally-created drafts AND eBay API data, creating confusion
2. **Stale data**: Displays database records that may not reflect current eBay status
3. **No forced refresh**: User cannot easily refresh to get latest eBay data
4. **Rate limit enforcement unclear**: No clear visual feedback on when refresh is allowed

### User Need
**Primary Goal**: See ONLY real eBay listing data from the API, with clear focus on:
- **Active listings** - What's currently live on eBay
- **Sold items** - What has successfully sold

**Key Requirements**:
1. **API-First Data**: Show ONLY data retrieved from eBay Trading API
2. **Smart Caching**: Store latest API response in database to avoid repeated calls
3. **Rate Limiting**: Enforce eBay's rate limits with clear user feedback
4. **Status Focus**: Prioritize display of Active and Sold listings
5. **Refresh Control**: User can manually refresh within rate limit constraints

## eBay Trading API Rate Limits

### Official Documentation
Source: [eBay Trading API Call Limits](https://developer.ebay.com/support/kb-article?KBid=4702)

**Per-User Limits (OAuth)**:
- **GetSellerList**: 5,000 calls/day per OAuth user token
- **Limit Window**: 24-hour rolling window
- **Recommended Minimum Interval**: 15 minutes between full refreshes
- **Burst Protection**: No more than 1 call per 5 seconds per user

**Per-App Limits (Application-Level)**:
- **Total Daily Calls**: Varies by eBay developer tier
- **Default Free Tier**: 5,000 calls/day total across all users
- **Production Tier**: 1,000,000+ calls/day (requires application)

### Our Rate Limiting Strategy

**Conservative Approach** (recommended):
- **Full Refresh Interval**: 15 minutes minimum between calls
- **Visual Countdown**: Show "Next refresh available in X minutes"
- **Emergency Refresh**: Allow override with warning (for debugging)
- **Burst Prevention**: Never allow multiple rapid refreshes

**Implementation Details**:
```r
# Rate limit configuration
RATE_LIMIT_MINUTES <- 15  # Minimum minutes between full refreshes
RATE_LIMIT_EMERGENCY_OVERRIDE <- TRUE  # Allow admin override
RATE_LIMIT_WARNING_THRESHOLD <- 10  # Warn if refreshing more than X times/day
```

## Technical Architecture

### New Database Table: `ebay_listings_cache`

**Purpose**: Store ONLY data retrieved from eBay Trading API (not local drafts).

**Schema**:
```sql
CREATE TABLE IF NOT EXISTS ebay_listings_cache (
  cache_id INTEGER PRIMARY KEY AUTOINCREMENT,
  ebay_item_id TEXT UNIQUE NOT NULL,  -- eBay ItemID from API
  ebay_user_id TEXT NOT NULL,         -- Which eBay account owns this

  -- Core listing data (from GetSellerList response)
  title TEXT,
  current_price REAL,
  currency TEXT DEFAULT 'USD',
  listing_status TEXT,                -- Active, Completed, Ended, etc.
  listing_type TEXT,                  -- FixedPriceItem, Chinese (auction), etc.
  quantity INTEGER DEFAULT 1,
  quantity_sold INTEGER DEFAULT 0,

  -- Engagement metrics
  watch_count INTEGER DEFAULT 0,
  view_count INTEGER DEFAULT 0,
  bid_count INTEGER DEFAULT 0,        -- For auctions only

  -- Time tracking
  start_time DATETIME,                -- When listing went live
  end_time DATETIME,                  -- When listing ends/ended
  time_remaining TEXT,                -- ISO 8601 duration (e.g., "P3DT2H30M")

  -- Links and metadata
  listing_url TEXT,                   -- Direct eBay URL
  gallery_url TEXT,                   -- Thumbnail image URL

  -- SKU detection (to link back to our local data if needed)
  sku TEXT,                           -- Extracted from listing or NULL

  -- Cache metadata
  synced_at DATETIME DEFAULT CURRENT_TIMESTAMP,  -- When this data was fetched
  api_call_name TEXT DEFAULT 'GetSellerList',    -- Which API call retrieved this

  FOREIGN KEY (ebay_user_id) REFERENCES ebay_users(ebay_user_id)
);

CREATE INDEX idx_cache_item_id ON ebay_listings_cache(ebay_item_id);
CREATE INDEX idx_cache_user_id ON ebay_listings_cache(ebay_user_id);
CREATE INDEX idx_cache_status ON ebay_listings_cache(listing_status);
CREATE INDEX idx_cache_synced_at ON ebay_listings_cache(synced_at);
```

**Key Design Decisions**:
- **Separate from `ebay_listings`**: The existing table tracks our local draft/submission process. This cache is API truth.
- **No card_id foreign key**: Some eBay items may not have been created through our app.
- **Sync timestamp**: Always know how fresh the data is.
- **SKU extraction**: Try to parse SKU from eBay data to optionally link to local records.

### Modified Table: `ebay_sync_log`

**Add rate limiting fields**:
```sql
-- Already exists, add columns if needed:
ALTER TABLE ebay_sync_log ADD COLUMN user_ip TEXT;          -- Track by user session
ALTER TABLE ebay_sync_log ADD COLUMN override_used INTEGER DEFAULT 0;  -- Emergency override flag
```

### Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER CLICKS "REFRESH"                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                ┌────────────────────────────┐
                │  Check Rate Limit          │
                │  (last_sync < 15 mins ago?)│
                └────────────┬───────────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
        ┌───────▼─────────┐      ┌───────▼──────────┐
        │ ALLOWED         │      │ BLOCKED          │
        │ (proceed)       │      │ Show countdown   │
        └───────┬─────────┘      └──────────────────┘
                │
                ▼
    ┌───────────────────────────┐
    │ Call GetSellerList API    │
    │ (last 90 days, all items) │
    └───────────┬───────────────┘
                │
                ▼
    ┌───────────────────────────┐
    │ Parse XML Response        │
    │ Extract ItemArray/Item    │
    └───────────┬───────────────┘
                │
                ▼
    ┌───────────────────────────┐
    │ CLEAR ebay_listings_cache │
    │ (delete old data)         │
    └───────────┬───────────────┘
                │
                ▼
    ┌───────────────────────────┐
    │ INSERT new items into     │
    │ ebay_listings_cache       │
    └───────────┬───────────────┘
                │
                ▼
    ┌───────────────────────────┐
    │ Log sync_complete         │
    │ Update ebay_sync_log      │
    └───────────┬───────────────┘
                │
                ▼
    ┌───────────────────────────┐
    │ Render DT::datatable      │
    │ (show Active & Sold first)│
    └───────────────────────────┘
```

**Key Points**:
1. **Clear old cache**: Each refresh replaces ALL cached data (not incremental)
2. **Single API call**: GetSellerList returns up to 200 items per call (handles pagination internally)
3. **Atomic operation**: Either full sync succeeds or fails (no partial updates)

## UI/UX Design

### Module Structure
**Module Name**: `mod_ebay_listings` (modify existing)
**Files Modified**:
- `R/mod_ebay_listings.R` - Refactor to use cache table exclusively
- `R/ebay_sync_helpers.R` - Update cache functions
- `R/ebay_database_extension.R` - Add cache table initialization
- `tests/testthat/test-mod_ebay_listings.R` - Update tests

### UI Components

#### Top Bar - Refresh Control (Enhanced)
```
┌────────────────────────────────────────────────────────────────┐
│  eBay Listings (API-Synced)                                    │
│                                                                 │
│  [🔄 Refresh from eBay]   Last synced: 3 minutes ago          │
│  Next refresh available in: 12 minutes                         │
│                                                                 │
│  ⚠️ Note: This shows ONLY data from eBay API, not local drafts │
└────────────────────────────────────────────────────────────────┘
```

**Conditional Button States**:
- **Allowed (green)**: `[🔄 Refresh from eBay]` - clickable
- **Blocked (gray)**: `[⏱️ Wait 12 mins]` - disabled
- **Loading**: `[⏳ Syncing...]` - spinner active

#### Stats Display (Status-Focused)
```
┌────────────────────────────────────────────────────────────────┐
│  Total: 47  |  🟢 Active: 32  |  🔵 Sold: 8  |  ⚪ Ended: 7   │
└────────────────────────────────────────────────────────────────┘
```

**Status Priority Order**:
1. **Active** - Currently live on eBay
2. **Sold** - Successfully sold items
3. **Ended** - Ended without sale
4. **Completed** - Generic completion status
5. **Cancelled/Terminated** - User-cancelled listings

#### Filters (Simplified)
```
Filter by Status: [🟢 Active ▼]   Type: [All Types ▼]   Search: [...]
```

**Status Filter Options**:
- **Active** (default) - Show only active listings
- **Sold** - Show only sold items
- **All** - Show everything from cache

#### Main Datatable (Essential Columns Only)

**Column Design** (mobile-first, desktop-enhanced):

| Column | Mobile | Desktop | Description | Source |
|--------|--------|---------|-------------|--------|
| **Status** | ✅ | ✅ | Badge (Active/Sold) | `listing_status` |
| **Title** | ✅ | ✅ | Truncated to 60 chars | `title` |
| **Price** | ✅ | ✅ | Current price | `current_price` |
| **Type** | ❌ | ✅ | Fixed/Auction | `listing_type` |
| **Views** | ❌ | ✅ | View count | `view_count` |
| **Watchers** | ❌ | ✅ | Watcher count | `watch_count` |
| **Bids** | ❌ | ✅ | Bid count (auctions) | `bid_count` |
| **Time Left** | ✅ | ✅ | Time remaining | `time_remaining` |
| **Sold Qty** | ❌ | ✅ | Quantity sold | `quantity_sold` |

**Example Datatable Row**:
```
┌────────┬──────────────────────────────┬────────┬────────┬────────┐
│ Status │ Title                        │ Price  │ Views  │ Time   │
├────────┼──────────────────────────────┼────────┼────────┼────────┤
│ 🟢Active│ AUSTRIA 1912 Parcel Post...  │ $6.50  │   45   │ 3d 2h  │
│        │ Watchers: 3  Bids: -         │        │        │        │
├────────┼──────────────────────────────┼────────┼────────┼────────┤
│ 🔵Sold │ USA STAMP 1920 Lincoln...    │ $4.25  │   67   │ Oct 31 │
│        │ Watchers: 5  Bids: 8  Qty: 1 │        │        │        │
└────────┴──────────────────────────────┴────────┴────────┴────────┘
```

### Rate Limit Enforcement - Visual Feedback

#### Countdown Timer (reactive)
```r
output$refresh_countdown <- renderUI({
  req(last_sync_time())

  time_since_sync <- difftime(Sys.time(), last_sync_time(), units = "mins")
  time_remaining <- max(0, RATE_LIMIT_MINUTES - as.numeric(time_since_sync))

  if (time_remaining > 0) {
    tags$div(
      class = "alert alert-warning",
      icon("clock"),
      sprintf("Next refresh available in: %d minutes", ceiling(time_remaining))
    )
  } else {
    tags$div(
      class = "alert alert-success",
      icon("check"),
      "Refresh available now"
    )
  }
})
```

#### Button Disable Logic
```r
observe({
  can_refresh <- can_sync_listings(con, ebay_user_id(), RATE_LIMIT_MINUTES)

  if (can_refresh) {
    shinyjs::enable("refresh_btn")
    shinyjs::removeClass("refresh_btn", "btn-secondary")
    shinyjs::addClass("refresh_btn", "btn-primary")
  } else {
    shinyjs::disable("refresh_btn")
    shinyjs::removeClass("refresh_btn", "btn-primary")
    shinyjs::addClass("refresh_btn", "btn-secondary")
  }
})
```

## Implementation Details

### Function: `initialize_ebay_cache_table()`

**File**: `R/ebay_database_extension.R`

```r
#' Initialize eBay Listings Cache Table
#'
#' Creates table for storing ONLY eBay API data (not local drafts)
#'
#' @param db_path Path to SQLite database
#' @export
initialize_ebay_cache_table <- function(db_path = "inst/app/data/tracking.sqlite") {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
    on.exit(DBI::dbDisconnect(con))

    # Create cache table
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS ebay_listings_cache (
        cache_id INTEGER PRIMARY KEY AUTOINCREMENT,
        ebay_item_id TEXT UNIQUE NOT NULL,
        ebay_user_id TEXT NOT NULL,
        title TEXT,
        current_price REAL,
        currency TEXT DEFAULT 'USD',
        listing_status TEXT,
        listing_type TEXT,
        quantity INTEGER DEFAULT 1,
        quantity_sold INTEGER DEFAULT 0,
        watch_count INTEGER DEFAULT 0,
        view_count INTEGER DEFAULT 0,
        bid_count INTEGER DEFAULT 0,
        start_time DATETIME,
        end_time DATETIME,
        time_remaining TEXT,
        listing_url TEXT,
        gallery_url TEXT,
        sku TEXT,
        synced_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        api_call_name TEXT DEFAULT 'GetSellerList'
      )
    ")

    # Create indexes
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_cache_item_id ON ebay_listings_cache(ebay_item_id)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_cache_user_id ON ebay_listings_cache(ebay_user_id)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_cache_status ON ebay_listings_cache(listing_status)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_cache_synced_at ON ebay_listings_cache(synced_at)")

    message("✅ eBay listings cache table initialized")
    return(TRUE)

  }, error = function(e) {
    message("❌ Failed to initialize cache table: ", e$message)
    return(FALSE)
  })
}
```

### Function: `refresh_ebay_cache()`

**File**: `R/ebay_sync_helpers.R`

**Purpose**: Main cache refresh function - replaces ALL cached data with fresh API data.

```r
#' Refresh eBay Listings Cache from API
#'
#' Clears existing cache and repopulates with fresh data from GetSellerList
#'
#' @param con Database connection
#' @param ebay_api EbayTradingAPI object
#' @param ebay_user_id eBay user ID
#' @param days_back Number of days to fetch (default 90)
#'
#' @return List with success, items_synced, error
#' @export
refresh_ebay_cache <- function(con, ebay_api, ebay_user_id, days_back = 90) {
  # Check rate limit
  if (!can_sync_listings(con, ebay_user_id, RATE_LIMIT_MINUTES)) {
    return(list(
      success = FALSE,
      error = sprintf("Rate limit: wait %d minutes between refreshes", RATE_LIMIT_MINUTES)
    ))
  }

  # Log sync start
  sync_id <- log_sync_start(con, ebay_user_id)

  tryCatch({
    # Fetch from eBay Trading API
    ebay_data <- fetch_seller_listings(
      ebay_api,
      start_date = Sys.Date() - days_back,
      end_date = Sys.Date()
    )

    # Clear existing cache for this user
    DBI::dbExecute(con, "
      DELETE FROM ebay_listings_cache WHERE ebay_user_id = ?
    ", list(ebay_user_id))

    cat("🗑️  Cleared old cache for user:", ebay_user_id, "\n")

    # Insert new items
    items_inserted <- 0
    for (item in ebay_data$items) {
      # Map eBay status to our internal status
      listing_status <- map_ebay_status(item$ListingStatus)

      # Detect SKU from title (if present)
      sku <- extract_sku_from_title(item$Title)

      DBI::dbExecute(con, "
        INSERT INTO ebay_listings_cache (
          ebay_item_id, ebay_user_id, title, current_price, currency,
          listing_status, listing_type, quantity, quantity_sold,
          watch_count, view_count, bid_count, time_remaining,
          listing_url, gallery_url, sku, synced_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ", list(
        item$ItemID,
        ebay_user_id,
        item$Title,
        item$CurrentPrice,
        "USD",
        listing_status,
        item$ListingType %||% "FixedPriceItem",
        item$Quantity %||% 1,
        item$QuantitySold %||% 0,
        item$WatchCount %||% 0,
        item$HitCount %||% 0,
        item$BidCount %||% 0,
        item$TimeLeft,
        item$ViewItemURL,
        item$GalleryURL,
        sku
      ))

      items_inserted <- items_inserted + 1
    }

    # Log sync complete
    log_sync_complete(con, sync_id, items_inserted, api_calls = 1)

    cat("✅ Cache refreshed:", items_inserted, "items\n")

    return(list(
      success = TRUE,
      items_synced = items_inserted
    ))

  }, error = function(e) {
    # Log error
    log_sync_error(con, sync_id, e$message)

    return(list(
      success = FALSE,
      error = e$message
    ))
  })
}

#' Map eBay ListingStatus to internal status
#' @keywords internal
map_ebay_status <- function(ebay_status) {
  status_map <- c(
    "Active" = "active",
    "Completed" = "sold",
    "Ended" = "ended",
    "Cancelled" = "terminated",
    "CustomCode" = "error"
  )

  status_map[ebay_status] %||% tolower(ebay_status)
}

#' Extract SKU from listing title (pattern matching)
#' @keywords internal
extract_sku_from_title <- function(title) {
  # Try to detect SKU patterns: PC-XXXX or ST-XXXX
  match <- stringr::str_extract(title, "(PC|ST|STAMP)-[A-Z0-9]+")
  return(match %||% NA_character_)
}
```

### Function: `get_cached_listings()`

**File**: `R/ebay_sync_helpers.R`

```r
#' Get Cached eBay Listings
#'
#' Retrieve listings from cache table with optional filtering
#'
#' @param con Database connection
#' @param ebay_user_id eBay user ID (required)
#' @param status_filter Optional status filter ("active", "sold", etc.)
#'
#' @return Data frame with cached listings
#' @export
get_cached_listings <- function(con, ebay_user_id, status_filter = NULL) {
  sql <- "
    SELECT *
    FROM ebay_listings_cache
    WHERE ebay_user_id = ?
  "

  params <- list(ebay_user_id)

  # Add status filter
  if (!is.null(status_filter) && status_filter != "all") {
    sql <- paste0(sql, " AND listing_status = ?")
    params <- c(params, list(status_filter))
  }

  # Order by status priority: active first, then sold, then others
  sql <- paste0(sql, "
    ORDER BY
      CASE listing_status
        WHEN 'active' THEN 1
        WHEN 'sold' THEN 2
        WHEN 'ended' THEN 3
        ELSE 4
      END,
      synced_at DESC
  ")

  result <- DBI::dbGetQuery(con, sql, params)

  return(result)
}
```

### Module Server Function (Refactored)

**File**: `R/mod_ebay_listings.R`

```r
#' eBay Listings Server (API-Synced Version)
#'
#' @param id Module ID
#' @param ebay_api Reactive returning EbayTradingAPI object
#' @param session_id Reactive returning session ID
#'
#' @export
mod_ebay_listings_server <- function(id, ebay_api, session_id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Database helper
    get_db <- function() {
      DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    }

    # Reactive values
    cached_listings <- reactiveVal(NULL)
    last_sync_time <- reactiveVal(NULL)
    is_syncing <- reactiveVal(FALSE)

    # Get eBay user ID
    ebay_user_id <- reactive({
      req(session_id())
      con <- get_db()
      on.exit(DBI::dbDisconnect(con))
      get_ebay_user_id_from_session(con, session_id())
    })

    # Load cached data on init
    observe({
      req(ebay_user_id())

      con <- get_db()
      on.exit(DBI::dbDisconnect(con))

      data <- get_cached_listings(con, ebay_user_id())
      cached_listings(data)

      # Get last sync time
      last_sync <- DBI::dbGetQuery(con, "
        SELECT MAX(sync_started_at) as last_sync
        FROM ebay_sync_log
        WHERE ebay_user_id = ? AND sync_status = 'completed'
      ", list(ebay_user_id()))

      if (!is.na(last_sync$last_sync)) {
        last_sync_time(as.POSIXct(last_sync$last_sync))
      }
    })

    # Refresh button handler
    observeEvent(input$refresh_all, {
      req(ebay_user_id(), ebay_api())

      con <- get_db()
      on.exit(DBI::dbDisconnect(con))

      # Show progress
      is_syncing(TRUE)
      showNotification("Syncing from eBay API...", id = "sync_progress", duration = NULL)

      # Call refresh function
      result <- refresh_ebay_cache(con, ebay_api()$trading, ebay_user_id())

      # Hide progress
      is_syncing(FALSE)
      removeNotification("sync_progress")

      if (result$success) {
        # Reload cached data
        data <- get_cached_listings(con, ebay_user_id())
        cached_listings(data)
        last_sync_time(Sys.time())

        showNotification(
          sprintf("✅ Synced %d listings from eBay", result$items_synced),
          type = "message",
          duration = 3
        )
      } else {
        showNotification(
          paste("Error:", result$error),
          type = "error",
          duration = 10
        )
      }
    })

    # Filtered data
    filtered_data <- reactive({
      req(cached_listings())
      data <- cached_listings()

      if (nrow(data) == 0) return(data)

      # Apply status filter
      if (!is.null(input$filter_status) && input$filter_status != "All") {
        data <- data[data$listing_status == tolower(input$filter_status), ]
      }

      # Apply search filter
      if (!is.null(input$search_text) && nzchar(input$search_text)) {
        search_pattern <- tolower(input$search_text)
        matches <- grepl(search_pattern, tolower(data$title))
        data <- data[matches, ]
      }

      return(data)
    })

    # Render stats
    output$stats_display <- renderUI({
      req(cached_listings())
      data <- cached_listings()

      if (nrow(data) == 0) {
        return(tags$div(
          class = "alert alert-info",
          "No cached data. Click 'Refresh from eBay' to load listings."
        ))
      }

      total <- nrow(data)
      active <- sum(data$listing_status == "active", na.rm = TRUE)
      sold <- sum(data$listing_status == "sold", na.rm = TRUE)
      ended <- sum(data$listing_status == "ended", na.rm = TRUE)

      tags$div(
        class = "stats-row",
        tags$span(class = "stat-item", paste("Total:", total)),
        tags$span(class = "stat-item text-success", paste("🟢 Active:", active)),
        tags$span(class = "stat-item text-primary", paste("🔵 Sold:", sold)),
        tags$span(class = "stat-item text-muted", paste("⚪ Ended:", ended))
      )
    })

    # Render countdown timer
    output$refresh_countdown <- renderUI({
      req(last_sync_time())

      # Reactive timer to update every 10 seconds
      invalidateLater(10000)

      time_since_sync <- difftime(Sys.time(), last_sync_time(), units = "mins")
      time_remaining <- max(0, RATE_LIMIT_MINUTES - as.numeric(time_since_sync))

      if (time_remaining > 0) {
        tags$div(
          class = "alert alert-warning",
          icon("clock"),
          sprintf("Next refresh available in: %d minutes", ceiling(time_remaining))
        )
      } else {
        tags$div(
          class = "alert alert-success",
          icon("check"),
          "Refresh available now"
        )
      }
    })

    # Enable/disable refresh button
    observe({
      req(last_sync_time())

      time_since_sync <- difftime(Sys.time(), last_sync_time(), units = "mins")
      can_refresh <- as.numeric(time_since_sync) >= RATE_LIMIT_MINUTES

      if (can_refresh && !is_syncing()) {
        shinyjs::enable("refresh_all")
      } else {
        shinyjs::disable("refresh_all")
      }
    })

    # Render datatable
    output$listings_table <- DT::renderDataTable({
      data <- filtered_data()

      if (nrow(data) == 0) {
        return(DT::datatable(
          data.frame(Message = "No listings match your filters"),
          options = list(dom = 't', ordering = FALSE),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Prepare display data
      display_data <- data.frame(
        Status = sapply(data$listing_status, render_status_badge),
        Title = substr(data$title, 1, 60),
        Price = sprintf("$%.2f", data$current_price),
        Type = ifelse(data$listing_type == "Chinese", "Auction", "Fixed"),
        Views = ifelse(is.na(data$view_count), "-", as.character(data$view_count)),
        Watchers = ifelse(is.na(data$watch_count), "-", as.character(data$watch_count)),
        Bids = ifelse(is.na(data$bid_count) | data$bid_count == 0, "-", as.character(data$bid_count)),
        TimeLeft = ifelse(is.na(data$time_remaining), "-",
                         sapply(data$time_remaining, format_time_remaining)),
        SoldQty = ifelse(is.na(data$quantity_sold) | data$quantity_sold == 0, "-",
                        as.character(data$quantity_sold)),
        stringsAsFactors = FALSE
      )

      DT::datatable(
        display_data,
        selection = "single",
        filter = "none",
        escape = FALSE,
        rownames = FALSE,
        options = list(
          pageLength = 25,
          lengthMenu = c(10, 25, 50, 100),
          order = list(list(0, "asc")),  # Sort by Status (Active first)
          dom = "Blfrtip",
          buttons = c("copy", "csv", "excel"),
          scrollX = TRUE
        ),
        extensions = "Buttons"
      )
    })
  })
}
```

## Testing Strategy

### Unit Tests

**File**: `tests/testthat/test-ebay_cache.R`

```r
test_that("initialize_ebay_cache_table creates table", {
  con <- with_test_db()

  result <- initialize_ebay_cache_table(test_db_path())

  expect_true(result)
  expect_true(DBI::dbExistsTable(con, "ebay_listings_cache"))

  # Check schema
  columns <- DBI::dbListFields(con, "ebay_listings_cache")
  expect_true("ebay_item_id" %in% columns)
  expect_true("listing_status" %in% columns)
  expect_true("synced_at" %in% columns)
})

test_that("refresh_ebay_cache clears old data", {
  con <- with_test_db()

  # Insert old cache data
  DBI::dbExecute(con, "
    INSERT INTO ebay_listings_cache (ebay_item_id, ebay_user_id, title, listing_status)
    VALUES ('OLD123', 'user1', 'Old Listing', 'ended')
  ")

  # Mock eBay API response
  mock_ebay_api <- list(
    trading = list(
      get_seller_list = function(...) {
        '<?xml version="1.0"?>
        <GetSellerListResponse>
          <Ack>Success</Ack>
          <ItemArray>
            <Item>
              <ItemID>NEW456</ItemID>
              <Title>New Listing</Title>
              <SellingStatus><CurrentPrice>10.00</CurrentPrice><ListingStatus>Active</ListingStatus></SellingStatus>
            </Item>
          </ItemArray>
          <HasMoreItems>false</HasMoreItems>
        </GetSellerListResponse>'
      }
    )
  )

  # Refresh cache
  result <- refresh_ebay_cache(con, mock_ebay_api$trading, "user1")

  expect_true(result$success)
  expect_equal(result$items_synced, 1)

  # Verify old data deleted
  old_item <- DBI::dbGetQuery(con, "SELECT * FROM ebay_listings_cache WHERE ebay_item_id = 'OLD123'")
  expect_equal(nrow(old_item), 0)

  # Verify new data inserted
  new_item <- DBI::dbGetQuery(con, "SELECT * FROM ebay_listings_cache WHERE ebay_item_id = 'NEW456'")
  expect_equal(nrow(new_item), 1)
  expect_equal(new_item$listing_status, "active")
})

test_that("get_cached_listings filters by status", {
  con <- with_test_db()

  # Insert test data
  DBI::dbExecute(con, "
    INSERT INTO ebay_listings_cache (ebay_item_id, ebay_user_id, title, listing_status)
    VALUES
      ('ACTIVE1', 'user1', 'Active Listing', 'active'),
      ('SOLD1', 'user1', 'Sold Listing', 'sold'),
      ('ENDED1', 'user1', 'Ended Listing', 'ended')
  ")

  # Test filter: active only
  active_listings <- get_cached_listings(con, "user1", "active")
  expect_equal(nrow(active_listings), 1)
  expect_equal(active_listings$listing_status, "active")

  # Test filter: all
  all_listings <- get_cached_listings(con, "user1", "all")
  expect_equal(nrow(all_listings), 3)

  # Test ordering (active first)
  expect_equal(all_listings$ebay_item_id[1], "ACTIVE1")
})

test_that("rate limiting prevents rapid refreshes", {
  con <- with_test_db()

  # Create recent sync log (5 mins ago)
  DBI::dbExecute(con, "
    INSERT INTO ebay_sync_log (ebay_user_id, sync_started_at, sync_status)
    VALUES ('user1', datetime('now', '-5 minutes'), 'completed')
  ")

  # Should not allow sync (15 min interval)
  expect_false(can_sync_listings(con, "user1", 15))

  # Create old sync log (20 mins ago)
  DBI::dbExecute(con, "
    UPDATE ebay_sync_log
    SET sync_started_at = datetime('now', '-20 minutes')
    WHERE ebay_user_id = 'user1'
  ")

  # Should allow sync now
  expect_true(can_sync_listings(con, "user1", 15))
})
```

### Integration Tests

**File**: `tests/testthat/test-mod_ebay_listings_integration.R`

```r
test_that("full sync workflow updates cache", {
  # Create test database
  con <- with_test_db()

  # Initialize cache table
  initialize_ebay_cache_table(test_db_path())

  # Mock eBay API
  mock_api <- create_mock_ebay_api()

  # Run full sync
  result <- refresh_ebay_cache(con, mock_api$trading, "test_user")

  expect_true(result$success)
  expect_gt(result$items_synced, 0)

  # Verify data in cache
  cached_data <- get_cached_listings(con, "test_user")
  expect_gt(nrow(cached_data), 0)
  expect_true(all(!is.na(cached_data$synced_at)))
})
```

## Implementation Phases

### PHASE 1: Database Cache Table (1 hour)
**Goal**: Create `ebay_listings_cache` table and migration logic.

**Tasks**:
1. Add `initialize_ebay_cache_table()` to `ebay_database_extension.R`
2. Add cache table creation SQL
3. Add indexes for performance
4. Test table initialization
5. Write unit tests

**Success Criteria**:
- ✅ Cache table created automatically
- ✅ Indexes created
- ✅ Tests pass

**Files Modified**:
- `R/ebay_database_extension.R`
- `tests/testthat/test-ebay_database_extension.R`

---

### PHASE 2: Cache Management Functions (2 hours)
**Goal**: Implement cache refresh and retrieval functions.

**Tasks**:
1. Implement `refresh_ebay_cache()`
2. Implement `get_cached_listings()`
3. Implement `map_ebay_status()`
4. Implement `extract_sku_from_title()`
5. Update `fetch_seller_listings()` if needed
6. Write comprehensive unit tests

**Success Criteria**:
- ✅ Cache refresh clears old data and inserts new
- ✅ Status mapping works correctly
- ✅ SKU extraction detects patterns
- ✅ Rate limiting enforced
- ✅ Tests pass

**Files Modified**:
- `R/ebay_sync_helpers.R`
- `tests/testthat/test-ebay_sync_helpers.R`

---

### PHASE 3: Module Refactor (3 hours)
**Goal**: Refactor `mod_ebay_listings` to use cache table exclusively.

**Tasks**:
1. Update server function to use `get_cached_listings()`
2. Update refresh handler to use `refresh_ebay_cache()`
3. Add countdown timer UI component
4. Add rate limit enforcement to refresh button
5. Update datatable rendering for cache data structure
6. Update stats display
7. Test module in isolation

**Success Criteria**:
- ✅ Module shows only cached data
- ✅ Refresh button disabled during cooldown
- ✅ Countdown timer updates reactively
- ✅ Filters work correctly
- ✅ Tests pass

**Files Modified**:
- `R/mod_ebay_listings.R`
- `tests/testthat/test-mod_ebay_listings.R`

---

### PHASE 4: UI Enhancements (1 hour)
**Goal**: Improve visual feedback and UX.

**Tasks**:
1. Add countdown timer display
2. Style refresh button states (enabled/disabled)
3. Add loading spinner during sync
4. Update stats display to prioritize Active/Sold
5. Add informational alert about API-only data
6. Test responsive design

**Success Criteria**:
- ✅ Countdown timer visible and updates
- ✅ Button states clear (enabled/disabled)
- ✅ Loading spinner appears during sync
- ✅ Stats prioritize key metrics
- ✅ Mobile-friendly layout

**Files Modified**:
- `R/mod_ebay_listings.R` (UI function)
- `inst/app/www/custom.css` (if needed)

---

### PHASE 5: Testing & Documentation (1 hour)
**Goal**: Comprehensive testing and documentation.

**Tasks**:
1. Run critical test suite
2. Manual sandbox testing
3. Test rate limiting (wait 15 mins, try refresh)
4. Test with empty cache
5. Test with 100+ items
6. Write serena memory file
7. Update INDEX.md

**Success Criteria**:
- ✅ All tests pass
- ✅ No bugs in manual testing
- ✅ Rate limiting works correctly
- ✅ Documentation complete

**Files Created/Modified**:
- `.serena/memories/ebay_listings_api_sync_complete_YYYYMMDD.md`
- `.serena/memories/INDEX.md`

---

## Summary of Phases

| Phase | Description | Duration | Complexity |
|-------|-------------|----------|------------|
| 1 | Database Cache Table | 1h | LOW |
| 2 | Cache Management Functions | 2h | MEDIUM |
| 3 | Module Refactor | 3h | HIGH |
| 4 | UI Enhancements | 1h | LOW |
| 5 | Testing & Documentation | 1h | MEDIUM |

**Total Estimated Time**: 8 hours

## Success Metrics

1. **Functional Completeness**:
   - ✅ Shows ONLY eBay API data (not local drafts)
   - ✅ Cache table stores latest API response
   - ✅ Rate limiting enforced (15 min minimum)
   - ✅ Countdown timer accurate
   - ✅ Active and Sold listings prioritized

2. **Performance**:
   - ✅ Cache refresh < 10 seconds (200 items)
   - ✅ Datatable render < 1 second
   - ✅ Countdown updates without lag

3. **Reliability**:
   - ✅ No API rate limit errors (429)
   - ✅ Graceful error handling
   - ✅ No data loss during refresh

4. **Testing**:
   - ✅ All critical tests pass
   - ✅ Manual testing successful
   - ✅ Rate limiting verified

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| User frustrated by 15-min wait | HIGH | MEDIUM | Clear countdown timer, explain eBay limits |
| Cache table grows too large | LOW | MEDIUM | Implement automatic cleanup (30-day old data) |
| API call fails mid-refresh | MEDIUM | HIGH | Atomic transactions, rollback on error |
| Missing data in cache | LOW | LOW | Add "View on eBay" links to listing |

## Future Enhancements (Out of Scope)

1. **Differential Sync**: Only update changed items (not full cache clear)
2. **Multi-User Cache**: Share cache across users with same eBay account
3. **Offline Mode**: Display stale cache with warning if API unavailable
4. **Push Notifications**: Alert when sold item detected
5. **Historical Tracking**: Store cache snapshots over time for analytics

## Conclusion

This PRP transforms the eBay Listings Viewer into a pure API-driven interface with smart caching and strict rate limiting. The key innovation is the dedicated `ebay_listings_cache` table that stores ONLY eBay API data, providing a single source of truth for listing status.

**Key Benefits**:
- **Accuracy**: Always shows real eBay data (no stale local drafts)
- **Performance**: Cached data loads instantly, API refresh controlled
- **Compliance**: Respects eBay rate limits with visual countdown
- **Focus**: Prioritizes Active and Sold listings (most important statuses)

**Expected Outcome**: Users can confidently view their eBay listings with fresh, accurate data while staying well within API rate limits. The countdown timer provides transparency and prevents frustration.

---

**Ready for Implementation**: Yes
**Next Step**: Review PRP with user, then proceed with Phase 1 (Database Cache Table)
