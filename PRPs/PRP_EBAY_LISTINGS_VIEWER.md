# PRP: eBay Listings Viewer & Management

**Date**: 2025-11-02
**Status**: DRAFT - Ready for Implementation
**Priority**: HIGH
**Complexity**: MEDIUM

## Executive Summary

Create a comprehensive eBay Listings Viewer that consolidates and displays all eBay listings (both stamps and postal cards) with rich data from multiple sources: local database, eBay Trading API, and eBay Inventory API (legacy). The viewer will provide a unified interface to monitor, manage, and refresh listing data with intelligent rate limiting and caching.

## Context & Motivation

### Current State
- eBay listings are created from both postal cards (`mod_delcampe_export`) and stamps (`mod_stamp_export`)
- Listings are saved to local database (`ebay_listings` table) with comprehensive metadata
- No unified view of all eBay listings across both item types
- No way to sync listing status with eBay (views, watchers, bids, sold status)
- No refresh mechanism to fetch latest data from eBay API

### User Need
**Primary Goal**: View and manage all eBay listings (stamps + postcards) in a single, filterable, sortable datatable with rich information from eBay API.

**Key Requirements**:
1. **Unified View**: See all listings regardless of item type (stamp/postcard)
2. **Rich Data**: Show eBay metrics (views, watchers, bids, sales, time remaining)
3. **Smart Refresh**: Update from eBay API without hitting rate limits
4. **Easy Navigation**: Click to open eBay listing, filter by status/type, search by keyword
5. **Performance Tracking**: Identify best performers (most views, watchers, bids)

## Technical Architecture

### Data Sources

#### 1. Local Database (Primary - Always Available)
**Table**: `ebay_listings`
**Key Fields**:
- `listing_id`, `card_id`, `session_id`
- `ebay_item_id` (eBay ItemID - required for API sync)
- `sku` (unique identifier)
- `status` (draft/listed/sold/ended/error)
- `environment` (sandbox/production)
- `title`, `description`, `price`, `condition`
- `listing_type` (fixed_price/auction)
- `listing_duration` (GTC/3/5/7/10 days)
- `schedule_time`, `is_scheduled`, `actual_start_time`
- `api_type` (trading/inventory)
- `created_at`, `listed_at`, `last_updated`
- `listing_url`, `image_urls`, `aspects`

#### 2. eBay Trading API (Primary Sync Source - Active Listings)
**API Call**: `GetSellerList` (recommended) or `GetMyeBaySelling`
**Rate Limit**: 5,000 calls/day
**Data Retrieved**:
- Item details (title, price, condition, category)
- Listing status (Active, Ended, Sold)
- Time remaining (for auctions/scheduled end)
- Bid count, current price (for auctions)
- Watch count (if enabled)
- Quantity sold (for fixed price)
- Start time, end time
- View count (if available)
- Listing URL

**XML Request Example** (GetSellerList):
```xml
<GetSellerListRequest xmlns="urn:ebay:apis:eBLBaseComponents">
  <RequesterCredentials>
    <eBayAuthToken>{token}</eBayAuthToken>
  </RequesterCredentials>
  <DetailLevel>ReturnAll</DetailLevel>
  <StartTimeFrom>{start_date}</StartTimeFrom>
  <StartTimeTo>{end_date}</StartTimeTo>
  <Pagination>
    <EntriesPerPage>200</EntriesPerPage>
    <PageNumber>1</PageNumber>
  </Pagination>
  <IncludeWatchCount>true</IncludeWatchCount>
</GetSellerListRequest>
```

**Response Fields**:
- `<ItemID>` - eBay Item ID
- `<Title>` - Listing title
- `<SellingStatus><CurrentPrice>` - Current price
- `<SellingStatus><BidCount>` - Number of bids (auctions)
- `<SellingStatus><ListingStatus>` - Active/Completed/Ended
- `<SellingStatus><QuantitySold>` - Items sold
- `<WatchCount>` - Number of watchers
- `<TimeLeft>` - Time remaining (e.g., "P3DT2H30M")
- `<HitCount>` - View count
- `<ListingDetails><ViewItemURL>` - Direct link

#### 3. Item Type Detection (Stamp vs Postcard)
**Strategy**: Join with `postal_cards` table on `card_id`
- If `card_id` exists in `postal_cards` → Postcard
- If `card_id` does NOT exist in `postal_cards` → Stamp
- Store as computed column `item_type` in UI dataframe

### Data Consolidation Strategy

#### Step 1: Load Local Database Records
```r
get_all_ebay_listings <- function(con) {
  DBI::dbGetQuery(con, "
    SELECT
      el.*,
      CASE
        WHEN pc.card_id IS NOT NULL THEN 'Postcard'
        ELSE 'Stamp'
      END as item_type,
      pc.combined_image_path as image_path
    FROM ebay_listings el
    LEFT JOIN postal_cards pc ON el.card_id = pc.card_id
    WHERE el.status IN ('listed', 'sold', 'ended')
    ORDER BY el.listed_at DESC
  ")
}
```

#### Step 2: Enrich with eBay Trading API Data (On Refresh)
```r
sync_ebay_listings <- function(ebay_api, local_listings) {
  # Only sync listings with ebay_item_id (actually listed on eBay)
  listable <- local_listings[!is.na(local_listings$ebay_item_id), ]

  # Batch API call (GetSellerList) - up to 200 items per call
  ebay_data <- fetch_seller_listings(ebay_api,
                                     start_date = Sys.Date() - 90, # Last 90 days
                                     end_date = Sys.Date())

  # Match by ebay_item_id and merge
  merged <- merge(local_listings, ebay_data,
                  by.x = "ebay_item_id", by.y = "ItemID",
                  all.x = TRUE, suffixes = c("_local", "_ebay"))

  # Prefer eBay data for dynamic fields
  merged$current_price <- coalesce(merged$current_price_ebay, merged$price_local)
  merged$listing_status <- coalesce(merged$status_ebay, merged$status_local)
  merged$watch_count <- merged$watch_count_ebay
  merged$view_count <- merged$view_count_ebay
  merged$bid_count <- merged$bid_count_ebay
  merged$time_remaining <- merged$time_remaining_ebay

  return(merged)
}
```

#### Step 3: Display in DT::datatable
```r
render_listings_table <- function(data) {
  DT::datatable(
    data,
    selection = "single",
    filter = "top",
    extensions = c("Buttons", "Responsive"),
    options = list(
      dom = "Bfrtip",
      buttons = c("copy", "csv", "excel"),
      pageLength = 25,
      order = list(list(column_index_of_listed_at, "desc")),
      columnDefs = list(
        list(targets = "_all", className = "dt-center")
      )
    ),
    escape = FALSE  # Allow HTML in cells (for links, badges)
  )
}
```

### Database Extension

#### New Table: `ebay_sync_log`
Track refresh operations to implement intelligent caching.

```sql
CREATE TABLE IF NOT EXISTS ebay_sync_log (
  sync_id INTEGER PRIMARY KEY AUTOINCREMENT,
  sync_started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  sync_completed_at DATETIME,
  items_synced INTEGER,
  api_calls_made INTEGER,
  sync_status TEXT DEFAULT 'in_progress', -- in_progress/completed/failed
  error_message TEXT,
  ebay_user_id TEXT,  -- Which eBay account was synced
  FOREIGN KEY (ebay_user_id) REFERENCES ebay_users(ebay_user_id)
);

CREATE INDEX idx_sync_log_user ON ebay_sync_log(ebay_user_id);
CREATE INDEX idx_sync_log_started ON ebay_sync_log(sync_started_at);
```

#### New Columns in `ebay_listings` (Optional - For Caching)
These columns cache eBay API data to avoid unnecessary API calls.

```sql
ALTER TABLE ebay_listings ADD COLUMN watch_count INTEGER DEFAULT 0;
ALTER TABLE ebay_listings ADD COLUMN view_count INTEGER DEFAULT 0;
ALTER TABLE ebay_listings ADD COLUMN bid_count INTEGER DEFAULT 0;
ALTER TABLE ebay_listings ADD COLUMN current_price REAL;
ALTER TABLE ebay_listings ADD COLUMN time_remaining TEXT;
ALTER TABLE ebay_listings ADD COLUMN last_synced_at DATETIME;
```

**Migration Strategy**: Add columns in `initialize_ebay_tables()` with `IF NOT EXISTS` checks (same pattern as existing migrations).

### Refresh Mechanism with Rate Limiting

#### Strategy: Smart Refresh with Tiered Caching

**Tier 1: Instant (No API Call)**
- Show cached database values
- Display last sync time
- Use case: Initial page load, frequent refreshes

**Tier 2: Stale Cache Refresh (API Call)**
- Trigger: Last sync > 15 minutes ago OR user clicks "Refresh" button
- Action: Call `GetSellerList` for all active listings
- Rate limit: Max 1 call per 15 minutes per user
- Update: Refresh all cached fields in database

**Tier 3: On-Demand Single Item Refresh (API Call)**
- Trigger: User clicks "Refresh" icon on specific row
- Action: Call `GetItem` for single item
- Rate limit: Max 1 call per 5 minutes per item
- Update: Refresh single row in database

#### Implementation: Rate Limiter

```r
can_sync_listings <- function(con, ebay_user_id, min_interval_minutes = 15) {
  last_sync <- DBI::dbGetQuery(con, "
    SELECT sync_started_at
    FROM ebay_sync_log
    WHERE ebay_user_id = ? AND sync_status = 'completed'
    ORDER BY sync_started_at DESC
    LIMIT 1
  ", list(ebay_user_id))

  if (nrow(last_sync) == 0) return(TRUE)

  last_sync_time <- as.POSIXct(last_sync$sync_started_at)
  time_since_sync <- difftime(Sys.time(), last_sync_time, units = "mins")

  return(as.numeric(time_since_sync) >= min_interval_minutes)
}

log_sync_start <- function(con, ebay_user_id) {
  DBI::dbExecute(con, "
    INSERT INTO ebay_sync_log (ebay_user_id, sync_status)
    VALUES (?, 'in_progress')
  ", list(ebay_user_id))

  return(DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS sync_id")$sync_id)
}

log_sync_complete <- function(con, sync_id, items_synced, api_calls) {
  DBI::dbExecute(con, "
    UPDATE ebay_sync_log
    SET sync_completed_at = CURRENT_TIMESTAMP,
        items_synced = ?,
        api_calls_made = ?,
        sync_status = 'completed'
    WHERE sync_id = ?
  ", list(items_synced, api_calls, sync_id))
}
```

### UI/UX Design

#### Module Structure
**Module Name**: `mod_ebay_listings`
**Files**:
- `R/mod_ebay_listings.R` - Main module (UI + Server)
- `R/ebay_sync_helpers.R` - Sync functions (GetSellerList, GetItem, rate limiting)
- `tests/testthat/test-mod_ebay_listings.R` - Unit tests

#### UI Components

##### Top Bar (Filters & Actions)
```
+------------------------------------------------------------------+
| [🔄 Refresh All]  [📊 Stats]    Last synced: 14 mins ago       |
|                                                                  |
| Filter: [Status ▼] [Type ▼] [Duration ▼]  Search: [.........] |
+------------------------------------------------------------------+
```

##### Main Datatable (Columns)
| Column | Type | Description | Source | Width |
|--------|------|-------------|--------|-------|
| **Thumbnail** | Image | Item image preview | `image_urls` | 60px |
| **Title** | Link | Clickable title → eBay listing | `title` + `listing_url` | 300px |
| **Type** | Badge | Stamp / Postcard | Computed | 80px |
| **Price** | Currency | Current/starting price | `current_price` or `price` | 80px |
| **Status** | Badge | Listed / Sold / Ended / Scheduled | `status` | 100px |
| **Format** | Badge | Fixed Price / Auction | `listing_type` | 100px |
| **Duration** | Text | GTC / 3d / 5d / 7d / 10d | `listing_duration` | 80px |
| **Views** | Number | Total views | `view_count` | 60px |
| **Watchers** | Number | Current watchers | `watch_count` | 80px |
| **Bids** | Number | Bid count (auctions) | `bid_count` | 60px |
| **Time Left** | Dynamic | Time remaining (auctions) | `time_remaining` | 100px |
| **Listed** | Date | Date listed on eBay | `listed_at` | 100px |
| **Actions** | Buttons | [🔄] [📊] [🗑️] | N/A | 100px |

##### Status Badges (Color-Coded)
- **Listed** → 🟢 Green
- **Scheduled** → 🟡 Yellow
- **Sold** → 🔵 Blue
- **Ended** → ⚪ Gray
- **Error** → 🔴 Red

##### Row Actions
- **🔄 Refresh** - Sync single item with eBay (if >5 mins since last sync)
- **📊 Details** - Show expanded modal with full listing data
- **🗑️ Delete** - Remove from database (not from eBay - requires manual eBay action)

#### Wireframe

```
┌──────────────────────────────────────────────────────────────────┐
│  eBay Listings Viewer                                 [🔄 Refresh]│
│                                                                    │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ Total: 47  |  Active: 32  |  Sold: 8  |  Scheduled: 7      │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                    │
│  Filter: [All Status ▼] [All Types ▼] [All Durations ▼]         │
│  Search: [.........................]                 [Clear]      │
│                                                                    │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ 📷 | Title                    | Type  | Price | Status    | │ │
│  ├───┼─────────────────────────┼───────┼───────┼───────────┼ │ │
│  │[🖼]│ AUSTRIA 1912 PARCEL...  │ 🟦Card│ $6.50 │ 🟢 Listed  │ │ │
│  │   │ Views: 45  Watchers: 3   │       │       │ 2d left   │ │ │
│  │   │                          │       │       │ [🔄📊🗑️]  │ │ │
│  ├───┼─────────────────────────┼───────┼───────┼───────────┼ │ │
│  │[🖼]│ USA STAMP 1920 LINCOLN..│ 🟧Stmp│ $2.50 │ 🔵 Sold    │ │ │
│  │   │ Views: 67  Watchers: 5   │       │ $4.25 │ Oct 25    │ │ │
│  │   │ Bids: 8                  │       │       │ [📊]      │ │ │
│  ├───┼─────────────────────────┼───────┼───────┼───────────┼ │ │
│  │[🖼]│ ROMANIA POSTCARD 1930.. │ 🟦Card│ $8.00 │ 🟡 Sched   │ │ │
│  │   │ Starts: Nov 3 10:00 AM   │       │       │ Nov 3     │ │ │
│  │   │                          │       │       │ [📊🗑️]   │ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                    │
│  Showing 1-25 of 47   [< 1 2 >]                     [Export CSV]  │
└──────────────────────────────────────────────────────────────────┘
```

### eBay API Integration Details

#### Function: `fetch_seller_listings()`

**Purpose**: Retrieve all active listings for the authenticated seller.

**API Call**: `GetSellerList` (Trading API)

**Implementation**:
```r
fetch_seller_listings <- function(ebay_api, start_date, end_date, page_number = 1) {
  # Build XML request
  xml_body <- sprintf('
    <GetSellerListRequest xmlns="urn:ebay:apis:eBLBaseComponents">
      <RequesterCredentials>
        <eBayAuthToken>%s</eBayAuthToken>
      </RequesterCredentials>
      <DetailLevel>ReturnAll</DetailLevel>
      <StartTimeFrom>%s</StartTimeFrom>
      <StartTimeTo>%s</StartTimeTo>
      <Pagination>
        <EntriesPerPage>200</EntriesPerPage>
        <PageNumber>%d</PageNumber>
      </Pagination>
      <IncludeWatchCount>true</IncludeWatchCount>
    </GetSellerListRequest>
  ',
  ebay_api$oauth$get_access_token(),
  format(start_date, "%Y-%m-%dT%H:%M:%S.000Z"),
  format(end_date, "%Y-%m-%dT%H:%M:%S.000Z"),
  page_number)

  # Make request
  response <- ebay_api$trading$make_request(xml_body, "GetSellerList")

  # Parse XML response
  items <- parse_seller_list_response(response)

  # Handle pagination (if HasMoreItems = true)
  if (items$has_more_items) {
    next_page <- fetch_seller_listings(ebay_api, start_date, end_date, page_number + 1)
    items$items <- c(items$items, next_page$items)
  }

  return(items)
}

parse_seller_list_response <- function(xml_response) {
  doc <- xml2::read_xml(xml_response)

  # Check Ack
  ack <- xml2::xml_text(xml2::xml_find_first(doc, "//Ack"))
  if (ack != "Success" && ack != "Warning") {
    error_msg <- xml2::xml_text(xml2::xml_find_first(doc, "//LongMessage"))
    stop("GetSellerList failed: ", error_msg)
  }

  # Extract items
  item_nodes <- xml2::xml_find_all(doc, "//ItemArray/Item")
  items <- lapply(item_nodes, function(item) {
    list(
      ItemID = xml2::xml_text(xml2::xml_find_first(item, "./ItemID")),
      Title = xml2::xml_text(xml2::xml_find_first(item, "./Title")),
      CurrentPrice = as.numeric(xml2::xml_text(xml2::xml_find_first(item, "./SellingStatus/CurrentPrice"))),
      ListingStatus = xml2::xml_text(xml2::xml_find_first(item, "./SellingStatus/ListingStatus")),
      QuantitySold = as.integer(xml2::xml_text(xml2::xml_find_first(item, "./SellingStatus/QuantitySold"))),
      BidCount = as.integer(xml2::xml_text(xml2::xml_find_first(item, "./SellingStatus/BidCount"))),
      WatchCount = as.integer(xml2::xml_text(xml2::xml_find_first(item, "./WatchCount"))),
      HitCount = as.integer(xml2::xml_text(xml2::xml_find_first(item, "./HitCount"))),
      TimeLeft = xml2::xml_text(xml2::xml_find_first(item, "./TimeLeft")),
      ViewItemURL = xml2::xml_text(xml2::xml_find_first(item, "./ListingDetails/ViewItemURL"))
    )
  })

  # Check for more items
  has_more <- xml2::xml_text(xml2::xml_find_first(doc, "//HasMoreItems")) == "true"

  return(list(items = items, has_more_items = has_more))
}
```

#### Function: `fetch_single_item()`

**Purpose**: Retrieve detailed data for a single item (on-demand refresh).

**API Call**: `GetItem` (Trading API)

**Implementation**:
```r
fetch_single_item <- function(ebay_api, ebay_item_id) {
  xml_body <- sprintf('
    <GetItemRequest xmlns="urn:ebay:apis:eBLBaseComponents">
      <RequesterCredentials>
        <eBayAuthToken>%s</eBayAuthToken>
      </RequesterCredentials>
      <ItemID>%s</ItemID>
      <DetailLevel>ReturnAll</DetailLevel>
      <IncludeWatchCount>true</IncludeWatchCount>
    </GetItemRequest>
  ',
  ebay_api$oauth$get_access_token(),
  ebay_item_id)

  response <- ebay_api$trading$make_request(xml_body, "GetItem")

  # Parse single item (similar to parse_seller_list_response)
  doc <- xml2::read_xml(response)
  item <- xml2::xml_find_first(doc, "//Item")

  # Extract and return item data
  return(list(
    ItemID = xml2::xml_text(xml2::xml_find_first(item, "./ItemID")),
    # ... (same fields as parse_seller_list_response)
  ))
}
```

### Module Implementation (Shiny)

#### UI Function

```r
mod_ebay_listings_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Header card with stats and refresh button
    bslib::card(
      bslib::card_header("eBay Listings Viewer"),
      bslib::card_body(
        fluidRow(
          column(10,
            uiOutput(ns("stats_display"))
          ),
          column(2,
            actionButton(ns("refresh_all"), "🔄 Refresh All",
                        class = "btn-primary", width = "100%")
          )
        ),

        # Filters
        fluidRow(
          column(3,
            selectInput(ns("filter_status"), "Status",
                       choices = c("All", "Listed", "Scheduled", "Sold", "Ended", "Error"),
                       selected = "All")
          ),
          column(3,
            selectInput(ns("filter_type"), "Type",
                       choices = c("All", "Postcard", "Stamp"),
                       selected = "All")
          ),
          column(3,
            selectInput(ns("filter_format"), "Format",
                       choices = c("All", "Fixed Price", "Auction"),
                       selected = "All")
          ),
          column(3,
            textInput(ns("search_text"), "Search",
                     placeholder = "Search title or SKU...")
          )
        )
      )
    ),

    # Main datatable
    bslib::card(
      bslib::card_body(
        DT::dataTableOutput(ns("listings_table"))
      )
    )
  )
}
```

#### Server Function

```r
mod_ebay_listings_server <- function(id, ebay_api, session_id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive: Load listings from database
    listings_data <- reactiveVal(NULL)

    # Load initial data on module start
    observe({
      con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
      on.exit(DBI::dbDisconnect(con))

      data <- get_all_ebay_listings(con)
      listings_data(data)
    })

    # Refresh all listings from eBay API
    observeEvent(input$refresh_all, {
      con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
      on.exit(DBI::dbDisconnect(con))

      # Get eBay user ID from session
      ebay_user_id <- get_ebay_user_id_from_session(con, session_id)

      # Check rate limit
      if (!can_sync_listings(con, ebay_user_id, min_interval_minutes = 15)) {
        showNotification("Please wait 15 minutes between full refreshes.",
                        type = "warning")
        return()
      }

      # Start sync
      sync_id <- log_sync_start(con, ebay_user_id)

      tryCatch({
        # Fetch from eBay
        ebay_data <- fetch_seller_listings(
          ebay_api,
          start_date = Sys.Date() - 90,
          end_date = Sys.Date()
        )

        # Update database cache
        update_listings_cache(con, ebay_data$items)

        # Log success
        log_sync_complete(con, sync_id, length(ebay_data$items), 1)

        # Reload data
        data <- get_all_ebay_listings(con)
        listings_data(data)

        showNotification(sprintf("✅ Synced %d listings from eBay",
                                length(ebay_data$items)),
                        type = "message")
      }, error = function(e) {
        log_sync_error(con, sync_id, e$message)
        showNotification(paste("Error syncing:", e$message), type = "error")
      })
    })

    # Filtered data (based on user filters)
    filtered_data <- reactive({
      req(listings_data())
      data <- listings_data()

      # Apply status filter
      if (input$filter_status != "All") {
        data <- data[data$status == tolower(input$filter_status), ]
      }

      # Apply type filter
      if (input$filter_type != "All") {
        data <- data[data$item_type == input$filter_type, ]
      }

      # Apply format filter
      if (input$filter_format != "All") {
        format_value <- ifelse(input$filter_format == "Fixed Price",
                               "fixed_price", "auction")
        data <- data[data$listing_type == format_value, ]
      }

      # Apply search filter
      if (nzchar(input$search_text)) {
        search_pattern <- tolower(input$search_text)
        data <- data[grepl(search_pattern, tolower(data$title)) |
                    grepl(search_pattern, tolower(data$sku)), ]
      }

      return(data)
    })

    # Render stats
    output$stats_display <- renderUI({
      req(listings_data())
      data <- listings_data()

      total <- nrow(data)
      active <- sum(data$status == "listed", na.rm = TRUE)
      sold <- sum(data$status == "sold", na.rm = TRUE)
      scheduled <- sum(data$status == "scheduled", na.rm = TRUE)

      tagList(
        tags$div(class = "stats-row",
          tags$span(class = "stat-item", paste("Total:", total)),
          tags$span(class = "stat-item", paste("Active:", active)),
          tags$span(class = "stat-item", paste("Sold:", sold)),
          tags$span(class = "stat-item", paste("Scheduled:", scheduled))
        )
      )
    })

    # Render datatable
    output$listings_table <- DT::renderDataTable({
      req(filtered_data())
      data <- filtered_data()

      # Prepare display data
      display_data <- data.frame(
        Thumbnail = sprintf('<img src="%s" height="50">', data$image_path),
        Title = sprintf('<a href="%s" target="_blank">%s</a>',
                       data$listing_url, data$title),
        Type = ifelse(data$item_type == "Postcard", "🟦 Card", "🟧 Stamp"),
        Price = sprintf("$%.2f", data$price),
        Status = render_status_badge(data$status),
        Format = ifelse(data$listing_type == "fixed_price", "Fixed", "Auction"),
        Views = data$view_count,
        Watchers = data$watch_count,
        Bids = data$bid_count,
        Listed = format(as.Date(data$listed_at), "%b %d"),
        stringsAsFactors = FALSE
      )

      DT::datatable(
        display_data,
        selection = "single",
        filter = "none",
        escape = FALSE,
        options = list(
          pageLength = 25,
          order = list(list(9, "desc")),  # Sort by Listed date descending
          dom = "Bfrtip",
          buttons = c("copy", "csv", "excel")
        ),
        extensions = "Buttons"
      )
    })
  })
}

# Helper function for status badges
render_status_badge <- function(status) {
  badges <- c(
    "listed" = '<span class="badge bg-success">🟢 Listed</span>',
    "scheduled" = '<span class="badge bg-warning">🟡 Scheduled</span>',
    "sold" = '<span class="badge bg-primary">🔵 Sold</span>',
    "ended" = '<span class="badge bg-secondary">⚪ Ended</span>',
    "error" = '<span class="badge bg-danger">🔴 Error</span>'
  )
  return(badges[status])
}
```

### Testing Strategy

#### Unit Tests (testthat)

**File**: `tests/testthat/test-mod_ebay_listings.R`

```r
test_that("get_all_ebay_listings returns correct structure", {
  con <- with_test_db()

  # Insert test data
  # ... (create test listings with postal_cards join)

  result <- get_all_ebay_listings(con)

  expect_s3_class(result, "data.frame")
  expect_true("item_type" %in% names(result))
  expect_true(all(result$item_type %in% c("Postcard", "Stamp")))
})

test_that("can_sync_listings respects rate limit", {
  con <- with_test_db()

  # Create recent sync log entry (10 mins ago)
  DBI::dbExecute(con, "
    INSERT INTO ebay_sync_log (ebay_user_id, sync_started_at, sync_status)
    VALUES ('test_user', datetime('now', '-10 minutes'), 'completed')
  ")

  # Should not allow sync (15 min interval)
  expect_false(can_sync_listings(con, "test_user", 15))

  # Should allow sync (5 min interval)
  expect_true(can_sync_listings(con, "test_user", 5))
})

test_that("parse_seller_list_response extracts all fields", {
  xml_response <- '
    <GetSellerListResponse>
      <Ack>Success</Ack>
      <ItemArray>
        <Item>
          <ItemID>123456789</ItemID>
          <Title>Test Postcard</Title>
          <SellingStatus>
            <CurrentPrice>6.50</CurrentPrice>
            <ListingStatus>Active</ListingStatus>
            <BidCount>3</BidCount>
          </SellingStatus>
          <WatchCount>5</WatchCount>
        </Item>
      </ItemArray>
      <HasMoreItems>false</HasMoreItems>
    </GetSellerListResponse>
  '

  result <- parse_seller_list_response(xml_response)

  expect_equal(length(result$items), 1)
  expect_equal(result$items[[1]]$ItemID, "123456789")
  expect_equal(result$items[[1]]$CurrentPrice, 6.50)
  expect_equal(result$items[[1]]$WatchCount, 5)
})
```

#### Integration Tests

**File**: `tests/testthat/test-ebay_sync_integration.R`

```r
test_that("full sync workflow updates database", {
  con <- with_test_db()

  # Create test listings
  # ... (setup test data)

  # Mock eBay API response
  with_mocked_ebay_api({
    # Run sync
    sync_id <- log_sync_start(con, "test_user")
    ebay_data <- fetch_seller_listings(mock_ebay_api, Sys.Date() - 30, Sys.Date())
    update_listings_cache(con, ebay_data$items)
    log_sync_complete(con, sync_id, length(ebay_data$items), 1)

    # Verify database updated
    updated <- DBI::dbGetQuery(con, "
      SELECT * FROM ebay_listings WHERE ebay_item_id = '123456789'
    ")

    expect_equal(updated$watch_count, 5)
    expect_equal(updated$view_count, 45)
  })
})
```

### Critical Tests

Add to `dev/run_critical_tests.R`:
```r
# eBay Listings Viewer tests (critical)
testthat::test_file("tests/testthat/test-mod_ebay_listings.R")
testthat::test_file("tests/testthat/test-ebay_sync_helpers.R")
```

## Implementation Phases

### PHASE 1: Database Extension (2 hours)
**Goal**: Add sync logging and caching columns.

**Tasks**:
1. Add `ebay_sync_log` table to `initialize_ebay_tables()`
2. Add caching columns to `ebay_listings` (watch_count, view_count, etc.)
3. Write migration logic in `R/ebay_database_extension.R`
4. Test migrations with existing database
5. Write unit tests for database functions

**Success Criteria**:
- ✅ New table and columns created automatically
- ✅ Existing databases migrate without data loss
- ✅ Tests pass for table initialization

**Files Modified**:
- `R/ebay_database_extension.R`
- `tests/testthat/test-ebay_database_extension.R`

---

### PHASE 2: eBay API Sync Helpers (3 hours)
**Goal**: Implement functions to fetch listing data from eBay Trading API.

**Tasks**:
1. Create `R/ebay_sync_helpers.R`
2. Implement `fetch_seller_listings()` (GetSellerList)
3. Implement `parse_seller_list_response()`
4. Implement `fetch_single_item()` (GetItem)
5. Implement rate limiting functions (can_sync_listings, log_sync_start, etc.)
6. Implement `update_listings_cache()` to write eBay data to database
7. Write unit tests with mocked eBay responses

**Success Criteria**:
- ✅ `fetch_seller_listings()` returns correct data structure
- ✅ XML parsing extracts all required fields
- ✅ Rate limiting prevents excessive API calls
- ✅ Database cache updates correctly
- ✅ Tests pass with mocked API responses

**Files Created**:
- `R/ebay_sync_helpers.R`
- `tests/testthat/test-ebay_sync_helpers.R`

---

### PHASE 3: Data Consolidation Layer (2 hours)
**Goal**: Merge local database with eBay API data.

**Tasks**:
1. Implement `get_all_ebay_listings()` (SQL query with JOIN)
2. Implement `sync_ebay_listings()` (merge eBay data with local)
3. Implement `render_status_badge()` and other display helpers
4. Test item type detection (Postcard vs Stamp)
5. Write unit tests for consolidation logic

**Success Criteria**:
- ✅ Query correctly identifies item type (Postcard/Stamp)
- ✅ Merge logic prefers eBay data for dynamic fields
- ✅ Missing eBay data gracefully falls back to local data
- ✅ Tests pass for edge cases (missing images, NULL fields)

**Files Modified**:
- `R/ebay_sync_helpers.R` (add consolidation functions)
- `tests/testthat/test-ebay_sync_helpers.R`

---

### PHASE 4: UI Module Implementation (4 hours)
**Goal**: Create Shiny module for listings viewer.

**Tasks**:
1. Create `R/mod_ebay_listings.R`
2. Implement UI function (filters, stats, datatable)
3. Implement server function (reactive data loading, filtering)
4. Implement "Refresh All" button with rate limiting
5. Add CSS for badges and stats display
6. Test filtering logic (status, type, format, search)
7. Test datatable rendering with various data sizes

**Success Criteria**:
- ✅ Module displays all listings correctly
- ✅ Filters work correctly (status, type, format, search)
- ✅ Stats display updates reactively
- ✅ Refresh button respects rate limits
- ✅ Datatable is responsive and performant

**Files Created**:
- `R/mod_ebay_listings.R`
- `tests/testthat/test-mod_ebay_listings.R`

---

### PHASE 5: Trading API Extension (2 hours)
**Goal**: Add GetSellerList and GetItem methods to EbayTradingAPI class.

**Tasks**:
1. Modify `R/ebay_trading_api.R`
2. Add `get_seller_list()` method to EbayTradingAPI R6 class
3. Add `get_item()` method to EbayTradingAPI R6 class
4. Update `make_request()` to handle new call names
5. Write unit tests for new methods

**Success Criteria**:
- ✅ GetSellerList returns valid XML response
- ✅ GetItem returns valid XML response
- ✅ Tests pass with mocked HTTP responses

**Files Modified**:
- `R/ebay_trading_api.R`
- `tests/testthat/test-ebay_trading_api.R`

---

### PHASE 6: App Integration (1 hour)
**Goal**: Add eBay Listings menu item to main app.

**Tasks**:
1. Modify `inst/app/app.R` (or main UI file)
2. Add "eBay Listings" menu item in navigation
3. Call `mod_ebay_listings_ui()` and `mod_ebay_listings_server()`
4. Pass `ebay_api` and `session_id` to module
5. Test navigation and module initialization

**Success Criteria**:
- ✅ Menu item appears in app navigation
- ✅ Clicking menu loads module UI
- ✅ Module displays initial data from database
- ✅ No console errors on load

**Files Modified**:
- `inst/app/app.R` (or equivalent)

---

### PHASE 7: Testing & Refinement (2 hours)
**Goal**: Comprehensive testing and bug fixes.

**Tasks**:
1. Run critical test suite (`dev/run_critical_tests.R`)
2. Manual sandbox testing:
   - Create test listings (stamps + postcards)
   - Test full refresh
   - Test filters and search
   - Test rate limiting (wait 15 mins, try again)
   - Test with empty database
3. Fix any bugs discovered
4. Performance testing with 100+ listings
5. Write serena memory file

**Success Criteria**:
- ✅ All critical tests pass
- ✅ Manual testing reveals no major bugs
- ✅ Performance acceptable with large datasets
- ✅ Documentation complete

**Files Created**:
- `.serena/memories/ebay_listings_viewer_complete_YYYYMMDD.md`

---

## Summary of Phases

| Phase | Description | Duration | Complexity | Dependencies |
|-------|-------------|----------|------------|--------------|
| 1 | Database Extension | 2h | LOW | None |
| 2 | eBay API Sync Helpers | 3h | MEDIUM | Phase 1 |
| 3 | Data Consolidation | 2h | MEDIUM | Phase 1, 2 |
| 4 | UI Module | 4h | HIGH | Phase 3 |
| 5 | Trading API Extension | 2h | MEDIUM | Phase 2 |
| 6 | App Integration | 1h | LOW | Phase 4 |
| 7 | Testing & Refinement | 2h | MEDIUM | All previous |

**Total Estimated Time**: 16 hours

## API Rate Limits & Costs

### eBay Trading API Limits
- **Free Tier**: 5,000 calls/day
- **GetSellerList**: Returns up to 200 items per call
- **Estimated Usage**:
  - Full refresh (200 items): 1 call
  - Full refresh (1000 items): 5 calls
  - Single item refresh: 1 call per item

### Refresh Strategy Efficiency
- **Without smart caching**: 1 call per page view = 100+ calls/day
- **With smart caching**: 1 call per 15 mins = 96 calls/day (max)
- **Headroom**: 5,000 - 96 = 4,904 calls/day for other operations

## Success Metrics

1. **Functional Completeness**:
   - ✅ All listings (stamps + postcards) visible in single view
   - ✅ eBay API sync working with rate limiting
   - ✅ Filters and search operational
   - ✅ Status badges accurate

2. **Performance**:
   - ✅ Initial load < 2 seconds (100 items)
   - ✅ Filter response < 500ms
   - ✅ API sync < 10 seconds (200 items)

3. **Reliability**:
   - ✅ No API errors in normal operation
   - ✅ Graceful degradation if eBay API unavailable
   - ✅ No data loss during sync

4. **Testing**:
   - ✅ All critical tests pass
   - ✅ Manual sandbox testing successful
   - ✅ Rate limiting prevents 429 errors

## Future Enhancements (Out of Scope)

These features are NOT part of the initial implementation but may be added later:

1. **Bulk Actions**: Select multiple listings → End all, revise all, etc.
2. **Analytics Dashboard**: Charts for views over time, conversion rate, etc.
3. **Automated Re-Listing**: Automatically relist ended items
4. **Price Optimization**: Suggest price changes based on views/watchers
5. **Listing Comparison**: Compare performance of similar items
6. **Email Notifications**: Alert on sold items, watchers milestones
7. **Export to Excel**: Advanced export with custom columns
8. **Integration with Delcampe**: Compare eBay vs Delcampe performance

## Dependencies & Prerequisites

### R Packages
- `DBI`, `RSQLite` - Database access (already in DESCRIPTION)
- `xml2` - XML parsing (already in DESCRIPTION)
- `httr2` - HTTP requests (already in DESCRIPTION)
- `DT` - Interactive datatable (**ADD to DESCRIPTION**)
- `bslib` - UI components (already in DESCRIPTION)
- `shiny` - Framework (already in DESCRIPTION)

### eBay API
- OAuth tokens configured (already working via `ebay_oauth_integration`)
- Trading API credentials (same as existing)

### Database
- `tracking.sqlite` with `ebay_listings` table (already exists)
- Migrations will add new table and columns

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| eBay API rate limits exceeded | MEDIUM | HIGH | Smart caching, rate limiting, 15-min cooldown |
| Slow performance with 1000+ items | LOW | MEDIUM | Pagination, lazy loading, index optimization |
| Missing data from eBay API | MEDIUM | LOW | Fallback to local database values |
| Breaking changes to Trading API | LOW | HIGH | Monitor eBay announcements, version compatibility |

## Documentation Updates

### Memories to Create
- `.serena/memories/ebay_listings_viewer_complete_YYYYMMDD.md` - Implementation summary
- `.serena/memories/ebay_sync_strategies_YYYYMMDD.md` - API sync patterns and rate limiting

### Memories to Update
- `.serena/memories/INDEX.md` - Add new entries for listings viewer
- `.serena/memories/tech_stack_and_architecture.md` - Document new modules

### User Documentation (Optional)
- `docs/guides/ebay-listings-viewer.md` - User guide for new feature

## Conclusion

This PRP defines a comprehensive eBay Listings Viewer that consolidates stamps and postcards into a unified, data-rich view with smart API syncing and rate limiting. The modular architecture ensures maintainability, and the phased implementation minimizes risk.

**Key Innovation**: Smart caching with tiered refresh strategy balances data freshness with API efficiency, staying well within eBay's rate limits while providing near-real-time listing metrics.

**Expected Outcome**: Users can monitor all eBay listings (stamps + postcards) in one place, track performance metrics (views, watchers, bids), and refresh data on-demand without worrying about API limits.

---

**Ready for Implementation**: Yes
**Next Step**: Review PRP with user, then proceed with Phase 1 (Database Extension)
