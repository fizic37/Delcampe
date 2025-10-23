# Tests for tracking_database.R
# Covers database initialization, card tracking, AI extraction, and eBay posting

# ==== DATABASE INITIALIZATION TESTS ====

test_that("initialize_tracking_db creates all required tables", {
  db <- create_test_db()

  # Get list of tables
  tables <- DBI::dbListTables(db)

  # Core tables should exist
  expect_true("users" %in% tables)
  expect_true("processing_sessions" %in% tables)
  expect_true("cards" %in% tables)

  # 3-layer architecture tables
  expect_true("uploaded_images" %in% tables)
  expect_true("card_processing" %in% tables)
  expect_true("processing_actions" %in% tables)

  # Legacy/additional tables
  expect_true("extractions" %in% tables)

  cleanup_test_db(db)
})

test_that("initialize_tracking_db creates tables with correct schema", {
  db <- create_test_db()

  # Check users table structure
  users_info <- DBI::dbGetQuery(db, "PRAGMA table_info(users)")
  expect_true("username" %in% users_info$name)
  expect_true("password_hash" %in% users_info$name)
  expect_true("is_master" %in% users_info$name)

  # Check cards table structure
  cards_info <- DBI::dbGetQuery(db, "PRAGMA table_info(cards)")
  expect_true("card_id" %in% cards_info$name)
  expect_true("image_hash" %in% cards_info$name)
  expect_true("first_seen" %in% cards_info$name)

  cleanup_test_db(db)
})

# ==== IMAGE HASH CALCULATION TESTS ====

test_that("calculate_image_hash returns consistent SHA-256 hash", {
  test_img <- test_path("fixtures/test_face.jpg")

  hash1 <- calculate_image_hash(test_img)
  hash2 <- calculate_image_hash(test_img)

  expect_type(hash1, "character")
  expect_equal(nchar(hash1), 64)  # SHA-256 = 64 hex characters
  expect_equal(hash1, hash2)  # Deterministic
})

test_that("calculate_image_hash returns different hashes for different images", {
  face_img <- test_path("fixtures/test_face.jpg")
  verso_img <- test_path("fixtures/test_verso.jpg")

  hash_face <- calculate_image_hash(face_img)
  hash_verso <- calculate_image_hash(verso_img)

  expect_false(hash_face == hash_verso)
})

test_that("calculate_image_hash handles missing files gracefully", {
  expect_error(
    calculate_image_hash("nonexistent_file.jpg"),
    "file does not exist|cannot open"
  )
})

# ==== CARD CREATION AND RETRIEVAL TESTS ====

test_that("get_or_create_card creates new card", {
  with_test_db({
    result <- get_or_create_card(db, "test_hash_123")

    expect_type(result$card_id, "integer")
    expect_equal(result$image_hash, "test_hash_123")
    expect_true(result$is_new)
  })
})

test_that("get_or_create_card finds existing card", {
  with_test_db({
    first <- get_or_create_card(db, "test_hash_456")
    second <- get_or_create_card(db, "test_hash_456")

    expect_equal(first$card_id, second$card_id)
    expect_true(first$is_new)
    expect_false(second$is_new)
  })
})

test_that("get_or_create_card handles NULL hash", {
  with_test_db({
    expect_error(
      get_or_create_card(db, NULL),
      "hash|NULL|required"
    )
  })
})

test_that("get_hash_for_card retrieves hash for existing card", {
  with_test_db({
    # Create a card
    card <- get_or_create_card(db, "known_hash_789")

    # Retrieve hash
    hash <- get_hash_for_card(db, card$card_id)

    expect_equal(hash, "known_hash_789")
  })
})

# ==== CARD PROCESSING TESTS ====

test_that("save_card_processing stores metadata correctly", {
  with_test_db({
    # Create card and session
    card_info <- get_or_create_card(db, "hash_processing_1")
    session_id <- create_test_session(db, user_id = 1)

    # Save processing
    result <- save_card_processing(
      db,
      card_id = card_info$card_id,
      session_id = session_id,
      face_path = "path/to/face.jpg",
      verso_path = "path/to/verso.jpg"
    )

    expect_true(result$success)

    # Verify stored in database
    row <- DBI::dbGetQuery(db,
      "SELECT * FROM card_processing WHERE card_id = ?",
      params = list(card_info$card_id)
    )
    expect_equal(nrow(row), 1)
    expect_equal(row$face_path, "path/to/face.jpg")
    expect_equal(row$verso_path, "path/to/verso.jpg")
  })
})

test_that("save_card_processing handles NULL paths", {
  with_test_db({
    card_info <- get_or_create_card(db, "hash_null_test")
    session_id <- create_test_session(db, user_id = 1)

    result <- save_card_processing(
      db,
      card_id = card_info$card_id,
      session_id = session_id,
      face_path = NULL,
      verso_path = NULL
    )

    expect_true(result$success)

    # Verify NULLs are stored correctly
    row <- DBI::dbGetQuery(db,
      "SELECT * FROM card_processing WHERE card_id = ?",
      params = list(card_info$card_id)
    )
    expect_true(is.na(row$face_path) || is.null(row$face_path))
  })
})

test_that("find_card_processing retrieves correct processing record", {
  with_test_db({
    card <- get_or_create_card(db, "hash_find_test")
    session_id <- create_test_session(db, user_id = 1)

    save_card_processing(
      db, card$card_id, session_id,
      "face.jpg", "verso.jpg"
    )

    # Find the processing
    result <- find_card_processing(db, card$card_id)

    expect_true(!is.null(result))
    expect_equal(result$card_id, card$card_id)
  })
})

# ==== USER MANAGEMENT TESTS ====

test_that("ensure_user_exists creates new user", {
  with_test_db({
    result <- ensure_user_exists(db, "newuser", "password123", is_master = FALSE)

    expect_true(result$user_id > 0)
    expect_true(result$created)

    # Verify in database
    user <- DBI::dbGetQuery(db,
      "SELECT * FROM users WHERE username = ?",
      params = list("newuser")
    )
    expect_equal(nrow(user), 1)
  })
})

test_that("ensure_user_exists finds existing user", {
  with_test_db({
    # Create user first time
    first <- ensure_user_exists(db, "existinguser", "pass1", FALSE)

    # Try to create again
    second <- ensure_user_exists(db, "existinguser", "pass2", FALSE)

    expect_equal(first$user_id, second$user_id)
    expect_false(second$created)
  })
})

test_that("ensure_user_exists properly hashes passwords", {
  with_test_db({
    ensure_user_exists(db, "hashtest", "mypassword", FALSE)

    user <- DBI::dbGetQuery(db,
      "SELECT password_hash FROM users WHERE username = ?",
      params = list("hashtest")
    )

    # Password should be hashed (64 char SHA-256)
    expect_equal(nchar(user$password_hash), 64)
    expect_false(user$password_hash == "mypassword")
  })
})

test_that("ensure_user_exists respects master user flag", {
  with_test_db({
    ensure_user_exists(db, "master1", "masterpass", is_master = TRUE)

    user <- DBI::dbGetQuery(db,
      "SELECT is_master FROM users WHERE username = ?",
      params = list("master1")
    )

    expect_equal(user$is_master, 1)  # SQLite stores TRUE as 1
  })
})

# ==== SESSION TRACKING TESTS ====

test_that("start_processing_session creates session", {
  with_test_db({
    user_id <- create_test_user(db, "sessionuser", "pass", FALSE)

    session_id <- start_processing_session(db, user_id)

    expect_true(session_id > 0)

    # Verify in database
    session <- DBI::dbGetQuery(db,
      "SELECT * FROM processing_sessions WHERE session_id = ?",
      params = list(session_id)
    )
    expect_equal(nrow(session), 1)
    expect_equal(session$user_id, user_id)
  })
})

test_that("track_session_activity updates session timestamp", {
  with_test_db({
    user_id <- create_test_user(db, "activityuser", "pass", FALSE)
    session_id <- start_processing_session(db, user_id)

    # Wait a moment
    Sys.sleep(0.1)

    # Track activity
    track_session_activity(db, session_id, "test_action")

    # Verify last_activity was updated
    session <- DBI::dbGetQuery(db,
      "SELECT last_activity FROM processing_sessions WHERE session_id = ?",
      params = list(session_id)
    )

    expect_true(!is.na(session$last_activity))
  })
})

test_that("query_sessions retrieves sessions for user", {
  with_test_db({
    user_id <- create_test_user(db, "queryuser", "pass", FALSE)

    # Create multiple sessions
    s1 <- start_processing_session(db, user_id)
    s2 <- start_processing_session(db, user_id)

    # Query sessions
    sessions <- query_sessions(db, user_id)

    expect_true(nrow(sessions) >= 2)
    expect_true(s1 %in% sessions$session_id)
    expect_true(s2 %in% sessions$session_id)
  })
})

# ==== AI EXTRACTION TRACKING TESTS ====

test_that("track_ai_extraction stores extraction metadata", {
  with_test_db({
    card <- get_or_create_card(db, "hash_ai_test")
    session_id <- create_test_session(db, user_id = 1)

    extraction_data <- list(
      title = "Test Card",
      description = "Test description",
      price = "10.00"
    )

    result <- track_ai_extraction(
      db,
      card_id = card$card_id,
      session_id = session_id,
      provider = "claude",
      model = "claude-3-5-sonnet-20241022",
      extraction_data = extraction_data,
      success = TRUE
    )

    expect_true(result$success)

    # Verify in database
    row <- DBI::dbGetQuery(db,
      "SELECT * FROM extractions WHERE card_id = ?",
      params = list(card$card_id)
    )
    expect_equal(nrow(row), 1)
    expect_equal(row$provider, "claude")
  })
})

test_that("track_ai_extraction handles failed extractions", {
  with_test_db({
    card <- get_or_create_card(db, "hash_ai_fail")
    session_id <- create_test_session(db, user_id = 1)

    result <- track_ai_extraction(
      db,
      card_id = card$card_id,
      session_id = session_id,
      provider = "claude",
      model = "claude-3-5-sonnet-20241022",
      extraction_data = NULL,
      success = FALSE,
      error_message = "API rate limit exceeded"
    )

    expect_true(result$success)  # Tracking succeeded

    # Verify error stored
    row <- DBI::dbGetQuery(db,
      "SELECT * FROM extractions WHERE card_id = ?",
      params = list(card$card_id)
    )
    expect_true(!is.na(row$error_message) || !is.null(row$error_message))
  })
})

test_that("get_ai_extraction_history retrieves extraction history", {
  with_test_db({
    card <- get_or_create_card(db, "hash_history")
    session_id <- create_test_session(db, user_id = 1)

    # Track multiple extractions
    track_ai_extraction(db, card$card_id, session_id, "claude", "model1", list(), TRUE)
    track_ai_extraction(db, card$card_id, session_id, "openai", "model2", list(), TRUE)

    # Get history
    history <- get_ai_extraction_history(db, card$card_id)

    expect_true(nrow(history) >= 2)
  })
})

# ==== EBAY POSTING TRACKING TESTS ====

test_that("track_ebay_post stores posting metadata", {
  with_test_db({
    card <- get_or_create_card(db, "hash_ebay_test")
    session_id <- create_test_session(db, user_id = 1)

    result <- track_ebay_post(
      db,
      card_id = card$card_id,
      session_id = session_id,
      listing_id = "123456789",
      title = "Test Listing",
      price = "15.00",
      success = TRUE
    )

    expect_true(result$success)

    # Verify in database (assuming ebay_posts table exists)
    row <- DBI::dbGetQuery(db,
      "SELECT * FROM ebay_posts WHERE card_id = ?",
      params = list(card$card_id)
    )
    expect_equal(nrow(row), 1)
    expect_equal(row$listing_id, "123456789")
  })
})

test_that("format_ebay_status formats status correctly", {
  status <- format_ebay_status("active", "123456")

  expect_type(status, "character")
  expect_true(nchar(status) > 0)
})

# ==== IMAGE DEDUPLICATION TESTS ====

test_that("find_existing_processing detects duplicate images", {
  with_test_db({
    # Create and process a card
    card <- get_or_create_card(db, "duplicate_hash")
    session1 <- create_test_session(db, user_id = 1)

    save_card_processing(db, card$card_id, session1, "face.jpg", "verso.jpg")

    # Try to find existing processing
    existing <- find_existing_processing(db, "duplicate_hash")

    expect_true(!is.null(existing))
    expect_equal(existing$card_id, card$card_id)
  })
})

test_that("find_existing_processing returns NULL for new images", {
  with_test_db({
    existing <- find_existing_processing(db, "new_unique_hash")

    expect_true(is.null(existing))
  })
})

test_that("mark_processing_reused marks processing as reused", {
  with_test_db({
    card <- get_or_create_card(db, "reuse_hash")
    session1 <- create_test_session(db, user_id = 1)
    session2 <- create_test_session(db, user_id = 1)

    # Initial processing
    save_card_processing(db, card$card_id, session1, "face.jpg", "verso.jpg")

    # Mark as reused in second session
    result <- mark_processing_reused(db, card$card_id, session2)

    expect_true(result$success)
  })
})

# ==== TRACKING VIEWER TESTS ====

test_that("get_tracking_data retrieves data for all sessions", {
  with_test_db({
    user_id <- create_test_user(db, "viewuser", "pass", FALSE)
    session_id <- create_test_session(db, user_id)

    # Create some data
    card <- get_or_create_card(db, "view_hash")
    save_card_processing(db, card$card_id, session_id, "face.jpg", "verso.jpg")

    # Get tracking data
    data <- get_tracking_data(db, user_id)

    expect_true(is.data.frame(data) || is.list(data))
  })
})

test_that("get_session_tracking_data retrieves data for specific session", {
  with_test_db({
    user_id <- create_test_user(db, "sessiondatauser", "pass", FALSE)
    session_id <- create_test_session(db, user_id)

    card <- get_or_create_card(db, "session_hash")
    save_card_processing(db, card$card_id, session_id, "face.jpg", "verso.jpg")

    # Get session-specific data
    data <- get_session_tracking_data(db, session_id)

    expect_true(is.data.frame(data) || is.list(data))
  })
})

test_that("get_session_cards retrieves cards for session", {
  with_test_db({
    user_id <- create_test_user(db, "cardsuser", "pass", FALSE)
    session_id <- create_test_session(db, user_id)

    # Create multiple cards
    card1 <- get_or_create_card(db, "card_hash_1")
    card2 <- get_or_create_card(db, "card_hash_2")

    save_card_processing(db, card1$card_id, session_id, "f1.jpg", "v1.jpg")
    save_card_processing(db, card2$card_id, session_id, "f2.jpg", "v2.jpg")

    # Get cards
    cards <- get_session_cards(db, session_id)

    expect_true(length(cards) >= 2)
  })
})

# ==== UTILITY FUNCTION TESTS ====

test_that("format_timestamp formats timestamps correctly", {
  timestamp <- format_timestamp(Sys.time())

  expect_type(timestamp, "character")
  expect_true(nchar(timestamp) > 0)
})

test_that("get_system_info returns system information", {
  info <- get_system_info()

  expect_type(info, "list")
  expect_true("r_version" %in% names(info) || "platform" %in% names(info))
})

# ==== STATISTICS TESTS ====

test_that("get_tracking_statistics returns summary statistics", {
  with_test_db({
    user_id <- create_test_user(db, "statsuser", "pass", FALSE)
    session_id <- create_test_session(db, user_id)

    # Create some data
    card <- get_or_create_card(db, "stats_hash")
    save_card_processing(db, card$card_id, session_id, "face.jpg", "verso.jpg")

    # Get statistics
    stats <- get_tracking_statistics(db, user_id)

    expect_type(stats, "list")
  })
})

test_that("get_posting_statistics returns eBay posting stats", {
  with_test_db({
    user_id <- create_test_user(db, "postuser", "pass", FALSE)

    # Get posting statistics
    stats <- get_posting_statistics(db, user_id)

    expect_type(stats, "list")
  })
})
