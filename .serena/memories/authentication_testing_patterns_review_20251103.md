# Testing Infrastructure Review for Authentication System

**Date**: 2025-11-03
**Purpose**: Understanding patterns for writing comprehensive auth system tests
**Status**: Complete analysis with detailed patterns and examples

---

## Executive Summary

The Delcampe testing infrastructure is mature and production-ready with:
- **Two-tier test strategy**: Critical (always pass) + Discovery (learning)
- **Comprehensive helper system**: Database, mocking, fixtures
- **Clear patterns** for different testing scenarios
- **170+ passing critical tests** providing foundation
- **Module testing templates** showing best practices

For authentication testing, follow these proven patterns from existing test suite.

---

## 1. HELPER FILES - The Foundation

All helper files are **auto-loaded** by testthat before tests run.

### 1.1 Database Testing Helpers (`helper-setup.R`)

**Pattern: Use `with_test_db()` for database testing**

```r
test_that("auth function creates user", {
  with_test_db({
    # db is automatically available
    user_id <- create_test_user(db, "authtest", "pass123", FALSE)
    
    # Now test your auth logic
    expect_true(user_id > 0)
  })
  # Database automatically cleaned up after test
})
```

**Key helper functions:**

```r
# 1. Create in-memory test database
db <- create_test_db()

# 2. Execute code with automatic cleanup (RECOMMENDED)
with_test_db({
  # db is available here
  # Cleanup happens automatically on exit
})

# 3. Clean up manually if needed
cleanup_test_db(db)

# 4. Create test users
user_id <- create_test_user(db, "username", "password", is_master = FALSE)

# 5. Create test sessions
session_id <- create_test_session(db, user_id = 1)
```

**Best Practice**: Always use `with_test_db()` wrapper - don't manage cleanup manually.

### 1.2 Mocking Helpers (`helper-mocks.R`)

**Pattern: Use `with_mocked_ai()` and `with_mocked_ebay()` to avoid real API calls**

```r
test_that("auth system handles API calls", {
  with_mocked_ai({
    # httr2::req_perform is mocked
    # Your function calls API but gets mock response
    result <- call_my_function()
    expect_true(result$success)
  }, provider = "claude", success = TRUE)
})
```

**Available mocking functions:**

```r
# 1. Mock Claude API responses
response <- mock_claude_response(success = TRUE, extraction_data = NULL)
# Returns: list(success=TRUE, data=list(...), model="...", tokens_used=...)

# 2. Mock OpenAI API responses
response <- mock_openai_response(success = TRUE, extraction_data = NULL)
# Returns: list(success=TRUE, data=list(...), model="gpt-4o", tokens_used=...)

# 3. Mock eBay OAuth responses
response <- mock_ebay_oauth(success = TRUE)
# Returns: list(access_token="v^1.1#...", token_type="...", expires_in=7200)

# 4. Execute code with mocked AI
with_mocked_ai({
  # your code here - httr2::req_perform is mocked
}, provider = "claude", success = TRUE)

# 5. Execute code with mocked eBay
with_mocked_ebay({
  # your code here - eBay API calls are mocked
}, success = TRUE)

# 6. Mock file uploads
file_mock <- mock_file_upload("/path/to/file.jpg", "custom_name.jpg")
# Returns: list(name="...", size=..., type="...", datapath="...")
```

### 1.3 Fixture Generators (`helper-fixtures.R`)

**Pattern: Use `generate_test_*()` for consistent test data**

```r
test_that("auth validates user data", {
  # Generate realistic test data
  user <- generate_test_user(username = "testauth", password = "pass123", is_master = FALSE)
  
  expect_equal(user$username, "testauth")
  expect_type(user$password_hash, "character")
  expect_false(user$is_master)
})
```

**Available fixture generators:**

```r
# 1. Generate test postcard data
card <- generate_test_card(id = 1, title = NULL, description = NULL)

# 2. Generate test user data
user <- generate_test_user(username = "testuser", password = "testpass", is_master = FALSE)

# 3. Generate AI extraction results
extraction <- sample_ai_extraction(side = "face", quality = "high")

# 4. Generate processing session
session <- generate_test_session(session_id = 1, user_id = 1, num_cards = 5)

# 5. Generate crop boundaries
crops <- generate_test_crops(num_crops = 6)

# 6. Generate eBay listing
listing <- generate_test_ebay_listing(listing_id = 1)

# 7. Generate Delcampe export
export <- generate_test_delcampe_export(export_id = 1)
```

---

## 2. TEST FILE PATTERNS

### 2.1 Standard Test Structure

All tests follow this structure in separate files:

```r
# test-component_name.R

# ==== SECTION 1: SETUP TESTS ====

test_that("component initializes correctly", {
  # Simple initialization test
})

# ==== SECTION 2: CORE FUNCTIONALITY TESTS ====

test_that("component does its primary job", {
  # Arrange
  input_data <- setup_test_data()
  
  # Act
  result <- my_function(input_data)
  
  # Assert
  expect_true(result$success)
})

# ==== SECTION 3: ERROR HANDLING TESTS ====

test_that("component handles errors gracefully", {
  expect_error(my_function(invalid_input))
})

# ==== SECTION 4: EDGE CASE TESTS ====

test_that("component handles edge cases", {
  # Test boundary conditions
})
```

### 2.2 Database Testing Pattern

From `test-tracking_database.R`:

```r
test_that("get_or_create_card creates new card", {
  with_test_db({
    # Arrange
    result <- get_or_create_card(db, "test_hash_123")
    
    # Assert
    expect_type(result$card_id, "integer")
    expect_equal(result$image_hash, "test_hash_123")
    expect_true(result$is_new)
  })
})

test_that("get_or_create_card finds existing card", {
  with_test_db({
    # Arrange
    first <- get_or_create_card(db, "test_hash_456")
    second <- get_or_create_card(db, "test_hash_456")
    
    # Assert
    expect_equal(first$card_id, second$card_id)
    expect_true(first$is_new)
    expect_false(second$is_new)
  })
})
```

**Key points:**
- Use `with_test_db()` - automatic cleanup
- Database `db` is automatically injected
- Test both success and existing record paths

### 2.3 Module Testing Pattern

From `test-mod_login.R`:

```r
test_that("mod_login_ui generates valid UI", {
  ui <- mod_login_ui("test")
  
  # Check structure
  expect_s3_class(ui, "shiny.tag")
  
  # Check content
  ui_html <- as.character(ui)
  expect_true(grepl("login", ui_html, ignore.case = TRUE))
})

test_that("mod_login_server handles authentication", {
  skip("Requires auth_system mocking")
  
  with_test_db({
    # Setup
    user_id <- create_test_user(db, "testuser", "testpass", FALSE)
    vals <- reactiveValues(login = FALSE)
    
    # Test
    testServer(mod_login_server, args = list(vals = vals), {
      # Simulate user input
      session$setInputs(
        userName = "testuser",
        passwd = "testpass",
        login = 1
      )
      
      # Wait for reactive processing
      session$flushReact()
      
      # Assert
      expect_true(vals$login)
      expect_equal(vals$user_name, "testuser@example.com")
    })
  })
})
```

**Key patterns:**
- Use `testServer()` for module server logic
- Use `session$setInputs()` to simulate user input
- Use `session$flushReact()` to process reactives
- Use `skip()` for tests not yet implemented
- Use `with_test_db()` for database-dependent tests

### 2.4 Assertion Patterns

From `test-utils_helpers.R` and `test-ebay_helpers.R`:

```r
# Type checking
expect_type(x, "character")
expect_type(x, "logical")
expect_type(x, "integer")
expect_type(x, "numeric")

# Equality
expect_equal(x, expected_value)
expect_true(condition)
expect_false(condition)

# Errors and warnings
expect_error(expression, pattern = "error message")
expect_warning(expression)

# Existence
expect_null(x)
expect_true(!is.null(x))

# Special Shiny checks
expect_s3_class(ui, "shiny.tag")
expect_s3_class(ui, "shiny.tag.list")

# Range checking
expect_true(result > 0)
expect_true(result %in% c("option1", "option2"))
```

### 2.5 Error Handling Pattern

```r
test_that("function handles errors gracefully", {
  result <- tryCatch(
    risky_function(bad_input),
    error = function(e) NULL
  )
  
  expect_true(is.null(result) || !inherits(result, "error"))
})
```

---

## 3. CRITICAL vs DISCOVERY TEST STRATEGY

### 3.1 What Makes a Test "Critical"

A test is critical if it:
- ✅ Tests core business logic (authentication, data validation)
- ✅ Always passes (100% reliable)
- ✅ Fast execution (<1 second)
- ✅ No external dependencies
- ✅ Critical path for users

**Currently critical:**
- `test-ebay_helpers.R` - eBay business logic
- `test-ebay_time_helpers.R` - Time handling
- `test-utils_helpers.R` - Utility functions
- `test-mod_delcampe_export.R` - Delcampe export
- `test-mod_tracking_viewer.R` - Tracking viewer

### 3.2 What Makes a Test "Discovery"

A test is discovery if it:
- 🔍 Explores behavior edge cases
- 🔍 Tests experimental features
- 🔍 Helps understand code
- 🔍 Failures reveal opportunities
- 🔍 Uses mocking or templates

**Currently discovery:**
- `test-ai_api_helpers.R` - AI integration (exploratory)
- `test-tracking_database.R` - Database edge cases
- `test-mod_login.R` - Authentication template
- `test-mod_settings_llm.R` - Settings template

### 3.3 Running Tests

```r
# Run only critical tests (do this before committing)
source("dev/run_critical_tests.R")

# Run discovery tests (when exploring)
source("dev/run_discovery_tests.R")

# Run everything
source("dev/run_tests.R")

# Run one file
devtools::load_all()
testthat::test_file("tests/testthat/test-component.R")
```

---

## 4. AUTHENTICATION TEST PATTERNS

### 4.1 User Creation/Retrieval Testing

For auth system, follow this pattern:

```r
test_that("create_user adds new user to database", {
  with_test_db({
    # Create user
    user_id <- create_test_user(db, "authuser", "pass123", is_master = FALSE)
    
    # Verify in database
    user <- DBI::dbGetQuery(db, 
      "SELECT * FROM users WHERE user_id = ?",
      params = list(user_id)
    )
    
    expect_equal(user$username, "authuser")
    expect_true(is_master == FALSE)
    expect_type(user$password_hash, "character")
  })
})

test_that("get_user retrieves existing user", {
  with_test_db({
    # Setup
    user_id <- create_test_user(db, "retrieve", "pass", FALSE)
    
    # Get user
    user <- get_user(db, user_id)
    
    # Assert
    expect_equal(user$user_id, user_id)
    expect_equal(user$username, "retrieve")
  })
})
```

### 4.2 Password Validation Testing

```r
test_that("validate_password checks hashed password correctly", {
  with_test_db({
    # Create user with password
    user_id <- create_test_user(db, "pwdtest", "correct_password", FALSE)
    
    # Valid password should succeed
    result <- validate_password(db, user_id, "correct_password")
    expect_true(result$success)
    
    # Invalid password should fail
    result <- validate_password(db, user_id, "wrong_password")
    expect_false(result$success)
  })
})

test_that("validate_password handles nonexistent user", {
  with_test_db({
    result <- validate_password(db, 99999, "anypassword")
    expect_false(result$success)
    expect_type(result$error, "character")
  })
})
```

### 4.3 Session Management Testing

```r
test_that("create_session establishes new session", {
  with_test_db({
    # Create user
    user_id <- create_test_user(db, "sestest", "pass", FALSE)
    
    # Create session
    session_id <- create_test_session(db, user_id = user_id)
    
    # Verify session exists
    session <- DBI::dbGetQuery(db,
      "SELECT * FROM processing_sessions WHERE session_id = ?",
      params = list(session_id)
    )
    
    expect_equal(session$user_id, user_id)
    expect_type(session$session_start, "character")
  })
})

test_that("session links to correct user", {
  with_test_db({
    # Create two users
    user1 <- create_test_user(db, "user1", "pass1", FALSE)
    user2 <- create_test_user(db, "user2", "pass2", FALSE)
    
    # Create sessions
    session1 <- create_test_session(db, user_id = user1)
    session2 <- create_test_session(db, user_id = user2)
    
    # Verify linkage
    s1 <- DBI::dbGetQuery(db,
      "SELECT user_id FROM processing_sessions WHERE session_id = ?",
      params = list(session1)
    )
    
    expect_equal(s1$user_id, user1)
  })
})
```

### 4.4 Master User Protection Testing

```r
test_that("cannot delete master user", {
  with_test_db({
    # Create master user
    master_id <- create_test_user(db, "master", "pass", is_master = TRUE)
    
    # Attempt to delete should fail
    result <- delete_user(db, master_id)
    
    expect_false(result$success)
    expect_true(grepl("master user", result$error, ignore.case = TRUE))
    
    # Master user should still exist
    user <- DBI::dbGetQuery(db,
      "SELECT COUNT(*) as count FROM users WHERE user_id = ?",
      params = list(master_id)
    )
    expect_equal(user$count, 1)
  })
})

test_that("master can manage own credentials", {
  skip("Requires session context")
  
  with_test_db({
    master_id <- create_test_user(db, "master", "oldpass", is_master = TRUE)
    
    # Master changes own password
    result <- change_password(db, master_id, "oldpass", "newpass")
    
    expect_true(result$success)
    
    # New password should work
    auth_result <- validate_password(db, master_id, "newpass")
    expect_true(auth_result$success)
  })
})
```

### 4.5 User Permission Testing

```r
test_that("non-master user has limited permissions", {
  with_test_db({
    # Create regular user
    regular_id <- create_test_user(db, "regular", "pass", is_master = FALSE)
    
    # Cannot delete other users
    other_id <- create_test_user(db, "other", "pass", FALSE)
    
    result <- delete_user_as(db, regular_id, other_id)
    expect_false(result$success)
    expect_true(grepl("permission", result$error, ignore.case = TRUE))
  })
})

test_that("master user can manage created users", {
  with_test_db({
    # Create master user
    master_id <- create_test_user(db, "master", "pass", is_master = TRUE)
    
    # Master creates regular user
    created_id <- create_user_as(db, master_id, "created", "pass", FALSE)
    expect_true(created_id > 0)
    
    # Master can modify created user
    result <- modify_user_as(db, master_id, created_id, list(username = "newname"))
    expect_true(result$success)
  })
})
```

### 4.6 Shiny Module Testing (Authentication UI)

```r
test_that("mod_login_ui renders login form", {
  ui <- mod_login_ui("test")
  
  # Check it's a tag
  expect_s3_class(ui, "shiny.tag")
  
  # Check content
  html <- as.character(ui)
  expect_true(grepl("username|user", html, ignore.case = TRUE))
  expect_true(grepl("password|passwd", html, ignore.case = TRUE))
})

test_that("mod_login_server validates credentials", {
  testServer(mod_login_server, {
    # Setup: Create test user
    with_test_db({
      create_test_user(db, "testuser", "testpass", FALSE)
      
      # Simulate login attempt
      session$setInputs(userName = "testuser", passwd = "testpass", login = 1)
      session$flushReact()
      
      # Verify login successful
      expect_true(output$login_success)
    })
  })
})
```

---

## 5. RUNNING AUTH TESTS

### 5.1 Before Adding Auth Test Suite

```r
# 1. Load the package
devtools::load_all()

# 2. Run critical tests to ensure baseline
source("dev/run_critical_tests.R")

# 3. Should see all pass - confirms infrastructure working
```

### 5.2 Creating New Auth Test File

```r
# Create: tests/testthat/test-auth_helpers.R

# Tests for authentication system
# Covers user management, password handling, sessions, permissions

# Load helpers (automatic)
# - with_test_db() for database
# - create_test_user() for test data
# - testServer() for Shiny modules

# ==== USER CREATION TESTS ====

test_that("create_user adds user to database", {
  with_test_db({
    # Test code here
  })
})

# ==== PASSWORD VALIDATION TESTS ====

test_that("validate_password checks credentials", {
  with_test_db({
    # Test code here
  })
})

# ==== SESSION MANAGEMENT TESTS ====

test_that("session links to user", {
  with_test_db({
    # Test code here
  })
})

# ==== MASTER USER PROTECTION TESTS ====

test_that("master user cannot be deleted", {
  with_test_db({
    # Test code here
  })
})
```

### 5.3 Running Your Auth Tests

```r
# Run just your auth tests
devtools::load_all()
testthat::test_file("tests/testthat/test-auth_helpers.R")

# Run with discovery tests if complex
source("dev/run_discovery_tests.R")

# Once stable, add to critical tests
# Edit: dev/run_critical_tests.R
critical_tests <- c(
  "test-ebay_helpers.R",
  "test-utils_helpers.R",
  "test-auth_helpers.R",  # Add here when ready
  "test-mod_delcampe_export.R",
  "test-mod_tracking_viewer.R"
)
```

---

## 6. ASSERTION PATTERNS FOR AUTH TESTS

```r
# User creation
expect_type(user_id, "integer")
expect_true(user_id > 0)

# User data
expect_equal(user$username, "expected")
expect_type(user$password_hash, "character")
expect_equal(nchar(user$password_hash), 64)  # SHA-256

# Boolean fields
expect_true(user$is_master)
expect_false(user$is_master)

# Success/failure
expect_true(result$success)
expect_false(result$success)
expect_type(result$error, "character")

# Database state
user_count <- DBI::dbGetQuery(db, "SELECT COUNT(*) as n FROM users")
expect_equal(user_count$n, expected_count)

# Timestamps
expect_type(user$created_at, "character")
expect_true(nzchar(user$created_at))  # Non-empty string
```

---

## 7. COMMON MISTAKES TO AVOID

### 7.1 Database Cleanup

**WRONG:**
```r
test_that("my test", {
  db <- create_test_db()
  # ... test code ...
  # Forgot to cleanup - database leaks
})
```

**RIGHT:**
```r
test_that("my test", {
  with_test_db({
    # ... test code ...
    # Automatic cleanup
  })
})
```

### 7.2 Not Loading Package

**WRONG:**
```r
# Running test without loading package first
testthat::test_file("tests/testthat/test-auth.R")
# Error: "could not find function"
```

**RIGHT:**
```r
devtools::load_all()
testthat::test_file("tests/testthat/test-auth.R")
# Works!
```

### 7.3 API Calls Without Mocking

**WRONG:**
```r
test_that("auth with API", {
  result <- call_real_api()  # Makes actual API call!
})
```

**RIGHT:**
```r
test_that("auth with API", {
  with_mocked_ai({
    result <- call_api()  # Uses mock instead
  })
})
```

### 7.4 Not Using Helper Functions

**WRONG:**
```r
test_that("test auth", {
  db <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  DBI::dbExecute(db, "CREATE TABLE users ...")
  # ... 50 lines of setup ...
})
```

**RIGHT:**
```r
test_that("test auth", {
  with_test_db({
    create_test_user(db, "testuser", "pass", FALSE)
    # Much cleaner!
  })
})
```

---

## 8. FILE LOCATIONS AND STRUCTURE

```
tests/
├── testthat/
│   ├── helper-setup.R              ← Database helpers
│   ├── helper-mocks.R              ← API mocking
│   ├── helper-fixtures.R           ← Test data
│   ├── test-auth_helpers.R         ← Your auth tests (create this)
│   ├── test-mod_login.R            ← Login module tests
│   ├── test-ebay_helpers.R         ← eBay tests (model)
│   ├── test-utils_helpers.R        ← Utils tests (model)
│   └── test-tracking_database.R    ← Database tests (model)
└── fixtures/
    ├── test_face.jpg
    └── test_verso.jpg

dev/
├── run_critical_tests.R            ← Edit to add auth tests here
├── run_discovery_tests.R
├── TESTING_CHEATSHEET.md
└── TESTING_STRATEGY.md
```

---

## 9. QUICK REFERENCE

### Essential Commands

```r
# Load package (ALWAYS first!)
devtools::load_all()

# Run all critical tests
source("dev/run_critical_tests.R")

# Run discovery tests
source("dev/run_discovery_tests.R")

# Run one test file
testthat::test_file("tests/testthat/test-auth_helpers.R")

# Run one test
testthat::test_file("tests/testthat/test-auth_helpers.R", filter = "user creation")
```

### Essential Helpers

```r
# Database
with_test_db({ /* code */ })
create_test_user(db, "user", "pass", is_master)
create_test_session(db, user_id)

# Mocking
with_mocked_ai({ /* code */ }, provider = "claude", success = TRUE)
with_mocked_ebay({ /* code */ }, success = TRUE)

# Module testing
testServer(mod_server, args = list(...), { /* assertions */ })
```

### Test Structure Template

```r
# tests/testthat/test-auth_helpers.R

# ==== SECTION NAME TESTS ====

test_that("description of what you're testing", {
  with_test_db({
    # Arrange
    setup_data <- create_test_user(db, "user", "pass", FALSE)
    
    # Act
    result <- function_being_tested(db, setup_data)
    
    # Assert
    expect_true(result$success)
  })
})
```

---

## 10. KEY TAKEAWAYS

1. **Always use `with_test_db()`** - automatic cleanup, cleaner code
2. **Always load package first** - `devtools::load_all()` before any tests
3. **Use helpers extensively** - reduces boilerplate, improves maintainability
4. **Two test suites work well** - critical for confidence, discovery for learning
5. **Module tests use `testServer()`** - proper Shiny testing pattern
6. **Mock external APIs** - use `with_mocked_*()` functions
7. **One assertion per test when possible** - clearer, easier to debug
8. **Skip incomplete tests** - `skip("reason")` better than failing
9. **Add auth tests to discovery first** - move to critical when stable
10. **Reference existing tests** - patterns in `test-ebay_helpers.R`, `test-tracking_database.R`

---

## References

- **Memory**: `testing_infrastructure_complete_20251023`
- **Testing Cheatsheet**: `dev/TESTING_CHEATSHEET.md`
- **Testing Strategy**: `dev/TESTING_STRATEGY.md`
- **Testing Guide**: `dev/TESTING_GUIDE.md`
- **Critical Test Runner**: `dev/run_critical_tests.R`
- **Discovery Test Runner**: `dev/run_discovery_tests.R`

---

## Next Steps for Authentication Testing

1. Create `tests/testthat/test-auth_helpers.R`
2. Follow patterns from this review
3. Use helper functions (`with_test_db`, etc.)
4. Organize by section (user creation, validation, permissions, etc.)
5. Use both positive and negative test cases
6. Start in discovery suite, move to critical when stable
7. Run `source("dev/run_critical_tests.R")` before committing
8. Reference this memory when writing tests

