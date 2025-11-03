# Process eBay Stamp Categories from Official CSV
# Source: https://ir.ebaystatic.com/pictures/aw/pics/pdf/us/file_exchange/CategoryIDs-US.csv

library(dplyr)
library(stringr)

cat("\n=== PROCESSING EBAY STAMP CATEGORIES ===\n\n")

# Read the stamp categories
stamp_cats <- read.csv("dev/stamp_categories_only.csv", header = FALSE, col.names = c("CategoryID", "CategoryPath"))

cat("Total stamp categories:", nrow(stamp_cats), "\n\n")

# Parse the category hierarchy
stamp_cats <- stamp_cats %>%
  mutate(
    # Split the path
    Region = str_extract(CategoryPath, "Stamps > ([^>]+)") %>% str_remove("Stamps > "),
    Country = str_extract(CategoryPath, "Stamps > [^>]+ > ([^>]+)") %>% str_remove("Stamps > [^>]+ > "),
    Subcategory = str_extract(CategoryPath, "Stamps > [^>]+ > [^>]+ > ([^>]+)") %>% str_remove("Stamps > [^>]+ > [^>]+ > "),
    Level = str_count(CategoryPath, ">") + 1
  )

# Show regions
cat("=== REGIONS ===\n\n")
regions <- stamp_cats %>%
  filter(Level == 2) %>%  # Top level under Stamps
  select(CategoryID, Region) %>%
  arrange(Region)

print(regions, n = Inf)

# Show countries per region (sample)
cat("\n\n=== SAMPLE: UNITED STATES CATEGORIES ===\n\n")
us_cats <- stamp_cats %>%
  filter(Region == "United States") %>%
  select(CategoryID, Country, Subcategory, CategoryPath)

print(head(us_cats, 20), n = 20)

# Create region mapping for R code
cat("\n\n=== R CODE: REGION CATEGORIES ===\n\n")

cat("# Top-level regional categories\n")
cat("EBAY_STAMP_REGIONS <- list(\n")

region_list <- stamp_cats %>%
  filter(Level == 2) %>%
  arrange(Region)

for (i in 1:nrow(region_list)) {
  region_name <- region_list$Region[i]
  cat_id <- region_list$CategoryID[i]

  # Create R-friendly variable name
  var_name <- toupper(gsub("[^A-Za-z0-9]", "_", region_name))
  var_name <- gsub("_+", "_", var_name)
  var_name <- gsub("^_|_$", "", var_name)

  comma <- if (i < nrow(region_list)) "," else ""
  cat(sprintf("  %s = %s%s  # %s\n", var_name, cat_id, comma, region_name))
}
cat(")\n\n")

# Create country mapping for major regions
cat("# Country categories (US, Canada, Great Britain, Europe)\n")
cat("EBAY_STAMP_COUNTRIES <- list(\n")

# Get specific country categories
country_cats <- stamp_cats %>%
  filter(Level == 3, !is.na(Country)) %>%
  filter(Region %in% c("United States", "Canada", "Great Britain", "Europe", "Asia", "Africa")) %>%
  select(Region, Country, CategoryID) %>%
  arrange(Region, Country)

for (i in 1:min(50, nrow(country_cats))) {  # Limit to first 50 for readability
  region <- country_cats$Region[i]
  country <- country_cats$Country[i]
  cat_id <- country_cats$CategoryID[i]

  # Create variable name
  var_name <- paste(region, country, sep = "_") %>%
    toupper() %>%
    gsub("[^A-Za-z0-9]", "_", .) %>%
    gsub("_+", "_", .) %>%
    gsub("^_|_$", "", .)

  comma <- if (i < min(50, nrow(country_cats))) "," else ""
  cat(sprintf("  %s = %s%s  # %s > %s\n", var_name, cat_id, comma, region, country))
}
cat("  # ... (388 more categories in full list)\n")
cat(")\n\n")

# Save complete list
saveRDS(stamp_cats, "dev/stamp_categories_parsed.rds")
write.csv(stamp_cats, "dev/stamp_categories_parsed.csv", row.names = FALSE)

cat("✅ Saved to:\n")
cat("   - dev/stamp_categories_parsed.rds\n")
cat("   - dev/stamp_categories_parsed.csv\n\n")

cat("=== KEY CATEGORIES FOR IMPLEMENTATION ===\n\n")

# Most commonly needed categories
key_cats <- stamp_cats %>%
  filter(
    (Region == "United States" & Level == 3 & str_detect(Country, "19th|1901|1941|Postage")) |
    (Region == "Europe" & Level == 2) |
    (Region == "Asia" & Level == 2) |
    (Region == "Africa" & Level == 2) |
    (Region == "Latin America" & Level == 2) |
    (Region == "Canada" & Level == 2) |
    (Region == "Great Britain" & Level == 2)
  ) %>%
  select(CategoryID, CategoryPath)

cat("Recommended categories for dropdown:\n\n")
print(key_cats, n = Inf)

invisible(stamp_cats)
