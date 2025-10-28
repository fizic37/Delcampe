# Tests for eBay Trading API Implementation
# Testing XML-based Trading API for cross-border seller support

# ==== SETUP ====

test_that("EbayTradingAPI class initializes correctly", {
  mock_oauth <- list(get_access_token = function() "test_token")
  mock_config <- list(environment = "sandbox")

  trading_api <- EbayTradingAPI$new(mock_oauth, mock_config)

  expect_s3_class(trading_api, "EbayTradingAPI")
  expect_s3_class(trading_api, "R6")
})

# ==== XML BUILDER TESTS ====

test_that("build_add_item_xml generates valid XML structure", {
  mock_oauth <- list(get_access_token = function() "test_token")
  mock_config <- list(environment = "sandbox")

  trading_api <- EbayTradingAPI$new(mock_oauth, mock_config)

  item_data <- list(
    title = "Test Postcard",
    description = "Test description",
    country = "RO",
    location = "Bucharest",
    category_id = 262042,
    price = "6.50",
    condition_id = 3000,
    quantity = 1,
    images = list("https://example.com/image.jpg"),
    aspects = list(Type = "Postcard", Era = "1920s")
  )

  # Access private method via R6 environment
  xml <- trading_api$.__enclos_env__$private$build_add_item_xml(item_data)

  expect_type(xml, "character")
  expect_true(grepl("<AddFixedPriceItemRequest", xml, fixed = TRUE))
  expect_true(grepl("<Country>RO</Country>", xml, fixed = TRUE))
  expect_true(grepl("<Title>Test Postcard</Title>", xml, fixed = TRUE))
  expect_true(grepl("<eBayAuthToken>test_token</eBayAuthToken>", xml, fixed = TRUE))
  expect_true(grepl("<ConditionID>3000</ConditionID>", xml, fixed = TRUE))
})

test_that("build_add_item_xml handles multiple images", {
  mock_oauth <- list(get_access_token = function() "test_token")
  mock_config <- list(environment = "sandbox")

  trading_api <- EbayTradingAPI$new(mock_oauth, mock_config)

  item_data <- list(
    title = "Test",
    description = "Test",
    country = "RO",
    location = "Bucharest",
    category_id = 262042,
    price = "6.50",
    condition_id = 3000,
    quantity = 1,
    images = list("https://example.com/img1.jpg", "https://example.com/img2.jpg"),
    aspects = list()
  )

  xml <- trading_api$.__enclos_env__$private$build_add_item_xml(item_data)

  expect_true(grepl("<PictureURL>https://example.com/img1.jpg</PictureURL>", xml, fixed = TRUE))
  expect_true(grepl("<PictureURL>https://example.com/img2.jpg</PictureURL>", xml, fixed = TRUE))
})

test_that("build_add_item_xml handles aspects correctly", {
  mock_oauth <- list(get_access_token = function() "test_token")
  mock_config <- list(environment = "sandbox")

  trading_api <- EbayTradingAPI$new(mock_oauth, mock_config)

  item_data <- list(
    title = "Test",
    description = "Test",
    country = "RO",
    location = "Bucharest",
    category_id = 262042,
    price = "6.50",
    condition_id = 3000,
    quantity = 1,
    images = list("https://example.com/img.jpg"),
    aspects = list(
      Type = "Postcard",
      Era = "1920s",
      Color = "Sepia"
    )
  )

  xml <- trading_api$.__enclos_env__$private$build_add_item_xml(item_data)

  expect_true(grepl("<ItemSpecifics>", xml, fixed = TRUE))
  expect_true(grepl("<Name>Type</Name>", xml, fixed = TRUE))
  expect_true(grepl("<Value>Postcard</Value>", xml, fixed = TRUE))
  expect_true(grepl("<Name>Era</Name>", xml, fixed = TRUE))
  expect_true(grepl("<Value>1920s</Value>", xml, fixed = TRUE))
})

# ==== XML PARSER TESTS ====

test_that("parse_response handles success response", {
  mock_oauth <- list(get_access_token = function() "test")
  mock_config <- list(environment = "sandbox")

  trading_api <- EbayTradingAPI$new(mock_oauth, mock_config)

  success_xml <- '<?xml version="1.0"?>
    <AddFixedPriceItemResponse xmlns="urn:ebay:apis:eBLBaseComponents">
      <Ack>Success</Ack>
      <ItemID>123456789</ItemID>
    </AddFixedPriceItemResponse>'

  result <- trading_api$.__enclos_env__$private$parse_response(success_xml)

  expect_true(result$success)
  expect_equal(result$item_id, "123456789")
  expect_null(result$warnings)
})

test_that("parse_response handles warning response", {
  mock_oauth <- list(get_access_token = function() "test")
  mock_config <- list(environment = "sandbox")

  trading_api <- EbayTradingAPI$new(mock_oauth, mock_config)

  warning_xml <- '<?xml version="1.0"?>
    <AddFixedPriceItemResponse xmlns="urn:ebay:apis:eBLBaseComponents">
      <Ack>Warning</Ack>
      <ItemID>987654321</ItemID>
      <Errors>
        <SeverityCode>Warning</SeverityCode>
        <ErrorCode>123</ErrorCode>
        <LongMessage>This is a warning message</LongMessage>
      </Errors>
    </AddFixedPriceItemResponse>'

  result <- trading_api$.__enclos_env__$private$parse_response(warning_xml)

  expect_true(result$success)
  expect_equal(result$item_id, "987654321")
  expect_true(!is.null(result$warnings))
  expect_true(length(result$warnings) > 0)
})

test_that("parse_response handles error response", {
  mock_oauth <- list(get_access_token = function() "test")
  mock_config <- list(environment = "sandbox")

  trading_api <- EbayTradingAPI$new(mock_oauth, mock_config)

  error_xml <- '<?xml version="1.0"?>
    <AddFixedPriceItemResponse xmlns="urn:ebay:apis:eBLBaseComponents">
      <Ack>Failure</Ack>
      <Errors>
        <ErrorCode>21916888</ErrorCode>
        <LongMessage>Invalid token</LongMessage>
      </Errors>
    </AddFixedPriceItemResponse>'

  result <- trading_api$.__enclos_env__$private$parse_response(error_xml)

  expect_false(result$success)
  expect_true(grepl("21916888", result$error))
  expect_true(grepl("Invalid token", result$error))
})

test_that("parse_response handles multiple errors", {
  mock_oauth <- list(get_access_token = function() "test")
  mock_config <- list(environment = "sandbox")

  trading_api <- EbayTradingAPI$new(mock_oauth, mock_config)

  error_xml <- '<?xml version="1.0"?>
    <AddFixedPriceItemResponse xmlns="urn:ebay:apis:eBLBaseComponents">
      <Ack>Failure</Ack>
      <Errors>
        <ErrorCode>100</ErrorCode>
        <LongMessage>First error</LongMessage>
      </Errors>
      <Errors>
        <ErrorCode>200</ErrorCode>
        <LongMessage>Second error</LongMessage>
      </Errors>
    </AddFixedPriceItemResponse>'

  result <- trading_api$.__enclos_env__$private$parse_response(error_xml)

  expect_false(result$success)
  expect_true(grepl("First error", result$error))
  expect_true(grepl("Second error", result$error))
})

# ==== HELPER FUNCTION TESTS ====

test_that("map_condition_to_trading_id maps conditions correctly", {
  expect_equal(map_condition_to_trading_id("Mint"), 3000)
  expect_equal(map_condition_to_trading_id("mint"), 3000)
  expect_equal(map_condition_to_trading_id("Excellent"), 3000)
  expect_equal(map_condition_to_trading_id("Very Good"), 4000)
  expect_equal(map_condition_to_trading_id("very good"), 4000)
  expect_equal(map_condition_to_trading_id("Good"), 5000)
  expect_equal(map_condition_to_trading_id("Fair"), 6000)
  expect_equal(map_condition_to_trading_id("Poor"), 7000)
})

test_that("map_condition_to_trading_id handles unknown condition", {
  expect_warning(result <- map_condition_to_trading_id("Unknown"))
  expect_equal(result, 3000)  # Default to "Used"
})

test_that("map_condition_to_trading_id handles whitespace", {
  expect_equal(map_condition_to_trading_id("  Excellent  "), 3000)
  expect_equal(map_condition_to_trading_id("\tGood\n"), 5000)
})

test_that("build_trading_item_data creates valid structure", {
  ai_data <- list(
    title = "Vintage Romanian Postcard from Bucharest",
    description = "Beautiful postcard showing Bucharest in the 1920s",
    price = "6.50",
    condition = "Excellent"
  )

  result <- build_trading_item_data(
    card_id = 123,
    ai_data = ai_data,
    image_url = "https://example.com/img.jpg",
    country = "RO",
    location = "Bucharest"
  )

  expect_equal(result$country, "RO")
  expect_equal(result$location, "Bucharest")
  expect_equal(result$category_id, 262042)
  expect_equal(result$condition_id, 3000)
  expect_equal(result$price, "6.50")
  expect_equal(result$quantity, 1)
  expect_true(nchar(result$title) <= 80)
  expect_equal(result$images[[1]], "https://example.com/img.jpg")
})

test_that("build_trading_item_data truncates long titles", {
  ai_data <- list(
    title = paste0(rep("A", 100), collapse = ""),  # 100 character title
    description = "Test",
    price = "5.00",
    condition = "Good"
  )

  result <- build_trading_item_data(
    card_id = 1,
    ai_data = ai_data,
    image_url = "https://example.com/img.jpg",
    country = "US",
    location = "New York"
  )

  expect_equal(nchar(result$title), 80)
})

test_that("build_trading_item_data formats price correctly", {
  ai_data <- list(
    title = "Test",
    description = "Test",
    price = 5,  # Numeric
    condition = "Good"
  )

  result <- build_trading_item_data(
    card_id = 1,
    ai_data = ai_data,
    image_url = "https://example.com/img.jpg",
    country = "US",
    location = "New York"
  )

  expect_equal(result$price, "5.00")  # Formatted string
})

# ==== ENDPOINT TESTS ====

test_that("get_endpoint returns correct sandbox URL", {
  mock_oauth <- list(get_access_token = function() "test")
  mock_config <- list(environment = "sandbox")

  trading_api <- EbayTradingAPI$new(mock_oauth, mock_config)

  endpoint <- trading_api$.__enclos_env__$private$get_endpoint()

  expect_equal(endpoint, "https://api.sandbox.ebay.com/ws/api.dll")
})

test_that("get_endpoint returns correct production URL", {
  mock_oauth <- list(get_access_token = function() "test")
  mock_config <- list(environment = "production")

  trading_api <- EbayTradingAPI$new(mock_oauth, mock_config)

  endpoint <- trading_api$.__enclos_env__$private$get_endpoint()

  expect_equal(endpoint, "https://api.ebay.com/ws/api.dll")
})

# ==== DATABASE TESTS ====

test_that("save_ebay_listing supports api_type parameter", {
  skip_if_not(file.exists("inst/app/data/tracking.sqlite"), "Database not available")

  # This test verifies the function signature accepts api_type
  expect_error({
    save_ebay_listing(
      card_id = 999,
      session_id = "test_session",
      sku = "test_sku_api_type",
      status = "draft",
      api_type = "trading"
    )
  }, NA)  # Expect no error
})
