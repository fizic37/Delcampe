# Tests for eBay listings cache table
# Covers cache table initialization, data management, and rate limiting

# ==== CACHE TABLE INITIALIZATION TESTS ====

test_that("initialize_ebay_cache_table creates table successfully", {
  # Create temporary database
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  # Initialize cache table
  result <- initialize_ebay_cache_table(db_path)
  expect_true(result)

  # Check table exists
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  expect_true(DBI::dbExistsTable(con, "ebay_listings_cache"))
})

test_that("initialize_ebay_cache_table creates all required columns", {
  # Create temporary database
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  # Initialize cache table
  initialize_ebay_cache_table(db_path)

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  # Check schema has all required columns
  columns <- DBI::dbListFields(con, "ebay_listings_cache")

  # Core identification columns
  expect_true("cache_id" %in% columns)
  expect_true("ebay_item_id" %in% columns)
  expect_true("ebay_user_id" %in% columns)

  # Listing data columns
  expect_true("title" %in% columns)
  expect_true("current_price" %in% columns)
  expect_true("currency" %in% columns)
  expect_true("listing_status" %in% columns)
  expect_true("listing_type" %in% columns)
  expect_true("quantity" %in% columns)
  expect_true("quantity_sold" %in% columns)

  # Engagement metrics
  expect_true("watch_count" %in% columns)
  expect_true("view_count" %in% columns)
  expect_true("bid_count" %in% columns)

  # Time tracking
  expect_true("start_time" %in% columns)
  expect_true("end_time" %in% columns)
  expect_true("time_remaining" %in% columns)

  # Links and metadata
  expect_true("listing_url" %in% columns)
  expect_true("gallery_url" %in% columns)
  expect_true("sku" %in% columns)
  expect_true("category_id" %in% columns)

  # Cache metadata
  expect_true("synced_at" %in% columns)
  expect_true("api_call_name" %in% columns)
})

test_that("initialize_ebay_cache_table creates indexes correctly", {
  # Create temporary database
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  # Initialize cache table
  initialize_ebay_cache_table(db_path)

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  # Query index information
  indexes <- DBI::dbGetQuery(con, "
    SELECT name FROM sqlite_master
    WHERE type = 'index' AND tbl_name = 'ebay_listings_cache'
  ")

  # Check for required indexes
  expect_true("idx_cache_item_id" %in% indexes$name)
  expect_true("idx_cache_user_id" %in% indexes$name)
  expect_true("idx_cache_status" %in% indexes$name)
  expect_true("idx_cache_synced_at" %in% indexes$name)
})

test_that("initialize_ebay_cache_table is idempotent", {
  # Create temporary database
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  # Initialize twice
  result1 <- initialize_ebay_cache_table(db_path)
  result2 <- initialize_ebay_cache_table(db_path)

  # Both should succeed
  expect_true(result1)
  expect_true(result2)

  # Table should exist
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  expect_true(DBI::dbExistsTable(con, "ebay_listings_cache"))
})

test_that("ebay_listings_cache table enforces unique ebay_item_id", {
  # Create temporary database
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  # Initialize cache table
  initialize_ebay_cache_table(db_path)

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  # Insert first item
  DBI::dbExecute(con, "
    INSERT INTO ebay_listings_cache (ebay_item_id, ebay_user_id, title, listing_status)
    VALUES ('TEST123', 'user1', 'Test Listing', 'active')
  ")

  # Try to insert duplicate ebay_item_id
  expect_error({
    DBI::dbExecute(con, "
      INSERT INTO ebay_listings_cache (ebay_item_id, ebay_user_id, title, listing_status)
      VALUES ('TEST123', 'user2', 'Another Listing', 'ended')
    ")
  })
})
