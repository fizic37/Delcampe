# Check all listings to see SKU patterns

library(DBI)
library(RSQLite)

con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")

cat("\n=== ALL 6 LISTINGS IN DATABASE ===\n\n")

all_listings <- dbGetQuery(con, "
  SELECT
    listing_id,
    card_id,
    sku,
    LEFT(title, 50) as title,
    status,
    listing_type,
    is_scheduled,
    schedule_time,
    price,
    ebay_item_id,
    api_type,
    created_at
  FROM ebay_listings
  ORDER BY created_at DESC
")

for (i in 1:nrow(all_listings)) {
  cat("--- Listing", i, "---\n")
  cat("Listing ID:", all_listings$listing_id[i], "\n")
  cat("Card ID:", all_listings$card_id[i], "\n")
  cat("SKU:", all_listings$sku[i], "\n")
  cat("Title:", all_listings$title[i], "\n")
  cat("Status:", all_listings$status[i], "\n")
  cat("Listing Type:", all_listings$listing_type[i], "\n")
  cat("Is Scheduled:", all_listings$is_scheduled[i], "\n")
  cat("Schedule Time:", all_listings$schedule_time[i], "\n")
  cat("Price:", all_listings$price[i], "\n")
  cat("eBay Item ID:", all_listings$ebay_item_id[i], "\n")
  cat("API Type:", all_listings$api_type[i], "\n")
  cat("Created:", all_listings$created_at[i], "\n")

  # Detect what type this would show as
  item_type <- if (grepl("^PC-", all_listings$sku[i])) {
    "Postcard"
  } else if (grepl("^(ST-|STAMP-)", all_listings$sku[i])) {
    "Stamp"
  } else {
    "Unknown"
  }
  cat("Detected Type:", item_type, "\n")
  cat("\n")
}

# Check stamps table for reference
cat("\n=== CHECKING STAMPS TABLE ===\n")
stamps_check <- dbGetQuery(con, "SELECT COUNT(*) as count FROM stamps")
cat("Total stamps in stamps table:", stamps_check$count, "\n")

if (stamps_check$count > 0) {
  recent_stamps <- dbGetQuery(con, "
    SELECT stamp_id, combined_image_path, created_at
    FROM stamps
    ORDER BY created_at DESC
    LIMIT 5
  ")
  cat("\nRecent stamps:\n")
  print(recent_stamps)
}

dbDisconnect(con)
cat("\n=== DIAGNOSTIC COMPLETE ===\n")
