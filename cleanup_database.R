# Database Cleanup Script
# Removes old entries with temporary directory paths to test new persistent storage

library(DBI)
library(RSQLite)

cat("\n=== DATABASE CLEANUP FOR PERSISTENT STORAGE TESTING ===\n\n")

db_path <- "inst/app/data/tracking.sqlite"

if (!file.exists(db_path)) {
  cat("❌ Database not found at:", db_path, "\n")
  cat("   No cleanup needed.\n\n")
  quit(save = "no")
}

# Connect to database
con <- dbConnect(SQLite(), db_path)

cat("1. Checking current database state...\n\n")

# Show current postal cards
postal_cards <- dbGetQuery(con, "
  SELECT card_id, image_type, original_filename, first_seen, times_uploaded
  FROM postal_cards
  ORDER BY card_id
")

if (nrow(postal_cards) > 0) {
  cat("   Postal Cards:\n")
  for (i in 1:nrow(postal_cards)) {
    cat(sprintf("     [%d] %s - %s (uploaded %d times)\n",
                postal_cards$card_id[i],
                postal_cards$image_type[i],
                postal_cards$original_filename[i],
                postal_cards$times_uploaded[i]))
  }
  cat("\n")
} else {
  cat("   No postal cards found.\n\n")
}

# Check card_processing entries
processing <- dbGetQuery(con, "
  SELECT p.processing_id, p.card_id, c.image_type, p.crop_paths, p.last_processed
  FROM card_processing p
  JOIN postal_cards c ON p.card_id = c.card_id
  ORDER BY p.card_id
")

if (nrow(processing) > 0) {
  cat("   Processing Records:\n")
  for (i in 1:nrow(processing)) {
    # Parse JSON to check path type
    paths_json <- processing$crop_paths[i]
    if (!is.na(paths_json) && paths_json != "") {
      paths <- tryCatch(jsonlite::fromJSON(paths_json), error = function(e) NULL)
      if (!is.null(paths) && length(paths) > 0) {
        path_type <- if (grepl("Rtmp", paths[1])) {
          "❌ TEMP"
        } else if (grepl("inst/app/data/crops", paths[1])) {
          "✅ PERSISTENT"
        } else {
          "⚠️ UNKNOWN"
        }

        cat(sprintf("     [%d] Card %d (%s) - %s - %s\n",
                    processing$processing_id[i],
                    processing$card_id[i],
                    processing$image_type[i],
                    path_type,
                    processing$last_processed[i]))
        cat(sprintf("         Sample: %s\n", substr(paths[1], 1, 80)))
      }
    }
  }
  cat("\n")
} else {
  cat("   No processing records found.\n\n")
}

# Check session activity
activity_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM session_activity")$count
cat("   Session Activity Records:", activity_count, "\n\n")

# Ask for confirmation
cat("2. Cleanup Options:\n\n")
cat("   [A] Clean ALL data (recommended for fresh start)\n")
cat("       - Deletes all postal_cards, card_processing, session_activity\n")
cat("       - Keeps database structure intact\n")
cat("       - Allows testing persistent storage from scratch\n\n")
cat("   [B] Clean only TEMP path entries\n")
cat("       - Keeps cards with persistent paths (if any)\n")
cat("       - Removes cards with temp directory paths\n\n")
cat("   [C] Cancel (no changes)\n\n")

choice <- readline(prompt = "Enter choice [A/B/C]: ")
choice <- toupper(trimws(choice))

if (choice == "A") {
  cat("\n3. Cleaning ALL data...\n")

  # Delete in reverse order of foreign key dependencies
  dbExecute(con, "DELETE FROM session_activity")
  deleted_activity <- dbGetQuery(con, "SELECT changes() as count")$count
  cat("   ✓ Deleted", deleted_activity, "session activity records\n")

  dbExecute(con, "DELETE FROM card_processing")
  deleted_processing <- dbGetQuery(con, "SELECT changes() as count")$count
  cat("   ✓ Deleted", deleted_processing, "processing records\n")

  dbExecute(con, "DELETE FROM postal_cards")
  deleted_cards <- dbGetQuery(con, "SELECT changes() as count")$count
  cat("   ✓ Deleted", deleted_cards, "postal cards\n")

  # Reset autoincrement counters
  dbExecute(con, "DELETE FROM sqlite_sequence WHERE name IN ('postal_cards', 'card_processing', 'session_activity')")
  cat("   ✓ Reset ID counters\n")

  cat("\n✅ Database cleaned successfully!\n")
  cat("   All data removed. Database ready for fresh testing.\n\n")

} else if (choice == "B") {
  cat("\n3. Cleaning TEMP path entries...\n")

  # Find cards with temp paths
  temp_cards <- c()
  if (nrow(processing) > 0) {
    for (i in 1:nrow(processing)) {
      paths_json <- processing$crop_paths[i]
      if (!is.na(paths_json) && paths_json != "") {
        paths <- tryCatch(jsonlite::fromJSON(paths_json), error = function(e) NULL)
        if (!is.null(paths) && length(paths) > 0 && grepl("Rtmp", paths[1])) {
          temp_cards <- c(temp_cards, processing$card_id[i])
        }
      }
    }
  }

  if (length(temp_cards) > 0) {
    temp_cards <- unique(temp_cards)
    cat("   Found", length(temp_cards), "cards with temp paths\n")

    # Delete session activity for these cards
    for (card_id in temp_cards) {
      dbExecute(con, "DELETE FROM session_activity WHERE card_id = ?", list(card_id))
    }
    cat("   ✓ Deleted session activity for temp cards\n")

    # Delete processing records
    for (card_id in temp_cards) {
      dbExecute(con, "DELETE FROM card_processing WHERE card_id = ?", list(card_id))
    }
    cat("   ✓ Deleted processing records for temp cards\n")

    # Delete postal cards
    for (card_id in temp_cards) {
      dbExecute(con, "DELETE FROM postal_cards WHERE card_id = ?", list(card_id))
    }
    cat("   ✓ Deleted postal cards with temp paths\n")

    cat("\n✅ Cleanup complete!\n")
    cat("   Removed", length(temp_cards), "cards with temporary directory paths.\n\n")
  } else {
    cat("   No cards with temp paths found. Nothing to clean.\n\n")
  }

} else {
  cat("\n❌ Cleanup cancelled. No changes made.\n\n")
}

# Show final state
cat("4. Final database state:\n\n")
final_cards <- dbGetQuery(con, "SELECT COUNT(*) as count FROM postal_cards")$count
final_processing <- dbGetQuery(con, "SELECT COUNT(*) as count FROM card_processing")$count
final_activity <- dbGetQuery(con, "SELECT COUNT(*) as count FROM session_activity")$count

cat("   Postal Cards:", final_cards, "\n")
cat("   Processing Records:", final_processing, "\n")
cat("   Session Activity:", final_activity, "\n\n")

dbDisconnect(con)

cat("=== CLEANUP COMPLETE ===\n\n")
cat("Next steps:\n")
cat("  1. Run: Delcampe::run_app()\n")
cat("  2. Upload face image and extract crops\n")
cat("  3. Upload verso image and extract crops\n")
cat("  4. Check console for: '📂 Persistent crop directory: inst/app/data/crops/...'\n")
cat("  5. Close app completely\n")
cat("  6. Restart app and test deduplication\n\n")
