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
    # Header card with stats and refresh - COMPACT VERSION
    bslib::card(
      bslib::card_header(
        class = "d-flex justify-content-between align-items-center py-2",
        tags$span("eBay Listings Viewer", style = "font-size: 1.1rem; font-weight: 500;"),
        actionButton(ns("refresh_all"), "Refresh from eBay",
                    class = "btn-primary btn-sm", icon = icon("refresh"))
      ),
      bslib::card_body(
        class = "py-2",
        # Stats display - compact
        uiOutput(ns("stats_display")),

        # Filters row - compact spacing
        fluidRow(
          style = "margin-top: 8px;",
          column(3,
            selectInput(ns("filter_status"), "Status",
                       choices = c("All", "Listed", "Active", "Scheduled", "Sold", "Ended",
                                 "Completed", "Terminated", "Cancelled", "Draft", "Error"),
                       selected = "All")
          ),
          column(3,
            selectInput(ns("filter_type"), "Type",
                       choices = c("All", "Postcard", "Stamp"),
                       selected = "All")
          ),
          column(3,
            selectInput(ns("filter_format"), "Format",
                       choices = c("All", "Fixed Price", "Auction"),
                       selected = "All")
          ),
          column(3,
            textInput(ns("search_text"), "Search",
                     placeholder = "Search title or SKU...")
          )
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
mod_ebay_listings_server <- function(id, ebay_api, session_id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Database connection helper
    get_db <- function() {
      DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    }

    # Reactive: Load listings from database
    listings_data <- reactiveVal(NULL)
    last_refresh_time <- reactiveVal(NULL)

    # Load initial data
    observe({
      req(session_id())

      con <- get_db()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      data <- get_all_ebay_listings(con)
      listings_data(data)
    })

    # Refresh all listings from eBay API
    observeEvent(input$refresh_all, {
      req(session_id(), ebay_api())

      con <- get_db()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      # Get eBay user ID
      ebay_user_id <- get_ebay_user_id_from_session(con, session_id())

      if (is.null(ebay_user_id)) {
        showNotification("Unable to determine eBay user ID", type = "error")
        return()
      }

      # Check rate limit
      if (!can_sync_listings(con, ebay_user_id, min_interval_minutes = 15)) {
        showNotification(
          "Please wait 15 minutes between full refreshes to avoid rate limits.",
          type = "warning",
          duration = 5
        )
        return()
      }

      # Show progress
      showNotification("Syncing listings from eBay...", id = "sync_progress", duration = NULL)

      # Start sync
      sync_id <- log_sync_start(con, ebay_user_id)

      tryCatch({
        # Get Trading API object
        trading_api <- ebay_api()$trading

        if (is.null(trading_api)) {
          stop("Trading API not initialized")
        }

        # Fetch from eBay (last 90 days)
        ebay_data <- fetch_seller_listings(
          trading_api,
          start_date = Sys.Date() - 90,
          end_date = Sys.Date()
        )

        # Update cache
        if (length(ebay_data$items) > 0) {
          cat("📥 Syncing", length(ebay_data$items), "items from eBay\n")
          update_listings_cache(con, ebay_data$items)

          # Debug: Show first item details
          if (length(ebay_data$items) > 0) {
            first_item <- ebay_data$items[[1]]
            cat("   First item: ID =", first_item$ItemID, "Title =", first_item$Title, "\n")
          }
        } else {
          cat("⚠️  No items returned from eBay API\n")
        }

        # Log success
        log_sync_complete(con, sync_id, length(ebay_data$items), api_calls = 1)

        # Reload data
        data <- get_all_ebay_listings(con)
        cat("📊 Database now has", nrow(data), "total listings\n")
        listings_data(data)
        last_refresh_time(Sys.time())

        # Remove progress notification
        removeNotification("sync_progress")

        showNotification(
          sprintf("Successfully synced %d listings from eBay", length(ebay_data$items)),
          type = "message",
          duration = 3
        )

      }, error = function(e) {
        # Log error
        log_sync_error(con, sync_id, e$message)

        # Remove progress notification
        removeNotification("sync_progress")

        showNotification(
          paste("Error syncing:", e$message),
          type = "error",
          duration = 10
        )
      })
    })

    # Filtered data based on user selections
    filtered_data <- reactive({
      req(listings_data())
      data <- listings_data()

      if (nrow(data) == 0) return(data)

      # Apply status filter
      if (input$filter_status != "All") {
        data <- data[data$status == tolower(input$filter_status), ]
      }

      # Apply type filter
      if (input$filter_type != "All") {
        data <- data[data$item_type == input$filter_type, ]
      }

      # Apply format filter
      if (input$filter_format != "All") {
        format_value <- ifelse(input$filter_format == "Fixed Price", "fixed_price", "auction")
        data <- data[data$listing_type == format_value, ]
      }

      # Apply search filter
      if (!is.null(input$search_text) && nzchar(input$search_text)) {
        search_pattern <- tolower(input$search_text)
        matches <- grepl(search_pattern, tolower(data$title)) |
                  grepl(search_pattern, tolower(data$sku))
        data <- data[matches, ]
      }

      return(data)
    })

    # Render stats display
    output$stats_display <- renderUI({
      req(listings_data())
      data <- listings_data()

      if (nrow(data) == 0) {
        return(tags$div(
          style = "font-size: 14px; color: #6c757d;",
          "No listings found"
        ))
      }

      total <- nrow(data)
      active <- sum(data$status == "listed", na.rm = TRUE)
      sold <- sum(data$status == "sold", na.rm = TRUE)
      scheduled <- sum(data$status == "scheduled", na.rm = TRUE)

      # Last refresh info
      refresh_info <- if (!is.null(last_refresh_time())) {
        time_ago <- as.numeric(difftime(Sys.time(), last_refresh_time(), units = "mins"))
        if (time_ago < 1) {
          "just now"
        } else if (time_ago < 60) {
          paste(round(time_ago), "minutes ago")
        } else {
          paste(round(time_ago / 60, 1), "hours ago")
        }
      } else {
        "not synced yet"
      }

      tags$div(
        style = "font-size: 14px; line-height: 1.2;",
        fluidRow(
          column(9,
            tags$span(class = "me-3", icon("list"), strong(" Total:"), total),
            tags$span(class = "me-3", icon("check-circle", class = "text-success"),
                     strong(" Active:"), active),
            tags$span(class = "me-3", icon("dollar-sign", class = "text-primary"),
                     strong(" Sold:"), sold),
            tags$span(icon("clock", class = "text-warning"),
                     strong(" Scheduled:"), scheduled)
          ),
          column(3, class = "text-end text-muted",
            tags$small(style = "font-size: 12px;", icon("sync"), " Last sync:", refresh_info)
          )
        )
      )
    })

    # Render datatable
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

      # Prepare display data
      display_data <- data.frame(
        Type = ifelse(data$item_type == "Postcard", "📮 Card", "📬 Stamp"),
        Title = substr(data$title, 1, 60),
        Price = sprintf("$%.2f", data$price),
        Status = sapply(data$status, render_status_badge),
        Format = ifelse(data$listing_type == "fixed_price", "Fixed", "Auction"),
        Views = ifelse(is.na(data$view_count), "-", as.character(data$view_count)),
        Watchers = ifelse(is.na(data$watch_count), "-", as.character(data$watch_count)),
        Bids = ifelse(is.na(data$bid_count) | data$bid_count == 0, "-", as.character(data$bid_count)),
        TimeLeft = ifelse(is.na(data$time_remaining), "-",
                         sapply(data$time_remaining, format_time_remaining)),
        Listed = ifelse(is.na(data$listed_at), "-",
                       format(as.Date(data$listed_at), "%b %d")),
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
          order = list(list(9, "desc")),  # Sort by Listed date descending
          dom = "Blfrtip",
          buttons = c("copy", "csv", "excel"),
          scrollX = TRUE,
          columnDefs = list(
            list(width = "50px", targets = 0),   # Type
            list(width = "300px", targets = 1),  # Title
            list(width = "80px", targets = 2),   # Price
            list(width = "100px", targets = 3),  # Status
            list(width = "80px", targets = 4),   # Format
            list(width = "60px", targets = 5:7), # Views, Watchers, Bids
            list(width = "80px", targets = 8),   # TimeLeft
            list(width = "80px", targets = 9)    # Listed
          )
        ),
        extensions = "Buttons"
      )
    })
  })
}
