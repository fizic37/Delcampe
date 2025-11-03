# TASK PRP: eBay Listings Viewer & Management

**Date**: 2025-11-02
**Status**: READY FOR EXECUTION
**Estimated Time**: 16 hours
**Source PRP**: PRPs/PRP_EBAY_LISTINGS_VIEWER.md

---

## Context

### Problem Statement
Users have no way to view and manage all eBay listings (stamps + postcards) in one place. Listings are created from multiple modules (`mod_delcampe_export` for postcards, `mod_stamp_export` for stamps), stored in the local database, but there's no unified interface to:
- Monitor listing performance (views, watchers, bids)
- Refresh data from eBay API
- Filter/search listings
- Track listing status across both item types

### Solution Overview
Create a comprehensive eBay Listings Viewer module that:
1. Consolidates data from local database + eBay Trading API
2. Displays all listings in a filterable, sortable interface
3. Implements smart caching with rate limiting
4. Provides on-demand refresh capabilities

### Documentation Context

**Relevant Memories:**
- `testing_infrastructure_complete_20251023` - Testing patterns and strategy
- `ebay_trading_api_implementation_complete_20251028` - Trading API structure
- `simple_tracking_viewer_complete_20251016` - Module UI/UX patterns
- `ebay_scheduled_listing_backend_complete_20251101` - Recent eBay work

**Existing Patterns:**
- **Database migrations**: `R/ebay_database_extension.R:initialize_ebay_tables()` (lines 5-97)
- **Trading API calls**: `R/ebay_trading_api.R:EbayTradingAPI` class
- **Simple viewer UI**: `R/mod_tracking_viewer.R` (252 lines, bslib cards)
- **Testing framework**: `dev/run_critical_tests.R`, `dev/run_discovery_tests.R`

**Gotchas:**
- **NEVER save backups in R/ folder** - they get loaded into R environment
- **Use Delcampe_BACKUP/** folder for all backups
- **showNotification() type values**: Only "message", "warning", "error" (NOT "default" or "success")
- **bslib > custom JavaScript** for module namespace compatibility
- **Rate limiting is critical** - eBay Trading API has 5,000 calls/day limit
- **xml2 package** is already in DESCRIPTION (from Trading API implementation)

---

## PHASE 1: Database Extension (2 hours)

### TASK 1.1: Add ebay_sync_log table
**File**: `R/ebay_database_extension.R`

**OPERATION**:
```r
# Insert after line 90 (before "Create indexes" comment)
# Add new table creation:

# eBay Sync Log table (for rate limiting)
DBI::dbExecute(con, "
  CREATE TABLE IF NOT EXISTS ebay_sync_log (
    sync_id INTEGER PRIMARY KEY AUTOINCREMENT,
    sync_started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    sync_completed_at DATETIME,
    items_synced INTEGER,
    api_calls_made INTEGER,
    sync_status TEXT DEFAULT 'in_progress',
    error_message TEXT,
    ebay_user_id TEXT,
    FOREIGN KEY (ebay_user_id) REFERENCES ebay_users(ebay_user_id)
  )
")

# Add indexes
DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_sync_log_user ON ebay_sync_log(ebay_user_id)")
DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_sync_log_started ON ebay_sync_log(sync_started_at)")
```

**VALIDATE**:
```r
# Test table creation
source("dev/test_database_migration.R")
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/test_tracking.sqlite")
initialize_ebay_tables("inst/app/data/test_tracking.sqlite")
tables <- DBI::dbListTables(con)
stopifnot("ebay_sync_log" %in% tables)

# Verify schema
schema <- DBI::dbGetQuery(con, "PRAGMA table_info(ebay_sync_log)")
required_cols <- c("sync_id", "sync_started_at", "sync_completed_at", "items_synced",
                  "api_calls_made", "sync_status", "error_message", "ebay_user_id")
stopifnot(all(required_cols %in% schema$name))
DBI::dbDisconnect(con)
```

**IF_FAIL**:
- Check SQL syntax (common error: missing comma or quote)
- Verify foreign key reference: `ebay_users(ebay_user_id)` exists
- Run: `DBI::dbGetQuery(con, "SELECT * FROM sqlite_master WHERE type='table'")` to debug

**ROLLBACK**:
```r
# Manual rollback if needed
DBI::dbExecute(con, "DROP TABLE IF EXISTS ebay_sync_log")
DBI::dbExecute(con, "DROP INDEX IF EXISTS idx_sync_log_user")
DBI::dbExecute(con, "DROP INDEX IF EXISTS idx_sync_log_started")
```

---

### TASK 1.2: Add caching columns to ebay_listings
**File**: `R/ebay_database_extension.R`

**OPERATION**:
```r
# Insert after line 73 (after actual_start_time migration)
# Add new migration section:

# Migration: Add eBay API cache columns
columns <- DBI::dbGetQuery(con, "PRAGMA table_info(ebay_listings)")
if (!"watch_count" %in% columns$name) {
  DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN watch_count INTEGER DEFAULT 0")
  message("✅ Added watch_count column to ebay_listings table")
}
if (!"view_count" %in% columns$name) {
  DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN view_count INTEGER DEFAULT 0")
  message("✅ Added view_count column to ebay_listings table")
}
if (!"bid_count" %in% columns$name) {
  DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN bid_count INTEGER DEFAULT 0")
  message("✅ Added bid_count column to ebay_listings table")
}
if (!"current_price" %in% columns$name) {
  DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN current_price REAL")
  message("✅ Added current_price column to ebay_listings table")
}
if (!"time_remaining" %in% columns$name) {
  DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN time_remaining TEXT")
  message("✅ Added time_remaining column to ebay_listings table")
}
if (!"last_synced_at" %in% columns$name) {
  DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN last_synced_at DATETIME")
  message("✅ Added last_synced_at column to ebay_listings table")
}
```

**VALIDATE**:
```r
# Verify new columns exist
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/test_tracking.sqlite")
schema <- DBI::dbGetQuery(con, "PRAGMA table_info(ebay_listings)")
new_cols <- c("watch_count", "view_count", "bid_count", "current_price",
              "time_remaining", "last_synced_at")
stopifnot(all(new_cols %in% schema$name))

# Verify defaults
DBI::dbExecute(con, "INSERT INTO ebay_listings (sku, session_id) VALUES ('TEST_SKU', 'TEST_SESSION')")
row <- DBI::dbGetQuery(con, "SELECT watch_count, view_count, bid_count FROM ebay_listings WHERE sku = 'TEST_SKU'")
stopifnot(row$watch_count == 0, row$view_count == 0, row$bid_count == 0)
DBI::dbExecute(con, "DELETE FROM ebay_listings WHERE sku = 'TEST_SKU'")
DBI::dbDisconnect(con)
```

**IF_FAIL**:
- Check column type syntax (INTEGER, REAL, TEXT, DATETIME)
- Verify DEFAULT clauses are valid
- Run migration twice - should not error on second run

**ROLLBACK**:
SQLite doesn't support DROP COLUMN, so:
```r
# Option 1: Recreate table (complex, avoid)
# Option 2: Leave columns (harmless if unused)
# Option 3: Restore from backup database
```

---

### TASK 1.3: Update save_ebay_listing to support caching
**File**: `R/ebay_database_extension.R`

**OPERATION**:
Find `save_ebay_listing` function (should be around line 120-180) and update signature:
```r
# OLD signature:
save_ebay_listing <- function(con, card_id, session_id, ebay_item_id = NULL,
                              ebay_offer_id = NULL, sku, status = "draft",
                              environment = "sandbox", title, description,
                              price, quantity = 1, condition, category_id = "914",
                              listing_url = NULL, image_urls = NULL, aspects = NULL,
                              api_type = "inventory", ...) {

# NEW signature (add cache params):
save_ebay_listing <- function(con, card_id, session_id, ebay_item_id = NULL,
                              ebay_offer_id = NULL, sku, status = "draft",
                              environment = "sandbox", title, description,
                              price, quantity = 1, condition, category_id = "914",
                              listing_url = NULL, image_urls = NULL, aspects = NULL,
                              api_type = "inventory",
                              watch_count = 0, view_count = 0, bid_count = 0,
                              current_price = NULL, time_remaining = NULL,
                              last_synced_at = NULL, ...) {

# Update INSERT statement to include new fields
# Find the INSERT INTO ebay_listings statement and add new columns/values
```

**VALIDATE**:
```r
# Test save with new params
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/test_tracking.sqlite")
result <- save_ebay_listing(con,
  card_id = 1, session_id = "test", sku = "TEST_123",
  title = "Test", description = "Test", price = 10.00, condition = "Used",
  watch_count = 5, view_count = 20, bid_count = 2,
  current_price = 12.50, time_remaining = "P2DT3H",
  last_synced_at = Sys.time()
)
row <- DBI::dbGetQuery(con, "SELECT * FROM ebay_listings WHERE sku = 'TEST_123'")
stopifnot(row$watch_count == 5, row$view_count == 20, row$bid_count == 2)
stopifnot(abs(row$current_price - 12.50) < 0.01)
DBI::dbDisconnect(con)
```

**IF_FAIL**:
- Check parameter names match column names exactly
- Verify INSERT statement includes all new columns
- Check for missing commas in SQL

**ROLLBACK**:
```bash
# Restore from git
git checkout R/ebay_database_extension.R
```

---

### TASK 1.4: Write database migration tests
**File**: `tests/testthat/test-ebay_database_extension.R`

**OPERATION**:
```r
# Add new test section at end of file
test_that("ebay_sync_log table created with correct schema", {
  with_test_db({
    initialize_ebay_tables(test_db_path())
    con <- DBI::dbConnect(RSQLite::SQLite(), test_db_path())
    on.exit(DBI::dbDisconnect(con))

    # Table exists
    tables <- DBI::dbListTables(con)
    expect_true("ebay_sync_log" %in% tables)

    # Schema correct
    schema <- DBI::dbGetQuery(con, "PRAGMA table_info(ebay_sync_log)")
    expect_true("sync_id" %in% schema$name)
    expect_true("ebay_user_id" %in% schema$name)

    # Indexes exist
    indexes <- DBI::dbGetQuery(con, "SELECT name FROM sqlite_master WHERE type='index'")
    expect_true(any(grepl("idx_sync_log_user", indexes$name)))
  })
})

test_that("ebay_listings cache columns migration works", {
  with_test_db({
    initialize_ebay_tables(test_db_path())
    con <- DBI::dbConnect(RSQLite::SQLite(), test_db_path())
    on.exit(DBI::dbDisconnect(con))

    schema <- DBI::dbGetQuery(con, "PRAGMA table_info(ebay_listings)")
    cache_cols <- c("watch_count", "view_count", "bid_count",
                   "current_price", "time_remaining", "last_synced_at")
    expect_true(all(cache_cols %in% schema$name))
  })
})

test_that("save_ebay_listing accepts cache parameters", {
  with_test_db({
    con <- DBI::dbConnect(RSQLite::SQLite(), test_db_path())
    on.exit(DBI::dbDisconnect(con))

    # Create test session
    DBI::dbExecute(con, "
      INSERT INTO sessions (session_id, user_id, login_time)
      VALUES ('test', 'testuser', CURRENT_TIMESTAMP)
    ")

    # Save with cache params
    result <- save_ebay_listing(con,
      card_id = 1, session_id = "test", sku = "CACHE_TEST",
      title = "Test", description = "Test", price = 10.00, condition = "Used",
      watch_count = 10, view_count = 50, bid_count = 3
    )

    expect_true(result$success)

    # Verify saved
    row <- DBI::dbGetQuery(con, "SELECT * FROM ebay_listings WHERE sku = 'CACHE_TEST'")
    expect_equal(row$watch_count, 10)
    expect_equal(row$view_count, 50)
    expect_equal(row$bid_count, 3)
  })
})
```

**VALIDATE**:
```r
# Run tests
testthat::test_file("tests/testthat/test-ebay_database_extension.R")
# Should see: ✓ 3 new tests pass
```

**IF_FAIL**:
- Check test helper functions available (`with_test_db`, `test_db_path`)
- Verify test database initialization in helper-setup.R
- Debug with: `devtools::load_all(); testthat::test_file("tests/...")`

**ROLLBACK**: Delete added test blocks

---

## PHASE 2: eBay API Sync Helpers (3 hours)

### TASK 2.1: Create ebay_sync_helpers.R file
**File**: `R/ebay_sync_helpers.R` (NEW FILE)

**OPERATION**:
```r
#' eBay Listing Sync Helpers
#'
#' Functions for syncing listing data from eBay Trading API with rate limiting
#'
#' @name ebay_sync_helpers
#' @keywords internal
NULL

#' Fetch all seller listings from eBay Trading API
#'
#' @param ebay_api EbayAPI object (from init_ebay_api)
#' @param start_date POSIXct start date for listings
#' @param end_date POSIXct end date for listings
#' @param page_number Integer page number for pagination
#'
#' @return List with items (list of listing data) and has_more_items (boolean)
#' @export
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

  # Handle pagination
  if (items$has_more_items) {
    next_page <- fetch_seller_listings(ebay_api, start_date, end_date, page_number + 1)
    items$items <- c(items$items, next_page$items)
  }

  return(items)
}

#' Parse GetSellerList XML response
#'
#' @param xml_response Character XML response from eBay
#'
#' @return List with items and has_more_items
#' @keywords internal
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
    # Helper to safely extract text (returns NA if node missing)
    safe_text <- function(xpath, default = NA) {
      node <- xml2::xml_find_first(item, xpath)
      if (length(node) == 0) return(default)
      xml2::xml_text(node)
    }

    # Helper to safely extract numeric
    safe_numeric <- function(xpath, default = NA) {
      text <- safe_text(xpath, as.character(default))
      as.numeric(text)
    }

    # Helper to safely extract integer
    safe_integer <- function(xpath, default = NA) {
      text <- safe_text(xpath, as.character(default))
      as.integer(text)
    }

    list(
      ItemID = safe_text("./ItemID"),
      Title = safe_text("./Title"),
      CurrentPrice = safe_numeric("./SellingStatus/CurrentPrice"),
      ListingStatus = safe_text("./SellingStatus/ListingStatus"),
      QuantitySold = safe_integer("./SellingStatus/QuantitySold", 0),
      BidCount = safe_integer("./SellingStatus/BidCount", 0),
      WatchCount = safe_integer("./WatchCount", 0),
      HitCount = safe_integer("./HitCount", 0),
      TimeLeft = safe_text("./TimeLeft"),
      ViewItemURL = safe_text("./ListingDetails/ViewItemURL")
    )
  })

  # Check for more items
  has_more <- xml2::xml_text(xml2::xml_find_first(doc, "//HasMoreItems")) == "true"

  return(list(items = items, has_more_items = has_more))
}

#' Check if eBay sync is allowed (rate limiting)
#'
#' @param con Database connection
#' @param ebay_user_id eBay user ID
#' @param min_interval_minutes Minimum minutes between syncs (default 15)
#'
#' @return Logical TRUE if sync allowed
#' @export
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

#' Log start of sync operation
#'
#' @param con Database connection
#' @param ebay_user_id eBay user ID
#'
#' @return Integer sync_id
#' @export
log_sync_start <- function(con, ebay_user_id) {
  DBI::dbExecute(con, "
    INSERT INTO ebay_sync_log (ebay_user_id, sync_status)
    VALUES (?, 'in_progress')
  ", list(ebay_user_id))

  return(DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS sync_id")$sync_id)
}

#' Log completion of sync operation
#'
#' @param con Database connection
#' @param sync_id Sync log ID
#' @param items_synced Number of items synced
#' @param api_calls Number of API calls made
#'
#' @export
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

#' Log sync error
#'
#' @param con Database connection
#' @param sync_id Sync log ID
#' @param error_message Error message
#'
#' @export
log_sync_error <- function(con, sync_id, error_message) {
  DBI::dbExecute(con, "
    UPDATE ebay_sync_log
    SET sync_completed_at = CURRENT_TIMESTAMP,
        sync_status = 'failed',
        error_message = ?
    WHERE sync_id = ?
  ", list(error_message, sync_id))
}

#' Update cached eBay data in database
#'
#' @param con Database connection
#' @param ebay_items List of items from parse_seller_list_response
#'
#' @export
update_listings_cache <- function(con, ebay_items) {
  for (item in ebay_items) {
    # Find matching listing by ebay_item_id
    DBI::dbExecute(con, "
      UPDATE ebay_listings
      SET watch_count = ?,
          view_count = ?,
          bid_count = ?,
          current_price = ?,
          time_remaining = ?,
          last_synced_at = CURRENT_TIMESTAMP
      WHERE ebay_item_id = ?
    ", list(
      item$WatchCount,
      item$HitCount,
      item$BidCount,
      item$CurrentPrice,
      item$TimeLeft,
      item$ItemID
    ))
  }
}
```

**VALIDATE**:
```r
# Syntax check
source("R/ebay_sync_helpers.R")

# Unit test
testthat::test_that("parse_seller_list_response extracts fields", {
  xml <- '
    <GetSellerListResponse>
      <Ack>Success</Ack>
      <ItemArray>
        <Item>
          <ItemID>123</ItemID>
          <Title>Test</Title>
          <SellingStatus>
            <CurrentPrice>10.50</CurrentPrice>
          </SellingStatus>
          <WatchCount>5</WatchCount>
        </Item>
      </ItemArray>
      <HasMoreItems>false</HasMoreItems>
    </GetSellerListResponse>
  '
  result <- parse_seller_list_response(xml)
  expect_equal(length(result$items), 1)
  expect_equal(result$items[[1]]$ItemID, "123")
  expect_equal(result$items[[1]]$WatchCount, 5)
})
```

**IF_FAIL**:
- Check xml2 package is loaded: `library(xml2)`
- Verify XPath expressions with `xml2::xml_find_all(doc, xpath)`
- Debug XML parsing: `xml2::xml_structure(doc)`

**ROLLBACK**: Delete file `R/ebay_sync_helpers.R`

---

### TASK 2.2: Add GetSellerList to EbayTradingAPI class
**File**: `R/ebay_trading_api.R`

**OPERATION**:
Find `make_request` method in EbayTradingAPI class (around line 100-150) and add new method after it:

```r
,
get_seller_list = function(start_date, end_date, page_number = 1, include_watch_count = TRUE) {
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
      <IncludeWatchCount>%s</IncludeWatchCount>
    </GetSellerListRequest>
  ',
  private$oauth$get_access_token(),
  format(start_date, "%Y-%m-%dT%H:%M:%S.000Z"),
  format(end_date, "%Y-%m-%dT%H:%M:%S.000Z"),
  page_number,
  tolower(as.character(include_watch_count))
  )

  response <- self$make_request(xml_body, "GetSellerList")
  return(response)
}
```

**VALIDATE**:
```r
# Test method exists
devtools::load_all()
ebay_api <- init_ebay_api("sandbox")
expect_true("get_seller_list" %in% names(ebay_api$trading))

# Test with mock (requires OAuth token)
# This will be tested in integration testing phase
```

**IF_FAIL**:
- Check comma before method definition
- Verify method is inside `public = list(...)` section
- Check proper use of `private$oauth` vs `self$oauth`

**ROLLBACK**:
```bash
git checkout R/ebay_trading_api.R
```

---

### TASK 2.3: Write sync helpers tests
**File**: `tests/testthat/test-ebay_sync_helpers.R` (NEW FILE)

**OPERATION**:
```r
test_that("parse_seller_list_response handles success", {
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
            <QuantitySold>0</QuantitySold>
          </SellingStatus>
          <WatchCount>5</WatchCount>
          <HitCount>45</HitCount>
          <TimeLeft>P2DT3H30M</TimeLeft>
          <ListingDetails>
            <ViewItemURL>https://www.ebay.com/itm/123456789</ViewItemURL>
          </ListingDetails>
        </Item>
      </ItemArray>
      <HasMoreItems>false</HasMoreItems>
    </GetSellerListResponse>
  '

  result <- parse_seller_list_response(xml_response)

  expect_equal(length(result$items), 1)
  expect_equal(result$items[[1]]$ItemID, "123456789")
  expect_equal(result$items[[1]]$Title, "Test Postcard")
  expect_equal(result$items[[1]]$CurrentPrice, 6.50)
  expect_equal(result$items[[1]]$WatchCount, 5)
  expect_equal(result$items[[1]]$HitCount, 45)
  expect_false(result$has_more_items)
})

test_that("parse_seller_list_response handles missing fields", {
  xml_response <- '
    <GetSellerListResponse>
      <Ack>Success</Ack>
      <ItemArray>
        <Item>
          <ItemID>999</ItemID>
          <Title>Minimal Item</Title>
        </Item>
      </ItemArray>
      <HasMoreItems>false</HasMoreItems>
    </GetSellerListResponse>
  '

  result <- parse_seller_list_response(xml_response)

  expect_equal(result$items[[1]]$ItemID, "999")
  expect_true(is.na(result$items[[1]]$WatchCount) || result$items[[1]]$WatchCount == 0)
})

test_that("can_sync_listings respects rate limit", {
  with_test_db({
    con <- DBI::dbConnect(RSQLite::SQLite(), test_db_path())
    on.exit(DBI::dbDisconnect(con))

    # No previous sync - should allow
    expect_true(can_sync_listings(con, "test_user", 15))

    # Add sync 10 mins ago
    DBI::dbExecute(con, "
      INSERT INTO ebay_sync_log (ebay_user_id, sync_started_at, sync_status)
      VALUES ('test_user', datetime('now', '-10 minutes'), 'completed')
    ")

    # Should block (15 min interval)
    expect_false(can_sync_listings(con, "test_user", 15))

    # Should allow (5 min interval)
    expect_true(can_sync_listings(con, "test_user", 5))
  })
})

test_that("log_sync_start creates record", {
  with_test_db({
    con <- DBI::dbConnect(RSQLite::SQLite(), test_db_path())
    on.exit(DBI::dbDisconnect(con))

    sync_id <- log_sync_start(con, "test_user")

    expect_true(is.numeric(sync_id))
    expect_true(sync_id > 0)

    row <- DBI::dbGetQuery(con, "SELECT * FROM ebay_sync_log WHERE sync_id = ?", list(sync_id))
    expect_equal(row$ebay_user_id, "test_user")
    expect_equal(row$sync_status, "in_progress")
  })
})

test_that("log_sync_complete updates record", {
  with_test_db({
    con <- DBI::dbConnect(RSQLite::SQLite(), test_db_path())
    on.exit(DBI::dbDisconnect(con))

    sync_id <- log_sync_start(con, "test_user")
    log_sync_complete(con, sync_id, items_synced = 50, api_calls = 1)

    row <- DBI::dbGetQuery(con, "SELECT * FROM ebay_sync_log WHERE sync_id = ?", list(sync_id))
    expect_equal(row$sync_status, "completed")
    expect_equal(row$items_synced, 50)
    expect_equal(row$api_calls_made, 1)
    expect_false(is.na(row$sync_completed_at))
  })
})

test_that("update_listings_cache updates database", {
  with_test_db({
    con <- DBI::dbConnect(RSQLite::SQLite(), test_db_path())
    on.exit(DBI::dbDisconnect(con))

    # Create test listing
    DBI::dbExecute(con, "
      INSERT INTO sessions (session_id, user_id, login_time)
      VALUES ('test', 'testuser', CURRENT_TIMESTAMP)
    ")
    save_ebay_listing(con,
      card_id = 1, session_id = "test", sku = "TEST_SYNC", ebay_item_id = "999",
      title = "Test", description = "Test", price = 10.00, condition = "Used"
    )

    # Update cache
    ebay_items <- list(
      list(ItemID = "999", WatchCount = 10, HitCount = 50, BidCount = 3,
           CurrentPrice = 12.50, TimeLeft = "P1DT2H")
    )
    update_listings_cache(con, ebay_items)

    # Verify
    row <- DBI::dbGetQuery(con, "SELECT * FROM ebay_listings WHERE ebay_item_id = '999'")
    expect_equal(row$watch_count, 10)
    expect_equal(row$view_count, 50)
    expect_equal(row$bid_count, 3)
    expect_equal(row$current_price, 12.50)
  })
})
```

**VALIDATE**:
```r
testthat::test_file("tests/testthat/test-ebay_sync_helpers.R")
# Should see: ✓ 6 tests pass
```

**IF_FAIL**: Debug individual tests, check helper functions available

**ROLLBACK**: Delete test file

---

## PHASE 3: Data Consolidation Layer (2 hours)

### TASK 3.1: Add get_all_ebay_listings function
**File**: `R/ebay_sync_helpers.R`

**OPERATION**:
Add at end of file:
```r
#' Get all eBay listings with item type detection
#'
#' @param con Database connection
#' @param status_filter Optional status filter (e.g., "listed", "sold")
#'
#' @return Data frame with all listings
#' @export
get_all_ebay_listings <- function(con, status_filter = NULL) {
  sql <- "
    SELECT
      el.*,
      CASE
        WHEN pc.card_id IS NOT NULL THEN 'Postcard'
        ELSE 'Stamp'
      END as item_type,
      pc.combined_image_path as image_path
    FROM ebay_listings el
    LEFT JOIN postal_cards pc ON el.card_id = pc.card_id
    WHERE 1=1
  "

  # Add status filter if provided
  if (!is.null(status_filter)) {
    sql <- paste0(sql, " AND el.status = ?")
  }

  sql <- paste0(sql, " ORDER BY el.listed_at DESC")

  if (!is.null(status_filter)) {
    result <- DBI::dbGetQuery(con, sql, list(status_filter))
  } else {
    result <- DBI::dbGetQuery(con, sql)
  }

  return(result)
}

#' Get eBay user ID from session
#'
#' @param con Database connection
#' @param session_id Session ID
#'
#' @return Character eBay user ID or NULL
#' @export
get_ebay_user_id_from_session <- function(con, session_id) {
  result <- DBI::dbGetQuery(con, "
    SELECT user_id FROM sessions WHERE session_id = ?
  ", list(session_id))

  if (nrow(result) == 0) return(NULL)

  # For now, assume user_id maps 1:1 to ebay_user_id
  # TODO: Add mapping table if needed
  return(result$user_id)
}
```

**VALIDATE**:
```r
# Test query
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
result <- get_all_ebay_listings(con)
expect_true("item_type" %in% names(result))
expect_true(all(result$item_type %in% c("Postcard", "Stamp")))
DBI::dbDisconnect(con)
```

**IF_FAIL**:
- Check JOIN syntax (LEFT JOIN vs INNER JOIN)
- Verify postal_cards table exists
- Debug with: `DBI::dbGetQuery(con, "SELECT * FROM postal_cards LIMIT 1")`

**ROLLBACK**: Remove added functions

---

### TASK 3.2: Add render helper functions
**File**: `R/ebay_sync_helpers.R`

**OPERATION**:
Add at end:
```r
#' Render status badge HTML
#'
#' @param status Status string
#'
#' @return HTML string
#' @export
render_status_badge <- function(status) {
  badges <- c(
    "listed" = '<span class="badge bg-success">Listed</span>',
    "scheduled" = '<span class="badge bg-warning">Scheduled</span>',
    "sold" = '<span class="badge bg-primary">Sold</span>',
    "ended" = '<span class="badge bg-secondary">Ended</span>',
    "error" = '<span class="badge bg-danger">Error</span>',
    "draft" = '<span class="badge bg-light text-dark">Draft</span>'
  )

  return(badges[status] %||% '<span class="badge bg-light">Unknown</span>')
}

#' Format time remaining for display
#'
#' @param time_left ISO 8601 duration string (e.g., "P2DT3H30M")
#'
#' @return Human-readable string
#' @export
format_time_remaining <- function(time_left) {
  if (is.null(time_left) || is.na(time_left) || time_left == "") {
    return("")
  }

  # Parse ISO 8601 duration
  # P2DT3H30M = 2 days, 3 hours, 30 minutes
  days <- as.numeric(gsub(".*P([0-9]+)D.*", "\\1", time_left))
  hours <- as.numeric(gsub(".*T([0-9]+)H.*", "\\1", time_left))

  if (is.na(days)) days <- 0
  if (is.na(hours)) hours <- 0

  if (days > 0) {
    return(sprintf("%dd %dh", days, hours))
  } else if (hours > 0) {
    return(sprintf("%dh", hours))
  } else {
    return("< 1h")
  }
}
```

**VALIDATE**:
```r
expect_equal(render_status_badge("listed"), '<span class="badge bg-success">Listed</span>')
expect_equal(format_time_remaining("P2DT3H30M"), "2d 3h")
expect_equal(format_time_remaining("PT5H"), "5h")
```

**IF_FAIL**: Check regex patterns, test with various ISO 8601 formats

**ROLLBACK**: Remove functions

---

## PHASE 4: UI Module Implementation (4 hours)

### TASK 4.1: Create mod_ebay_listings.R file
**File**: `R/mod_ebay_listings.R` (NEW FILE)

**OPERATION**:
Create complete module file (see PRP lines 472-691 for full code). Key sections:

```r
#' eBay Listings Viewer Module
#'
#' @description
#' Displays all eBay listings (stamps + postcards) with filtering, search, and refresh
#'
#' @param id Module ID
#'
#' @export
mod_ebay_listings_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Header card with stats and refresh
    bslib::card(
      bslib::card_header("eBay Listings Viewer"),
      bslib::card_body(
        fluidRow(
          column(10, uiOutput(ns("stats_display"))),
          column(2, actionButton(ns("refresh_all"), "Refresh All",
                                class = "btn-primary", width = "100%"))
        ),

        # Filters
        fluidRow(
          column(3, selectInput(ns("filter_status"), "Status",
                               choices = c("All", "Listed", "Scheduled", "Sold", "Ended", "Error"),
                               selected = "All")),
          column(3, selectInput(ns("filter_type"), "Type",
                               choices = c("All", "Postcard", "Stamp"),
                               selected = "All")),
          column(3, selectInput(ns("filter_format"), "Format",
                               choices = c("All", "Fixed Price", "Auction"),
                               selected = "All")),
          column(3, textInput(ns("search_text"), "Search",
                             placeholder = "Search title or SKU..."))
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

#' eBay Listings Viewer Server
#'
#' @param id Module ID
#' @param ebay_api Reactive EbayAPI object
#' @param session_id Reactive session ID
#'
#' @export
mod_ebay_listings_server <- function(id, ebay_api, session_id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Database connection helper
    get_db <- function() {
      DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    }

    # Reactive: Load listings from database
    listings_data <- reactiveVal(NULL)

    # Load initial data
    observe({
      con <- get_db()
      on.exit(DBI::dbDisconnect(con))

      data <- get_all_ebay_listings(con)
      listings_data(data)
    })

    # Refresh all listings from eBay API
    observeEvent(input$refresh_all, {
      con <- get_db()
      on.exit(DBI::dbDisconnect(con))

      # Get eBay user ID
      ebay_user_id <- get_ebay_user_id_from_session(con, session_id())

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
          ebay_api(),
          start_date = Sys.Date() - 90,
          end_date = Sys.Date()
        )

        # Update cache
        update_listings_cache(con, ebay_data$items)

        # Log success
        log_sync_complete(con, sync_id, length(ebay_data$items), 1)

        # Reload data
        data <- get_all_ebay_listings(con)
        listings_data(data)

        showNotification(sprintf("Synced %d listings from eBay",
                                length(ebay_data$items)),
                        type = "message")
      }, error = function(e) {
        log_sync_error(con, sync_id, e$message)
        showNotification(paste("Error syncing:", e$message), type = "error")
      })
    })

    # Filtered data
    filtered_data <- reactive({
      req(listings_data())
      data <- listings_data()

      # Apply filters
      if (input$filter_status != "All") {
        data <- data[data$status == tolower(input$filter_status), ]
      }

      if (input$filter_type != "All") {
        data <- data[data$item_type == input$filter_type, ]
      }

      if (input$filter_format != "All") {
        format_value <- ifelse(input$filter_format == "Fixed Price",
                               "fixed_price", "auction")
        data <- data[data$listing_type == format_value, ]
      }

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

      tags$div(style = "font-size: 16px;",
        tags$span(style = "margin-right: 20px;", paste("Total:", total)),
        tags$span(style = "margin-right: 20px;", paste("Active:", active)),
        tags$span(style = "margin-right: 20px;", paste("Sold:", sold)),
        tags$span(paste("Scheduled:", scheduled))
      )
    })

    # Render datatable
    output$listings_table <- DT::renderDataTable({
      req(filtered_data())
      data <- filtered_data()

      # Prepare display data
      display_data <- data.frame(
        Type = ifelse(data$item_type == "Postcard", "Card", "Stamp"),
        Title = data$title,
        Price = sprintf("$%.2f", data$price),
        Status = sapply(data$status, render_status_badge),
        Format = ifelse(data$listing_type == "fixed_price", "Fixed", "Auction"),
        Views = data$view_count,
        Watchers = data$watch_count,
        Bids = data$bid_count,
        TimeLeft = sapply(data$time_remaining, format_time_remaining),
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
          order = list(list(9, "desc")),
          dom = "Bfrtip",
          buttons = c("copy", "csv")
        ),
        extensions = "Buttons"
      )
    })
  })
}
```

**VALIDATE**:
```r
# Syntax check
source("R/mod_ebay_listings.R")

# Check module size
system("wc -l R/mod_ebay_listings.R")
# Should be < 400 lines
```

**IF_FAIL**:
- Check all `ns()` calls for input/output IDs
- Verify reactive dependencies (`req()`, `reactive()`, `observeEvent()`)
- Test in isolation with mock data

**ROLLBACK**: Delete file

---

### TASK 4.2: Add module tests
**File**: `tests/testthat/test-mod_ebay_listings.R` (NEW FILE)

**OPERATION**:
```r
test_that("mod_ebay_listings_ui creates proper namespace", {
  ui <- mod_ebay_listings_ui("test")

  # Should contain namespaced IDs
  ui_html <- as.character(ui)
  expect_true(grepl("test-refresh_all", ui_html))
  expect_true(grepl("test-listings_table", ui_html))
  expect_true(grepl("test-filter_status", ui_html))
})

test_that("get_all_ebay_listings returns correct structure", {
  with_test_db({
    con <- DBI::dbConnect(RSQLite::SQLite(), test_db_path())
    on.exit(DBI::dbDisconnect(con))

    # Create test data
    DBI::dbExecute(con, "
      INSERT INTO sessions (session_id, user_id, login_time)
      VALUES ('test', 'testuser', CURRENT_TIMESTAMP)
    ")

    save_ebay_listing(con,
      card_id = 1, session_id = "test", sku = "TEST1",
      title = "Test Postcard", description = "Test",
      price = 10.00, condition = "Used", status = "listed"
    )

    result <- get_all_ebay_listings(con)

    expect_s3_class(result, "data.frame")
    expect_true("item_type" %in% names(result))
    expect_true(all(result$item_type %in% c("Postcard", "Stamp")))
  })
})

test_that("render_status_badge returns correct HTML", {
  expect_equal(render_status_badge("listed"), '<span class="badge bg-success">Listed</span>')
  expect_equal(render_status_badge("sold"), '<span class="badge bg-primary">Sold</span>')
  expect_equal(render_status_badge("error"), '<span class="badge bg-danger">Error</span>')
})

test_that("format_time_remaining parses ISO 8601 duration", {
  expect_equal(format_time_remaining("P2DT3H30M"), "2d 3h")
  expect_equal(format_time_remaining("PT5H"), "5h")
  expect_equal(format_time_remaining(""), "")
  expect_equal(format_time_remaining(NA), "")
})
```

**VALIDATE**:
```r
testthat::test_file("tests/testthat/test-mod_ebay_listings.R")
# Should see: ✓ 4 tests pass
```

**IF_FAIL**: Debug individual tests

**ROLLBACK**: Delete test file

---

## PHASE 5: App Integration (1 hour)

### TASK 5.1: Add menu item to app
**File**: Find main app file (likely `inst/app/app.R` or `R/app_ui.R`)

**OPERATION**:
1. Locate navigation menu (search for "sidebar" or "nav_panel")
2. Add new menu item:
```r
bslib::nav_panel("eBay Listings", mod_ebay_listings_ui("ebay_listings"))
```

3. In server function, add module call:
```r
mod_ebay_listings_server("ebay_listings",
  ebay_api = reactive(ebay_api),
  session_id = reactive(session_id)
)
```

**VALIDATE**:
```r
# Run app
golem::run_dev()
# Navigate to eBay Listings tab
# Should see UI without errors
```

**IF_FAIL**:
- Check module ID matches ("ebay_listings")
- Verify ebay_api and session_id are available in server scope
- Check console for errors

**ROLLBACK**:
```bash
git checkout inst/app/app.R  # or whichever file was modified
```

---

## PHASE 6: Testing & Documentation (2 hours)

### TASK 6.1: Run critical tests
**Command**:
```r
source("dev/run_critical_tests.R")
```

**EXPECTED**: All existing tests pass (no regressions)

**IF_FAIL**:
- Identify which test failed
- Check if new code broke existing functionality
- Fix or rollback changes

---

### TASK 6.2: Manual testing in sandbox
**Scenarios**:

1. **Empty state**: No listings → should show empty table
2. **Load listings**: Navigate to tab → should load from database
3. **Filter by status**: Select "Listed" → should show only listed items
4. **Filter by type**: Select "Postcard" → should show only postcards
5. **Search**: Type keyword → should filter results
6. **Refresh button (no prior sync)**: Click → should sync immediately
7. **Refresh button (recent sync)**: Click within 15 mins → should block with warning
8. **Refresh button (stale sync)**: Click after 15 mins → should sync successfully

**LOG RESULTS** in TESTING_RESULTS.md (create file)

---

### TASK 6.3: Add to critical test suite
**File**: `dev/run_critical_tests.R`

**OPERATION**:
Add before final summary:
```r
# eBay Listings Viewer tests
cat("\n=== eBay Listings Viewer Tests ===\n")
testthat::test_file("tests/testthat/test-ebay_sync_helpers.R", stop_on_failure = FALSE)
testthat::test_file("tests/testthat/test-mod_ebay_listings.R", stop_on_failure = FALSE)
```

**VALIDATE**:
```r
source("dev/run_critical_tests.R")
# Should see new test section in output
```

---

### TASK 6.4: Create Serena memory file
**File**: `.serena/memories/ebay_listings_viewer_complete_20251102.md`

**OPERATION**:
Document:
- What was implemented (summary of all phases)
- Key decisions made
- Testing results
- Known issues/limitations
- Performance metrics (if available)

**Template**:
```md
# eBay Listings Viewer Implementation - Complete

**Date**: 2025-11-02
**Status**: ✅ Complete
**Implementation Time**: [actual hours]

## Overview
[1-paragraph summary]

## What Was Implemented
- Database extensions (ebay_sync_log table, cache columns)
- eBay sync helpers (fetch_seller_listings, rate limiting)
- UI module (mod_ebay_listings)
- Tests (X tests passing)

## Key Technical Decisions
1. ...
2. ...

## Testing Results
- Critical tests: [X/Y passing]
- Manual testing: [scenarios covered]

## Performance
- Initial load time: [X seconds]
- Refresh time: [X seconds for Y items]

## Known Limitations
- ...

## Future Enhancements
- ...
```

---

### TASK 6.5: Update INDEX.md
**File**: `.serena/memories/INDEX.md`

**OPERATION**:
Add entry:
```md
## eBay Integration

...existing entries...

- **ebay_listings_viewer_complete_20251102.md** - eBay Listings Viewer implementation with sync, filtering, and rate limiting
```

**VALIDATE**: Check alphabetical order and categorization

---

## Success Criteria Checklist

### Functional ✅
- [ ] Database tables created (ebay_sync_log, cache columns)
- [ ] eBay Trading API sync working (GetSellerList)
- [ ] Rate limiting prevents excessive API calls (15 min cooldown)
- [ ] Module displays all listings (stamps + postcards)
- [ ] Filters work (status, type, format, search)
- [ ] Refresh button updates data from eBay
- [ ] Stats display shows counts

### Testing ✅
- [ ] All critical tests pass
- [ ] New tests added (database, sync, module)
- [ ] Manual testing complete (all scenarios)
- [ ] No regressions in existing features

### Code Quality ✅
- [ ] No files > 400 lines
- [ ] Uses bslib (no custom JavaScript)
- [ ] Proper error handling
- [ ] Rate limiting implemented correctly
- [ ] Follows Golem conventions

### Documentation ✅
- [ ] Serena memory created
- [ ] INDEX.md updated
- [ ] Code comments added
- [ ] Testing results documented

---

## Rollback Plan

### Quick Rollback (Per-Phase)
Each task has individual rollback instructions. Follow in reverse order.

### Full Rollback (Git)
```bash
# Before starting implementation, create branch
git checkout -b feature/ebay-listings-viewer

# If need to rollback everything
git checkout main
git branch -D feature/ebay-listings-viewer
```

### Database Rollback
```sql
-- Manual cleanup if needed
DROP TABLE IF EXISTS ebay_sync_log;
-- Note: Cannot drop columns in SQLite, but they're harmless if unused
```

---

## Debugging Strategies

### Issue: Module not appearing
- Check app integration (PHASE 5)
- Verify module namespace IDs match
- Check console for JavaScript errors

### Issue: Refresh fails
- Check OAuth token validity
- Verify Trading API endpoint accessible
- Check rate limiting logic
- Review ebay_sync_log table for errors

### Issue: Empty listings
- Verify database has data: `SELECT COUNT(*) FROM ebay_listings`
- Check JOIN with postal_cards table
- Debug SQL query with: `DBI::dbGetQuery(con, sql)`

### Issue: Filters not working
- Check reactive dependencies
- Verify filter logic (case sensitivity)
- Test with: `print(filtered_data())`

---

## Performance Targets

- **Initial load**: < 2 seconds (100 items)
- **Filter response**: < 500ms
- **API sync**: < 10 seconds (200 items)
- **Database query**: < 100ms

---

## Dependencies Check

### R Packages (all should be in DESCRIPTION)
- ✅ DBI, RSQLite - Database
- ✅ xml2 - XML parsing (added in Trading API phase)
- ✅ httr2 - HTTP requests
- ✅ DT - Datatable (ADD if missing)
- ✅ bslib - UI components
- ✅ shiny - Framework

### Verify DT package
```r
if (!"DT" %in% rownames(installed.packages())) {
  install.packages("DT")
}
# Add to DESCRIPTION if missing:
# usethis::use_package("DT")
```

---

## Timeline Estimates

| Phase | Tasks | Estimated | Complexity |
|-------|-------|-----------|------------|
| 1 | Database (4 tasks) | 2h | LOW |
| 2 | Sync Helpers (3 tasks) | 3h | MEDIUM |
| 3 | Consolidation (2 tasks) | 2h | MEDIUM |
| 4 | UI Module (2 tasks) | 4h | HIGH |
| 5 | Integration (1 task) | 1h | LOW |
| 6 | Testing & Docs (5 tasks) | 2h | MEDIUM |
| **TOTAL** | **17 tasks** | **14h** | **MEDIUM** |

---

## Next Steps After Completion

1. **Production Testing**: Test with production eBay account
2. **Monitor Rate Limits**: Track API usage over 24 hours
3. **User Feedback**: Gather feedback on UI/UX
4. **Optimization**: Index tuning if slow with 1000+ listings
5. **Future Features**: See PRP lines 1013-1024 for enhancement ideas

---

**END OF TASK PRP**
