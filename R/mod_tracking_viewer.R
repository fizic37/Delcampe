#' tracking_viewer UI Function
#'
#' @description A shiny Module for viewing processing tracking data.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @export
#'
#' @importFrom shiny NS tagList 
mod_tracking_viewer_ui <- function(id) {
  ns <- NS(id)
  tagList(
    shinyjs::useShinyjs(),
    
    # Tracking overview cards
    fluidRow(
      column(
        width = 3,
        bslib::card(
          header = bslib::card_header(
            "Total Sessions",
            class = "settings-panel",
            style = "background-color: #52B788; color: white;"
          ),
          div(
            style = "text-align: center; padding: 20px;",
            h2(
              id = ns("total_sessions"),
              "0",
              style = "margin: 0; color: #52B788; font-weight: bold;"
            ),
            p("Processing Sessions", style = "margin: 5px 0 0 0; color: #6c757d; font-size: 14px;")
          )
        )
      ),
      column(
        width = 3,
        bslib::card(
          header = bslib::card_header(
            "Images Processed",
            class = "settings-panel",
            style = "background-color: #40916C; color: white;"
          ),
          div(
            style = "text-align: center; padding: 20px;",
            h2(
              id = ns("total_images"),
              "0",
              style = "margin: 0; color: #40916C; font-weight: bold;"
            ),
            p("Total Images", style = "margin: 5px 0 0 0; color: #6c757d; font-size: 14px;")
          )
        )
      ),
      column(
        width = 3,
        bslib::card(
          header = bslib::card_header(
            "Extractions",
            class = "settings-panel",
            style = "background-color: #E76F51; color: white;"
          ),
          div(
            style = "text-align: center; padding: 20px;",
            h2(
              id = ns("total_extractions"),
              "0",
              style = "margin: 0; color: #E76F51; font-weight: bold;"
            ),
            p("Completed", style = "margin: 5px 0 0 0; color: #6c757d; font-size: 14px;")
          )
        )
      ),
      column(
        width = 3,
        bslib::card(
          header = bslib::card_header(
            "Active Users",
            class = "settings-panel",
            style = "background-color: #F77F00; color: white;"
          ),
          div(
            style = "text-align: center; padding: 20px;",
            h2(
              id = ns("active_users"),
              "1",
              style = "margin: 0; color: #F77F00; font-weight: bold;"
            ),
            p("Current Session", style = "margin: 5px 0 0 0; color: #6c757d; font-size: 14px;")
          )
        )
      )
    ),
    
    # Controls row
    fluidRow(
      style = "margin-top: 20px; margin-bottom: 15px;",
      column(
        width = 6,
        div(
          style = "display: flex; align-items: center; gap: 15px;",
          selectInput(
            inputId = ns("time_filter"),
            label = "Time Period:",
            choices = list(
              "Last 24 Hours" = "24h",
              "Last Week" = "7d",
              "Last Month" = "30d",
              "All Time" = "all"
            ),
            selected = "7d",
            width = "150px"
          ),
          selectInput(
            inputId = ns("user_filter"),
            label = "User:",
            choices = list("All Users" = "all"),
            selected = "all",
            width = "150px"
          )
        )
      ),
      column(
        width = 6,
        div(
          style = "display: flex; justify-content: flex-end; align-items: end; gap: 10px; height: 100%;",
          actionButton(
            inputId = ns("refresh_data"),
            label = "Refresh",
            icon = icon("sync-alt"),
            class = "btn-outline-primary btn-sm",
            style = "margin-top: 32px;"
          ),
          actionButton(
            inputId = ns("export_data"),
            label = "Export CSV",
            icon = icon("download"),
            class = "btn-outline-success btn-sm",
            style = "margin-top: 32px;"
          )
        )
      )
    ),
    
    # Main tracking table
    bslib::card(
      header = bslib::card_header(
        "Processing Activity Log",
        class = "settings-panel",
        style = "background-color: #6c757d; color: white;"
      ),
      div(
        style = "padding: 15px;",
        DT::dataTableOutput(ns("tracking_table"))
      )
    )
  )
}

#' tracking_viewer Server Functions
#'
#' @export
mod_tracking_viewer_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # Reactive values for tracking data
    tracking_data <- reactiveValues(
      sessions = NULL,
      summary_stats = list(
        total_sessions = 0,
        total_images = 0,
        total_extractions = 0,
        active_users = 1
      )
    )
    
    # Load tracking functions
    observe({
      tryCatch({
        source("R/tracking_database.R")
      }, error = function(e) {
        message("Failed to load tracking database functions: ", e$message)
      })
    })
    
    # Fetch tracking data based on filters
    fetch_tracking_data <- reactive({
      tryCatch({
        # Default empty data structure
        default_data <- data.frame(
          session_id = character(0),
          user_id = character(0),
          start_time = character(0),
          activity_type = character(0),
          details = character(0),
          stringsAsFactors = FALSE
        )
        
        # Try to get actual data if tracking functions are available
        if (exists("get_tracking_sessions")) {
          time_filter <- input$time_filter %||% "7d"
          user_filter <- input$user_filter %||% "all"
          
          # Calculate time cutoff
          cutoff_time <- switch(time_filter,
            "24h" = Sys.time() - (24 * 60 * 60),
            "7d" = Sys.time() - (7 * 24 * 60 * 60),
            "30d" = Sys.time() - (30 * 24 * 60 * 60),
            "all" = as.POSIXct("1970-01-01")
          )
          
          sessions_data <- get_tracking_sessions(
            since = cutoff_time,
            user_filter = if (user_filter == "all") NULL else user_filter
          )
          
          if (!is.null(sessions_data) && nrow(sessions_data) > 0) {
            # Format the data for display
            sessions_data$start_time_formatted <- format(
              as.POSIXct(sessions_data$start_time), 
              "%Y-%m-%d %H:%M:%S"
            )
            
            # Calculate summary statistics
            tracking_data$summary_stats <- list(
              total_sessions = nrow(sessions_data),
              total_images = sum(grepl("image_upload|extraction", sessions_data$activity_type), na.rm = TRUE),
              total_extractions = sum(grepl("extraction", sessions_data$activity_type), na.rm = TRUE),
              active_users = length(unique(sessions_data$user_id))
            )
            
            return(sessions_data)
          }
        }
        
        return(default_data)
      }, error = function(e) {
        message("Error fetching tracking data: ", e$message)
        return(data.frame(
          session_id = character(0),
          user_id = character(0),
          start_time = character(0),
          activity_type = character(0),
          details = character(0),
          stringsAsFactors = FALSE
        ))
      })
    })
    
    # Update summary statistics display
    observe({
      stats <- tracking_data$summary_stats
      
      shinyjs::html("total_sessions", as.character(stats$total_sessions))
      shinyjs::html("total_images", as.character(stats$total_images))
      shinyjs::html("total_extractions", as.character(stats$total_extractions))
      shinyjs::html("active_users", as.character(stats$active_users))
    })
    
    # Render tracking table
    output$tracking_table <- DT::renderDataTable({
      data <- fetch_tracking_data()
      
      if (is.null(data) || nrow(data) == 0) {
        return(DT::datatable(
          data.frame(Message = "No tracking data available"),
          options = list(
            searching = FALSE,
            paging = FALSE,
            info = FALSE
          ),
          rownames = FALSE
        ))
      }
      
      # Prepare display data
      display_data <- data.frame(
        "Session ID" = substr(data$session_id, 1, 8),
        "User" = data$user_id,
        "Start Time" = data$start_time_formatted,
        "Activity" = data$activity_type,
        "Details" = ifelse(nchar(data$details) > 50, 
                          paste0(substr(data$details, 1, 50), "..."), 
                          data$details),
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      
      DT::datatable(
        display_data,
        options = list(
          pageLength = 15,
          scrollX = TRUE,
          order = list(list(2, 'desc')) # Sort by start time descending
        ),
        rownames = FALSE
      )
    })
    
    # Handle refresh button
    observeEvent(input$refresh_data, {
      # Force reactive to re-evaluate
      tracking_data$last_refresh <- Sys.time()
    })
    
    # Handle export button
    observeEvent(input$export_data, {
      data <- fetch_tracking_data()
      
      if (!is.null(data) && nrow(data) > 0) {
        showNotification("Export feature available in full version", type = "info")
      } else {
        showNotification("No data available to export.", type = "warning")
      }
    })
  })
}