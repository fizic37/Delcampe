# Tests for eBay Sync Helpers
# Testing XML parsing, rate limiting, cache updates, and helper functions

test_that("parse_seller_list_response handles success with all fields", {
  xml_response <- '<?xml version="1.0" encoding="UTF-8"?>
    <GetSellerListResponse xmlns="urn:ebay:apis:eBLBaseComponents">
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
    </GetSellerListResponse>'

  result <- parse_seller_list_response(xml_response)

  expect_equal(length(result$items), 1)
  expect_equal(result$items[[1]]$ItemID, "123456789")
  expect_equal(result$items[[1]]$Title, "Test Postcard")
  expect_equal(result$items[[1]]$CurrentPrice, 6.50)
  expect_equal(result$items[[1]]$WatchCount, 5)
  expect_equal(result$items[[1]]$HitCount, 45)
  expect_equal(result$items[[1]]$BidCount, 3)
  expect_equal(result$items[[1]]$TimeLeft, "P2DT3H30M")
  expect_false(result$has_more_items)
})

test_that("parse_seller_list_response handles missing optional fields", {
  xml_response <- '<?xml version="1.0" encoding="UTF-8"?>
    <GetSellerListResponse xmlns="urn:ebay:apis:eBLBaseComponents">
      <Ack>Success</Ack>
      <ItemArray>
        <Item>
          <ItemID>999</ItemID>
          <Title>Minimal Item</Title>
        </Item>
      </ItemArray>
      <HasMoreItems>false</HasMoreItems>
    </GetSellerListResponse>'

  result <- parse_seller_list_response(xml_response)

  expect_equal(result$items[[1]]$ItemID, "999")
  expect_equal(result$items[[1]]$Title, "Minimal Item")
  # Missing fields should be NA or 0
  expect_true(is.na(result$items[[1]]$WatchCount) || result$items[[1]]$WatchCount == 0)
})

test_that("parse_seller_list_response handles multiple items", {
  xml_response <- '<?xml version="1.0" encoding="UTF-8"?>
    <GetSellerListResponse xmlns="urn:ebay:apis:eBLBaseComponents">
      <Ack>Success</Ack>
      <ItemArray>
        <Item>
          <ItemID>111</ItemID>
          <Title>Item 1</Title>
        </Item>
        <Item>
          <ItemID>222</ItemID>
          <Title>Item 2</Title>
        </Item>
        <Item>
          <ItemID>333</ItemID>
          <Title>Item 3</Title>
        </Item>
      </ItemArray>
      <HasMoreItems>true</HasMoreItems>
    </GetSellerListResponse>'

  result <- parse_seller_list_response(xml_response)

  expect_equal(length(result$items), 3)
  expect_equal(result$items[[1]]$ItemID, "111")
  expect_equal(result$items[[2]]$ItemID, "222")
  expect_equal(result$items[[3]]$ItemID, "333")
  expect_true(result$has_more_items)
})

test_that("parse_seller_list_response handles errors", {
  xml_response <- '<?xml version="1.0" encoding="UTF-8"?>
    <GetSellerListResponse xmlns="urn:ebay:apis:eBLBaseComponents">
      <Ack>Failure</Ack>
      <Errors>
        <LongMessage>Invalid request</LongMessage>
      </Errors>
    </GetSellerListResponse>'

  expect_error(
    parse_seller_list_response(xml_response),
    "GetSellerList failed"
  )
})

test_that("can_sync_listings respects rate limit", {
  # Create temporary database
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  initialize_ebay_tables(db_path)
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

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

test_that("can_sync_listings ignores failed syncs", {
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  initialize_ebay_tables(db_path)
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  # Add failed sync 5 mins ago
  DBI::dbExecute(con, "
    INSERT INTO ebay_sync_log (ebay_user_id, sync_started_at, sync_status)
    VALUES ('test_user', datetime('now', '-5 minutes'), 'failed')
  ")

  # Should allow (only looks at completed syncs)
  expect_true(can_sync_listings(con, "test_user", 15))
})

test_that("log_sync_start creates record", {
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  initialize_ebay_tables(db_path)
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  sync_id <- log_sync_start(con, "test_user")

  expect_true(is.numeric(sync_id))
  expect_true(sync_id > 0)

  row <- DBI::dbGetQuery(con, "SELECT * FROM ebay_sync_log WHERE sync_id = ?", list(sync_id))
  expect_equal(row$ebay_user_id, "test_user")
  expect_equal(row$sync_status, "in_progress")
  expect_false(is.na(row$sync_started_at))
})

test_that("log_sync_complete updates record", {
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  initialize_ebay_tables(db_path)
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  sync_id <- log_sync_start(con, "test_user")
  log_sync_complete(con, sync_id, items_synced = 50, api_calls = 1)

  row <- DBI::dbGetQuery(con, "SELECT * FROM ebay_sync_log WHERE sync_id = ?", list(sync_id))
  expect_equal(row$sync_status, "completed")
  expect_equal(row$items_synced, 50)
  expect_equal(row$api_calls_made, 1)
  expect_false(is.na(row$sync_completed_at))
})

test_that("log_sync_error updates record with error", {
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  initialize_ebay_tables(db_path)
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  sync_id <- log_sync_start(con, "test_user")
  log_sync_error(con, sync_id, "Test error message")

  row <- DBI::dbGetQuery(con, "SELECT * FROM ebay_sync_log WHERE sync_id = ?", list(sync_id))
  expect_equal(row$sync_status, "failed")
  expect_equal(row$error_message, "Test error message")
  expect_false(is.na(row$sync_completed_at))
})

test_that("update_listings_cache updates database", {
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  DBI::dbExecute(con, "
    CREATE TABLE sessions (
      session_id TEXT PRIMARY KEY,
      user_id TEXT,
      login_time DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ")
  DBI::dbExecute(con, "
    INSERT INTO sessions (session_id, user_id)
    VALUES ('test', 'testuser')
  ")
  DBI::dbDisconnect(con)

  initialize_ebay_tables(db_path)

  # Create test listing
  save_ebay_listing(
    card_id = 1,
    session_id = "test",
    sku = "TEST_SYNC",
    ebay_item_id = "999",
    title = "Test",
    description = "Test",
    price = 10.00,
    condition = "Used"
  )

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  # Update cache with Active status from eBay
  ebay_items <- list(
    list(ItemID = "999", WatchCount = 10, HitCount = 50, BidCount = 3,
         CurrentPrice = 12.50, TimeLeft = "P1DT2H", ListingStatus = "Active")
  )
  update_listings_cache(con, ebay_items)

  # Verify
  row <- DBI::dbGetQuery(con, "SELECT * FROM ebay_listings WHERE ebay_item_id = '999'")
  expect_equal(row$status, "listed")  # Active maps to "listed"
  expect_equal(row$watch_count, 10)
  expect_equal(row$view_count, 50)
  expect_equal(row$bid_count, 3)
  expect_equal(row$current_price, 12.50)
  expect_equal(row$time_remaining, "P1DT2H")
  expect_false(is.na(row$last_synced_at))
})

test_that("get_all_ebay_listings returns correct structure", {
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  DBI::dbExecute(con, "
    CREATE TABLE sessions (
      session_id TEXT PRIMARY KEY,
      user_id TEXT
    )
  ")
  DBI::dbExecute(con, "INSERT INTO sessions (session_id, user_id) VALUES ('test', 'testuser')")

  DBI::dbExecute(con, "
    CREATE TABLE postal_cards (
      card_id INTEGER PRIMARY KEY
    )
  ")
  DBI::dbExecute(con, "INSERT INTO postal_cards (card_id) VALUES (1)")
  DBI::dbDisconnect(con)

  initialize_ebay_tables(db_path)

  save_ebay_listing(
    card_id = 1,
    session_id = "test",
    sku = "TEST1",
    title = "Test Postcard",
    description = "Test",
    price = 10.00,
    condition = "Used",
    status = "listed"
  )

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  result <- get_all_ebay_listings(con)

  expect_s3_class(result, "data.frame")
  expect_true("item_type" %in% names(result))
  expect_equal(nrow(result), 1)
  expect_equal(result$item_type[1], "Postcard")
})

test_that("get_all_ebay_listings filters by status", {
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  DBI::dbExecute(con, "CREATE TABLE sessions (session_id TEXT PRIMARY KEY, user_id TEXT)")
  DBI::dbExecute(con, "INSERT INTO sessions VALUES ('test', 'testuser')")
  DBI::dbExecute(con, "CREATE TABLE postal_cards (card_id INTEGER PRIMARY KEY)")
  DBI::dbDisconnect(con)

  initialize_ebay_tables(db_path)

  save_ebay_listing(card_id = 1, session_id = "test", sku = "LISTED1",
                    title = "Listed", description = "Test", price = 10, condition = "Used", status = "listed")
  save_ebay_listing(card_id = 2, session_id = "test", sku = "SOLD1",
                    title = "Sold", description = "Test", price = 15, condition = "Used", status = "sold")

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  all_results <- get_all_ebay_listings(con)
  expect_equal(nrow(all_results), 2)

  listed_only <- get_all_ebay_listings(con, status_filter = "listed")
  expect_equal(nrow(listed_only), 1)
  expect_equal(listed_only$status[1], "listed")
})

test_that("render_status_badge returns correct HTML", {
  expect_equal(render_status_badge("listed"), '<span class="badge bg-success">Listed</span>')
  expect_equal(render_status_badge("sold"), '<span class="badge bg-primary">Sold</span>')
  expect_equal(render_status_badge("error"), '<span class="badge bg-danger">Error</span>')
  expect_equal(render_status_badge("scheduled"), '<span class="badge bg-warning">Scheduled</span>')
  expect_equal(render_status_badge("ended"), '<span class="badge bg-secondary">Ended</span>')
  expect_equal(render_status_badge("terminated"), '<span class="badge bg-danger">Terminated</span>')
  expect_equal(render_status_badge("cancelled"), '<span class="badge bg-danger">Cancelled</span>')
  expect_equal(render_status_badge("draft"), '<span class="badge bg-light text-dark">Draft</span>')
})

test_that("render_status_badge handles unknown status", {
  result <- render_status_badge("unknown_status")
  expect_true(grepl("Unknown", result))
  expect_true(grepl("badge", result))
})

test_that("format_time_remaining parses ISO 8601 duration", {
  expect_equal(format_time_remaining("P2DT3H30M"), "2d 3h")
  expect_equal(format_time_remaining("P5DT0H"), "5d 0h")
  expect_equal(format_time_remaining("PT5H"), "5h")
  expect_equal(format_time_remaining("PT0H30M"), "< 1h")
})

test_that("format_time_remaining handles edge cases", {
  expect_equal(format_time_remaining(""), "")
  expect_equal(format_time_remaining(NA), "")
  expect_equal(format_time_remaining(NULL), "")
})

test_that("get_ebay_user_id_from_session returns user_id", {
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  DBI::dbExecute(con, "CREATE TABLE sessions (session_id TEXT PRIMARY KEY, user_id TEXT)")
  DBI::dbExecute(con, "INSERT INTO sessions VALUES ('test_session', 'test_user_123')")

  result <- get_ebay_user_id_from_session(con, "test_session")
  expect_equal(result, "test_user_123")

  DBI::dbDisconnect(con)
})

test_that("get_ebay_user_id_from_session returns NULL for missing session", {
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  DBI::dbExecute(con, "CREATE TABLE sessions (session_id TEXT PRIMARY KEY, user_id TEXT)")

  result <- get_ebay_user_id_from_session(con, "nonexistent")
  expect_null(result)

  DBI::dbDisconnect(con)
})

test_that("update_listings_cache correctly maps eBay status to internal status", {
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  DBI::dbExecute(con, "CREATE TABLE sessions (session_id TEXT PRIMARY KEY, user_id TEXT)")
  DBI::dbExecute(con, "INSERT INTO sessions VALUES ('test', 'testuser')")
  DBI::dbDisconnect(con)

  initialize_ebay_tables(db_path)

  # Create test listing
  save_ebay_listing(
    card_id = 1,
    session_id = "test",
    sku = "TEST_STATUS",
    ebay_item_id = "123",
    title = "Test",
    description = "Test",
    price = 10.00,
    condition = "Used",
    status = "draft"
  )

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  # Test status mapping: Cancelled -> terminated
  update_listings_cache(con, list(
    list(ItemID = "123", ListingStatus = "Cancelled", WatchCount = 0, HitCount = 0,
         BidCount = 0, CurrentPrice = 10, TimeLeft = "")
  ))
  row <- DBI::dbGetQuery(con, "SELECT status FROM ebay_listings WHERE ebay_item_id = '123'")
  expect_equal(row$status, "terminated")

  # Test status mapping: Completed -> sold
  update_listings_cache(con, list(
    list(ItemID = "123", ListingStatus = "Completed", WatchCount = 0, HitCount = 0,
         BidCount = 0, CurrentPrice = 10, TimeLeft = "")
  ))
  row <- DBI::dbGetQuery(con, "SELECT status FROM ebay_listings WHERE ebay_item_id = '123'")
  expect_equal(row$status, "sold")

  # Test status mapping: Active -> listed
  update_listings_cache(con, list(
    list(ItemID = "123", ListingStatus = "Active", WatchCount = 5, HitCount = 20,
         BidCount = 0, CurrentPrice = 10, TimeLeft = "P2D")
  ))
  row <- DBI::dbGetQuery(con, "SELECT status FROM ebay_listings WHERE ebay_item_id = '123'")
  expect_equal(row$status, "listed")
})
