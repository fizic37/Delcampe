# PRP: Comprehensive Automated Testing for Delcampe App

**Status**: Draft
**Priority**: High (Pre-Deployment Critical)
**Created**: 2025-10-20
**Type**: Quality Assurance / Testing Infrastructure

---

## Executive Summary

The Delcampe Postal Card Processor app is near production deployment but lacks comprehensive automated test coverage. Currently, only 1 out of 24 R modules has tests (`test-mod_postal_card_processor.R` for coordinate mapping), representing ~4% code coverage. This PRP defines a phased approach to implement production-grade automated testing following Golem framework best practices.

## Business Context

### Why Now?
- **Pre-Deployment Critical**: App is close to production deployment
- **Risk Mitigation**: Prevent regressions as features evolve
- **Confidence**: Enable safe refactoring and feature additions
- **Maintenance**: Reduce debugging time for future issues
- **Documentation**: Tests serve as executable documentation

### Current State Assessment

**Existing Test Infrastructure** ✅
- `tests/testthat/` directory exists
- `testthat.R` runner configured
- One working test file: `test-mod_postal_card_processor.R`
- Manual test scripts in `tests/manual/`
- Clear README with testing guidelines

**Coverage Gaps** ❌
- 11 Shiny modules with NO tests
- 30+ database functions untested
- API integrations (AI, eBay) untested
- Authentication/authorization logic untested
- Utility functions untested
- No integration tests
- No CI/CD pipeline

## Goals

### Primary Goals
1. **Achieve 70%+ code coverage** for critical business logic
2. **Test all Shiny modules** using `shiny::testServer()`
3. **Implement integration tests** using `shinytest2`
4. **Establish CI/CD pipeline** for automated test execution
5. **Document testing patterns** for future development

### Secondary Goals
- Mock external API dependencies (AI, eBay)
- Test database operations with in-memory SQLite
- Validate authentication/authorization flows
- Test error handling and edge cases
- Establish performance benchmarks

## Technical Approach

### Testing Strategy Overview

```
┌─────────────────────────────────────────────────────┐
│                 Testing Pyramid                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│         ▲                                            │
│        ╱ ╲    E2E Tests (shinytest2)                │
│       ╱   ╲   - Full app workflows                  │
│      ╱     ╲  - User scenarios                      │
│     ╱───────╲                                        │
│    ╱         ╲                                       │
│   ╱ Integration╲                                     │
│  ╱   Tests      ╲                                    │
│ ╱ (testServer)   ╲                                   │
│╱─────────────────╲                                   │
│   Unit Tests      │                                  │
│   (testthat)      │                                  │
│   70% of tests    │                                  │
└───────────────────┘                                  │
```

### Testing Layers

#### Layer 1: Unit Tests (testthat)
**Purpose**: Test individual functions in isolation
**Tool**: `testthat` (>= 3.0.0)
**Coverage Target**: 70% of tests

**What to Test**:
- Helper functions (`utils_helpers.R`)
- Database CRUD operations (`tracking_database.R`)
- API helper functions (`ai_api_helpers.R`)
- Configuration functions (`app_config.R`)
- Utility functions (`python_cache_utils.R`, `ebay_policy_helper.R`)

**Patterns**:
```r
test_that("calculate_image_hash returns consistent SHA-256 hash", {
  # Arrange
  test_image <- test_path("fixtures/test_face.jpg")

  # Act
  hash1 <- calculate_image_hash(test_image)
  hash2 <- calculate_image_hash(test_image)

  # Assert
  expect_type(hash1, "character")
  expect_equal(nchar(hash1), 64)  # SHA-256 = 64 hex chars
  expect_equal(hash1, hash2)  # Deterministic
})
```

#### Layer 2: Module Tests (shiny::testServer)
**Purpose**: Test Shiny module server logic
**Tool**: `shiny::testServer()` + `testthat`
**Coverage Target**: 20% of tests

**What to Test**:
- Module reactive logic
- Input/output behavior
- Module return values
- Observer behavior
- Error handling within modules

**Modules to Test** (Priority Order):
1. `mod_login` - Authentication (CRITICAL)
2. `mod_ai_extraction` - AI extraction logic
3. `mod_delcampe_export` - Export functionality
4. `mod_ebay_postcard` - eBay integration
5. `mod_ebay_auth` - OAuth flow
6. `mod_postal_card_processor` - Image processing
7. `mod_tracking_viewer` - Data display
8. `mod_settings_password` - Security
9. `mod_settings_llm` - Configuration
10. `mod_delcampe_ui` - UI logic
11. `mod_settings_ui` - Settings interface

**Patterns**:
```r
test_that("mod_login authenticates valid credentials", {
  # Setup mock database
  testdb <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  initialize_tracking_db(testdb)
  ensure_user_exists(testdb, "testuser", "password123", FALSE)

  testServer(mod_login_server, args = list(db = testdb), {
    # Simulate user input
    session$setInputs(
      username = "testuser",
      password = "password123",
      login_btn = 1
    )

    # Assert authentication succeeds
    expect_true(authenticated())
    expect_equal(current_user(), "testuser")
  })

  DBI::dbDisconnect(testdb)
})
```

#### Layer 3: Integration Tests (shinytest2)
**Purpose**: Test full app workflows and module interactions
**Tool**: `shinytest2` + chromote
**Coverage Target**: 10% of tests

**What to Test**:
- Complete user workflows
- Module-to-module interactions
- Authentication flows
- Image upload → processing → export pipeline
- Settings persistence
- Navigation between sections

**Patterns**:
```r
test_that("Complete postcard processing workflow", {
  # Launch app
  app <- AppDriver$new(
    app_dir = system.file(package = "Delcampe"),
    name = "postcard-workflow"
  )

  # Login
  app$set_inputs(username = "testuser", password = "testpass")
  app$click("login_btn")
  app$expect_values(output = "authenticated")

  # Upload image
  app$upload_file(upload = test_path("fixtures/test_face.jpg"))
  app$wait_for_idle()

  # Process grid
  app$click("process_btn")
  app$wait_for_idle(timeout = 10000)

  # Verify crops created
  app$expect_values(output = "crop_grid")

  # Extract with AI
  app$click("extract_btn")
  app$wait_for_idle(timeout = 20000)

  # Verify extraction results
  app$expect_values(output = "extraction_results")
})
```

### Test Organization Structure

```
tests/
├── testthat.R                              # Test runner (existing)
├── README.md                               # Testing guidelines (existing)
│
├── testthat/
│   ├── helper-setup.R                      # Shared test utilities
│   ├── helper-mocks.R                      # Mock factories
│   ├── helper-fixtures.R                   # Test data generators
│   │
│   ├── test-utils_helpers.R                # Unit: Helper functions
│   ├── test-tracking_database.R            # Unit: Database operations
│   ├── test-ai_api_helpers.R               # Unit: AI API helpers
│   ├── test-ebay_helpers.R                 # Unit: eBay helpers
│   ├── test-app_config.R                   # Unit: Configuration
│   │
│   ├── test-mod_login.R                    # Module: Authentication
│   ├── test-mod_ai_extraction.R            # Module: AI extraction
│   ├── test-mod_delcampe_export.R          # Module: Export
│   ├── test-mod_ebay_postcard.R            # Module: eBay listing
│   ├── test-mod_ebay_auth.R                # Module: OAuth
│   ├── test-mod_postal_card_processor.R    # Module: Processing (exists)
│   ├── test-mod_tracking_viewer.R          # Module: Viewer
│   ├── test-mod_settings_password.R        # Module: Security
│   ├── test-mod_settings_llm.R             # Module: LLM config
│   │
│   └── test-integration-workflows.R        # Integration: Full workflows
│
├── fixtures/                               # Test data
│   ├── test_face.jpg                       # Sample images
│   ├── test_verso.jpg
│   ├── mock_api_responses/                 # Recorded API responses
│   │   ├── claude_response.json
│   │   └── ebay_oauth_response.json
│   └── sample_database.sqlite              # Pre-populated test DB
│
└── manual/                                 # Manual tests (existing)
    ├── verify_fix.R
    ├── test_coordinate_mapping.R
    └── ...
```

## Implementation Plan

### Phase 1: Foundation (Week 1)
**Goal**: Establish testing infrastructure and patterns

**Tasks**:
1. **Update DESCRIPTION** with test dependencies:
   ```r
   Suggests:
       testthat (>= 3.0.0),
       shinytest2,
       mockery,
       withr,
       chromote
   ```

2. **Create test helpers** (`tests/testthat/helper-*.R`):
   - `helper-setup.R`: Shared setup/teardown utilities
   - `helper-mocks.R`: Mock API responses and external dependencies
   - `helper-fixtures.R`: Test data generators

3. **Setup test fixtures** (`tests/fixtures/`):
   - Copy test images
   - Create mock API response files
   - Generate sample database

4. **Document testing patterns**:
   - Update `tests/README.md` with patterns
   - Add examples for each testing layer
   - Document mock usage

**Deliverables**:
- ✅ Testing dependencies installed
- ✅ Helper files created
- ✅ Fixtures organized
- ✅ Documentation updated

---

### Phase 2: Critical Unit Tests (Week 1-2)
**Goal**: Test core business logic functions

**Priority 1: Database Functions** (`test-tracking_database.R`)
Test all functions in `R/tracking_database.R`:
- `initialize_tracking_db()` - Schema creation
- `get_or_create_card()` - Card CRUD
- `save_card_processing()` - Processing tracking
- `track_ai_extraction()` - AI tracking
- `track_ebay_post()` - eBay tracking
- `calculate_image_hash()` - Hash generation
- `find_existing_processing()` - Deduplication
- All 30+ database functions

**Priority 2: API Helpers** (`test-ai_api_helpers.R`)
Test functions in `R/ai_api_helpers.R`:
- `get_llm_config()` - Config retrieval
- `compress_image_if_needed()` - Image compression
- `call_claude_api()` - API calls (mocked)
- `call_openai_api()` - API calls (mocked)
- `parse_ai_response()` - Response parsing
- `extract_with_llm()` - End-to-end extraction

**Priority 3: Utility Functions** (`test-utils_helpers.R`, `test-ebay_helpers.R`)
- `safe_session_id()` - Session management
- `update_delcampe_status()` - Status updates
- eBay helper functions

**Testing Pattern**: Use in-memory SQLite for database tests, mock HTTP calls for API tests

**Deliverables**:
- ✅ 30+ database function tests
- ✅ 13 AI API helper tests
- ✅ Utility function tests
- ✅ >60% unit test coverage

---

### Phase 3: Module Tests (Week 2-3)
**Goal**: Test all Shiny module server logic

**Priority 1: Authentication** (`test-mod_login.R`)
- Valid credentials authenticate
- Invalid credentials fail
- Session management works
- Master user protections enforced

**Priority 2: AI Extraction** (`test-mod_ai_extraction.R`)
- Image upload handling
- Provider selection
- Extraction triggering
- Result parsing and display
- Error handling

**Priority 3: eBay Integration** (`test-mod_ebay_auth.R`, `test-mod_ebay_postcard.R`)
- OAuth flow initiation
- Token storage
- Listing creation
- Image upload to eBay
- Error handling

**Priority 4: Processing** (`test-mod_postal_card_processor.R`)
- Already has coordinate tests
- Add tests for:
  - Image upload
  - Grid detection
  - Crop extraction
  - Results display

**Priority 5: Settings & Tracking**
- `test-mod_settings_password.R` - Password changes
- `test-mod_settings_llm.R` - LLM configuration
- `test-mod_tracking_viewer.R` - Data display

**Testing Pattern**: Use `shiny::testServer()` with mocked database and API connections

**Deliverables**:
- ✅ 11 module test files
- ✅ Critical paths covered
- ✅ Error scenarios tested

---

### Phase 4: Integration Tests (Week 3-4)
**Goal**: Test complete user workflows

**Test Scenarios**:
1. **Complete Processing Workflow**:
   - Login → Upload → Process → Extract → Export

2. **eBay Posting Workflow**:
   - Login → OAuth → Process → Create Listing → Upload Images

3. **Settings Configuration**:
   - Login → Change Password → Configure LLM → Test Extraction

4. **Tracking & History**:
   - Login → View Tracking → Filter Data → Export

**Testing Pattern**: Use `shinytest2::AppDriver` for full app testing

**Deliverables**:
- ✅ 4 integration test scenarios
- ✅ Screenshot comparisons
- ✅ Workflow validation

---

### Phase 5: CI/CD Pipeline (Week 4)
**Goal**: Automate test execution

**Setup GitHub Actions**:
Create `.github/workflows/test.yaml`:
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
          covr::codecov()
        shell: Rscript {0}
```

**Coverage Reporting**:
- Integrate with Codecov or Coveralls
- Display coverage badge in README
- Set minimum coverage threshold (60%)

**Deliverables**:
- ✅ CI/CD pipeline configured
- ✅ Automated test execution on push/PR
- ✅ Coverage reporting enabled

---

### Phase 6: Documentation & Maintenance (Ongoing)
**Goal**: Establish testing culture

**Documentation**:
1. Update `tests/README.md` with:
   - All testing patterns
   - How to run tests locally
   - How to add new tests
   - Troubleshooting guide

2. Create `docs/guides/TESTING_GUIDE.md`:
   - Testing philosophy
   - Best practices
   - Common patterns
   - Mock examples

3. Add testing section to main `README.md`:
   - Coverage badge
   - Quick start
   - Link to full guide

**Maintenance**:
- Require tests for all new features
- Update tests when modifying existing code
- Review test failures in CI before merging
- Monitor coverage trends

**Deliverables**:
- ✅ Comprehensive testing documentation
- ✅ Testing culture established
- ✅ Maintenance procedures defined

---

## Technical Implementation Details

### Mocking External Dependencies

#### AI API Mocking
```r
# tests/testthat/helper-mocks.R
mock_claude_response <- function(success = TRUE) {
  if (success) {
    list(
      status_code = 200,
      content = list(
        content = list(
          list(text = '{
            "title": "Test Postcard",
            "description": "Vintage postcard from Paris",
            "price": "15.00",
            "condition": "Good"
          }')
        )
      )
    )
  } else {
    list(status_code = 429, content = list(error = "Rate limit exceeded"))
  }
}

with_mocked_ai <- function(code) {
  mockery::stub(code, "httr2::req_perform", mock_claude_response())
}
```

#### Database Mocking
```r
# tests/testthat/helper-fixtures.R
create_test_db <- function() {
  db <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
  initialize_tracking_db(db)

  # Add test data
  ensure_user_exists(db, "testuser", "password123", FALSE)
  ensure_user_exists(db, "master", "masterpass", TRUE)

  db
}

cleanup_test_db <- function(db) {
  DBI::dbDisconnect(db)
}
```

#### eBay API Mocking
```r
mock_ebay_oauth <- function(success = TRUE) {
  if (success) {
    list(
      access_token = "test_token_123",
      refresh_token = "refresh_token_456",
      expires_in = 7200
    )
  } else {
    stop("OAuth failed")
  }
}
```

### Python Integration Testing

**Challenge**: Testing R-Python integration via reticulate

**Approach**:
1. **Mock Python functions** for unit tests:
```r
test_that("Grid detection handles Python errors", {
  # Mock py_func to raise error
  mockery::stub(
    detect_grid_layout,
    "reticulate::py_call",
    function(...) stop("Python error")
  )

  expect_error(
    detect_grid_layout(test_image),
    "Python error"
  )
})
```

2. **Integration tests** with real Python:
```r
test_that("Grid detection works with real Python", {
  skip_if_not(reticulate::py_module_available("cv2"), "OpenCV not available")

  result <- detect_grid_layout(test_path("fixtures/test_face.jpg"))

  expect_type(result, "list")
  expect_true("h_boundaries" %in% names(result))
  expect_true("v_boundaries" %in% names(result))
})
```

### Authentication Testing

**Critical**: Master user protections must be tested

```r
test_that("Master users cannot be deleted", {
  testdb <- create_test_db()

  # Try to delete master user
  result <- delete_user(testdb, "master", requester = "testuser")

  expect_false(result$success)
  expect_match(result$error, "cannot delete master")

  cleanup_test_db(testdb)
})

test_that("Master users can manage their own credentials", {
  testdb <- create_test_db()

  result <- change_password(
    testdb,
    username = "master",
    old_password = "masterpass",
    new_password = "newpass123"
  )

  expect_true(result$success)

  cleanup_test_db(testdb)
})
```

### Performance Testing

**Optional**: Add performance benchmarks

```r
test_that("Image hash calculation is fast", {
  test_image <- test_path("fixtures/test_face.jpg")

  timing <- system.time({
    hash <- calculate_image_hash(test_image)
  })

  expect_lt(timing[["elapsed"]], 1.0)  # < 1 second
})
```

---

## Testing Anti-Patterns to Avoid

### ❌ Don't Test Implementation Details
```r
# BAD: Testing internal reactive values
test_that("reactive updates correctly", {
  testServer(mod_server, {
    expect_equal(internal_state(), "initial")  # DON'T TEST INTERNALS
  })
})

# GOOD: Test observable behavior
test_that("output reflects user input", {
  testServer(mod_server, {
    session$setInputs(name = "Test")
    expect_equal(output$greeting, "Hello, Test!")  # TEST OUTPUTS
  })
})
```

### ❌ Don't Create Brittle Tests
```r
# BAD: Hardcoded timestamps
expect_equal(result$timestamp, "2025-10-20 10:30:00")

# GOOD: Test timestamp properties
expect_true(lubridate::is.POSIXct(result$timestamp))
expect_true(result$timestamp <= Sys.time())
```

### ❌ Don't Test External Services Directly
```r
# BAD: Calling real APIs
test_that("Claude API works", {
  result <- call_claude_api(image, prompt)  # REAL API CALL
  expect_true(result$success)
})

# GOOD: Mock the API
test_that("Claude API call succeeds", {
  with_mocked_api({
    result <- call_claude_api(image, prompt)  # MOCKED
    expect_true(result$success)
  })
})
```

---

## Success Criteria

### Quantitative Metrics
- ✅ **70%+ code coverage** across all R files
- ✅ **100% module coverage** (all 11 modules have tests)
- ✅ **All critical paths tested** (auth, processing, export)
- ✅ **0 test failures** in CI pipeline
- ✅ **< 5 minutes** total test execution time

### Qualitative Metrics
- ✅ **Tests serve as documentation** (clear, readable)
- ✅ **Easy to add new tests** (good patterns established)
- ✅ **Catches regressions** (tests fail when behavior changes)
- ✅ **Developer confidence** (safe to refactor)

---

## Risks & Mitigations

### Risk 1: Time Investment
**Impact**: High
**Likelihood**: Certain
**Mitigation**:
- Phased approach allows incremental progress
- Start with highest-value tests (auth, database)
- Can deploy with partial coverage, improve over time

### Risk 2: Flaky Tests
**Impact**: Medium
**Likelihood**: Medium
**Mitigation**:
- Use stable mocks for external dependencies
- Avoid time-dependent assertions
- Use `withr` for clean test isolation
- Set appropriate timeouts for async operations

### Risk 3: Python Integration Complexity
**Impact**: Medium
**Likelihood**: Medium
**Mitigation**:
- Mock Python calls for unit tests
- Use real Python only for integration tests
- Skip Python tests if dependencies unavailable
- Document Python setup requirements

### Risk 4: Maintenance Burden
**Impact**: Low
**Likelihood**: Medium
**Mitigation**:
- Follow DRY principle with helper functions
- Use fixtures for shared test data
- Keep tests focused and simple
- Update tests alongside code changes

---

## Dependencies & Prerequisites

### R Packages (Add to DESCRIPTION Suggests)
```r
Suggests:
    testthat (>= 3.0.0),
    shinytest2,
    mockery,
    withr,
    chromote,
    covr
```

### System Requirements
- R >= 4.0.0
- Python 3.12+ (already present)
- Chrome/Chromium (for shinytest2)
- Git (for CI/CD)

### Knowledge Requirements
- Understanding of testthat framework
- Familiarity with Shiny reactive programming
- Basic mock/stub concepts
- CI/CD basics (GitHub Actions)

---

## Post-Implementation

### Monitoring
- Track test execution time (alert if > 5 min)
- Monitor coverage trends (alert if drops below 60%)
- Review test failures in CI (fix within 24 hours)

### Continuous Improvement
- Add tests when bugs are found (prevent regression)
- Refactor tests when patterns emerge
- Update documentation as patterns evolve
- Review and prune obsolete tests

### Team Adoption
- Require tests for all PRs
- Review test quality in code reviews
- Share testing best practices
- Celebrate improved coverage

---

## References

### Documentation
- [Golem Testing Guide](https://thinkr-open.github.io/golem/)
- [testthat Documentation](https://testthat.r-lib.org/)
- [shinytest2 Documentation](https://rstudio.github.io/shinytest2/)
- [Mastering Shiny - Testing](https://mastering-shiny.org/scaling-testing.html)

### Internal References
- Current tests: `tests/testthat/test-mod_postal_card_processor.R`
- Testing README: `tests/README.md`
- Architecture: `.serena/memories/tech_stack_and_architecture.md`
- Project overview: `.serena/memories/project_purpose_and_overview.md`

---

## Appendix: Test Count Estimate

| Category | Files | Est. Tests | Time |
|----------|-------|------------|------|
| Database Functions | 1 | 30-40 | 8 hrs |
| API Helpers | 2 | 15-20 | 6 hrs |
| Utilities | 3 | 10-15 | 4 hrs |
| **Modules** | 11 | 50-70 | 20 hrs |
| Integration | 1 | 8-12 | 8 hrs |
| **Total** | **18** | **113-157** | **46 hrs** |

**Estimated Timeline**: 4 weeks (1 developer @ 12 hrs/week)

---

## Next Steps

1. **Review this PRP** with stakeholders
2. **Get approval** to proceed
3. **Create implementation task** using `/prp` command
4. **Begin Phase 1** (Foundation setup)
5. **Iterate through phases** with regular check-ins

---

**END OF PRP**
