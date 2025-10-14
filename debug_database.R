# Database Debug Script
# Run this after uploading and processing an image to check if data is being saved

library(DBI)
library(RSQLite)

# Connect to database
con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")

cat("\n=== DATABASE CONTENTS ===\n\n")

# Check images table
cat("IMAGES TABLE:\n")
images <- dbGetQuery(con, "SELECT * FROM images ORDER BY upload_timestamp DESC LIMIT 5")
if (nrow(images) > 0) {
  print(images)
} else {
  cat("  (empty)\n")
}

cat("\nPROCESSING_LOG TABLE:\n")
logs <- dbGetQuery(con, "SELECT 
  log_id, image_id, action, timestamp, success,
  substr(details, 1, 100) as details_preview
FROM processing_log ORDER BY timestamp DESC LIMIT 5")
if (nrow(logs) > 0) {
  print(logs)
} else {
  cat("  (empty)\n")
}

# Check for duplicates
cat("\nDUPLICATE ANALYSIS:\n")
dupes <- dbGetQuery(con, "
  SELECT file_hash, COUNT(*) as count, GROUP_CONCAT(image_id) as image_ids
  FROM images 
  WHERE file_hash IS NOT NULL
  GROUP BY file_hash
  HAVING COUNT(*) > 1
")
if (nrow(dupes) > 0) {
  cat("  Found", nrow(dupes), "duplicate hash(es):\n")
  print(dupes)
} else {
  cat("  No duplicates found\n")
}

# Check processed images
cat("\nPROCESSED IMAGES (with extraction_complete):\n")
processed <- dbGetQuery(con, "
  SELECT i.image_id, i.file_hash, i.image_type, i.upload_timestamp, p.timestamp as processed_at
  FROM images i
  JOIN processing_log p ON i.image_id = p.image_id
  WHERE p.action = 'extraction_complete'
  ORDER BY p.timestamp DESC
  LIMIT 5
")
if (nrow(processed) > 0) {
  print(processed)
} else {
  cat("  (none)\n")
}

dbDisconnect(con)

cat("\n=== END ===\n")
