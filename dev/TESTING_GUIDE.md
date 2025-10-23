# Testing Guide for Delcampe

Quick reference for running tests and working with the test suite.

## Quick Start

### Run All Tests

```r
# From R console
devtools::test()

# Or
testthat::test_dir("tests/testthat")

# Or use the helper script
source("dev/run_tests.R")
```

### Run Specific Test File

```r
testthat::test_file("tests/testthat/test-tracking_database.R")
testthat::test_file("tests/testthat/test-ai_api_helpers.R")
```

### Generate Coverage Report

```r
# Simple coverage
covr::package_coverage()

# Detailed HTML report
coverage <- covr::package_coverage()
covr::report(coverage)

# Or use the helper script which does both
source("dev/run_tests.R")
```

## Test Structure

```
tests/
├── testthat.R              # Test runner entry point
├── testthat/
│   ├── helper-setup.R      # Database test utilities
│   ├── helper-mocks.R      # API mocking utilities
│   ├── helper-fixtures.R   # Test data generators
│   ├── test-tracking_database.R    # Database tests (42 tests)
│   ├── test-ai_api_helpers.R       # AI API tests (40 tests)
│   ├── test-utils_helpers.R        # Utility tests (30 tests)
│   ├── test-ebay_helpers.R         # eBay helper tests (30 tests)
│   ├── test-mod_login.R            # Login module tests (template)
│   └── test-mod_settings_llm.R     # Settings module tests (template)
└── fixtures/
    ├── test_face.jpg       # Test postcard image (face)
    ├── test_verso.jpg      # Test postcard image (verso)
    └── mock_api_responses/ # Mock API JSON responses
```

## Helper Functions Reference

### Database Helpers (`helper-setup.R`)

```r
# Create test database
db <- create_test_db()

# Clean up
cleanup_test_db(db)

# Use with automatic cleanup
with_test_db({
  # db is available here
  card <- get_or_create_card(db, "test_hash")
})

# Create test users
user_id <- create_test_user(db, "username", "password", is_master = FALSE)

# Create test sessions
session_id <- create_test_session(db, user_id)
```

### Mock Helpers (`helper-mocks.R`)

```r
# Mock AI responses
response <- mock_claude_response(success = TRUE)
response <- mock_openai_response(success = TRUE)

# Use in tests
with_mocked_ai({
  result <- call_claude_api(test_image, "prompt")
  expect_true(result$success)
}, provider = "claude")

# Mock eBay OAuth
token <- mock_ebay_oauth(success = TRUE)
```

### Fixture Helpers (`helper-fixtures.R`)

```r
# Generate test data
card <- generate_test_card(id = 1)
user <- generate_test_user(username = "alice")
extraction <- sample_ai_extraction(side = "face", quality = "high")
session <- generate_test_session(session_id = 1)
crops <- generate_test_crops(num_crops = 6)
listing <- generate_test_ebay_listing(listing_id = 1)
```

## Writing New Tests

### 1. Unit Tests for Functions

```r
# tests/testthat/test-my_module.R

test_that("my_function does something", {
  # Arrange
  input <- "test"

  # Act
  result <- my_function(input)

  # Assert
  expect_equal(result, "expected")
})
```

### 2. Database Tests

```r
test_that("database function works", {
  with_test_db({
    # Arrange
    card <- get_or_create_card(db, "hash_123")

    # Act
    result <- save_card_processing(db, card$card_id, 1, "face.jpg", "verso.jpg")

    # Assert
    expect_true(result$success)

    # Verify in database
    row <- DBI::dbGetQuery(db,
      "SELECT * FROM card_processing WHERE card_id = ?",
      params = list(card$card_id)
    )
    expect_equal(nrow(row), 1)
  })
})
```

### 3. Shiny Module Tests

```r
test_that("module server works", {
  testServer(mod_example_server, args = list(db = db), {
    # Set inputs
    session$setInputs(
      input_field = "test",
      action_btn = 1
    )

    # Flush reactives
    session$flushReact()

    # Assert
    expect_true(some_reactive())
    expect_true(!is.null(output$result))
  })
})
```

## Test Templates

- **`test-mod_login.R`** - Comprehensive module test with authentication, security, edge cases
- **`test-mod_settings_llm.R`** - Simpler module test with configuration and validation

Use these as templates when creating new module tests.

## CI/CD Integration

Tests run automatically on:
- Push to `main`, `master`, or `develop` branches
- Pull requests to `main` or `master`
- Manual workflow trigger

### Workflow Configuration

See `.github/workflows/test.yaml` for:
- R environment setup
- Python dependencies for reticulate
- Test execution
- Coverage reporting
- Multiple R version testing (on PRs)

## Coverage Goals

- **Target**: 70% overall coverage
- **Priority**: Core business logic (database, AI extraction, eBay posting)
- **Secondary**: Module server logic
- **Lower priority**: UI generation functions

## Common Issues

### Tests fail with "package not found"

```r
# Install missing test dependencies
install.packages(c("testthat", "mockery", "withr", "covr"))
```

### Database tests fail

```r
# Ensure DBI and RSQLite are installed
install.packages(c("DBI", "RSQLite"))

# Check that initialize_tracking_db() is accessible
devtools::load_all()
```

### Python integration tests fail

```bash
# Install Python dependencies
pip install opencv-python numpy
```

### Mocked tests are skipped

This is expected! Tests with `skip()` are templates that need:
1. Remove the `skip()` call
2. Uncomment the test code
3. Set up required mocking infrastructure
4. Implement assertions based on actual behavior

## Best Practices

1. **One assertion per test** (when possible)
2. **Use descriptive test names** - "function does X when Y"
3. **Follow Arrange-Act-Assert pattern**
4. **Clean up after tests** - use `cleanup_test_db()`, `on.exit()`, etc.
5. **Don't test external APIs** - use mocks instead
6. **Keep tests fast** - aim for <1 second per test
7. **Test edge cases** - NULL, empty strings, invalid inputs
8. **Document complex tests** - add comments explaining what/why

## Resources

- **testthat documentation**: https://testthat.r-lib.org/
- **Shiny module testing**: https://shiny.rstudio.com/articles/modules.html
- **Coverage with covr**: https://covr.r-lib.org/
- **Golem testing**: https://thinkr-open.github.io/golem/

## Questions?

See `tests/README.md` for more detailed testing patterns and examples.
