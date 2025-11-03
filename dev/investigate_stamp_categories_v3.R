# eBay Stamp Category Investigation - Version 3 (Simplified Debug)
# Purpose: Retrieve stamp category hierarchy with better error handling

source("R/ebay_api.R")
library(xml2)
library(httr2)

cat("\n=== eBay STAMP CATEGORY INVESTIGATION (V3) ===\n\n")

# Initialize eBay API
cat("Step 1: Initializing eBay API...\n")

api_result <- init_ebay_api(environment = "production")
cat("✅ API initialized\n\n")

# Get credentials
oauth <- api_result$oauth
config <- api_result$config

# Build XML request
xml_body <- '<?xml version="1.0" encoding="utf-8"?>
<GetCategoriesRequest xmlns="urn:ebay:apis:eBLBaseComponents">
  <CategoryParent>260</CategoryParent>
  <DetailLevel>ReturnAll</DetailLevel>
  <ViewAllNodes>true</ViewAllNodes>
  <LevelLimit>5</LevelLimit>
</GetCategoriesRequest>'

cat("Step 2: Making API call...\n")

# Get endpoint
endpoint <- if (config$environment == "production") {
  "https://api.ebay.com/ws/api.dll"
} else {
  "https://api.sandbox.ebay.com/ws/api.dll"
}

# Get token
token <- oauth$get_access_token()
cat("   Token length:", nchar(token), "\n")
cat("   Endpoint:", endpoint, "\n\n")

# Build and execute request
cat("Step 3: Executing request...\n")

req <- httr2::request(endpoint) |>
  httr2::req_headers(
    "X-EBAY-API-SITEID" = "0",
    "X-EBAY-API-COMPATIBILITY-LEVEL" = "1355",
    "X-EBAY-API-CALL-NAME" = "GetCategories",
    "X-EBAY-API-IAF-TOKEN" = token,
    "Content-Type" = "text/xml"
  ) |>
  httr2::req_body_raw(xml_body, type = "text/xml")

cat("   Request built, performing...\n")

http_response <- httr2::req_perform(req)

cat("✅ Response received\n")
cat("   Status:", httr2::resp_status(http_response), "\n")
cat("   Content-Type:", httr2::resp_header(http_response, "Content-Type"), "\n\n")

# Extract XML
cat("Step 4: Parsing response...\n")

xml_string <- httr2::resp_body_string(http_response)
cat("   Response length:", nchar(xml_string), "characters\n")

# Parse XML
xml_doc <- xml2::read_xml(xml_string)

# Check for success
ack <- xml2::xml_text(xml2::xml_find_first(xml_doc, "//Ack"))
cat("   Ack:", ack, "\n")

if (ack != "Success" && ack != "Warning") {
  cat("\n❌ API Error Response:\n")
  errors <- xml2::xml_find_all(xml_doc, "//Errors")
  for (error in errors) {
    code <- xml2::xml_text(xml2::xml_find_first(error, ".//ErrorCode"))
    msg <- xml2::xml_text(xml2::xml_find_first(error, ".//LongMessage"))
    cat("   Error", code, ":", msg, "\n")
  }
  stop("API returned error")
}

cat("\n✅ API call successful\n\n")

# Extract and analyze categories
cat("Step 5: Analyzing category hierarchy...\n\n")

categories <- xml2::xml_find_all(xml_doc, "//Category")
cat("Total categories found:", length(categories), "\n\n")

cat("=== CATEGORY TREE ===\n\n")

leaf_categories <- list()

for (cat in categories) {
  cat_id <- xml2::xml_text(xml2::xml_find_first(cat, ".//CategoryID"))
  cat_name <- xml2::xml_text(xml2::xml_find_first(cat, ".//CategoryName"))
  cat_level <- xml2::xml_text(xml2::xml_find_first(cat, ".//CategoryLevel"))
  is_leaf <- xml2::xml_text(xml2::xml_find_first(cat, ".//LeafCategory"))

  indent <- strrep("  ", as.integer(cat_level) - 1)
  leaf_marker <- if (is_leaf == "true") " [LEAF ✓]" else ""

  cat(sprintf("%s%s (ID: %s)%s\n", indent, cat_name, cat_id, leaf_marker))

  # Collect leaf categories
  if (is_leaf == "true") {
    leaf_categories[[cat_id]] <- list(
      id = cat_id,
      name = cat_name,
      level = cat_level
    )
  }
}

cat("\n=== LEAF CATEGORIES (Can be used for listings) ===\n\n")

if (length(leaf_categories) > 0) {
  cat("Found", length(leaf_categories), "leaf categories:\n\n")
  for (leaf in leaf_categories) {
    cat(sprintf("  • %s (ID: %s)\n", leaf$name, leaf$id))
  }
} else {
  cat("⚠️ No leaf categories found!\n")
}

# Save results
cat("\n=== SAVING RESULTS ===\n\n")

saveRDS(list(
  raw_xml = xml_string,
  xml_doc = xml_doc,
  leaf_categories = leaf_categories,
  timestamp = Sys.time()
), "dev/stamp_category_hierarchy.rds")

cat("✅ Saved to: dev/stamp_category_hierarchy.rds\n")

# Save text output
sink("dev/stamp_category_hierarchy.txt")
cat("eBay Stamp Category Hierarchy\n")
cat("Retrieved:", as.character(Sys.time()), "\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

cat("LEAF CATEGORIES:\n\n")
for (leaf in leaf_categories) {
  cat(sprintf("  %s (ID: %s)\n", leaf$name, leaf$id))
}

cat("\n\nFULL TREE:\n\n")
for (cat in categories) {
  cat_id <- xml2::xml_text(xml2::xml_find_first(cat, ".//CategoryID"))
  cat_name <- xml2::xml_text(xml2::xml_find_first(cat, ".//CategoryName"))
  cat_level <- xml2::xml_text(xml2::xml_find_first(cat, ".//CategoryLevel"))
  is_leaf <- xml2::xml_text(xml2::xml_find_first(cat, ".//LeafCategory"))

  indent <- strrep("  ", as.integer(cat_level) - 1)
  leaf_marker <- if (is_leaf == "true") " [LEAF]" else ""

  cat(sprintf("%s%s (ID: %s)%s\n", indent, cat_name, cat_id, leaf_marker))
}
sink()

cat("✅ Saved to: dev/stamp_category_hierarchy.txt\n\n")

cat("=== INVESTIGATION COMPLETE ===\n\n")
cat("Next: Check the output above for leaf categories\n")
cat("Then update R/ebay_integration.R to use a leaf category ID\n\n")

invisible(leaf_categories)
