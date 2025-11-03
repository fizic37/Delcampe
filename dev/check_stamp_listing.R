# Quick diagnostic to check stamp listing in database
# Run this in R console or RStudio

library(DBI)
library(RSQLite)

con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")

cat("\n=== CHECKING STAMP LISTING ===\n\n")

# Query all stamp listings
stamps <- dbGetQuery(con, "
  SELECT
    listing_id,
    sku,
    title,
    status,
    listing_type,
    is_scheduled,
    schedule_time,
    price,
    listing_duration,
    buy_it_now_price,
    reserve_price,
    ebay_item_id,
    created_at
  FROM ebay_listings
  WHERE sku LIKE 'ST-%' OR sku LIKE 'STAMP-%'
  ORDER BY created_at DESC
")

if (nrow(stamps) == 0) {
  cat("❌ NO STAMP LISTINGS FOUND\n")
  cat("\nChecking if ANY listings exist...\n")
  all <- dbGetQuery(con, "SELECT COUNT(*) as total FROM ebay_listings")
  cat("Total listings in database:", all$total, "\n")
} else {
  cat("✅ Found", nrow(stamps), "stamp listing(s)\n\n")

  for (i in 1:nrow(stamps)) {
    cat("--- Stamp Listing", i, "---\n")
    cat("SKU:", stamps$sku[i], "\n")
    cat("Title:", stamps$title[i], "\n")
    cat("Status:", stamps$status[i], "\n")
    cat("Listing Type:", stamps$listing_type[i], "\n")
    cat("Is Scheduled:", stamps$is_scheduled[i], "\n")
    cat("Schedule Time:", stamps$schedule_time[i], "\n")
    cat("Price:", stamps$price[i], "\n")
    cat("Duration:", stamps$listing_duration[i], "\n")
    cat("Buy It Now:", stamps$buy_it_now_price[i], "\n")
    cat("Reserve:", stamps$reserve_price[i], "\n")
    cat("eBay Item ID:", stamps$ebay_item_id[i], "\n")
    cat("Created:", stamps$created_at[i], "\n")
    cat("\n")

    # Check if it would be filtered out
    cat("Filter Analysis:\n")
    if (stamps$listing_type[i] != "auction") {
      cat("  ⚠️ WARNING: listing_type is '", stamps$listing_type[i],
          "' not 'auction' - will NOT show in Auction filter!\n", sep = "")
    } else {
      cat("  ✅ listing_type is 'auction' - should show in Auction filter\n")
    }

    if (!grepl("^(ST-|STAMP-)", stamps$sku[i])) {
      cat("  ⚠️ WARNING: SKU doesn't start with ST- or STAMP- - will show as Unknown type!\n")
    } else {
      cat("  ✅ SKU prefix is correct for Stamp type\n")
    }

    if (stamps$is_scheduled[i] == 1) {
      cat("  ✅ is_scheduled = 1 (should show in Scheduled filter)\n")
    } else {
      cat("  ⚠️ is_scheduled = 0 (will NOT show in Scheduled filter)\n")
    }
    cat("\n")
  }
}

dbDisconnect(con)
cat("\n=== DIAGNOSTIC COMPLETE ===\n")
