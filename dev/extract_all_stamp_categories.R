# Extract Complete eBay Stamp Category Hierarchy
# Purpose: Get ALL stamp categories (regions and countries) with their IDs

library(httr2)
library(xml2)
library(jsonlite)

cat("\n=== EXTRACTING ALL STAMP CATEGORIES ===\n\n")

# Approach: Use eBay's page source which contains category data in JSON

cat("Step 1: Fetching stamps main page...\n")

url <- "https://www.ebay.com/b/Stamps/260/bn_1865095"
response <- httr2::request(url) |>
  httr2::req_headers(
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
  ) |>
  httr2::req_perform()

html_content <- httr2::resp_body_string(response)

cat("✅ Page fetched\n\n")

# Extract the sidebar category links
cat("Step 2: Extracting category links...\n")

# Parse HTML
html_doc <- xml2::read_html(html_content)

# Find all category links in the sidebar
category_links <- xml2::xml_find_all(html_doc, "//a[contains(@href, '/b/') and contains(@href, '-Stamps/')]")

cat("Found", length(category_links), "category links\n\n")

# Extract category data
categories <- list()

for (link in category_links) {
  href <- xml2::xml_attr(link, "href")
  text <- xml2::xml_text(link)

  # Extract category ID from URL pattern: /b/Name/ID/bn_
  if (grepl("/b/[^/]+/([0-9]+)/", href)) {
    cat_id <- sub(".*/b/[^/]+/([0-9]+)/.*", "\\1", href)
    cat_name <- trimws(text)

    if (cat_name != "" && cat_id != "") {
      categories[[cat_name]] <- list(
        name = cat_name,
        id = as.numeric(cat_id),
        url = href
      )
    }
  }
}

cat("\n=== EXTRACTED CATEGORIES ===\n\n")

# Sort by name
categories <- categories[order(names(categories))]

for (cat in categories) {
  cat(sprintf("%-40s ID: %s\n", cat$name, cat$id))
}

# Save as JSON
output_json <- "dev/stamp_categories_all.json"
write(toJSON(categories, pretty = TRUE, auto_unbox = TRUE), output_json)
cat("\n✅ Saved to:", output_json, "\n")

# Save as R data
output_rds <- "dev/stamp_categories_all.rds"
saveRDS(categories, output_rds)
cat("✅ Saved to:", output_rds, "\n")

# Create R code snippet for easy integration
cat("\n=== R CODE FOR INTEGRATION ===\n\n")

cat("EBAY_STAMP_CATEGORIES <- list(\n")
for (i in seq_along(categories)) {
  cat_name <- names(categories)[i]
  cat_id <- categories[[i]]$id

  # Create R-friendly variable name
  var_name <- toupper(gsub("[^A-Za-z0-9]", "_", cat_name))
  var_name <- gsub("_+", "_", var_name)  # Remove duplicate underscores
  var_name <- gsub("_$", "", var_name)  # Remove trailing underscore

  comma <- if (i < length(categories)) "," else ""
  cat(sprintf("  %s = %s%s  # %s\n", var_name, cat_id, comma, cat_name))
}
cat(")\n")

cat("\n=== EXTRACTION COMPLETE ===\n\n")
cat("Total categories found:", length(categories), "\n")
cat("Next: Review the output and integrate into R/ebay_category_config.R\n")

invisible(categories)
