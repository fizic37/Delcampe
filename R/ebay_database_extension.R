# eBay Database Extension for Delcampe App
# Add this to tracking_database.R or create as separate file

#' Initialize eBay listings table
#' @export
initialize_ebay_tables <- function(db_path = "inst/app/data/tracking.sqlite") {
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
        category_id TEXT DEFAULT '914',
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
    
    # Create indexes
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_card ON ebay_listings(card_id)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_session ON ebay_listings(session_id)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_status ON ebay_listings(status)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_sku ON ebay_listings(sku)")
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_api_type ON ebay_listings(api_type)")
    
    message("✅ eBay listings table initialized")
    return(TRUE)
    
  }, error = function(e) {
    message("❌ Failed to initialize eBay tables: ", e$message)
    return(FALSE)
  })
}

#' Save eBay listing to database
#' @param api_type API type used: "trading" or "inventory" (default: "inventory")
#' @export
save_ebay_listing <- function(card_id, session_id, ebay_item_id = NULL,
                              ebay_offer_id = NULL, sku, status = "draft",
                              title = NULL, description = NULL, price = NULL,
                              condition = NULL, aspects = NULL, environment = "sandbox",
                              ebay_user_id = NULL, ebay_username = NULL, api_type = "inventory") {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con))
    
    # Convert aspects to JSON if provided
    aspects_json <- if (!is.null(aspects)) {
      jsonlite::toJSON(aspects, auto_unbox = TRUE)
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
            api_type = ?,
            last_updated = CURRENT_TIMESTAMP,
            listed_at = CASE WHEN ? = 'listed' THEN CURRENT_TIMESTAMP ELSE listed_at END
        WHERE sku = ?
      ", list(ebay_item_id, ebay_offer_id, status,
              title, description, price, condition,
              aspects_json, ebay_user_id, ebay_username,
              api_type,
              status, sku))

      message("Updated eBay listing: ", sku)
    } else {
      # Insert new
      DBI::dbExecute(con, "
        INSERT INTO ebay_listings (
          card_id, session_id, ebay_item_id, ebay_offer_id, sku,
          status, environment, title, description, price,
          condition, aspects, ebay_user_id, ebay_username, api_type, listed_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
          CASE WHEN ? = 'listed' THEN CURRENT_TIMESTAMP ELSE NULL END)
      ", list(card_id, session_id, ebay_item_id, ebay_offer_id, sku,
              status, environment, title, description, price,
              condition, aspects_json, ebay_user_id, ebay_username, api_type, status))

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
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
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
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
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
