# Testing Patterns for Shiny Modules

This document provides comprehensive patterns and examples for testing Shiny modules in the Delcampe project.

---

## Table of Contents

1. [Basic Module Testing Pattern](#basic-module-testing-pattern)
2. [UI Testing Patterns](#ui-testing-patterns)
3. [Server Logic Testing with testServer](#server-logic-testing-with-testserver)
4. [Testing Reactive Values](#testing-reactive-values)
5. [Testing Complex Forms](#testing-complex-forms)
6. [Testing Database Integration](#testing-database-integration)
7. [Testing API Integration](#testing-api-integration)
8. [Testing Multi-Module Communication](#testing-multi-module-communication)
9. [Common Pitfalls and Solutions](#common-pitfalls-and-solutions)

---

## Basic Module Testing Pattern

Every module test file should follow this structure:

```r
# Tests for mod_your_module.R
# Brief description of what this module does

# ==== MODULE INITIALIZATION TESTS ====

test_that("mod_your_module_ui returns tagList", {
  ui <- mod_your_module_ui("test")

  expect_s3_class(ui, "shiny.tag.list")
})

test_that("mod_your_module_ui creates namespaced outputs", {
  ui <- mod_your_module_ui("test_module")
  ui_html <- as.character(ui)

  # Check for key namespaced elements
  expect_true(grepl("test_module-key_output", ui_html))
})

# ==== SERVER LOGIC TESTS ====

test_that("mod_your_module_server initializes correctly", {
  testServer(mod_your_module_server, {
    # Test initialization
    expect_true(is.environment(session))
    # Test reactive values initialization
    expect_true(exists("rv"))
  })
})
```

---

## UI Testing Patterns

### Pattern 1: Test UI Structure

```r
test_that("module UI includes required elements", {
  ui <- mod_your_module_ui("test")
  ui_html <- as.character(ui)

  # Check for specific UI elements
  expect_true(grepl("button_id", ui_html))
  expect_true(grepl("input_id", ui_html))
  expect_true(grepl("output_id", ui_html))
})
```

### Pattern 2: Test UI Component Types

```r
test_that("module uses bslib components correctly", {
  ui <- mod_your_module_ui("test")
  ui_html <- as.character(ui)

  # Check for bslib card
  expect_true(grepl("card", ui_html, ignore.case = TRUE))

  # Check for accordion
  expect_true(grepl("accordion", ui_html, ignore.case = TRUE))
})
```

### Pattern 3: Test Default Values

```r
test_that("form inputs have correct defaults", {
  ui <- mod_your_module_ui("test")
  ui_html <- as.character(ui)

  # Check default values
  expect_true(grepl('value="default_value"', ui_html))
  expect_true(grepl('selected="option1"', ui_html))
})
```

**Example from mod_delcampe_export.R:**

```r
test_that("mod_delcampe_export form has correct default values", {
  testServer(mod_delcampe_export_server, {
    form <- create_form_content(1, "test.jpg")
    form_html <- as.character(form)

    # Default price should be 2.50
    expect_true(grepl("2.50", form_html))

    # Default condition should be "used"
    expect_true(grepl("used", form_html))
  })
})
```

---

## Server Logic Testing with testServer

### Pattern 1: Testing Reactive Values

```r
test_that("module tracks state correctly", {
  testServer(mod_your_module_server, {
    # Initialize state
    rv$counter <- 0

    # Trigger action
    rv$counter <- rv$counter + 1

    # Verify state change
    expect_equal(rv$counter, 1)
  })
})
```

### Pattern 2: Testing with Input Changes

```r
test_that("module responds to input changes", {
  testServer(mod_your_module_server, {
    # Set inputs
    session$setInputs(
      text_input = "test value",
      numeric_input = 42
    )

    # Verify module processed inputs
    expect_equal(input$text_input, "test value")
    expect_equal(input$numeric_input, 42)
  })
})
```

### Pattern 3: Testing Functions Within Modules

```r
test_that("helper function produces correct output", {
  testServer(mod_your_module_server, {
    # Call module's internal function
    result <- helper_function("input")

    # Verify output
    expect_equal(result, "expected output")
  })
})
```

**Example from mod_delcampe_export.R:**

```r
test_that("mod_delcampe_export get_status_badge generates correct HTML", {
  testServer(mod_delcampe_export_server, {
    badge_ready <- get_status_badge("ready")
    expect_s3_class(badge_ready, "shiny.tag")

    badge_html <- as.character(badge_ready)
    expect_true(grepl("Ready", badge_html))
    expect_true(grepl("#1971c2", badge_html))  # Color check
  })
})
```

---

## Testing Reactive Values

### Pattern 1: State Management

```r
test_that("module manages multiple state variables", {
  testServer(mod_your_module_server, {
    # Verify initial state
    expect_length(rv$items, 0)
    expect_false(rv$processing)

    # Change state
    rv$items <- c("item1", "item2")
    rv$processing <- TRUE

    # Verify state changes
    expect_length(rv$items, 2)
    expect_true(rv$processing)
  })
})
```

### Pattern 2: Status Tracking

```r
test_that("module tracks item status correctly", {
  testServer(mod_your_module_server, {
    # Set up items with different statuses
    rv$completed <- c("item1")
    rv$pending <- c("item2")
    rv$failed <- c("item3")

    # Test status lookup function
    expect_equal(get_status("item1"), "completed")
    expect_equal(get_status("item2"), "pending")
    expect_equal(get_status("item3"), "failed")
    expect_equal(get_status("item4"), "unknown")
  })
})
```

**Example from mod_delcampe_export.R:**

```r
test_that("mod_delcampe_export tracks image status correctly", {
  testServer(mod_delcampe_export_server, {
    session$setInputs(image_paths = c("img1.jpg", "img2.jpg", "img3.jpg"))

    # Mark images with different statuses
    rv$sent_images <- c("img1.jpg")
    rv$pending_images <- c("img2.jpg")
    rv$failed_images <- c("img3.jpg")

    # Verify status tracking
    expect_equal(get_image_status(1), "sent")
    expect_equal(get_image_status(2), "pending")
    expect_equal(get_image_status(3), "failed")
  })
})
```

---

## Testing Complex Forms

### Pattern 1: Form Data Saving

```r
test_that("module saves form data correctly", {
  testServer(mod_your_module_server, {
    # Set form inputs
    session$setInputs(
      title = "Test Title",
      description = "Test Description",
      price = 10.00,
      category = "Category A"
    )

    # Trigger save
    save_form_data()

    # Verify data was saved
    expect_true("1" %in% names(rv$saved_forms))
    expect_equal(rv$saved_forms[["1"]]$title, "Test Title")
    expect_equal(rv$saved_forms[["1"]]$price, 10.00)
  })
})
```

### Pattern 2: Form Validation

```r
test_that("module validates required fields", {
  testServer(mod_your_module_server, {
    # Set invalid inputs
    session$setInputs(
      title = "",  # Required but empty
      price = -5   # Invalid price
    )

    # Check validation
    validation_result <- validate_form()
    expect_false(validation_result$valid)
    expect_true(grepl("title", validation_result$errors))
    expect_true(grepl("price", validation_result$errors))
  })
})
```

**Example from mod_delcampe_export.R:**

```r
test_that("mod_delcampe_export saves drafts correctly", {
  testServer(mod_delcampe_export_server, {
    session$setInputs(
      item_title_1 = "Test Postcard Title",
      item_description_1 = "Test description",
      starting_price_1 = 5.00,
      condition_1 = "excellent"
    )

    save_current_draft(1)

    expect_true("1" %in% names(rv$image_drafts))
    expect_equal(rv$image_drafts[["1"]]$title, "Test Postcard Title")
    expect_equal(rv$image_drafts[["1"]]$price, 5.00)
  })
})
```

---

## Testing Database Integration

### Pattern 1: Using with_test_db Wrapper

```r
test_that("module reads from database correctly", {
  with_test_db({
    # Create test data
    card <- get_or_create_card(db, "test_hash")

    # Test module function that reads from DB
    result <- get_card_data(db, card$card_id)

    expect_equal(result$image_hash, "test_hash")
  })
})
```

### Pattern 2: Testing Database Writes

```r
test_that("module writes to database correctly", {
  with_test_db({
    # Perform write operation
    save_result <- save_to_database(
      db,
      title = "Test",
      description = "Test Description"
    )

    expect_true(save_result$success)

    # Verify write with query
    row <- DBI::dbGetQuery(db,
      "SELECT * FROM table WHERE title = ?",
      params = list("Test")
    )
    expect_equal(nrow(row), 1)
    expect_equal(row$description, "Test Description")
  })
})
```

### Pattern 3: Testing Complex Queries

```r
test_that("module handles database queries with filters", {
  with_test_db({
    # Create test data
    create_test_session(db, user_id = 1)
    create_test_session(db, user_id = 2)

    # Test filtered query
    results <- get_sessions_by_user(db, user_id = 1)

    expect_equal(nrow(results), 1)
    expect_equal(results$user_id[1], 1)
  })
})
```

---

## Testing API Integration

### Pattern 1: Using Mock Responses

```r
test_that("module handles API success response", {
  skip("Requires API mocking")

  testServer(mod_your_module_server, {
    # with_mocked_api({
    #   result <- call_api(param1, param2)
    #
    #   expect_true(result$success)
    #   expect_type(result$data, "list")
    # })
  })
})
```

### Pattern 2: Testing Error Handling

```r
test_that("module handles API errors gracefully", {
  skip("Requires API error mocking")

  testServer(mod_your_module_server, {
    # with_mocked_api_error({
    #   result <- call_api(param1, param2)
    #
    #   expect_false(result$success)
    #   expect_true("error" %in% names(result))
    # })
  })
})
```

---

## Testing Multi-Module Communication

### Pattern 1: Testing Reactive Parameters

```r
test_that("module accepts and uses reactive parameters", {
  mock_data <- reactive({ c("item1", "item2") })

  testServer(
    mod_your_module_server,
    args = list(input_data = mock_data),
    {
      # Module should have access to reactive data
      expect_true(is.function(input_data))
      data_val <- input_data()
      expect_length(data_val, 2)
    }
  )
})
```

### Pattern 2: Testing Return Values

```r
test_that("module returns reactive values for other modules", {
  testServer(mod_your_module_server, {
    # Set up state that module should return
    rv$selected_item <- "item1"
    rv$status <- "complete"

    # Get module's return value
    returned <- session$returned()

    # Verify return structure
    expect_true(is.reactive(returned$selected))
    expect_equal(returned$selected(), "item1")
  })
})
```

**Example from mod_delcampe_export.R:**

```r
test_that("mod_delcampe_export accepts ebay_api reactive", {
  mock_api <- reactive({ list(authenticated = TRUE) })

  testServer(
    mod_delcampe_export_server,
    args = list(ebay_api = mock_api),
    {
      expect_true(is.function(ebay_api))
      api_val <- ebay_api()
      expect_true(api_val$authenticated)
    }
  )
})
```

---

## Common Pitfalls and Solutions

### Pitfall 1: Testing Full UI Rendering

**Problem:** Trying to test complete UI rendering with testServer

```r
# ❌ DON'T DO THIS
test_that("accordion renders correctly", {
  testServer(mod_your_module_server, {
    # Can't actually test full UI rendering here
    output <- output$accordion_container
  })
})
```

**Solution:** Test UI generation logic, not rendering

```r
# ✅ DO THIS
test_that("accordion panels are created for each item", {
  testServer(mod_your_module_server, {
    session$setInputs(items = c("item1", "item2", "item3"))

    # Test that panel creation function works
    panel <- create_accordion_panel(1, "item1")
    expect_s3_class(panel, "shiny.tag")
  })
})
```

### Pitfall 2: Not Using skip() for Integration Tests

**Problem:** Tests that require full setup always run and fail

```r
# ❌ DON'T DO THIS
test_that("full workflow works", {
  # This requires database, API, file system, etc.
  result <- complex_workflow()
  expect_true(result$success)
})
```

**Solution:** Use skip() with explanatory message

```r
# ✅ DO THIS
test_that("full workflow works", {
  skip("Requires full integration: database + API + file system")

  # Test code here
  # Will be skipped in normal test runs
  # Can be enabled for integration testing
})
```

### Pitfall 3: Not Testing Edge Cases

**Problem:** Only testing happy path

```r
# ❌ DON'T DO THIS - only tests valid input
test_that("function works", {
  result <- my_function("valid_input")
  expect_equal(result, "expected_output")
})
```

**Solution:** Test edge cases and error conditions

```r
# ✅ DO THIS
test_that("function handles NULL input", {
  result <- my_function(NULL)
  expect_equal(result, default_value)
})

test_that("function handles empty input", {
  result <- my_function("")
  expect_equal(result, default_value)
})

test_that("function handles out of bounds", {
  result <- my_function(9999)
  expect_equal(result, fallback_value)
})
```

**Example from mod_delcampe_export.R:**

```r
test_that("mod_delcampe_export handles NULL image paths gracefully", {
  testServer(mod_delcampe_export_server, {
    session$setInputs(image_paths = NULL)

    # Should not error
    status <- get_image_status(1)
    expect_equal(status, "ready")
  })
})

test_that("mod_delcampe_export handles out of bounds index", {
  testServer(mod_delcampe_export_server, {
    session$setInputs(image_paths = c("img1.jpg", "img2.jpg"))

    # Request status for index 10 (out of bounds)
    status <- get_image_status(10)
    expect_equal(status, "ready")
  })
})
```

---

## Test Organization Best Practices

### 1. Group Related Tests

```r
# ==== INITIALIZATION TESTS ====
test_that("module initializes...", { })
test_that("module creates...", { })

# ==== STATUS MANAGEMENT TESTS ====
test_that("module tracks status...", { })
test_that("module updates status...", { })

# ==== ERROR HANDLING TESTS ====
test_that("module handles NULL...", { })
test_that("module handles invalid...", { })
```

### 2. Use Descriptive Test Names

```r
# ❌ BAD
test_that("it works", { })
test_that("test 1", { })

# ✅ GOOD
test_that("module saves form data with all required fields", { })
test_that("get_status_badge generates correct HTML for 'sent' status", { })
```

### 3. One Assertion Per Concept

```r
# ✅ GOOD - each test has clear focus
test_that("badge has correct text", {
  expect_true(grepl("Ready", badge_html))
})

test_that("badge has correct color", {
  expect_true(grepl("#1971c2", badge_html))
})
```

---

## Summary Checklist

For each new module, ensure tests cover:

- ✅ UI initialization and structure
- ✅ Server initialization and reactive values
- ✅ Form data handling (if applicable)
- ✅ Status tracking (if applicable)
- ✅ Database integration (if applicable)
- ✅ API integration (if applicable)
- ✅ Error handling and edge cases
- ✅ NULL/empty/invalid input handling
- ✅ Multi-module communication (if applicable)

---

**Remember:** Good tests are:
- **Fast** - Run in milliseconds
- **Independent** - Don't depend on other tests
- **Repeatable** - Same result every time
- **Self-validating** - Pass or fail clearly
- **Timely** - Written alongside code

---

**For More Information:**
- Golem testing guide: https://thinkr-open.github.io/golem/articles/c_deploy.html#testing
- testthat documentation: https://testthat.r-lib.org/
- Shiny testServer: https://shiny.posit.co/r/reference/shiny/latest/testserver
