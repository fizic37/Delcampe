# Helper functions for test setup and teardown
# This file is automatically sourced by testthat before running tests

#' Create an in-memory test database
#'
#' Creates a temporary SQLite database in memory with the full Delcampe schema
#' initialized. This database is isolated from production data.
#'
#' @return A DBI connection object to the test database
#' @export
#'
#' @examples
#' db <- create_test_db()
#' # Use database for testing...
#' cleanup_test_db(db)
create_test_db <- function() {
  # Create in-memory SQLite database
  db <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")

  # Initialize the full schema using the app's initialization function
  # This ensures test DB matches production structure
  tryCatch({
    initialize_tracking_db(db)
  }, error = function(e) {
    warning("Failed to initialize test database: ", e$message)
    DBI::dbDisconnect(db)
    stop("Test database initialization failed")
  })

  return(db)
}

#' Clean up and disconnect a test database
#'
#' Properly disconnects from a test database connection and cleans up resources.
#'
#' @param db A DBI connection object
#' @return NULL (called for side effects)
#' @export
#'
#' @examples
#' db <- create_test_db()
#' # ... run tests ...
#' cleanup_test_db(db)
cleanup_test_db <- function(db) {
  if (!is.null(db) && DBI::dbIsValid(db)) {
    DBI::dbDisconnect(db)
  }
  invisible(NULL)
}

#' Execute code with a temporary test database
#'
#' Provides a withr-style wrapper that creates a test database, executes code,
#' and ensures proper cleanup even if errors occur.
#'
#' @param code Code to execute with the test database
#' @return The result of evaluating code
#' @export
#'
#' @examples
#' with_test_db({
#'   # db is available in this scope
#'   result <- get_or_create_card(db, "test_hash")
#'   expect_true(result$is_new)
#' })
with_test_db <- function(code) {
  db <- create_test_db()

  # Use on.exit to ensure cleanup happens even if code fails
  on.exit(cleanup_test_db(db), add = TRUE)

  # Make db available in the calling environment
  eval(substitute(code), envir = list(db = db), enclos = parent.frame())
}

#' Create a test user in the database
#'
#' Helper to quickly create test users with known credentials.
#' Passwords are properly hashed using the same method as production.
#'
#' @param db Database connection
#' @param username Username for the test user
#' @param password Plain-text password (will be hashed)
#' @param is_master Whether user should be a master user
#' @return The user_id of the created user
#' @export
#'
#' @examples
#' db <- create_test_db()
#' user_id <- create_test_user(db, "testuser", "testpass", FALSE)
create_test_user <- function(db, username = "testuser", password = "testpass", is_master = FALSE) {
  # Hash password using the same method as production
  password_hash <- digest::digest(password, algo = "sha256", serialize = FALSE)

  # Insert user
  DBI::dbExecute(
    db,
    "INSERT INTO users (username, password_hash, is_master, created_at) VALUES (?, ?, ?, ?)",
    params = list(username, password_hash, as.integer(is_master), as.character(Sys.time()))
  )

  # Return the user_id
  user_id <- DBI::dbGetQuery(db, "SELECT last_insert_rowid() as id")$id
  return(user_id)
}

#' Create a test processing session
#'
#' Helper to create a processing session for testing
#'
#' @param db Database connection
#' @param user_id User ID (default 1)
#' @return The session_id of the created session
#' @export
create_test_session <- function(db, user_id = 1) {
  DBI::dbExecute(
    db,
    "INSERT INTO processing_sessions (user_id, session_start) VALUES (?, ?)",
    params = list(user_id, as.character(Sys.time()))
  )

  session_id <- DBI::dbGetQuery(db, "SELECT last_insert_rowid() as id")$id
  return(session_id)
}
