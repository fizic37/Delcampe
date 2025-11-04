# SQLite Database Integration Patterns - Delcampe Codebase

## Overview
The Delcampe project uses SQLite for lightweight, embedded data storage with a comprehensive 3-layer architecture for tracking postal cards and stamps, plus eBay listing integration.

---

## 1. DATABASE PATH AND CONNECTION MANAGEMENT

### Database Path
- **Fixed Path**: `inst/app/data/tracking.sqlite`
- Used consistently across all database functions
- Created in `initialize_tracking_db()` which creates the directory structure if needed
- No abstraction function - hardcoded path used everywhere

```r
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
```

### Connection Pattern (CRITICAL)
All database functions follow this exact pattern:

```r
function_name <- function(params) {
  tryCatch({
    # 1. Connect (always at function start)
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    
    # 2. Register exit handler (for cleanup)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    # or simply: on.exit(DBI::dbDisconnect(con))
    
    # 3. Execute queries/updates
    # 4. Return results
    
    return(result)
    
  }, error = function(e) {
    # Always provide informative error message
    message("❌ Error in function_name: ", e$message)
    return(NULL)  # or FALSE for boolean functions
  })
}
```

**Key Points:**
- Connection is **always** closed via `on.exit()`, even on error
- Use `add = TRUE` to append to existing exit handlers if needed
- Never leave connections open - this exhausts SQLite resources
- Each function opens/closes its own connection (no persistent connections)

---

## 2. TABLE SCHEMA AND NAMING CONVENTIONS

### 3-Layer Architecture (Primary for Cards)

**Layer 1: Master Table (postal_cards)**
```r
CREATE TABLE IF NOT EXISTS postal_cards (
  card_id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_hash TEXT UNIQUE NOT NULL,
  original_filename TEXT NOT NULL,
  image_type TEXT NOT NULL,
  file_size INTEGER,
  width INTEGER,
  height INTEGER,
  first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
  times_uploaded INTEGER DEFAULT 1
)
```

**Layer 2: Processing Results (card_processing)**
```r
CREATE TABLE IF NOT EXISTS card_processing (
  processing_id INTEGER PRIMARY KEY AUTOINCREMENT,
  card_id INTEGER UNIQUE NOT NULL,
  crop_paths TEXT,          # JSON array
  h_boundaries TEXT,        # JSON
  v_boundaries TEXT,        # JSON
  grid_rows INTEGER,
  grid_cols INTEGER,
  extraction_dir TEXT,
  ai_title TEXT,
  ai_description TEXT,
  ai_condition TEXT,
  ai_price REAL,
  ai_model TEXT,
  ai_year TEXT,             # Added via migration
  ai_era TEXT,              # Added via migration
  ai_city TEXT,             # Added via migration
  ai_country TEXT,          # Added via migration
  ai_region TEXT,           # Added via migration
  ai_theme_keywords TEXT,   # Added via migration
  last_processed DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (card_id) REFERENCES postal_cards(card_id) ON DELETE CASCADE
)
```

**Layer 3: Activity Log (session_activity)**
```r
CREATE TABLE IF NOT EXISTS session_activity (
  activity_id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  card_id INTEGER NOT NULL,
  action TEXT NOT NULL,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  details TEXT,
  FOREIGN KEY (session_id) REFERENCES sessions(session_id),
  FOREIGN KEY (card_id) REFERENCES postal_cards(card_id)
)
```

### Stamps Tables (Parallel Structure)
Identical to postal_cards but:
- Table: `stamps` instead of `postal_cards`
- Table: `stamp_processing` instead of `card_processing`
- Special field: `image_type CHECK(image_type IN ('face', 'verso', 'combined', 'lot'))`
- Stamp-specific fields in `stamp_processing`: country, year, denomination, scott_number, perforation, watermark, grade
- Listing table: `ebay_stamp_listings` (category_id defaults to '260')

### Legacy Tables (Pre-3-layer)
Still maintained for backward compatibility:
- `users` - User accounts with authentication
- `sessions` - Processing sessions
- `images` - Legacy image tracking
- `processing_log` - Legacy action log
- `ai_extractions` - AI extraction history
- `ebay_posts` - Legacy eBay posting records

### eBay Integration Tables
```r
CREATE TABLE IF NOT EXISTS ebay_listings (
  listing_id INTEGER PRIMARY KEY AUTOINCREMENT,
  card_id INTEGER,
  session_id TEXT NOT NULL,
  ebay_item_id TEXT,
  ebay_offer_id TEXT,
  ebay_user_id TEXT,          # Added via migration
  ebay_username TEXT,         # Added via migration
  sku TEXT UNIQUE NOT NULL,
  status TEXT DEFAULT 'draft',
  environment TEXT DEFAULT 'sandbox',
  title TEXT,
  description TEXT,
  price REAL,
  quantity INTEGER DEFAULT 1,
  condition TEXT,
  category_id TEXT DEFAULT '914',  # Postal cards
  listing_url TEXT,
  image_urls TEXT,            # JSON array
  aspects TEXT,               # JSON
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  listed_at DATETIME,
  last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
  error_message TEXT,
  FOREIGN KEY (card_id) REFERENCES postal_cards(card_id),
  FOREIGN KEY (session_id) REFERENCES sessions(session_id)
)
```

---

## 3. DATABASE INITIALIZATION

### Main Initialization Function
```r
initialize_tracking_db <- function(db_path = "inst/app/data/tracking.sqlite")
```

**Execution Steps:**
1. Create directory structure with `dir.create(..., recursive = TRUE)`
2. Connect to database
3. Enable PRAGMAS:
   - `PRAGMA foreign_keys = ON` - Enable referential integrity
   - `PRAGMA journal_mode = WAL` - Write-Ahead Logging for concurrency
4. Create all tables with `CREATE TABLE IF NOT EXISTS`
5. Handle migrations (see Migration Pattern section)
6. Create indexes (see Indexing section)
7. Return TRUE/FALSE status

**Key Pattern:**
```r
DBI::dbExecute(con, "PRAGMA foreign_keys = ON")
DBI::dbExecute(con, "PRAGMA journal_mode = WAL")
```

---

## 4. SQL PATTERNS AND PARAMETER BINDING

### INSERT Patterns

**Basic INSERT:**
```r
DBI::dbExecute(con, "
  INSERT INTO table_name (col1, col2, col3)
  VALUES (?, ?, ?)
", params = list(val1, val2, val3))
```

**INSERT OR IGNORE (upsert - ignore if duplicate key):**
```r
DBI::dbExecute(con, "
  INSERT OR IGNORE INTO table_name (col1, col2)
  VALUES (?, ?)
", params = list(val1, val2))
```

**INSERT OR REPLACE (upsert - replace if exists):**
```r
DBI::dbExecute(con, "
  INSERT OR REPLACE INTO table_name (col1, col2)
  VALUES (?, ?)
", params = list(val1, val2))
```

### SELECT Patterns

**Query returning single row:**
```r
result <- DBI::dbGetQuery(con, "
  SELECT col1, col2 FROM table_name
  WHERE id = ?
", params = list(id))

if (nrow(result) > 0) {
  value <- result$col1[1]  # Access first row
}
```

**Query returning multiple rows:**
```r
results <- DBI::dbGetQuery(con, "
  SELECT * FROM table_name
  WHERE status = ?
  ORDER BY created_at DESC
", params = list(status))
```

**Get Last Inserted Row ID:**
```r
new_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id
```

### UPDATE Patterns

**Simple Update:**
```r
DBI::dbExecute(con, "
  UPDATE table_name
  SET column1 = ?, column2 = ?
  WHERE id = ?
", params = list(new_val1, new_val2, id))
```

**Update with COALESCE (conditional update):**
```r
# Only update if new value is not NULL
DBI::dbExecute(con, "
  UPDATE table_name
  SET column1 = COALESCE(?, column1),
      column2 = COALESCE(?, column2)
  WHERE id = ?
", params = list(new_val1, new_val2, id))
```

**Update Timestamp:**
```r
DBI::dbExecute(con, "
  UPDATE table_name
  SET last_updated = CURRENT_TIMESTAMP
  WHERE id = ?
", params = list(id))
```

### Parameter Binding (CRITICAL for Security)
Always use `?` placeholders and pass parameters separately:

```r
# CORRECT:
DBI::dbExecute(con, "SELECT * FROM users WHERE id = ?", params = list(user_id))

# WRONG (SQL injection vulnerability):
DBI::dbExecute(con, paste0("SELECT * FROM users WHERE id = '", user_id, "'"))
```

---

## 5. HANDLING NULL VALUES IN SQL

### R NULL vs SQL NULL
R's NULL doesn't translate directly to SQL. Use type-specific NA values:

```r
# For character columns:
value <- if (!is.null(var)) as.character(var) else NA_character_

# For numeric columns:
value <- if (!is.null(var)) as.numeric(var) else NA_real_

# For integer columns:
value <- if (!is.null(var)) as.integer(var) else NA_integer_

# For logical columns:
value <- if (!is.null(var)) as.logical(var) else NA
```

### JSON Conversion
```r
# Convert R list to JSON before storing:
json_data <- if (!is.null(data)) jsonlite::toJSON(data) else NA_character_

# When storing NULL/empty values:
crop_paths_json <- if (!is.null(crop_paths)) jsonlite::toJSON(crop_paths) else NA_character_
```

### COALESCE Pattern
Use SQL COALESCE to preserve existing values if new ones are NULL:

```r
DBI::dbExecute(con, "
  UPDATE table SET
    col1 = COALESCE(?, col1),
    col2 = COALESCE(?, col2)
  WHERE id = ?
", params = list(new_val1, new_val2, id))
```

---

## 6. ERROR HANDLING CONVENTIONS

### Standard Error Handler
```r
tryCatch({
  # Database operations
  return(result)
}, error = function(e) {
  message("❌ Error in function_name: ", e$message)
  return(NULL)  # or FALSE, or appropriate default
})
```

### Detailed Error Handling
```r
tryCatch({
  # Step 1
  result1 <- do_something()
  # Step 2
  result2 <- do_something_else()
  return(list(result1, result2))
}, error = function(e) {
  message("❌ Error in complex_operation: ", e$message)
  message("   Details: ", e$call)
  return(NULL)
})
```

### With Inner Try-Catch (for migrations)
```r
tryCatch({
  # Outer operation
  tryCatch({
    # Inner risky operation (migration check)
    DBI::dbExecute(con, "ALTER TABLE...")
  }, error = function(e) {
    # Inner error handling
    message("⚠️ Migration warning: ", e$message)
  })
}, error = function(e) {
  # Outer error handling
  message("❌ Outer operation failed: ", e$message)
})
```

---

## 7. MIGRATION PATTERNS

### Schema Addition (ALTER TABLE)
```r
tryCatch({
  # Check if columns exist
  columns <- DBI::dbGetQuery(con, "PRAGMA table_info(table_name)")
  
  if (!"new_column" %in% columns$name) {
    DBI::dbExecute(con, "ALTER TABLE table_name ADD COLUMN new_column TEXT")
    message("✅ Added new_column to table_name")
  }
}, error = function(e) {
  message("⚠️ Migration warning: ", e$message)
})
```

### Constraint Modification (Rename/Recreate)
SQLite doesn't support ALTER TABLE on constraints. Pattern:

```r
tryCatch({
  # Try to test if constraint allows new value
  DBI::dbExecute(con, "
    INSERT INTO stamps (file_hash, original_filename, image_type, file_size)
    VALUES (?, 'test.jpg', 'lot', 0)
  ", params = list(test_hash))
  
  # If successful, constraint already updated
  DBI::dbExecute(con, "DELETE FROM stamps WHERE file_hash = ?", params = list(test_hash))
  message("✅ Constraint already supports 'lot'")
}, error = function(e) {
  # Need to migrate
  message("🔄 Migrating stamps table to support 'lot'...")
  
  # Step 1: Rename old table
  DBI::dbExecute(con, "ALTER TABLE stamps RENAME TO stamps_old")
  
  # Step 2: Create new table with updated constraint
  DBI::dbExecute(con, "
    CREATE TABLE stamps (
      stamp_id INTEGER PRIMARY KEY AUTOINCREMENT,
      file_hash TEXT UNIQUE NOT NULL,
      original_filename TEXT NOT NULL,
      image_type TEXT NOT NULL CHECK(image_type IN ('face', 'verso', 'combined', 'lot')),
      file_size INTEGER,
      width INTEGER,
      height INTEGER,
      first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
      last_accessed DATETIME DEFAULT CURRENT_TIMESTAMP,
      times_uploaded INTEGER DEFAULT 1
    )
  ")
  
  # Step 3: Copy data
  DBI::dbExecute(con, "INSERT INTO stamps SELECT * FROM stamps_old")
  
  # Step 4: Drop old table
  DBI::dbExecute(con, "DROP TABLE stamps_old")
  
  message("✅ Migration complete")
})
```

---

## 8. INDEXING STRATEGY

### Index Creation Pattern
```r
indexes <- c(
  "CREATE INDEX IF NOT EXISTS idx_table_column ON table(column)",
  "CREATE UNIQUE INDEX IF NOT EXISTS idx_table_unique ON table(column)",
  "CREATE INDEX IF NOT EXISTS idx_table_composite ON table(col1, col2)"
)

for (index in indexes) {
  DBI::dbExecute(con, index)
}
```

### Current Indexes (by purpose)

**Legacy/Basic Indexes:**
```
idx_images_session          ON images(session_id)
idx_images_user             ON images(user_id)
idx_images_status           ON images(processing_status)
idx_images_type             ON images(image_type)
idx_images_hash             ON images(file_hash)
idx_log_image               ON processing_log(image_id)
```

**3-Layer Architecture Indexes:**
```
idx_postal_cards_hash       UNIQUE ON postal_cards(file_hash)
idx_postal_cards_type       ON postal_cards(image_type)
idx_card_processing_card    UNIQUE ON card_processing(card_id)
idx_session_activity_session ON session_activity(session_id)
idx_session_activity_card   ON session_activity(card_id)
idx_session_activity_action ON session_activity(action)
```

**eBay Indexes:**
```
idx_ebay_listings_card      ON ebay_listings(card_id)
idx_ebay_listings_session   ON ebay_listings(session_id)
idx_ebay_listings_status    ON ebay_listings(status)
idx_ebay_listings_sku       UNIQUE ON ebay_listings(sku)
```

**Stamp Indexes:**
```
idx_stamps_hash             UNIQUE ON stamps(file_hash)
idx_stamps_type             ON stamps(image_type)
idx_stamp_processing_stamp  UNIQUE ON stamp_processing(stamp_id)
idx_ebay_stamp_listings_*   (similar to postal card listings)
```

---

## 9. HELPER FUNCTION PATTERNS

### Null Coalescing Operator
```r
`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0 || all(is.na(a))) b else a
}

# Usage:
value <- query_result$count %||% 0
```

### Common Helper Patterns

**Ensure Entity Exists (Create if Missing):**
```r
ensure_user_exists <- function(user_id, username, email = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con))
    
    # Use INSERT OR IGNORE to create if missing
    DBI::dbExecute(con, "
      INSERT OR IGNORE INTO users (user_id, username, email)
      VALUES (?, ?, ?)
    ", list(as.character(user_id), as.character(username), email))
    
    # Always update timestamp
    DBI::dbExecute(con, "
      UPDATE users SET last_login = CURRENT_TIMESTAMP
      WHERE user_id = ?
    ", list(as.character(user_id)))
    
    return(user_id)
  }, error = function(e) {
    message("❌ Error in ensure_user_exists: ", e$message)
    return(user_id)
  })
}
```

**Get or Create Pattern:**
```r
get_or_create_card <- function(file_hash, image_type, original_filename, 
                               file_size = NULL, dimensions = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    
    # Check if exists
    existing <- DBI::dbGetQuery(con, "
      SELECT card_id, times_uploaded 
      FROM postal_cards 
      WHERE file_hash = ? AND image_type = ?
    ", list(as.character(file_hash), as.character(image_type)))
    
    if (nrow(existing) > 0) {
      # Update existing
      card_id <- existing$card_id[1]
      DBI::dbExecute(con, "
        UPDATE postal_cards 
        SET times_uploaded = times_uploaded + 1,
            last_updated = CURRENT_TIMESTAMP
        WHERE card_id = ?
      ", list(card_id))
      message("Existing card found: card_id = ", card_id)
      return(card_id)
    } else {
      # Create new
      width_val <- if (!is.null(dimensions) && !is.null(dimensions$width)) 
                     as.integer(dimensions$width) else NA_integer_
      
      DBI::dbExecute(con, "
        INSERT INTO postal_cards (
          file_hash, original_filename, image_type, 
          file_size, width, height
        ) VALUES (?, ?, ?, ?, ?, ?)
      ", list(as.character(file_hash), as.character(original_filename),
              as.character(image_type), as.integer(file_size),
              width_val, height_val))
      
      card_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id
      message("New card created: card_id = ", card_id)
      return(card_id)
    }
  }, error = function(e) {
    message("Error in get_or_create_card: ", e$message)
    return(NULL)
  })
}
```

---

## 10. LOGGING AND MESSAGES

### Message Conventions
```r
message("✅ Success message: ", result)        # Success
message("❌ Error message: ", error)           # Error/Failure
message("⚠️ Warning message: ", warning)       # Warning
message("🔄 Processing message: ", status)    # In-progress
message("ℹ️ Information message: ", detail)   # Info
```

### Logging Database Operations
Each function provides feedback:
```r
message("✅ User exists or created: ", user_id)
message("✅ Session started: ", session_id)
message("✅ Card processing updated for card_id: ", card_id)
message("❌ Error in function_name: ", e$message)
```

---

## 11. ADDING A NEW TABLE

### Step-by-Step Procedure

1. **Add table creation to `initialize_tracking_db()`:**
   ```r
   # In appropriate section (e.g., after ========== STAMP TABLES)
   DBI::dbExecute(con, "
     CREATE TABLE IF NOT EXISTS new_table (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       foreign_key_id INTEGER NOT NULL,
       column1 TEXT NOT NULL,
       column2 REAL,
       created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
       FOREIGN KEY (foreign_key_id) REFERENCES parent_table(id)
     )
   ")
   ```

2. **Add indexes:**
   ```r
   # Add to indexes list
   "CREATE INDEX IF NOT EXISTS idx_new_table_foreign_key ON new_table(foreign_key_id)",
   "CREATE INDEX IF NOT EXISTS idx_new_table_column1 ON new_table(column1)"
   ```

3. **Create helper functions:**
   ```r
   # Insert function
   insert_to_new_table <- function(foreign_key_id, column1, column2 = NULL) {
     tryCatch({
       con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
       on.exit(DBI::dbDisconnect(con))
       
       DBI::dbExecute(con, "
         INSERT INTO new_table (foreign_key_id, column1, column2)
         VALUES (?, ?, ?)
       ", list(as.integer(foreign_key_id), as.character(column1), column2))
       
       new_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id
       message("✅ Record inserted: id = ", new_id)
       return(new_id)
     }, error = function(e) {
       message("❌ Error in insert_to_new_table: ", e$message)
       return(NULL)
     })
   }
   
   # Query function
   get_new_table_records <- function(foreign_key_id) {
     tryCatch({
       con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
       on.exit(DBI::dbDisconnect(con))
       
       result <- DBI::dbGetQuery(con, "
         SELECT * FROM new_table
         WHERE foreign_key_id = ?
         ORDER BY created_at DESC
       ", list(as.integer(foreign_key_id)))
       
       return(result)
     }, error = function(e) {
       message("❌ Error in get_new_table_records: ", e$message)
       return(data.frame())
     })
   }
   ```

4. **Export in NAMESPACE if needed:**
   ```r
   export("insert_to_new_table")
   export("get_new_table_records")
   ```

5. **Add migration code (if adding to existing DB):**
   ```r
   # In initialize_tracking_db() migration section
   tryCatch({
     if (!DBI::dbExistsTable(con, "new_table")) {
       # Create table as above
     }
     message("✅ New table ready")
   }, error = function(e) {
     message("⚠️ Migration warning: ", e$message)
   })
   ```

---

## 12. USERS TABLE (CRITICAL FOR AUTH)

### Current Schema
```r
CREATE TABLE IF NOT EXISTS users (
  user_id TEXT PRIMARY KEY,
  username TEXT NOT NULL,
  email TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_login DATETIME
)
```

### Key Points
- `user_id` is TEXT PRIMARY KEY (not auto-increment)
- Unique constraint on `user_id` enforced by PRIMARY KEY
- `username` is required (NOT NULL)
- `email` is optional
- Timestamps auto-populated

### Current Functions
- `ensure_user_exists(user_id, username, email = NULL)` - Create/update user
- `start_processing_session(session_id, user_id)` - Ensure user exists then create session

### Extension Pattern
When adding authentication (passwords, roles, etc.):

```r
# Add password column via migration
tryCatch({
  columns <- DBI::dbGetQuery(con, "PRAGMA table_info(users)")
  if (!"password_hash" %in% columns$name) {
    DBI::dbExecute(con, "ALTER TABLE users ADD COLUMN password_hash TEXT")
    DBI::dbExecute(con, "ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'user'")
    DBI::dbExecute(con, "ALTER TABLE users ADD COLUMN is_master BOOLEAN DEFAULT 0")
    message("✅ Added authentication columns to users table")
  }
}, error = function(e) {
  message("⚠️ Migration warning: ", e$message)
})
```

---

## 13. TRANSACTION SUPPORT

### Current Status
- NOT explicitly used in existing code
- SQLite handles implicit transactions per statement
- Could be added for multi-statement operations if needed

### Transaction Pattern (if needed)
```r
tryCatch({
  con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
  on.exit(DBI::dbDisconnect(con))
  
  # Start explicit transaction
  DBI::dbExecute(con, "BEGIN TRANSACTION")
  
  # Multiple statements
  DBI::dbExecute(con, "INSERT INTO table1 ...", list(...))
  DBI::dbExecute(con, "UPDATE table2 ...", list(...))
  
  # Commit if successful
  DBI::dbExecute(con, "COMMIT")
  
  return(TRUE)
}, error = function(e) {
  # Rollback on error
  tryCatch({
    DBI::dbExecute(con, "ROLLBACK")
  }, error = function(e2) {})
  message("❌ Transaction failed: ", e$message)
  return(FALSE)
})
```

---

## SUMMARY: DATABASE INTEGRATION CHECKLIST

When adding a new database feature:

- [x] Use `DBI::dbConnect()` / `DBI::dbDisconnect()` pattern
- [x] Always wrap in `tryCatch()` with error handler
- [x] Use `on.exit()` for connection cleanup
- [x] Use parameter binding with `?` placeholders
- [x] Convert R NULL to NA_character_/NA_integer_/NA_real_
- [x] Use JSON for complex data (arrays, nested objects)
- [x] Provide `CREATE TABLE IF NOT EXISTS` for migrations
- [x] Add appropriate indexes for query performance
- [x] Use meaningful emoji in messages (✅❌⚠️🔄)
- [x] Return NULL on error (or FALSE for boolean functions)
- [x] Document parameters and return values with Roxygen2
- [x] Follow naming conventions (table names plural, id columns with _id suffix)
- [x] Use FOREIGN KEY constraints where appropriate
- [x] Enable `PRAGMA foreign_keys = ON` for referential integrity
- [x] Use `PRAGMA journal_mode = WAL` for better concurrency
