# Complete Testing Infrastructure Patterns for Authentication System

**Date**: 2025-11-03
**Purpose**: Actionable copy-paste patterns for writing comprehensive auth system tests
**Status**: Ready for implementation

---

## TABLE OF CONTENTS

1. Helper Functions Available
2. Exact Database Testing Pattern (with_test_db)
3. Module Testing Pattern (testServer)
4. Mock Patterns for External Dependencies
5. Test Structure and Organization
6. Critical vs Discovery Tests
7. Assertion Patterns
8. Complete Example Test Files
9. Test Data Setup Patterns
10. Running Tests (Commands)

---

## 1. HELPER FUNCTIONS AVAILABLE

### Location
- `tests/testthat/helper-setup.R` - Database utilities
- `tests/testthat/helper-mocks.R` - API mocking
- `tests/testthat/helper-fixtures.R` - Test data generators

### Database Helpers (helper-setup.R)

```r
# Create in-memory test database with full schema
db <- create_test_db()

# Disconnect properly
cleanup_test_db(db)

# Use with automatic cleanup (PREFERRED - use this!)
with_test_db({
  # db is available here
  result <- get_or_create_card(db, "test_hash")
  expect_true(result$is_new)
})

# Create test user (passwords auto-hashed with SHA-256)
user_id <- create_test_user(db, 
                             username = "testuser", 
                             password = "testpass", 
                             is_master = FALSE)

# Create test session
session_id <- create_test_session(db, user_id = 1)
```

### Mock Helpers (helper-mocks.R)

```r
# Mock Claude API responses
response <- mock_claude_response(success = TRUE)
response <- mock_claude_response(success = FALSE)

# Mock OpenAI responses
response <- mock_openai_response(success = TRUE)

# Mock eBay OAuth
token <- mock_ebay_oauth(success = TRUE)

# Use mocked AI in tests (no real API calls)
with_mocked_ai({
  result <- call_claude_api(test_image, "prompt")
  expect_true(result$success)
}, provider = "claude")

# Use mocked eBay
with_mocked_ebay({
  result <- authenticate_ebay()
  expect_true(result$access_token)
}, success = TRUE)

# Mock file uploads
upload <- mock_file_upload("path/to/test.jpg")
```

### Fixture Helpers (helper-fixtures.R)

```r
# Generate test data (all properly formatted)
card <- generate_test_card(id = 1, title = "Custom Title")
user <- generate_test_user(username = "alice", password = "pass123")
extraction <- sample_ai_extraction(side = "face", quality = "high")
session <- generate_test_session(session_id = 1, user_id = 1, num_cards = 5)
crops <- generate_test_crops(num_crops = 6)
ebay_listing <- generate_test_ebay_listing(listing_id = 1)
delcampe_export <- generate_test_delcampe_export(export_id = 1)
```

---

## 2. EXACT DATABASE TESTING PATTERN

### Pattern: with_test_db() - COPY THIS

```r
test_that("function name describes what it does", {
  with_test_db({
    # ARRANGE - Set up test data
    user_id <- create_test_user(db, "testuser", "testpass", FALSE)
    session_id <- create_test_session(db, user_id = user_id)
    card <- get_or_create_card(db, "test_hash_123")
    
    # ACT - Call the function being tested
    result <- my_database_function(db, user_id, session_id)
    
    # ASSERT - Verify the result
    expect_true(result$success)
    expect_equal(result$user_id, user_id)
    
    # Optional: Verify state in database
    row <- DBI::dbGetQuery(db, 
      "SELECT * FROM users WHERE user_id = ?",
      params = list(user_id)
    )
    expect_equal(nrow(row), 1)
    expect_equal(row$username, "testuser")
  })
})
```

### Key Points
1. `with_test_db()` automatically creates db and cleans up with `on.exit()`
2. `db` is available in the scope automatically
3. No manual cleanup needed (even if test fails)
4. Database is in-memory SQLite (fast and isolated)
5. Full schema initialized via `initialize_tracking_db(db)`

### Real Example from Codebase

```r
test_that("get_or_create_card creates new card", {
  with_test_db({
    result <- get_or_create_card(db, "test_hash_123")

    expect_type(result$card_id, "integer")
    expect_equal(result$image_hash, "test_hash_123")
    expect_true(result$is_new)
  })
})
```

---

## 3. MODULE TESTING PATTERN

### Pattern: testServer() - COPY THIS

```r
test_that("mod_example_server does something", {
  testServer(mod_example_server, args = list(db = db), {
    # Simulate user input
    session$setInputs(
      username = "testuser",
      password = "testpass",
      login_button = 1  # Click count
    )
    
    # Process reactives
    session$flushReact()
    
    # Assert reactive values changed
    expect_true(rv$logged_in)
    expect_equal(rv$user_id, 1)
    
    # Assert outputs were rendered
    expect_false(is.null(output$welcome_message))
  })
})
```

### Pattern with Database

```r
test_that("mod_login_server authenticates user", {
  skip("Requires auth_system mocking")  # Skip if still developing
  
  with_test_db({
    # Create test user
    create_test_user(db, "alice", "password123", FALSE)
    
    # Initialize module
    testServer(mod_login_server, args = list(db = db), {
      # Simulate login attempt
      session$setInputs(
        username = "alice",
        password = "password123",
        login = 1
      )
      
      session$flushReact()
      
      # Verify authenticated
      expect_true(rv$logged_in)
      expect_equal(rv$username, "alice")
    })
  })
})
```

### Key Points
1. Use `testServer()` for module server logic
2. Pass module args: `args = list(db = db, vals = vals, ...)`
3. Set inputs: `session$setInputs(id1 = value1, id2 = value2)`
4. Flush reactives: `session$flushReact()`
5. Test reactive values: `expect_true(rv$name)`
6. Test outputs: `expect_false(is.null(output$id))`
7. Use `skip()` if test needs work

### Module Server Tests (Real Examples)

#### Test 1: UI Generation
```r
test_that("mod_login_ui generates valid UI", {
  ui <- mod_login_ui("test")
  
  expect_s3_class(ui, "shiny.tag")
  ui_html <- as.character(ui)
  expect_true(grepl("login", ui_html, ignore.case = TRUE))
})
```

#### Test 2: Namespaced IDs
```r
test_that("mod_login_ui uses namespaced IDs", {
  ui <- mod_login_ui("test_namespace")
  ui_html <- as.character(ui)
  
  expect_true(grepl("test_namespace", ui_html))
})
```

#### Test 3: Module Initialization
```r
test_that("mod_delcampe_export_server initializes with NULL images", {
  testServer(mod_delcampe_export_server, {
    expect_true(is.environment(session))
    expect_true(exists("rv"))
    expect_type(rv$sent_images, "character")
  })
})
```

---

## 4. MOCK PATTERNS FOR EXTERNAL DEPENDENCIES

### Pattern: Mocking AI API Calls

```r
test_that("function handles Claude API response", {
  with_mocked_ai({
    result <- call_claude_api("test_image.jpg", "Extract title")
    expect_true(result$success)
    expect_type(result$data$title, "character")
  }, provider = "claude", success = TRUE)
})

test_that("function handles API failure gracefully", {
  with_mocked_ai({
    result <- call_claude_api("test_image.jpg", "Extract")
    expect_false(result$success)
    expect_true("error" %in% names(result))
  }, provider = "claude", success = FALSE)
})
```

### Pattern: Mocking eBay Auth

```r
test_that("function handles eBay OAuth", {
  with_mocked_ebay({
    token <- get_ebay_oauth_token()
    expect_equal(token$token_type, "User Access Token")
    expect_true(!is.null(token$access_token))
  }, success = TRUE)
})
```

### Pattern: Mock Responses (Custom)

```r
# Create mock response manually
mock_response <- list(
  success = TRUE,
  data = list(
    title = "Test Title",
    description = "Test Description"
  )
)

# Use with expect_equal to verify function returns expected structure
result <- my_function()
expect_equal(result$success, mock_response$success)
expect_equal(result$data$title, mock_response$data$title)
```

### Real Example from Codebase

```r
test_that("mock_claude_response creates valid structure", {
  response <- mock_claude_response(success = TRUE)
  
  expect_true(response$success)
  expect_type(response$data, "list")
  expect_equal(response$model, "claude-3-5-sonnet-20241022")
  expect_type(response$tokens_used, "integer")
})
```

---

## 5. TEST STRUCTURE AND ORGANIZATION

### File Organization

```
tests/
├── testthat.R                         # Entry point
├── testthat/
│   ├── helper-setup.R                 # Database utilities (auto-loaded)
│   ├── helper-mocks.R                 # API mocking (auto-loaded)
│   ├── helper-fixtures.R              # Data generators (auto-loaded)
│   ├── test-tracking_database.R       # Database tests
│   ├── test-ebay_helpers.R            # eBay business logic
│   ├── test-mod_login.R               # Login module
│   ├── test-mod_delcampe_export.R     # Delcampe export module
│   └── [test-auth_system.R]           # NEW: Auth system tests
└── fixtures/
    ├── test_face.jpg                  # Test image
    ├── test_verso.jpg                 # Test image
    └── mock_api_responses/            # Mock JSON responses
```

### File Naming Convention

```
test-<component_name>.R

Examples:
- test-tracking_database.R   (for tracking_database.R module)
- test-auth_system.R         (for auth_system.R module)
- test-mod_login.R           (for mod_login.R Shiny module)
```

### Test Organization Within File

```r
# ==== SETUP/INITIALIZATION TESTS ====
test_that("function initializes correctly", { ... })

# ==== HAPPY PATH TESTS ====
test_that("function works with valid input", { ... })
test_that("function returns correct output", { ... })

# ==== ERROR HANDLING TESTS ====
test_that("function handles NULL input", { ... })
test_that("function handles empty string", { ... })
test_that("function handles invalid type", { ... })

# ==== EDGE CASE TESTS ====
test_that("function handles boundary values", { ... })
test_that("function handles large datasets", { ... })

# ==== INTEGRATION TESTS ====
test_that("function works with other modules", { ... })
```

---

## 6. CRITICAL VS DISCOVERY TESTS

### Critical Tests (Always Pass)

**What goes here:**
- Core business logic (authentication, validation, database ops)
- Functions used throughout the codebase
- Features that block other work if broken

**Test files:**
- `test-ebay_helpers.R` - ~30 tests, all passing
- `test-utils_helpers.R` - ~30 tests, all passing
- `test-mod_delcampe_export.R` - ~50 tests, all passing
- `test-mod_tracking_viewer.R` - ~60 tests, all passing
- `[test-auth_system.R]` - SHOULD be here when complete

**Running:**
```r
source("dev/run_critical_tests.R")
# Expected: 100% pass rate (~170 tests)
# Time: 10-20 seconds
# Use: Before every commit
```

### Discovery Tests (Learning Tool)

**What goes here:**
- Exploratory tests (failures teach us)
- Tests with known failures (show gaps)
- Template tests (mostly skipped)
- Edge cases we're investigating

**Test files:**
- `test-ai_api_helpers.R` - AI integration
- `test-tracking_database.R` - Database functions
- `test-mod_login.R` - Login module template

**Running:**
```r
source("dev/run_discovery_tests.R")
# Expected: Some failures OK
# Time: 30-60 seconds
# Use: During development/exploration
```

### Classification Decision Tree

```
New test for:
├── Core auth logic? → CRITICAL
├── Validation? → CRITICAL
├── Error handling? → CRITICAL
├── Edge case exploration? → DISCOVERY
├── Experimental feature? → DISCOVERY
├── Module template? → DISCOVERY
└── Investigating bug? → DISCOVERY
```

---

## 7. ASSERTION PATTERNS

### Common Assertions for Auth Testing

```r
# Value assertions
expect_equal(result$user_id, 1)
expect_true(result$is_authenticated)
expect_false(result$is_master)
expect_null(result$session_token)
expect_true(!is.null(result$session_token))

# Type assertions
expect_type(user_id, "integer")
expect_type(username, "character")
expect_type(is_master, "logical")

# Class assertions
expect_s3_class(db_result, "data.frame")
expect_s3_class(ui, "shiny.tag")
expect_s3_class(ui, "shiny.tag.list")

# String matching
expect_match(error_message, "Invalid credentials", ignore.case = TRUE)
expect_true(grepl("password", error_msg, ignore.case = TRUE))

# Database assertions
row <- DBI::dbGetQuery(db, "SELECT * FROM users WHERE user_id = ?")
expect_equal(nrow(row), 1)
expect_equal(row$username, "testuser")
expect_true(row$is_master)

# Error assertions
expect_error(my_function(NULL), "NULL|required")
expect_error(my_function(""), "empty|blank")

# List/Vector assertions
expect_true("field" %in% names(result))
expect_equal(length(result$errors), 2)
```

### Real Examples from Codebase

```r
# From test-ebay_helpers.R
test_that("map_condition_to_ebay maps standard conditions correctly", {
  expect_equal(map_condition_to_ebay("Mint"), "NEW")
  expect_equal(map_condition_to_ebay("Excellent"), "LIKE_NEW")
  expect_equal(map_condition_to_ebay("Very Good"), "VERY_GOOD")
})

# From test-tracking_database.R
test_that("calculate_image_hash returns consistent SHA-256 hash", {
  test_img <- test_path("fixtures/test_face.jpg")
  hash1 <- calculate_image_hash(test_img)
  hash2 <- calculate_image_hash(test_img)
  
  expect_type(hash1, "character")
  expect_equal(nchar(hash1), 64)  # SHA-256 = 64 hex chars
  expect_equal(hash1, hash2)      # Deterministic
})
```

---

## 8. COMPLETE EXAMPLE TEST FILE

### For Reference: Structure of a Complete Test File

```r
# Tests for auth_system.R
# Covers user authentication, session management, password validation

# ==== INITIALIZATION TESTS ====

test_that("initialize_auth_db creates all required tables", {
  db <- create_test_db()
  
  tables <- DBI::dbListTables(db)
  
  expect_true("users" %in% tables)
  expect_true("sessions" %in% tables)
  expect_true("login_attempts" %in% tables)
  
  cleanup_test_db(db)
})

# ==== USER CREATION TESTS ====

test_that("create_user creates new user with hashed password", {
  with_test_db({
    result <- create_user(db, "alice", "password123", is_master = FALSE)
    
    expect_true(result$success)
    expect_type(result$user_id, "integer")
    
    # Verify in database
    user <- DBI::dbGetQuery(db,
      "SELECT * FROM users WHERE user_id = ?",
      params = list(result$user_id)
    )
    expect_equal(user$username, "alice")
    expect_false(user$is_master)
    # Password should be hashed, not plaintext
    expect_false(user$password_hash == "password123")
  })
})

test_that("create_user rejects duplicate username", {
  with_test_db({
    create_user(db, "alice", "pass1", FALSE)
    result <- create_user(db, "alice", "pass2", FALSE)
    
    expect_false(result$success)
    expect_true(grepl("already exists|duplicate", result$error, ignore.case = TRUE))
  })
})

# ==== AUTHENTICATION TESTS ====

test_that("authenticate_user succeeds with correct password", {
  with_test_db({
    create_user(db, "alice", "correctpass", FALSE)
    result <- authenticate_user(db, "alice", "correctpass")
    
    expect_true(result$success)
    expect_equal(result$user_id, 1)
  })
})

test_that("authenticate_user fails with wrong password", {
  with_test_db({
    create_user(db, "alice", "correctpass", FALSE)
    result <- authenticate_user(db, "alice", "wrongpass")
    
    expect_false(result$success)
    expect_true(grepl("Invalid credentials", result$error))
  })
})

test_that("authenticate_user fails with nonexistent user", {
  with_test_db({
    result <- authenticate_user(db, "nonexistent", "anypass")
    
    expect_false(result$success)
  })
})

# ==== SESSION MANAGEMENT TESTS ====

test_that("create_session returns valid session token", {
  with_test_db({
    user_id <- create_test_user(db, "alice", "pass")
    result <- create_session(db, user_id)
    
    expect_true(result$success)
    expect_type(result$session_token, "character")
    expect_true(nchar(result$session_token) > 0)
  })
})

test_that("verify_session succeeds with valid token", {
  with_test_db({
    user_id <- create_test_user(db, "alice", "pass")
    session <- create_session(db, user_id)
    
    result <- verify_session(db, session$session_token)
    
    expect_true(result$valid)
    expect_equal(result$user_id, user_id)
  })
})

# ==== MASTER USER TESTS ====

test_that("create_master_user sets is_master flag", {
  with_test_db({
    result <- create_user(db, "master1", "pass", is_master = TRUE)
    
    user <- DBI::dbGetQuery(db,
      "SELECT is_master FROM users WHERE user_id = ?",
      params = list(result$user_id)
    )
    expect_true(as.logical(user$is_master))
  })
})

test_that("master users cannot delete each other", {
  with_test_db({
    master1_id <- create_user(db, "master1", "pass", TRUE)$user_id
    master2_id <- create_user(db, "master2", "pass", TRUE)$user_id
    
    # master1 tries to delete master2
    result <- delete_user(db, master1_id, master2_id)
    
    expect_false(result$success)
    expect_true(grepl("Cannot delete|master user", result$error, ignore.case = TRUE))
  })
})

# ==== PASSWORD VALIDATION TESTS ====

test_that("validate_password rejects empty password", {
  result <- validate_password("")
  
  expect_false(result$valid)
  expect_true(grepl("empty|blank", result$error, ignore.case = TRUE))
})

test_that("validate_password rejects short password", {
  result <- validate_password("short")
  
  expect_false(result$valid)
  expect_true(grepl("too short|minimum", result$error, ignore.case = TRUE))
})

# ==== ERROR HANDLING TESTS ====

test_that("authenticate_user handles NULL username", {
  with_test_db({
    result <- authenticate_user(db, NULL, "password")
    
    expect_false(result$success)
  })
})

test_that("authenticate_user handles NULL password", {
  with_test_db({
    result <- authenticate_user(db, "alice", NULL)
    
    expect_false(result$success)
  })
})
```

---

## 9. TEST DATA SETUP PATTERNS

### Pattern: User Setup

```r
# Single user
user_id <- create_test_user(db, "alice", "password123", FALSE)

# Multiple users
user1_id <- create_test_user(db, "alice", "pass1", FALSE)
user2_id <- create_test_user(db, "bob", "pass2", FALSE)
admin_id <- create_test_user(db, "admin", "admin_pass", TRUE)  # Master user

# Using fixtures
user_data <- generate_test_user(username = "charlie", password = "pass")
```

### Pattern: Session Setup

```r
# Single session
user_id <- create_test_user(db, "alice", "pass")
session_id <- create_test_session(db, user_id = user_id)

# Multiple sessions
session1_id <- create_test_session(db, user_id = 1)
session2_id <- create_test_session(db, user_id = 2)
```

### Pattern: Card with Processing

```r
# Simple card
card <- get_or_create_card(db, "test_hash_123")

# Card with processing
card <- get_or_create_card(db, "test_hash_456")
session_id <- create_test_session(db, user_id = 1)
save_card_processing(db, card$card_id, session_id, 
                     "path/face.jpg", "path/verso.jpg")
```

### Pattern: Complex Setup

```r
with_test_db({
  # Create users
  alice_id <- create_test_user(db, "alice", "pass", FALSE)
  admin_id <- create_test_user(db, "admin", "adminpass", TRUE)
  
  # Create sessions
  alice_session <- create_test_session(db, user_id = alice_id)
  
  # Create cards
  card1 <- get_or_create_card(db, "hash1")
  card2 <- get_or_create_card(db, "hash2")
  
  # Process cards
  save_card_processing(db, card1$card_id, alice_session, 
                       "face1.jpg", "verso1.jpg")
  
  # Now run test
  result <- my_function(db, alice_id, alice_session)
  expect_true(result$success)
})
```

---

## 10. RUNNING TESTS

### Quick Commands

```r
# Run critical tests (before commit)
source("dev/run_critical_tests.R")

# Run discovery tests (during development)
source("dev/run_discovery_tests.R")

# Run all tests
source("dev/run_tests.R")

# Run single file
testthat::test_file("tests/testthat/test-auth_system.R")

# Run with coverage
devtools::load_all()
coverage <- covr::package_coverage()
covr::report(coverage)
```

### Daily Workflow

```r
# 1. Load package
devtools::load_all()

# 2. Run critical tests
source("dev/run_critical_tests.R")

# 3. Write code...

# 4. Before committing
source("dev/run_critical_tests.R")  # Must pass!

# 5. If exploring
source("dev/run_discovery_tests.R")
```

### Expected Results

**Critical tests:**
```
✓ Passed:  ~170
✗ Failed:  0
⊘ Skipped: 0
Time:      10-20 seconds
```

**Discovery tests:**
```
✓ Passed:  ~24
✗ Failed:  ~26 (learning opportunities)
⊘ Skipped: ~92 (templates)
Time:      30-60 seconds
```

---

## SUMMARY: COPY-PASTE READY PATTERNS

### 1. Database Test Pattern
```r
test_that("description", {
  with_test_db({
    # Setup
    user_id <- create_test_user(db, "user", "pass", FALSE)
    
    # Act
    result <- my_function(db, user_id)
    
    # Assert
    expect_true(result$success)
  })
})
```

### 2. Module Test Pattern
```r
test_that("description", {
  testServer(mod_name_server, args = list(db = db), {
    session$setInputs(field = "value", button = 1)
    session$flushReact()
    expect_true(rv$reactive_value)
  })
})
```

### 3. Mock API Pattern
```r
test_that("description", {
  with_mocked_ai({
    result <- my_api_function()
    expect_true(result$success)
  }, provider = "claude", success = TRUE)
})
```

### 4. Error Handling Pattern
```r
test_that("description", {
  with_test_db({
    expect_error(
      my_function(db, NULL),
      "error message|pattern"
    )
  })
})
```

---

## KEY FILES REFERENCE

| File | Purpose | Size |
|------|---------|------|
| `tests/testthat/helper-setup.R` | Database utilities | 126 lines |
| `tests/testthat/helper-mocks.R` | API mocking | 204 lines |
| `tests/testthat/helper-fixtures.R` | Test data generators | 237 lines |
| `tests/testthat/test-ebay_helpers.R` | eBay tests (CRITICAL) | ~150 lines |
| `tests/testthat/test-tracking_database.R` | Database tests | ~300 lines |
| `tests/testthat/test-mod_login.R` | Login module template | ~250 lines |
| `tests/testthat/test-mod_delcampe_export.R` | Export module (CRITICAL) | ~350 lines |
| `dev/run_critical_tests.R` | Critical test runner | 127 lines |
| `dev/run_discovery_tests.R` | Discovery test runner | 191 lines |

---

## IMPLEMENTATION CHECKLIST FOR AUTH SYSTEM TESTS

When creating `tests/testthat/test-auth_system.R`:

- [ ] Database initialization tests (all tables created)
- [ ] User creation tests (success and errors)
- [ ] Authentication tests (correct/wrong password, nonexistent user)
- [ ] Session management tests (create, verify, invalidate)
- [ ] Master user tests (cannot delete each other)
- [ ] Password validation tests (empty, short, format)
- [ ] Error handling tests (NULL inputs, invalid types)
- [ ] Integration tests (user → session → card flow)
- [ ] Edge case tests (special characters, unicode, etc.)
- [ ] Add stable tests to `dev/run_critical_tests.R`

---

**Last Updated**: 2025-11-03
**Status**: Ready for use ✅
