#' eBay Listing Sync Helpers
#'
#' Functions for syncing listing data from eBay Trading API with rate limiting
#'
#' @name ebay_sync_helpers
#' @keywords internal
NULL

#' Fetch all seller listings from eBay Trading API
#'
#' @param ebay_api EbayTradingAPI object (from trading field of init_ebay_api result)
#' @param start_date POSIXct start date for listings
#' @param end_date POSIXct end date for listings
#' @param page_number Integer page number for pagination
#'
#' @return List with items (list of listing data) and has_more_items (boolean)
#' @export
fetch_seller_listings <- function(ebay_api, start_date, end_date, page_number = 1) {
  # Call Trading API's get_seller_list method
  response_xml <- ebay_api$get_seller_list(start_date, end_date, page_number, include_watch_count = TRUE)

  # Parse XML response
  items <- parse_seller_list_response(response_xml)

  # Handle pagination recursively
  if (items$has_more_items) {
    next_page <- fetch_seller_listings(ebay_api, start_date, end_date, page_number + 1)
    items$items <- c(items$items, next_page$items)
  }

  return(items)
}

#' Parse GetSellerList XML response
#'
#' @param xml_response Character XML response from eBay
#'
#' @return List with items and has_more_items
#' @keywords internal
parse_seller_list_response <- function(xml_response) {
  # Parse XML with error handling
  doc <- tryCatch({
    xml2::read_xml(xml_response)
  }, error = function(e) {
    cat("❌ Failed to parse XML response:\n")
    cat(substr(xml_response, 1, 500), "\n")
    stop("XML parsing failed: ", e$message)
  })

  # Check Ack (handle missing node)
  ack_node <- xml2::xml_find_first(doc, "//Ack")
  ack <- if (length(ack_node) > 0) {
    xml2::xml_text(ack_node)
  } else {
    "Unknown"
  }

  cat("🔍 eBay API Response - Ack:", ack, "\n")

  if (!is.na(ack) && ack != "Success" && ack != "Warning") {
    # Extract all error information
    error_code_node <- xml2::xml_find_first(doc, "//ErrorCode")
    error_code <- if (length(error_code_node) > 0) {
      xml2::xml_text(error_code_node)
    } else {
      "Unknown"
    }

    short_msg_node <- xml2::xml_find_first(doc, "//ShortMessage")
    short_msg <- if (length(short_msg_node) > 0) {
      xml2::xml_text(short_msg_node)
    } else {
      "Unknown"
    }

    error_msg_node <- xml2::xml_find_first(doc, "//LongMessage")
    error_msg <- if (length(error_msg_node) > 0) {
      xml2::xml_text(error_msg_node)
    } else {
      "Unknown error"
    }

    # Print full error details to console
    cat("❌ eBay API Error:\n")
    cat("   Code:", error_code, "\n")
    cat("   Short Message:", short_msg, "\n")
    cat("   Long Message:", error_msg, "\n")

    stop("GetSellerList failed [", error_code, "]: ", error_msg)
  }

  # Extract items
  item_nodes <- xml2::xml_find_all(doc, "//ItemArray/Item")
  items <- lapply(item_nodes, function(item) {
    # Helper to safely extract text (returns NA if node missing)
    safe_text <- function(xpath, default = NA) {
      node <- xml2::xml_find_first(item, xpath)
      if (length(node) == 0) return(default)
      xml2::xml_text(node)
    }

    # Helper to safely extract numeric
    safe_numeric <- function(xpath, default = NA) {
      text <- safe_text(xpath, as.character(default))
      as.numeric(text)
    }

    # Helper to safely extract integer
    safe_integer <- function(xpath, default = NA) {
      text <- safe_text(xpath, as.character(default))
      as.integer(text)
    }

    list(
      ItemID = safe_text("./ItemID"),
      Title = safe_text("./Title"),
      CurrentPrice = safe_numeric("./SellingStatus/CurrentPrice"),
      ListingStatus = safe_text("./SellingStatus/ListingStatus"),
      QuantitySold = safe_integer("./SellingStatus/QuantitySold", 0),
      BidCount = safe_integer("./SellingStatus/BidCount", 0),
      WatchCount = safe_integer("./WatchCount", 0),
      HitCount = safe_integer("./HitCount", 0),
      TimeLeft = safe_text("./TimeLeft"),
      ViewItemURL = safe_text("./ListingDetails/ViewItemURL")
    )
  })

  # Check for more items (handle missing node gracefully)
  has_more_node <- xml2::xml_find_first(doc, "//HasMoreItems")
  has_more <- if (length(has_more_node) > 0) {
    xml2::xml_text(has_more_node) == "true"
  } else {
    FALSE
  }

  return(list(items = items, has_more_items = has_more))
}

#' Check if eBay sync is allowed (rate limiting)
#'
#' @param con Database connection
#' @param ebay_user_id eBay user ID
#' @param min_interval_minutes Minimum minutes between syncs (default 15)
#'
#' @return Logical TRUE if sync allowed
#' @export
can_sync_listings <- function(con, ebay_user_id, min_interval_minutes = 15) {
  last_sync <- DBI::dbGetQuery(con, "
    SELECT sync_started_at
    FROM ebay_sync_log
    WHERE ebay_user_id = ? AND sync_status = 'completed'
    ORDER BY sync_started_at DESC
    LIMIT 1
  ", list(ebay_user_id))

  if (nrow(last_sync) == 0) return(TRUE)

  last_sync_time <- as.POSIXct(last_sync$sync_started_at)
  time_since_sync <- difftime(Sys.time(), last_sync_time, units = "mins")

  return(as.numeric(time_since_sync) >= min_interval_minutes)
}

#' Log start of sync operation
#'
#' @param con Database connection
#' @param ebay_user_id eBay user ID
#'
#' @return Integer sync_id
#' @export
log_sync_start <- function(con, ebay_user_id) {
  DBI::dbExecute(con, "
    INSERT INTO ebay_sync_log (ebay_user_id, sync_status)
    VALUES (?, 'in_progress')
  ", list(ebay_user_id))

  return(DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS sync_id")$sync_id)
}

#' Log completion of sync operation
#'
#' @param con Database connection
#' @param sync_id Sync log ID
#' @param items_synced Number of items synced
#' @param api_calls Number of API calls made
#'
#' @export
log_sync_complete <- function(con, sync_id, items_synced, api_calls) {
  DBI::dbExecute(con, "
    UPDATE ebay_sync_log
    SET sync_completed_at = CURRENT_TIMESTAMP,
        items_synced = ?,
        api_calls_made = ?,
        sync_status = 'completed'
    WHERE sync_id = ?
  ", list(items_synced, api_calls, sync_id))
}

#' Log sync error
#'
#' @param con Database connection
#' @param sync_id Sync log ID
#' @param error_message Error message
#'
#' @export
log_sync_error <- function(con, sync_id, error_message) {
  DBI::dbExecute(con, "
    UPDATE ebay_sync_log
    SET sync_completed_at = CURRENT_TIMESTAMP,
        sync_status = 'failed',
        error_message = ?
    WHERE sync_id = ?
  ", list(error_message, sync_id))
}

#' Update cached eBay data in database (INSERT or UPDATE)
#'
#' @param con Database connection
#' @param ebay_items List of items from parse_seller_list_response
#'
#' @export
update_listings_cache <- function(con, ebay_items) {
  for (item in ebay_items) {
    # Safely extract ListingStatus with comprehensive NULL/NA handling
    listing_status <- tryCatch({
      if (is.null(item$ListingStatus)) {
        "unknown"
      } else if (length(item$ListingStatus) == 0) {
        "unknown"
      } else if (is.na(item$ListingStatus)) {
        "unknown"
      } else {
        as.character(item$ListingStatus)
      }
    }, error = function(e) {
      "unknown"
    })

    # Map eBay ListingStatus to our internal status
    ebay_status <- tolower(listing_status)

    internal_status <- switch(ebay_status,
      "active" = "listed",
      "completed" = "sold",
      "ended" = "ended",
      "cancelled" = "terminated",
      "customcode" = "error",
      ebay_status  # Use as-is if not recognized
    )

    # Check if listing exists in database
    existing <- tryCatch({
      DBI::dbGetQuery(con, "
        SELECT listing_id FROM ebay_listings WHERE ebay_item_id = ?
      ", list(item$ItemID))
    }, error = function(e) {
      data.frame(listing_id = integer(0))
    })

    if (nrow(existing) > 0) {
      # UPDATE existing listing
      DBI::dbExecute(con, "
        UPDATE ebay_listings
        SET status = ?,
            watch_count = ?,
            view_count = ?,
            bid_count = ?,
            current_price = ?,
            time_remaining = ?,
            last_synced_at = CURRENT_TIMESTAMP
        WHERE ebay_item_id = ?
      ", list(
        internal_status,
        item$WatchCount %||% 0,
        item$HitCount %||% 0,
        item$BidCount %||% 0,
        item$CurrentPrice,
        item$TimeLeft,
        item$ItemID
      ))
    } else {
      # INSERT new listing from eBay (not in our database yet)
      # Detect SKU pattern from title or generate one
      sku <- paste0("EBAY-", item$ItemID)

      DBI::dbExecute(con, "
        INSERT INTO ebay_listings (
          ebay_item_id, sku, title, status, price,
          watch_count, view_count, bid_count, current_price, time_remaining,
          session_id, api_type, last_synced_at, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ", list(
        item$ItemID,
        sku,
        item$Title,
        internal_status,
        item$CurrentPrice,
        item$WatchCount %||% 0,
        item$HitCount %||% 0,
        item$BidCount %||% 0,
        item$CurrentPrice,
        item$TimeLeft,
        "ebay_sync",  # session_id for synced items
        "trading"     # api_type
      ))
    }
  }
}

#' Get all eBay listings with item type detection
#'
#' @param con Database connection
#' @param status_filter Optional status filter (e.g., "listed", "sold")
#'
#' @return Data frame with all listings
#' @export
get_all_ebay_listings <- function(con, status_filter = NULL) {
  sql <- "
    SELECT
      el.*,
      CASE
        WHEN el.sku LIKE 'PC-%' THEN 'Postcard'
        WHEN el.sku LIKE 'ST-%' THEN 'Stamp'
        WHEN el.sku LIKE 'STAMP-%' THEN 'Stamp'
        ELSE 'Unknown'
      END as item_type
    FROM ebay_listings el
    WHERE 1=1
  "

  # Add status filter if provided
  if (!is.null(status_filter)) {
    sql <- paste0(sql, " AND el.status = ?")
  }

  sql <- paste0(sql, " ORDER BY el.listed_at DESC")

  if (!is.null(status_filter)) {
    result <- DBI::dbGetQuery(con, sql, list(status_filter))
  } else {
    result <- DBI::dbGetQuery(con, sql)
  }

  return(result)
}

#' Get eBay user ID from session
#'
#' @param con Database connection
#' @param session_id Session ID
#'
#' @return Character eBay user ID or NULL
#' @export
get_ebay_user_id_from_session <- function(con, session_id) {
  result <- DBI::dbGetQuery(con, "
    SELECT user_id FROM sessions WHERE session_id = ?
  ", list(session_id))

  if (nrow(result) == 0) return(NULL)

  # For now, assume user_id maps 1:1 to ebay_user_id
  # TODO: Add mapping table if needed
  return(result$user_id)
}

#' Render status badge HTML
#'
#' @param status Status string
#'
#' @return HTML string
#' @export
render_status_badge <- function(status) {
  badges <- c(
    "listed" = '<span class="badge bg-success">Listed</span>',
    "active" = '<span class="badge bg-success">Active</span>',
    "scheduled" = '<span class="badge bg-warning">Scheduled</span>',
    "sold" = '<span class="badge bg-primary">Sold</span>',
    "ended" = '<span class="badge bg-secondary">Ended</span>',
    "completed" = '<span class="badge bg-secondary">Completed</span>',
    "terminated" = '<span class="badge bg-danger">Terminated</span>',
    "cancelled" = '<span class="badge bg-danger">Cancelled</span>',
    "error" = '<span class="badge bg-danger">Error</span>',
    "draft" = '<span class="badge bg-light text-dark">Draft</span>'
  )

  # If status is NULL or empty, show Unknown
  if (is.null(status) || is.na(status) || status == "") {
    return('<span class="badge bg-light text-muted">Unknown</span>')
  }

  # Return matching badge or Unknown with the actual status
  badges[status] %||% sprintf('<span class="badge bg-light text-muted">%s</span>', status)
}

#' Format time remaining for display
#'
#' @param time_left ISO 8601 duration string (e.g., "P2DT3H30M")
#'
#' @return Human-readable string
#' @export
format_time_remaining <- function(time_left) {
  if (is.null(time_left) || is.na(time_left) || time_left == "") {
    return("")
  }

  # Parse ISO 8601 duration
  # P2DT3H30M = 2 days, 3 hours, 30 minutes
  days <- as.numeric(gsub(".*P([0-9]+)D.*", "\\1", time_left))
  hours <- as.numeric(gsub(".*T([0-9]+)H.*", "\\1", time_left))

  if (is.na(days)) days <- 0
  if (is.na(hours)) hours <- 0

  if (days > 0) {
    return(sprintf("%dd %dh", days, hours))
  } else if (hours > 0) {
    return(sprintf("%dh", hours))
  } else {
    return("< 1h")
  }
}
