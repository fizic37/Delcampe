#' eBay Listings Viewer Module
#'
#' @description
#' Displays all eBay listings (stamps + postcards) with filtering, search, and refresh
#' Consolidates data from local database and eBay Trading API with smart caching
#'
#' @param id Module ID
#'
#' @export
mod_ebay_listings_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Header with stats and filters - NO BSLIB CARD BODY
    tags$div(
      class = "bg-light border rounded mb-3 p-2",

      # Title bar
      tags$div(
        class = "d-flex justify-content-between align-items-center mb-2",
        tags$h5(class = "mb-0", "eBay Listings Viewer (API-Synced)"),
        actionButton(ns("refresh_all"), "Refresh from eBay",
                    class = "btn-primary btn-sm", icon = icon("refresh"))
      ),

      # Single row: Stats + Filters + Countdown
      tags$div(
        class = "d-flex justify-content-between align-items-center gap-3",
        style = "font-size: 13px;",

        # Left: Stats with color labels
        tags$div(
          class = "d-flex align-items-center gap-3",
          uiOutput(ns("stats_display"))
        ),

        # Center: Filters (no labels)
        tags$div(
          class = "d-flex align-items-center gap-2",
          selectInput(ns("filter_status"), NULL,
                     choices = c("All", "Active", "Sold", "Ended"),
                     selected = "All",
                     width = "100px"),
          selectInput(ns("filter_format"), NULL,
                     choices = c("All", "Fixed Price", "Auction"),
                     selected = "All",
                     width = "110px")
        ),

        # Right: Countdown
        tags$div(
          class = "text-end text-muted",
          style = "font-size: 12px;",
          uiOutput(ns("refresh_countdown"))
        )
      )
    ),

    # Main datatable card
    bslib::card(
      bslib::card_header("Listings"),
      bslib::card_body(
        DT::dataTableOutput(ns("listings_table"))
      )
    )
  )
}

#' eBay Listings Viewer Server
#'
#' @param id Module ID
#' @param ebay_api Reactive returning EbayAPI object (with $trading field)
#' @param session_id Reactive returning session ID
#'
#' @export
mod_ebay_listings_server <- function(id, ebay_api, session_id, ebay_account_manager = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Database connection helper
    get_db <- function() {
      DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    }

    # Helper to decode category ID to broad category name
    # IMPORTANT: Uses SKU prefix as authoritative source since old stamps
    # were incorrectly exported to postcard category 262042
    decode_category <- function(category_id, sku) {
      if (is.na(category_id) || category_id == "") return("-")

      # Check SKU prefix first (authoritative for stamps vs postcards)
      if (!is.na(sku) && nzchar(sku)) {
        if (grepl("^(STAMP-|ST-)", sku, ignore.case = TRUE)) {
          return("Stamps")
        }
        if (grepl("^PC-", sku, ignore.case = TRUE)) {
          return("Postcards")
        }
      }

      # Fallback to category ID if SKU doesn't help
      category_num <- as.numeric(category_id)

      # Postcards: 262042 (Topographical), 262043 (Non-Topographical)
      if (category_num %in% c(262042, 262043)) {
        return("Postcards")
      }

      # Stamps: 260 is parent, 675, 265, etc. are leaf categories
      if (category_num == 260 || category_num %in% c(675, 265)) {
        return("Stamps")
      }

      # Unknown category
      return(paste0("Cat:", category_id))
    }

    # Reactive values for cache-based system
    cached_listings <- reactiveVal(NULL)
    last_sync_time <- reactiveVal(NULL)
    is_syncing <- reactiveVal(FALSE)

    # Get eBay user ID from active account
    ebay_user_id <- reactive({
      if (!is.null(ebay_account_manager)) {
        active <- ebay_account_manager$get_active_account()
        if (!is.null(active) && !is.null(active$user_id)) {
          return(active$user_id)
        }
      }
      return(NULL)
    })

    # Load cached data on init
    observe({
      req(ebay_user_id())

      con <- get_db()
      on.exit(DBI::dbDisconnect(con))

      data <- get_cached_listings(con, ebay_user_id())
      cached_listings(data)

      # Get last sync time from log
      last_sync <- DBI::dbGetQuery(con, "
        SELECT MAX(sync_started_at) as last_sync
        FROM ebay_sync_log
        WHERE ebay_user_id = ? AND sync_status = 'completed'
      ", list(ebay_user_id()))

      if (!is.na(last_sync$last_sync[1])) {
        last_sync_time(as.POSIXct(last_sync$last_sync[1]))
      }
    })

    # Countdown timer output
    output$refresh_countdown <- renderUI({
      if (is.null(last_sync_time())) {
        return(tags$span(class = "text-muted", icon("sync"), " Never synced"))
      }

      # Update every 10 seconds
      invalidateLater(10000)

      time_since_sync <- difftime(Sys.time(), last_sync_time(), units = "mins")
      time_remaining <- max(0, RATE_LIMIT_MINUTES - as.numeric(time_since_sync))

      # Calculate "ago" text
      mins_ago <- as.numeric(time_since_sync)
      sync_text <- if (mins_ago < 1) {
        "just now"
      } else if (mins_ago < 60) {
        paste(round(mins_ago), "min ago")
      } else {
        paste(round(mins_ago / 60, 1), "hrs ago")
      }

      tagList(
        tags$div(icon("sync"), " Last sync: ", sync_text),
        if (time_remaining > 0) {
          tags$div(
            class = "text-warning",
            icon("clock"),
            sprintf(" Next refresh in %d min", ceiling(time_remaining))
          )
        } else {
          tags$div(
            class = "text-success",
            icon("check"),
            " Refresh available"
          )
        }
      )
    })

    # Refresh all listings from eBay API (using new cache system)
    observeEvent(input$refresh_all, {
      cat("Refresh button clicked\n")

      # Debug: Check what we have
      user_id <- ebay_user_id()
      api <- ebay_api()

      cat("eBay User ID:", if (!is.null(user_id)) user_id else "NULL", "\n")
      cat("eBay API:", if (!is.null(api)) "Present" else "NULL", "\n")

      if (is.null(user_id)) {
        showNotification("No eBay account selected", type = "warning", duration = 5)
        return()
      }

      if (is.null(api) || is.null(api$trading)) {
        showNotification("eBay API not initialized. Please check OAuth connection.", type = "error", duration = 5)
        return()
      }

      con <- get_db()
      on.exit(DBI::dbDisconnect(con))

      # Show progress
      is_syncing(TRUE)
      showNotification("Syncing from eBay API...", id = "sync_progress", duration = NULL)

      # Call refresh function
      result <- refresh_ebay_cache(con, api$trading, user_id)

      # Hide progress
      is_syncing(FALSE)
      removeNotification("sync_progress")

      if (result$success) {
        # Reload cached data
        data <- get_cached_listings(con, ebay_user_id())
        cached_listings(data)
        last_sync_time(Sys.time())

        showNotification(
          sprintf("\u2705 Synced %d listings from eBay", result$items_synced),
          type = "message",
          duration = 3
        )
      } else {
        showNotification(
          paste("Error:", result$error),
          type = "error",
          duration = 10
        )
      }
    })

    # Filtered data based on user selections
    filtered_data <- reactive({
      req(cached_listings())
      data <- cached_listings()

      if (nrow(data) == 0) return(data)

      # Apply status filter (using listing_status from cache table)
      if (input$filter_status != "All") {
        data <- data[data$listing_status == tolower(input$filter_status), ]
      }

      # Apply format filter (using listing_type from cache table)
      if (input$filter_format != "All") {
        format_map <- c("Fixed Price" = "FixedPriceItem", "Auction" = "Chinese")
        format_value <- format_map[input$filter_format]
        data <- data[data$listing_type == format_value, ]
      }

      # Apply search filter
      if (!is.null(input$search_text) && nzchar(input$search_text)) {
        search_pattern <- tolower(input$search_text)
        matches <- grepl(search_pattern, tolower(data$title)) |
                  grepl(search_pattern, tolower(data$sku), fixed = TRUE)
        data <- data[matches, ]
      }

      # Add sort priority: active=1, ended=2, completed=3, sold=4
      data$sort_priority <- ifelse(data$listing_status == "active", 1,
                              ifelse(data$listing_status == "ended", 2,
                              ifelse(data$listing_status == "completed", 3, 4)))

      # Sort by priority then by title
      data <- data[order(data$sort_priority, data$title), ]

      return(data)
    })

    # Render stats display (status-focused: Active/Sold priority)
    output$stats_display <- renderUI({
      req(cached_listings())
      data <- cached_listings()

      if (nrow(data) == 0) {
        return(tags$div(
          class = "alert alert-info py-2 mb-2",
          "No cached data. Click 'Refresh from eBay' to load listings."
        ))
      }

      total <- nrow(data)
      active <- sum(data$listing_status == "active", na.rm = TRUE)
      sold <- sum(data$listing_status == "sold", na.rm = TRUE)
      ended <- sum(data$listing_status == "ended", na.rm = TRUE)

      # Last sync info
      sync_info <- if (!is.null(last_sync_time())) {
        time_ago <- as.numeric(difftime(Sys.time(), last_sync_time(), units = "mins"))
        if (time_ago < 1) {
          "just now"
        } else if (time_ago < 60) {
          paste(round(time_ago), "minutes ago")
        } else {
          paste(round(time_ago / 60, 1), "hours ago")
        }
      } else {
        "never"
      }

      tags$div(
        style = "font-size: 13px;",
        tags$span(class = "me-3", icon("list"), strong(" Total: "), total),
        tags$span(class = "me-3", "\U0001F7E2", strong(" Active: "), tags$span(class = "text-success", active)),
        tags$span(class = "me-3", "\U0001F535", strong(" Sold: "), tags$span(class = "text-primary", sold)),
        tags$span(class = "me-3", "\u26AA", strong(" Ended: "), tags$span(class = "text-muted", ended))
      )
    })

    # Render datatable (using cache table structure)
    output$listings_table <- DT::renderDataTable({
      data <- filtered_data()

      if (nrow(data) == 0) {
        return(DT::datatable(
          data.frame(Message = "No listings match your filters"),
          options = list(dom = 't', ordering = FALSE),
          rownames = FALSE,
          selection = 'none'
        ))
      }

      # Prepare display data (cache table columns)
      display_data <- data.frame(
        Status = sapply(data$listing_status, render_status_badge),
        Title = substr(data$title, 1, 60),
        Category = mapply(decode_category, data$category_id, data$sku, SIMPLIFY = TRUE),
        Price = sprintf("$%.2f", data$current_price),
        Type = ifelse(data$listing_type == "Chinese", "Auction", "Fixed"),
        Views = ifelse(is.na(data$view_count), "-", as.character(data$view_count)),
        Watchers = ifelse(is.na(data$watch_count), "-", as.character(data$watch_count)),
        Bids = ifelse(is.na(data$bid_count) | data$bid_count == 0, "-", as.character(data$bid_count)),
        TimeLeft = ifelse(is.na(data$time_remaining), "-",
                         sapply(data$time_remaining, format_time_remaining)),
        SoldQty = ifelse(is.na(data$quantity_sold) | data$quantity_sold == 0, "-",
                        as.character(data$quantity_sold)),
        stringsAsFactors = FALSE
      )

      DT::datatable(
        display_data,
        selection = "single",
        filter = "none",
        escape = FALSE,  # Allow HTML in Status column
        rownames = FALSE,
        options = list(
          pageLength = 25,
          lengthMenu = c(10, 25, 50, 100),
          ordering = FALSE,  # Disable client-side sorting (already sorted server-side)
          dom = "Blfrtip",
          buttons = c("copy", "csv", "excel"),
          scrollX = TRUE,
          columnDefs = list(
            list(width = "100px", targets = 0),  # Status
            list(width = "300px", targets = 1),  # Title
            list(width = "80px", targets = 2),   # Category
            list(width = "80px", targets = 3),   # Price
            list(width = "80px", targets = 4),   # Type
            list(width = "60px", targets = 5:7), # Views, Watchers, Bids
            list(width = "80px", targets = 8),   # TimeLeft
            list(width = "60px", targets = 9)    # SoldQty
          )
        ),
        extensions = "Buttons"
      )
    })
  })
}
