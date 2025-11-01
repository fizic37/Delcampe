#!/usr/bin/env Rscript
# Cleanup Script: Delete stamp IDs 1, 2, 3

cat("\n=== CLEANUP: Stamp IDs 1, 2, 3 ===\n\n")

con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")

# Find records
stamps <- DBI::dbGetQuery(con, "SELECT stamp_id, image_type FROM stamps WHERE stamp_id IN (1,2,3)")
cat("Found", nrow(stamps), "records\n")
if (nrow(stamps) > 0) print(stamps)

# Delete (ignore errors for missing tables)
cat("\nDeleting...\n")
try(DBI::dbExecute(con, "DELETE FROM stamp_processing WHERE stamp_id IN (1,2,3)"), silent = TRUE)
try(DBI::dbExecute(con, "DELETE FROM session_activity WHERE card_id IN (1,2,3)"), silent = TRUE)
DBI::dbExecute(con, "DELETE FROM stamps WHERE stamp_id IN (1,2,3)")

DBI::dbDisconnect(con)

# Delete crop files
cat("\nDeleting crop files...\n")
for (id in 1:3) {
  for (type in c("face", "verso", "combined", "lot")) {
    dir <- file.path("inst/app/data/crops", type, id)
    if (dir.exists(dir)) {
      unlink(dir, recursive = TRUE)
      cat("  ✓", dir, "\n")
    }
  }
}

cat("\n✅ Done!\n")
