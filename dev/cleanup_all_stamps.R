#!/usr/bin/env Rscript
# Cleanup Script: Delete ALL stamp records from database
# Use this to test conditional AI prompts with a clean slate

cat("\n=== CLEANUP: DELETE ALL STAMP RECORDS ===\n\n")

con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")

# Count records before deletion
cat("Record counts BEFORE deletion:\n")
stamps_count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM stamps")
cat("  stamps table:", stamps_count$count, "records\n")

processing_count <- tryCatch({
  result <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM stamp_processing")
  result$count
}, error = function(e) 0)
cat("  stamp_processing table:", processing_count, "records\n")

# Ask for confirmation
cat("\n⚠️  WARNING: This will delete ALL stamp records!\n")
cat("   - All records in 'stamps' table\n")
cat("   - All records in 'stamp_processing' table\n")
cat("   - All stamp crop files\n\n")

response <- readline(prompt = "Type 'YES' to confirm deletion: ")

if (response != "YES") {
  cat("\n❌ Deletion cancelled.\n")
  DBI::dbDisconnect(con)
  quit(save = "no")
}

cat("\n🗑️  Deleting records...\n")

# Delete from stamp_processing first (foreign key constraint)
try({
  result <- DBI::dbExecute(con, "DELETE FROM stamp_processing")
  cat("  ✓ Deleted", result, "records from stamp_processing\n")
}, silent = FALSE)

# Delete from stamps
result <- DBI::dbExecute(con, "DELETE FROM stamps")
cat("  ✓ Deleted", result, "records from stamps\n")

# Reset auto-increment
DBI::dbExecute(con, "DELETE FROM sqlite_sequence WHERE name='stamps'")
cat("  ✓ Reset auto-increment counter\n")

DBI::dbDisconnect(con)

# Delete crop files
cat("\n🗑️  Deleting crop files...\n")
crop_base <- "inst/app/data/crops"
deleted_count <- 0

for (type in c("face", "verso", "combined", "lot")) {
  type_dir <- file.path(crop_base, type)
  if (dir.exists(type_dir)) {
    # Get all stamp ID directories
    stamp_dirs <- list.dirs(type_dir, full.names = TRUE, recursive = FALSE)
    for (dir in stamp_dirs) {
      unlink(dir, recursive = TRUE)
      deleted_count <- deleted_count + 1
    }
  }
}
cat("  ✓ Deleted", deleted_count, "crop directories\n")

# Verify deletion
cat("\n✅ Verification:\n")
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
stamps_count_after <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM stamps")
cat("  stamps table:", stamps_count_after$count, "records (should be 0)\n")

processing_count_after <- tryCatch({
  result <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM stamp_processing")
  result$count
}, error = function(e) 0)
cat("  stamp_processing table:", processing_count_after, "records (should be 0)\n")

DBI::dbDisconnect(con)

cat("\n✅ Done! All stamp records deleted.\n")
cat("   You can now test conditional AI prompts with a clean slate.\n\n")
