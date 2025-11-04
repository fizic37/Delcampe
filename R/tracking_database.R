# File: R/tracking_database.R - EXTENDED VERSION WITH AI & EBAY TRACKING
# Extended SQLite tracking system with AI extraction and eBay posting tables

#' @importFrom RSQLite SQLite
#' @importFrom DBI dbConnect dbDisconnect dbExecute dbGetQuery
#' @importFrom jsonlite toJSON fromJSON
#' @importFrom digest digest
NULL

# Helper function for null coalescing
`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0 || all(is.na(a))) b else a
}

# ==== DATABASE INITIALIZATION ====

#' Initialize the tracking database (EXTENDED VERSION with AI & eBay tables)
#' @param db_path Path to SQLite database file
#' @return Database connection status
#' @export
#' Get database path based on environment
#'
#' Returns the appropriate database path depending on whether the app
#' is running in Docker (mounted volume at /data) or local development
#' (inst/app/data).
#'
#' @return Character string with database path
#' @export
get_db_path <- function() {
  # Check if running in Docker with mounted volume
  if (file.exists("/data")) {
    db_path <- "/data/tracking.sqlite"
    message("Using Docker volume database: ", db_path)
  } else {
    # Local development
    db_path <- get_db_path()
    message("Using local development database: ", db_path)
  }

  # Create directory if it doesn't exist
  dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)

  return(db_path)
}

initialize_tracking_db <- function(db_path = NULL) {
  if (is.null(db_path)) db_path <- get_db_path()
  tryCatch({
    dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)
    con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
    on.exit(DBI::dbDisconnect(con))
    
    DBI::dbExecute(con, "PRAGMA foreign_keys = ON")
    DBI::dbExecute(con, "PRAGMA journal_mode = WAL")
    
    # ========== EXISTING TABLES ==========
    
    # Users table
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS users (
        user_id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        email TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_login DATETIME
      )
    ")
    
    # Sessions table
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS sessions (
        session_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        session_start DATETIME DEFAULT CURRENT_TIMESTAMP,
        session_end DATETIME,
        status TEXT DEFAULT 'active',
        notes TEXT,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      )
    ")
    
    # Images table
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS images (
        image_id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        original_filename TEXT NOT NULL,
        upload_path TEXT NOT NULL,
        image_type TEXT NOT NULL,
        file_size INTEGER,
        width INTEGER,
        height INTEGER,
        file_hash TEXT,
        upload_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        processing_status TEXT DEFAULT 'uploaded',
        FOREIGN KEY (session_id) REFERENCES sessions(session_id),
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      )
    ")
    
    # Processing log table
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS processing_log (
        log_id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        user_id TEXT NOT NULL,
        details TEXT,
        success BOOLEAN DEFAULT 1,
        FOREIGN KEY (image_id) REFERENCES images(image_id),
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      )
    ")
    
    # ========== NEW 3-LAYER ARCHITECTURE TABLES ==========
    
    # Layer 1: POSTAL_CARDS - Master table (one entry per unique image hash)
    DBI::dbExecute(con, "
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
    ")
    
    # Layer 2: CARD_PROCESSING - Processing results (crops, boundaries, AI data)
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS card_processing (
        processing_id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id INTEGER UNIQUE NOT NULL,
        crop_paths TEXT,
        h_boundaries TEXT,
        v_boundaries TEXT,
        grid_rows INTEGER,
        grid_cols INTEGER,
        extraction_dir TEXT,
        ai_title TEXT,
        ai_description TEXT,
        ai_condition TEXT,
        ai_price REAL,
        ai_model TEXT,
        last_processed DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (card_id) REFERENCES postal_cards(card_id) ON DELETE CASCADE
      )
    ")
    
    # Layer 3: SESSION_ACTIVITY - Track what happened in each session
    DBI::dbExecute(con, "
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
    ")
    
    # ========== LEGACY TABLES FOR AI EXTRACTION & EBAY ==========
    
    # AI Extractions table
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS ai_extractions (
        extraction_id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_id INTEGER NOT NULL,
        model TEXT NOT NULL,
        title TEXT,
        description TEXT,
        condition TEXT,
        recommended_price REAL,
        extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        success BOOLEAN DEFAULT 1,
        error_message TEXT,
        FOREIGN KEY (image_id) REFERENCES images(image_id)
      )
    ")
    
    # eBay Posts table
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS ebay_posts (
        post_id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_id INTEGER NOT NULL,
        ebay_listing_id TEXT,
        title TEXT,
        description TEXT,
        price REAL,
        condition TEXT,
        posted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        status TEXT DEFAULT 'pending',
        error_message TEXT,
        FOREIGN KEY (image_id) REFERENCES images(image_id)
      )
    ")

    # eBay Listings table (comprehensive tracking for new 3-layer architecture)
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS ebay_listings (
        listing_id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id INTEGER,
        session_id TEXT NOT NULL,
        ebay_item_id TEXT,
        ebay_offer_id TEXT,
        ebay_user_id TEXT,
        ebay_username TEXT,
        sku TEXT UNIQUE NOT NULL,
        status TEXT DEFAULT 'draft',
        environment TEXT DEFAULT 'sandbox',
        title TEXT,
        description TEXT,
        price REAL,
        quantity INTEGER DEFAULT 1,
        condition TEXT,
        category_id TEXT DEFAULT '914',
        listing_url TEXT,
        image_urls TEXT,
        aspects TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        listed_at DATETIME,
        last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
        error_message TEXT,
        FOREIGN KEY (card_id) REFERENCES postal_cards(card_id),
        FOREIGN KEY (session_id) REFERENCES sessions(session_id)
      )
    ")

    # ========== STAMP TABLES (PARALLEL TO POSTAL CARDS) ==========

    # Layer 1: STAMPS - Master table (one entry per unique stamp image hash)
    # Check if stamps table exists and needs migration
    stamps_exists <- DBI::dbExistsTable(con, "stamps")

    if (stamps_exists) {
      # MIGRATION: Check if 'lot' is already in the constraint
      # SQLite doesn't allow ALTER TABLE to modify CHECK constraints
      # So we need to recreate the table if constraint is outdated
      tryCatch({
        # Try to insert a test 'lot' record (will fail if constraint doesn't allow it)
        test_hash <- paste0("migration_test_", as.integer(Sys.time()))
        DBI::dbExecute(con, "
          INSERT INTO stamps (file_hash, original_filename, image_type, file_size)
          VALUES (?, 'test.jpg', 'lot', 0)
        ", params = list(test_hash))
        # If successful, 'lot' is already allowed - clean up test record
        DBI::dbExecute(con, "DELETE FROM stamps WHERE file_hash = ?", params = list(test_hash))
        message("✅ Stamps table already supports 'lot' image type")
      }, error = function(e) {
        # Constraint violation - need to migrate
        message("🔄 Migrating stamps table to support 'lot' image type...")

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

        # Step 3: Copy data from old table
        DBI::dbExecute(con, "
          INSERT INTO stamps SELECT * FROM stamps_old
        ")

        # Step 4: Drop old table
        DBI::dbExecute(con, "DROP TABLE stamps_old")

        message("✅ Stamps table migration complete")
      })
    } else {
      # Create new table
      DBI::dbExecute(con, "
        CREATE TABLE IF NOT EXISTS stamps (
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
    }

    # Layer 2: STAMP_PROCESSING - Processing results with stamp-specific fields
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS stamp_processing (
        processing_id INTEGER PRIMARY KEY AUTOINCREMENT,
        stamp_id INTEGER UNIQUE NOT NULL,
        crop_paths TEXT,
        h_boundaries TEXT,
        v_boundaries TEXT,
        grid_rows INTEGER,
        grid_cols INTEGER,
        extraction_dir TEXT,
        ai_title TEXT,
        ai_description TEXT,
        ai_condition TEXT,
        ai_price REAL,
        ai_model TEXT,
        ai_country TEXT,
        ai_year INTEGER,
        ai_denomination TEXT,
        ai_scott_number TEXT,
        ai_perforation TEXT,
        ai_watermark TEXT,
        ai_grade TEXT,
        processed_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (stamp_id) REFERENCES stamps(stamp_id) ON DELETE CASCADE
      )
    ")

    # Layer 3: EBAY_STAMP_LISTINGS - eBay tracking for stamps (category 260)
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS ebay_stamp_listings (
        listing_id INTEGER PRIMARY KEY AUTOINCREMENT,
        stamp_id INTEGER,
        session_id TEXT NOT NULL,
        ebay_item_id TEXT,
        ebay_offer_id TEXT,
        ebay_user_id TEXT,
        ebay_username TEXT,
        sku TEXT UNIQUE NOT NULL,
        status TEXT DEFAULT 'draft',
        environment TEXT DEFAULT 'sandbox',
        title TEXT,
        description TEXT,
        price REAL,
        quantity INTEGER DEFAULT 1,
        condition TEXT,
        category_id TEXT DEFAULT '260',
        listing_url TEXT,
        image_urls TEXT,
        aspects TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        listed_at DATETIME,
        last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
        error_message TEXT,
        FOREIGN KEY (stamp_id) REFERENCES stamps(stamp_id),
        FOREIGN KEY (session_id) REFERENCES sessions(session_id)
      )
    ")

    # ========== SCHEMA MIGRATIONS ==========

    # Migration: Add ebay_user_id and ebay_username columns if they don't exist
    tryCatch({
      # Check if columns exist
      columns <- DBI::dbGetQuery(con, "PRAGMA table_info(ebay_listings)")

      if (!"ebay_user_id" %in% columns$name) {
        DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN ebay_user_id TEXT")
        message("✅ Added ebay_user_id column to ebay_listings table")
      }

      if (!"ebay_username" %in% columns$name) {
        DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN ebay_username TEXT")
        message("✅ Added ebay_username column to ebay_listings table")
      }
    }, error = function(e) {
      message("⚠️ Migration warning: ", e$message)
    })

    # Migration: Add eBay metadata columns to card_processing table
    tryCatch({
      # Check if columns exist
      columns <- DBI::dbGetQuery(con, "PRAGMA table_info(card_processing)")

      if (!"ai_year" %in% columns$name) {
        DBI::dbExecute(con, "ALTER TABLE card_processing ADD COLUMN ai_year TEXT")
        message("✅ Added ai_year column to card_processing table")
      }

      if (!"ai_era" %in% columns$name) {
        DBI::dbExecute(con, "ALTER TABLE card_processing ADD COLUMN ai_era TEXT")
        message("✅ Added ai_era column to card_processing table")
      }

      if (!"ai_city" %in% columns$name) {
        DBI::dbExecute(con, "ALTER TABLE card_processing ADD COLUMN ai_city TEXT")
        message("✅ Added ai_city column to card_processing table")
      }

      if (!"ai_country" %in% columns$name) {
        DBI::dbExecute(con, "ALTER TABLE card_processing ADD COLUMN ai_country TEXT")
        message("✅ Added ai_country column to card_processing table")
      }

      if (!"ai_region" %in% columns$name) {
        DBI::dbExecute(con, "ALTER TABLE card_processing ADD COLUMN ai_region TEXT")
        message("✅ Added ai_region column to card_processing table")
      }

      if (!"ai_theme_keywords" %in% columns$name) {
        DBI::dbExecute(con, "ALTER TABLE card_processing ADD COLUMN ai_theme_keywords TEXT")
        message("✅ Added ai_theme_keywords column to card_processing table")
      }
    }, error = function(e) {
      message("⚠️ Migration warning: ", e$message)
    })

    # Migration: Upgrade users table for authentication system
    tryCatch({
      # Check if users table has password_hash column (new auth system)
      columns <- DBI::dbGetQuery(con, "PRAGMA table_info(users)")

      if (!"password_hash" %in% columns$name) {
        message("🔄 Migrating users table to authentication system...")

        # Step 1: Backup old users data (if any)
        old_users_exist <- DBI::dbExistsTable(con, "users")
        if (old_users_exist) {
          old_users <- DBI::dbGetQuery(con, "SELECT * FROM users")
          DBI::dbExecute(con, "DROP TABLE users")
          message("✅ Backed up ", nrow(old_users), " legacy users")
        }

        # Step 2: Create new users table with authentication columns
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

        message("✅ Created new users table with authentication schema")

        # Step 3: Seed two master users
        # NOTE: Default passwords should be changed on first login in production!
        master1_email <- "master1@delcampe.com"
        master2_email <- "master2@delcampe.com"
        master_password <- "DelcampeMaster2025!"  # Change this in production!

        # Source the hash_password function from auth_system.R
        # We need to hash passwords - using digest directly since auth_system may not be loaded yet
        hash_password_init <- function(password) {
          digest::digest(password, algo = "sha256", serialize = FALSE)
        }

        master_hash <- hash_password_init(master_password)
        current_time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

        DBI::dbExecute(con, "
          INSERT INTO users (email, password_hash, role, is_master, created_at, active)
          VALUES (?, ?, 'master', 1, ?, 1)
        ", params = list(master1_email, master_hash, current_time))

        DBI::dbExecute(con, "
          INSERT INTO users (email, password_hash, role, is_master, created_at, active)
          VALUES (?, ?, 'master', 1, ?, 1)
        ", params = list(master2_email, master_hash, current_time))

        message("✅ Seeded 2 master users: ", master1_email, ", ", master2_email)
        message("⚠️  Default password: DelcampeMaster2025! (CHANGE IN PRODUCTION!)")
      }
    }, error = function(e) {
      message("⚠️ Users table migration warning: ", e$message)
    })

    # ========== INDEXES ==========
    
    indexes <- c(
      # Users table indexes (authentication)
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email)",
      "CREATE INDEX IF NOT EXISTS idx_users_active ON users(active)",
      "CREATE INDEX IF NOT EXISTS idx_users_role ON users(role)",
      # Existing indexes (legacy)
      "CREATE INDEX IF NOT EXISTS idx_images_session ON images(session_id)",
      "CREATE INDEX IF NOT EXISTS idx_images_user ON images(user_id)",
      "CREATE INDEX IF NOT EXISTS idx_images_status ON images(processing_status)",
      "CREATE INDEX IF NOT EXISTS idx_images_type ON images(image_type)",
      "CREATE INDEX IF NOT EXISTS idx_images_hash ON images(file_hash)",
      "CREATE INDEX IF NOT EXISTS idx_log_image ON processing_log(image_id)",
      # Legacy AI/eBay indexes
      "CREATE INDEX IF NOT EXISTS idx_ai_extractions_image ON ai_extractions(image_id)",
      "CREATE INDEX IF NOT EXISTS idx_ai_extractions_model ON ai_extractions(model)",
      "CREATE INDEX IF NOT EXISTS idx_ebay_posts_image ON ebay_posts(image_id)",
      "CREATE INDEX IF NOT EXISTS idx_ebay_posts_status ON ebay_posts(status)",
      "CREATE INDEX IF NOT EXISTS idx_ebay_posts_listing ON ebay_posts(ebay_listing_id)",
      # New 3-layer architecture indexes
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_postal_cards_hash ON postal_cards(file_hash)",
      "CREATE INDEX IF NOT EXISTS idx_postal_cards_type ON postal_cards(image_type)",
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_card_processing_card ON card_processing(card_id)",
      "CREATE INDEX IF NOT EXISTS idx_session_activity_session ON session_activity(session_id)",
      "CREATE INDEX IF NOT EXISTS idx_session_activity_card ON session_activity(card_id)",
      "CREATE INDEX IF NOT EXISTS idx_session_activity_action ON session_activity(action)",
      # eBay Listings indexes
      "CREATE INDEX IF NOT EXISTS idx_ebay_listings_card ON ebay_listings(card_id)",
      "CREATE INDEX IF NOT EXISTS idx_ebay_listings_session ON ebay_listings(session_id)",
      "CREATE INDEX IF NOT EXISTS idx_ebay_listings_status ON ebay_listings(status)",
      "CREATE INDEX IF NOT EXISTS idx_ebay_listings_sku ON ebay_listings(sku)",
      # Stamp tables indexes (parallel to postal cards)
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_stamps_hash ON stamps(file_hash)",
      "CREATE INDEX IF NOT EXISTS idx_stamps_type ON stamps(image_type)",
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_stamp_processing_stamp ON stamp_processing(stamp_id)",
      "CREATE INDEX IF NOT EXISTS idx_ebay_stamp_listings_stamp ON ebay_stamp_listings(stamp_id)",
      "CREATE INDEX IF NOT EXISTS idx_ebay_stamp_listings_session ON ebay_stamp_listings(session_id)",
      "CREATE INDEX IF NOT EXISTS idx_ebay_stamp_listings_status ON ebay_stamp_listings(status)",
      "CREATE INDEX IF NOT EXISTS idx_ebay_stamp_listings_sku ON ebay_stamp_listings(sku)"
    )
    
    for (index in indexes) {
      DBI::dbExecute(con, index)
    }
    
    message("✅ Database initialized with AI extraction & eBay tracking: ", db_path)
    return(TRUE)
    
  }, error = function(e) {
    message("❌ Failed to initialize database: ", e$message)
    return(FALSE)
  })
}

#' Get or create stamp (identical to postal card logic)
#' @param file_hash MD5 hash of the stamp image
#' @param image_type Type ('face', 'verso', or 'combined')
#' @param original_filename Original filename
#' @param file_size File size in bytes
#' @param dimensions Dimensions string (widthxheight)
#' @return stamp_id
#' @export
get_or_create_stamp <- function(file_hash, image_type, original_filename, file_size, dimensions = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))

    # Check for existing stamp (by hash only - same image file)
    existing <- DBI::dbGetQuery(con,
      "SELECT stamp_id, image_type FROM stamps WHERE file_hash = ?",
      params = list(file_hash))

    if (nrow(existing) > 0) {
      # Update last_accessed
      DBI::dbExecute(con,
        "UPDATE stamps SET last_accessed = CURRENT_TIMESTAMP WHERE stamp_id = ?",
        params = list(existing$stamp_id[1]))
      message("✅ Found existing stamp: ", existing$stamp_id[1],
              " (original type: ", existing$image_type[1], ", requested: ", image_type, ")")
      return(existing$stamp_id[1])
    }

    # Parse dimensions - FIXED: Handle NULL properly
    width <- NULL
    height <- NULL
    if (!is.null(dimensions) && is.character(dimensions) && grepl("x", dimensions)) {
      dims <- strsplit(dimensions, "x")[[1]]
      if (length(dims) == 2) {
        width <- as.integer(dims[1])
        height <- as.integer(dims[2])
      }
    }

    # Create new stamp - FIXED: Use NA instead of NULL for SQL parameters
    DBI::dbExecute(con,
      "INSERT INTO stamps (file_hash, image_type, original_filename, file_size, width, height)
       VALUES (?, ?, ?, ?, ?, ?)",
      params = list(file_hash, image_type, original_filename, file_size, 
                    if(is.null(width)) NA_integer_ else width, 
                    if(is.null(height)) NA_integer_ else height))

    new_stamp <- DBI::dbGetQuery(con,
      "SELECT stamp_id FROM stamps WHERE file_hash = ? AND image_type = ?",
      params = list(file_hash, image_type))

    message("✅ Created new stamp: ", new_stamp$stamp_id[1])
    return(new_stamp$stamp_id[1])

  }, error = function(e) {
    message("❌ Error in get_or_create_stamp: ", e$message)
    return(NULL)
  })
}

#' Save stamp processing (identical to postal card logic with stamp-specific fields)
#' @param stamp_id Stamp ID
#' @param crop_paths Vector of cropped image paths
#' @param h_boundaries Horizontal boundaries
#' @param v_boundaries Vertical boundaries
#' @param grid_rows Number of rows
#' @param grid_cols Number of columns
#' @param extraction_dir Extraction directory
#' @param ai_data List with AI extraction data
#' @return Success status
#' @export
save_stamp_processing <- function(stamp_id, crop_paths = NULL, h_boundaries = NULL, 
                                  v_boundaries = NULL, grid_rows = NULL, grid_cols = NULL, 
                                  extraction_dir = NULL, ai_data = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))

    # Convert to JSON - use NA_character_ instead of NULL for SQL compatibility
    crop_paths_json <- if (!is.null(crop_paths)) jsonlite::toJSON(crop_paths) else NA_character_
    h_boundaries_json <- if (!is.null(h_boundaries)) jsonlite::toJSON(h_boundaries) else NA_character_
    v_boundaries_json <- if (!is.null(v_boundaries)) jsonlite::toJSON(v_boundaries) else NA_character_

    # Convert grid parameters - use NA instead of NULL for SQL
    grid_rows_na <- if (!is.null(grid_rows)) grid_rows else NA_integer_
    grid_cols_na <- if (!is.null(grid_cols)) grid_cols else NA_integer_
    extraction_dir_na <- if (!is.null(extraction_dir)) extraction_dir else NA_character_

    # Check if processing exists
    existing <- DBI::dbGetQuery(con,
      "SELECT processing_id FROM stamp_processing WHERE stamp_id = ?",
      params = list(stamp_id))

    # Handle AI data - use NA_character_/NA_real_ instead of NULL for SQL
    ai_title <- if (!is.null(ai_data$title)) ai_data$title else NA_character_
    ai_description <- if (!is.null(ai_data$description)) ai_data$description else NA_character_
    ai_condition <- if (!is.null(ai_data$condition)) ai_data$condition else NA_character_
    ai_price <- if (!is.null(ai_data$price)) ai_data$price else NA_real_
    ai_model <- if (!is.null(ai_data$model)) ai_data$model else NA_character_
    ai_country <- if (!is.null(ai_data$country)) ai_data$country else NA_character_
    ai_year <- if (!is.null(ai_data$year)) ai_data$year else NA_character_
    ai_denomination <- if (!is.null(ai_data$denomination)) ai_data$denomination else NA_character_
    ai_scott_number <- if (!is.null(ai_data$scott_number)) ai_data$scott_number else NA_character_
    ai_perforation <- if (!is.null(ai_data$perforation)) ai_data$perforation else NA_character_
    ai_watermark <- if (!is.null(ai_data$watermark)) ai_data$watermark else NA_character_
    ai_grade <- if (!is.null(ai_data$grade)) ai_data$grade else NA_character_

    if (nrow(existing) > 0) {
      # Update existing (use COALESCE to keep existing values if new ones are NULL)
      DBI::dbExecute(con,
        "UPDATE stamp_processing SET
         crop_paths = COALESCE(?, crop_paths),
         h_boundaries = COALESCE(?, h_boundaries),
         v_boundaries = COALESCE(?, v_boundaries),
         grid_rows = COALESCE(?, grid_rows),
         grid_cols = COALESCE(?, grid_cols),
         extraction_dir = COALESCE(?, extraction_dir),
         ai_title = COALESCE(?, ai_title),
         ai_description = COALESCE(?, ai_description),
         ai_condition = COALESCE(?, ai_condition),
         ai_price = COALESCE(?, ai_price),
         ai_model = COALESCE(?, ai_model),
         ai_country = COALESCE(?, ai_country),
         ai_year = COALESCE(?, ai_year),
         ai_denomination = COALESCE(?, ai_denomination),
         ai_scott_number = COALESCE(?, ai_scott_number),
         ai_perforation = COALESCE(?, ai_perforation),
         ai_watermark = COALESCE(?, ai_watermark),
         ai_grade = COALESCE(?, ai_grade),
         processed_timestamp = CURRENT_TIMESTAMP
         WHERE stamp_id = ?",
        params = list(
          crop_paths_json, h_boundaries_json, v_boundaries_json,
          grid_rows_na, grid_cols_na, extraction_dir_na,
          ai_title, ai_description, ai_condition,
          ai_price, ai_model,
          ai_country, ai_year, ai_denomination,
          ai_scott_number, ai_perforation, ai_watermark,
          ai_grade, stamp_id
        ))
      message("✅ Updated stamp processing for stamp_id: ", stamp_id)
    } else {
      # Insert new
      DBI::dbExecute(con,
        "INSERT INTO stamp_processing (
         stamp_id, crop_paths, h_boundaries, v_boundaries,
         grid_rows, grid_cols, extraction_dir,
         ai_title, ai_description, ai_condition, ai_price, ai_model,
         ai_country, ai_year, ai_denomination, ai_scott_number,
         ai_perforation, ai_watermark, ai_grade
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        params = list(
          stamp_id, crop_paths_json, h_boundaries_json, v_boundaries_json,
          grid_rows_na, grid_cols_na, extraction_dir_na,
          ai_title, ai_description, ai_condition,
          ai_price, ai_model,
          ai_country, ai_year, ai_denomination,
          ai_scott_number, ai_perforation, ai_watermark,
          ai_grade
        ))
      message("✅ Created stamp processing for stamp_id: ", stamp_id)
    }

    return(TRUE)

  }, error = function(e) {
    message("❌ Error in save_stamp_processing: ", e$message)
    return(FALSE)
  })
}

#' Find stamp processing (identical to postal card logic)
#' @param file_hash File hash
#' @param image_type Image type ('face', 'verso', or 'combined')
#' @return Data frame row with stamp processing details or NULL
#' @export
find_stamp_processing <- function(file_hash, image_type) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))


    # Main query with LEFT JOIN (search by hash only, same image can have multiple types)
    result <- DBI::dbGetQuery(con,
      "SELECT s.stamp_id, s.file_hash, s.image_type, s.last_accessed,
              sp.crop_paths, sp.h_boundaries, sp.v_boundaries,
              sp.grid_rows, sp.grid_cols, sp.ai_title, sp.ai_description,
              sp.ai_price, sp.ai_condition, sp.ai_model,
              sp.ai_country, sp.ai_year, sp.ai_denomination,
              sp.ai_scott_number, sp.ai_perforation, sp.ai_watermark, sp.ai_grade,
              sp.processed_timestamp as last_processed
       FROM stamps s
       LEFT JOIN stamp_processing sp ON s.stamp_id = sp.stamp_id
       WHERE s.file_hash = ?",
      params = list(file_hash))

    if (nrow(result) == 0) {
      return(NULL)
    }

    # Parse JSON fields
    row <- result[1, ]

    # CRITICAL: If no processing record exists (LEFT JOIN returned all NAs), return NULL
    # This happens when stamp exists but hasn't been processed yet
    if (is.na(row$last_processed)) {
      return(NULL)
    }

    # Parse JSON fields into temporary variables (to avoid data frame assignment errors)
    crop_paths_parsed <- if (!is.na(row$crop_paths) && !is.null(row$crop_paths)) {
      jsonlite::fromJSON(row$crop_paths)
    } else {
      character(0)
    }

    h_boundaries_parsed <- if (!is.na(row$h_boundaries) && !is.null(row$h_boundaries)) {
      jsonlite::fromJSON(row$h_boundaries)
    } else {
      numeric(0)
    }

    v_boundaries_parsed <- if (!is.na(row$v_boundaries) && !is.null(row$v_boundaries)) {
      jsonlite::fromJSON(row$v_boundaries)
    } else {
      numeric(0)
    }

    # Return as a list with parsed JSON fields
    return(list(
      stamp_id = row$stamp_id,
      file_hash = row$file_hash,
      image_type = row$image_type,
      last_accessed = row$last_accessed,
      crop_paths = crop_paths_parsed,
      h_boundaries = h_boundaries_parsed,
      v_boundaries = v_boundaries_parsed,
      grid_rows = row$grid_rows,
      grid_cols = row$grid_cols,
      ai_title = row$ai_title,
      ai_description = row$ai_description,
      ai_price = row$ai_price,
      ai_condition = row$ai_condition,
      ai_model = row$ai_model,
      ai_country = row$ai_country,
      ai_year = row$ai_year,
      ai_denomination = row$ai_denomination,
      ai_scott_number = row$ai_scott_number,
      ai_perforation = row$ai_perforation,
      ai_watermark = row$ai_watermark,
      ai_grade = row$ai_grade,
      last_processed = row$last_processed
    ))

  }, error = function(e) {
    message("❌ ERROR in find_stamp_processing: ", e$message)
    return(NULL)
  })
}

#' Save eBay stamp listing (tracking for stamps in eBay)
#' @param stamp_id Stamp ID
#' @param session_id Session ID
#' @param ebay_item_id eBay item ID
#' @param sku SKU
#' @param title Listing title
#' @param price Listing price
#' @param status Listing status
#' @param listing_url Listing URL
#' @param ebay_offer_id eBay offer ID (optional)
#' @param ebay_user_id eBay user ID (optional)
#' @param ebay_username eBay username (optional)
#' @return listing_id
#' @export
save_ebay_stamp_listing <- function(stamp_id, session_id, ebay_item_id, sku, title, price, 
                                    status = "listed", listing_url = NULL, ebay_offer_id = NULL,
                                    ebay_user_id = NULL, ebay_username = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))

    DBI::dbExecute(con,
      "INSERT INTO ebay_stamp_listings (
        stamp_id, session_id, ebay_item_id, ebay_offer_id, ebay_user_id, ebay_username,
        sku, status, title, price, listing_url, listed_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)",
      params = list(stamp_id, session_id, ebay_item_id, ebay_offer_id, ebay_user_id, 
                    ebay_username, sku, status, title, price, listing_url))

    listing_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id

    message("✅ Saved eBay stamp listing: ", listing_id)
    return(listing_id)

  }, error = function(e) {
    message("❌ Error in save_ebay_stamp_listing: ", e$message)
    return(NULL)
  })
}

#' Track stamp session activity
#' @param session_id Session ID
#' @param stamp_id Stamp ID
#' @param action Action performed
#' @param details Additional details (optional)
#' @return Success status
#' @export
track_stamp_activity <- function(session_id, stamp_id, action, details = NULL) {
  # For now, just log to console since we don't have a stamp_activity table yet
  # This prevents crashes while maintaining compatibility
  tryCatch({
    message("📊 Stamp Activity: ", action, " (stamp_id: ", stamp_id, ")")
    return(TRUE)
  }, error = function(e) {
    message("⚠️ Error in track_stamp_activity: ", e$message)
    return(FALSE)
  })
}

message("✅ Stamp tracking functions loaded!")

# ==== NEW 3-LAYER ARCHITECTURE FUNCTIONS ====

#' Get or create postal card entry
#' @param file_hash MD5 hash of the image
#' @param image_type Type of image ('face' or 'verso')
#' @param original_filename Original filename
#' @param file_size File size in bytes
#' @param dimensions List with width and height (optional)
#' @return card_id
#' @export
get_or_create_card <- function(file_hash, image_type, original_filename, 
                               file_size = NULL, dimensions = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    
    # Check if card already exists
    existing <- DBI::dbGetQuery(con, "
      SELECT card_id, times_uploaded 
      FROM postal_cards 
      WHERE file_hash = ? AND image_type = ?
    ", list(as.character(file_hash), as.character(image_type)))
    
    if (nrow(existing) > 0) {
      # Card exists - update times_uploaded and last_updated
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
      # New card - insert
      width_val <- if (!is.null(dimensions) && !is.null(dimensions$width)) as.integer(dimensions$width) else NA_integer_
      height_val <- if (!is.null(dimensions) && !is.null(dimensions$height)) as.integer(dimensions$height) else NA_integer_
      size_val <- if (!is.null(file_size)) as.integer(file_size) else NA_integer_
      
      DBI::dbExecute(con, "
        INSERT INTO postal_cards (
          file_hash, original_filename, image_type, 
          file_size, width, height
        ) VALUES (?, ?, ?, ?, ?, ?)
      ", list(
        as.character(file_hash),
        as.character(original_filename),
        as.character(image_type),
        size_val,
        width_val,
        height_val
      ))
      
      card_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id
      message("New card created: card_id = ", card_id)
      return(card_id)
    }
    
  }, error = function(e) {
    message("Error in get_or_create_card: ", e$message)
    return(NULL)
  })
}

#' Save or update card processing results
#' @param card_id Card ID from postal_cards table
#' @param crop_paths Vector of absolute crop file paths
#' @param h_boundaries Horizontal boundaries
#' @param v_boundaries Vertical boundaries
#' @param grid_rows Number of grid rows
#' @param grid_cols Number of grid columns
#' @param extraction_dir Directory where crops were saved
#' @param ai_data Optional list with AI extraction results
#' @return Success status
#' @export
save_card_processing <- function(card_id, crop_paths, h_boundaries, v_boundaries,
                                grid_rows, grid_cols, extraction_dir, 
                                ai_data = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    
    # Convert to JSON - ensure single character strings for SQL parameters
    # Handle NULL values properly - convert to NA_character_ for database (scalar values)
    crop_paths_json <- if (!is.null(crop_paths)) as.character(jsonlite::toJSON(crop_paths, auto_unbox = FALSE))[1] else NA_character_
    h_bound_json <- if (!is.null(h_boundaries)) as.character(jsonlite::toJSON(h_boundaries, auto_unbox = FALSE))[1] else NA_character_
    v_bound_json <- if (!is.null(v_boundaries)) as.character(jsonlite::toJSON(v_boundaries, auto_unbox = FALSE))[1] else NA_character_
    
    # Check if processing record exists
    existing <- DBI::dbGetQuery(con, "
      SELECT processing_id FROM card_processing WHERE card_id = ?
    ", list(as.integer(card_id)))
    
    if (nrow(existing) > 0) {
      # UPDATE existing processing - only update non-NULL fields
      update_fields <- c()
      params <- list()

      if (!is.null(crop_paths_json)) {
        update_fields <- c(update_fields, "crop_paths = ?")
        params <- c(params, list(crop_paths_json))
      }
      if (!is.null(h_bound_json)) {
        update_fields <- c(update_fields, "h_boundaries = ?")
        params <- c(params, list(h_bound_json))
      }
      if (!is.null(v_bound_json)) {
        update_fields <- c(update_fields, "v_boundaries = ?")
        params <- c(params, list(v_bound_json))
      }
      if (!is.null(grid_rows)) {
        update_fields <- c(update_fields, "grid_rows = ?")
        params <- c(params, list(as.integer(grid_rows)[1]))
      }
      if (!is.null(grid_cols)) {
        update_fields <- c(update_fields, "grid_cols = ?")
        params <- c(params, list(as.integer(grid_cols)[1]))
      }
      if (!is.null(extraction_dir)) {
        update_fields <- c(update_fields, "extraction_dir = ?")
        params <- c(params, list(as.character(extraction_dir)[1]))
      }

      # Add AI data if provided
      if (!is.null(ai_data)) {
        if (!is.null(ai_data$title)) {
          update_fields <- c(update_fields, "ai_title = ?")
          params <- c(params, list(ai_data$title))
        }
        if (!is.null(ai_data$description)) {
          update_fields <- c(update_fields, "ai_description = ?")
          params <- c(params, list(ai_data$description))
        }
        if (!is.null(ai_data$condition)) {
          update_fields <- c(update_fields, "ai_condition = ?")
          params <- c(params, list(ai_data$condition))
        }
        if (!is.null(ai_data$price)) {
          update_fields <- c(update_fields, "ai_price = ?")
          params <- c(params, list(ai_data$price))
        }
        if (!is.null(ai_data$model)) {
          update_fields <- c(update_fields, "ai_model = ?")
          params <- c(params, list(ai_data$model))
        }
        # Add eBay metadata fields
        if (!is.null(ai_data$year)) {
          update_fields <- c(update_fields, "ai_year = ?")
          params <- c(params, list(ai_data$year))
        }
        if (!is.null(ai_data$era)) {
          update_fields <- c(update_fields, "ai_era = ?")
          params <- c(params, list(ai_data$era))
        }
        if (!is.null(ai_data$city)) {
          update_fields <- c(update_fields, "ai_city = ?")
          params <- c(params, list(ai_data$city))
        }
        if (!is.null(ai_data$country)) {
          update_fields <- c(update_fields, "ai_country = ?")
          params <- c(params, list(ai_data$country))
        }
        if (!is.null(ai_data$region)) {
          update_fields <- c(update_fields, "ai_region = ?")
          params <- c(params, list(ai_data$region))
        }
        if (!is.null(ai_data$theme_keywords)) {
          update_fields <- c(update_fields, "ai_theme_keywords = ?")
          params <- c(params, list(ai_data$theme_keywords))
        }
      }

      # Always update last_processed
      update_fields <- c(update_fields, "last_processed = CURRENT_TIMESTAMP")

      # Build query
      if (length(update_fields) > 0) {
        query <- paste0("UPDATE card_processing SET ", paste(update_fields, collapse = ", "), " WHERE card_id = ?")
        params <- c(params, list(as.integer(card_id)))

        DBI::dbExecute(con, query, params)
        message("Updated processing for card_id: ", card_id)
      } else {
        message("No fields to update for card_id: ", card_id)
      }
    } else {
      # INSERT new processing
      DBI::dbExecute(con, "
        INSERT INTO card_processing (
          card_id, crop_paths, h_boundaries, v_boundaries,
          grid_rows, grid_cols, extraction_dir,
          ai_title, ai_description, ai_condition, ai_price, ai_model,
          ai_year, ai_era, ai_city, ai_country, ai_region, ai_theme_keywords
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ", list(
        as.integer(card_id),
        crop_paths_json,
        h_bound_json,
        v_bound_json,
        if (!is.null(grid_rows)) as.integer(grid_rows) else NA_integer_,
        if (!is.null(grid_cols)) as.integer(grid_cols) else NA_integer_,
        if (!is.null(extraction_dir)) as.character(extraction_dir) else NA_character_,
        if (!is.null(ai_data) && !is.null(ai_data$title)) ai_data$title else NA_character_,
        if (!is.null(ai_data) && !is.null(ai_data$description)) ai_data$description else NA_character_,
        if (!is.null(ai_data) && !is.null(ai_data$condition)) ai_data$condition else NA_character_,
        if (!is.null(ai_data) && !is.null(ai_data$price)) as.numeric(ai_data$price) else NA_real_,
        if (!is.null(ai_data) && !is.null(ai_data$model)) ai_data$model else NA_character_,
        if (!is.null(ai_data) && !is.null(ai_data$year)) ai_data$year else NA_character_,
        if (!is.null(ai_data) && !is.null(ai_data$era)) ai_data$era else NA_character_,
        if (!is.null(ai_data) && !is.null(ai_data$city)) ai_data$city else NA_character_,
        if (!is.null(ai_data) && !is.null(ai_data$country)) ai_data$country else NA_character_,
        if (!is.null(ai_data) && !is.null(ai_data$region)) ai_data$region else NA_character_,
        if (!is.null(ai_data) && !is.null(ai_data$theme_keywords)) ai_data$theme_keywords else NA_character_
      ))
      message("Created processing for card_id: ", card_id)
    }
    
    return(TRUE)
    
  }, error = function(e) {
    message("Error in save_card_processing: ", e$message)
    return(FALSE)
  })
}

#' Track session activity
#' @param session_id Session identifier
#' @param card_id Card ID
#' @param action Action performed ('uploaded', 'processed', 'reused', etc.)
#' @param details Optional JSON details
#' @return Success status
#' @export
track_session_activity <- function(session_id, card_id, action, details = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    
    details_json <- if (!is.null(details)) {
      jsonlite::toJSON(details, auto_unbox = TRUE)
    } else {
      NULL
    }
    
    DBI::dbExecute(con, "
      INSERT INTO session_activity (session_id, card_id, action, details)
      VALUES (?, ?, ?, ?)
    ", list(
      as.character(session_id),
      as.integer(card_id),
      as.character(action),
      as.character(details_json)
    ))
    
    return(TRUE)
    
  }, error = function(e) {
    message("Error in track_session_activity: ", e$message)
    return(FALSE)
  })
}

#' Find existing card processing by hash
#' @param file_hash MD5 hash of the image
#' @param image_type Type of image ('face' or 'verso')
#' @return List with card data and processing, or NULL if not found
#' @export
find_card_processing <- function(file_hash, image_type) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    result <- DBI::dbGetQuery(con, "
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
        p.ai_model,
        p.ai_year,
        p.ai_era,
        p.ai_city,
        p.ai_country,
        p.ai_region,
        p.ai_theme_keywords,
        p.last_processed
      FROM postal_cards c
      LEFT JOIN card_processing p ON c.card_id = p.card_id
      WHERE c.file_hash = ? AND c.image_type = ?
    ", list(as.character(file_hash), as.character(image_type)))
    
    if (nrow(result) == 0 || is.na(result$last_processed)) {
      return(NULL)  # No processed card found
    }
    
    # Parse JSON fields
    crop_paths <- tryCatch(jsonlite::fromJSON(result$crop_paths), error = function(e) NULL)
    h_boundaries <- tryCatch(jsonlite::fromJSON(result$h_boundaries), error = function(e) NULL)
    v_boundaries <- tryCatch(jsonlite::fromJSON(result$v_boundaries), error = function(e) NULL)
    
    return(list(
      card_id = result$card_id,
      file_hash = result$file_hash,
      image_type = result$image_type,
      first_seen = result$first_seen,
      last_updated = result$last_updated,
      last_processed = result$last_processed,
      crop_paths = crop_paths,
      h_boundaries = h_boundaries,
      v_boundaries = v_boundaries,
      grid_rows = result$grid_rows,
      grid_cols = result$grid_cols,
      extraction_dir = result$extraction_dir,
      ai_title = result$ai_title,
      ai_description = result$ai_description,
      ai_condition = result$ai_condition,
      ai_price = result$ai_price,
      ai_model = result$ai_model,
      ai_year = result$ai_year,
      ai_era = result$ai_era,
      ai_city = result$ai_city,
      ai_country = result$ai_country,
      ai_region = result$ai_region,
      ai_theme_keywords = result$ai_theme_keywords
    ))
    
  }, error = function(e) {
    message("Error in find_card_processing: ", e$message)
    return(NULL)
  })
}

# ==== LEGACY FUNCTIONS (UNCHANGED) ====

#' Calculate MD5 hash of an image file for deduplication
#' @param image_path Path to the image file
#' @return Character string with MD5 hash, or NULL if error
#' @export
calculate_image_hash <- function(image_path) {
  tryCatch({
    if (!file.exists(image_path)) {
      warning("Image file does not exist: ", image_path)
      return(NULL)
    }
    
    # Simple MD5 file hash (fast and sufficient for deduplication)
    file_hash <- digest::digest(file = image_path, algo = "md5")
    return(file_hash)
    
  }, error = function(e) {
    warning("Could not calculate image hash for: ", image_path, " - ", e$message)
    return(NULL)
  })
}

track_image_upload <- function(session_id, user_id, original_filename, 
                              upload_path, content_category, image_type, 
                              file_size = NULL, dimensions = NULL) {
  
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    # Clean parameters
    session_id_clean <- as.character(session_id)[1]
    user_id_clean <- as.character(user_id)[1]
    filename_clean <- as.character(original_filename)[1]
    path_clean <- as.character(upload_path)[1]
    type_clean <- as.character(image_type)[1]
    
    # Ensure valid values
    if (is.na(session_id_clean) || session_id_clean == "") session_id_clean <- "unknown_session"
    if (is.na(user_id_clean) || user_id_clean == "") user_id_clean <- "unknown_user"
    if (is.na(filename_clean) || filename_clean == "") filename_clean <- "unknown.jpg"
    if (is.na(path_clean) || path_clean == "") path_clean <- "data/unknown.jpg"
    if (is.na(type_clean) || type_clean == "") type_clean <- "unknown"
    
    # Calculate hash
    file_hash <- NULL
    full_path <- file.path("inst/app", path_clean)
    if (file.exists(full_path)) {
      tryCatch({
        file_hash <- digest::digest(file = full_path, algo = "md5")
      }, error = function(e) {
        file_hash <- NULL
      })
    }
    
    # Handle dimensions
    width_val <- NULL
    height_val <- NULL
    if (!is.null(dimensions) && is.list(dimensions)) {
      if (!is.null(dimensions$width) && !is.na(dimensions$width)) {
        width_val <- as.integer(dimensions$width)[1]
      }
      if (!is.null(dimensions$height) && !is.na(dimensions$height)) {
        height_val <- as.integer(dimensions$height)[1]
      }
    }
    
    # Handle file size
    size_val <- NULL
    if (!is.null(file_size) && !is.na(file_size)) {
      size_val <- as.integer(file_size)[1]
    }
    
    # Insert
    DBI::dbExecute(con, "
      INSERT INTO images (
        session_id, user_id, original_filename, upload_path, 
        image_type, file_size, width, height, file_hash
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ", list(
      session_id_clean,
      user_id_clean,
      filename_clean,
      path_clean,
      type_clean,
      size_val,
      width_val,
      height_val,
      file_hash
    ))
    
    image_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id
    
    # Log action
    DBI::dbExecute(con, "
      INSERT INTO processing_log (image_id, action, user_id)
      VALUES (?, ?, ?)
    ", list(image_id, "uploaded", user_id_clean))
    
    message("✅ Image tracked successfully with ID: ", image_id)
    return(image_id)
    
  }, error = function(e) {
    message("❌ Error in track_image_upload: ", e$message)
    stop("Database insert failed: ", e$message)
  })
}

#' Save uploaded image
#' @param file_info File info from fileInput
#' @param user_id User identifier
#' @param session_id Session identifier  
#' @param content_category Content category
#' @param image_type Type ('face', 'verso')
#' @return List with image_id and file_path
#' @export
save_uploaded_image <- function(file_info, user_id, session_id, content_category, image_type) {
  
  tryCatch({
    if (is.null(file_info) || !is.list(file_info) || is.null(file_info$name) || is.null(file_info$datapath)) {
      return(list(success = FALSE, error = "Invalid file_info"))
    }
    
    if (!file.exists(file_info$datapath)) {
      return(list(success = FALSE, error = "Source file does not exist"))
    }
    
    # Generate filename
    timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
    clean_filename <- gsub("[^a-zA-Z0-9._-]", "_", file_info$name)
    unique_filename <- paste0(timestamp, "_", clean_filename)
    
    folder_name <- paste("uploads", content_category, image_type, sep = "-")
    relative_path <- file.path("data", folder_name, unique_filename)
    full_path <- file.path("inst/app", relative_path)
    
    # Create directory and copy
    dir.create(dirname(full_path), recursive = TRUE, showWarnings = FALSE)
    copy_success <- file.copy(file_info$datapath, full_path, overwrite = TRUE)
    
    if (!copy_success || !file.exists(full_path) || file.size(full_path) == 0) {
      return(list(success = FALSE, error = "Failed to copy file"))
    }
    
    file_size <- file.info(full_path)$size
    
    # Get dimensions
    dimensions <- NULL
    if (requireNamespace("magick", quietly = TRUE)) {
      tryCatch({
        img <- magick::image_read(full_path)
        info <- magick::image_info(img)
        dimensions <- list(
          width = as.integer(info$width),
          height = as.integer(info$height)
        )
      }, error = function(e) {
        dimensions <- NULL
      })
    }
    
    # Track in database
    image_id <- track_image_upload(
      session_id = session_id,
      user_id = user_id,
      original_filename = file_info$name,
      upload_path = relative_path,
      content_category = content_category,
      image_type = image_type,
      file_size = file_size,
      dimensions = dimensions
    )
    
    return(list(
      image_id = image_id,
      file_path = relative_path,
      full_path = full_path,
      web_path = sub("^inst/app/", "", relative_path),
      success = TRUE,
      file_size = file_size
    ))
    
  }, error = function(e) {
    message("❌ Error in save_uploaded_image: ", e$message)
    return(list(success = FALSE, error = e$message))
  })
}

#' Start processing session
#' @param session_id Session identifier
#' @param user_id User identifier
#' @param session_type Type of session
#' @return Session ID
#' @export
start_processing_session <- function(session_id, user_id, session_type = "general") {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    DBI::dbExecute(con, "
      INSERT OR IGNORE INTO users (user_id, username) 
      VALUES (?, ?)
    ", list(as.character(user_id), paste0("user_", user_id)))
    
    DBI::dbExecute(con, "
      INSERT OR REPLACE INTO sessions (session_id, user_id) 
      VALUES (?, ?)
    ", list(as.character(session_id), as.character(user_id)))
    
    message("✅ Session started: ", session_id)
    return(session_id)
    
  }, error = function(e) {
    message("❌ Error starting session: ", e$message)
    return(session_id)
  })
}

#' Ensure user exists
#' @param user_id User identifier
#' @param username Username
#' @param email User email
#' @param role User role
#' @return User ID
#' @export
ensure_user_exists <- function(user_id, username, email = NULL, role = "user") {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    DBI::dbExecute(con, "
      INSERT OR IGNORE INTO users (user_id, username, email) 
      VALUES (?, ?, ?)
    ", list(as.character(user_id), as.character(username), email))
    
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

#' Query sessions
#' @param user_id Optional user filter
#' @param limit Limit results
#' @param start_date Start date filter
#' @param end_date End date filter
#' @param session_type Session type filter
#' @return Data frame with sessions
#' @export
query_sessions <- function(user_id = NULL, limit = 100, start_date = NULL, end_date = NULL, session_type = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    query <- "
      SELECT
        s.session_id,
        s.user_id,
        s.session_start,
        s.session_end,
        s.status,
        s.notes,
        u.email as username,
        u.email,
        COUNT(i.image_id) as image_count
      FROM sessions s
      LEFT JOIN users u ON s.user_id = u.user_id
      LEFT JOIN images i ON s.session_id = i.session_id
    "
    
    where_conditions <- c()
    params <- list()
    
    if (!is.null(user_id)) {
      where_conditions <- c(where_conditions, "s.user_id = ?")
      params <- append(params, user_id)
    }
    
    if (length(where_conditions) > 0) {
      query <- paste(query, "WHERE", paste(where_conditions, collapse = " AND "))
    }
    
    query <- paste(query,
                   "GROUP BY s.session_id, s.user_id, s.session_start, s.session_end, s.status, s.notes, u.email",
                   "ORDER BY s.session_start DESC LIMIT", limit)
    
    if (length(params) > 0) {
      result <- DBI::dbGetQuery(con, query, params)
    } else {
      result <- DBI::dbGetQuery(con, query)
    }
    
    return(result)
    
  }, error = function(e) {
    message("❌ Error in query_sessions: ", e$message)
    return(data.frame())
  })
}

#' Track processing action
#' @param image_id Image ID
#' @param action Action performed
#' @param user_id User performing action
#' @param details Additional details
#' @param success Whether action succeeded
#' @param error_message Error message if failed
#' @return Success status
#' @export
track_processing_action <- function(image_id, action, user_id, 
                                   details = NULL, success = TRUE,
                                   error_message = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    details_json <- NULL
    if (!is.null(details) || !is.null(error_message)) {
      combined_details <- if (!is.null(details)) details else list()
      if (!is.null(error_message)) {
        combined_details$error <- error_message
      }
      details_json <- jsonlite::toJSON(combined_details, auto_unbox = TRUE)
    }
    
    DBI::dbExecute(con, "
      INSERT INTO processing_log (image_id, action, user_id, details, success)
      VALUES (?, ?, ?, ?, ?)
    ", list(as.integer(image_id), as.character(action), as.character(user_id), 
             details_json, as.logical(success)))
    
    return(TRUE)
    
  }, error = function(e) {
    message("❌ Error in track_processing_action: ", e$message)
    return(FALSE)
  })
}

#' Track extraction completion
#' @param session_id Session identifier
#' @param image_type Type of image processed
#' @param extraction_dir Directory where crops were saved
#' @param cropped_paths Vector of cropped image paths
#' @param grid_config Grid configuration used
#' @param h_boundaries Horizontal boundaries
#' @param v_boundaries Vertical boundaries
#' @export
track_extraction <- function(session_id, image_type, extraction_dir, cropped_paths, 
                           grid_config = NULL, h_boundaries = NULL, v_boundaries = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    image_record <- DBI::dbGetQuery(con, "
      SELECT image_id, user_id FROM images 
      WHERE session_id = ? AND image_type LIKE ?
      ORDER BY upload_timestamp DESC
      LIMIT 1
    ", list(session_id, paste0("%", image_type, "%")))
    
    if (nrow(image_record) == 0) {
      warning("No image found for extraction tracking")
      return(FALSE)
    }
    
    image_id <- image_record$image_id[1]
    user_id <- image_record$user_id[1]
    
    DBI::dbExecute(con, "
      UPDATE images 
      SET processing_status = 'processed',
          processing_timestamp = CURRENT_TIMESTAMP
      WHERE image_id = ?
    ", list(image_id))
    
    extraction_details <- list(
      extraction_dir = extraction_dir,
      cropped_paths = cropped_paths,
      crop_count = length(cropped_paths),
      grid_config = grid_config,
      h_boundaries = h_boundaries,
      v_boundaries = v_boundaries
    )
    
    track_processing_action(
      image_id = image_id,
      action = "extraction_complete",
      user_id = user_id,
      details = extraction_details,
      success = TRUE
    )
    
    message("✅ Extraction tracked successfully for image_id: ", image_id)
    return(TRUE)
    
  }, error = function(e) {
    message("❌ Error tracking extraction: ", e$message)
    return(FALSE)
  })
}

#' Get tracking statistics
#' @return List with tracking statistics
#' @export
get_tracking_statistics <- function() {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    total_images <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM images")$count %||% 0
    total_sessions <- DBI::dbGetQuery(con, "SELECT COUNT(DISTINCT session_id) as count FROM images")$count %||% 0
    processed_images <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM images WHERE processing_status = 'processed'")$count %||% 0
    recent_activity <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM images WHERE upload_timestamp > datetime('now', '-24 hours')")$count %||% 0
    
    return(list(
      total_sessions = total_sessions,
      total_images = total_images,
      processed_images = processed_images,
      recent_activity = recent_activity,
      last_updated = Sys.time(),
      system_status = "active"
    ))
    
  }, error = function(e) {
    warning("Error getting tracking statistics: ", e$message)
    return(list(
      total_sessions = 0,
      total_images = 0,
      processed_images = 0,
      recent_activity = 0,
      last_updated = Sys.time(),
      system_status = "error",
      error = e$message
    ))
  })
}

# ==== NEW FUNCTIONS FOR AI EXTRACTION & EBAY TRACKING ====

#' Track AI extraction attempt
#' @param image_id Image ID from database
#' @param model Model used ('claude-sonnet-4-5-20250929' or 'gpt-4o')
#' @param title Extracted title
#' @param description Extracted description
#' @param condition Extracted condition
#' @param recommended_price Recommended price in US Dollars (USD)
#' @param success Whether extraction succeeded
#' @param error_message Error message if failed
#' @return Extraction ID
#' @export
track_ai_extraction <- function(image_id, model, title = NULL, description = NULL,
                               condition = NULL, recommended_price = NULL,
                               success = TRUE, error_message = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    # Clean parameters
    image_id_clean <- as.integer(image_id)[1]
    model_clean <- as.character(model)[1]
    success_clean <- as.logical(success)[1]
    
    # Handle NULL values appropriately
    title_clean <- if (!is.null(title)) as.character(title)[1] else NULL
    description_clean <- if (!is.null(description)) as.character(description)[1] else NULL
    condition_clean <- if (!is.null(condition)) as.character(condition)[1] else NULL
    price_clean <- if (!is.null(recommended_price)) as.numeric(recommended_price)[1] else NULL
    error_clean <- if (!is.null(error_message)) as.character(error_message)[1] else NULL
    
    # Insert extraction record
    DBI::dbExecute(con, "
      INSERT INTO ai_extractions (
        image_id, model, title, description, condition, 
        recommended_price, success, error_message
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ", list(
      image_id_clean,
      model_clean,
      title_clean,
      description_clean,
      condition_clean,
      price_clean,
      success_clean,
      error_clean
    ))
    
    # Get the inserted ID
    extraction_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id
    
    message("✅ AI extraction tracked successfully with ID: ", extraction_id)
    return(extraction_id)
    
  }, error = function(e) {
    message("❌ Error in track_ai_extraction: ", e$message)
    return(NULL)
  })
}

#' Track eBay posting attempt
#' @param image_id Image ID from database
#' @param title Posted title
#' @param description Posted description
#' @param price Posted price
#' @param condition Posted condition
#' @param ebay_listing_id eBay's listing ID (if successful)
#' @param status 'success', 'failed', or 'pending'
#' @param error_message Error message if failed
#' @return Post ID
#' @export
track_ebay_post <- function(image_id, title, description, price, condition,
                           ebay_listing_id = NULL, status = 'pending',
                           error_message = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    # Clean parameters
    image_id_clean <- as.integer(image_id)[1]
    title_clean <- as.character(title)[1]
    description_clean <- as.character(description)[1]
    price_clean <- as.numeric(price)[1]
    condition_clean <- as.character(condition)[1]
    status_clean <- as.character(status)[1]
    
    listing_id_clean <- if (!is.null(ebay_listing_id)) as.character(ebay_listing_id)[1] else NULL
    error_clean <- if (!is.null(error_message)) as.character(error_message)[1] else NULL
    
    # Insert post record
    DBI::dbExecute(con, "
      INSERT INTO ebay_posts (
        image_id, title, description, price, condition,
        ebay_listing_id, status, error_message
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ", list(
      image_id_clean,
      title_clean,
      description_clean,
      price_clean,
      condition_clean,
      listing_id_clean,
      status_clean,
      error_clean
    ))
    
    # Get the inserted ID
    post_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id
    
    message("✅ eBay post tracked successfully with ID: ", post_id)
    return(post_id)
    
  }, error = function(e) {
    message("❌ Error in track_ebay_post: ", e$message)
    return(NULL)
  })
}

#' Get image ID from file path
#' @param file_path File path or web path
#' @param session_id Current session ID (optional filter)
#' @return Image ID or NULL
#' @export
get_image_by_path <- function(file_path, session_id = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    # Clean the file path - extract just the filename
    clean_path <- basename(file_path)
    
    # Build query
    if (!is.null(session_id)) {
      result <- DBI::dbGetQuery(con, "
        SELECT image_id FROM images 
        WHERE (upload_path LIKE ? OR original_filename LIKE ?)
          AND session_id = ?
        ORDER BY upload_timestamp DESC
        LIMIT 1
      ", list(paste0("%", clean_path, "%"), paste0("%", clean_path, "%"), as.character(session_id)))
    } else {
      result <- DBI::dbGetQuery(con, "
        SELECT image_id FROM images 
        WHERE upload_path LIKE ? OR original_filename LIKE ?
        ORDER BY upload_timestamp DESC
        LIMIT 1
      ", list(paste0("%", clean_path, "%"), paste0("%", clean_path, "%")))
    }
    
    if (nrow(result) > 0) {
      return(result$image_id[1])
    } else {
      message("⚠️ No image found for path: ", file_path)
      return(NULL)
    }
    
  }, error = function(e) {
    message("❌ Error in get_image_by_path: ", e$message)
    return(NULL)
  })
}

#' Get AI extraction history for an image
#' @param image_id Image ID
#' @return Data frame with extraction history
#' @export
get_ai_extraction_history <- function(image_id) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    result <- DBI::dbGetQuery(con, "
      SELECT 
        extraction_id,
        model,
        title,
        description,
        condition,
        recommended_price,
        extracted_at,
        success,
        error_message
      FROM ai_extractions
      WHERE image_id = ?
      ORDER BY extracted_at DESC
    ", list(as.integer(image_id)))
    
    return(result)
    
  }, error = function(e) {
    message("❌ Error in get_ai_extraction_history: ", e$message)
    return(data.frame())
  })
}

#' Get statistics on eBay postings
#' @param session_id Optional session filter
#' @return List with statistics
#' @export
get_posting_statistics <- function(session_id = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    if (!is.null(session_id)) {
      # Filter by session
      total_posts <- DBI::dbGetQuery(con, "
        SELECT COUNT(*) as count FROM ebay_posts ep
        JOIN images i ON ep.image_id = i.image_id
        WHERE i.session_id = ?
      ", list(as.character(session_id)))$count %||% 0
      
      successful_posts <- DBI::dbGetQuery(con, "
        SELECT COUNT(*) as count FROM ebay_posts ep
        JOIN images i ON ep.image_id = i.image_id
        WHERE ep.status = 'success' AND i.session_id = ?
      ", list(as.character(session_id)))$count %||% 0
      
      failed_posts <- DBI::dbGetQuery(con, "
        SELECT COUNT(*) as count FROM ebay_posts ep
        JOIN images i ON ep.image_id = i.image_id
        WHERE ep.status = 'failed' AND i.session_id = ?
      ", list(as.character(session_id)))$count %||% 0
      
      pending_posts <- DBI::dbGetQuery(con, "
        SELECT COUNT(*) as count FROM ebay_posts ep
        JOIN images i ON ep.image_id = i.image_id
        WHERE ep.status = 'pending' AND i.session_id = ?
      ", list(as.character(session_id)))$count %||% 0
      
    } else {
      # All posts
      total_posts <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM ebay_posts")$count %||% 0
      successful_posts <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM ebay_posts WHERE status = 'success'")$count %||% 0
      failed_posts <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM ebay_posts WHERE status = 'failed'")$count %||% 0
      pending_posts <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM ebay_posts WHERE status = 'pending'")$count %||% 0
    }
    
    # Get AI extraction statistics
    total_extractions <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM ai_extractions")$count %||% 0
    successful_extractions <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM ai_extractions WHERE success = 1")$count %||% 0
    
    return(list(
      ebay_posts = list(
        total = total_posts,
        successful = successful_posts,
        failed = failed_posts,
        pending = pending_posts
      ),
      ai_extractions = list(
        total = total_extractions,
        successful = successful_extractions,
        failed = total_extractions - successful_extractions
      ),
      last_updated = Sys.time()
    ))
    
  }, error = function(e) {
    message("❌ Error in get_posting_statistics: ", e$message)
    return(list(
      ebay_posts = list(total = 0, successful = 0, failed = 0, pending = 0),
      ai_extractions = list(total = 0, successful = 0, failed = 0),
      last_updated = Sys.time(),
      error = e$message
    ))
  })
}

# ==== IMAGE DEDUPLICATION FUNCTIONS ====

#' Find existing processing for an image by hash
#' @param image_hash MD5 hash of the image
#' @param image_type Type of image ('face' or 'verso', optional)
#' @return List with existing processing details or NULL
#' @export
find_existing_processing <- function(image_hash, image_type = NULL, exclude_image_id = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    # Build query
    query <- "
      SELECT 
        i.image_id,
        i.session_id,
        i.upload_path,
        i.image_type,
        i.upload_timestamp,
        p.details,
        p.timestamp as processed_at
      FROM images i
      LEFT JOIN processing_log p 
        ON i.image_id = p.image_id 
        AND p.action = 'extraction_complete'
      WHERE i.file_hash = ?
    "
    
    params <- list(as.character(image_hash))
    
    # Add image type filter if provided
    if (!is.null(image_type)) {
      query <- paste(query, "AND i.image_type = ?")
      params <- list(as.character(image_hash), as.character(image_type))
    }
    
    # Exclude current image to avoid finding itself
    if (!is.null(exclude_image_id)) {
      query <- paste(query, "AND i.image_id != ?")
      params <- c(params, list(as.integer(exclude_image_id)))
    }
    
    query <- paste(query, "ORDER BY i.upload_timestamp DESC LIMIT 1")
    
    result <- DBI::dbGetQuery(con, query, params)
    
    if (nrow(result) == 0 || is.na(result$processed_at)) {
      return(NULL)  # No previous processing found
    }
    
    # Parse JSON from details column
    details <- tryCatch({
      jsonlite::fromJSON(result$details)
    }, error = function(e) {
      return(list())
    })
    
    return(list(
      image_id = result$image_id,
      session_id = result$session_id,
      source_path = result$upload_path,
      image_type = result$image_type,
      uploaded_at = result$upload_timestamp,
      processed_at = result$processed_at,
      h_boundaries = details$h_boundaries,
      v_boundaries = details$v_boundaries,
      cropped_paths = details$cropped_paths,
      grid_config = details$grid_config,
      extraction_dir = details$extraction_dir
    ))
    
  }, error = function(e) {
    message("❌ Error finding existing processing: ", e$message)
    return(NULL)
  })
}

#' Validate that crop files from previous processing still exist
#' @param cropped_paths Vector of file paths to validate
#' @return List with all_exist (logical) and missing_files (vector)
#' @export
validate_existing_crops <- function(cropped_paths) {
  message("  🔍 validate_existing_crops called")

  if (is.null(cropped_paths) || length(cropped_paths) == 0) {
    message("     ⚠️ No crop paths provided")
    return(list(
      all_exist = FALSE,
      missing_files = character(0)
    ))
  }

  # Convert to character vector if it's a list
  if (is.list(cropped_paths)) {
    cropped_paths <- unlist(cropped_paths)
  }

  message("     📁 Checking ", length(cropped_paths), " paths:")
  for (i in seq_along(cropped_paths)) {
    exists <- file.exists(cropped_paths[i])
    status <- if (exists) "✓" else "✗"
    message("        ", status, " ", cropped_paths[i])
  }

  existing <- file.exists(cropped_paths)

  result <- list(
    all_exist = all(existing),
    missing_files = cropped_paths[!existing]
  )

  message("     Result: all_exist = ", result$all_exist)
  if (!result$all_exist) {
    message("     ⚠️ Missing ", length(result$missing_files), " files")
  }

  return(result)
}

#' Copy existing crop files to a new directory
#' @param source_paths Vector of paths to copy from
#' @param dest_dir Directory to copy to
#' @return List with new_paths and success
#' @export
copy_existing_crops <- function(source_paths, dest_dir) {
  if (!dir.exists(dest_dir)) {
    dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  new_paths <- character(length(source_paths))
  
  for (i in seq_along(source_paths)) {
    source_file <- source_paths[i]
    filename <- basename(source_file)
    dest_file <- file.path(dest_dir, filename)
    
    success <- file.copy(source_file, dest_file, overwrite = TRUE)
    
    if (!success) {
      warning("Failed to copy: ", source_file)
      return(list(new_paths = NULL, success = FALSE))
    }
    
    new_paths[i] <- dest_file
  }
  
  return(list(new_paths = new_paths, success = TRUE))
}

#' Mark processing as reused in database
#' @param current_session_id Current session ID
#' @param source_session_id Source session ID
#' @param image_id Current image ID
#' @param source_image_id Source image ID
#' @return TRUE if successful
#' @export
mark_processing_reused <- function(current_session_id, source_session_id, 
                                   image_id, source_image_id) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    # Get user_id from image record
    user_record <- DBI::dbGetQuery(con, "
      SELECT user_id FROM images WHERE image_id = ?
    ", list(as.integer(image_id)))
    
    if (nrow(user_record) == 0) {
      warning("No user found for image_id: ", image_id)
      return(FALSE)
    }
    
    user_id <- user_record$user_id[1]
    
    DBI::dbExecute(con, "
      INSERT INTO processing_log (image_id, action, user_id, details, timestamp)
      VALUES (?, ?, ?, ?, datetime('now'))
    ", list(
      as.integer(image_id),
      "crops_reused",
      as.character(user_id),
      jsonlite::toJSON(list(
        source_session_id = as.character(source_session_id),
        source_image_id = as.integer(source_image_id),
        current_session_id = as.character(current_session_id),
        reused_at = as.character(Sys.time())
      ), auto_unbox = TRUE)
    ))
    
    return(TRUE)
    
  }, error = function(e) {
    message("❌ Error marking processing as reused: ", e$message)
    return(FALSE)
  })
}

#' Format timestamp for display
#' @param timestamp POSIXct or character timestamp
#' @return Formatted string
#' @export
format_timestamp <- function(timestamp) {
  if (is.null(timestamp)) {
    return("Unknown")
  }

  tryCatch({
    if (is.character(timestamp)) {
      timestamp <- as.POSIXct(timestamp)
    }

    format(timestamp, "%Y-%m-%d %H:%M:%S")
  }, error = function(e) {
    return(as.character(timestamp))
  })
}

#' Get file hash for a card_id
#' @param card_id Card ID from postal_cards table
#' @return Character string with file hash, or NULL if not found
#' @export
get_hash_for_card <- function(card_id) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))

    result <- DBI::dbGetQuery(con, "
      SELECT file_hash FROM postal_cards WHERE card_id = ?
    ", list(as.integer(card_id)))

    if (nrow(result) > 0) {
      return(result$file_hash[1])
    } else {
      message("No card found with card_id: ", card_id)
      return(NULL)
    }

  }, error = function(e) {
    message("Error in get_hash_for_card: ", e$message)
    return(NULL)
  })
}

# ==== SYSTEM INFORMATION ====

#' Get system information
#' @export
get_system_info <- function() {
  list(
    version = "3.1.0-deduplication",
    system = "Extended SQLite Tracking with AI, eBay & Deduplication Support",
    database_path = get_db_path(),
    features = c("AI Extraction Tracking", "eBay Posting Tracking", "Image Upload Tracking", "Image Deduplication"),
    new_tables = c("ai_extractions", "ebay_posts"),
    load_status = "working"
  )
}

message("✅ EXTENDED tracking system loaded with AI extraction, eBay posting & deduplication support!")
message("ℹ️ New tables: ai_extractions, ebay_posts")
message("ℹ️ New functions: track_ai_extraction, track_ebay_post, get_image_by_path")
message("ℹ️ Deduplication functions: find_existing_processing, validate_existing_crops, copy_existing_crops, mark_processing_reused")

# ==== TRACKING VIEWER HELPER FUNCTIONS ====

#' Get tracking data with filters
#'
#' @description Query processing history with date and eBay status filters
#'
#' @param date_filter SQL WHERE clause for date filtering
#' @param ebay_filter SQL WHERE clause for eBay status filtering
#' @return Data frame with tracking data
#' @export
get_tracking_data <- function(date_filter = "", ebay_filter = "") {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    query <- sprintf("
      SELECT
        pc.card_id,
        pc.original_filename,
        pc.image_type,
        pc.file_size,
        pc.width,
        pc.height,
        pc.first_seen,
        pc.last_updated,
        cp.crop_paths,
        cp.extraction_dir,
        cp.grid_rows,
        cp.grid_cols,
        cp.ai_title,
        cp.ai_description,
        cp.ai_condition,
        cp.ai_price,
        cp.ai_model,
        cp.last_processed,
        el.status as ebay_status,
        el.listing_url,
        el.error_message,
        sa.session_id,
        sa.timestamp as session_time,
        s.user_id,
        u.email as username,
        i.upload_path
      FROM postal_cards pc
      LEFT JOIN card_processing cp ON pc.card_id = cp.card_id
      LEFT JOIN ebay_listings el ON pc.card_id = el.card_id
      LEFT JOIN session_activity sa ON pc.card_id = sa.card_id AND sa.action = 'processed'
      LEFT JOIN sessions s ON sa.session_id = s.session_id
      LEFT JOIN users u ON s.user_id = u.user_id
      LEFT JOIN (
        SELECT file_hash, upload_path, upload_timestamp,
               ROW_NUMBER() OVER (PARTITION BY file_hash ORDER BY upload_timestamp DESC) as rn
        FROM images
        WHERE upload_path NOT LIKE '%%Temp%%'
      ) i ON pc.file_hash = i.file_hash AND i.rn = 1
      WHERE cp.last_processed IS NOT NULL
        %s
        %s
      ORDER BY pc.first_seen DESC
    ", date_filter, ebay_filter)

    result <- DBI::dbGetQuery(con, query)
    return(result)

  }, error = function(e) {
    message("Error getting tracking data: ", e$message)
    return(data.frame())
  })
}

#' Get Session-Based Tracking Data
#'
#' Groups processed cards by session, showing one row per processing session
#'
#' @param date_filter SQL date filter clause
#' @param ebay_filter SQL eBay status filter clause
#' @return Data frame with one row per session
#' @export
get_session_tracking_data <- function(date_filter = "", ebay_filter = "") {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    query <- sprintf("
      SELECT
        sa.session_id,
        MIN(sa.timestamp) as session_time,
        s.user_id,
        u.email as username,
        COUNT(DISTINCT pc.card_id) as cards_processed,
        SUM(CASE WHEN pc.image_type = 'face' THEN 1 ELSE 0 END) as has_face,
        SUM(CASE WHEN pc.image_type = 'verso' THEN 1 ELSE 0 END) as has_verso,
        SUM(CASE WHEN pc.image_type = 'combined' THEN 1 ELSE 0 END) as has_combined,
        SUM(CASE WHEN cp.ai_title IS NOT NULL THEN 1 ELSE 0 END) as ai_extractions,
        SUM(CASE WHEN el.status IS NOT NULL THEN 1 ELSE 0 END) as ebay_posts,
        MAX(el.status) as ebay_status
      FROM session_activity sa
      LEFT JOIN sessions s ON sa.session_id = s.session_id
      LEFT JOIN users u ON s.user_id = u.user_id
      LEFT JOIN postal_cards pc ON sa.card_id = pc.card_id
      LEFT JOIN card_processing cp ON pc.card_id = cp.card_id
      LEFT JOIN ebay_listings el ON pc.card_id = el.card_id
      WHERE sa.action IN ('processed', 'images_combined')
        AND cp.last_processed IS NOT NULL
        %s
        %s
      GROUP BY sa.session_id, s.user_id, u.email
      ORDER BY MIN(sa.timestamp) DESC
    ", date_filter, ebay_filter)

    result <- DBI::dbGetQuery(con, query)
    return(result)

  }, error = function(e) {
    message("Error getting session tracking data: ", e$message)
    return(data.frame())
  })
}

#' Get All Cards for a Session
#'
#' Retrieves all processed cards for a specific session with images and AI data
#'
#' @param session_id Session ID to retrieve cards for
#' @return Data frame with all cards in the session
#' @export
get_session_cards <- function(session_id) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    # Get ALL cards involved in this session, regardless of action type
    # This includes uploaded, processed, reused, and images_combined actions
    query <- "
      SELECT DISTINCT
        pc.card_id,
        pc.file_hash,
        pc.original_filename,
        pc.image_type,
        pc.file_size,
        pc.width,
        pc.height,
        cp.crop_paths,
        cp.grid_rows,
        cp.grid_cols,
        cp.h_boundaries,
        cp.v_boundaries,
        cp.extraction_dir,
        cp.ai_title,
        cp.ai_description,
        cp.ai_condition,
        cp.ai_price,
        cp.ai_model,
        cp.last_processed,
        el.status as ebay_status,
        el.listing_url,
        el.error_message,
        i.upload_path
      FROM session_activity sa
      LEFT JOIN postal_cards pc ON sa.card_id = pc.card_id
      LEFT JOIN card_processing cp ON pc.card_id = cp.card_id
      LEFT JOIN ebay_listings el ON pc.card_id = el.card_id
      LEFT JOIN (
        SELECT file_hash, upload_path, upload_timestamp,
               ROW_NUMBER() OVER (PARTITION BY file_hash ORDER BY upload_timestamp DESC) as rn
        FROM images
        WHERE upload_path NOT LIKE '%Temp%'
      ) i ON pc.file_hash = i.file_hash AND i.rn = 1
      WHERE sa.session_id = ?
      ORDER BY 
        CASE pc.image_type
          WHEN 'face' THEN 1
          WHEN 'verso' THEN 2
          WHEN 'combined' THEN 3
          ELSE 4
        END
    "

    result <- DBI::dbGetQuery(con, query, params = list(session_id))
    
    message("📊 get_session_cards found ", nrow(result), " cards for session ", session_id)
    if (nrow(result) > 0) {
      message("   Types: ", paste(result$image_type, collapse = ", "))
    }
    
    return(result)

  }, error = function(e) {
    message("Error getting session cards: ", e$message)
    return(data.frame())
  })
}


#' Format eBay status for display
#'
#' @description Convert eBay status to HTML badge
#'
#' @param status eBay status string
#' @return HTML span with badge styling
#' @export
format_ebay_status <- function(status) {
  if (is.na(status) || is.null(status) || status == "") {
    return('<span class="badge bg-secondary">Not Posted</span>')
  }

  badge_class <- switch(tolower(status),
    "listed" = "bg-success",
    "draft" = "bg-warning",
    "failed" = "bg-danger",
    "pending" = "bg-info",
    "bg-secondary"  # Fallback
  )

  sprintf('<span class="badge %s">%s</span>', badge_class, tools::toTitleCase(status))
}
