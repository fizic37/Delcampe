# Tests for eBay Listings Module
# Testing UI generation, data filtering, and rendering logic

test_that("mod_ebay_listings_ui creates proper namespace", {
  ui <- mod_ebay_listings_ui("test")

  # Should contain namespaced IDs
  ui_html <- as.character(ui)
  expect_true(grepl("test-refresh_all", ui_html))
  expect_true(grepl("test-listings_table", ui_html))
  expect_true(grepl("test-filter_status", ui_html))
  expect_true(grepl("test-filter_type", ui_html))
  expect_true(grepl("test-filter_format", ui_html))
  expect_true(grepl("test-search_text", ui_html))
})

test_that("mod_ebay_listings_ui includes all filter options", {
  ui <- mod_ebay_listings_ui("test")
  ui_html <- as.character(ui)

  # Check status filter options
  expect_true(grepl("Listed", ui_html))
  expect_true(grepl("Sold", ui_html))
  expect_true(grepl("Scheduled", ui_html))

  # Check type filter
  expect_true(grepl("Postcard", ui_html))
  expect_true(grepl("Stamp", ui_html))

  # Check format filter
  expect_true(grepl("Fixed Price", ui_html))
  expect_true(grepl("Auction", ui_html))
})

test_that("render_status_badge generates valid HTML", {
  listed_badge <- render_status_badge("listed")
  expect_true(grepl('<span class="badge', listed_badge))
  expect_true(grepl('bg-success', listed_badge))
  expect_true(grepl('Listed', listed_badge))

  sold_badge <- render_status_badge("sold")
  expect_true(grepl('bg-primary', sold_badge))
  expect_true(grepl('Sold', sold_badge))

  error_badge <- render_status_badge("error")
  expect_true(grepl('bg-danger', error_badge))
  expect_true(grepl('Error', error_badge))
})

test_that("format_time_remaining correctly parses durations", {
  # Days and hours
  expect_equal(format_time_remaining("P2DT3H30M"), "2d 3h")
  expect_equal(format_time_remaining("P1DT12H"), "1d 12h")

  # Hours only
  expect_equal(format_time_remaining("PT5H"), "5h")
  expect_equal(format_time_remaining("PT23H"), "23h")

  # Less than an hour
  expect_equal(format_time_remaining("PT0H30M"), "< 1h")
  expect_equal(format_time_remaining("PT0H"), "< 1h")
})

test_that("format_time_remaining handles empty/invalid inputs", {
  expect_equal(format_time_remaining(""), "")
  expect_equal(format_time_remaining(NA_character_), "")
  expect_equal(format_time_remaining(NULL), "")
})

test_that("get_all_ebay_listings detects item types correctly", {
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)

  # Create minimal schema
  DBI::dbExecute(con, "CREATE TABLE sessions (session_id TEXT PRIMARY KEY, user_id TEXT)")
  DBI::dbExecute(con, "INSERT INTO sessions VALUES ('test', 'testuser')")

  DBI::dbExecute(con, "CREATE TABLE postal_cards (card_id INTEGER PRIMARY KEY)")
  DBI::dbExecute(con, "INSERT INTO postal_cards VALUES (1)")
  DBI::dbExecute(con, "INSERT INTO postal_cards VALUES (2)")

  DBI::dbDisconnect(con)

  # Initialize eBay tables
  initialize_ebay_tables(db_path)

  # Create listings: one with card_id (postcard), one without (stamp)
  save_ebay_listing(
    card_id = 1,
    session_id = "test",
    sku = "POSTCARD_001",
    title = "Vintage Postcard",
    description = "Test",
    price = 5.00,
    condition = "Used"
  )

  save_ebay_listing(
    card_id = NULL,
    session_id = "test",
    sku = "STAMP_001",
    title = "Rare Stamp",
    description = "Test",
    price = 10.00,
    condition = "Used"
  )

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  result <- get_all_ebay_listings(con)

  expect_equal(nrow(result), 2)
  expect_true("item_type" %in% names(result))

  # Check postcard detection
  postcard_row <- result[result$sku == "POSTCARD_001", ]
  expect_equal(postcard_row$item_type, "Postcard")

  # Check stamp detection
  stamp_row <- result[result$sku == "STAMP_001", ]
  expect_equal(stamp_row$item_type, "Stamp")
})

test_that("get_ebay_user_id_from_session handles valid and invalid sessions", {
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  DBI::dbExecute(con, "CREATE TABLE sessions (session_id TEXT PRIMARY KEY, user_id TEXT)")
  DBI::dbExecute(con, "INSERT INTO sessions VALUES ('valid_session', 'user123')")

  # Valid session
  result <- get_ebay_user_id_from_session(con, "valid_session")
  expect_equal(result, "user123")

  # Invalid session
  result_null <- get_ebay_user_id_from_session(con, "invalid_session")
  expect_null(result_null)

  DBI::dbDisconnect(con)
})
