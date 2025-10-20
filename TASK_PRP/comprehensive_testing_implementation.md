# TASK PRP: Comprehensive Testing Implementation

**Source PRP**: PRPs/PRP_COMPREHENSIVE_TESTING.md
**Created**: 2025-10-20
**Type**: Quality Assurance / Testing Infrastructure
**Estimated Time**: 46 hours (4 weeks @ 12 hrs/week)

---

## Context

### Current State
- ✅ Testing infrastructure exists (`tests/testthat/`, `testthat.R`)
- ✅ One working test file: `test-mod_postal_card_processor.R` (129 lines)
- ❌ Only 1 of 26 R files has tests (~4% coverage)
- ❌ 11 Shiny modules with NO tests
- ❌ 30+ database functions untested
- ❌ API integrations (AI, eBay) untested
- ❌ No integration tests with shinytest2
- ❌ No CI/CD pipeline

### Documentation References
```yaml
docs:
  - url: https://thinkr-open.github.io/golem/
    focus: Testing Golem apps
  - url: https://testthat.r-lib.org/
    focus: testthat framework
  - url: https://rstudio.github.io/shinytest2/
    focus: Integration testing
  - url: https://mastering-shiny.org/scaling-testing.html
    focus: Shiny testing patterns

patterns:
  - file: tests/testthat/test-mod_postal_card_processor.R
    copy: Unit test structure and naming conventions
  - file: tests/README.md
    copy: Test documentation approach

gotchas:
  - issue: "Python integration via reticulate can be fragile"
    fix: "Mock Python calls for unit tests, use real Python only for integration tests with skip_if_not()"
  - issue: "Shiny modules have namespace issues with testServer"
    fix: "Use shiny::testServer() with proper args list, mock reactive dependencies"
  - issue: "External API calls will fail/cost money in tests"
    fix: "Use mockery package to stub httr2::req_perform"
  - issue: "In-memory SQLite may not support all features"
    fix: "Test with real SQLite :memory: connection, matches production"
```

---

## Phase 1: Foundation Setup

**Goal**: Establish testing infrastructure and patterns
**Time**: 8 hours

### SETUP tests/testthat/helper-setup.R:
- CREATE shared setup utilities
  ```r
  # Helper for creating in-memory test database
  create_test_db <- function()
  cleanup_test_db <- function(db)
  with_test_db <- function(code)  # withr-style wrapper
  ```
- VALIDATE: Source file and run `create_test_db()` manually
- IF_FAIL: Check DBI and RSQLite are loaded
- ROLLBACK: Delete file if malformed

### SETUP tests/testthat/helper-mocks.R:
- CREATE mock factories for external dependencies
  ```r
  mock_claude_response <- function(success = TRUE)
  mock_openai_response <- function(success = TRUE)
  mock_ebay_oauth <- function(success = TRUE)
  with_mocked_ai <- function(code)
  with_mocked_ebay <- function(code)
  ```
- VALIDATE: Test each mock returns expected structure
- IF_FAIL: Check mockery package installed
- ROLLBACK: Delete file if malformed

### SETUP tests/testthat/helper-fixtures.R:
- CREATE test data generators
  ```r
  generate_test_card <- function(id = 1)
  generate_test_user <- function(username = "testuser")
  sample_ai_extraction <- function()
  ```
- VALIDATE: Generate sample data and inspect structure
- IF_FAIL: Check jsonlite for JSON serialization
- ROLLBACK: Delete file if malformed

### SETUP tests/fixtures/ directory:
- CREATE directory: `tests/fixtures/`
- COPY test images:
  - `test_face.jpg` (from existing test_images/)
  - `test_verso.jpg` (from existing test_images/)
- CREATE mock API responses:
  - `mock_api_responses/claude_success.json`
  - `mock_api_responses/claude_error.json`
  - `mock_api_responses/ebay_oauth.json`
- VALIDATE: All files exist and readable
- IF_FAIL: Check source files exist
- ROLLBACK: Remove directory if incomplete

### UPDATE DESCRIPTION:
- ADD to Suggests field:
  ```r
  Suggests:
      testthat (>= 3.0.0),
      shinytest2,
      mockery,
      withr,
      chromote,
      covr
  ```
- VALIDATE: Run `devtools::load_all()` without errors
- IF_FAIL: Check package names correct
- ROLLBACK: Git restore DESCRIPTION

### UPDATE tests/README.md:
- ADD section: "Testing Patterns"
- ADD examples for each helper function
- ADD mock usage documentation
- VALIDATE: Review for clarity
- IF_FAIL: Rewrite unclear sections
- ROLLBACK: Git restore README.md

**Phase 1 Deliverables**:
- ✅ 3 helper files created
- ✅ Fixtures directory with test data
- ✅ Dependencies added to DESCRIPTION
- ✅ Documentation updated

---

## Phase 2: Critical Unit Tests

**Goal**: Test core business logic functions
**Time**: 14 hours

### Priority 1: Database Functions (8 hours)

#### CREATE tests/testthat/test-tracking_database.R:
- SETUP: Source helper-setup.R
- TEST `initialize_tracking_db()`:
  ```r
  test_that("initialize_tracking_db creates all tables", {
    db <- create_test_db()
    tables <- DBI::dbListTables(db)
    expect_true("users" %in% tables)
    expect_true("cards" %in% tables)
    expect_true("processing_sessions" %in% tables)
    cleanup_test_db(db)
  })
  ```
- VALIDATE: Run `testthat::test_file("tests/testthat/test-tracking_database.R")`
- IF_FAIL: Check database initialization errors in console
- ROLLBACK: Remove test file

- TEST `calculate_image_hash()`:
  ```r
  test_that("calculate_image_hash returns consistent SHA-256", {
    test_img <- test_path("fixtures/test_face.jpg")
    hash1 <- calculate_image_hash(test_img)
    hash2 <- calculate_image_hash(test_img)

    expect_type(hash1, "character")
    expect_equal(nchar(hash1), 64)  # SHA-256 = 64 hex chars
    expect_equal(hash1, hash2)  # Deterministic
  })
  ```
- VALIDATE: Run test, verify hash is deterministic
- IF_FAIL: Check test image path exists
- ROLLBACK: Remove test

- TEST `get_or_create_card()`:
  ```r
  test_that("get_or_create_card creates new card", {
    db <- create_test_db()
    result <- get_or_create_card(db, "test_hash_123")

    expect_type(result$card_id, "integer")
    expect_equal(result$image_hash, "test_hash_123")
    expect_true(result$is_new)
    cleanup_test_db(db)
  })

  test_that("get_or_create_card finds existing card", {
    db <- create_test_db()
    first <- get_or_create_card(db, "test_hash_456")
    second <- get_or_create_card(db, "test_hash_456")

    expect_equal(first$card_id, second$card_id)
    expect_false(second$is_new)
    cleanup_test_db(db)
  })
  ```
- VALIDATE: Run tests, check both create and find paths
- IF_FAIL: Debug SQL queries with `DBI::dbGetQuery()`
- ROLLBACK: Remove tests

- TEST `save_card_processing()`:
  ```r
  test_that("save_card_processing stores metadata", {
    db <- create_test_db()
    card_info <- get_or_create_card(db, "hash_789")

    result <- save_card_processing(
      db,
      card_id = card_info$card_id,
      session_id = 1,
      face_path = "path/to/face.jpg",
      verso_path = "path/to/verso.jpg"
    )

    expect_true(result$success)

    # Verify stored in DB
    row <- DBI::dbGetQuery(db,
      "SELECT * FROM card_processing WHERE card_id = ?",
      params = list(card_info$card_id)
    )
    expect_equal(nrow(row), 1)
    expect_equal(row$face_path, "path/to/face.jpg")

    cleanup_test_db(db)
  })
  ```
- VALIDATE: Check data persists in database
- IF_FAIL: Check column names match schema
- ROLLBACK: Remove test

- TEST `track_ai_extraction()`:
- TEST `track_ebay_post()`:
- TEST `find_existing_processing()`:
- CONTINUE for all 30+ database functions...

**Strategy**: Add 5-7 tests per function covering:
1. Success path
2. Error handling (NULL values, invalid IDs)
3. Edge cases (empty strings, max values)
4. Data integrity (foreign keys, constraints)

- VALIDATE ENTIRE FILE: Run `devtools::test()`, check >30 tests pass
- IF_FAIL: Review failed test output, fix logic or tests
- ROLLBACK: Git restore test file

**Deliverables**:
- ✅ test-tracking_database.R with 30-40 tests
- ✅ All database functions tested
- ✅ >60% coverage of R/tracking_database.R

---

### Priority 2: AI API Helpers (4 hours)

#### CREATE tests/testthat/test-ai_api_helpers.R:
- SETUP: Source helper-mocks.R
- TEST `get_llm_config()`:
  ```r
  test_that("get_llm_config returns valid config", {
    config <- get_llm_config("claude")

    expect_type(config, "list")
    expect_true("api_key" %in% names(config))
    expect_true("model" %in% names(config))
  })
  ```
- VALIDATE: Run test
- IF_FAIL: Check config file structure
- ROLLBACK: Remove test

- TEST `compress_image_if_needed()`:
  ```r
  test_that("compress_image_if_needed reduces large images", {
    skip_if_not_installed("magick")

    # Create large test image (>5MB)
    large_img <- test_path("fixtures/test_face.jpg")

    result <- compress_image_if_needed(large_img, max_size_mb = 1)

    expect_type(result, "character")
    file_size_mb <- file.size(result) / 1024^2
    expect_lt(file_size_mb, 1.5)  # Some tolerance
  })

  test_that("compress_image_if_needed skips small images", {
    small_img <- test_path("fixtures/small.jpg")  # <1MB
    result <- compress_image_if_needed(small_img, max_size_mb = 5)

    expect_equal(result, small_img)  # No compression
  })
  ```
- VALIDATE: Run tests with different image sizes
- IF_FAIL: Check magick package available
- ROLLBACK: Remove tests

- TEST `call_claude_api()` (mocked):
  ```r
  test_that("call_claude_api succeeds with valid response", {
    with_mocked_ai({
      result <- call_claude_api(
        image_path = test_path("fixtures/test_face.jpg"),
        prompt = "Test prompt"
      )

      expect_true(result$success)
      expect_type(result$data, "list")
    })
  })

  test_that("call_claude_api handles rate limiting", {
    mockery::stub(
      call_claude_api,
      "httr2::req_perform",
      mock_claude_response(success = FALSE)
    )

    result <- call_claude_api(test_path("fixtures/test_face.jpg"), "Test")

    expect_false(result$success)
    expect_match(result$error, "Rate limit")
  })
  ```
- VALIDATE: Run tests, verify mocking works
- IF_FAIL: Check mockery package loaded
- ROLLBACK: Remove tests

- TEST `parse_ai_response()`:
  ```r
  test_that("parse_ai_response extracts JSON from text", {
    response_text <- '{
      "title": "Vintage Postcard",
      "description": "Paris 1920s",
      "price": "15.00"
    }'

    result <- parse_ai_response(response_text)

    expect_type(result, "list")
    expect_equal(result$title, "Vintage Postcard")
    expect_equal(result$price, "15.00")
  })

  test_that("parse_ai_response handles malformed JSON", {
    bad_json <- '{"title": "Missing closing brace"'

    expect_error(parse_ai_response(bad_json), "JSON")
  })
  ```
- VALIDATE: Test with various JSON formats
- IF_FAIL: Check jsonlite parsing
- ROLLBACK: Remove tests

- CONTINUE for remaining AI helper functions...

- VALIDATE ENTIRE FILE: Run `devtools::test()`
- IF_FAIL: Fix failing tests
- ROLLBACK: Git restore

**Deliverables**:
- ✅ test-ai_api_helpers.R with 13-20 tests
- ✅ All AI functions tested with mocks
- ✅ Error handling validated

---

### Priority 3: Utility Functions (2 hours)

#### CREATE tests/testthat/test-utils_helpers.R:
- TEST `safe_session_id()`:
- TEST `update_delcampe_status()`:
- VALIDATE: Run tests
- ROLLBACK: Remove file if issues

#### CREATE tests/testthat/test-ebay_helpers.R:
- TEST eBay helper functions
- VALIDATE: Run tests
- ROLLBACK: Remove file if issues

**Deliverables**:
- ✅ Utility function tests
- ✅ All tests passing

**Phase 2 Complete**:
- ✅ 3 test files created
- ✅ 50-70 unit tests written
- ✅ >60% unit test coverage

---

## Phase 3: Module Tests

**Goal**: Test all Shiny module server logic
**Time**: 16 hours

### Priority 1: Authentication Module (3 hours)

#### CREATE tests/testthat/test-mod_login.R:
- SETUP: Load mod_login.R functions
- TEST valid authentication:
  ```r
  test_that("mod_login authenticates valid credentials", {
    testdb <- create_test_db()
    ensure_user_exists(testdb, "testuser", "password123", FALSE)

    shiny::testServer(mod_login_server, args = list(db = testdb), {
      # Simulate login form submission
      session$setInputs(
        username = "testuser",
        password = "password123",
        login_btn = 1
      )

      # Assert authentication succeeds
      expect_true(authenticated())
      expect_equal(current_user(), "testuser")
    })

    cleanup_test_db(testdb)
  })
  ```
- VALIDATE: Run `testthat::test_file("tests/testthat/test-mod_login.R")`
- IF_FAIL: Check module namespace issues, review testServer docs
- ROLLBACK: Remove test

- TEST invalid credentials:
  ```r
  test_that("mod_login rejects invalid password", {
    testdb <- create_test_db()
    ensure_user_exists(testdb, "testuser", "correct_pass", FALSE)

    shiny::testServer(mod_login_server, args = list(db = testdb), {
      session$setInputs(
        username = "testuser",
        password = "wrong_pass",
        login_btn = 1
      )

      expect_false(authenticated())
      expect_null(current_user())
    })

    cleanup_test_db(testdb)
  })
  ```
- VALIDATE: Test fails correctly
- IF_FAIL: Check password hashing logic
- ROLLBACK: Remove test

- TEST master user protection:
  ```r
  test_that("mod_login enforces master user privileges", {
    testdb <- create_test_db()
    ensure_user_exists(testdb, "master", "masterpass", TRUE)

    shiny::testServer(mod_login_server, args = list(db = testdb), {
      session$setInputs(
        username = "master",
        password = "masterpass",
        login_btn = 1
      )

      expect_true(authenticated())
      expect_true(is_master_user())
    })

    cleanup_test_db(testdb)
  })
  ```
- VALIDATE: Master user flag set correctly
- IF_FAIL: Check user table schema
- ROLLBACK: Remove test

- CONTINUE with session management, logout, etc.
- VALIDATE ENTIRE FILE: All auth tests pass
- ROLLBACK: Git restore

**Deliverables**:
- ✅ test-mod_login.R with 8-12 tests
- ✅ Authentication flows validated
- ✅ Security checks tested

---

### Priority 2: AI Extraction Module (3 hours)

#### CREATE tests/testthat/test-mod_ai_extraction.R:
- TEST image upload handling:
  ```r
  test_that("mod_ai_extraction processes uploaded image", {
    testdb <- create_test_db()

    shiny::testServer(
      mod_ai_extraction_server,
      args = list(db = testdb, session_id = reactive(1)),
      {
        # Mock file upload
        session$setInputs(
          image_upload = list(
            datapath = test_path("fixtures/test_face.jpg"),
            name = "test.jpg"
          )
        )

        # Verify image processed
        expect_true(!is.null(output$preview_image))
      }
    )

    cleanup_test_db(testdb)
  })
  ```
- VALIDATE: Run test
- IF_FAIL: Check reactive dependency issues
- ROLLBACK: Remove test

- TEST provider selection:
- TEST extraction triggering (mocked AI call):
  ```r
  test_that("mod_ai_extraction calls AI API", {
    testdb <- create_test_db()

    with_mocked_ai({
      shiny::testServer(
        mod_ai_extraction_server,
        args = list(db = testdb, session_id = reactive(1)),
        {
          session$setInputs(
            provider = "claude",
            extract_btn = 1
          )

          # Wait for async processing
          Sys.sleep(0.5)

          # Verify extraction results
          expect_true(!is.null(extraction_results()))
          expect_type(extraction_results()$title, "character")
        }
      )
    })

    cleanup_test_db(testdb)
  })
  ```
- VALIDATE: Mocked extraction works
- IF_FAIL: Check mockery setup
- ROLLBACK: Remove test

- CONTINUE for error handling, result display...
- VALIDATE ENTIRE FILE: All tests pass
- ROLLBACK: Git restore

**Deliverables**:
- ✅ test-mod_ai_extraction.R with 10-15 tests

---

### Priority 3-5: Remaining Modules (10 hours)

Follow same pattern for:
- **mod_ebay_auth** (OAuth flow, token storage)
- **mod_ebay_postcard** (Listing creation, image upload)
- **mod_delcampe_export** (Export functionality)
- **mod_postal_card_processor** (Extend existing tests)
- **mod_tracking_viewer** (Data display)
- **mod_settings_password** (Password changes)
- **mod_settings_llm** (LLM configuration)

**Each module**: 1-2 hours, 6-10 tests

**Deliverables**:
- ✅ 8 new module test files
- ✅ 50-70 module tests total
- ✅ All critical paths covered

**Phase 3 Complete**:
- ✅ 11 modules tested
- ✅ 100% module coverage

---

## Phase 4: Integration Tests

**Goal**: Test complete user workflows
**Time**: 6 hours

### SETUP shinytest2:
- INSTALL chromote: `install.packages("chromote")`
- VALIDATE: Check Chrome/Chromium available
- IF_FAIL: Install Chrome browser
- ROLLBACK: Skip integration tests for now

### CREATE tests/testthat/test-integration-workflows.R:
- TEST complete processing workflow:
  ```r
  test_that("Complete postcard processing workflow", {
    skip_if_not_installed("chromote")

    app <- shinytest2::AppDriver$new(
      app_dir = system.file(package = "Delcampe"),
      name = "postcard-workflow",
      height = 800,
      width = 1200
    )

    # Login
    app$set_inputs(username = "testuser", password = "testpass")
    app$click("login_btn")
    app$wait_for_idle(timeout = 2000)

    # Upload image
    app$upload_file(
      upload = test_path("../fixtures/test_face.jpg")
    )
    app$wait_for_idle(timeout = 3000)

    # Process grid
    app$click("process_btn")
    app$wait_for_idle(timeout = 10000)

    # Verify crops created
    app$expect_values(output = "crop_grid")

    # Extract with AI (mocked)
    app$click("extract_btn")
    app$wait_for_idle(timeout = 20000)

    # Verify results
    app$expect_values(output = "extraction_results")

    app$stop()
  })
  ```
- VALIDATE: Run test (may take 30+ seconds)
- IF_FAIL: Check timeout values, app initialization
- ROLLBACK: Remove test

- TEST eBay posting workflow:
- TEST settings configuration:
- TEST tracking & history:

**Deliverables**:
- ✅ 4 integration test scenarios
- ✅ Full workflows validated

**Phase 4 Complete**:
- ✅ Integration tests working
- ✅ E2E flows covered

---

## Phase 5: CI/CD Pipeline

**Goal**: Automate test execution
**Time**: 2 hours

### CREATE .github/workflows/test.yaml:
- WRITE GitHub Actions configuration:
  ```yaml
  name: Test Suite

  on:
    push:
      branches: [main, master, develop]
    pull_request:
      branches: [main, master]

  jobs:
    test:
      runs-on: ubuntu-latest

      steps:
        - uses: actions/checkout@v3

        - uses: r-lib/actions/setup-r@v2
          with:
            r-version: '4.3.0'

        - uses: r-lib/actions/setup-r-dependencies@v2
          with:
            extra-packages: |
              any::rcmdcheck
              any::covr

        - name: Setup Python
          uses: actions/setup-python@v4
          with:
            python-version: '3.12'

        - name: Install Python dependencies
          run: |
            python -m pip install opencv-python numpy

        - name: Run tests
          run: |
            devtools::test()
          shell: Rscript {0}

        - name: Test coverage
          run: |
            covr::codecov(quiet = FALSE)
          shell: Rscript {0}
  ```
- VALIDATE: Push to GitHub, check Actions tab
- IF_FAIL: Review workflow syntax, permissions
- ROLLBACK: Delete workflow file

### SETUP coverage reporting:
- REGISTER with Codecov.io or Coveralls
- ADD badge to README.md
- VALIDATE: Coverage report generated
- IF_FAIL: Check token configuration
- ROLLBACK: Remove badge

**Deliverables**:
- ✅ CI/CD pipeline running
- ✅ Coverage reporting enabled

---

## Validation Strategy

### After Each Phase:
1. **Run all tests**: `devtools::test()`
2. **Check coverage**: `covr::package_coverage()`
3. **Review failures**: Fix or document known issues
4. **Update docs**: Document new patterns

### Final Validation:
- ✅ >70% code coverage
- ✅ 100% module coverage
- ✅ 0 test failures
- ✅ <5 min execution time
- ✅ CI passing

---

## Rollback Strategy

### Per-File Rollback:
```bash
git restore tests/testthat/test-<name>.R
```

### Per-Phase Rollback:
```bash
git restore tests/testthat/
git restore DESCRIPTION
```

### Complete Rollback:
```bash
git restore tests/
git restore .github/workflows/
git restore DESCRIPTION
```

---

## Success Criteria

### Quantitative:
- [ ] 70%+ code coverage
- [ ] 113-157 tests implemented
- [ ] All 11 modules tested
- [ ] 4 integration tests
- [ ] CI pipeline passing

### Qualitative:
- [ ] Tests readable and well-documented
- [ ] Easy to add new tests
- [ ] Catches regressions
- [ ] Developer confidence high

---

## Timeline

| Phase | Tasks | Time | Deliverables |
|-------|-------|------|-------------|
| 1 | Foundation | 8 hrs | Helpers, fixtures, deps |
| 2 | Unit Tests | 14 hrs | 50-70 tests, 60% coverage |
| 3 | Module Tests | 16 hrs | 11 modules, 50-70 tests |
| 4 | Integration | 6 hrs | 4 E2E workflows |
| 5 | CI/CD | 2 hrs | Automated pipeline |
| **Total** | | **46 hrs** | **113-157 tests** |

---

## Risk Mitigation

### Python Integration:
- Mock Python calls in unit tests
- Use real Python only in integration tests
- Add `skip_if_not()` checks

### Flaky Tests:
- Use stable mocks
- Avoid time-dependent assertions
- Set appropriate timeouts

### Maintenance:
- Follow DRY with helpers
- Keep tests focused
- Update alongside code

---

## Next Steps

1. **Review this task PRP** ✅
2. **Get approval** to proceed
3. **Begin Phase 1** (Foundation)
4. **Iterate through phases**
5. **Deploy with >70% coverage**

---

**END OF TASK PRP**
