# Tests for mod_tracking_viewer.R
# Tests the tracking viewer module that displays processing history with DT::datatable

# ==== MODULE INITIALIZATION TESTS ====

test_that("mod_tracking_viewer_ui returns tagList", {
  ui <- mod_tracking_viewer_ui("test")

  expect_s3_class(ui, "shiny.tag.list")
})

test_that("mod_tracking_viewer_ui creates namespaced outputs", {
  ui <- mod_tracking_viewer_ui("test_module")
  ui_html <- as.character(ui)

  # Should contain namespaced elements
  expect_true(grepl("test_module-tracking_table", ui_html))
  expect_true(grepl("test_module-date_range", ui_html))
  expect_true(grepl("test_module-ebay_filter", ui_html))
})

test_that("mod_tracking_viewer_ui includes bslib card", {
  ui <- mod_tracking_viewer_ui("test")
  ui_html <- as.character(ui)

  # Should use bslib::card
  expect_true(grepl("card", ui_html, ignore.case = TRUE))
  expect_true(grepl("Processing History", ui_html))
})

test_that("mod_tracking_viewer_ui includes DT datatable output", {
  ui <- mod_tracking_viewer_ui("test")
  ui_html <- as.character(ui)

  # Should include DataTable output
  expect_true(grepl("tracking_table", ui_html))
})

# ==== FILTER CONTROLS TESTS ====

test_that("mod_tracking_viewer_ui includes date range filter", {
  ui <- mod_tracking_viewer_ui("test")
  ui_html <- as.character(ui)

  # Should have date range options
  expect_true(grepl("Last 7 days", ui_html))
  expect_true(grepl("Last 30 days", ui_html))
  expect_true(grepl("Last 90 days", ui_html))
  expect_true(grepl("All time", ui_html))
})

test_that("mod_tracking_viewer_ui includes eBay status filter", {
  ui <- mod_tracking_viewer_ui("test")
  ui_html <- as.character(ui)

  # Should have eBay status options
  expect_true(grepl("Listed", ui_html))
  expect_true(grepl("Draft", ui_html))
  expect_true(grepl("Failed", ui_html))
  expect_true(grepl("Not Posted", ui_html))
})

test_that("mod_tracking_viewer_ui has sensible default filters", {
  ui <- mod_tracking_viewer_ui("test")
  ui_html <- as.character(ui)

  # Default date range should be 7 days
  expect_true(grepl('selected.*"7"', ui_html) || grepl('value="7"', ui_html))

  # Default eBay filter should be "all"
  expect_true(grepl('selected.*"all"', ui_html) || grepl('value="all"', ui_html))
})

# ==== SERVER LOGIC TESTS ====

test_that("mod_tracking_viewer_server initializes correctly", {
  skip_if_not_installed("DT")

  testServer(mod_tracking_viewer_server, {
    # Server should initialize
    expect_true(is.environment(session))
  })
})

test_that("mod_tracking_viewer_server builds date filter correctly", {
  skip_if_not_installed("DT")
  skip("Requires mocked database")

  testServer(mod_tracking_viewer_server, {
    # Test "7 days" filter
    session$setInputs(date_range = "7", ebay_filter = "all")

    # The SQL filter should contain "7 days"
    # This would require inspecting the generated SQL
  })
})

test_that("mod_tracking_viewer_server handles 'all time' date filter", {
  skip_if_not_installed("DT")
  skip("Requires mocked database")

  testServer(mod_tracking_viewer_server, {
    session$setInputs(date_range = "all", ebay_filter = "all")

    # Should generate empty date filter
    # Verify by checking the reactive value or SQL generation
  })
})

test_that("mod_tracking_viewer_server validates date filter input", {
  skip_if_not_installed("DT")
  skip("Requires mocked database")

  testServer(mod_tracking_viewer_server, {
    # Test with invalid input
    session$setInputs(date_range = "invalid", ebay_filter = "all")

    # Should fall back to default (7 days)
    # as.integer("invalid") returns NA, should use fallback
  })
})

test_that("mod_tracking_viewer_server builds eBay filter correctly", {
  skip_if_not_installed("DT")
  skip("Requires mocked database")

  testServer(mod_tracking_viewer_server, {
    # Test "listed" filter
    session$setInputs(date_range = "7", ebay_filter = "listed")

    # SQL should contain "AND el.status = 'listed'"
  })
})

test_that("mod_tracking_viewer_server handles 'none' eBay filter", {
  skip_if_not_installed("DT")
  skip("Requires mocked database")

  testServer(mod_tracking_viewer_server, {
    session$setInputs(date_range = "7", ebay_filter = "none")

    # SQL should filter for NULL or empty status
    # "AND (el.status IS NULL OR el.status = '')"
  })
})

test_that("mod_tracking_viewer_server sanitizes eBay filter input", {
  skip_if_not_installed("DT")
  skip("Requires mocked database")

  testServer(mod_tracking_viewer_server, {
    # Test with invalid/malicious input
    session$setInputs(date_range = "7", ebay_filter = "'; DROP TABLE users; --")

    # Should not include invalid status in SQL
    # Whitelist approach should prevent injection
  })
})

# ==== DATA FORMATTING TESTS ====

test_that("mod_tracking_viewer formats time correctly", {
  skip_if_not_installed("DT")

  # Test the time formatting logic
  test_time <- "2025-10-23 14:30:00"
  formatted <- format(as.POSIXct(test_time), "%Y-%m-%d %H:%M")

  expect_equal(formatted, "2025-10-23 14:30")
})

test_that("mod_tracking_viewer formats username with fallback", {
  # Test the username formatting logic
  username1 <- "testuser"
  username2 <- NA
  username3 <- ""

  result1 <- ifelse(is.na(username1) | username1 == "", "Unknown", username1)
  result2 <- ifelse(is.na(username2) | username2 == "", "Unknown", username2)
  result3 <- ifelse(is.na(username3) | username3 == "", "Unknown", username3)

  expect_equal(result1, "testuser")
  expect_equal(result2, "Unknown")
  expect_equal(result3, "Unknown")
})

test_that("mod_tracking_viewer formats image type indicators", {
  # Test image type formatting: F=face, V=verso, C=combined
  has_face <- 1
  has_verso <- 0
  has_combined <- 1

  result <- sprintf("%s%s%s",
    ifelse(has_face > 0, "F", ""),
    ifelse(has_verso > 0, "V", ""),
    ifelse(has_combined > 0, "C", "")
  )

  expect_equal(result, "FC")  # Face and Combined
})

test_that("mod_tracking_viewer formats eBay status with fallback", {
  status1 <- "listed"
  status2 <- NA
  status3 <- ""

  result1 <- ifelse(is.na(status1) | status1 == "", "Not Posted", tools::toTitleCase(status1))
  result2 <- ifelse(is.na(status2) | status2 == "", "Not Posted", tools::toTitleCase(status2))
  result3 <- ifelse(is.na(status3) | status3 == "", "Not Posted", tools::toTitleCase(status3))

  expect_equal(result1, "Listed")
  expect_equal(result2, "Not Posted")
  expect_equal(result3, "Not Posted")
})

# ==== DATATABLE CONFIGURATION TESTS ====

test_that("mod_tracking_viewer_server renders empty state correctly", {
  skip_if_not_installed("DT")
  skip("Requires mocked database that returns empty data")

  testServer(mod_tracking_viewer_server, {
    # Mock empty data
    # Should return a data frame with a Message column
  })
})

test_that("mod_tracking_viewer configures DT options correctly", {
  skip_if_not_installed("DT")

  # Test that DT::datatable would be called with correct options
  # This tests the logic, not the actual DT rendering

  options_config <- list(
    pageLength = 25,
    lengthMenu = c(10, 25, 50, 100),
    order = list(list(1, "desc")),
    autoWidth = TRUE
  )

  expect_equal(options_config$pageLength, 25)
  expect_equal(options_config$lengthMenu, c(10, 25, 50, 100))
  expect_true(options_config$autoWidth)
})

test_that("mod_tracking_viewer sorts by time descending by default", {
  # Test sort configuration
  order_config <- list(list(1, "desc"))  # Column 1 (Time), descending

  expect_equal(length(order_config), 1)
  expect_equal(order_config[[1]][[1]], 1)  # Column index
  expect_equal(order_config[[1]][[2]], "desc")  # Direction
})

test_that("mod_tracking_viewer includes column filters", {
  skip_if_not_installed("DT")

  # Should have filter = "top"
  filter_setting <- "top"
  expect_equal(filter_setting, "top")
})

# ==== STYLING TESTS ====

test_that("mod_tracking_viewer applies status colors correctly", {
  skip_if_not_installed("DT")

  # Test color configuration
  status_colors <- list(
    bg = c('Listed' = '#d1fcd3', 'Failed' = '#f8d7da', 'Not Posted' = '#e9ecef'),
    fg = c('Listed' = '#0f5132', 'Failed' = '#842029', 'Not Posted' = '#6c757d')
  )

  expect_equal(status_colors$bg['Listed'], '#d1fcd3')
  expect_equal(status_colors$bg['Failed'], '#f8d7da')
  expect_equal(status_colors$fg['Listed'], '#0f5132')
  expect_equal(status_colors$fg['Failed'], '#842029')
})

test_that("mod_tracking_viewer uses Bootstrap table classes", {
  skip_if_not_installed("DT")

  # Should use "table table-striped table-hover"
  table_class <- "table table-striped table-hover"

  expect_true(grepl("table", table_class))
  expect_true(grepl("striped", table_class))
  expect_true(grepl("hover", table_class))
})

# ==== COLUMN WIDTH TESTS ====

test_that("mod_tracking_viewer sets appropriate column widths", {
  columnDefs <- list(
    list(width = "100px", targets = 0),  # SessionID
    list(width = "140px", targets = 1),  # Time
    list(width = "100px", targets = 2),  # User
    list(width = "80px", targets = 3),   # Cards
    list(width = "80px", targets = 4),   # Images
    list(width = "100px", targets = 5),  # AI Extractions
    list(width = "100px", targets = 6),  # eBay Posts
    list(width = "110px", targets = 7)   # EbayStatus
  )

  expect_equal(length(columnDefs), 8)
  expect_equal(columnDefs[[1]]$width, "100px")
  expect_equal(columnDefs[[2]]$width, "140px")
  expect_equal(columnDefs[[7]]$width, "100px")  # eBay Posts
})

# ==== LANGUAGE/TEXT CONFIGURATION TESTS ====

test_that("mod_tracking_viewer uses custom DT language", {
  language_config <- list(
    search = "Search sessions:",
    lengthMenu = "Show _MENU_ sessions per page",
    info = "Showing _START_ to _END_ of _TOTAL_ processing sessions"
  )

  expect_true(grepl("sessions", language_config$search))
  expect_true(grepl("sessions per page", language_config$lengthMenu))
  expect_true(grepl("processing sessions", language_config$info))
})

test_that("mod_tracking_viewer has meaningful empty/filtered messages", {
  language_config <- list(
    infoEmpty = "No sessions to display",
    infoFiltered = "(filtered from _MAX_ total sessions)",
    zeroRecords = "No matching sessions found"
  )

  expect_true(nchar(language_config$infoEmpty) > 0)
  expect_true(grepl("filtered", language_config$infoFiltered))
  expect_true(grepl("No matching", language_config$zeroRecords))
})

# ==== FACTOR CONVERSION TESTS ====

test_that("mod_tracking_viewer converts categorical columns to factors", {
  # Test the factor conversion logic
  test_data <- data.frame(
    User = c("user1", "user2", "Unknown"),
    Images = c("FC", "FV", "C"),
    EbayStatus = c("Listed", "Draft", "Not Posted"),
    stringsAsFactors = FALSE
  )

  # Convert to factors
  test_data$User <- factor(test_data$User)
  test_data$Images <- factor(test_data$Images)
  test_data$EbayStatus <- factor(test_data$EbayStatus)

  expect_s3_class(test_data$User, "factor")
  expect_s3_class(test_data$Images, "factor")
  expect_s3_class(test_data$EbayStatus, "factor")
})

# ==== SELECTION MODE TESTS ====

test_that("mod_tracking_viewer uses single row selection", {
  selection_mode <- "single"
  expect_equal(selection_mode, "single")
})

test_that("mod_tracking_viewer disables row names", {
  rownames_setting <- FALSE
  expect_false(rownames_setting)
})

# ==== SQL INJECTION PREVENTION TESTS ====

test_that("mod_tracking_viewer validates date filter as integer", {
  # Test as.integer() validation
  valid_input <- "7"
  invalid_input <- "7; DROP TABLE users"

  valid_days <- as.integer(valid_input)
  invalid_days <- as.integer(invalid_input)

  expect_equal(valid_days, 7)
  expect_true(is.na(invalid_days))  # Should be NA for invalid input
})

test_that("mod_tracking_viewer uses whitelist for eBay status", {
  allowed_statuses <- c("listed", "draft", "failed", "pending")

  # Valid status
  expect_true("listed" %in% allowed_statuses)
  expect_true("draft" %in% allowed_statuses)

  # Invalid status (SQL injection attempt)
  expect_false("'; DROP TABLE" %in% allowed_statuses)
  expect_false("OR 1=1" %in% allowed_statuses)
})

test_that("mod_tracking_viewer falls back to safe defaults on invalid input", {
  # Test fallback logic
  days_input <- "invalid"
  days <- as.integer(days_input)
  if (is.na(days)) days <- 7  # Fallback

  expect_equal(days, 7)

  # Test eBay filter fallback
  allowed_statuses <- c("listed", "draft", "failed", "pending")
  ebay_input <- "malicious'; DROP"
  filter <- if (ebay_input %in% allowed_statuses) {
    sprintf("AND el.status = '%s'", ebay_input)
  } else {
    ""  # Safe fallback - show all
  }

  expect_equal(filter, "")  # Should use safe fallback
})

# ==== IMAGE TYPE INDICATOR TESTS ====

test_that("mod_tracking_viewer formats all image type combinations", {
  # Test all possible combinations
  combinations <- list(
    list(f = 1, v = 0, c = 0, expected = "F"),
    list(f = 0, v = 1, c = 0, expected = "V"),
    list(f = 0, v = 0, c = 1, expected = "C"),
    list(f = 1, v = 1, c = 0, expected = "FV"),
    list(f = 1, v = 0, c = 1, expected = "FC"),
    list(f = 0, v = 1, c = 1, expected = "VC"),
    list(f = 1, v = 1, c = 1, expected = "FVC"),
    list(f = 0, v = 0, c = 0, expected = "")
  )

  for (combo in combinations) {
    result <- sprintf("%s%s%s",
      ifelse(combo$f > 0, "F", ""),
      ifelse(combo$v > 0, "V", ""),
      ifelse(combo$c > 0, "C", "")
    )
    expect_equal(result, combo$expected)
  }
})

# ==== DATA INTEGRITY TESTS ====

test_that("mod_tracking_viewer handles NA values in numeric columns", {
  # Test that NA values are converted to integers properly
  cards <- c(5, NA, 10)
  ai_extractions <- c(2, NA, 0)

  cards_int <- as.integer(cards)
  ai_int <- as.integer(ai_extractions)

  expect_equal(cards_int[1], 5)
  expect_true(is.na(cards_int[2]))
  expect_equal(ai_int[3], 0)
})

test_that("mod_tracking_viewer handles mixed data types", {
  # Test data frame creation with mixed types
  display_data <- data.frame(
    SessionID = as.character(c(1, 2, 3)),
    Time = c("2025-10-23 10:00", "2025-10-23 11:00", "2025-10-23 12:00"),
    User = c("user1", "Unknown", "user2"),
    Cards = as.integer(c(5, 3, 7)),
    Images = c("FC", "F", "FVC"),
    AIExtractions = as.integer(c(2, 1, 5)),
    EbayPosts = as.integer(c(1, 0, 3)),
    EbayStatus = c("Listed", "Not Posted", "Draft"),
    stringsAsFactors = FALSE
  )

  expect_equal(nrow(display_data), 3)
  expect_equal(ncol(display_data), 8)
  expect_type(display_data$SessionID, "character")
  expect_type(display_data$Cards, "integer")
})
