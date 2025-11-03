# Tests for eBay Database Extension
# Testing database migrations, sync_log table, and cache columns

test_that("ebay_sync_log table created with correct schema", {
  # Create temporary database
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  # Initialize eBay tables
  result <- initialize_ebay_tables(db_path)
  expect_true(result)

  # Check table exists
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  tables <- DBI::dbListTables(con)
  expect_true("ebay_sync_log" %in% tables)

  # Check schema
  schema <- DBI::dbGetQuery(con, "PRAGMA table_info(ebay_sync_log)")
  required_cols <- c("sync_id", "sync_started_at", "sync_completed_at", "items_synced",
                    "api_calls_made", "sync_status", "error_message", "ebay_user_id")
  expect_true(all(required_cols %in% schema$name))

  # Check indexes
  indexes <- DBI::dbGetQuery(con, "SELECT name FROM sqlite_master WHERE type='index'")
  expect_true(any(grepl("idx_sync_log_user", indexes$name)))
  expect_true(any(grepl("idx_sync_log_started", indexes$name)))
})

test_that("ebay_listings cache columns migration works", {
  # Create temporary database
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  # Initialize eBay tables
  initialize_ebay_tables(db_path)

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  # Check cache columns exist
  schema <- DBI::dbGetQuery(con, "PRAGMA table_info(ebay_listings)")
  cache_cols <- c("watch_count", "view_count", "bid_count",
                 "current_price", "time_remaining", "last_synced_at")
  expect_true(all(cache_cols %in% schema$name))

  # Check column types
  watch_col <- schema[schema$name == "watch_count", ]
  expect_equal(watch_col$type, "INTEGER")

  current_price_col <- schema[schema$name == "current_price", ]
  expect_equal(current_price_col$type, "REAL")
})

test_that("save_ebay_listing accepts cache parameters", {
  # Create temporary database
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  # Initialize both tracking and eBay tables
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)

  # Create minimal schema for testing
  DBI::dbExecute(con, "
    CREATE TABLE sessions (
      session_id TEXT PRIMARY KEY,
      user_id TEXT,
      login_time DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ")

  DBI::dbExecute(con, "
    INSERT INTO sessions (session_id, user_id)
    VALUES ('test_session', 'test_user')
  ")

  DBI::dbDisconnect(con)

  # Initialize eBay tables
  initialize_ebay_tables(db_path)

  # Save listing with cache params
  result <- save_ebay_listing(
    card_id = 1,
    session_id = "test_session",
    sku = "CACHE_TEST_123",
    title = "Test Item",
    description = "Test Description",
    price = 10.00,
    condition = "Used",
    watch_count = 10,
    view_count = 50,
    bid_count = 3,
    current_price = 12.50,
    time_remaining = "P2DT3H",
    last_synced_at = Sys.time()
  )

  expect_true(result)

  # Verify saved data
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  row <- DBI::dbGetQuery(con, "SELECT * FROM ebay_listings WHERE sku = 'CACHE_TEST_123'")
  expect_equal(nrow(row), 1)
  expect_equal(row$watch_count, 10)
  expect_equal(row$view_count, 50)
  expect_equal(row$bid_count, 3)
  expect_equal(row$current_price, 12.50)
  expect_equal(row$time_remaining, "P2DT3H")
  expect_false(is.na(row$last_synced_at))
})

test_that("save_ebay_listing updates cache columns on existing listing", {
  # Create temporary database
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
    VALUES ('test_session', 'test_user')
  ")
  DBI::dbDisconnect(con)

  initialize_ebay_tables(db_path)

  # Create initial listing
  save_ebay_listing(
    card_id = 1,
    session_id = "test_session",
    sku = "UPDATE_TEST_123",
    title = "Test Item",
    description = "Test Description",
    price = 10.00,
    condition = "Used",
    watch_count = 5,
    view_count = 20
  )

  # Update with new cache values
  save_ebay_listing(
    card_id = 1,
    session_id = "test_session",
    sku = "UPDATE_TEST_123",
    title = "Test Item",
    description = "Test Description",
    price = 10.00,
    condition = "Used",
    watch_count = 15,
    view_count = 75,
    bid_count = 2
  )

  # Verify updated values
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  row <- DBI::dbGetQuery(con, "SELECT * FROM ebay_listings WHERE sku = 'UPDATE_TEST_123'")
  expect_equal(row$watch_count, 15)
  expect_equal(row$view_count, 75)
  expect_equal(row$bid_count, 2)
})

test_that("ebay_sync_log accepts default values correctly", {
  # Create temporary database
  db_path <- tempfile(fileext = ".sqlite")
  on.exit(unlink(db_path), add = TRUE)

  initialize_ebay_tables(db_path)

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  # Insert minimal record
  DBI::dbExecute(con, "
    INSERT INTO ebay_sync_log (ebay_user_id)
    VALUES ('test_user')
  ")

  # Check defaults
  row <- DBI::dbGetQuery(con, "SELECT * FROM ebay_sync_log WHERE ebay_user_id = 'test_user'")
  expect_equal(row$sync_status, "in_progress")
  expect_false(is.na(row$sync_started_at))
  expect_true(is.na(row$sync_completed_at))
})
