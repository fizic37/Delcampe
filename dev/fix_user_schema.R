# Fix User Schema - Add user_id for Backward Compatibility
# This script adds a user_id TEXT column to users table
# and populates it with string version of id

cat("\n")
cat("══════════════════════════════════════════════════════════════\n")
cat("   Fix User Schema - Add user_id Column\n")
cat("══════════════════════════════════════════════════════════════\n\n")

db_path <- "inst/app/data/tracking.sqlite"

if (!file.exists(db_path)) {
  cat("❌ Database not found:", db_path, "\n\n")
  stop("Database does not exist")
}

con <- DBI::dbConnect(RSQLite::SQLite(), db_path)

# Wrap everything in tryCatch to ensure connection closes
tryCatch({

# Disable foreign keys temporarily
DBI::dbExecute(con, "PRAGMA foreign_keys = OFF")

# Check current users table schema
schema <- DBI::dbGetQuery(con, "PRAGMA table_info(users)")
cat("📊 Current users table schema:\n")
print(schema[, c("name", "type")])
cat("\n")

if ("user_id" %in% schema$name) {
  cat("✅ user_id column already exists\n\n")
} else {
  cat("🔄 Adding user_id column...\n")

  # Add user_id column (without UNIQUE constraint - we'll add that via index)
  DBI::dbExecute(con, "ALTER TABLE users ADD COLUMN user_id TEXT")
  cat("✅ Added user_id column\n")

  # Populate user_id with string version of id
  DBI::dbExecute(con, "UPDATE users SET user_id = CAST(id AS TEXT)")
  cat("✅ Populated user_id from id\n")

  # Create unique index on user_id
  DBI::dbExecute(con, "CREATE UNIQUE INDEX idx_users_user_id ON users(user_id)")
  cat("✅ Created unique index on user_id\n\n")
}

# Check sessions table and fix if needed
cat("🔄 Checking sessions table...\n")
sessions_exist <- DBI::dbExistsTable(con, "sessions")

if (sessions_exist) {
  # Check if there are any sessions
  session_count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as cnt FROM sessions")$cnt
  cat("📊 Found", session_count, "existing sessions\n")

  if (session_count > 0) {
    # We have data, so we need to migrate carefully
    cat("🔄 Migrating sessions table...\n")

    # Backup sessions
    DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS sessions_backup AS SELECT * FROM sessions")

    # Drop old sessions table
    DBI::dbExecute(con, "DROP TABLE sessions")

    # Recreate with correct foreign key
    DBI::dbExecute(con, "
      CREATE TABLE sessions (
        session_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        session_start DATETIME DEFAULT CURRENT_TIMESTAMP,
        session_end DATETIME,
        status TEXT DEFAULT 'active',
        notes TEXT,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      )
    ")

    # Try to restore compatible data
    tryCatch({
      DBI::dbExecute(con, "
        INSERT INTO sessions (session_id, user_id, session_start, session_end, status, notes)
        SELECT session_id, user_id, session_start, session_end, status, notes
        FROM sessions_backup
        WHERE user_id IN (SELECT user_id FROM users)
      ")
      cat("✅ Migrated compatible sessions\n")
    }, error = function(e) {
      cat("⚠️  Warning: Could not migrate old sessions:", e$message, "\n")
    })

    # Drop backup
    DBI::dbExecute(con, "DROP TABLE IF EXISTS sessions_backup")
  }
} else {
  cat("ℹ️  Sessions table doesn't exist (will be created by initialize_tracking_db)\n")
}

# Re-enable foreign keys
DBI::dbExecute(con, "PRAGMA foreign_keys = ON")

# Verify final schema
cat("\n📊 Final users table schema:\n")
final_schema <- DBI::dbGetQuery(con, "PRAGMA table_info(users)")
print(final_schema[, c("name", "type")])

# Show current users
users <- DBI::dbGetQuery(con, "SELECT id, user_id, email, role FROM users")
cat("\n📊 Current users:\n")
print(users)

cat("\n")
cat("══════════════════════════════════════════════════════════════\n")
cat("✅ SCHEMA FIX COMPLETE\n")
cat("══════════════════════════════════════════════════════════════\n\n")
cat("Next steps:\n")
cat("1. Logout and login again\n")
cat("2. Try the 'Refresh from eBay' button\n\n")

}, error = function(e) {
  cat("❌ Error during migration:", e$message, "\n")
}, finally = {
  # Always close connection
  if (DBI::dbIsValid(con)) {
    DBI::dbDisconnect(con)
    cat("🔌 Database connection closed\n")
  }
})
