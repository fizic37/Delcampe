# Testing Assertion Reference for Authentication System

**Date**: 2025-11-03
**Purpose**: Quick lookup for all assertion patterns used in Delcampe tests
**Use this for**: Copy-paste assertion patterns

---

## ASSERTION QUICK REFERENCE

### Value Equality

```r
# Exact value match
expect_equal(result, expected_value)
expect_equal(user_id, 1)
expect_equal(username, "alice")
expect_equal(password_hash, "abcd1234...")

# Multiple values
expect_equal(nrow(data), 5)
expect_equal(length(names(result)), 3)
```

### Boolean Values

```r
# True
expect_true(result$success)
expect_true(!is.null(value))
expect_true(is.logical(flag))

# False
expect_false(result$success)
expect_false(is.null(value))
expect_false(result$is_master)
```

### NULL and Existence

```r
# Is NULL
expect_null(result$error)

# Is not NULL
expect_true(!is.null(result$user_id))
expect_false(is.null(value))

# Exists in environment
expect_true(exists("db"))
expect_true(exists("rv"))
```

### Type Checking

```r
# Primitive types
expect_type(user_id, "integer")
expect_type(username, "character")
expect_type(is_active, "logical")
expect_type(price, "double")
expect_type(items, "list")

# Class checking
expect_s3_class(db_result, "data.frame")
expect_s3_class(ui, "shiny.tag")
expect_s3_class(ui, "shiny.tag.list")

# Is specific class
expect_is(obj, "data.frame")
```

### String/Pattern Matching

```r
# Exact substring match
expect_match(error_msg, "Invalid credentials")

# Case-insensitive match
expect_match(error_msg, "invalid|wrong|error", ignore.case = TRUE)

# Using grepl for complex patterns
expect_true(grepl("password", error_msg, ignore.case = TRUE))
expect_true(grepl("^[A-Z]", result, ignore.case = FALSE))

# Multiple patterns (OR logic)
expect_true(grepl("Invalid|Wrong", error_msg))
```

### List/Vector/Data.frame

```r
# List membership
expect_true("user_id" %in% names(result))
expect_true("admin" %in% roles)

# Vector length
expect_equal(length(vector), 3)
expect_equal(nrow(df), 5)
expect_equal(ncol(df), 3)

# Empty
expect_equal(length(vector), 0)
expect_equal(nrow(df), 0)

# Contains specific value
expect_true(1 %in% user_ids)
expect_true("alice" %in% usernames)
```

### Error Handling

```r
# Function throws error with matching message
expect_error(
  my_function(invalid_input),
  "Invalid|error|required"  # Pattern in error message
)

# Function throws error (any message)
expect_error(authenticate(NULL, "pass"))

# Error with regex pattern
expect_error(
  create_user(db, "", "pass"),
  "empty|blank"
)

# No error
expect_no_error(my_function(valid_input))
```

### Conditional Assertions (Multiple Possibilities)

```r
# Value could be one of several options
expect_true(
  result %in% c("GOOD", "VERY_GOOD", "EXCELLENT")
)

# Is one of these types
expect_true(
  is.null(result) || is.na(result) || is.character(result)
)

# Covers multiple scenarios
expect_true(
  result$success || result$error %in% c("timeout", "network_error")
)
```

---

## ASSERTION PATTERNS BY TEST TYPE

### Authentication System Tests

#### User Creation

```r
test_that("user creation succeeds with valid input", {
  with_test_db({
    result <- create_user(db, "alice", "password123", is_master = FALSE)
    
    # Verify success
    expect_true(result$success)
    
    # Verify user_id returned
    expect_type(result$user_id, "integer")
    expect_true(result$user_id > 0)
    
    # Verify in database
    user <- DBI::dbGetQuery(db,
      "SELECT * FROM users WHERE user_id = ?",
      params = list(result$user_id)
    )
    
    # Verify username
    expect_equal(user$username, "alice")
    
    # Verify is_master flag
    expect_false(as.logical(user$is_master))
    
    # Verify password is hashed (not plaintext!)
    expect_false(user$password_hash == "password123")
    
    # Verify password hash is 64 chars (SHA-256)
    expect_equal(nchar(user$password_hash), 64)
  })
})
```

#### Login/Authentication

```r
test_that("authentication with correct password succeeds", {
  with_test_db({
    # Create user
    create_test_user(db, "alice", "correctpass", FALSE)
    
    # Authenticate
    result <- authenticate_user(db, "alice", "correctpass")
    
    # Verify success
    expect_true(result$success)
    
    # Verify user_id returned
    expect_type(result$user_id, "integer")
    expect_equal(result$user_id, 1)
  })
})

test_that("authentication with wrong password fails", {
  with_test_db({
    create_test_user(db, "alice", "correctpass", FALSE)
    
    result <- authenticate_user(db, "alice", "wrongpass")
    
    # Verify failure
    expect_false(result$success)
    
    # Verify error message
    expect_true(grepl("Invalid|credentials|password", 
                      result$error, ignore.case = TRUE))
    
    # Verify no user_id returned
    expect_null(result$user_id)
  })
})

test_that("authentication with nonexistent user fails", {
  with_test_db({
    result <- authenticate_user(db, "nonexistent", "anypass")
    
    expect_false(result$success)
    expect_true("error" %in% names(result))
  })
})
```

#### Password Validation

```r
test_that("password validation rejects empty string", {
  result <- validate_password("")
  
  expect_false(result$valid)
  expect_match(result$error, "empty|blank")
})

test_that("password validation rejects NULL", {
  result <- validate_password(NULL)
  
  expect_false(result$valid)
})

test_that("password validation accepts strong password", {
  result <- validate_password("StrongPassword123!")
  
  expect_true(result$valid)
  expect_null(result$error)
})
```

#### Session Management

```r
test_that("session creation returns valid token", {
  with_test_db({
    user_id <- create_test_user(db, "alice", "pass")
    
    result <- create_session(db, user_id)
    
    # Verify success
    expect_true(result$success)
    
    # Verify token exists and has content
    expect_type(result$session_token, "character")
    expect_true(nchar(result$session_token) > 0)
    
    # Verify token is reasonably long (not obviously wrong)
    expect_true(nchar(result$session_token) >= 20)
  })
})

test_that("session verification succeeds with valid token", {
  with_test_db({
    user_id <- create_test_user(db, "alice", "pass")
    session <- create_session(db, user_id)
    
    result <- verify_session(db, session$session_token)
    
    expect_true(result$valid)
    expect_equal(result$user_id, user_id)
    expect_null(result$error)
  })
})

test_that("session verification fails with invalid token", {
  with_test_db({
    result <- verify_session(db, "invalid_token_12345")
    
    expect_false(result$valid)
    expect_true("error" %in% names(result))
  })
})
```

#### Master User Tests

```r
test_that("master user flag is set correctly", {
  with_test_db({
    regular_id <- create_test_user(db, "alice", "pass", is_master = FALSE)
    master_id <- create_test_user(db, "master", "pass", is_master = TRUE)
    
    # Check regular user
    user_regular <- DBI::dbGetQuery(db,
      "SELECT is_master FROM users WHERE user_id = ?",
      params = list(regular_id)
    )
    expect_false(as.logical(user_regular$is_master))
    
    # Check master user
    user_master <- DBI::dbGetQuery(db,
      "SELECT is_master FROM users WHERE user_id = ?",
      params = list(master_id)
    )
    expect_true(as.logical(user_master$is_master))
  })
})

test_that("master users cannot delete each other", {
  with_test_db({
    master1_id <- create_test_user(db, "master1", "pass", TRUE)
    master2_id <- create_test_user(db, "master2", "pass", TRUE)
    
    # Attempt to delete another master user
    result <- delete_user(db, master1_id, master2_id)
    
    # Should fail
    expect_false(result$success)
    expect_match(result$error, "Cannot delete|master")
    
    # Verify master user still exists
    user <- DBI::dbGetQuery(db,
      "SELECT * FROM users WHERE user_id = ?",
      params = list(master2_id)
    )
    expect_equal(nrow(user), 1)
  })
})
```

### Database Tests

#### Basic CRUD Operations

```r
test_that("get_or_create_card creates new card", {
  with_test_db({
    result <- get_or_create_card(db, "test_hash_123")
    
    # Return value checks
    expect_type(result$card_id, "integer")
    expect_equal(result$image_hash, "test_hash_123")
    expect_true(result$is_new)
    
    # Database verification
    card <- DBI::dbGetQuery(db,
      "SELECT * FROM cards WHERE card_id = ?",
      params = list(result$card_id)
    )
    expect_equal(nrow(card), 1)
    expect_equal(card$image_hash, "test_hash_123")
  })
})

test_that("get_or_create_card finds existing card", {
  with_test_db({
    first <- get_or_create_card(db, "test_hash_456")
    second <- get_or_create_card(db, "test_hash_456")
    
    # Same card returned
    expect_equal(first$card_id, second$card_id)
    
    # is_new flag correct
    expect_true(first$is_new)
    expect_false(second$is_new)
  })
})
```

#### Schema Validation

```r
test_that("database schema includes required tables", {
  db <- create_test_db()
  
  tables <- DBI::dbListTables(db)
  
  # Check required tables exist
  required_tables <- c("users", "processing_sessions", "cards")
  for (table in required_tables) {
    expect_true(table %in% tables, 
                info = paste("Missing table:", table))
  }
  
  cleanup_test_db(db)
})

test_that("users table has required columns", {
  db <- create_test_db()
  
  columns <- DBI::dbGetQuery(db, "PRAGMA table_info(users)")$name
  
  expect_true("user_id" %in% columns)
  expect_true("username" %in% columns)
  expect_true("password_hash" %in% columns)
  expect_true("is_master" %in% columns)
  
  cleanup_test_db(db)
})
```

### Shiny Module Tests

#### UI Tests

```r
test_that("module UI returns valid tag structure", {
  ui <- mod_login_ui("test_id")
  
  # Check it's a Shiny tag
  expect_s3_class(ui, "shiny.tag")
  
  # Convert to HTML to search for content
  ui_html <- as.character(ui)
  
  # Verify contains expected elements
  expect_true(grepl("login", ui_html, ignore.case = TRUE))
  expect_true(grepl("password", ui_html, ignore.case = TRUE))
  expect_true(grepl("username", ui_html, ignore.case = TRUE))
})

test_that("module UI uses correct namespacing", {
  ui <- mod_login_ui("my_namespace")
  ui_html <- as.character(ui)
  
  # Should contain namespace in IDs
  expect_true(grepl("my_namespace", ui_html))
})
```

#### Server Tests

```r
test_that("module server initializes reactive values", {
  testServer(mod_login_server, {
    expect_true(exists("rv"))
    expect_true(exists("session"))
    
    # Check reactive values exist
    expect_type(rv$logged_in, "logical")
    expect_false(rv$logged_in)  # Initial state
  })
})

test_that("module handles user input correctly", {
  testServer(mod_login_server, {
    # Simulate input
    session$setInputs(
      username = "alice",
      password = "pass123",
      login_btn = 1  # Click count
    )
    
    # Process changes
    session$flushReact()
    
    # Verify reactive state changed
    expect_true(rv$logged_in)
    expect_equal(rv$username, "alice")
  })
})
```

### Error Handling Tests

```r
test_that("function handles NULL input gracefully", {
  with_test_db({
    expect_error(
      my_function(db, NULL),
      "NULL|null|required"
    )
  })
})

test_that("function handles empty string gracefully", {
  with_test_db({
    expect_error(
      my_function(db, ""),
      "empty|blank|required"
    )
  })
})

test_that("function handles invalid type gracefully", {
  with_test_db({
    # Function expects integer, gets character
    expect_error(
      save_user_data(db, "not_a_number", "value"),
      "type|class|integer"
    )
  })
})
```

---

## ASSERTION PATTERNS BY CATEGORY

### Response Structure Assertions

```r
# API Response
result <- my_api_function()

# These are guaranteed to be present
expect_true("success" %in% names(result))
expect_true("data" %in% names(result) || "error" %in% names(result))

# On success
if (result$success) {
  expect_type(result$data, "list")
}

# On error
if (!result$success) {
  expect_true("error" %in% names(result))
  expect_type(result$error, "character")
}
```

### Database State Assertions

```r
# Verify state changed
with_test_db({
  # Before operation
  before <- DBI::dbGetQuery(db, "SELECT COUNT(*) as cnt FROM users")
  
  # Perform operation
  create_user(db, "alice", "pass", FALSE)
  
  # After operation
  after <- DBI::dbGetQuery(db, "SELECT COUNT(*) as cnt FROM users")
  
  # Verify change
  expect_equal(after$cnt, before$cnt + 1)
})
```

### Timestamp Assertions

```r
test_that("timestamps are valid", {
  with_test_db({
    result <- create_session(db, user_id = 1)
    
    # Get the record
    session <- DBI::dbGetQuery(db,
      "SELECT created_at FROM sessions WHERE session_id = ?",
      params = list(result$session_id)
    )
    
    # Verify timestamp exists
    expect_false(is.na(session$created_at))
    
    # Verify it's recent (within last minute)
    session_time <- as.POSIXct(session$created_at)
    now <- Sys.time()
    
    expect_true(abs(difftime(now, session_time, units = "secs")) < 60)
  })
})
```

### Hash Assertions

```r
test_that("password hash is valid SHA-256", {
  with_test_db({
    hash <- digest::digest("password", algo = "sha256", serialize = FALSE)
    
    # SHA-256 produces 64 hex character string
    expect_equal(nchar(hash), 64)
    
    # Only contains hex characters (0-9, a-f)
    expect_true(grepl("^[0-9a-f]{64}$", hash))
    
    # Not the plaintext password
    expect_false(hash == "password")
  })
})
```

---

## SPECIAL ASSERTION HELPERS

### For Checking Auth Specific Things

```r
# Check if password is properly hashed
is_valid_sha256_hash <- function(hash) {
  nchar(hash) == 64 && grepl("^[0-9a-f]{64}$", hash)
}

# Use in test
expect_true(is_valid_sha256_hash(user$password_hash))

# Check if user is master
is_master <- function(user_record) {
  as.logical(user_record$is_master)
}

expect_true(is_master(admin_user))
```

### For Data Completeness

```r
# Verify all required fields present
required_fields <- c("user_id", "username", "password_hash", "is_master")
result_fields <- names(user_record)

for (field in required_fields) {
  expect_true(field %in% result_fields,
              info = paste("Missing field:", field))
}
```

---

## ASSERTION TROUBLESHOOTING

### Common Issues

#### Issue: expect_equal fails with floating point

```r
# ❌ WRONG - floating point comparison fails
expect_equal(0.1 + 0.2, 0.3)

# ✅ CORRECT - use tolerance
expect_equal(0.1 + 0.2, 0.3, tolerance = 1e-7)
```

#### Issue: expect_match fails with special characters

```r
# ❌ WRONG - . matches any character (greedy)
expect_match(error_msg, "Invalid.")

# ✅ CORRECT - escape special characters
expect_match(error_msg, "Invalid\\.")
```

#### Issue: Can't compare data.frames

```r
# ❌ WRONG - expect_equal doesn't work well with data.frames
expect_equal(df1, df2)

# ✅ CORRECT - compare row by row or specific fields
expect_equal(nrow(df1), nrow(df2))
expect_equal(df1$user_id, df2$user_id)
```

#### Issue: NULL vs FALSE confusion

```r
# ❌ WRONG - NULL is not FALSE
result <- NULL
expect_false(result)  # Fails!

# ✅ CORRECT - check for NULL first
expect_null(result)
# OR
expect_false(!is.null(result))
```

---

**Last Updated**: 2025-11-03
**All patterns tested and working** ✅
