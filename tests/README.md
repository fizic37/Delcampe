# Tests Directory Structure

This directory contains tests for the Delcampe package following the Golem framework structure.

## Structure

```
tests/
├── testthat.R              # Test runner configuration
├── testthat/               # Automated unit tests (run with testthat)
│   └── test-mod_postal_card_processor.R  # Tests for coordinate mapping
├── manual/                 # Manual verification scripts
│   ├── verify_fix.R        # Complete system verification
│   ├── test_coordinate_mapping.R  # Visual coordinate conversion test
│   ├── debug_upload_issue.R  # Legacy debug script
│   └── test_drag_bug.R     # Legacy debug script
└── README.md              # This file
```

## Running Tests

### Automated Unit Tests (Recommended)

Run all tests:
```r
devtools::test()
# or
testthat::test_dir("tests/testthat")
```

Run specific test file:
```r
testthat::test_file("tests/testthat/test-mod_postal_card_processor.R")
```

### Manual Verification Scripts

**Complete system verification:**
```r
source("tests/manual/verify_fix.R")
```
This checks:
- File existence
- JavaScript implementation
- R module configuration
- Mathematical accuracy

**Visual coordinate mapping test:**
```r
source("tests/manual/test_coordinate_mapping.R")
```
This shows:
- Step-by-step coordinate conversion
- Expected vs actual values
- Testing instructions

## Test Coverage

### mod_postal_card_processor Tests

**Coordinate Conversion Math** (`test-mod_postal_card_processor.R`)
- ✅ Forward conversion (Original → Screen)
- ✅ Reverse conversion (Screen → Original)
- ✅ Round-trip accuracy (<0.1px error)
- ✅ Rendered bounds calculation
- ✅ Offset calculations for object-fit:contain
- ✅ Scale factor conversion matching JavaScript
- ✅ Boundary array validation
- ✅ Grid dimension derivation

## Test Data

Test images are located in `test_images/`:
- `test_face.jpg` - Face side of postcards (1915×3507)
- `test_verso.jpg` - Verso side of postcards

Test fixtures are located in `tests/fixtures/`:
- `test_face.jpg` - Copy of face image for unit tests
- `test_verso.jpg` - Copy of verso image for unit tests
- `mock_api_responses/` - Mock JSON responses for external APIs

## Testing Patterns

### Helper Functions

The test suite includes three helper files that are automatically sourced:

#### `helper-setup.R` - Database Setup

```r
# Create an in-memory test database
db <- create_test_db()

# Clean up when done
cleanup_test_db(db)

# Or use withr-style wrapper
with_test_db({
  # db is available here
  result <- get_or_create_card(db, "test_hash")
})

# Create test users
user_id <- create_test_user(db, "testuser", "testpass", is_master = FALSE)

# Create test sessions
session_id <- create_test_session(db, user_id)
```

#### `helper-mocks.R` - External API Mocking

```r
# Mock Claude API response
response <- mock_claude_response(success = TRUE)

# Mock OpenAI API response
response <- mock_openai_response(success = TRUE)

# Mock eBay OAuth
token <- mock_ebay_oauth(success = TRUE)

# Use mocked AI in tests
with_mocked_ai({
  result <- call_claude_api(test_image, "Extract title")
  expect_true(result$success)
}, provider = "claude")

# Use mocked eBay
with_mocked_ebay({
  token <- fetch_ebay_token()
  expect_true(!is.null(token$access_token))
})

# Mock file upload for Shiny
upload <- mock_file_upload(test_path("fixtures/test_face.jpg"))
```

#### `helper-fixtures.R` - Test Data Generators

```r
# Generate test card
card <- generate_test_card(id = 1)

# Generate test user
user <- generate_test_user(username = "alice")

# Generate AI extraction result
extraction <- sample_ai_extraction(side = "face", quality = "high")

# Generate test session
session <- generate_test_session(session_id = 1, num_cards = 5)

# Generate test crops
crops <- generate_test_crops(num_crops = 6)

# Generate eBay listing data
listing <- generate_test_ebay_listing(listing_id = 1)

# Generate Delcampe export data
export <- generate_test_delcampe_export(export_id = 1)
```

### Testing Shiny Modules

Use `shiny::testServer()` for module testing:

```r
test_that("module server logic works", {
  testdb <- create_test_db()

  shiny::testServer(
    mod_example_server,
    args = list(db = testdb, session_id = reactive(1)),
    {
      # Set inputs
      session$setInputs(
        input_field = "test value",
        action_btn = 1
      )

      # Assert reactive values
      expect_true(some_reactive_value())

      # Assert outputs
      expect_true(!is.null(output$result))
    }
  )

  cleanup_test_db(testdb)
})
```

### Testing Database Functions

```r
test_that("database function performs correctly", {
  with_test_db({
    # Arrange
    card <- get_or_create_card(db, "test_hash")

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

### Testing with Mocked APIs

```r
test_that("AI extraction handles API errors gracefully", {
  with_mocked_ai({
    result <- extract_with_ai(
      image_path = test_path("fixtures/test_face.jpg"),
      provider = "claude"
    )

    expect_true(result$success)
    expect_type(result$data$title, "character")
  }, provider = "claude", success = TRUE)

  # Test error handling
  with_mocked_ai({
    result <- extract_with_ai(
      image_path = test_path("fixtures/test_face.jpg"),
      provider = "claude"
    )

    expect_false(result$success)
    expect_match(result$error, "Rate limit")
  }, provider = "claude", success = FALSE)
})
```

### Using Test Fixtures

```r
test_that("image processing works correctly", {
  # Use test image from fixtures
  test_img <- test_path("fixtures/test_face.jpg")

  # Process image
  result <- process_image(test_img)

  # Assert
  expect_true(file.exists(result$output_path))
})
```

## Adding New Tests

### For Automated Tests

Create a new file in `tests/testthat/` following the naming convention:
```
test-<module_name>.R
```

Example structure:
```r
test_that("description of what you're testing", {
  # Arrange
  input <- some_value
  
  # Act
  result <- function_to_test(input)
  
  # Assert
  expect_equal(result, expected_value)
})
```

### For Manual Tests

Create a new file in `tests/manual/` with descriptive name:
```
verify_<feature>.R
```

Include:
- Clear comments explaining what it tests
- Step-by-step instructions
- Expected output examples
- Visual indicators (✅/❌) for pass/fail

## Continuous Integration

To add CI testing, create `.github/workflows/R-CMD-check.yaml`:
```yaml
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

name: R-CMD-check

jobs:
  R-CMD-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: r-lib/actions/setup-r@v2
      - uses: r-lib/actions/setup-r-dependencies@v2
      - uses: r-lib/actions/check-r-package@v2
```

## Test Philosophy

### Automated Tests Should:
- Run quickly (<1 second each)
- Be deterministic (same input = same output)
- Test one thing at a time
- Not depend on external state
- Be easy to understand

### Manual Tests Should:
- Provide visual feedback
- Include step-by-step instructions
- Show expected vs actual results
- Be runnable by non-technical users
- Document complex scenarios

## Debugging Failed Tests

If tests fail:

1. **Check the test output** - testthat provides clear error messages
2. **Run the test interactively** - Source the test file and step through
3. **Check console logs** - Especially for JavaScript-R integration
4. **Verify test data** - Ensure test images exist and are valid
5. **Check dependencies** - Make sure all packages are installed

## Related Documentation

- **`.serena/memories/draggable_lines_coordinate_fix.md`** - Technical solution details
- **`COORDINATE_FIX_SUMMARY.md`** - Complete reference documentation
- **`IMPLEMENTATION_GUIDE.md`** - Quick start guide
- **Golem Book**: https://thinkr-open.github.io/golem/

## Maintenance

When modifying the coordinate mapping logic:
1. ✅ Update tests in `test-mod_postal_card_processor.R`
2. ✅ Run `devtools::test()` to verify all tests pass
3. ✅ Update documentation in `.serena/memories/`
4. ✅ Run manual verification: `source("tests/manual/verify_fix.R")`
5. ✅ Test visually in running app

## Questions?

- For automated tests: See testthat documentation
- For Golem structure: See Golem book
- For coordinate mapping: See `.serena/memories/draggable_lines_coordinate_fix.md`
