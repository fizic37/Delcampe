# eBay Stamp Category Investigation
# Purpose: Retrieve and analyze stamp category hierarchy
# Created: 2025-11-02

# Source required files directly
source("R/ebay_api.R")
source("R/ebay_trading_api.R")
library(xml2)
library(httr2)
library(R6)

cat("\n=== eBay STAMP CATEGORY INVESTIGATION ===\n\n")

# Initialize eBay API (using production, not sandbox)
cat("Step 1: Initializing eBay API...\n")

api_result <- tryCatch({
  init_ebay_api(environment = "production")
}, error = function(e) {
  cat("❌ Error initializing API:", e$message, "\n")
  cat("\nPlease ensure eBay credentials are set in your environment\n")
  NULL
})

if (is.null(api_result)) {
  stop("Cannot proceed without API initialization")
}

# Get the trading API instance
api <- api_result$trading

cat("✅ API initialized\n\n")

# Fetch stamp category hierarchy
cat("Step 2: Fetching stamp category hierarchy (Category 260)...\n")
cat("This may take 10-30 seconds...\n\n")

get_stamp_categories <- function(api) {
  # Build GetCategories XML request
  # NOTE: With OAuth2/IAF, we don't put token in XML body
  request_body <- '<?xml version="1.0" encoding="utf-8"?>
  <GetCategoriesRequest xmlns="urn:ebay:apis:eBLBaseComponents">
    <CategoryParent>260</CategoryParent>
    <DetailLevel>ReturnAll</DetailLevel>
    <ViewAllNodes>true</ViewAllNodes>
    <LevelLimit>5</LevelLimit>
  </GetCategoriesRequest>'

  # Make API call using Trading API's make_request method
  response <- tryCatch({
    api$make_request(request_body, "GetCategories")
  }, error = function(e) {
    cat("❌ API Error:", e$message, "\n")
    NULL
  })

  return(response)
}

http_response <- get_stamp_categories(api)

if (is.null(http_response)) {
  stop("Failed to retrieve category data")
}

cat("✅ HTTP response received\n")

# Extract XML from HTTP response
xml_string <- httr2::resp_body_string(http_response)
cat("✅ Response length:", nchar(xml_string), "characters\n\n")

# Parse XML
xml_doc <- xml2::read_xml(xml_string)

cat("✅ XML parsed successfully\n\n")

# Parse and display category tree
cat("Step 3: Parsing category tree...\n\n")

parse_category_tree <- function(xml_doc) {
  categories <- xml2::xml_find_all(xml_doc, "//Category")

  cat("=== STAMP CATEGORY HIERARCHY (Category 260) ===\n\n")
  cat("Total categories found:", length(categories), "\n\n")

  # Collect all categories for analysis
  cat_data <- list()
  leaf_categories <- list()

  for (cat in categories) {
    cat_id <- xml_text(xml_find_first(cat, ".//CategoryID"))
    cat_name <- xml_text(xml_find_first(cat, ".//CategoryName"))
    cat_level <- xml_text(xml_find_first(cat, ".//CategoryLevel"))
    is_leaf <- xml_text(xml_find_first(cat, ".//LeafCategory"))
    cat_parent <- xml_text(xml_find_first(cat, ".//CategoryParentID"))

    indent <- strrep("  ", as.integer(cat_level) - 1)
    leaf_marker <- if (is_leaf == "true") " [LEAF ✓]" else ""

    cat(sprintf("%s%s (ID: %s)%s\n", indent, cat_name, cat_id, leaf_marker))

    # Store data
    cat_data[[cat_id]] <- list(
      id = cat_id,
      name = cat_name,
      level = cat_level,
      is_leaf = is_leaf,
      parent = cat_parent
    )

    # Track leaf categories
    if (is_leaf == "true") {
      leaf_categories[[cat_id]] <- list(
        id = cat_id,
        name = cat_name,
        level = cat_level,
        parent = cat_parent
      )
    }
  }

  cat("\n=== LEAF CATEGORIES SUMMARY ===\n")
  cat("(These are the categories where stamps can be listed)\n\n")

  if (length(leaf_categories) > 0) {
    for (leaf in leaf_categories) {
      cat(sprintf("  • %s (ID: %s)\n", leaf$name, leaf$id))
    }
  } else {
    cat("  ⚠️ No leaf categories found!\n")
  }

  cat("\n=== KEY INSIGHTS ===\n\n")

  # Check if 260 itself is a leaf
  if ("260" %in% names(cat_data)) {
    if (cat_data[["260"]]$is_leaf == "true") {
      cat("✅ Category 260 IS a leaf category - current code is correct\n")
    } else {
      cat("❌ Category 260 IS NOT a leaf category - MUST use subcategory!\n")
      cat("   Current implementation will likely fail or be auto-reassigned\n")
    }
  }

  # Look for US stamps category
  us_cats <- Filter(function(x) grepl("United States", x$name, ignore.case = TRUE), cat_data)
  if (length(us_cats) > 0) {
    cat("\n📌 United States stamp categories found:\n")
    for (us_cat in us_cats) {
      leaf_status <- if (us_cat$is_leaf == "true") "[LEAF ✓]" else "[Parent]"
      cat(sprintf("   • %s (ID: %s) %s\n", us_cat$name, us_cat$id, leaf_status))
    }
  }

  # Look for worldwide/international categories
  world_cats <- Filter(function(x) grepl("World|International|Worldwide", x$name, ignore.case = TRUE), cat_data)
  if (length(world_cats) > 0) {
    cat("\n🌍 Worldwide stamp categories found:\n")
    for (world_cat in world_cats) {
      leaf_status <- if (world_cat$is_leaf == "true") "[LEAF ✓]" else "[Parent]"
      cat(sprintf("   • %s (ID: %s) %s\n", world_cat$name, world_cat$id, leaf_status))
    }
  }

  return(list(
    all = cat_data,
    leaf = leaf_categories
  ))
}

category_data <- parse_category_tree(xml_doc)

# Save results
cat("\n=== SAVING RESULTS ===\n\n")

output_file <- "dev/stamp_category_hierarchy.rds"
saveRDS(list(
  raw_xml = xml_string,
  xml_doc = xml_doc,
  parsed_data = category_data,
  timestamp = Sys.time()
), output_file)

cat("✅ Results saved to:", output_file, "\n")

# Also save as readable text
output_text <- "dev/stamp_category_hierarchy.txt"
sink(output_text)
cat("eBay Stamp Category Hierarchy\n")
cat("Retrieved:", as.character(Sys.time()), "\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")
parse_category_tree(xml_doc)
sink()

cat("✅ Readable output saved to:", output_text, "\n")

cat("\n=== INVESTIGATION COMPLETE ===\n\n")

cat("Next Steps:\n")
cat("1. Review the leaf categories above\n")
cat("2. Identify which category is appropriate for US stamps\n")
cat("3. Identify which category is appropriate for international stamps\n")
cat("4. Update R/ebay_stamp_helpers.R to use the correct leaf category\n")
cat("5. Test with sample stamp listings\n\n")

# Return category data for interactive use
invisible(category_data)
