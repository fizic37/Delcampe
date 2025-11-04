#' Production Database Cleanup Script
#'
#' @description
#' WARNING: This script deletes ALL data from the tracking database
#' while preserving the schema structure. Use ONLY before production deployment.
#'
#' @details
#' This script will:
#' - Delete all records from all tables (except users table if it exists)
#' - Preserve all table schemas
#' - Vacuum the database to reclaim disk space
#' - Provide a detailed report of what was cleaned
#'
#' @usage
#' source("dev/cleanup_production_database.R")
#' cleanup_production_database()
#'
#' @author Delcampe Development Team
#' @date 2025-11-03

#' Main cleanup function
#'
#' @param db_path Path to the tracking database
#' @param skip_users If TRUE, preserve users table (default: TRUE for safety)
#' @return Invisible TRUE if successful, FALSE if aborted
#' @export
cleanup_production_database <- function(
  db_path = "inst/app/data/tracking.sqlite",
  skip_users = TRUE
) {
  # Check if database exists
  if (!file.exists(db_path)) {
    stop("❌ Database not found: ", db_path)
  }

  # Safety confirmation
  cat("\n")
  cat("╔════════════════════════════════════════════════════════════════╗\n")
  cat("║                    ⚠️  WARNING ⚠️                                ║\n")
  cat("║                                                                ║\n")
  cat("║  This will DELETE ALL DATA from the production database!      ║\n")
  cat("║                                                                ║\n")
  cat("╚════════════════════════════════════════════════════════════════╝\n")
  cat("\n")
  cat("Database: ", db_path, "\n")
  cat("Current size: ", format(file.info(db_path)$size, units = "MB"), "\n")
  cat("\n")

  if (skip_users) {
    cat("✅ Users table will be PRESERVED\n")
  } else {
    cat("⚠️  Users table will be DELETED\n")
  }

  cat("\n")
  cat("Type 'YES' (all caps) to confirm deletion: ")

  response <- readline()
  if (response != "YES") {
    cat("\n❌ Operation aborted. No changes made.\n\n")
    return(invisible(FALSE))
  }

  # Load required packages
  if (!requireNamespace("DBI", quietly = TRUE)) {
    stop("DBI package required. Install with: install.packages('DBI')")
  }
  if (!requireNamespace("RSQLite", quietly = TRUE)) {
    stop("RSQLite package required. Install with: install.packages('RSQLite')")
  }

  library(DBI)
  library(RSQLite)

  # Connect to database
  cat("\n📊 Connecting to database...\n")
  con <- dbConnect(SQLite(), db_path)
  on.exit(dbDisconnect(con), add = TRUE)

  # Get all tables
  all_tables <- dbListTables(con)

  # Define tables to clean
  tables_to_clean <- c(
    "processing_sessions",
    "postal_cards",
    "postal_card_processing",
    "session_activities",
    "ebay_exports",
    "ebay_export_cache",
    "stamps",
    "stamp_processing",
    "ebay_listings_cache"  # If exists
  )

  # Filter to only tables that exist
  tables_to_clean <- intersect(tables_to_clean, all_tables)

  # Optionally skip users table
  if (skip_users) {
    tables_to_clean <- setdiff(tables_to_clean, "users")
  }

  if (length(tables_to_clean) == 0) {
    cat("\n⚠️  No tables found to clean. Database may be empty or have unexpected schema.\n")
    cat("Available tables: ", paste(all_tables, collapse = ", "), "\n\n")
    return(invisible(FALSE))
  }

  # Clean each table
  cat("\n🗑️  Cleaning database tables...\n")
  cat("══════════════════════════════════════════════════════════════\n")

  total_rows_deleted <- 0

  for (table in tables_to_clean) {
    tryCatch({
      # Count rows before deletion
      count_before <- dbGetQuery(con, sprintf("SELECT COUNT(*) as n FROM %s", table))$n

      # Delete all rows
      rows_deleted <- dbExecute(con, sprintf("DELETE FROM %s", table))

      # Verify deletion
      count_after <- dbGetQuery(con, sprintf("SELECT COUNT(*) as n FROM %s", table))$n

      cat(sprintf("  ✓ %-30s %6d rows deleted\n", paste0(table, ":"), rows_deleted))

      if (count_after > 0) {
        cat(sprintf("    ⚠️  Warning: %d rows remaining!\n", count_after))
      }

      total_rows_deleted <- total_rows_deleted + rows_deleted

    }, error = function(e) {
      cat(sprintf("  ✗ %-30s ERROR: %s\n", paste0(table, ":"), e$message))
    })
  }

  cat("══════════════════════════════════════════════════════════════\n")
  cat(sprintf("Total rows deleted: %d\n", total_rows_deleted))

  # Vacuum to reclaim space
  cat("\n🔧 Vacuuming database to reclaim disk space...\n")
  tryCatch({
    dbExecute(con, "VACUUM")
    cat("  ✓ Vacuum completed\n")
  }, error = function(e) {
    cat("  ✗ Vacuum failed:", e$message, "\n")
  })

  # Final statistics
  cat("\n📈 Database Statistics:\n")
  cat("══════════════════════════════════════════════════════════════\n")
  cat("  Size before: ", format(file.info(db_path)$size, units = "MB"), "\n")

  # Force disconnect to update file size
  dbDisconnect(con)
  Sys.sleep(0.5)  # Brief pause to ensure file system updates

  cat("  Size after:  ", format(file.info(db_path)$size, units = "MB"), "\n")
  cat("\n✅ Database cleanup completed successfully!\n")

  if (skip_users) {
    cat("ℹ️  Users table was preserved\n")
  }

  cat("\n")

  invisible(TRUE)
}

#' Backup database before cleanup
#'
#' @param db_path Path to the tracking database
#' @param backup_dir Directory to store backup (default: parent directory)
#' @return Path to backup file
#' @export
backup_database <- function(
  db_path = "inst/app/data/tracking.sqlite",
  backup_dir = NULL
) {
  if (!file.exists(db_path)) {
    stop("❌ Database not found: ", db_path)
  }

  # Default backup directory
  if (is.null(backup_dir)) {
    backup_dir <- dirname(dirname(db_path))  # Go up two levels from inst/app/data
  }

  # Create backup filename with timestamp
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_filename <- sprintf("tracking_backup_%s.sqlite", timestamp)
  backup_path <- file.path(backup_dir, backup_filename)

  # Copy database file
  cat("\n📦 Creating backup...\n")
  cat("  Source: ", db_path, "\n")
  cat("  Backup: ", backup_path, "\n")

  file.copy(db_path, backup_path, overwrite = FALSE)

  if (file.exists(backup_path)) {
    cat("  ✅ Backup created successfully\n")
    cat("  Size: ", format(file.info(backup_path)$size, units = "MB"), "\n\n")
    return(invisible(backup_path))
  } else {
    stop("❌ Backup failed!")
  }
}

#' Interactive cleanup workflow with automatic backup
#'
#' @param db_path Path to the tracking database
#' @export
cleanup_with_backup <- function(db_path = "inst/app/data/tracking.sqlite") {
  cat("\n")
  cat("╔════════════════════════════════════════════════════════════════╗\n")
  cat("║         Production Database Cleanup with Backup               ║\n")
  cat("╚════════════════════════════════════════════════════════════════╝\n")

  # Step 1: Create backup
  cat("\n📦 Step 1: Creating backup...\n")
  backup_path <- backup_database(db_path)

  # Step 2: Clean database
  cat("\n🗑️  Step 2: Cleaning database...\n")
  result <- cleanup_production_database(db_path, skip_users = TRUE)

  if (result) {
    cat("\n")
    cat("╔════════════════════════════════════════════════════════════════╗\n")
    cat("║                    ✅ SUCCESS ✅                                 ║\n")
    cat("╚════════════════════════════════════════════════════════════════╝\n")
    cat("\n")
    cat("Database cleaned and ready for production deployment!\n")
    cat("Backup saved to: ", backup_path, "\n")
    cat("\n")
  } else {
    cat("\n⚠️  Cleanup was aborted or failed.\n")
    cat("Backup is available at: ", backup_path, "\n\n")
  }

  invisible(result)
}

# ══════════════════════════════════════════════════════════════════════════════
# USAGE EXAMPLES
# ══════════════════════════════════════════════════════════════════════════════

# Example 1: Cleanup with automatic backup (RECOMMENDED)
# cleanup_with_backup()

# Example 2: Manual backup then cleanup
# backup_database()
# cleanup_production_database()

# Example 3: Cleanup without users table (default)
# cleanup_production_database(skip_users = TRUE)

# Example 4: Cleanup including users table (DANGEROUS!)
# cleanup_production_database(skip_users = FALSE)

# ══════════════════════════════════════════════════════════════════════════════
# NOTES
# ══════════════════════════════════════════════════════════════════════════════

# - Always backup before running cleanup
# - Run this script AFTER implementing the auth system
# - The users table will be preserved by default (skip_users = TRUE)
# - Vacuum reclaims disk space but may take time on large databases
# - For safety, the script requires explicit "YES" confirmation

# ══════════════════════════════════════════════════════════════════════════════
