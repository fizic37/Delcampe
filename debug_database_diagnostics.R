# Database Diagnostics Script
# Run this to check database schema and data
# Usage: source("debug_database_diagnostics.R")

library(DBI)
library(RSQLite)

cat("\n╔═══════════════════════════════════════════════════════════╗\n")
cat("║         DATABASE DIAGNOSTICS FOR AI PRE-POPULATION        ║\n")
cat("╚═══════════════════════════════════════════════════════════╝\n\n")

db_path <- "inst/app/data/tracking.sqlite"

if (!file.exists(db_path)) {
  cat("❌ ERROR: Database file not found at:", db_path, "\n")
  cat("   Make sure you're running this from the project root directory.\n")
  stop("Database not found")
}

con <- dbConnect(SQLite(), db_path)

# ============================================================
# 1. CHECK TABLES EXIST
# ============================================================
cat("1. Checking Tables\n")
cat("   ────────────────────────────────────────────────────────\n")

tables <- dbGetQuery(con, "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
cat("   Found", nrow(tables), "tables:\n")
for (i in seq_len(nrow(tables))) {
  cat("      -", tables$name[i], "\n")
}

required_tables <- c("postal_cards", "card_processing")
missing_tables <- setdiff(required_tables, tables$name)

if (length(missing_tables) > 0) {
  cat("   ❌ MISSING REQUIRED TABLES:", paste(missing_tables, collapse=", "), "\n")
} else {
  cat("   ✅ All required tables exist\n")
}

# ============================================================
# 2. CHECK postal_cards SCHEMA
# ============================================================
cat("\n2. Checking postal_cards Schema\n")
cat("   ────────────────────────────────────────────────────────\n")

postal_cards_schema <- dbGetQuery(con, "PRAGMA table_info(postal_cards)")
cat("   Columns:\n")
for (i in seq_len(nrow(postal_cards_schema))) {
  cat("      -", postal_cards_schema$name[i],
      "(", postal_cards_schema$type[i], ")",
      if(postal_cards_schema$pk[i] == 1) "[PRIMARY KEY]" else "",
      if(postal_cards_schema$notnull[i] == 1) "[NOT NULL]" else "",
      "\n")
}

# Check for image_type column
if ("image_type" %in% postal_cards_schema$name) {
  cat("   ✅ postal_cards.image_type column exists\n")
} else {
  cat("   ❌ postal_cards.image_type column MISSING\n")
}

# ============================================================
# 3. CHECK card_processing SCHEMA
# ============================================================
cat("\n3. Checking card_processing Schema\n")
cat("   ────────────────────────────────────────────────────────\n")

card_processing_schema <- dbGetQuery(con, "PRAGMA table_info(card_processing)")
cat("   Columns:\n")
for (i in seq_len(nrow(card_processing_schema))) {
  cat("      -", card_processing_schema$name[i],
      "(", card_processing_schema$type[i], ")",
      if(card_processing_schema$pk[i] == 1) "[PRIMARY KEY]" else "",
      if(card_processing_schema$notnull[i] == 1) "[NOT NULL]" else "",
      "\n")
}

# Check for AI columns
ai_columns <- c("ai_title", "ai_description", "ai_condition", "ai_price", "ai_model")
missing_ai_cols <- setdiff(ai_columns, card_processing_schema$name)

if (length(missing_ai_cols) > 0) {
  cat("   ❌ MISSING AI COLUMNS:", paste(missing_ai_cols, collapse=", "), "\n")
} else {
  cat("   ✅ All AI columns exist\n")
}

# ============================================================
# 4. CHECK DATA IN postal_cards
# ============================================================
cat("\n4. Checking postal_cards Data\n")
cat("   ────────────────────────────────────────────────────────\n")

total_cards <- dbGetQuery(con, "SELECT COUNT(*) as count FROM postal_cards")$count
cat("   Total cards:", total_cards, "\n")

if (total_cards > 0) {
  # Count by image_type
  by_type <- dbGetQuery(con, "
    SELECT image_type, COUNT(*) as count
    FROM postal_cards
    GROUP BY image_type
  ")

  cat("   Cards by type:\n")
  for (i in seq_len(nrow(by_type))) {
    cat("      -", by_type$image_type[i], ":", by_type$count[i], "\n")
  }

  # Show recent combined images
  combined <- dbGetQuery(con, "
    SELECT card_id, file_hash, original_filename, first_seen, last_updated
    FROM postal_cards
    WHERE image_type = 'combined'
    ORDER BY card_id DESC
    LIMIT 5
  ")

  if (nrow(combined) > 0) {
    cat("\n   Recent combined images:\n")
    for (i in seq_len(nrow(combined))) {
      cat("      Card ID:", combined$card_id[i], "\n")
      cat("         Hash:", combined$file_hash[i], "\n")
      cat("         File:", combined$original_filename[i], "\n")
      cat("         First seen:", combined$first_seen[i], "\n")
      cat("\n")
    }
  } else {
    cat("   ⚠️ No combined images found in postal_cards\n")
  }
} else {
  cat("   ⚠️ No data in postal_cards table\n")
}

# ============================================================
# 5. CHECK DATA IN card_processing
# ============================================================
cat("\n5. Checking card_processing Data\n")
cat("   ────────────────────────────────────────────────────────\n")

total_processing <- dbGetQuery(con, "SELECT COUNT(*) as count FROM card_processing")$count
cat("   Total processing records:", total_processing, "\n")

if (total_processing > 0) {
  # Count with AI data
  with_ai <- dbGetQuery(con, "
    SELECT COUNT(*) as count
    FROM card_processing
    WHERE ai_title IS NOT NULL AND ai_title != ''
  ")$count

  cat("   Records with AI data:", with_ai, "\n")

  if (with_ai > 0) {
    cat("   ✅ AI data exists in card_processing\n")
  } else {
    cat("   ⚠️ No AI data found in card_processing\n")
  }

  # Show recent processing records
  recent <- dbGetQuery(con, "
    SELECT
      cp.processing_id,
      cp.card_id,
      cp.ai_title,
      cp.ai_price,
      cp.ai_condition,
      cp.ai_model,
      cp.last_processed,
      pc.image_type,
      pc.file_hash
    FROM card_processing cp
    LEFT JOIN postal_cards pc ON cp.card_id = pc.card_id
    ORDER BY cp.processing_id DESC
    LIMIT 5
  ")

  cat("\n   Recent processing records:\n")
  for (i in seq_len(nrow(recent))) {
    cat("      Processing ID:", recent$processing_id[i], "\n")
    cat("         Card ID:", recent$card_id[i], "\n")
    cat("         Image type:", if(is.na(recent$image_type[i])) "NULL" else recent$image_type[i], "\n")
    cat("         File hash:", if(is.na(recent$file_hash[i])) "NULL" else recent$file_hash[i], "\n")
    cat("         AI Title:", if(is.na(recent$ai_title[i])) "NULL" else substr(recent$ai_title[i], 1, 50), "\n")
    cat("         AI Price:", if(is.na(recent$ai_price[i])) "NULL" else recent$ai_price[i], "\n")
    cat("         AI Condition:", if(is.na(recent$ai_condition[i])) "NULL" else recent$ai_condition[i], "\n")
    cat("         AI Model:", if(is.na(recent$ai_model[i])) "NULL" else recent$ai_model[i], "\n")
    cat("         Processed:", if(is.na(recent$last_processed[i])) "NULL" else recent$last_processed[i], "\n")
    cat("\n")
  }
} else {
  cat("   ⚠️ No data in card_processing table\n")
}

# ============================================================
# 6. CHECK JOIN QUERY (what find_card_processing uses)
# ============================================================
cat("\n6. Testing find_card_processing() Query\n")
cat("   ────────────────────────────────────────────────────────\n")

# Get a sample combined card hash
sample_hash <- dbGetQuery(con, "
  SELECT file_hash FROM postal_cards
  WHERE image_type = 'combined'
  LIMIT 1
")

if (nrow(sample_hash) > 0) {
  test_hash <- sample_hash$file_hash[1]
  cat("   Testing with hash:", test_hash, "\n")

  # Run the same query as find_card_processing
  result <- dbGetQuery(con, "
    SELECT
      c.card_id,
      c.file_hash,
      c.image_type,
      c.first_seen,
      c.last_updated,
      p.crop_paths,
      p.h_boundaries,
      p.v_boundaries,
      p.grid_rows,
      p.grid_cols,
      p.extraction_dir,
      p.ai_title,
      p.ai_description,
      p.ai_condition,
      p.ai_price,
      p.last_processed
    FROM postal_cards c
    LEFT JOIN card_processing p ON c.card_id = p.card_id
    WHERE c.file_hash = ? AND c.image_type = ?
  ", list(test_hash, "combined"))

  if (nrow(result) > 0) {
    cat("   ✅ Query successful\n")
    cat("      Card ID:", result$card_id[1], "\n")
    cat("      Has processing record:", !is.na(result$last_processed[1]), "\n")
    cat("      Has AI title:", !is.na(result$ai_title[1]) && result$ai_title[1] != "", "\n")
    cat("      AI Title:", if(is.na(result$ai_title[1])) "NULL" else substr(result$ai_title[1], 1, 50), "\n")
    cat("      AI Price:", if(is.na(result$ai_price[1])) "NULL" else result$ai_price[1], "\n")
  } else {
    cat("   ❌ Query returned no results\n")
  }
} else {
  cat("   ⚠️ No combined images to test with\n")
}

# ============================================================
# 7. SUMMARY & RECOMMENDATIONS
# ============================================================
cat("\n╔═══════════════════════════════════════════════════════════╗\n")
cat("║                    SUMMARY & RECOMMENDATIONS               ║\n")
cat("╚═══════════════════════════════════════════════════════════╝\n\n")

issues_found <- c()

if (length(missing_tables) > 0) {
  issues_found <- c(issues_found, "Missing tables - run initialize_tracking_db()")
}

if (length(missing_ai_cols) > 0) {
  issues_found <- c(issues_found, "Missing AI columns in card_processing")
}

if (total_cards == 0) {
  issues_found <- c(issues_found, "No cards in postal_cards - upload some images first")
}

if (total_processing > 0 && with_ai == 0) {
  issues_found <- c(issues_found, "No AI data in card_processing - run AI extraction")
}

if (length(issues_found) > 0) {
  cat("Issues Found:\n")
  for (i in seq_along(issues_found)) {
    cat("   ", i, ".", issues_found[i], "\n")
  }
  cat("\n")
} else {
  cat("✅ No major issues found!\n\n")
}

cat("Next Steps:\n")
cat("   1. If schema is missing: Run initialize_tracking_db()\n")
cat("   2. Upload images and run AI extraction\n")
cat("   3. Check R console for debug messages from mod_delcampe_export.R\n")
cat("   4. Look for '=== SAVING AI DATA TO DATABASE ===' messages\n")
cat("   5. Look for '=== PRE-POPULATION OBSERVER TRIGGERED ===' messages\n")

dbDisconnect(con)

cat("\n✅ Diagnostics complete!\n\n")
