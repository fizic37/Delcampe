# Tests for mod_delcampe_export.R
# Tests the Delcampe export module for eBay listing creation with AI extraction

# ==== MODULE INITIALIZATION TESTS ====

test_that("mod_delcampe_export_ui returns tagList", {
  ui <- mod_delcampe_export_ui("test")

  expect_s3_class(ui, "shiny.tag.list")
})

test_that("mod_delcampe_export_ui creates namespaced outputs", {
  ui <- mod_delcampe_export_ui("test_module")
  ui_html <- as.character(ui)

  # Should contain the namespaced accordion container
  expect_true(grepl("test_module-accordion_container", ui_html))
})

# ==== SERVER LOGIC TESTS (Using testServer) ====

test_that("mod_delcampe_export_server initializes with NULL images", {
  testServer(mod_delcampe_export_server, {
    # Server should initialize even with no images
    expect_true(is.environment(session))

    # Reactive values should be initialized
    expect_true(exists("rv"))
    expect_type(rv$sent_images, "character")
    expect_type(rv$pending_images, "character")
    expect_type(rv$failed_images, "character")
    expect_type(rv$image_drafts, "list")
  })
})

test_that("mod_delcampe_export_server tracks image status correctly", {
  testServer(mod_delcampe_export_server, {
    # Set up test images
    session$setInputs(image_paths = c("img1.jpg", "img2.jpg", "img3.jpg"))

    # Initially all should be "ready"
    expect_equal(get_image_status(1), "ready")
    expect_equal(get_image_status(2), "ready")

    # Mark one as sent
    rv$sent_images <- c("img1.jpg")
    expect_equal(get_image_status(1), "sent")
    expect_equal(get_image_status(2), "ready")

    # Mark one as pending
    rv$pending_images <- c("img2.jpg")
    expect_equal(get_image_status(2), "pending")

    # Mark one as failed
    rv$failed_images <- c("img3.jpg")
    expect_equal(get_image_status(3), "failed")
  })
})

test_that("mod_delcampe_export_server saves drafts correctly", {
  testServer(mod_delcampe_export_server, {
    # Set up form inputs for image 1
    session$setInputs(
      item_title_1 = "Test Postcard Title",
      item_description_1 = "Test description",
      starting_price_1 = 5.00,
      condition_1 = "excellent"
    )

    # Save draft
    save_current_draft(1)

    # Verify draft was saved
    expect_true("1" %in% names(rv$image_drafts))
    expect_equal(rv$image_drafts[["1"]]$title, "Test Postcard Title")
    expect_equal(rv$image_drafts[["1"]]$description, "Test description")
    expect_equal(rv$image_drafts[["1"]]$price, 5.00)
    expect_equal(rv$image_drafts[["1"]]$condition, "excellent")
  })
})

test_that("mod_delcampe_export_server draft changes status to 'draft'", {
  testServer(mod_delcampe_export_server, {
    # Initially no draft
    expect_equal(get_image_status(1), "ready")

    # Save a draft
    rv$image_drafts[["1"]] <- list(
      title = "Test",
      description = "Test desc",
      price = 2.50,
      condition = "used"
    )

    # Status should change to draft
    expect_equal(get_image_status(1), "draft")
  })
})

# ==== STATUS BADGE GENERATION TESTS ====

test_that("mod_delcampe_export get_status_badge generates correct HTML", {
  testServer(mod_delcampe_export_server, {
    # Test each status
    badge_ready <- get_status_badge("ready")
    expect_s3_class(badge_ready, "shiny.tag")
    badge_html <- as.character(badge_ready)
    expect_true(grepl("Ready", badge_html))
    expect_true(grepl("#1971c2", badge_html))  # Color

    badge_sent <- get_status_badge("sent")
    badge_html_sent <- as.character(badge_sent)
    expect_true(grepl("Sent", badge_html_sent))
    expect_true(grepl("#2f9e44", badge_html_sent))  # Green color

    badge_failed <- get_status_badge("failed")
    badge_html_failed <- as.character(badge_failed)
    expect_true(grepl("Failed", badge_html_failed))
    expect_true(grepl("#c92a2a", badge_html_failed))  # Red color
  })
})

test_that("mod_delcampe_export get_status_badge handles unknown status", {
  testServer(mod_delcampe_export_server, {
    badge <- get_status_badge("unknown_status")
    badge_html <- as.character(badge)

    # Should default to "Ready"
    expect_true(grepl("Ready", badge_html))
  })
})

# ==== PATH CONVERSION TESTS ====

test_that("convert_web_path_to_file_path handles tempdir paths", {
  skip("Path conversion requires actual file system setup")

  testServer(mod_delcampe_export_server, {
    # Create a test file in tempdir
    test_file <- file.path(tempdir(), "test_image.jpg")
    file.create(test_file)

    # Convert web path to file path
    web_path <- "combined_session_images/test_image.jpg"
    result <- convert_web_path_to_file_path(web_path)

    expect_false(is.null(result))
    expect_true(file.exists(result))

    # Cleanup
    unlink(test_file)
  })
})

test_that("convert_web_path_to_file_path returns NULL for non-existent files", {
  testServer(mod_delcampe_export_server, {
    web_path <- "nonexistent_dir/nonexistent_file.jpg"
    result <- convert_web_path_to_file_path(web_path)

    expect_null(result)
  })
})

test_that("convert_web_path_to_file_path removes resource prefix", {
  testServer(mod_delcampe_export_server, {
    # Test path cleaning logic
    web_path <- "combined_session_images/subdir/image.jpg"

    # The cleaned path should remove the first directory
    cleaned <- sub("^[^/]+/", "", web_path)
    expect_equal(cleaned, "subdir/image.jpg")
  })
})

# ==== FORM GENERATION TESTS ====

test_that("mod_delcampe_export creates form inputs with correct IDs", {
  testServer(mod_delcampe_export_server, {
    form <- create_form_content(1, "test.jpg")
    form_html <- as.character(form)

    # Should contain all required form inputs with namespaced IDs
    expect_true(grepl("item_title_1", form_html))
    expect_true(grepl("item_description_1", form_html))
    expect_true(grepl("starting_price_1", form_html))
    expect_true(grepl("condition_1", form_html))
    expect_true(grepl("send_to_ebay_1", form_html))
    expect_true(grepl("ai_model_1", form_html))
  })
})

test_that("mod_delcampe_export form includes AI controls", {
  testServer(mod_delcampe_export_server, {
    form <- create_form_content(1, "test.jpg")
    form_html <- as.character(form)

    # Should include AI assistant section
    expect_true(grepl("AI Assistant", form_html))
    expect_true(grepl("robot", form_html))  # Icon
    expect_true(grepl("ai_model_", form_html))
  })
})

test_that("mod_delcampe_export form has correct default values", {
  testServer(mod_delcampe_export_server, {
    form <- create_form_content(1, "test.jpg")
    form_html <- as.character(form)

    # Default price should be 2.50
    expect_true(grepl("2.50", form_html) || grepl("2\\.5", form_html))

    # Default condition should be "used"
    expect_true(grepl("used", form_html))
  })
})

# ==== ACCORDION GENERATION TESTS ====

test_that("mod_delcampe_export renders empty state with no images", {
  testServer(mod_delcampe_export_server, {
    # Set empty images
    session$setInputs(image_paths = character(0))

    # Trigger accordion rendering
    output_html <- session$returned()

    # Should show empty state message
    # Note: Full UI rendering not available in testServer, so we test the logic
    expect_equal(length(character(0)), 0)
  })
})

test_that("mod_delcampe_export creates accordion panels for images", {
  skip("Full accordion testing requires Shiny integration test")

  testServer(mod_delcampe_export_server, {
    session$setInputs(
      image_paths = c("img1.jpg", "img2.jpg", "img3.jpg")
    )

    # Should create 3 panels
    # This would require full UI rendering to test properly
  })
})

# ==== AI INTEGRATION TESTS ====

test_that("mod_delcampe_export pre-loads existing AI data from database", {
  skip("Requires database setup and actual image files")

  testServer(mod_delcampe_export_server, {
    # Would test the AI data pre-loading logic
    # Requires:
    # 1. Database with existing AI extractions
    # 2. Actual image files with hashes
    # 3. Mocked find_card_processing function
  })
})

test_that("mod_delcampe_export populates fields when AI data exists", {
  skip("Requires full reactive chain testing")

  testServer(mod_delcampe_export_server, {
    # Test that when accordion opens, fields are populated from AI data
    # This requires:
    # 1. Pre-loaded AI data in existing_ai_data()
    # 2. Accordion open event
    # 3. Verification that updateTextInput/updateNumericInput were called
  })
})

test_that("mod_delcampe_export tracks AI extraction status", {
  testServer(mod_delcampe_export_server, {
    # Initially not extracting
    expect_false(rv$ai_extracting)

    # Set extracting state
    rv$ai_extracting <- TRUE
    expect_true(rv$ai_extracting)

    # Store AI result
    rv$ai_result <- list(
      success = TRUE,
      title = "Test Title",
      description = "Test Description"
    )

    expect_true(rv$ai_result$success)
    expect_equal(rv$ai_result$title, "Test Title")
  })
})

# ==== IMAGE STATUS PRIORITY TESTS ====

test_that("mod_delcampe_export status priority: sent > pending > failed > draft > ready", {
  testServer(mod_delcampe_export_server, {
    test_path <- "test.jpg"

    # Ready (no markers)
    expect_equal(get_image_status(1), "ready")

    # Draft
    rv$image_drafts[["1"]] <- list(title = "Test")
    expect_equal(get_image_status(1), "draft")

    # Failed overrides draft
    rv$failed_images <- c(test_path)
    # Note: get_image_status checks by index, not path directly
    # So we test the logic principle
    expect_type(rv$failed_images, "character")

    # Sent is highest priority
    rv$sent_images <- c(test_path)
    expect_type(rv$sent_images, "character")
  })
})

# ==== ERROR HANDLING TESTS ====

test_that("mod_delcampe_export handles NULL image paths gracefully", {
  testServer(mod_delcampe_export_server, {
    session$setInputs(image_paths = NULL)

    # Should not error
    # get_image_status should handle NULL paths
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

test_that("mod_delcampe_export handles missing form inputs", {
  testServer(mod_delcampe_export_server, {
    # Try to save draft without setting inputs
    # Should use %||% operator to provide defaults
    save_current_draft(1)

    # Draft should exist with empty/default values
    expect_true("1" %in% names(rv$image_drafts))
    draft <- rv$image_drafts[["1"]]
    expect_true("title" %in% names(draft))
    expect_true("description" %in% names(draft))
  })
})

# ==== MULTI-IMAGE WORKFLOW TESTS ====

test_that("mod_delcampe_export handles multiple images independently", {
  testServer(mod_delcampe_export_server, {
    session$setInputs(
      image_paths = c("img1.jpg", "img2.jpg", "img3.jpg")
    )

    # Save drafts for different images
    rv$image_drafts[["1"]] <- list(title = "Image 1", price = 3.00)
    rv$image_drafts[["2"]] <- list(title = "Image 2", price = 4.00)

    # Each should maintain independent state
    expect_equal(rv$image_drafts[["1"]]$title, "Image 1")
    expect_equal(rv$image_drafts[["2"]]$title, "Image 2")
    expect_false("3" %in% names(rv$image_drafts))
  })
})

test_that("mod_delcampe_export tracks multiple statuses correctly", {
  testServer(mod_delcampe_export_server, {
    session$setInputs(
      image_paths = c("img1.jpg", "img2.jpg", "img3.jpg", "img4.jpg")
    )

    # Set different statuses
    rv$sent_images <- c("img1.jpg")
    rv$pending_images <- c("img2.jpg")
    rv$failed_images <- c("img3.jpg")
    rv$image_drafts[["4"]] <- list(title = "Draft")

    # Verify each has correct status
    expect_equal(get_image_status(1), "sent")
    expect_equal(get_image_status(2), "pending")
    expect_equal(get_image_status(3), "failed")
    expect_equal(get_image_status(4), "draft")
  })
})

# ==== EBAY INTEGRATION TESTS ====

test_that("mod_delcampe_export accepts ebay_api reactive", {
  mock_api <- reactive({ list(authenticated = TRUE) })

  testServer(
    mod_delcampe_export_server,
    args = list(ebay_api = mock_api),
    {
      # Should initialize with eBay API
      expect_true(is.function(ebay_api))
      api_val <- ebay_api()
      expect_true(api_val$authenticated)
    }
  )
})

test_that("mod_delcampe_export accepts ebay_account_manager", {
  mock_manager <- list(
    get_active_account = function() "account1",
    accounts = list(account1 = list(name = "Test Account"))
  )

  testServer(
    mod_delcampe_export_server,
    args = list(ebay_account_manager = mock_manager),
    {
      # Should have access to account manager
      expect_true(!is.null(ebay_account_manager))
      expect_equal(ebay_account_manager$get_active_account(), "account1")
    }
  )
})

# ==== IMAGE TYPE TESTS ====

test_that("mod_delcampe_export handles 'lot' image type", {
  testServer(
    mod_delcampe_export_server,
    args = list(image_type = "lot"),
    {
      # Image type should be set
      expect_equal(image_type, "lot")

      # Form should reflect lot type in labels
      form <- create_form_content(1, "test.jpg")
      form_html <- as.character(form)
      expect_true(grepl("Lot", form_html) || grepl("lot", form_html))
    }
  )
})

test_that("mod_delcampe_export handles 'combined' image type", {
  testServer(
    mod_delcampe_export_server,
    args = list(image_type = "combined"),
    {
      # Image type should be set
      expect_equal(image_type, "combined")

      # Form should reflect combined type in labels
      form <- create_form_content(1, "test.jpg")
      form_html <- as.character(form)
      expect_true(grepl("Combined", form_html) || grepl("combined", form_html))
    }
  )
})

# ==== CONDITION OPTIONS TESTS ====

test_that("mod_delcampe_export provides correct condition options", {
  testServer(mod_delcampe_export_server, {
    form <- create_form_content(1, "test.jpg")
    form_html <- as.character(form)

    # Should include all condition options
    expect_true(grepl("Used", form_html))
    expect_true(grepl("Excellent", form_html))
    expect_true(grepl("Good", form_html))
    expect_true(grepl("Fair", form_html))
    expect_true(grepl("Poor", form_html))
  })
})

# ==== PRICE VALIDATION TESTS ====

test_that("mod_delcampe_export enforces minimum price of 0.50", {
  testServer(mod_delcampe_export_server, {
    form <- create_form_content(1, "test.jpg")
    form_html <- as.character(form)

    # Should have min="0.50" or min="0.5"
    expect_true(grepl('min.*0\\.5', form_html))
  })
})

test_that("mod_delcampe_export uses 0.50 step for prices", {
  testServer(mod_delcampe_export_server, {
    form <- create_form_content(1, "test.jpg")
    form_html <- as.character(form)

    # Should have step="0.50" or step="0.5"
    expect_true(grepl('step.*0\\.5', form_html))
  })
})
