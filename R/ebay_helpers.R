#' eBay Helper Functions
#' Utilities for mapping Delcampe data to eBay API requirements

#' Map AI condition strings to eBay condition codes
#' @export
map_condition_to_ebay <- function(condition) {
  # Category 262042 (Topographical Postcards) ONLY accepts NEW condition
  # All other conditions (LIKE_NEW, USED_*, etc.) are rejected
  # This is eBay's restriction for this category - all postcards must be listed as NEW
  # Note: You can describe actual condition in the description text
  condition_map <- list(
    "excellent" = "NEW",
    "very good" = "NEW",
    "good" = "NEW",
    "fair" = "NEW",
    "poor" = "NEW",
    "used" = "NEW",
    "new" = "NEW",
    "like new" = "NEW"
  )

  condition_lower <- tolower(trimws(condition))
  ebay_condition <- condition_map[[condition_lower]]

  if (is.null(ebay_condition)) {
    warning("Unknown condition '", condition, "', defaulting to NEW")
    return("NEW")
  }

  return(ebay_condition)
}

#' Generate unique SKU from card ID
#' @export
generate_sku <- function(card_id, prefix = "PC") {
  # Format: PC-{card_id}-{timestamp}
  # Example: PC-123-20250115143022
  timestamp <- format(Sys.time(), "%Y%m%d%H%M%S")
  paste0(prefix, "-", card_id, "-", timestamp)
}

#' Extract postcard aspects from AI data
#' @export
extract_postcard_aspects <- function(ai_data) {
  # Return list of eBay aspects for postcards
  # Based on PRPs/ai_docs/ebay_api_documentation.md:79-111
  aspects <- list(
    "Type" = list("Postcard")
  )

  # Try to infer Era from description/title
  # For MVP, use defaults; future enhancement: parse from AI data
  if (!is.null(ai_data$era)) {
    aspects[["Era"]] <- list(ai_data$era)
  } else {
    aspects[["Era"]] <- list("Unknown")
  }

  # Default theme
  aspects[["Theme"]] <- list("Other")

  # Default to original
  aspects[["Original/Licensed Reprint"]] <- list("Original")

  return(aspects)
}

#' Validate required fields for eBay listing
#' @export
validate_required_fields <- function(ai_data, image_url = NULL) {
  errors <- character(0)

  # Required fields per API documentation
  if (is.null(ai_data$title) || nchar(trimws(ai_data$title)) == 0) {
    errors <- c(errors, "Title is required")
  }

  if (is.null(ai_data$description) || nchar(trimws(ai_data$description)) == 0) {
    errors <- c(errors, "Description is required")
  }

  if (is.null(ai_data$price) || !is.numeric(ai_data$price) || ai_data$price <= 0) {
    errors <- c(errors, "Valid price is required")
  }

  if (is.null(ai_data$condition) || nchar(trimws(ai_data$condition)) == 0) {
    errors <- c(errors, "Condition is required")
  }

  if (is.null(image_url) || nchar(trimws(image_url)) == 0) {
    errors <- c(errors, "At least one image URL is required")
  }

  if (length(errors) > 0) {
    return(list(
      valid = FALSE,
      message = paste("Validation errors:", paste(errors, collapse = "; "))
    ))
  }

  return(list(valid = TRUE))
}

#' Format price for eBay API (must be string with 2 decimals)
#' @export
format_ebay_price <- function(price) {
  # eBay requires string like "9.99" not numeric 9.99
  sprintf("%.2f", as.numeric(price))
}
