#' eBay Helper Functions
#' Utilities for mapping Delcampe data to eBay API requirements

#' Map AI condition strings to eBay Inventory API condition codes
#' @param condition String condition from AI extraction
#' @param use_unspecified If TRUE, return "UNSPECIFIED" for all conditions (bypasses validation)
#' @return String condition code for eBay Inventory API
#' @export
map_condition_to_ebay <- function(condition, use_unspecified = FALSE) {
  # UNSPECIFIED bypass option (for categories with strict condition requirements)
  # Per eBay docs: "UNSPECIFIED" safely bypasses condition enforcement
  if (use_unspecified) {
    return("UNSPECIFIED")
  }

  # eBay Inventory API accepts simple condition codes per REST Taxonomy API
  # Valid values for category 262042: "USED", "UNSPECIFIED"
  # Using "USED" to avoid Error 25019 (Overseas Warehouse Block)
  # NEVER use "NEW" which triggers overseas warehouse policy for cross-border listings
  condition_map <- list(
    "excellent" = "USED",
    "very good" = "USED",
    "good" = "USED",
    "fair" = "USED",
    "poor" = "USED",
    "used" = "USED",
    "new" = "UNSPECIFIED",   # Fallback to UNSPECIFIED to avoid "NEW"
    "like new" = "UNSPECIFIED",
    "mint" = "UNSPECIFIED"
  )

  condition_lower <- tolower(trimws(condition))
  ebay_condition <- condition_map[[condition_lower]]

  if (is.null(ebay_condition)) {
    warning("Unknown condition '", condition, "', defaulting to UNSPECIFIED")
    return("UNSPECIFIED")  # Safest fallback per eBay docs
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
extract_postcard_aspects <- function(ai_data, condition_code = NULL) {
  # Return list of eBay aspects for postcards
  # Based on PRPs/ai_docs/ebay_api_documentation.md:79-111
  aspects <- list(
    "Type" = list("Postcard")
  )

  # Add Condition as aspect (category 262042 requires it in aspects, not top-level)
  # Per eBay Metadata API: category 262042 has Condition as an aspect
  if (!is.null(condition_code)) {
    # Map condition code to display value
    condition_display <- switch(condition_code,
      "USED" = "Used",
      "UNSPECIFIED" = "Not specified",
      "NEW" = "New",
      "LIKE_NEW" = "Like New",
      condition_code  # fallback to raw value
    )
    aspects[["Condition"]] <- list(condition_display)
  }

  # Infer Era - prioritize AI-extracted data
  era <- "Unknown"
  
  # Priority 1: Use AI-extracted era directly
  if (!is.null(ai_data$era) && !is.na(ai_data$era) && trimws(ai_data$era) != "") {
    era <- ai_data$era
  }
  # Priority 2: Infer from AI-extracted year
  else if (!is.null(ai_data$year) && !is.na(ai_data$year)) {
    inferred_era <- infer_era_from_year(ai_data$year)
    if (!is.null(inferred_era)) {
      era <- inferred_era
    }
  }
  # Priority 3: Fall back to text parsing
  else {
    # Try to extract year from title or description
    text_to_search <- paste(ai_data$title, ai_data$description, collapse = " ")
    year_match <- regmatches(text_to_search, regexpr("\\b(19|20)\\d{2}\\b", text_to_search))

    if (length(year_match) > 0) {
      year <- as.integer(year_match[1])
      era <- if (year >= 1939) {
        "Chrome (c.1939-Present)"
      } else if (year >= 1930) {
        "Linen (c.1930-1945)"
      } else if (year >= 1907) {
        "Divided Back (c.1907-1915)"
      } else {
        "Undivided Back (pre-1907)"
      }
    }
  }
  aspects[["Era"]] <- list(era)

  # Add City aspect if available from AI (already ASCII from AI prompt!)
  if (!is.null(ai_data$city) && !is.na(ai_data$city) && trimws(ai_data$city) != "") {
    aspects[["City"]] <- list(ai_data$city)
  }

  # Infer Theme from content - prioritize AI keywords
  theme <- "Other"
  
  # Priority 1: Use AI theme keywords if available
  if (!is.null(ai_data$theme_keywords) && !is.na(ai_data$theme_keywords)) {
    keywords_lower <- tolower(ai_data$theme_keywords)
    if (grepl("view|town|city|street", keywords_lower)) {
      theme <- "Cities & Towns"
    } else if (grepl("church|cathedral|building", keywords_lower)) {
      theme <- "Architecture/Buildings"
    } else if (grepl("river|mountain|lake|landscape", keywords_lower)) {
      theme <- "Natural History"
    } else if (grepl("railway|train|transport", keywords_lower)) {
      theme <- "Transportation"
    }
  }
  # Priority 2: Fall back to text analysis
  else {
    text_lower <- tolower(paste(ai_data$title, ai_data$description, collapse = " "))
    if (grepl("view|town|city|street|building|landscape|panorama", text_lower)) {
      theme <- "Cities & Towns"
    } else if (grepl("church|cathedral|monastery|religious", text_lower)) {
      theme <- "Architecture/Buildings"
    } else if (grepl("river|mountain|lake|sea|coast", text_lower)) {
      theme <- "Natural History"
    } else if (grepl("train|railway|station|transport", text_lower)) {
      theme <- "Transportation"
    }
  }

  aspects[["Theme"]] <- list(theme)

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

#' Map Condition to Trading API ConditionID
#'
#' Trading API uses integer ConditionID instead of text codes
#' Reference: https://developer.ebay.com/devzone/finding/callref/enums/conditionIdList.html
#'
#' @param condition Condition string from AI
#' @return Integer ConditionID for postcards/collectibles
#' @export
map_condition_to_trading_id <- function(condition) {
  # Handle NULL or empty condition - default to "Used"
  if (is.null(condition) || trimws(condition) == "") {
    return(3000)  # Used
  }
  
  condition_lower <- tolower(trimws(condition))

  # eBay condition IDs for collectibles (postcards)
  # Category 262042 (Topographical Postcards) only accepts ID 3000 (Used)
  # All vintage postcards should use "Used" since they're pre-owned collectibles
  # Detailed condition goes in Item Specifics (aspects), not condition_id
  condition_map <- list(
    "mint" = 3000,           # Used
    "near mint" = 3000,      # Used
    "excellent" = 3000,      # Used
    "very good" = 3000,      # Used
    "good" = 3000,           # Used
    "fair" = 3000,           # Used
    "poor" = 3000,           # Used
    "used" = 3000            # Used (generic)
  )

  result <- condition_map[[condition_lower]]

  if (is.null(result)) {
    # Default to "Used" for unknown conditions
    warning("Unknown condition '", condition, "', defaulting to ConditionID 3000 (Used)")
    return(3000)
  }

  return(result)
}

#' Infer Postcard Era from Year
#'
#' Determines the postcard era based on the year.
#' Eras: Undivided Back (pre-1907), Divided Back (1907-1915),
#' Linen (1930-1945), Chrome (1939+)
#'
#' @param year Year as numeric or string
#' @return Era string or NULL if year is invalid
#' @export
infer_era_from_year <- function(year) {
  if (is.null(year) || is.na(year)) {
    return(NULL)
  }

  # Convert to numeric
  year_num <- tryCatch(
    as.numeric(year),
    error = function(e) NULL,
    warning = function(w) NULL
  )

  if (is.null(year_num) || is.na(year_num)) {
    return(NULL)
  }

  # Determine era based on year ranges
  if (year_num < 1907) {
    return("Undivided Back")
  } else if (year_num >= 1907 && year_num <= 1915) {
    return("Divided Back")
  } else if (year_num >= 1930 && year_num <= 1945) {
    return("Linen")
  } else if (year_num >= 1939) {
    return("Chrome")
  }

  return(NULL)
}

#' Build Trading API Item Data from Card
#'
#' Converts postcard data + AI extraction to Trading API format
#'
#' @param card_id Card ID
#' @param ai_data AI extraction data (title, description, price, condition, etc.)
#' @param image_url eBay Picture Services URL (already uploaded)
#' @param country ISO country code (e.g., "RO" for Romania)
#' @param location Text location (e.g., "Bucharest, Romania")
#' @return List suitable for EbayTradingAPI$add_fixed_price_item()
#' @export
build_trading_item_data <- function(card_id, ai_data, image_url, country, location) {
  # Truncate title to 80 chars (eBay limit)
  title <- substr(trimws(ai_data$title), 1, 80)

  # Map condition to Trading API ConditionID
  condition_id <- map_condition_to_trading_id(ai_data$condition)

  # Extract aspects (convert to Trading API format)
  # Capitalize condition for display in aspects (e.g., "fair" -> "Fair")
  condition_display <- paste0(toupper(substr(ai_data$condition, 1, 1)), substr(ai_data$condition, 2, nchar(ai_data$condition)))
  aspects <- extract_postcard_aspects(ai_data, condition_display)

  return(list(
    title = title,
    description = ai_data$description,
    country = country,
    location = location,
    category_id = 262042,  # Topographical Postcards
    price = format_ebay_price(ai_data$price),
    condition_id = condition_id,
    quantity = 1,
    images = list(image_url),
    aspects = aspects
  ))
}

#' Calculate Token Status for Display
#'
#' Analyzes token expiry timestamp and returns comprehensive status information
#' for UI display including color coding, icons, and time remaining.
#'
#' @param token_expiry POSIXct timestamp of token expiration (can be NULL)
#' @return List with status indicators and display text:
#'   - status: One of "healthy", "warning", "critical", "expired", "unknown"
#'   - alert_class: Bootstrap alert class for styling
#'   - icon: Shiny icon object with inline styling
#'   - status_text: Human-readable status message
#'   - time_remaining: Formatted time string (e.g., "in 1h 47m", "expired 2h ago")
#'   - needs_attention: Boolean indicating if user action required
#'
#' @details
#' Status thresholds:
#' - healthy: > 30 minutes remaining (green)
#' - warning: 5-30 minutes remaining (yellow)
#' - critical: < 5 minutes remaining (red)
#' - expired: Past expiry time (red)
#' - unknown: No expiry info available (gray)
#'
#' @examples
#' # Healthy token (2 hours remaining)
#' token_status <- get_token_status(Sys.time() + 7200)
#' # token_status$status == "healthy"
#' # token_status$time_remaining == "in 2h 0m"
#'
#' # Expiring soon (10 minutes remaining)
#' token_status <- get_token_status(Sys.time() + 600)
#' # token_status$status == "warning"
#' # token_status$needs_attention == TRUE
#' @export
get_token_status <- function(token_expiry) {
  # Handle NULL expiry (no token or unknown expiry)
  if (is.null(token_expiry)) {
    return(list(
      status = "unknown",
      alert_class = "alert-secondary",
      icon = shiny::icon("question-circle", style = "color: gray;"),
      status_text = "Unknown",
      time_remaining = "Unknown",
      needs_attention = TRUE
    ))
  }

  # Calculate time remaining
  now <- Sys.time()
  seconds_remaining <- as.numeric(difftime(token_expiry, now, units = "secs"))

  # Format time remaining for display
  if (seconds_remaining < 0) {
    # Token expired - show how long ago
    abs_seconds <- abs(seconds_remaining)
    if (abs_seconds < 3600) {
      # Less than 1 hour ago
      minutes <- round(abs_seconds / 60)
      time_remaining_detail <- sprintf("expired %d minute%s ago",
                                       minutes,
                                       ifelse(minutes == 1, "", "s"))
    } else {
      # More than 1 hour ago
      hours <- round(abs_seconds / 3600, 1)
      time_remaining_detail <- sprintf("expired %.1f hour%s ago",
                                       hours,
                                       ifelse(hours == 1, "", "s"))
    }
  } else if (seconds_remaining < 3600) {
    # Less than 1 hour remaining
    minutes <- round(seconds_remaining / 60)
    time_remaining_detail <- sprintf("in %d min", minutes)
  } else {
    # More than 1 hour remaining
    hours <- floor(seconds_remaining / 3600)
    minutes <- round((seconds_remaining %% 3600) / 60)
    time_remaining_detail <- sprintf("in %dh %dm", hours, minutes)
  }

  # Determine status level based on thresholds
  if (seconds_remaining < 0) {
    # EXPIRED
    return(list(
      status = "expired",
      alert_class = "alert-danger",
      icon = shiny::icon("times-circle", style = "color: red;"),
      status_text = "EXPIRED - Re-authorize Required",
      time_remaining = time_remaining_detail,
      needs_attention = TRUE
    ))
  } else if (seconds_remaining < 300) {
    # CRITICAL: Less than 5 minutes (300 seconds)
    return(list(
      status = "critical",
      alert_class = "alert-danger",
      icon = shiny::icon("exclamation-triangle", style = "color: red;"),
      status_text = "Expiring Imminently",
      time_remaining = time_remaining_detail,
      needs_attention = TRUE
    ))
  } else if (seconds_remaining < 1800) {
    # WARNING: Less than 30 minutes (1800 seconds)
    return(list(
      status = "warning",
      alert_class = "alert-warning",
      icon = shiny::icon("exclamation-circle", style = "color: orange;"),
      status_text = "Expiring Soon",
      time_remaining = time_remaining_detail,
      needs_attention = TRUE
    ))
  } else {
    # HEALTHY: 30+ minutes remaining
    return(list(
      status = "healthy",
      alert_class = "alert-success",
      icon = shiny::icon("check-circle", style = "color: green;"),
      status_text = "Active",
      time_remaining = time_remaining_detail,
      needs_attention = FALSE
    ))
  }
}
