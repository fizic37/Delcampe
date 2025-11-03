#' eBay Stamp Helpers
#'
#' @description Functions for mapping stamp data to eBay category 260 (Stamps)
#'
#' This module provides stamp-specific eBay integration, including condition mapping,
#' aspect extraction, and item data building for the Trading API.
#'
#' @name ebay_stamp_helpers
NULL

#' Map Stamp Grade to eBay Condition
#'
#' @description Converts philatelic grade to eBay condition code
#'
#' @param grade Character: Grade from AI extraction (MNH, MH, Used, Unused)
#' @return Character: eBay condition code
#' @export
map_stamp_grade_to_ebay <- function(grade) {
  if (is.null(grade) || is.na(grade)) {
    return("UNSPECIFIED")
  }

  grade_upper <- toupper(trimws(grade))

  # Use "USED" for all grades to avoid Error 25019 (per postal card pattern)
  # eBay's condition requirements for cross-border listings are strict
  if (grade_upper == "MNH" || grepl("NEVER.*HINGED", grade_upper)) {
    return("USED")
  } else if (grade_upper == "MH" || grepl("MINT.*HINGED", grade_upper)) {
    return("USED")
  } else if (grepl("USED", grade_upper)) {
    return("USED")
  } else if (grepl("UNUSED", grade_upper)) {
    return("USED")
  } else {
    return("UNSPECIFIED")
  }
}

#' Extract Stamp Aspects for eBay
#'
#' @description Builds eBay ItemSpecifics for stamp listings
#'
#' @param ai_data List: AI extraction data
#' @param condition_code Character: eBay condition code (optional)
#' @return List: eBay aspects/ItemSpecifics
#' @export
extract_stamp_aspects <- function(ai_data, condition_code = NULL) {

  aspects <- list()

  # Type (required for stamps)
  if (!is.null(ai_data$stamp_count) && ai_data$stamp_count > 1) {
    aspects[["Type"]] <- list("Lot")
  } else {
    aspects[["Type"]] <- list("Individual Stamp")
  }

  # Country
  if (!is.null(ai_data$country) && !is.na(ai_data$country)) {
    aspects[["Country/Region of Manufacture"]] <- list(ai_data$country)
  }

  # Year
  if (!is.null(ai_data$year) && !is.na(ai_data$year)) {
    aspects[["Year of Issue"]] <- list(as.character(ai_data$year))
  }

  # Grade (critical for stamps) - REQUIRED by many categories
  if (!is.null(ai_data$grade) && !is.na(ai_data$grade) && ai_data$grade != "") {
    aspects[["Grade"]] <- list(ai_data$grade)
  } else {
    # Default to "Ungraded" if not provided
    aspects[["Grade"]] <- list("Ungraded")
  }

  # Quality (required by some stamp categories like India) - NEW separate field
  if (!is.null(ai_data$quality) && !is.na(ai_data$quality) && ai_data$quality != "") {
    aspects[["Quality"]] <- list(ai_data$quality)
  } else {
    # Default to "Used" if not provided (most vintage stamps are used)
    aspects[["Quality"]] <- list("Used")
  }

  # Certification (default to uncertified)
  aspects[["Certification"]] <- list("Uncertified")

  # Denomination
  if (!is.null(ai_data$denomination) && !is.na(ai_data$denomination)) {
    aspects[["Denomination"]] <- list(ai_data$denomination)
  }

  # Scott Number (if available)
  if (!is.null(ai_data$scott_number) && !is.na(ai_data$scott_number)) {
    aspects[["Catalog Number"]] <- list(ai_data$scott_number)
  }

  # Perforation (if available)
  if (!is.null(ai_data$perforation) && !is.na(ai_data$perforation)) {
    aspects[["Perforation"]] <- list(ai_data$perforation)
  }

  return(aspects)
}

#' Build eBay Stamp Item Data (using Trading API)
#'
#' @description Creates Trading API item structure for stamp listings
#'
#' @param ai_data List: AI extraction results
#' @param image_urls List: Uploaded image URLs
#' @param price_usd Numeric: Price in USD
#' @param quantity Integer: Number of items
#' @return List: Formatted for eBay Trading API
#' @export
build_stamp_item_data <- function(ai_data, image_urls, price_usd, quantity = 1) {

  # Determine condition (use same logic as postal cards to avoid Error 25019)
  condition_code <- if (!is.null(ai_data$grade)) {
    map_stamp_grade_to_ebay(ai_data$grade)
  } else {
    "USED"  # Safe default
  }

  # Extract aspects
  aspects <- extract_stamp_aspects(ai_data, condition_code)

  # Build item data (exact same structure as postal cards)
  item_data <- list(
    Title = ai_data$title,
    Description = ai_data$description,
    PrimaryCategory = list(CategoryID = "260"),  # STAMPS CATEGORY
    StartPrice = price_usd,
    Quantity = quantity,
    Country = "US",
    Currency = "USD",
    ConditionID = "3000",  # 3000 = Used (safest for stamps per postal card pattern)
    ItemSpecifics = list(
      NameValueList = lapply(names(aspects), function(name) {
        list(Name = name, Value = aspects[[name]])
      })
    ),
    PictureDetails = list(
      PictureURL = image_urls
    ),
    ListingDuration = "Days_7",
    ListingType = "FixedPriceItem",
    PaymentMethods = "PayPal",
    PayPalEmailAddress = Sys.getenv("EBAY_PAYPAL_EMAIL", ""),
    PostalCode = Sys.getenv("EBAY_POSTAL_CODE", ""),
    ShippingDetails = list(
      ShippingType = "Flat",
      ShippingServiceOptions = list(
        list(
          ShippingService = "USPSFirstClass",
          ShippingServiceCost = 1.50  # Stamps are lightweight
        )
      )
    ),
    ReturnPolicy = list(
      ReturnsAcceptedOption = "ReturnsAccepted",
      RefundOption = "MoneyBack",
      ReturnsWithinOption = "Days_30",
      ShippingCostPaidByOption = "Buyer"
    )
  )

  return(item_data)
}

message("✅ eBay stamp helpers loaded!")
