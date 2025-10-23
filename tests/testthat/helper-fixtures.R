# Test data generators and fixtures
# This file provides factory functions for generating consistent test data

#' Generate a test postal card object
#'
#' Creates a realistic test card with all expected fields populated
#'
#' @param id Card ID (default 1)
#' @param title Custom title (optional)
#' @param description Custom description (optional)
#' @return A list representing a postal card
#' @export
#'
#' @examples
#' card <- generate_test_card(id = 1)
#' expect_equal(card$id, 1)
#' expect_type(card$title, "character")
generate_test_card <- function(id = 1, title = NULL, description = NULL) {
  if (is.null(title)) {
    title <- paste0("Test Postcard #", id, " - Paris Eiffel Tower")
  }

  if (is.null(description)) {
    description <- paste0(
      "Vintage postcard from Paris showing the Eiffel Tower. ",
      "Card #", id, " in test series. Good condition with minor wear."
    )
  }

  list(
    id = id,
    title = title,
    description = description,
    price = sprintf("%.2f", 10 + (id * 2.5)),
    condition = sample(c("Mint", "Excellent", "Very Good", "Good", "Fair"), 1),
    year = sample(c("1900s", "1910s", "1920s", "1930s", "1940s"), 1),
    location = sample(c("Paris, France", "London, England", "New York, USA"), 1),
    publisher = sample(c("Unknown", "Valentine & Sons", "Raphael Tuck & Sons"), 1),
    series = "",
    image_hash = digest::digest(paste0("test_card_", id), algo = "sha256", serialize = FALSE),
    face_path = paste0("test_data/face_", id, ".jpg"),
    verso_path = paste0("test_data/verso_", id, ".jpg"),
    created_at = as.character(Sys.time())
  )
}

#' Generate a test user object
#'
#' Creates a test user with proper password hashing
#'
#' @param username Username (default "testuser")
#' @param password Plain-text password (default "testpass")
#' @param is_master Whether user is a master user (default FALSE)
#' @return A list representing a user
#' @export
#'
#' @examples
#' user <- generate_test_user(username = "alice")
#' expect_equal(user$username, "alice")
#' expect_false(user$is_master)
generate_test_user <- function(username = "testuser", password = "testpass", is_master = FALSE) {
  list(
    username = username,
    password_hash = digest::digest(password, algo = "sha256", serialize = FALSE),
    is_master = is_master,
    created_at = as.character(Sys.time())
  )
}

#' Generate sample AI extraction result
#'
#' Creates a realistic AI extraction response for testing
#'
#' @param side Which side of the card ("face" or "verso")
#' @param quality Quality level ("high", "medium", "low")
#' @return A list representing AI extraction results
#' @export
#'
#' @examples
#' extraction <- sample_ai_extraction(side = "face", quality = "high")
#' expect_type(extraction$title, "character")
#' expect_true(extraction$confidence > 0.8)
sample_ai_extraction <- function(side = "face", quality = "high") {
  # Confidence based on quality
  confidence <- switch(quality,
    "high" = runif(1, 0.85, 0.99),
    "medium" = runif(1, 0.60, 0.84),
    "low" = runif(1, 0.30, 0.59),
    0.75
  )

  base_data <- list(
    title = "Vintage Postcard Collection",
    description = "Beautiful vintage postcard from early 20th century",
    condition = "Good",
    year = "1920s",
    location = "Paris, France",
    publisher = "Unknown",
    series = "",
    notes = "Minor wear on edges"
  )

  # Add side-specific data
  if (side == "face") {
    base_data$scene_description <- "Eiffel Tower with surrounding gardens"
    base_data$colors <- list("sepia", "brown", "cream")
    base_data$text_on_image <- "Paris - La Tour Eiffel"
  } else {
    base_data$message <- "Handwritten message in French"
    base_data$postmark <- "Paris 1925"
    base_data$stamp_description <- "French postage stamp, 10 centimes"
    base_data$recipient <- "Mme. Marie Dubois"
  }

  # Add extraction metadata
  base_data$extraction_metadata <- list(
    confidence = confidence,
    model = if (runif(1) > 0.5) "claude-3-5-sonnet-20241022" else "gpt-4o",
    timestamp = as.character(Sys.time()),
    processing_time_ms = round(runif(1, 800, 3000))
  )

  return(base_data)
}

#' Generate a test processing session
#'
#' Creates a test session object with metadata
#'
#' @param session_id Session ID (default 1)
#' @param user_id User ID (default 1)
#' @param num_cards Number of cards processed (default 5)
#' @return A list representing a processing session
#' @export
generate_test_session <- function(session_id = 1, user_id = 1, num_cards = 5) {
  start_time <- Sys.time() - as.difftime(30, units = "mins")

  list(
    session_id = session_id,
    user_id = user_id,
    session_start = as.character(start_time),
    session_end = as.character(Sys.time()),
    cards_processed = num_cards,
    grid_path = paste0("test_data/grid_session_", session_id, ".jpg"),
    config = list(
      rows = 2,
      cols = 3,
      rotate_face = FALSE,
      rotate_verso = FALSE
    )
  )
}

#' Generate test crop data
#'
#' Creates realistic crop boundary data for testing
#'
#' @param num_crops Number of crops to generate (default 6)
#' @return A data frame of crop boundaries
#' @export
generate_test_crops <- function(num_crops = 6) {
  crops <- data.frame(
    crop_id = 1:num_crops,
    x_min = round(runif(num_crops, 0, 500)),
    y_min = round(runif(num_crops, 0, 500)),
    x_max = round(runif(num_crops, 600, 1000)),
    y_max = round(runif(num_crops, 600, 1000)),
    width = 0,
    height = 0,
    stringsAsFactors = FALSE
  )

  # Calculate width and height
  crops$width <- crops$x_max - crops$x_min
  crops$height <- crops$y_max - crops$y_min

  return(crops)
}

#' Generate test eBay listing data
#'
#' Creates realistic eBay listing data for testing
#'
#' @param listing_id Listing ID (default 1)
#' @return A list representing an eBay listing
#' @export
generate_test_ebay_listing <- function(listing_id = 1) {
  list(
    listing_id = listing_id,
    title = paste0("Vintage Postcard #", listing_id, " - Historic Landmark"),
    description = "Beautiful vintage postcard in excellent condition",
    price = sprintf("%.2f", 15 + (listing_id * 5)),
    category_id = "4168",  # Collectibles > Postcards
    condition = "Used",
    condition_description = "Minor edge wear, otherwise excellent",
    quantity = 1,
    format = "FixedPrice",
    duration = "GTC",  # Good 'Til Cancelled
    shipping_service = "USPSFirstClass",
    shipping_cost = "3.50",
    returns_accepted = TRUE,
    return_period = "30 Days",
    location = list(
      country = "US",
      postal_code = "10001",
      city = "New York"
    ),
    image_urls = c(
      paste0("https://example.com/image_", listing_id, "_1.jpg"),
      paste0("https://example.com/image_", listing_id, "_2.jpg")
    )
  )
}

#' Generate test Delcampe export data
#'
#' Creates realistic Delcampe export data for testing
#'
#' @param export_id Export ID (default 1)
#' @return A list representing a Delcampe export
#' @export
generate_test_delcampe_export <- function(export_id = 1) {
  list(
    export_id = export_id,
    title = paste0("Lot #", export_id, " - Historic Postcards"),
    description = "Collection of vintage postcards from various locations",
    price_eur = sprintf("%.2f", 20 + (export_id * 8)),
    category = "Postcards > Europe > France",
    condition = "Good",
    shipping_cost = "5.00",
    shipping_country = "Worldwide",
    payment_methods = c("PayPal", "Bank Transfer"),
    export_date = as.character(Sys.Date()),
    export_format = "CSV"
  )
}
