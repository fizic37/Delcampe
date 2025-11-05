# Database Operations Guide

**Last Updated**: 2025-11-05
**Database**: SQLite
**Location**:
- Local: `inst/app/data/tracking.sqlite`
- Production: `/data/tracking.sqlite` (in Docker container, mounted from Hetzner volume)

---

## Table of Contents

1. [Adding New Columns to Existing Tables](#adding-new-columns-to-existing-tables)
2. [Creating New Tables](#creating-new-tables)
3. [Database Migrations](#database-migrations)
4. [Downloading Database from Hetzner](#downloading-database-from-hetzner)
5. [Database Backup and Restore](#database-backup-and-restore)
6. [Querying the Database](#querying-the-database)

---

## Adding New Columns to Existing Tables

### Step 1: Understand Current Schema

**First, check the existing table structure**:

```r
# In R console
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")

# Show table structure
DBI::dbGetQuery(con, "PRAGMA table_info(postal_cards)")

# Disconnect
DBI::dbDisconnect(con)
```

Or find the CREATE TABLE statement in `R/tracking_database.R`.

### Step 2: Add Migration Code

**Location**: `R/tracking_database.R` in the `initialize_tracking_db()` function

**Migration Pattern**:

```r
# In initialize_tracking_db() function, add AFTER all table creations:

# ========== MIGRATIONS ==========

# Migration: Add new_column to postal_cards table
tryCatch({
  # Check if column exists
  columns <- DBI::dbGetQuery(con, "PRAGMA table_info(postal_cards)")

  if (!"new_column" %in% columns$name) {
    message("🔄 Adding new_column to postal_cards table...")

    DBI::dbExecute(con, "
      ALTER TABLE postal_cards
      ADD COLUMN new_column TEXT DEFAULT NULL
    ")

    message("✅ Added new_column to postal_cards")
  } else {
    message("✅ Column new_column already exists in postal_cards")
  }
}, error = function(e) {
  message("⚠️ Migration warning: ", e$message)
})
```

### Step 3: Document the Column

Add to the table creation comment:

```r
# Postal Cards table
DBI::dbExecute(con, "
  CREATE TABLE IF NOT EXISTS postal_cards (
    card_id TEXT PRIMARY KEY,
    file_hash TEXT UNIQUE NOT NULL,
    image_type TEXT DEFAULT 'recto',
    first_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
    new_column TEXT DEFAULT NULL  -- Added: 2025-11-05 - Description of purpose
  )
")
```

### Step 4: Test Locally

```r
# Delete local database to test fresh creation
file.remove("inst/app/data/tracking.sqlite")

# Run app - database will recreate with new column
devtools::load_all()
golem::run_dev()
```

### Step 5: Test Migration on Existing Database

```r
# Don't delete database this time - test migration
devtools::load_all()
golem::run_dev()

# Check logs - should see:
# ✅ Column new_column already exists in postal_cards
```

### Step 6: Deploy to Production

Follow the [Deployment Workflow](DEPLOYMENT_WORKFLOW.md):

```bash
# 1. Commit changes
git add R/tracking_database.R
git commit -m "feat: Add new_column to postal_cards table"
git push origin main

# 2. Deploy to Hetzner
ssh root@37.27.80.87
cd /root/Delcampe
git pull origin main
docker build -t delcampe-app:latest .
docker-compose down && docker-compose up -d

# 3. Check logs for migration message
docker-compose logs -f
# Should see: ✅ Added new_column to postal_cards
```

**Important**: Migration runs automatically on startup, preserves existing data.

---

## Example: Adding Multiple Columns

```r
# Migration: Add multiple tracking columns
tryCatch({
  columns <- DBI::dbGetQuery(con, "PRAGMA table_info(ebay_listings)")

  # Add view_count if missing
  if (!"view_count" %in% columns$name) {
    DBI::dbExecute(con, "
      ALTER TABLE ebay_listings
      ADD COLUMN view_count INTEGER DEFAULT 0
    ")
    message("✅ Added view_count to ebay_listings")
  }

  # Add watch_count if missing
  if (!"watch_count" %in% columns$name) {
    DBI::dbExecute(con, "
      ALTER TABLE ebay_listings
      ADD COLUMN watch_count INTEGER DEFAULT 0
    ")
    message("✅ Added watch_count to ebay_listings")
  }

  # Add last_sync if missing
  if (!"last_sync" %in% columns$name) {
    DBI::dbExecute(con, "
      ALTER TABLE ebay_listings
      ADD COLUMN last_sync DATETIME DEFAULT NULL
    ")
    message("✅ Added last_sync to ebay_listings")
  }

}, error = function(e) {
  message("⚠️ Migration warning: ", e$message)
})
```

---

## Creating New Tables

### Step 1: Design the Schema

```sql
-- Example: User preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
  pref_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  preference_key TEXT NOT NULL,
  preference_value TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,

  -- Foreign key
  FOREIGN KEY (user_id) REFERENCES users(id),

  -- Unique constraint
  UNIQUE(user_id, preference_key)
)
```

### Step 2: Add Table Creation in initialize_tracking_db()

**Location**: `R/tracking_database.R`

```r
# Add BEFORE the migrations section:

# User Preferences table
DBI::dbExecute(con, "
  CREATE TABLE IF NOT EXISTS user_preferences (
    pref_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    preference_key TEXT NOT NULL,
    preference_value TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE(user_id, preference_key)
  )
")
```

### Step 3: Create Helper Functions

**Create a new file** `R/user_preferences_database.R`:

```r
#' Save user preference
#' @export
save_user_preference <- function(user_id, key, value, db_path = NULL) {
  if (is.null(db_path)) db_path <- get_db_path()

  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
    on.exit(DBI::dbDisconnect(con))

    DBI::dbExecute(con, "
      INSERT OR REPLACE INTO user_preferences (user_id, preference_key, preference_value, updated_at)
      VALUES (?, ?, ?, CURRENT_TIMESTAMP)
    ", params = list(user_id, key, value))

    return(TRUE)
  }, error = function(e) {
    message("❌ Error saving preference: ", e$message)
    return(FALSE)
  })
}

#' Get user preference
#' @export
get_user_preference <- function(user_id, key, default = NULL, db_path = NULL) {
  if (is.null(db_path)) db_path <- get_db_path()

  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
    on.exit(DBI::dbDisconnect(con))

    result <- DBI::dbGetQuery(con, "
      SELECT preference_value
      FROM user_preferences
      WHERE user_id = ? AND preference_key = ?
    ", params = list(user_id, key))

    if (nrow(result) == 0) return(default)
    return(result$preference_value[1])

  }, error = function(e) {
    message("❌ Error getting preference: ", e$message)
    return(default)
  })
}
```

### Step 4: Export Functions in NAMESPACE

Run:
```r
devtools::document()
```

This auto-generates NAMESPACE entries for `@export` functions.

### Step 5: Write Tests

**Create** `tests/testthat/test-user_preferences_database.R`:

```r
test_that("user preferences save and retrieve", {
  with_test_db({
    # Save preference
    result <- save_user_preference(1, "theme", "dark")
    expect_true(result)

    # Retrieve preference
    theme <- get_user_preference(1, "theme")
    expect_equal(theme, "dark")

    # Default value when not found
    missing <- get_user_preference(1, "nonexistent", default = "light")
    expect_equal(missing, "light")
  })
})
```

---

## Database Migrations

### Migration Best Practices

1. **Always check before altering**: Use `PRAGMA table_info()` to check column existence
2. **Handle errors gracefully**: Wrap in `tryCatch()` with warning messages
3. **Preserve data**: Use `ALTER TABLE ADD COLUMN`, not DROP/CREATE
4. **Test both paths**:
   - Fresh database (table creation)
   - Existing database (migration)
5. **Log migrations**: Use `message()` with ✅/🔄/⚠️ symbols
6. **Make migrations idempotent**: Can run multiple times safely

### Complex Migration Example: Renaming Columns

SQLite doesn't support `ALTER TABLE RENAME COLUMN` directly. Use this pattern:

```r
# Migration: Rename 'old_name' to 'new_name' in postal_cards
tryCatch({
  columns <- DBI::dbGetQuery(con, "PRAGMA table_info(postal_cards)")

  if ("old_name" %in% columns$name && !"new_name" %in% columns$name) {
    message("🔄 Migrating column old_name -> new_name...")

    # Step 1: Add new column
    DBI::dbExecute(con, "
      ALTER TABLE postal_cards
      ADD COLUMN new_name TEXT DEFAULT NULL
    ")

    # Step 2: Copy data
    DBI::dbExecute(con, "
      UPDATE postal_cards
      SET new_name = old_name
    ")

    # Step 3: Drop old column (requires recreating table in SQLite)
    # For safety, keep old column and mark as deprecated in comments

    message("✅ Migrated old_name -> new_name (old_name column preserved)")
  }
}, error = function(e) {
  message("⚠️ Migration warning: ", e$message)
})
```

**Note**: For complex schema changes, consider:
1. Create new table with new schema
2. Copy data from old table
3. Drop old table
4. Rename new table

---

## Downloading Database from Hetzner

### Method 1: SCP (Secure Copy)

**From Windows PowerShell or WSL**:

```bash
# Download to local machine
scp root@37.27.80.87:/mnt/HC_Volume_103879961/tracking.sqlite \
    C:/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/tracking_production_$(date +%Y%m%d).sqlite
```

**From WSL** (Linux path):

```bash
scp root@37.27.80.87:/mnt/HC_Volume_103879961/tracking.sqlite \
    /mnt/c/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/tracking_production_$(date +%Y%m%d).sqlite
```

### Method 2: Docker Copy

```bash
# Step 1: Copy from volume to container (easier to access)
ssh root@37.27.80.87
docker exec delcampe-app cp /data/tracking.sqlite /tmp/tracking_backup.sqlite

# Step 2: Copy from container to host
docker cp delcampe-app:/tmp/tracking_backup.sqlite /root/tracking_backup.sqlite

# Step 3: Download from host to local machine (from local terminal)
scp root@37.27.80.87:/root/tracking_backup.sqlite \
    C:/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/tracking_production_20251105.sqlite
```

### Method 3: SQLite Dump (as SQL file)

**Advantages**: Text format, easier to inspect, smaller file

```bash
# On Hetzner
ssh root@37.27.80.87

# Create SQL dump
docker exec delcampe-app sqlite3 /data/tracking.sqlite .dump > /root/tracking_dump.sql

# Compress
gzip /root/tracking_dump.sql

# Download (from local terminal)
scp root@37.27.80.87:/root/tracking_dump.sql.gz \
    C:/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/
```

**Restore from dump**:

```bash
# Uncompress
gunzip tracking_dump.sql.gz

# Restore to local SQLite
sqlite3 new_database.sqlite < tracking_dump.sql
```

### Method 4: Automated Backup Script

**Create on Hetzner**: `/root/backup_database.sh`

```bash
#!/bin/bash
# Automated database backup script

BACKUP_DIR="/root/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/tracking_$DATE.sqlite"

# Create backup directory if not exists
mkdir -p $BACKUP_DIR

# Copy database
docker exec delcampe-app sqlite3 /data/tracking.sqlite ".backup /tmp/backup.sqlite"
docker cp delcampe-app:/tmp/backup.sqlite $BACKUP_FILE

# Compress
gzip $BACKUP_FILE

# Keep only last 7 days of backups
find $BACKUP_DIR -name "tracking_*.sqlite.gz" -mtime +7 -delete

echo "Backup created: $BACKUP_FILE.gz"
```

**Make executable**:
```bash
chmod +x /root/backup_database.sh
```

**Run manually**:
```bash
/root/backup_database.sh
```

**Schedule with cron** (daily at 2 AM):
```bash
crontab -e

# Add this line:
0 2 * * * /root/backup_database.sh >> /var/log/backup.log 2>&1
```

---

## Database Backup and Restore

### Local Backup (Before Major Changes)

**Always backup before**:
- Dropping columns or tables
- Major schema migrations
- Testing destructive operations

```bash
# Backup with timestamp
cp inst/app/data/tracking.sqlite \
   "C:/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/tracking_local_$(date +%Y%m%d_%H%M%S).sqlite"
```

### Restore Local Database

```bash
# Restore from backup
cp "C:/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/tracking_local_20251105.sqlite" \
   inst/app/data/tracking.sqlite
```

### Production Backup (Before Deployment)

```bash
# On Hetzner, before deploying
ssh root@37.27.80.87

# Backup current database
docker exec delcampe-app cp /data/tracking.sqlite /data/tracking_backup_$(date +%Y%m%d).sqlite

# Or copy to host
docker cp delcampe-app:/data/tracking.sqlite /root/tracking_backup_$(date +%Y%m%d).sqlite
```

### Restore Production Database

```bash
# Stop application
docker-compose down

# Restore database
cp /root/tracking_backup_20251105.sqlite /mnt/HC_Volume_103879961/tracking.sqlite

# Fix permissions
chown 999:999 /mnt/HC_Volume_103879961/tracking.sqlite

# Start application
docker-compose up -d
```

---

## Querying the Database

### From R Console (Local)

```r
# Connect
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")

# List all tables
DBI::dbListTables(con)

# Show table structure
DBI::dbGetQuery(con, "PRAGMA table_info(postal_cards)")

# Query data
results <- DBI::dbGetQuery(con, "
  SELECT * FROM postal_cards
  WHERE image_type = 'recto'
  LIMIT 10
")

# Count records
DBI::dbGetQuery(con, "SELECT COUNT(*) as total FROM postal_cards")

# Complex query with JOIN
DBI::dbGetQuery(con, "
  SELECT
    pc.card_id,
    pc.image_type,
    cp.ai_title,
    el.status as ebay_status
  FROM postal_cards pc
  LEFT JOIN card_processing cp ON pc.card_id = cp.card_id
  LEFT JOIN ebay_listings el ON pc.card_id = el.card_id
  WHERE cp.ai_title IS NOT NULL
  LIMIT 20
")

# Disconnect
DBI::dbDisconnect(con)
```

### From Hetzner (Production)

```bash
# Enter container shell
ssh root@37.27.80.87
docker exec -it delcampe-app /bin/bash

# Use sqlite3 CLI
sqlite3 /data/tracking.sqlite

# List tables
.tables

# Show schema
.schema postal_cards

# Query
SELECT COUNT(*) FROM postal_cards;

# Exit
.quit
```

### Using SQLite Browser (GUI)

**Download**: https://sqlitebrowser.org/

**Steps**:
1. Download database from Hetzner (see above)
2. Open in SQLite Browser
3. Browse data, execute queries, export to CSV

---

## Common Database Queries

### Check Database Size

```r
# Get file size
file.size("inst/app/data/tracking.sqlite") / 1024^2  # Size in MB
```

```bash
# On Hetzner
docker exec delcampe-app du -h /data/tracking.sqlite
```

### Count Records by Table

```r
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")

tables <- DBI::dbListTables(con)
counts <- sapply(tables, function(tbl) {
  DBI::dbGetQuery(con, paste0("SELECT COUNT(*) as n FROM ", tbl))$n
})

data.frame(
  table = tables,
  records = counts
)

DBI::dbDisconnect(con)
```

### Find Large Tables

```r
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")

# Get page counts (1 page = 4KB in SQLite)
DBI::dbGetQuery(con, "
  SELECT
    name as table_name,
    (SELECT COUNT(*) FROM pragma_table_info(name)) as columns,
    (SELECT COUNT(*) FROM sqlite_master WHERE tbl_name = name AND type = 'index') as indexes
  FROM sqlite_master
  WHERE type = 'table'
  ORDER BY name
")

DBI::dbDisconnect(con)
```

### Vacuum Database (Reclaim Space)

```r
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
DBI::dbExecute(con, "VACUUM")
DBI::dbDisconnect(con)
```

```bash
# On Hetzner
docker exec delcampe-app sqlite3 /data/tracking.sqlite "VACUUM;"
```

---

## Database Schema Documentation

**Current tables** (as of 2025-11-05):

1. **users** - User authentication
2. **sessions** - User sessions
3. **postal_cards** - Uploaded postal card images
4. **card_processing** - AI extraction results
5. **images** - Image upload tracking
6. **session_activity** - User activity tracking
7. **ebay_listings** - eBay listing creation/status
8. **ebay_listings_cache** - eBay API sync cache
9. **ebay_accounts** - Multiple eBay account management
10. **stamps** - Stamp image processing (separate workflow)

**Full schema**: See `R/tracking_database.R` for complete CREATE TABLE statements.

---

## Best Practices

1. **Always use get_db_path()**: Don't hardcode database paths
2. **Use parameterized queries**: Prevent SQL injection
   ```r
   # GOOD:
   DBI::dbGetQuery(con, "SELECT * FROM users WHERE id = ?", params = list(user_id))

   # BAD:
   DBI::dbGetQuery(con, paste0("SELECT * FROM users WHERE id = ", user_id))
   ```
3. **Always disconnect**: Use `on.exit(DBI::dbDisconnect(con))`
4. **Test migrations**: Both fresh DB and existing DB scenarios
5. **Backup before migrations**: Especially in production
6. **Use transactions for multi-step operations**:
   ```r
   DBI::dbExecute(con, "BEGIN TRANSACTION")
   tryCatch({
     DBI::dbExecute(con, "INSERT ...")
     DBI::dbExecute(con, "UPDATE ...")
     DBI::dbExecute(con, "COMMIT")
   }, error = function(e) {
     DBI::dbExecute(con, "ROLLBACK")
   })
   ```

---

## Related Documentation

- [Deployment Workflow](DEPLOYMENT_WORKFLOW.md)
- [Testing Guide](../dev/TESTING_GUIDE.md)
- [Architecture Overview](architecture/overview.md)
