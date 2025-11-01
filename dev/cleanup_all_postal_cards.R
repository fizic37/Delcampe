#!/usr/bin/env Rscript
# Cleanup Script: Delete ALL postal card records from database
# Use this to test conditional AI prompts with a clean slate

cat("\n=== CLEANUP: DELETE ALL POSTAL CARD RECORDS ===\n\n")

con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")

# Count records before deletion
cat("Record counts BEFORE deletion:\n")
cards_count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM postal_cards")
cat("  postal_cards table:", cards_count$count, "records\n")

processing_count <- tryCatch({
  result <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM card_processing")
  result$count
}, error = function(e) 0)
cat("  card_processing table:", processing_count, "records\n")

# Ask for confirmation
cat("\n⚠️  WARNING: This will delete ALL postal card records!\n")
cat("   - All records in 'postal_cards' table\n")
cat("   - All records in 'card_processing' table\n")
cat("   - All postal card crop files\n\n")

response <- readline(prompt = "Type 'YES' to confirm deletion: ")

if (response != "YES") {
  cat("\n❌ Deletion cancelled.\n")
  DBI::dbDisconnect(con)
  quit(save = "no")
}

cat("\n🗑️  Deleting records...\n")

# Delete from card_processing first (foreign key constraint)
try({
  result <- DBI::dbExecute(con, "DELETE FROM card_processing")
  cat("  ✓ Deleted", result, "records from card_processing\n")
}, silent = FALSE)

# Delete from postal_cards
result <- DBI::dbExecute(con, "DELETE FROM postal_cards")
cat("  ✓ Deleted", result, "records from postal_cards\n")

# Reset auto-increment
DBI::dbExecute(con, "DELETE FROM sqlite_sequence WHERE name='postal_cards'")
cat("  ✓ Reset auto-increment counter\n")

DBI::dbDisconnect(con)

# Delete crop files
cat("\n🗑️  Deleting crop files...\n")
crop_base <- "inst/app/data/crops"
deleted_count <- 0

for (type in c("face", "verso", "combined", "lot")) {
  type_dir <- file.path(crop_base, type)
  if (dir.exists(type_dir)) {
    # Get all card ID directories
    card_dirs <- list.dirs(type_dir, full.names = TRUE, recursive = FALSE)
    for (dir in card_dirs) {
      # Only delete if it's a numeric directory (card/stamp ID)
      if (grepl("^[0-9]+$", basename(dir))) {
        unlink(dir, recursive = TRUE)
        deleted_count <- deleted_count + 1
      }
    }
  }
}
cat("  ✓ Deleted", deleted_count, "crop directories\n")

# Verify deletion
cat("\n✅ Verification:\n")
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
cards_count_after <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM postal_cards")
cat("  postal_cards table:", cards_count_after$count, "records (should be 0)\n")

processing_count_after <- tryCatch({
  result <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM card_processing")
  result$count
}, error = function(e) 0)
cat("  card_processing table:", processing_count_after, "records (should be 0)\n")

DBI::dbDisconnect(con)

cat("\n✅ Done! All postal card records deleted.\n")
cat("   You can now test conditional AI prompts with a clean slate.\n\n")
