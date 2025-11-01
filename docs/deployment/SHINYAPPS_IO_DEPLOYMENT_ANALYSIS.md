# Shinyapps.io Deployment Readiness Analysis

**Date:** 2025-10-30
**Project:** Delcampe Postal Card Processor
**Target Platform:** shinyapps.io
**Analyst:** Claude Code

---

## Executive Summary

### Current Status: ⚠️ NOT READY FOR PRODUCTION

**Critical Issues Identified:**
- 🔴 **Security:** Hardcoded credentials and API keys in source code
- 🔴 **Data Persistence:** SQLite database incompatible with shinyapps.io architecture
- 🟡 **Authentication:** Login system needs hardening before production

**Estimated Time to Production-Ready:** 1-2 days of development work

---

## Table of Contents

1. [Security Analysis](#security-analysis)
2. [Database Persistence Problem](#database-persistence-problem)
3. [Deployment Options & Recommendations](#deployment-options--recommendations)
4. [Migration Strategy](#migration-strategy)
5. [Action Plan](#action-plan)
6. [Appendix: Code Examples](#appendix-code-examples)

---

## Security Analysis

### 🔴 Critical Security Issues

#### Issue 1: Hardcoded Credentials in Login Module

**Location:** `R/mod_login.R:167-188`

```r
textInput(
  inputId = ns("userName"),
  label = NULL,
  placeholder = "Email address",
  value = "marius.tita81@gmail.com"  // ⚠️ HARDCODED
)

passwordInput(
  inputId = ns("passwd"),
  label = NULL,
  placeholder = "Password",
  value = "admin123"  // ⚠️ HARDCODED
)
```

**Risk Level:** CRITICAL
**Impact:** Anyone with source code access can authenticate as admin
**Exploitability:** Trivial - credentials visible in GitHub/deployed code

**Required Action:**
```r
# BEFORE DEPLOYMENT - Remove default values:
textInput(
  inputId = ns("userName"),
  label = NULL,
  placeholder = "Email address"
  # value = ""  // Remove this line entirely
)
```

---

#### Issue 2: API Keys Stored in RDS Files

**Sensitive Files:**
- `data/llm_config.rds` - Contains Claude & OpenAI API keys
- `inst/app/data/ebay_accounts.rds` - Contains eBay OAuth credentials

**Current Protection:**
- ✅ Files are in `.gitignore` (not committed to Git)
- ❌ Files WILL be deployed to shinyapps.io with the app
- ❌ Anyone gaining access to deployed app can extract keys

**Risk Assessment:**

| Asset | Current Storage | Risk Level | Exposure Path |
|-------|----------------|------------|---------------|
| Claude API Key | `data/llm_config.rds` | HIGH | App file access |
| OpenAI API Key | `data/llm_config.rds` | HIGH | App file access |
| eBay OAuth Tokens | `inst/app/data/ebay_accounts.rds` | CRITICAL | App file access |
| eBay Client Secret | Likely in RDS file | CRITICAL | App file access |

**Required Action:** Migrate to environment variables (see [Migration Strategy](#api-key-migration))

---

#### Issue 3: Login Bypass Potential

**Current Implementation:**
- Login UI exists (`mod_login_ui`)
- Authentication logic uses `authenticate_user()` from auth system
- **Concern:** Verify authentication is enforced before app access

**Verification Needed:**
```r
# Check in R/app_server.R - ensure this pattern exists:
observe({
  if (vals$login == FALSE) {
    # Prevent any other server logic from executing
    return()
  }
  # ... rest of app logic only runs after login ...
})
```

**Required Action:**
1. Audit `R/app_server.R` for authentication enforcement
2. Test login bypass attempts
3. Ensure all reactive logic checks `vals$login` status

---

### 🟡 Moderate Security Considerations

#### User Authentication Database

**Location:** User credentials stored in SQLite (`inst/app/data/tracking.sqlite`)

**Current State:**
- Passwords hashed with SHA-256 ✅
- Master user protection implemented ✅
- Session management in place ✅

**Post-Migration Note:** When migrating to cloud database, ensure:
- Database connection uses SSL/TLS
- Database credentials are in environment variables
- Connection pooling prevents credential leaks

---

### 🟢 Good Security Practices Observed

**Positive Findings:**
- ✅ Password hashing (SHA-256) implemented
- ✅ Sensitive files in `.gitignore`
- ✅ Master user protection (cannot delete each other)
- ✅ Global error handler with session tracking (`R/app_server.R:8-20`)
- ✅ Input validation in authentication flow

---

## Database Persistence Problem

### 🔴 Critical Issue: SQLite Incompatible with shinyapps.io

#### The Problem

Your application extensively uses SQLite for data persistence:

**Database Location:** `inst/app/data/tracking.sqlite`

**Tables in Use:**
```sql
-- Core tracking (legacy)
- users
- sessions
- images
- processing_log

-- 3-layer architecture (current)
- postal_cards (master table)
- card_processing (AI data & crops)
- session_activity (user actions)

-- eBay & AI integration
- ai_extractions
- ebay_posts
- ebay_listings
```

**Current Database Size:** ~150+ operations tracked across 11 tables

---

#### Why SQLite Fails on shinyapps.io

**Architecture Mismatch:**

```
shinyapps.io Architecture:
┌─────────────────────────────────────┐
│  Load Balancer                      │
└────────┬─────────────┬──────────────┘
         │             │
    ┌────▼────┐   ┌────▼────┐
    │Instance1│   │Instance2│
    │SQLite A │   │SQLite B │  ⚠️ Separate copies!
    └─────────┘   └─────────┘
```

**Problem 1: Ephemeral Containers**
- Containers restart frequently (daily, during updates, scaling events)
- File system is NOT persistent
- All database changes are lost on restart
- Database reverts to deployment state

**Problem 2: Multi-Instance Inconsistency**
- Multiple users → multiple container instances
- Each instance has its own SQLite file copy
- User A's data goes to Instance 1
- User B's data goes to Instance 2
- Data is completely fragmented and inconsistent

**Problem 3: No Access to Production Data**
- Cannot download SQLite file from shinyapps.io
- Cannot run migrations on production database
- No way to backup or export user data

---

#### Impact on Your Application

**Affected Features:**

| Feature | Impact | Severity |
|---------|--------|----------|
| User Sessions | Lost on restart | CRITICAL |
| Image Upload Tracking | Data loss/inconsistency | CRITICAL |
| AI Extraction History | Cannot retrieve past results | HIGH |
| eBay Posting Records | Lost tracking data | HIGH |
| Card Deduplication | False duplicates detected | HIGH |
| Tracking Viewer | Shows incomplete data | MEDIUM |

**Example Failure Scenario:**

```
User Flow:
1. User uploads postal card → Tracked in SQLite Instance 1
2. AI extraction runs → Saved to SQLite Instance 1
3. User refreshes page → Routed to Instance 2
4. ❌ No upload history found (on Instance 2)
5. User re-uploads same card → Tracked in SQLite Instance 2
6. Container restarts → Both databases reset
7. ❌ All data lost permanently
```

---

## Deployment Options & Recommendations

### Option A: PostgreSQL on AWS RDS Free Tier ⭐ (Production-Grade)

**Overview:** Amazon's managed PostgreSQL database service

**Pricing:**
- Free Tier: 750 hours/month for 12 months
- After Free Tier: ~$15-30/month (db.t3.micro)

**Setup Steps:**
1. Create AWS account
2. Navigate to RDS → Create database
3. Select PostgreSQL 15+
4. Choose `db.t3.micro` (Free Tier eligible)
5. Configure:
   - Database name: `delcampe_production`
   - Username: `delcampe_app`
   - Password: (generate secure password)
   - Public access: Yes (with VPC security group)
6. Security group: Allow inbound on port 5432 from shinyapps.io IPs
7. Note connection details:
   - Endpoint: `xxx.rds.amazonaws.com`
   - Port: 5432

**Pros:**
- ✅ Production-grade reliability
- ✅ Automatic backups (7-day retention)
- ✅ Point-in-time recovery
- ✅ Scalable (can upgrade instance size)
- ✅ High availability options
- ✅ AWS ecosystem integration

**Cons:**
- ⚠️ Requires AWS account setup
- ⚠️ More complex initial configuration
- ⚠️ Free tier expires after 12 months
- ⚠️ Need to manage security groups

**Best For:**
- Production applications with paying users
- Apps requiring high reliability
- Long-term projects with growth potential

---

### Option B: Supabase PostgreSQL ⭐⭐⭐ (RECOMMENDED)

**Overview:** Open-source Firebase alternative with PostgreSQL backend

**Pricing:**
- Free Forever: Up to 500MB database, 2GB bandwidth
- Pro: $25/month (8GB database, 50GB bandwidth)

**Setup Steps:**
1. Visit supabase.com → Sign up
2. Create new project
3. Wait ~2 minutes for provisioning
4. Go to Settings → Database
5. Copy connection string:
   ```
   postgresql://postgres:[password]@db.xxx.supabase.co:5432/postgres
   ```
6. Enable connection pooling (recommended)
7. Done!

**Pros:**
- ✅ Free forever tier (500MB sufficient for your use case)
- ✅ 5-minute setup (simplest option)
- ✅ Built-in database dashboard
- ✅ Automatic daily backups
- ✅ Real-time subscriptions (bonus feature)
- ✅ Row-level security (advanced security)
- ✅ No credit card required for free tier

**Cons:**
- ⚠️ 500MB storage limit (sufficient for ~10,000+ records)
- ⚠️ Third-party dependency
- ⚠️ Limited to Supabase infrastructure

**Best For:**
- Small to medium apps (1-100 users)
- Rapid prototyping → production
- Apps not requiring 99.99% uptime SLA
- **Your current use case** ⭐

**Why This is Recommended:**
1. You're currently at ~150 tracking records → 500MB is plenty
2. 5-minute setup vs 30 minutes (AWS)
3. Free forever vs Free for 1 year (AWS)
4. Can migrate to AWS later if you outgrow it
5. Easier development workflow (web dashboard)

---

### Option C: Google Sheets (Prototype Only)

**Overview:** Use Google Sheets API for data persistence

**Pricing:** Free

**Setup Steps:**
1. Create Google Sheet for data storage
2. Enable Google Sheets API
3. Install `googlesheets4` R package
4. Set up service account authentication

**Implementation:**
```r
library(googlesheets4)

save_tracking_record <- function(data) {
  gs4_auth(email = Sys.getenv("GOOGLE_SERVICE_ACCOUNT"))
  sheet_append(
    ss = Sys.getenv("GOOGLE_SHEET_ID"),
    data = data,
    sheet = "tracking"
  )
}
```

**Pros:**
- ✅ Free
- ✅ No database management
- ✅ Easy to view/export data (Google Sheets UI)
- ✅ Familiar spreadsheet interface

**Cons:**
- ❌ Slow for large datasets (100+ rows)
- ❌ Rate limits: 100 requests/100 seconds
- ❌ No transactions or rollback
- ❌ No complex queries (JOINs, indexes)
- ❌ Not designed for database operations
- ❌ No referential integrity

**Best For:**
- Quick prototypes (< 1 week lifespan)
- Data collection forms (< 1000 records)
- Read-only data display

**NOT Suitable For:**
- Your application (too complex, too many tables)

---

### Option D: Keep SQLite + Read-Only Deployment (Not Recommended)

**Concept:** Deploy SQLite with initial data, but don't write to it

**Limitations:**
- ❌ No user session persistence
- ❌ No upload tracking
- ❌ No AI extraction history
- ❌ App becomes mostly non-functional
- ❌ Defeats purpose of tracking system

**Only viable if:** You completely redesign app to be stateless (major rewrite)

---

## Migration Strategy

### Phase 1: API Key Migration (2-3 hours)

#### Current State Analysis

**Claude/OpenAI API Keys:**
- Stored in: `data/llm_config.rds`
- Read by: `R/ai_api_helpers.R::get_llm_config()`
- Used by: AI extraction module

**eBay Credentials:**
- Stored in: `inst/app/data/ebay_accounts.rds`
- Read by: `R/ebay_account_manager.R`
- Used by: eBay posting module

---

#### Migration Implementation

**Step 1: Update `R/ai_api_helpers.R`**

```r
#' Get LLM Configuration with Environment Variable Support
#' @description Reads from environment variables (production) or RDS file (development)
#' @return List with configuration
get_llm_config <- function() {
  # Default configuration
  config <- list(
    default_model = "claude-sonnet-4-5-20250929",
    temperature = 0.0,
    max_tokens = 1000,
    claude_api_key = "",
    openai_api_key = "",
    last_updated = NULL
  )

  # Determine environment
  is_production <- Sys.getenv("DEPLOY_ENV") == "production" ||
                   Sys.getenv("R_CONFIG_ACTIVE") == "shinyapps"

  if (is_production) {
    # PRODUCTION: Use environment variables
    cat("Loading API keys from environment variables\n")
    config$claude_api_key <- Sys.getenv("CLAUDE_API_KEY", "")
    config$openai_api_key <- Sys.getenv("OPENAI_API_KEY", "")

    # Validate
    if (config$claude_api_key == "" && config$openai_api_key == "") {
      warning("No API keys found in environment variables!")
    }

  } else {
    # DEVELOPMENT: Use local RDS file
    config_file <- "data/llm_config.rds"

    if (file.exists(config_file)) {
      cat("Loading API keys from local file:", config_file, "\n")
      tryCatch({
        saved_config <- readRDS(config_file)
        config <- modifyList(config, saved_config)
      }, error = function(e) {
        warning("Failed to read config file: ", e$message)
      })
    } else {
      warning("Config file not found, using empty keys")
    }
  }

  return(config)
}
```

**Step 2: Update `R/ebay_account_manager.R`**

```r
#' Load eBay Accounts with Environment Variable Support
load_ebay_accounts <- function() {
  is_production <- Sys.getenv("DEPLOY_ENV") == "production"

  if (is_production) {
    # PRODUCTION: Load from environment variables
    return(list(
      sandbox = list(
        client_id = Sys.getenv("EBAY_SANDBOX_CLIENT_ID"),
        client_secret = Sys.getenv("EBAY_SANDBOX_CLIENT_SECRET"),
        oauth_tokens = NULL  # Will be refreshed on first use
      ),
      production = list(
        client_id = Sys.getenv("EBAY_PROD_CLIENT_ID"),
        client_secret = Sys.getenv("EBAY_PROD_CLIENT_SECRET"),
        oauth_tokens = NULL
      )
    ))
  } else {
    # DEVELOPMENT: Load from RDS file
    accounts_file <- "inst/app/data/ebay_accounts.rds"
    if (file.exists(accounts_file)) {
      return(readRDS(accounts_file))
    } else {
      return(list())
    }
  }
}
```

**Step 3: Configure Environment Variables on shinyapps.io**

```r
# Option A: Via R console (before deployment)
library(rsconnect)

# Set up account if not already configured
setAccountInfo(
  name = "your-account-name",
  token = "your-token",
  secret = "your-secret"
)

# Configure environment variables (not directly supported in rsconnect)
# Must be done via shinyapps.io web dashboard
```

**Option B: Via shinyapps.io Dashboard (RECOMMENDED)**

1. Deploy app first (without env vars)
2. Log into shinyapps.io
3. Navigate to your application
4. Click **Settings** → **Variables**
5. Add the following variables:

```
Variable Name              | Value
---------------------------|----------------------------------
DEPLOY_ENV                 | production
CLAUDE_API_KEY             | sk-ant-api03-xxxx...
OPENAI_API_KEY             | sk-proj-xxxx...
EBAY_SANDBOX_CLIENT_ID     | YourSand-YourApp-SAND-xxxx
EBAY_SANDBOX_CLIENT_SECRET | SAND-xxxx...
EBAY_PROD_CLIENT_ID        | YourProd-YourApp-PROD-xxxx
EBAY_PROD_CLIENT_SECRET    | PROD-xxxx...
```

6. Click **Save Changes**
7. Restart application

---

### Phase 2: Database Migration (4-6 hours)

#### Step 1: Choose Database Provider

**Recommended: Supabase** (see [Option B](#option-b-supabase-postgresql-recommended))

---

#### Step 2: Create Supabase Project

1. Visit https://supabase.com/dashboard
2. Click **New Project**
3. Fill in:
   - Name: `delcampe-production`
   - Database Password: (generate strong password, save it!)
   - Region: Choose closest to your users
4. Wait 2-3 minutes for provisioning
5. Go to **Settings** → **Database**
6. Copy **Connection String** (Pooler):
   ```
   postgresql://postgres.xxx:[YOUR-PASSWORD]@aws-0-us-west-1.pooler.supabase.com:6543/postgres
   ```
7. Save connection details in password manager

---

#### Step 3: Update Database Connection Code

**Create new file: `R/database_config.R`**

```r
#' Get Database Connection
#'
#' @description Returns appropriate database connection based on environment
#' @return DBI connection object
#' @export
get_db_connection <- function() {
  is_production <- Sys.getenv("DEPLOY_ENV") == "production"

  if (is_production) {
    # PRODUCTION: PostgreSQL via connection pool
    message("Connecting to production PostgreSQL database...")

    pool::dbPool(
      drv = RPostgres::Postgres(),
      host = Sys.getenv("DB_HOST"),
      port = as.integer(Sys.getenv("DB_PORT", "5432")),
      dbname = Sys.getenv("DB_NAME"),
      user = Sys.getenv("DB_USER"),
      password = Sys.getenv("DB_PASSWORD"),
      # Connection pool settings
      minSize = 1,
      maxSize = 5,
      idleTimeout = 3600000  # 1 hour
    )
  } else {
    # DEVELOPMENT: SQLite
    message("Connecting to local SQLite database...")
    DBI::dbConnect(
      RSQLite::SQLite(),
      "inst/app/data/tracking.sqlite"
    )
  }
}

#' Close Database Connection
#'
#' @param con Database connection object
#' @export
close_db_connection <- function(con) {
  if (inherits(con, "Pool")) {
    pool::poolClose(con)
  } else {
    DBI::dbDisconnect(con)
  }
}
```

**Update `DESCRIPTION` file:**

```r
Imports:
    RPostgres,   # NEW
    pool,        # NEW
    base64enc,
    bslib,
    # ... rest of existing packages
```

---

#### Step 4: Modify `R/tracking_database.R`

**Update `initialize_tracking_db()` function:**

```r
#' Initialize the tracking database
#' @param db_path Path to SQLite database file (ignored in production)
#' @return Database connection status
#' @export
initialize_tracking_db <- function(db_path = "inst/app/data/tracking.sqlite") {
  tryCatch({
    # Get appropriate connection
    con <- get_db_connection()
    on.exit(close_db_connection(con))

    # Enable foreign keys and set journal mode
    # Note: PostgreSQL doesn't need these, but SQLite does
    if (inherits(con, "SQLiteConnection")) {
      DBI::dbExecute(con, "PRAGMA foreign_keys = ON")
      DBI::dbExecute(con, "PRAGMA journal_mode = WAL")
    }

    # Create tables (same SQL works for both SQLite and PostgreSQL)
    # Users table
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS users (
        user_id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        email TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_login TIMESTAMP
      )
    ")

    # ... rest of table creation SQL ...
    # (Your existing code works as-is)

    message("✅ Database initialized successfully")
    return(TRUE)

  }, error = function(e) {
    message("❌ Failed to initialize database: ", e$message)
    return(FALSE)
  })
}
```

**Update ALL database functions to use `get_db_connection()`:**

```r
# BEFORE (using hardcoded path):
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")

# AFTER (environment-aware):
con <- get_db_connection()
```

**Example updated function:**

```r
get_or_create_card <- function(file_hash, image_type, original_filename,
                               file_size = NULL, dimensions = NULL) {
  tryCatch({
    con <- get_db_connection()  # ✅ Changed
    on.exit(close_db_connection(con), add = TRUE)  # ✅ Changed

    # Rest of function unchanged...
    existing <- DBI::dbGetQuery(con, "
      SELECT card_id, times_uploaded
      FROM postal_cards
      WHERE file_hash = ? AND image_type = ?
    ", list(as.character(file_hash), as.character(image_type)))

    # ... etc ...
  }, error = function(e) {
    message("Error in get_or_create_card: ", e$message)
    return(NULL)
  })
}
```

---

#### Step 5: Create Migration Script

**Create file: `dev/migrations/migrate_to_postgres.R`**

```r
#!/usr/bin/env Rscript
#
# Migration Script: SQLite → PostgreSQL
#
# Purpose: Migrate existing local data to production PostgreSQL database
# Usage: source("dev/migrations/migrate_to_postgres.R")

library(DBI)
library(RSQLite)
library(RPostgres)

# Load environment variables
if (file.exists(".Renviron.production")) {
  readRenviron(".Renviron.production")
}

# Connect to source (SQLite)
message("📂 Connecting to source SQLite database...")
con_sqlite <- dbConnect(
  SQLite(),
  "inst/app/data/tracking.sqlite"
)

# Connect to destination (PostgreSQL)
message("🐘 Connecting to destination PostgreSQL database...")
con_postgres <- dbConnect(
  Postgres(),
  host = Sys.getenv("DB_HOST"),
  port = 5432,
  dbname = Sys.getenv("DB_NAME"),
  user = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASSWORD")
)

# Initialize schema on PostgreSQL
message("🏗️  Initializing PostgreSQL schema...")
source("R/tracking_database.R")
Sys.setenv(DEPLOY_ENV = "production")  # Force production mode
initialize_tracking_db()

# Tables to migrate (in dependency order)
tables <- c(
  "users",
  "sessions",
  "postal_cards",
  "card_processing",
  "session_activity",
  "images",
  "processing_log",
  "ai_extractions",
  "ebay_posts",
  "ebay_listings"
)

# Migrate each table
for (table_name in tables) {
  message(sprintf("📊 Migrating table: %s", table_name))

  # Read from SQLite
  data <- tryCatch({
    dbReadTable(con_sqlite, table_name)
  }, error = function(e) {
    message(sprintf("   ⚠️  Table %s not found in source, skipping", table_name))
    return(NULL)
  })

  if (is.null(data) || nrow(data) == 0) {
    message(sprintf("   ℹ️  No data in table %s", table_name))
    next
  }

  # Write to PostgreSQL
  tryCatch({
    dbWriteTable(
      con_postgres,
      table_name,
      data,
      append = TRUE,
      row.names = FALSE
    )
    message(sprintf("   ✅ Migrated %d rows", nrow(data)))
  }, error = function(e) {
    message(sprintf("   ❌ Error migrating %s: %s", table_name, e$message))
  })
}

# Verify migration
message("\n🔍 Verifying migration...")
for (table_name in tables) {
  count_sqlite <- tryCatch(
    dbGetQuery(con_sqlite, sprintf("SELECT COUNT(*) as n FROM %s", table_name))$n,
    error = function(e) 0
  )

  count_postgres <- tryCatch(
    dbGetQuery(con_postgres, sprintf("SELECT COUNT(*) as n FROM %s", table_name))$n,
    error = function(e) 0
  )

  status <- if (count_sqlite == count_postgres) "✅" else "⚠️"
  message(sprintf("%s %s: SQLite=%d, PostgreSQL=%d",
                  status, table_name, count_sqlite, count_postgres))
}

# Cleanup
dbDisconnect(con_sqlite)
dbDisconnect(con_postgres)

message("\n🎉 Migration complete!")
```

**Create `.Renviron.production` file (DO NOT COMMIT):**

```bash
# PostgreSQL Connection Details
DB_HOST=db.xxx.supabase.co
DB_PORT=5432
DB_NAME=postgres
DB_USER=postgres
DB_PASSWORD=your_password_here
DEPLOY_ENV=production
```

**Run migration:**

```r
source("dev/migrations/migrate_to_postgres.R")
```

---

#### Step 6: Update `.gitignore`

```bash
# Add to .gitignore:
.Renviron.production
dev/migrations/*.log
```

---

#### Step 7: Test Locally with PostgreSQL

**Before deploying, test locally:**

```r
# 1. Set environment to production mode
Sys.setenv(DEPLOY_ENV = "production")

# 2. Load environment variables
readRenviron(".Renviron.production")

# 3. Test database connection
source("R/database_config.R")
con <- get_db_connection()
DBI::dbGetQuery(con, "SELECT 1 as test")
# Should return: test = 1

# 4. Test a tracking function
source("R/tracking_database.R")
result <- get_tracking_statistics()
print(result)

# 5. Run the app
golem::run_dev()

# 6. Test upload → tracking → viewer flow
```

---

### Phase 3: Deployment (1 hour)

#### Pre-Deployment Checklist

**Security:**
- [ ] Removed hardcoded credentials from `R/mod_login.R`
- [ ] Updated `get_llm_config()` to use environment variables
- [ ] Updated `load_ebay_accounts()` to use environment variables
- [ ] Created `.Renviron.production` (not committed)

**Database:**
- [ ] Created Supabase project
- [ ] Ran schema initialization on PostgreSQL
- [ ] Migrated existing data (if any)
- [ ] Tested database connection locally
- [ ] Updated `DESCRIPTION` with `RPostgres` and `pool`

**Code:**
- [ ] Created `R/database_config.R`
- [ ] Updated all database functions to use `get_db_connection()`
- [ ] Tested app locally with PostgreSQL
- [ ] Ran critical tests: `source("dev/run_critical_tests.R")`

---

#### Deployment Steps

**Step 1: Install rsconnect (if not already installed)**

```r
install.packages("rsconnect")
```

**Step 2: Configure shinyapps.io Account**

```r
library(rsconnect)

# Get your tokens from https://www.shinyapps.io/admin/#/tokens
rsconnect::setAccountInfo(
  name   = "your-account-name",
  token  = "your-token-here",
  secret = "your-secret-here"
)

# Verify connection
rsconnect::accounts()
```

**Step 3: Deploy Application**

```r
# Deploy to shinyapps.io
rsconnect::deployApp(
  appName = "delcampe-app",
  appTitle = "Delcampe Postal Card Processor",
  account = "your-account-name",
  forceUpdate = TRUE,
  launch.browser = FALSE
)

# This will:
# 1. Bundle your app code
# 2. Upload to shinyapps.io
# 3. Install dependencies (takes 5-10 minutes first time)
# 4. Start the application
```

**Step 4: Configure Environment Variables**

1. Log into https://www.shinyapps.io/
2. Navigate to **Applications** → **delcampe-app**
3. Click **Settings** tab
4. Click **Variables** section
5. Add each variable:

| Variable | Value | Notes |
|----------|-------|-------|
| `DEPLOY_ENV` | `production` | Triggers production mode |
| `CLAUDE_API_KEY` | `sk-ant-api03-...` | From Claude Console |
| `OPENAI_API_KEY` | `sk-proj-...` | From OpenAI Dashboard |
| `EBAY_SANDBOX_CLIENT_ID` | `YourSand-...` | From eBay Dev Portal |
| `EBAY_SANDBOX_CLIENT_SECRET` | `SAND-...` | From eBay Dev Portal |
| `EBAY_PROD_CLIENT_ID` | `YourProd-...` | From eBay Dev Portal |
| `EBAY_PROD_CLIENT_SECRET` | `PROD-...` | From eBay Dev Portal |
| `DB_HOST` | `db.xxx.supabase.co` | From Supabase Dashboard |
| `DB_PORT` | `5432` | PostgreSQL default port |
| `DB_NAME` | `postgres` | Supabase default database |
| `DB_USER` | `postgres` | Supabase default user |
| `DB_PASSWORD` | `your_password` | From Supabase setup |

6. Click **Save**
7. Click **Restart** to apply changes

**Step 5: Verify Deployment**

```r
# Open deployed app
rsconnect::showLogs(account = "your-account-name", appName = "delcampe-app")

# Watch for errors in logs
# Look for:
# ✅ "Loading API keys from environment variables"
# ✅ "Connecting to production PostgreSQL database"
# ✅ "Database initialized successfully"
```

**Step 6: Test Production Application**

1. Navigate to your app URL: `https://your-account.shinyapps.io/delcampe-app/`
2. Test authentication (with real credentials)
3. Upload a test image
4. Verify database write (check Supabase dashboard)
5. Refresh page, verify data persists
6. Test AI extraction
7. Test eBay integration
8. Check logs for errors

---

#### Troubleshooting Deployment Issues

**Issue: "Package 'RPostgres' not found"**

```r
# Solution: Explicitly list in DESCRIPTION Imports
# Edit DESCRIPTION file:
Imports:
    RPostgres,
    pool,
    # ... rest
```

**Issue: "Could not connect to database"**

```r
# Solution 1: Check environment variables are set
# In shinyapps.io dashboard → Settings → Variables

# Solution 2: Verify Supabase connection string
# Test connection from local machine:
library(RPostgres)
con <- dbConnect(
  Postgres(),
  host = "db.xxx.supabase.co",
  port = 5432,
  dbname = "postgres",
  user = "postgres",
  password = "your_password"
)
dbGetQuery(con, "SELECT 1")
```

**Issue: "API key not found"**

```r
# Solution: Check environment variable names match exactly
# In code:     Sys.getenv("CLAUDE_API_KEY")
# In shinyapps.io: Variable name must be "CLAUDE_API_KEY" (exact match)
```

**Issue: App crashes on startup**

```r
# View detailed logs:
rsconnect::showLogs(
  account = "your-account-name",
  appName = "delcampe-app",
  streaming = TRUE
)

# Look for error messages in output
```

---

### Phase 4: Post-Deployment Operations

#### How to Update the Database Schema

**Scenario:** You want to add a new column or table to production

**Workflow:**

1. **Develop Locally (SQLite)**
   ```r
   # Make changes to R/tracking_database.R
   # Test locally with SQLite
   con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
   DBI::dbExecute(con, "ALTER TABLE postal_cards ADD COLUMN new_field TEXT")
   ```

2. **Create Migration Script**
   ```r
   # Create: dev/migrations/add_new_field.R
   library(RPostgres)

   readRenviron(".Renviron.production")

   con <- dbConnect(
     Postgres(),
     host = Sys.getenv("DB_HOST"),
     port = 5432,
     dbname = Sys.getenv("DB_NAME"),
     user = Sys.getenv("DB_USER"),
     password = Sys.getenv("DB_PASSWORD")
   )

   # Run migration
   dbExecute(con, "ALTER TABLE postal_cards ADD COLUMN new_field TEXT")

   # Verify
   dbGetQuery(con, "SELECT column_name FROM information_schema.columns
                     WHERE table_name = 'postal_cards'")

   dbDisconnect(con)
   ```

3. **Execute Migration**
   ```r
   source("dev/migrations/add_new_field.R")
   ```

4. **Deploy Updated App**
   ```r
   rsconnect::deployApp(forceUpdate = TRUE)
   ```

**No need to download/upload database files!** Migrations run directly against production database.

---

#### How to Access Production Data

**Option A: Via R Console (Recommended)**

```r
# Load production credentials
readRenviron(".Renviron.production")

# Connect
library(RPostgres)
con <- dbConnect(
  Postgres(),
  host = Sys.getenv("DB_HOST"),
  port = 5432,
  dbname = Sys.getenv("DB_NAME"),
  user = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASSWORD")
)

# Query data
recent_uploads <- dbGetQuery(con, "
  SELECT * FROM postal_cards
  ORDER BY first_seen DESC
  LIMIT 10
")

# Export to CSV
write.csv(recent_uploads, "production_data_export.csv")

# Cleanup
dbDisconnect(con)
```

**Option B: Via Supabase Dashboard**

1. Log into Supabase
2. Navigate to your project
3. Click **Table Editor**
4. Browse tables, run SQL queries
5. Export data to CSV

**Option C: Via Database Client (DBeaver, pgAdmin, etc.)**

1. Download DBeaver Community Edition
2. Create new PostgreSQL connection
3. Enter Supabase connection details
4. Connect and browse/query data

---

#### Monitoring & Maintenance

**Daily Checks:**

```r
# Check app status
rsconnect::showMetrics(
  account = "your-account-name",
  appName = "delcampe-app"
)

# View recent logs
rsconnect::showLogs(
  account = "your-account-name",
  appName = "delcampe-app",
  entries = 100
)
```

**Weekly Tasks:**
- Review error logs for patterns
- Check database size: `SELECT pg_database_size('postgres') / 1024 / 1024 as size_mb;`
- Verify backups are running (Supabase dashboard)

**Monthly Tasks:**
- Review API usage (Claude, OpenAI, eBay)
- Check database growth trends
- Update dependencies if needed

---

## Action Plan

### Pre-Deployment Tasks

#### Priority 1: Security (MUST DO)

**Task 1.1: Remove Hardcoded Credentials**

| File | Line | Action | Time |
|------|------|--------|------|
| `R/mod_login.R` | 167 | Remove `value = "marius.tita81@gmail.com"` | 5 min |
| `R/mod_login.R` | 188 | Remove `value = "admin123"` | 5 min |

**Task 1.2: Migrate API Keys to Environment Variables**

| Step | Action | Time |
|------|--------|------|
| 1 | Update `R/ai_api_helpers.R::get_llm_config()` | 30 min |
| 2 | Update `R/ebay_account_manager.R::load_ebay_accounts()` | 30 min |
| 3 | Create `.Renviron.production` (local testing) | 10 min |
| 4 | Test locally with environment variables | 20 min |

**Total Security Tasks: ~2 hours**

---

#### Priority 2: Database Migration (MUST DO)

**Task 2.1: Set Up Supabase**

| Step | Action | Time |
|------|--------|------|
| 1 | Create Supabase account | 5 min |
| 2 | Create new project | 3 min |
| 3 | Copy connection details | 2 min |

**Task 2.2: Update Database Code**

| Step | Action | Time |
|------|--------|------|
| 1 | Create `R/database_config.R` | 45 min |
| 2 | Update `R/tracking_database.R` functions | 90 min |
| 3 | Update `DESCRIPTION` dependencies | 5 min |
| 4 | Install `RPostgres` and `pool` packages | 5 min |

**Task 2.3: Migrate Existing Data**

| Step | Action | Time |
|------|--------|------|
| 1 | Create migration script | 30 min |
| 2 | Test schema creation on PostgreSQL | 15 min |
| 3 | Run data migration (if needed) | 10 min |

**Task 2.4: Local Testing**

| Step | Action | Time |
|------|--------|------|
| 1 | Test database connection | 10 min |
| 2 | Test tracking functions | 15 min |
| 3 | Run full app workflow | 20 min |
| 4 | Run critical tests | 10 min |

**Total Database Tasks: ~4 hours**

---

#### Priority 3: Deployment (FINAL STEP)

**Task 3.1: Deploy Application**

| Step | Action | Time |
|------|--------|------|
| 1 | Configure rsconnect account | 10 min |
| 2 | Deploy to shinyapps.io | 15 min |
| 3 | Configure environment variables | 15 min |
| 4 | Restart application | 5 min |

**Task 3.2: Verification**

| Step | Action | Time |
|------|--------|------|
| 1 | Test authentication | 5 min |
| 2 | Test upload + tracking | 10 min |
| 3 | Test AI extraction | 5 min |
| 4 | Test eBay integration | 5 min |
| 5 | Verify data persistence | 5 min |
| 6 | Review logs for errors | 10 min |

**Total Deployment Tasks: ~1.5 hours**

---

### Estimated Timeline

| Phase | Duration | Can Start |
|-------|----------|-----------|
| Security Fixes | 2 hours | Immediately |
| Database Migration | 4 hours | After security fixes |
| Deployment | 1.5 hours | After database migration |
| **Total** | **~8 hours** | **1 work day** |

---

### Recommended Schedule

**Session 1 (Morning - 3 hours):**
1. Remove hardcoded credentials (15 min)
2. Migrate API keys to env vars (1.5 hours)
3. Test locally (30 min)
4. ☕ Break

**Session 2 (Afternoon - 4 hours):**
1. Set up Supabase (10 min)
2. Update database code (2.5 hours)
3. Test database migration (1 hour)
4. ☕ Break

**Session 3 (Evening - 1.5 hours):**
1. Deploy to shinyapps.io (45 min)
2. Test production app (40 min)
3. 🎉 Production ready!

---

## Appendix: Code Examples

### Complete Environment Variable Setup

**`.Renviron.production` (for local testing):**

```bash
# ============================================
# PRODUCTION ENVIRONMENT CONFIGURATION
# ============================================
# WARNING: DO NOT COMMIT THIS FILE TO GIT
# Add to .gitignore immediately!

# Environment identifier
DEPLOY_ENV=production

# Database connection (Supabase)
DB_HOST=db.xxxxxxxxxxxx.supabase.co
DB_PORT=5432
DB_NAME=postgres
DB_USER=postgres
DB_PASSWORD=your_secure_password_here

# AI API Keys
CLAUDE_API_KEY=sk-ant-api03-your-key-here
OPENAI_API_KEY=sk-proj-your-key-here

# eBay API Credentials - Sandbox
EBAY_SANDBOX_CLIENT_ID=YourSand-YourAppl-SAND-xxxxxxxx-xxxxxxxx
EBAY_SANDBOX_CLIENT_SECRET=SAND-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# eBay API Credentials - Production
EBAY_PROD_CLIENT_ID=YourProd-YourAppl-PROD-xxxxxxxx-xxxxxxxx
EBAY_PROD_CLIENT_SECRET=PROD-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

### Updated `.gitignore`

```bash
# Add these lines to existing .gitignore:

# Production environment files
.Renviron.production
.env.production

# Database migration logs
dev/migrations/*.log
dev/migrations/*.backup

# Local PostgreSQL connection testing
.pgpass
```

---

### Testing Script

**Create `dev/test_production_config.R`:**

```r
#!/usr/bin/env Rscript
#
# Test Production Configuration
# Usage: source("dev/test_production_config.R")

message("=== Testing Production Configuration ===\n")

# Load production environment
if (!file.exists(".Renviron.production")) {
  stop("❌ .Renviron.production not found! Create it first.")
}
readRenviron(".Renviron.production")

# Test 1: Environment variables
message("1️⃣  Checking environment variables...")
required_vars <- c(
  "DEPLOY_ENV",
  "DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD",
  "CLAUDE_API_KEY", "OPENAI_API_KEY"
)

missing_vars <- character(0)
for (var in required_vars) {
  value <- Sys.getenv(var)
  if (value == "") {
    missing_vars <- c(missing_vars, var)
    message(sprintf("   ❌ %s: NOT SET", var))
  } else {
    # Show first 10 chars only for security
    preview <- substr(value, 1, 10)
    message(sprintf("   ✅ %s: %s...", var, preview))
  }
}

if (length(missing_vars) > 0) {
  stop(sprintf("Missing required variables: %s",
               paste(missing_vars, collapse = ", ")))
}

# Test 2: Database connection
message("\n2️⃣  Testing database connection...")
library(RPostgres)
tryCatch({
  con <- dbConnect(
    Postgres(),
    host = Sys.getenv("DB_HOST"),
    port = as.integer(Sys.getenv("DB_PORT")),
    dbname = Sys.getenv("DB_NAME"),
    user = Sys.getenv("DB_USER"),
    password = Sys.getenv("DB_PASSWORD")
  )

  result <- dbGetQuery(con, "SELECT 1 as test, NOW() as timestamp")
  message(sprintf("   ✅ Connected successfully at %s", result$timestamp))

  # Check if tables exist
  tables <- dbGetQuery(con, "
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
  ")
  message(sprintf("   ℹ️  Found %d tables in database", nrow(tables)))

  dbDisconnect(con)
}, error = function(e) {
  message(sprintf("   ❌ Database connection failed: %s", e$message))
  stop("Fix database configuration before continuing")
})

# Test 3: API key configuration
message("\n3️⃣  Testing API key configuration...")
source("R/ai_api_helpers.R")
config <- get_llm_config()

if (config$claude_api_key != "" && nchar(config$claude_api_key) > 20) {
  message("   ✅ Claude API key loaded")
} else {
  message("   ⚠️  Claude API key not configured")
}

if (config$openai_api_key != "" && nchar(config$openai_api_key) > 20) {
  message("   ✅ OpenAI API key loaded")
} else {
  message("   ⚠️  OpenAI API key not configured")
}

# Test 4: Database function
message("\n4️⃣  Testing database functions...")
source("R/database_config.R")
source("R/tracking_database.R")

tryCatch({
  con <- get_db_connection()

  # Test query
  stats <- get_tracking_statistics()
  message(sprintf("   ✅ Database functions working"))
  message(sprintf("      Total sessions: %d", stats$total_sessions))
  message(sprintf("      Total images: %d", stats$total_images))

  close_db_connection(con)
}, error = function(e) {
  message(sprintf("   ❌ Database function test failed: %s", e$message))
})

message("\n✅ All configuration tests passed!")
message("Ready to deploy to shinyapps.io")
```

**Run test:**

```r
source("dev/test_production_config.R")
```

---

### Deployment Command Reference

**First-time deployment:**

```r
library(rsconnect)

# Configure account (one time)
setAccountInfo(
  name   = "your-account-name",
  token  = "XXXXXXXXXX",
  secret = "XXXXXXXXXXXXXXXXX"
)

# Deploy
deployApp(
  appName = "delcampe-app",
  appTitle = "Delcampe Postal Card Processor",
  account = "your-account-name",
  forceUpdate = TRUE
)
```

**Update existing deployment:**

```r
# Quick update (same app name)
rsconnect::deployApp(forceUpdate = TRUE)

# View deployment info
rsconnect::deployments()

# View logs (streaming)
rsconnect::showLogs(streaming = TRUE)

# View metrics
rsconnect::showMetrics()
```

**Rollback to previous version:**

```r
# List deployments
rsconnect::deployments()

# Rollback (via web dashboard only)
# Go to shinyapps.io → Your App → Settings → Archive
# Then restore previous version
```

---

## Conclusion

Your Delcampe application has a solid foundation but requires critical changes before production deployment:

**Must Fix:**
1. 🔴 Remove hardcoded credentials (security vulnerability)
2. 🔴 Migrate to cloud database (SQLite won't work)
3. 🟡 Move API keys to environment variables (best practice)

**Recommended Path:**
1. **Morning:** Fix security issues (2 hours)
2. **Afternoon:** Migrate to Supabase (4 hours)
3. **Evening:** Deploy and test (1.5 hours)
4. **Result:** Production-ready application ✅

**Total Investment:** ~8 hours (1 work day)

**Long-term Benefits:**
- ✅ Secure API key management
- ✅ Persistent data storage
- ✅ Concurrent user support
- ✅ Easy database migrations
- ✅ Production-grade infrastructure

The migration effort is significant but necessary. The alternative (deploying with current SQLite setup) will result in data loss and inconsistent user experience.

---

**Questions or need help with implementation?** I'm ready to assist with:
- Writing migration scripts
- Debugging deployment issues
- Setting up Supabase
- Testing production configuration

Let me know where you'd like to start!
