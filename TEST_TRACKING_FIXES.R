# Quick Test Script for Tracking Fixes
# Run this after implementing the fixes to verify everything works

library(Delcampe)
library(DBI)

cat("\n=== TRACKING FIXES VERIFICATION ===\n\n")

# 1. Check persistent crops directory
cat("1. Checking persistent crops directory...\n")
crops_dir <- "inst/app/data/crops"
if (dir.exists(crops_dir)) {
  files <- list.files(crops_dir, recursive = TRUE, full.names = FALSE)
  cat("   ✓ Directory exists\n")
  cat("   Files found:", length(files), "\n")
  if (length(files) > 0) {
    cat("   Sample:", head(files, 3), "\n")
  }
} else {
  cat("   ℹ️ Directory doesn't exist yet (will be created on first extraction)\n")
}

# 2. Check database structure
cat("\n2. Checking database structure...\n")
db_path <- "inst/app/data/tracking.sqlite"
if (file.exists(db_path)) {
  con <- dbConnect(RSQLite::SQLite(), db_path)
  
  # Check tables
  tables <- dbListTables(con)
  cat("   Tables:", paste(tables, collapse = ", "), "\n")
  
  required_tables <- c("postal_cards", "card_processing", "session_activity")
  missing <- setdiff(required_tables, tables)
  if (length(missing) == 0) {
    cat("   ✓ All required tables exist\n")
  } else {
    cat("   ⚠️ Missing tables:", paste(missing, collapse = ", "), "\n")
  }
  
  # Check postal_cards data
  postal_cards <- dbGetQuery(con, "SELECT COUNT(*) as count, image_type FROM postal_cards GROUP BY image_type")
  if (nrow(postal_cards) > 0) {
    cat("\n   Postal Cards Summary:\n")
    for (i in 1:nrow(postal_cards)) {
      cat("     -", postal_cards$image_type[i], ":", postal_cards$count[i], "cards\n")
    }
  } else {
    cat("   ℹ️ No postal cards uploaded yet\n")
  }
  
  # Check processing data
  processing <- dbGetQuery(con, "
    SELECT c.image_type, COUNT(*) as count
    FROM card_processing p
    JOIN postal_cards c ON p.card_id = c.card_id
    GROUP BY c.image_type
  ")
  if (nrow(processing) > 0) {
    cat("\n   Processing Summary:\n")
    for (i in 1:nrow(processing)) {
      cat("     -", processing$image_type[i], ":", processing$count[i], "processed\n")
    }
  } else {
    cat("   ℹ️ No processing records yet\n")
  }
  
  # Check for persistent paths in database
  sample_paths <- dbGetQuery(con, "
    SELECT crop_paths 
    FROM card_processing 
    WHERE crop_paths IS NOT NULL 
    LIMIT 1
  ")
  if (nrow(sample_paths) > 0) {
    paths_json <- sample_paths$crop_paths[1]
    paths <- jsonlite::fromJSON(paths_json)
    if (length(paths) > 0) {
      cat("\n   Sample crop path:", paths[1], "\n")
      if (grepl("inst/app/data/crops", paths[1])) {
        cat("   ✓ Using persistent storage (correct)\n")
      } else if (grepl("Rtmp", paths[1])) {
        cat("   ⚠️ Using temp directory (incorrect - old implementation)\n")
      }
    }
  }
  
  dbDisconnect(con)
} else {
  cat("   ⚠️ Database doesn't exist yet\n")
  cat("   Run: initialize_tracking_db()\n")
}

cat("\n=== MANUAL TESTING REQUIRED ===\n\n")
cat("Test 1: Verso Deduplication Across Restarts\n")
cat("  1. Run: Delcampe::run_app()\n")
cat("  2. Upload a verso image and extract crops\n")
cat("  3. CLOSE app completely (stop R session)\n")
cat("  4. RESTART: Delcampe::run_app()\n")
cat("  5. Upload SAME verso image\n")
cat("  6. Expected: Modal 'Duplicate Image Detected' appears\n")
cat("  7. Click 'Use Existing' - crops should restore\n\n")

cat("Test 2: AI Pre-Population\n")
cat("  1. Create combined image and run AI extraction\n")
cat("  2. CLOSE app completely\n")
cat("  3. RESTART and recreate same combined image\n")
cat("  4. Expected: Form fields auto-populate immediately\n")
cat("  5. Expected: Green banner shows model name\n\n")

cat("=== END VERIFICATION ===\n\n")
