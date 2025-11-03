# Investigation script for eBay Listings issues
# Run this to check database state

library(DBI)
library(RSQLite)

con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")

cat("\n========== ALL EBAY LISTINGS ==========\n")
all_listings <- dbGetQuery(con, "
  SELECT
    listing_id,
    sku,
    LEFT(title, 40) as title,
    status,
    listing_type,
    is_scheduled,
    schedule_time,
    listed_at,
    ebay_item_id
  FROM ebay_listings
  ORDER BY created_at DESC
")
print(all_listings)

cat("\n========== SCHEDULED LISTINGS ==========\n")
scheduled <- dbGetQuery(con, "
  SELECT
    listing_id,
    sku,
    title,
    status,
    listing_type,
    is_scheduled,
    schedule_time
  FROM ebay_listings
  WHERE is_scheduled = 1
")
if (nrow(scheduled) > 0) {
  print(scheduled)
} else {
  cat("No scheduled listings found\n")
}

cat("\n========== AUCTION LISTINGS ==========\n")
auctions <- dbGetQuery(con, "
  SELECT
    listing_id,
    sku,
    title,
    status,
    listing_type,
    price as starting_price,
    is_scheduled
  FROM ebay_listings
  WHERE listing_type = 'auction'
")
if (nrow(auctions) > 0) {
  print(auctions)
} else {
  cat("No auction listings found\n")
}

cat("\n========== LISTINGS WITH STATUS 'listed' ==========\n")
listed_status <- dbGetQuery(con, "
  SELECT
    listing_id,
    sku,
    LEFT(title, 40) as title,
    status,
    listing_type,
    ebay_item_id,
    listed_at
  FROM ebay_listings
  WHERE status = 'listed'
")
if (nrow(listed_status) > 0) {
  print(listed_status)
} else {
  cat("No listings with status='listed' found\n")
}

cat("\n========== SKU PREFIX ANALYSIS ==========\n")
sku_analysis <- dbGetQuery(con, "
  SELECT
    CASE
      WHEN sku LIKE 'PC-%' THEN 'Postcard'
      WHEN sku LIKE 'ST-%' THEN 'Stamp'
      WHEN sku LIKE 'STAMP-%' THEN 'Stamp'
      ELSE 'Unknown'
    END as item_type,
    COUNT(*) as count
  FROM ebay_listings
  GROUP BY item_type
")
print(sku_analysis)

dbDisconnect(con)
