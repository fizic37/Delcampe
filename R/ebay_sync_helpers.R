#' eBay Listing Sync Helpers
#'
#' Functions for syncing listing data from eBay Trading API with rate limiting
#'
#' @name ebay_sync_helpers
#' @keywords internal
NULL

# Rate limiting configuration
RATE_LIMIT_MINUTES <- 15  # Minimum minutes between full cache refreshes

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
  # Call Trading API's get_seller_list method with error handling
  response_xml <- tryCatch({
    ebay_api$get_seller_list(start_date, end_date, page_number, include_watch_count = TRUE)
  }, error = function(e) {
    cat("❌ eBay API HTTP Request Failed:\n")
    cat("   Error:", e$message, "\n")
    cat("   Date range:", as.character(start_date), "to", as.character(end_date), "\n")
    cat("   Page:", page_number, "\n")

    # Check if it's an OAuth error
    if (grepl("401|403|Unauthorized|Forbidden", e$message, ignore.case = TRUE)) {
      cat("   ⚠️  This looks like an authentication error. OAuth token may have expired.\n")
    }

    stop("Failed to perform HTTP request: ", e$message)
  })

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

  # Check Ack (handle namespaces and missing nodes)
  ns <- xml2::xml_ns(doc)

  # Try multiple XPath strategies to find Ack node
  ack_node <- xml2::xml_find_first(doc, ".//d1:Ack | .//Ack | .//*[local-name()='Ack']", ns)
  ack <- if (length(ack_node) > 0 && !is.na(ack_node)) {
    xml2::xml_text(ack_node)
  } else {
    # Debug: Print response structure
    cat("⚠️  Could not find Ack node. Response preview:\n")
    cat(substr(as.character(xml_response), 1, 1000), "\n\n")
    NULL
  }

  cat("🔍 eBay API Response - Ack:", ifelse(is.null(ack), "NULL", ack), "\n")

  # Only treat as error if Ack is explicitly "Failure"
  if (!is.null(ack) && !is.na(ack) && ack == "Failure") {
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

  # Extract items (handle namespaces)
  item_nodes <- xml2::xml_find_all(doc, ".//d1:ItemArray/d1:Item | .//ItemArray/Item | .//*[local-name()='ItemArray']/*[local-name()='Item']", ns)

  cat("📦 Found", length(item_nodes), "items in response\n")

  items <- lapply(item_nodes, function(item) {
    # Helper to safely extract text (returns NA if node missing, handles namespaces)
    safe_text <- function(xpath, default = NA) {
      # First try: standard xpath
      node <- xml2::xml_find_first(item, xpath)

      # Second try: with d1 namespace
      if (length(node) == 0) {
        xpath_ns <- gsub("\\./", "./d1:", xpath)
        xpath_ns <- gsub("/", "/d1:", xpath_ns)
        node <- xml2::xml_find_first(item, xpath_ns, ns)
      }

      # Third try: strip namespace entirely using xml_children
      if (length(node) == 0) {
        # For simple paths like "./ItemID", just get child by name
        path_parts <- strsplit(xpath, "/")[[1]]
        path_parts <- path_parts[path_parts != "." & path_parts != ""]

        current <- item
        for (part in path_parts) {
          children <- xml2::xml_children(current)
          names <- xml2::xml_name(children)
          match_idx <- which(names == part)
          if (length(match_idx) == 0) {
            return(default)
          }
          current <- children[[match_idx[1]]]
        }
        node <- current
      }

      if (length(node) == 0) return(default)
      text <- xml2::xml_text(node)
      if (is.na(text) || text == "") return(default)
      text
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
      ListingType = safe_text("./ListingType"),
      Quantity = safe_integer("./Quantity", 1),
      QuantitySold = safe_integer("./SellingStatus/QuantitySold", 0),
      BidCount = safe_integer("./SellingStatus/BidCount", 0),
      WatchCount = safe_integer("./WatchCount", 0),
      HitCount = safe_integer("./HitCount", 0),
      TimeLeft = safe_text("./TimeLeft"),
      StartTime = safe_text("./ListingDetails/StartTime"),
      EndTime = safe_text("./ListingDetails/EndTime"),
      ViewItemURL = safe_text("./ListingDetails/ViewItemURL"),
      GalleryURL = safe_text("./PictureDetails/GalleryURL"),
      PrimaryCategory = safe_text("./PrimaryCategory/CategoryID")
    )
  })

  # Check for more items (handle missing node gracefully and namespaces)
  has_more_node <- xml2::xml_find_first(doc, ".//d1:HasMoreItems | .//HasMoreItems | .//*[local-name()='HasMoreItems']", ns)
  has_more <- if (length(has_more_node) > 0 && !is.na(has_more_node)) {
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

#' Refresh eBay Listings Cache from API
#'
#' Clears existing cache and repopulates with fresh data from GetSellerList.
#' This function enforces rate limiting and provides atomic cache refresh.
#'
#' @param con Database connection (DBI connection object)
#' @param ebay_api EbayTradingAPI object (from trading field of init_ebay_api result)
#' @param ebay_user_id eBay user ID (character)
#' @param days_back Number of days to fetch (default 90)
#'
#' @return List with success (boolean), items_synced (integer), and error (character) if failed
#' @export
refresh_ebay_cache <- function(con, ebay_api, ebay_user_id, days_back = 90) {
  # Check rate limit
  if (!can_sync_listings(con, ebay_user_id, RATE_LIMIT_MINUTES)) {
    return(list(
      success = FALSE,
      error = sprintf("Rate limit: wait %d minutes between refreshes", RATE_LIMIT_MINUTES)
    ))
  }

  # Log sync start
  sync_id <- log_sync_start(con, ebay_user_id)

  tryCatch({
    # Fetch from eBay Trading API
    ebay_data <- fetch_seller_listings(
      ebay_api,
      start_date = Sys.Date() - days_back,
      end_date = Sys.Date()
    )

    # Clear existing cache for this user (atomic operation)
    deleted_count <- DBI::dbExecute(con, "
      DELETE FROM ebay_listings_cache WHERE ebay_user_id = ?
    ", list(ebay_user_id))

    cat(sprintf("\U0001F5D1  Cleared %d old cache entries for user: %s\n", deleted_count, ebay_user_id))

    # Insert new items
    items_inserted <- 0

    # Debug: Print first item structure
    if (length(ebay_data$items) > 0) {
      cat("🔍 First item structure:\n")
      cat("  ItemID:", ebay_data$items[[1]]$ItemID, "\n")
      cat("  Title:", substr(ebay_data$items[[1]]$Title, 1, 50), "\n")
      cat("  ListingStatus:", ebay_data$items[[1]]$ListingStatus, "\n")
    }

    for (item in ebay_data$items) {
      # Helper to ensure single value (take first element if vector)
      ensure_single <- function(x, default = NA) {
        if (is.null(x) || length(x) == 0) return(default)
        if (length(x) > 1) return(x[1])
        if (is.na(x)) return(default)
        return(x)
      }

      # Skip items without ItemID (required field)
      item_id <- ensure_single(item$ItemID)
      if (is.null(item_id) || is.na(item_id) || item_id == "") {
        cat("⚠️  Skipping item with missing ItemID\n")
        next
      }

      # Map eBay status to our internal status
      listing_status <- map_ebay_status(ensure_single(item$ListingStatus), ensure_single(item$QuantitySold, 0))

      # Detect SKU from title (if present)
      sku <- extract_sku_from_title(ensure_single(item$Title))

      # Extract times safely
      start_time <- if (!is.null(item$StartTime) && !is.na(item$StartTime)) {
        as.character(ensure_single(item$StartTime))
      } else {
        NA_character_
      }

      end_time <- if (!is.null(item$EndTime) && !is.na(item$EndTime)) {
        as.character(ensure_single(item$EndTime))
      } else {
        NA_character_
      }

      # Prepare all parameters ensuring single values
      params <- list(
        ensure_single(item$ItemID),
        ensure_single(ebay_user_id),
        ensure_single(item$Title),
        ensure_single(item$CurrentPrice, 0),
        "USD",
        ensure_single(listing_status),
        ensure_single(item$ListingType, "FixedPriceItem"),
        ensure_single(item$Quantity, 1),
        ensure_single(item$QuantitySold, 0),
        ensure_single(item$WatchCount, 0),
        ensure_single(item$HitCount, 0),
        ensure_single(item$BidCount, 0),
        start_time,
        end_time,
        ensure_single(item$TimeLeft),
        ensure_single(item$ViewItemURL),
        ensure_single(item$GalleryURL),
        sku,
        ensure_single(item$PrimaryCategory)
      )

      # Insert into cache (OR REPLACE to handle duplicates)
      DBI::dbExecute(con, "
        INSERT OR REPLACE INTO ebay_listings_cache (
          ebay_item_id, ebay_user_id, title, current_price, currency,
          listing_status, listing_type, quantity, quantity_sold,
          watch_count, view_count, bid_count, start_time, end_time,
          time_remaining, listing_url, gallery_url, sku, category_id, synced_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ", params)

      items_inserted <- items_inserted + 1
    }

    # Log sync complete
    log_sync_complete(con, sync_id, items_inserted, api_calls = 1)

    cat(sprintf("\u2705 Cache refreshed: %d items\n", items_inserted))

    return(list(
      success = TRUE,
      items_synced = items_inserted
    ))

  }, error = function(e) {
    # Log error
    log_sync_error(con, sync_id, e$message)

    cat(sprintf("\u274c Cache refresh failed: %s\n", e$message))

    return(list(
      success = FALSE,
      error = e$message
    ))
  })
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

#' Get Cached eBay Listings
#'
#' Retrieve listings from cache table with optional filtering.
#' Results are ordered by status priority (active first, then sold, then others).
#'
#' @param con Database connection (DBI connection object)
#' @param ebay_user_id eBay user ID (character, required)
#' @param status_filter Optional status filter ("active", "sold", "ended", "all")
#'
#' @return Data frame with cached listings
#' @export
get_cached_listings <- function(con, ebay_user_id, status_filter = NULL) {
  sql <- "
    SELECT *
    FROM ebay_listings_cache
    WHERE ebay_user_id = ?
  "

  params <- list(ebay_user_id)

  # Add status filter if provided
  if (!is.null(status_filter) && status_filter != "all") {
    sql <- paste0(sql, " AND listing_status = ?")
    params <- c(params, list(status_filter))
  }

  # Order by status priority: active first, then sold, then others
  sql <- paste0(sql, "
    ORDER BY
      CASE listing_status
        WHEN 'active' THEN 1
        WHEN 'sold' THEN 2
        WHEN 'ended' THEN 3
        ELSE 4
      END,
      synced_at DESC
  ")

  result <- DBI::dbGetQuery(con, sql, params)

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
  days <- suppressWarnings(as.numeric(gsub(".*P([0-9]+)D.*", "\\1", time_left)))
  hours <- suppressWarnings(as.numeric(gsub(".*T([0-9]+)H.*", "\\1", time_left)))

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

#' Map eBay ListingStatus to Internal Status
#'
#' Converts eBay API listing status values to standardized internal status values.
#' Note: "Completed" can mean either sold or ended without sale.
#' Use quantity_sold to differentiate.
#'
#' @param ebay_status Character. Status value from eBay API (e.g., "Active", "Completed", "Ended")
#' @param quantity_sold Integer. Number of items sold (optional)
#' @return Character. Internal status value ("active", "sold", "ended", etc.)
#' @keywords internal
map_ebay_status <- function(ebay_status, quantity_sold = 0) {
  if (is.null(ebay_status) || is.na(ebay_status)) {
    return("unknown")
  }

  # Handle Completed status based on whether items were sold
  if (ebay_status == "Completed") {
    if (!is.null(quantity_sold) && !is.na(quantity_sold) && quantity_sold > 0) {
      return("sold")
    } else {
      return("ended")
    }
  }

  status_map <- c(
    "Active" = "active",
    "Ended" = "ended",
    "Cancelled" = "terminated",
    "CustomCode" = "error"
  )

  # Return mapped value or lowercase original if not found
  result <- status_map[ebay_status]
  if (is.na(result)) {
    return(tolower(ebay_status))
  }
  return(as.character(result))
}

#' Extract SKU from Listing Title
#'
#' Attempts to extract a SKU pattern from a listing title.
#' Looks for patterns like: PC-XXXX, ST-XXXX, STAMP-XXXX
#'
#' @param title Character. Listing title to search
#' @return Character. Extracted SKU or NA if not found
#' @keywords internal
extract_sku_from_title <- function(title) {
  if (is.null(title) || is.na(title) || title == "") {
    return(NA_character_)
  }

  # Try to detect SKU patterns: PC-XXXX, ST-XXXX, STAMP-XXXX
  match <- stringr::str_extract(title, "(PC|ST|STAMP)-[A-Z0-9]+")

  if (is.na(match)) {
    return(NA_character_)
  }

  return(match)
}
