# Authentication System Setup Script
# Run this ONCE before testing authentication
# This script can be run OUTSIDE the app (no login required)

cat("\n")
cat("══════════════════════════════════════════════════════════════\n")
cat("   Authentication System Setup\n")
cat("══════════════════════════════════════════════════════════════\n\n")

# Load required packages
library(DBI)
library(RSQLite)
library(digest)

# Database path
db_path <- "inst/app/data/tracking.sqlite"

# Ensure directory exists
dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)

# Connect to database
cat("📊 Connecting to database...\n")
con <- DBI::dbConnect(RSQLite::SQLite(), db_path)

# CRITICAL: Disable foreign keys temporarily for migration
DBI::dbExecute(con, "PRAGMA foreign_keys = OFF")

# Check if users table exists
if (DBI::dbExistsTable(con, "users")) {
  cat("ℹ️  Users table exists. Checking schema...\n")

  schema <- DBI::dbGetQuery(con, "PRAGMA table_info(users)")

  if ("password_hash" %in% schema$name) {
    cat("✅ Users table already has authentication schema!\n")

    # Check master users
    masters <- DBI::dbGetQuery(con,
      "SELECT email, role FROM users WHERE is_master = 1")

    if (nrow(masters) > 0) {
      cat("✅ Master users found:\n")
      for (i in 1:nrow(masters)) {
        cat("   • ", masters$email[i], "\n", sep = "")
      }
      cat("\n✅ Authentication system is ready!\n")
      cat("\nYou can now:\n")
      cat("1. Run: golem::run_dev()\n")
      cat("2. Login with: master1@delcampe.com / DelcampeMaster2025!\n\n")
      DBI::dbDisconnect(con)
      quit()
    }
  }

  # Old schema - need to migrate
  cat("⚠️  Old users table found. Migrating to authentication schema...\n")

  # Backup old data
  old_users <- DBI::dbGetQuery(con, "SELECT * FROM users")
  cat("📦 Backed up ", nrow(old_users), " existing users\n")

  # Rename old table
  DBI::dbExecute(con, "ALTER TABLE users RENAME TO users_old")
  cat("✅ Renamed old table to users_old\n")
}

# Create new users table with authentication schema
cat("🔨 Creating users table with authentication schema...\n")
DBI::dbExecute(con, "
  CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('master', 'admin', 'user')),
    is_master BOOLEAN NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    created_by TEXT,
    last_login TEXT,
    active BOOLEAN NOT NULL DEFAULT 1
  )
")

# Create indexes
DBI::dbExecute(con, "CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email)")
DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_users_active ON users(active)")
DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_users_role ON users(role)")

cat("✅ Users table created\n")

# Seed master users
cat("👥 Creating master users...\n")

# Hash password using SHA-256
hash_password <- function(password) {
  digest::digest(password, algo = "sha256", serialize = FALSE)
}

master_password <- "DelcampeMaster2025!"
master_hash <- hash_password(master_password)
current_time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

# Insert master users
DBI::dbExecute(con, "
  INSERT INTO users (email, password_hash, role, is_master, created_at, active)
  VALUES (?, ?, 'master', 1, ?, 1)
", params = list("master1@delcampe.com", master_hash, current_time))

DBI::dbExecute(con, "
  INSERT INTO users (email, password_hash, role, is_master, created_at, active)
  VALUES (?, ?, 'master', 1, ?, 1)
", params = list("master2@delcampe.com", master_hash, current_time))

cat("✅ Created 2 master users\n\n")

# Drop old users table if it exists
if (DBI::dbExistsTable(con, "users_old")) {
  DBI::dbExecute(con, "DROP TABLE users_old")
  cat("🗑️  Removed old users table\n\n")
}

# Re-enable foreign keys
DBI::dbExecute(con, "PRAGMA foreign_keys = ON")

# Verify
masters <- DBI::dbGetQuery(con,
  "SELECT email, role, is_master, created_at FROM users WHERE is_master = 1")

cat("══════════════════════════════════════════════════════════════\n")
cat("✅ AUTHENTICATION SYSTEM READY\n")
cat("══════════════════════════════════════════════════════════════\n\n")

cat("Master Users Created:\n")
for (i in 1:nrow(masters)) {
  cat("  • ", masters$email[i], " (", masters$role[i], ")\n", sep = "")
}

cat("\n🔑 Login Credentials:\n")
cat("   Email: master1@delcampe.com\n")
cat("   Password: DelcampeMaster2025!\n\n")

cat("⚠️  IMPORTANT: Change this password after first login!\n\n")

cat("Next Steps:\n")
cat("1. Run: golem::run_dev()\n")
cat("2. Login with the credentials above\n")
cat("3. Go to Settings and change your password\n\n")

# Close connection
DBI::dbDisconnect(con)

cat("✅ Setup complete!\n\n")
