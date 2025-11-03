# Find the missing stamp listing
# The stamp might have card_id that points to stamps table, not postal_cards

library(DBI)
library(RSQLite)

con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")

cat("\n=== SEARCHING FOR STAMP LISTING ===\n\n")

# First, check stamps table
cat("1. Checking stamps table:\n")
stamps <- dbGetQuery(con, "SELECT stamp_id, image_type, original_filename, first_seen FROM stamps")
if (nrow(stamps) > 0) {
  cat("   Found", nrow(stamps), "stamp(s) in stamps table:\n")
  print(stamps)
  cat("\n")

  # Try to find ebay_listing with these stamp_ids in card_id column
  cat("2. Checking if any ebay_listings have card_id matching stamp_ids:\n")
  for (stamp_id in stamps$stamp_id) {
    listing <- dbGetQuery(con, "
      SELECT * FROM ebay_listings
      WHERE card_id = ?
    ", list(stamp_id))

    if (nrow(listing) > 0) {
      cat("\n   ✅ FOUND! Stamp", stamp_id, "has eBay listing:\n")
      cat("      Listing ID:", listing$listing_id, "\n")
      cat("      SKU:", listing$sku, "\n")
      cat("      Title:", listing$title, "\n")
      cat("      Status:", listing$status, "\n")
      cat("      Listing Type:", listing$listing_type, "\n")
      cat("      Is Scheduled:", listing$is_scheduled, "\n")
      cat("      Schedule Time:", listing$schedule_time, "\n")
      cat("\n")

      # Analyze the SKU
      if (grepl("^PC-", listing$sku)) {
        cat("      ⚠️ PROBLEM: SKU starts with PC- (Postcard prefix)\n")
        cat("         This is why it shows as Postcard in the viewer!\n")
      } else if (grepl("^(ST-|STAMP-)", listing$sku)) {
        cat("      ✅ SKU correctly starts with ST- or STAMP-\n")
      } else {
        cat("      ⚠️ SKU has unexpected prefix:", substr(listing$sku, 1, 10), "\n")
      }
    }
  }
} else {
  cat("   No stamps found in stamps table\n")
}

# Also check all listings to see if any have scheduled auctions
cat("\n3. Checking for ANY scheduled auction listings:\n")
scheduled_auctions <- dbGetQuery(con, "
  SELECT * FROM ebay_listings
  WHERE listing_type = 'auction' AND is_scheduled = 1
")

if (nrow(scheduled_auctions) > 0) {
  cat("   Found", nrow(scheduled_auctions), "scheduled auction(s):\n")
  print(scheduled_auctions[, c("listing_id", "sku", "title", "status", "card_id")])
} else {
  cat("   No scheduled auctions found\n")
}

# Check for ANY auction listings
cat("\n4. Checking for ANY auction listings (scheduled or not):\n")
all_auctions <- dbGetQuery(con, "
  SELECT listing_id, sku, title, listing_type, is_scheduled, status
  FROM ebay_listings
  WHERE listing_type = 'auction'
")

if (nrow(all_auctions) > 0) {
  cat("   Found", nrow(all_auctions), "auction listing(s):\n")
  print(all_auctions)
} else {
  cat("   No auction listings found\n")
}

dbDisconnect(con)
cat("\n=== DIAGNOSTIC COMPLETE ===\n")
