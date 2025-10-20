#' Enhanced Tracking Viewer UI
#'
#' @description Shows processing history with DT::datatable, filters, and search
#'
#' @param id Module ID
#' @export
#' @importFrom shiny NS tagList
#' @importFrom DT dataTableOutput
mod_tracking_viewer_ui <- function(id) {
  ns <- NS(id)

  tagList(
    bslib::card(
      header = bslib::card_header(
        "Processing History",
        class = "bg-primary text-white"
      ),

      # Filter controls
      div(
        style = "padding: 15px; background: #f8f9fa; border-bottom: 1px solid #dee2e6;",
        div(
          style = "display: flex; gap: 15px; align-items: end;",
          div(
            style = "flex: 1;",
            selectInput(
              ns("date_range"),
              "Date Range:",
              choices = c(
                "Last 7 days" = "7",
                "Last 30 days" = "30",
                "Last 90 days" = "90",
                "Last 6 months" = "180",
                "Last year" = "365",
                "All time" = "all"
              ),
              selected = "7"
            )
          ),
          div(
            style = "flex: 1;",
            selectInput(
              ns("ebay_filter"),
              "eBay Status:",
              choices = c(
                "All" = "all",
                "Listed" = "listed",
                "Draft" = "draft",
                "Failed" = "failed",
                "Pending" = "pending",
                "Not Posted" = "none"
              ),
              selected = "all"
            )
          )
        )
      ),

      # DataTable
      div(
        style = "padding: 20px;",
        DT::dataTableOutput(ns("tracking_table"))
      )
    )
  )
}

#' Enhanced Tracking Viewer Server
#'
#' @description Server logic for tracking viewer with DT::datatable
#'
#' @param id Module ID
#' @export
#' @importFrom DT renderDataTable datatable
mod_tracking_viewer_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive: fetch filtered session data
    tracking_data <- reactive({
      # Get date filter
      days_back <- input$date_range
      date_filter <- if (days_back == "all") {
        ""
      } else {
        # Validate input to prevent SQL injection
        days <- as.integer(days_back)
        if (is.na(days)) days <- 7  # Fallback to default
        sprintf("AND sa.timestamp >= datetime('now', '-%d days')", days)
      }

      # Get eBay filter
      ebay_status <- input$ebay_filter
      ebay_filter <- if (ebay_status == "all") {
        ""
      } else if (ebay_status == "none") {
        "AND (el.status IS NULL OR el.status = '')"
      } else {
        # Sanitize input (whitelist approach)
        allowed_statuses <- c("listed", "draft", "failed", "pending")
        if (ebay_status %in% allowed_statuses) {
          sprintf("AND el.status = '%s'", ebay_status)
        } else {
          ""  # Invalid status, show all
        }
      }

      # Query database for session-based data
      get_session_tracking_data(date_filter, ebay_filter)
    })

    # Render DataTable
    output$tracking_table <- DT::renderDataTable({
      data <- tracking_data()

      if (nrow(data) == 0) {
        # Empty state
        return(data.frame(
          Message = "No processing sessions found for selected filters. Try adjusting your filters or process some images first."
        ))
      }

      # Format data for display with factors for better filtering
      # Show session-level summary with image type indicators
      display_data <- data.frame(
        SessionID = as.character(data$session_id),
        Time = format(as.POSIXct(data$session_time), "%Y-%m-%d %H:%M"),
        User = ifelse(
          is.na(data$username) | data$username == "",
          "Unknown",
          as.character(data$username)
        ),
        Cards = as.integer(data$cards_processed),
        Images = sprintf("%s%s%s",
          ifelse(data$has_face > 0, "F", ""),
          ifelse(data$has_verso > 0, "V", ""),
          ifelse(data$has_combined > 0, "C", "")
        ),
        AIExtractions = as.integer(data$ai_extractions),
        EbayPosts = as.integer(data$ebay_posts),
        EbayStatus = ifelse(
          is.na(data$ebay_status) | data$ebay_status == "",
          "Not Posted",
          tools::toTitleCase(data$ebay_status)
        ),
        stringsAsFactors = FALSE
      )

      # Convert categorical columns to factors for better DT filtering
      display_data$User <- factor(display_data$User)
      display_data$Images <- factor(display_data$Images)
      display_data$EbayStatus <- factor(display_data$EbayStatus)

      dt <- DT::datatable(
        display_data,
        selection = "single",
        filter = "top",  # Add column filters at the top
        options = list(
          pageLength = 25,
          lengthMenu = c(10, 25, 50, 100),
          order = list(list(1, "desc")),  # Sort by Time descending
          autoWidth = TRUE,
          columnDefs = list(
            list(width = "100px", targets = 0),  # SessionID
            list(width = "140px", targets = 1),  # Time
            list(width = "100px", targets = 2),  # User
            list(width = "80px", targets = 3),   # Cards
            list(width = "80px", targets = 4),   # Images (F/V/C)
            list(width = "100px", targets = 5),  # AI Extractions
            list(width = "100px", targets = 6),  # eBay Posts
            list(width = "110px", targets = 7)   # EbayStatus
          ),
          language = list(
            search = "Search sessions:",
            lengthMenu = "Show _MENU_ sessions per page",
            info = "Showing _START_ to _END_ of _TOTAL_ processing sessions",
            infoEmpty = "No sessions to display",
            infoFiltered = "(filtered from _MAX_ total sessions)",
            zeroRecords = "No matching sessions found"
          )
        ),
        rownames = FALSE,
        class = "table table-striped table-hover"
      )

      # Add visual styling to EbayStatus column
      dt <- DT::formatStyle(
        dt,
        'EbayStatus',
        backgroundColor = DT::styleEqual(
          c('Listed', 'Draft', 'Failed', 'Pending', 'Not Posted'),
          c('#d1fcd3', '#fff3cd', '#f8d7da', '#cfe2ff', '#e9ecef')
        ),
        color = DT::styleEqual(
          c('Listed', 'Draft', 'Failed', 'Pending', 'Not Posted'),
          c('#0f5132', '#997404', '#842029', '#084298', '#6c757d')
        ),
        fontWeight = 'bold'
      )

      dt
    })

    # Handle row click - open session detail modal
    observeEvent(input$tracking_table_rows_selected, {
      selected_row <- input$tracking_table_rows_selected

      if (length(selected_row) > 0) {
        data <- tracking_data()
        if (nrow(data) > 0 && selected_row <= nrow(data)) {
          session_id <- data$session_id[selected_row]
          show_session_modal(session_id, data[selected_row, ])
        }
      }
    })

    # Modal builder - Show all session images grouped by type
    show_session_modal <- function(session_id, session_row) {
      # Get all cards for this session
      cards <- get_session_cards(session_id)

      if (nrow(cards) == 0) {
        content <- tagList(
          div(
            class = "alert alert-warning",
            "No card data found for this session."
          )
        )
      } else {
        # Helper function to extract web path from various formats
        get_web_path <- function(crop_paths_json, upload_path) {
          # Try crop first
          crop_paths <- tryCatch(
            jsonlite::fromJSON(crop_paths_json),
            error = function(e) NULL
          )

          if (!is.null(crop_paths) && length(crop_paths) > 0) {
            path <- crop_paths[1]
            if (grepl("Delcampe/", path)) {
              return(sub("^inst/app/", "", sub(".*Delcampe/", "", path)))
            } else if (grepl("^inst/app/", path)) {
              return(sub("^inst/app/", "", path))
            } else {
              return(path)
            }
          }

          # Fallback to upload_path
          if (!is.na(upload_path) && !is.null(upload_path) && upload_path != "") {
            if (grepl("^data/", upload_path)) {
              return(upload_path)
            } else if (grepl("Delcampe/", upload_path)) {
              return(sub("^inst/app/", "", sub(".*Delcampe/", "", upload_path)))
            } else if (grepl("^inst/app/", upload_path)) {
              return(sub("^inst/app/", "", upload_path))
            } else {
              return(upload_path)
            }
          }

          return(NULL)
        }

        # Helper function to create card display
        create_card_display <- function(card) {
          web_path <- get_web_path(card$crop_paths, card$upload_path)
          has_image <- !is.null(web_path)
          has_ai <- !is.na(card$ai_title) && !is.null(card$ai_title) && nchar(as.character(card$ai_title)) > 0

          tagList(
            div(
              style = "margin-bottom: 30px; padding: 15px; background: #f8f9fa; border-radius: 8px;",

              # Image type header
              h4(tools::toTitleCase(card$image_type), style = "margin-bottom: 15px; color: #495057;"),

              div(
                style = "display: grid; grid-template-columns: 1fr 1fr; gap: 20px;",

                # Left: Image
                div(
                  if (has_image) {
                    tags$img(
                      src = web_path,
                      style = "width: 100%; max-height: 300px; object-fit: contain; border: 2px solid #dee2e6; border-radius: 4px; background: white;",
                      alt = card$original_filename,
                      onerror = "this.style.display='none'; this.nextElementSibling.style.display='block';"
                    )
                  } else {
                    div(
                      style = "padding: 40px; text-align: center; color: #6c757d; border: 2px dashed #dee2e6; border-radius: 4px;",
                      tags$i(class = "bi bi-image", style = "font-size: 48px;"),
                      tags$p("Image not available", style = "margin-top: 10px;")
                    )
                  },
                  if (has_image) {
                    div(style = "display: none; padding: 40px; text-align: center; color: #6c757d;",
                        "Image failed to load")
                  }
                ),

                # Right: AI Extraction
                div(
                  if (has_ai) {
                    tagList(
                      h5("AI Extraction", style = "margin-bottom: 10px;"),
                      tags$table(
                        class = "table table-sm",
                        tags$tr(tags$th("Model:"), tags$td(card$ai_model)),
                        tags$tr(tags$th("Title:"), tags$td(card$ai_title)),
                        tags$tr(tags$th("Condition:"), tags$td(card$ai_condition)),
                        tags$tr(tags$th("Price:"), tags$td(sprintf("$%.2f", card$ai_price)))
                      ),
                      div(
                        style = "margin-top: 10px;",
                        h6("Description:"),
                        div(
                          style = "padding: 10px; background: white; border-radius: 4px; border: 1px solid #dee2e6; max-height: 150px; overflow-y: auto;",
                          p(card$ai_description, style = "margin: 0; font-size: 0.9em;")
                        )
                      )
                    )
                  } else {
                    div(
                      class = "alert alert-secondary",
                      style = "margin: 0;",
                      "No AI extraction available for this image"
                    )
                  }
                )
              )
            )
          )
        }

        # Build content: group cards by type
        content <- tagList(
          # Session info
          div(
            style = "margin-bottom: 20px; padding: 15px; background: #e9ecef; border-radius: 8px;",
            div(style = "display: flex; justify-content: space-between; align-items: center;",
                h5(sprintf("Session: %s", session_id), style = "margin: 0;"),
                span(sprintf("%s | %d cards processed",
                           format(as.POSIXct(session_row$session_time), "%Y-%m-%d %H:%M"),
                           session_row$cards_processed),
                     style = "color: #6c757d;")
            )
          ),

          # Display cards by type
          lapply(1:nrow(cards), function(i) {
            create_card_display(cards[i, ])
          })
        )
      }

      # Show modal
      showModal(
        modalDialog(
          title = sprintf("Session Details: %s", format(as.POSIXct(session_row$session_time), "%Y-%m-%d %H:%M")),
          content,
          size = "xl",
          easyClose = TRUE,
          footer = modalButton("Close")
        )
      )
    }
  })
}
