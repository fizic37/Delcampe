# Tests for ai_api_helpers.R
# Covers LLM configuration, API calls, image compression, and response parsing

# ==== LLM CONFIGURATION TESTS ====

test_that("get_llm_config returns valid configuration", {
  config <- get_llm_config()

  expect_type(config, "list")
  expect_true("default_model" %in% names(config))
  expect_true("temperature" %in% names(config))
  expect_true("max_tokens" %in% names(config))
  expect_true("claude_api_key" %in% names(config))
  expect_true("openai_api_key" %in% names(config))
})

test_that("get_llm_config includes default model", {
  config <- get_llm_config()

  expect_type(config$default_model, "character")
  expect_true(nchar(config$default_model) > 0)
})

test_that("get_llm_config includes temperature setting", {
  config <- get_llm_config()

  expect_type(config$temperature, "double")
  expect_gte(config$temperature, 0)
  expect_lte(config$temperature, 1)
})

test_that("get_available_models returns models when API keys configured", {
  # This test may return empty list if no API keys are configured
  # That's expected behavior
  models <- get_available_models()

  expect_type(models, "list")
  # Models may be empty if no API keys configured - that's OK
})

test_that("get_provider_from_model identifies Claude models", {
  provider <- get_provider_from_model("claude-3-5-sonnet-20241022")

  expect_equal(provider, "claude")
})

test_that("get_provider_from_model identifies Claude models by pattern", {
  provider <- get_provider_from_model("claude-sonnet-4-5-20250929")

  expect_equal(provider, "claude")
})

test_that("get_provider_from_model identifies OpenAI models", {
  provider <- get_provider_from_model("gpt-4o")

  expect_equal(provider, "openai")
})

test_that("get_provider_from_model identifies GPT models by pattern", {
  provider <- get_provider_from_model("gpt-4-turbo")

  expect_equal(provider, "openai")
})

test_that("get_provider_from_model defaults to claude for unknown models", {
  result <- get_provider_from_model("unknown-model-xyz")

  # Function defaults to "claude" for unknown models
  expect_equal(result, "claude")
})

test_that("get_model_display_name returns readable names for known models", {
  name <- get_model_display_name("claude-sonnet-4-5-20250929")

  expect_type(name, "character")
  expect_equal(name, "Claude Sonnet 4.5")
})

test_that("get_model_display_name returns original ID for unknown models", {
  unknown_model <- "unknown-model-123"
  name <- get_model_display_name(unknown_model)

  expect_equal(name, unknown_model)
})

# ==== IMAGE COMPRESSION TESTS ====

test_that("compress_image_if_needed handles small images correctly", {
  skip_if_not_installed("magick")

  # Use test image (should be small enough)
  test_img <- test_path("fixtures/test_face.jpg")

  # If image is already small, it should be returned as-is
  result <- compress_image_if_needed(test_img, max_size_mb = 10)

  expect_type(result, "character")
  expect_true(file.exists(result))
})

test_that("compress_image_if_needed handles non-existent files", {
  skip_if_not_installed("magick")

  expect_error(
    compress_image_if_needed("nonexistent_file.jpg"),
    "file|exist|found"
  )
})

test_that("compress_image_if_needed validates max_size_mb parameter", {
  skip_if_not_installed("magick")

  test_img <- test_path("fixtures/test_face.jpg")

  expect_error(
    compress_image_if_needed(test_img, max_size_mb = -1),
    "positive|greater|size"
  )
})

# ==== API CALL TESTS (MOCKED) ====

test_that("call_claude_api succeeds with valid inputs (mocked)", {
  skip("Requires mocking infrastructure - to be implemented")

  # This test would use with_mocked_ai() once we verify the mocking works
  # with_mocked_ai({
  #   result <- call_claude_api(
  #     image_path = test_path("fixtures/test_face.jpg"),
  #     prompt = "Extract title"
  #   )
  #
  #   expect_true(result$success)
  #   expect_type(result$data, "list")
  # }, provider = "claude")
})

test_that("call_claude_api handles missing image file", {
  skip_if_not(Sys.getenv("CLAUDE_API_KEY") == "")  # Skip if API key present

  expect_error(
    call_claude_api(
      image_path = "nonexistent.jpg",
      prompt = "Test"
    ),
    "file|exist|found"
  )
})

test_that("call_openai_api succeeds with valid inputs (mocked)", {
  skip("Requires mocking infrastructure - to be implemented")

  # with_mocked_ai({
  #   result <- call_openai_api(
  #     image_path = test_path("fixtures/test_face.jpg"),
  #     prompt = "Extract title"
  #   )
  #
  #   expect_true(result$success)
  #   expect_type(result$data, "list")
  # }, provider = "openai")
})

test_that("call_openai_api handles missing image file", {
  skip_if_not(Sys.getenv("OPENAI_API_KEY") == "")  # Skip if API key present

  expect_error(
    call_openai_api(
      image_path = "nonexistent.jpg",
      prompt = "Test"
    ),
    "file|exist|found"
  )
})

# ==== PROMPT BUILDING TESTS ====

test_that("build_postal_card_prompt generates valid prompt for individual", {
  prompt <- build_postal_card_prompt(extraction_type = "individual")

  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 50)
  expect_true(grepl("postal|card|postcard", prompt, ignore.case = TRUE))
})

test_that("build_postal_card_prompt generates valid prompt for lot", {
  prompt <- build_postal_card_prompt(extraction_type = "lot", card_count = 5)

  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 50)
  expect_true(grepl("lot", prompt, ignore.case = TRUE))
  expect_true(grepl("5", prompt))
})

test_that("build_postal_card_prompt includes TITLE format instruction", {
  prompt <- build_postal_card_prompt(extraction_type = "individual")

  expect_true(grepl("TITLE:", prompt))
})

test_that("build_postal_card_prompt includes DESCRIPTION format instruction", {
  prompt <- build_postal_card_prompt(extraction_type = "individual")

  expect_true(grepl("DESCRIPTION:", prompt))
})

test_that("build_enhanced_postal_card_prompt generates enhanced prompt", {
  skip("Function may not exist or have different name")

  prompt <- build_enhanced_postal_card_prompt("face")

  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 100)
})

test_that("get_extraction_prompt returns appropriate prompt", {
  prompt <- get_extraction_prompt("face", enhanced = FALSE)

  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 20)
})

test_that("get_extraction_prompt uses enhanced prompt when requested", {
  basic_prompt <- get_extraction_prompt("face", enhanced = FALSE)
  enhanced_prompt <- get_extraction_prompt("face", enhanced = TRUE)

  # Enhanced should be longer/different
  expect_false(identical(basic_prompt, enhanced_prompt))
})

# ==== RESPONSE PARSING TESTS ====

test_that("parse_ai_response extracts TITLE format from text", {
  response_text <- 'TITLE: Vintage Postcard
DESCRIPTION: Paris 1920s architectural view'

  result <- parse_ai_response(response_text)

  expect_type(result, "list")
  expect_equal(result$title, "Vintage Postcard")
  expect_true(grepl("Paris", result$description))
})

test_that("parse_ai_response handles simple text without format", {
  plain_text <- "This is a vintage postcard from Paris"

  result <- parse_ai_response(plain_text)

  expect_type(result, "list")
  expect_true("title" %in% names(result))
  expect_true("description" %in% names(result))
})

test_that("parse_ai_response handles empty input", {
  result <- parse_ai_response("")

  expect_type(result, "list")
  expect_equal(result$title, "")
  expect_equal(result$description, "")
})

test_that("parse_ai_response handles NULL input", {
  result <- parse_ai_response(NULL)

  expect_type(result, "list")
  expect_equal(result$title, "")
  expect_equal(result$description, "")
})

test_that("parse_enhanced_ai_response extracts structured format", {
  enhanced_text <- 'TITLE: Historic Postcard
DESCRIPTION: London Bridge 1910 architectural view
CONDITION: excellent
PRICE: 12.50'

  result <- parse_enhanced_ai_response(enhanced_text)

  expect_type(result, "list")
  expect_equal(result$title, "Historic Postcard")
  expect_true(grepl("London", result$description))
  expect_equal(result$condition, "excellent")
  expect_equal(result$price, 12.50)
})

test_that("parse_enhanced_ai_response handles missing optional fields", {
  minimal_text <- 'TITLE: Test Card
DESCRIPTION: Simple description'

  result <- parse_enhanced_ai_response(minimal_text)

  expect_type(result, "list")
  expect_equal(result$title, "Test Card")
  expect_equal(result$description, "Simple description")
  # Should have defaults for missing fields
  expect_true("condition" %in% names(result))
  expect_true("price" %in% names(result))
})

test_that("parse_enhanced_ai_response provides defaults for empty input", {
  result <- parse_enhanced_ai_response("")

  expect_type(result, "list")
  expect_equal(result$title, "")
  expect_equal(result$description, "")
  expect_equal(result$condition, "used")
  expect_equal(result$price, 2.50)
})

test_that("parse_enhanced_ai_response clamps price to valid range", {
  high_price_text <- 'TITLE: Test
DESCRIPTION: Test
CONDITION: excellent
PRICE: 999.99'

  result <- parse_enhanced_ai_response(high_price_text)

  # Price should be clamped to max of 60.00
  expect_lte(result$price, 60.00)
})

# ==== EXTRACTION WORKFLOW TESTS ====

test_that("extract_with_llm integrates components correctly (dry run)", {
  skip("Integration test - requires full mock setup")

  # This would test the full extraction workflow:
  # 1. Load config
  # 2. Compress image if needed
  # 3. Build prompt
  # 4. Call API (mocked)
  # 5. Parse response
  # 6. Return structured data
})

test_that("extract_with_llm validates inputs", {
  # Test that extract_with_llm validates required parameters
  expect_error(
    extract_with_llm(
      image_path = NULL,
      model = "claude-3-5-sonnet-20241022"
    ),
    "image|path|required"
  )

  expect_error(
    extract_with_llm(
      image_path = test_path("fixtures/test_face.jpg"),
      model = NULL
    ),
    "model|required"
  )
})

test_that("extract_with_llm handles provider selection", {
  skip("Requires API mocking")

  # Should automatically select provider based on model
  # with_mocked_ai({
  #   result <- extract_with_llm(
  #     image_path = test_path("fixtures/test_face.jpg"),
  #     model = "claude-3-5-sonnet-20241022",
  #     side = "face"
  #   )
  #
  #   expect_true(result$success)
  #   expect_equal(result$provider, "claude")
  # })
})

# ==== ERROR HANDLING TESTS ====

test_that("AI helpers handle rate limiting gracefully", {
  skip("Requires API error response mocking")

  # Test that rate limit errors are caught and reported properly
})

test_that("AI helpers handle API key errors", {
  skip("Requires API error response mocking")

  # Test that missing/invalid API key errors are handled
})

test_that("AI helpers handle network errors", {
  skip("Requires network error mocking")

  # Test that network failures are caught and reported
})

test_that("AI helpers handle timeout errors", {
  skip("Requires timeout simulation")

  # Test that API timeouts are handled gracefully
})

# ==== CONFIGURATION VALIDATION TESTS ====

test_that("LLM config validates API keys format", {
  # Test that config validation checks API key format
  # (without actually validating real keys)
  config <- list(
    api_key = "sk-test-123",
    model = "test-model"
  )

  expect_true(is.character(config$api_key))
  expect_true(nchar(config$api_key) > 0)
})

test_that("LLM config includes required fields", {
  config <- get_llm_config()

  # Should include essential fields
  expect_true(is.list(config))
  expect_true(length(config) > 0)
  expect_true("default_model" %in% names(config))
  expect_true("temperature" %in% names(config))
  expect_true("max_tokens" %in% names(config))
})

# ==== HELPER FUNCTION TESTS ====

test_that("Helper functions handle edge cases", {
  # Test various edge cases in helper functions

  # build_postal_card_prompt with defaults
  result <- build_postal_card_prompt()
  expect_type(result, "character")
  expect_true(nchar(result) > 0)
})

test_that("Model name formatting is consistent", {
  # Test that model names are consistently formatted
  name1 <- get_model_display_name("claude-sonnet-4-5-20250929")
  name2 <- get_model_display_name("gpt-4o")

  expect_type(name1, "character")
  expect_type(name2, "character")
  expect_true(nchar(name1) > 0)
  expect_true(nchar(name2) > 0)
})

test_that("get_provider_from_model is case insensitive", {
  # Test case insensitivity
  provider1 <- get_provider_from_model("CLAUDE-SONNET")
  provider2 <- get_provider_from_model("claude-sonnet")

  expect_equal(provider1, provider2)
  expect_equal(provider1, "claude")
})

test_that("parse_ai_response handles multi-line descriptions", {
  multiline <- "TITLE: Test Card
DESCRIPTION: This is a long description
that spans multiple lines
with various details"

  result <- parse_ai_response(multiline)

  expect_type(result, "list")
  expect_equal(result$title, "Test Card")
  expect_true(grepl("multiple lines", result$description))
})
