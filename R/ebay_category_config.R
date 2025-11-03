#' eBay Category Configuration
#'
#' @description Known eBay leaf categories for stamps and postcards
#'
#' This file documents eBay category IDs found through research.
#' Category 260 (Stamps) is NOT a leaf category - must use subcategories.
#'
#' @name ebay_category_config
NULL

#' eBay Stamp Leaf Categories
#'
#' Known leaf categories under Stamps (260)
#' Source: Manual research 2025-11-02
#'
#' @export
EBAY_STAMP_CATEGORIES <- list(
  # US Stamps by Era
  US_19TH_CENTURY_USED = 675,      # Stamps > United States > 19th Century: Used
  US_SHEETS_1941_1950 = 265,       # Stamps > United States > Sheets > 1941-1950

  # TODO: Find these categories by browsing eBay:
  # US_1901_1940 = ???,
  # US_1941_1980 = ???,
  # US_1981_NOW = ???,
  # WORLDWIDE = ???,

  # Default fallback
  DEFAULT = 675  # Use 19th Century as default (covers most vintage)
)

#' eBay Postcard Leaf Categories
#'
#' @export
EBAY_POSTCARD_CATEGORIES <- list(
  TOPOGRAPHICAL = 262042,     # Working category
  NON_TOPOGRAPHICAL = 262043  # Alternative
)

#' Get appropriate stamp category based on data
#'
#' @param ai_data List with AI extraction data (year, country, etc.)
#' @return Numeric category ID (leaf category)
#' @export
get_stamp_category <- function(ai_data) {
  # TODO: Implement smarter logic based on:
  # - Year (map to era-specific categories)
  # - Country (US vs Worldwide)
  # - Type (sheets, plate blocks, etc.)

  # For now, use default
  return(EBAY_STAMP_CATEGORIES$DEFAULT)
}

#' Get appropriate postcard category
#'
#' @param ai_data List with AI extraction data
#' @return Numeric category ID (leaf category)
#' @export
get_postcard_category <- function(ai_data) {
  # Topographical is the default and working category
  return(EBAY_POSTCARD_CATEGORIES$TOPOGRAPHICAL)
}
