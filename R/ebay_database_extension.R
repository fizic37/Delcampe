# eBay Database Extension for Delcampe App
# Add this to tracking_database.R or create as separate file

#' Initialize eBay listings table
#' @export
initialize_ebay_tables <- function(db_path = get_db_path()) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
    on.exit(DBI::dbDisconnect(con))
    
    # eBay Listings table (comprehensive)
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS ebay_listings (
        listing_id INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id INTEGER,
        session_id TEXT NOT NULL,
        ebay_item_id TEXT,
        ebay_offer_id TEXT,
        sku TEXT UNIQUE NOT NULL,
        status TEXT DEFAULT 'draft',
        environment TEXT DEFAULT 'sandbox',
        title TEXT,
        description TEXT,
        price REAL,
        quantity INTEGER DEFAULT 1,
        condition TEXT,
        category_id TEXT DEFAULT NULL,
        listing_url TEXT,
        image_urls TEXT,
        aspects TEXT,
        api_type TEXT DEFAULT 'inventory',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        listed_at DATETIME,
        last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
        error_message TEXT,
        FOREIGN KEY (card_id) REFERENCES postal_cards(card_id),
        FOREIGN KEY (session_id) REFERENCES sessions(session_id)
      )
    ")

    # Migration: Add api_type column if it doesn't exist (for existing databases)
    columns <- DBI::dbGetQuery(con, "PRAGMA table_info(ebay_listings)")
    if (!"api_type" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN api_type TEXT DEFAULT 'inventory'")
      message("✅ Added api_type column to ebay_listings table")
    }

    # Migration: Add auction support columns if they don't exist
    columns <- DBI::dbGetQuery(con, "PRAGMA table_info(ebay_listings)")
    if (!"listing_type" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN listing_type TEXT DEFAULT 'fixed_price'")
      message("✅ Added listing_type column to ebay_listings table")
    }
    if (!"listing_duration" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN listing_duration TEXT DEFAULT 'GTC'")
      message("✅ Added listing_duration column to ebay_listings table")
    }
    if (!"buy_it_now_price" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN buy_it_now_price REAL")
      message("✅ Added buy_it_now_price column to ebay_listings table")
    }
    if (!"reserve_price" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN reserve_price REAL")
      message("✅ Added reserve_price column to ebay_listings table")
    }

    # Migration: Add scheduled listing support columns
    columns <- DBI::dbGetQuery(con, "PRAGMA table_info(ebay_listings)")
    if (!"schedule_time" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN schedule_time TEXT")
      message("✅ Added schedule_time column to ebay_listings table")
    }
    if (!"is_scheduled" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN is_scheduled INTEGER DEFAULT 0")
      message("✅ Added is_scheduled column to ebay_listings table")
    }
    if (!"actual_start_time" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN actual_start_time TEXT")
      message("✅ Added actual_start_time column to ebay_listings table")
    }

    # Migration: Add eBay API cache columns
    columns <- DBI::dbGetQuery(con, "PRAGMA table_info(ebay_listings)")
    if (!"watch_count" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN watch_count INTEGER DEFAULT 0")
      message("✅ Added watch_count column to ebay_listings table")
    }
    if (!"view_count" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN view_count INTEGER DEFAULT 0")
      message("✅ Added view_count column to ebay_listings table")
    }
    if (!"bid_count" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN bid_count INTEGER DEFAULT 0")
      message("✅ Added bid_count column to ebay_listings table")
    }
    if (!"current_price" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN current_price REAL")
      message("✅ Added current_price column to ebay_listings table")
    }
    if (!"time_remaining" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN time_remaining TEXT")
      message("✅ Added time_remaining column to ebay_listings table")
    }
    if (!"last_synced_at" %in% columns$name) {
      DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN last_synced_at DATETIME")
      message("✅ Added last_synced_at column to ebay_listings table")
    }

    # eBay Sync Log table (for rate limiting and tracking API calls)
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS ebay_sync_log (
        sync_id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        sync_completed_at DATETIME,
        items_synced INTEGER,
        api_calls_made INTEGER,
        sync_status TEXT DEFAULT 'in_progress',
        error_message TEXT,
        ebay_user_id TEXT
      )
    ")

    # Create indexes for ebay_listings
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_card ON ebay_listings(card_id)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_session ON ebay_listings(session_id)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_status ON ebay_listings(status)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_sku ON ebay_listings(sku)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_api_type ON ebay_listings(api_type)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_listing_type ON ebay_listings(listing_type)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_is_scheduled ON ebay_listings(is_scheduled)")

    # Create indexes for ebay_sync_log
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_sync_log_user ON ebay_sync_log(ebay_user_id)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_sync_log_started ON ebay_sync_log(sync_started_at)")
    
    message("✅ eBay listings table initialized")
    return(TRUE)
    
  }, error = function(e) {
    message("❌ Failed to initialize eBay tables: ", e$message)
    return(FALSE)
  })
}

#' Initialize eBay Listings Cache Table
#'
#' Creates table for storing ONLY eBay API data (not local drafts).
#' This cache is separate from the ebay_listings table which tracks our local draft/submission process.
#'
#' @param db_path Path to SQLite database
#'
#' @return TRUE if successful, FALSE otherwise
#' @export
initialize_ebay_cache_table <- function(db_path = get_db_path()) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
    on.exit(DBI::dbDisconnect(con))

    # Create cache table
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS ebay_listings_cache (
        cache_id INTEGER PRIMARY KEY AUTOINCREMENT,
        ebay_item_id TEXT UNIQUE NOT NULL,
        ebay_user_id TEXT NOT NULL,
        title TEXT,
        current_price REAL,
        currency TEXT DEFAULT 'USD',
        listing_status TEXT,
        listing_type TEXT,
        quantity INTEGER DEFAULT 1,
        quantity_sold INTEGER DEFAULT 0,
        watch_count INTEGER DEFAULT 0,
        view_count INTEGER DEFAULT 0,
        bid_count INTEGER DEFAULT 0,
        start_time DATETIME,
        end_time DATETIME,
        time_remaining TEXT,
        listing_url TEXT,
        gallery_url TEXT,
        sku TEXT,
        category_id TEXT,
        synced_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        api_call_name TEXT DEFAULT 'GetSellerList',
        FOREIGN KEY (ebay_user_id) REFERENCES ebay_users(ebay_user_id)
      )
    ")

    # Migration: Add category_id column if it doesn't exist
    existing_columns <- DBI::dbListFields(con, "ebay_listings_cache")
    if (!"category_id" %in% existing_columns) {
      message("🔄 Migrating cache table: adding category_id column")
      DBI::dbExecute(con, "ALTER TABLE ebay_listings_cache ADD COLUMN category_id TEXT")
    }

    # Create indexes for performance
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_cache_item_id ON ebay_listings_cache(ebay_item_id)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_cache_user_id ON ebay_listings_cache(ebay_user_id)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_cache_status ON ebay_listings_cache(listing_status)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_cache_synced_at ON ebay_listings_cache(synced_at)")

    message("\u2705 eBay listings cache table initialized")
    return(TRUE)

  }, error = function(e) {
    message("\u274c Failed to initialize cache table: ", e$message)
    return(FALSE)
  })
}

#' Save eBay listing to database
#' @param api_type API type used: "trading" or "inventory" (default: "inventory")
#' @param listing_type Listing type: "auction" or "fixed_price" (default: "fixed_price")
#' @param listing_duration Listing duration: "Days_3", "Days_5", "Days_7", "Days_10", or "GTC" (default: "GTC")
#' @param buy_it_now_price Buy It Now price for auctions (optional)
#' @param reserve_price Reserve price for auctions (optional)
#' @param schedule_time Scheduled start time as POSIXct or NULL for immediate (optional)
#' @param is_scheduled Boolean flag indicating if listing is scheduled (default: FALSE)
#' @param actual_start_time Actual start time returned by eBay as POSIXct or NULL (optional)
#' @param watch_count Number of watchers (default: 0)
#' @param view_count Number of views (default: 0)
#' @param bid_count Number of bids (default: 0)
#' @param current_price Current price from eBay (optional)
#' @param time_remaining Time remaining in ISO 8601 format (optional)
#' @param last_synced_at Last sync timestamp (optional)
#' @export
save_ebay_listing <- function(card_id, session_id, ebay_item_id = NULL,
                              ebay_offer_id = NULL, sku, status = "draft",
                              title = NULL, description = NULL, price = NULL,
                              condition = NULL, aspects = NULL, environment = "sandbox",
                              ebay_user_id = NULL, ebay_username = NULL, api_type = "inventory",
                              listing_type = "fixed_price", listing_duration = "GTC",
                              buy_it_now_price = NULL, reserve_price = NULL,
                              schedule_time = NULL, is_scheduled = FALSE, actual_start_time = NULL,
                              watch_count = 0, view_count = 0, bid_count = 0,
                              current_price = NULL, time_remaining = NULL, last_synced_at = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    # Convert aspects to JSON if provided
    aspects_json <- if (!is.null(aspects)) {
      jsonlite::toJSON(aspects, auto_unbox = TRUE)
    } else {
      NULL
    }

    # Convert datetime fields to character strings for database storage
    schedule_time_str <- if (!is.null(schedule_time)) {
      format(schedule_time, "%Y-%m-%d %H:%M:%S")
    } else {
      NULL
    }

    actual_start_time_str <- if (!is.null(actual_start_time)) {
      format(actual_start_time, "%Y-%m-%d %H:%M:%S")
    } else {
      NULL
    }

    last_synced_at_str <- if (!is.null(last_synced_at)) {
      format(last_synced_at, "%Y-%m-%d %H:%M:%S")
    } else {
      NULL
    }

    # Check if listing exists
    existing <- DBI::dbGetQuery(con, "
      SELECT listing_id FROM ebay_listings WHERE sku = ?
    ", list(sku))
    
    if (nrow(existing) > 0) {
      # Update existing
      DBI::dbExecute(con, "
        UPDATE ebay_listings
        SET ebay_item_id = ?, ebay_offer_id = ?, status = ?,
            title = ?, description = ?, price = ?, condition = ?,
            aspects = ?, ebay_user_id = ?, ebay_username = ?,
            api_type = ?, listing_type = ?, listing_duration = ?,
            buy_it_now_price = ?, reserve_price = ?,
            schedule_time = ?, is_scheduled = ?, actual_start_time = ?,
            watch_count = ?, view_count = ?, bid_count = ?,
            current_price = ?, time_remaining = ?, last_synced_at = ?,
            last_updated = CURRENT_TIMESTAMP,
            listed_at = CASE WHEN ? = 'listed' THEN CURRENT_TIMESTAMP ELSE listed_at END
        WHERE sku = ?
      ", list(ebay_item_id, ebay_offer_id, status,
              title, description, price, condition,
              aspects_json, ebay_user_id, ebay_username,
              api_type, listing_type, listing_duration,
              buy_it_now_price, reserve_price,
              schedule_time_str, as.integer(is_scheduled), actual_start_time_str,
              watch_count, view_count, bid_count,
              current_price, time_remaining, last_synced_at_str,
              status, sku))

      message("Updated eBay listing: ", sku)
    } else {
      # Insert new
      DBI::dbExecute(con, "
        INSERT INTO ebay_listings (
          card_id, session_id, ebay_item_id, ebay_offer_id, sku,
          status, environment, title, description, price,
          condition, aspects, ebay_user_id, ebay_username, api_type,
          listing_type, listing_duration, buy_it_now_price, reserve_price,
          schedule_time, is_scheduled, actual_start_time,
          watch_count, view_count, bid_count, current_price, time_remaining, last_synced_at,
          listed_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
          CASE WHEN ? = 'listed' THEN CURRENT_TIMESTAMP ELSE NULL END)
      ", list(card_id, session_id, ebay_item_id, ebay_offer_id, sku,
              status, environment, title, description, price,
              condition, aspects_json, ebay_user_id, ebay_username, api_type,
              listing_type, listing_duration, buy_it_now_price, reserve_price,
              schedule_time_str, as.integer(is_scheduled), actual_start_time_str,
              watch_count, view_count, bid_count, current_price, time_remaining, last_synced_at_str,
              status))

      message("Created eBay listing: ", sku)
    }
    
    return(TRUE)
    
  }, error = function(e) {
    message("Error saving eBay listing: ", e$message)
    return(FALSE)
  })
}

#' Get eBay listing by card ID
#' @export
get_ebay_listing_for_card <- function(card_id) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    result <- DBI::dbGetQuery(con, "
      SELECT * FROM ebay_listings 
      WHERE card_id = ? 
      ORDER BY created_at DESC 
      LIMIT 1
    ", list(card_id))
    
    if (nrow(result) > 0) {
      # Parse aspects JSON
      if (!is.null(result$aspects[1])) {
        result$aspects <- list(jsonlite::fromJSON(result$aspects[1]))
      }
      return(as.list(result[1,]))
    }
    
    return(NULL)
    
  }, error = function(e) {
    message("Error getting eBay listing: ", e$message)
    return(NULL)
  })
}

#' Update eBay listing status
#' @export  
update_ebay_listing_status <- function(sku, status, error_message = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con))
    
    DBI::dbExecute(con, "
      UPDATE ebay_listings 
      SET status = ?, error_message = ?, last_updated = CURRENT_TIMESTAMP
      WHERE sku = ?
    ", list(status, error_message, sku))
    
    return(TRUE)
    
  }, error = function(e) {
    message("Error updating eBay listing status: ", e$message)
    return(FALSE)
  })
}
