# Mock factories for external dependencies
# This file provides mock responses for AI APIs, eBay OAuth, and other external services

#' Create a mock Claude API response
#'
#' Generates a realistic mock response from the Claude API for testing
#' without making actual API calls or incurring costs.
#'
#' @param success Whether the mock should simulate a successful response
#' @param extraction_data Optional custom extraction data
#' @return A list mimicking the structure of a real Claude API response
#' @export
#'
#' @examples
#' response <- mock_claude_response(success = TRUE)
#' expect_true(response$success)
#' expect_type(response$data$title, "character")
mock_claude_response <- function(success = TRUE, extraction_data = NULL) {
  if (success) {
    if (is.null(extraction_data)) {
      extraction_data <- list(
        title = "Vintage Postcard - Paris Eiffel Tower",
        description = "Beautiful vintage postcard from Paris showing the Eiffel Tower in the 1920s. Good condition with minor wear on edges.",
        price = "15.00",
        condition = "Good",
        year = "1920s",
        location = "Paris, France",
        publisher = "Unknown",
        series = "",
        notes = "Minor edge wear, otherwise excellent"
      )
    }

    return(list(
      success = TRUE,
      data = extraction_data,
      model = "claude-3-5-sonnet-20241022",
      tokens_used = 1250
    ))
  } else {
    return(list(
      success = FALSE,
      error = "Rate limit exceeded. Please try again later.",
      retry_after = 60
    ))
  }
}

#' Create a mock OpenAI API response
#'
#' Generates a realistic mock response from the OpenAI API for testing
#'
#' @param success Whether the mock should simulate a successful response
#' @param extraction_data Optional custom extraction data
#' @return A list mimicking the structure of a real OpenAI API response
#' @export
mock_openai_response <- function(success = TRUE, extraction_data = NULL) {
  if (success) {
    if (is.null(extraction_data)) {
      extraction_data <- list(
        title = "Antique Postcard - London Bridge",
        description = "Historic postcard depicting London Bridge circa 1910. Sepia tone photograph with handwritten message on back.",
        price = "20.00",
        condition = "Very Good",
        year = "1910",
        location = "London, England",
        publisher = "Valentine & Sons",
        series = "Celebrated Series",
        notes = "Handwritten message adds historical value"
      )
    }

    return(list(
      success = TRUE,
      data = extraction_data,
      model = "gpt-4o",
      tokens_used = 980
    ))
  } else {
    return(list(
      success = FALSE,
      error = "API key invalid or quota exceeded",
      error_code = "invalid_api_key"
    ))
  }
}

#' Create a mock eBay OAuth response
#'
#' Generates a mock eBay OAuth token response for testing authentication flows
#'
#' @param success Whether the mock should simulate a successful response
#' @return A list mimicking eBay OAuth token response
#' @export
mock_ebay_oauth <- function(success = TRUE) {
  if (success) {
    return(list(
      access_token = "v^1.1#i^1#f^0#p^3#r^0#t^H4s1aABCDEF123456",
      token_type = "User Access Token",
      expires_in = 7200,
      refresh_token = "v^1.1#i^1#f^0#p^3#r^1#t^Ul4xMzQ5OjFBQzY5",
      refresh_token_expires_in = 47304000
    ))
  } else {
    return(list(
      error = "invalid_grant",
      error_description = "Authorization code is invalid or expired"
    ))
  }
}

#' Execute code with mocked AI API calls
#'
#' Wrapper that mocks httr2::req_perform for AI API calls, ensuring tests
#' don't make real API requests or incur costs.
#'
#' @param code Code to execute with mocked AI
#' @param provider Which AI provider to mock ("claude" or "openai")
#' @param success Whether mocked calls should succeed
#' @return Result of evaluating code
#' @export
#'
#' @examples
#' with_mocked_ai({
#'   result <- call_claude_api(test_image, "Extract title")
#'   expect_true(result$success)
#' }, provider = "claude")
with_mocked_ai <- function(code, provider = "claude", success = TRUE) {
  # Determine which mock response to use
  mock_response <- if (provider == "claude") {
    mock_claude_response(success = success)
  } else {
    mock_openai_response(success = success)
  }

  # Mock the httr2 request performance
  mockery::stub(
    where = parent.frame(),
    what = "httr2::req_perform",
    how = function(...) {
      # Return a mock httr2 response object
      structure(
        list(
          status_code = if (success) 200L else 429L,
          body = jsonlite::toJSON(mock_response, auto_unbox = TRUE)
        ),
        class = "httr2_response"
      )
    }
  )

  # Execute the code in the parent frame
  eval(substitute(code), envir = parent.frame())
}

#' Execute code with mocked eBay API calls
#'
#' Wrapper that mocks httr2::req_perform for eBay API calls
#'
#' @param code Code to execute with mocked eBay
#' @param success Whether mocked calls should succeed
#' @return Result of evaluating code
#' @export
with_mocked_ebay <- function(code, success = TRUE) {
  mock_response <- mock_ebay_oauth(success = success)

  mockery::stub(
    where = parent.frame(),
    what = "httr2::req_perform",
    how = function(...) {
      structure(
        list(
          status_code = if (success) 200L else 400L,
          body = jsonlite::toJSON(mock_response, auto_unbox = TRUE)
        ),
        class = "httr2_response"
      )
    }
  )

  eval(substitute(code), envir = parent.frame())
}

#' Mock file upload for Shiny testing
#'
#' Creates a mock file upload object compatible with Shiny's fileInput
#'
#' @param file_path Path to the test file
#' @param name Optional custom filename
#' @return A list mimicking Shiny's file upload structure
#' @export
mock_file_upload <- function(file_path, name = NULL) {
  if (is.null(name)) {
    name <- basename(file_path)
  }

  list(
    name = name,
    size = file.size(file_path),
    type = mime::guess_type(file_path),
    datapath = file_path
  )
}
