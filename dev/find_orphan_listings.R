# Find listings with fake/placeholder card_ids

library(DBI)
library(RSQLite)

con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")

cat("\n=== SEARCHING FOR ORPHAN LISTINGS ===\n\n")

# Get all listings
all_listings <- dbGetQuery(con, "
  SELECT listing_id, card_id, sku, title, status, listing_type, is_scheduled, schedule_time, created_at
  FROM ebay_listings
  ORDER BY created_at DESC
")

cat("Total listings:", nrow(all_listings), "\n\n")

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
  cat("Created:", all_listings$created_at[i], "\n")

  # Check if card_id looks like a placeholder
  card_id_str <- as.character(all_listings$card_id[i])
  if (grepl("CARD_", card_id_str)) {
    cat("⚠️  ORPHAN: This uses placeholder card_id pattern\n")
  }

  # Check SKU prefix
  sku <- all_listings$sku[i]
  if (grepl("^PC-", sku)) {
    cat("Type: Postcard (SKU prefix PC-)\n")
  } else if (grepl("^(ST-|STAMP-)", sku)) {
    cat("Type: Stamp (SKU prefix ST-/STAMP-)\n")
  } else {
    cat("Type: Unknown (SKU prefix:", substr(sku, 1, 5), ")\n")
  }

  cat("\n")
}

dbDisconnect(con)
cat("\n=== DIAGNOSTIC COMPLETE ===\n")
