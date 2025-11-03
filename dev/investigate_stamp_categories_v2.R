# eBay Stamp Category Investigation - Version 2
# Purpose: Retrieve and analyze stamp category hierarchy using direct httr2 calls
# Created: 2025-11-02

# Source required files
source("R/ebay_api.R")
library(xml2)
library(httr2)

cat("\n=== eBay STAMP CATEGORY INVESTIGATION (V2) ===\n\n")

# Initialize eBay API
cat("Step 1: Initializing eBay API...\n")

api_result <- tryCatch({
  init_ebay_api(environment = "production")
}, error = function(e) {
  cat("❌ Error initializing API:", e$message, "\n")
  NULL
})

if (is.null(api_result)) {
  stop("Cannot proceed without API initialization")
}

cat("✅ API initialized\n\n")

# Get credentials
oauth <- api_result$oauth
config <- api_result$config

# Build GetCategories request manually
cat("Step 2: Building GetCategories API request...\n")

# XML request body (no token in body for OAuth2)
xml_body <- '<?xml version="1.0" encoding="utf-8"?>
<GetCategoriesRequest xmlns="urn:ebay:apis:eBLBaseComponents">
  <CategoryParent>260</CategoryParent>
  <DetailLevel>ReturnAll</DetailLevel>
  <ViewAllNodes>true</ViewAllNodes>
  <LevelLimit>5</LevelLimit>
</GetCategoriesRequest>'

cat("✅ Request built\n\n")

# Make direct API call
cat("Step 3: Calling eBay Trading API...\n")
cat("This may take 10-30 seconds...\n\n")

# Get endpoint
endpoint <- if (config$environment == "production") {
  "https://api.ebay.com/ws/api.dll"
} else {
  "https://api.sandbox.ebay.com/ws/api.dll"
}

# Get OAuth token
token <- oauth$get_access_token()

if (is.null(token) || token == "") {
  stop("No OAuth token available. Please authenticate first.")
}

cat("   Endpoint:", endpoint, "\n")
cat("   Token:", substr(token, 1, 10), "...", substr(token, nchar(token)-9, nchar(token)), "\n\n")

# Make request
response <- tryCatch({
  req <- httr2::request(endpoint) |>
    httr2::req_headers(
      "X-EBAY-API-SITEID" = "0",  # 0 = US
      "X-EBAY-API-COMPATIBILITY-LEVEL" = "1355",
      "X-EBAY-API-CALL-NAME" = "GetCategories",
      "X-EBAY-API-IAF-TOKEN" = token,
      "Content-Type" = "text/xml"
    ) |>
    httr2::req_body_raw(xml_body, type = "text/xml") |>
    httr2::req_perform()

  response
}, error = function(e) {
  cat("❌ API Error:", e$message, "\n")
  NULL
})

if (is.null(response)) {
  stop("Failed to retrieve category data")
}

cat("✅ HTTP response received (Status:", httr2::resp_status(response), ")\n")

# Extract and parse XML
xml_string <- httr2::resp_body_string(response)
cat("✅ Response length:", nchar(xml_string), "characters\n\n")

# Check for errors in response
if (grepl("<Ack>Failure</Ack>", xml_string)) {
  cat("❌ API returned an error response\n")
  cat("Response preview:\n", substr(xml_string, 1, 1000), "\n")
  stop("API call failed")
}

# Parse XML
xml_doc <- xml2::read_xml(xml_string)
cat("✅ XML parsed successfully\n\n")

# Parse and display category tree
cat("Step 4: Analyzing category hierarchy...\n\n")

# Check for success
ack <- xml2::xml_text(xml2::xml_find_first(xml_doc, "//Ack"))
if (ack != "Success" && ack != "Warning") {
  cat("❌ API call was not successful. Ack:", ack, "\n")
  errors <- xml2::xml_find_all(xml_doc, "//Errors")
  if (length(errors) > 0) {
    for (error in errors) {
      error_code <- xml2::xml_text(xml2::xml_find_first(error, ".//ErrorCode"))
      error_msg <- xml2::xml_text(xml2::xml_find_first(error, ".//LongMessage"))
      cat("   Error", error_code, ":", error_msg, "\n")
    }
  }
  stop("API returned error")
}

cat("✅ API call successful (Ack:", ack, ")\n\n")

# Extract categories
categories <- xml2::xml_find_all(xml_doc, "//Category")

cat("=== STAMP CATEGORY HIERARCHY (Category 260) ===\n\n")
cat("Total categories found:", length(categories), "\n\n")

# Collect all categories for analysis
cat_data <- list()
leaf_categories <- list()

for (cat in categories) {
  cat_id <- xml2::xml_text(xml2::xml_find_first(cat, ".//CategoryID"))
  cat_name <- xml2::xml_text(xml2::xml_find_first(cat, ".//CategoryName"))
  cat_level <- xml2::xml_text(xml2::xml_find_first(cat, ".//CategoryLevel"))
  is_leaf <- xml2::xml_text(xml2::xml_find_first(cat, ".//LeafCategory"))
  cat_parent <- xml2::xml_text(xml2::xml_find_first(cat, ".//CategoryParentID"))

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
  cat("Found", length(leaf_categories), "leaf categories:\n\n")
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

# Save results
cat("\n=== SAVING RESULTS ===\n\n")

output_file <- "dev/stamp_category_hierarchy.rds"
saveRDS(list(
  raw_xml = xml_string,
  xml_doc = xml_doc,
  parsed_data = list(
    all = cat_data,
    leaf = leaf_categories
  ),
  timestamp = Sys.time()
), output_file)

cat("✅ Results saved to:", output_file, "\n")

# Also save as readable text
output_text <- "dev/stamp_category_hierarchy.txt"
sink(output_text)
cat("eBay Stamp Category Hierarchy\n")
cat("Retrieved:", as.character(Sys.time()), "\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

cat("Total categories:", length(categories), "\n")
cat("Leaf categories:", length(leaf_categories), "\n\n")

cat("CATEGORY TREE:\n\n")
for (cat in categories) {
  cat_id <- xml2::xml_text(xml2::xml_find_first(cat, ".//CategoryID"))
  cat_name <- xml2::xml_text(xml2::xml_find_first(cat, ".//CategoryName"))
  cat_level <- xml2::xml_text(xml2::xml_find_first(cat, ".//CategoryLevel"))
  is_leaf <- xml2::xml_text(xml2::xml_find_first(cat, ".//LeafCategory"))

  indent <- strrep("  ", as.integer(cat_level) - 1)
  leaf_marker <- if (is_leaf == "true") " [LEAF]" else ""

  cat(sprintf("%s%s (ID: %s)%s\n", indent, cat_name, cat_id, leaf_marker))
}

cat("\n\nLEAF CATEGORIES (can be used for listings):\n\n")
if (length(leaf_categories) > 0) {
  for (leaf in leaf_categories) {
    cat(sprintf("  %s (ID: %s)\n", leaf$name, leaf$id))
  }
} else {
  cat("  No leaf categories found\n")
}

sink()

cat("✅ Readable output saved to:", output_text, "\n")

cat("\n=== INVESTIGATION COMPLETE ===\n\n")

cat("Next Steps:\n")
cat("1. Review the results above\n")
cat("2. Check", output_text, "for full category tree\n")
cat("3. Identify the correct leaf category for your stamps\n")
cat("4. Update R/ebay_stamp_helpers.R to use the correct category ID\n\n")

# Return results for interactive use
invisible(list(
  all_categories = cat_data,
  leaf_categories = leaf_categories
))
