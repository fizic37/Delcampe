#' The application User-Interface - FIXED VERSION with Combined Images on Top
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd

app_ui <- function(request) {
  tagList(
    # Leave this function for adding external resources
    golem_add_external_resources(),
    
    # Initialize shinyjs
    shinyjs::useShinyjs(),
    
    # Main application UI using Bootstrap navigation
    bslib::page_navbar(
      title = "Delcampe Postal Card Processor",
      theme = bslib::bs_theme(version = 5, bootswatch = "flatly"),

      # FIXED: Single Stamps Tab with proper UI layout
      bslib::nav_panel(
        "Stamps",
        icon = icon("images"),
        
        # FIXED: Combined image output display section MOVED TO TOP
        fluidRow(
          column(
            width = 12,
            # This is where the combined image output will be displayed
            uiOutput("combined_image_output_display")
          )
        ),
        
        # Face and Verso processing in two columns
        fluidRow(
          style = "margin-top: 20px;",
          # Face Processing Section
          column(
            width = 6,
            class = "face-column",
            bslib::card(
              header = bslib::card_header(
                "Face Processing",
                style = "background-color: #52B788; color: white;"
              ),
              class = "stamps-processing-card",
              style = "min-height: 600px;",
              mod_postal_card_processor_ui("face_processor", card_type = "face")
            )
          ),
          
          # Verso Processing Section  
          column(
            width = 6,
            class = "verso-column",
            bslib::card(
              header = bslib::card_header(
                "Verso Processing", 
                style = "background-color: #40916C; color: white;"
              ),
              class = "stamps-processing-card",
              style = "min-height: 600px;",
              mod_postal_card_processor_ui("verso_processor", card_type = "verso")
            )
          )
        ),

        # Combined Results Section (shown after processing)
        fluidRow(
          style = "margin-top: 20px;",
          column(
            width = 12,
            uiOutput("combined_results_section")
          )
        )
      ),

      # Settings Tab with Tracking Integration
      bslib::nav_panel(
        "Settings",
        icon = icon("cog"),
        
        # Settings content with integrated tracking
        bslib::navset_card_tab(
          bslib::nav_panel(
            title = "General",
            mod_settings_ui("settings")
          ),
          bslib::nav_panel(
            title = "Tracking",
            # Tracking module integrated into settings
            mod_tracking_viewer_ui("tracking_viewer_1")
          )
        )
      ),

      # Navigation menu items
      bslib::nav_spacer(),

      bslib::nav_menu(
        "Help",
        icon = icon("question-circle"),
        bslib::nav_item(
          tags$a("Documentation", href = "#", class = "nav-link")
        ),
        bslib::nav_item(
          tags$a("Support", href = "#", class = "nav-link")
        )
      )
    )
  )
}

#' Add external Resources to the Application
#'
#' This function is internally used to add external
#' resources inside the Shiny application.
#'
#' @import shiny
#' @importFrom golem add_resource_path activate_js favicon bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path("www", app_sys("app/www"))

  # Add content-based data directories for image serving
  add_resource_path("data", file.path("inst", "app", "data"))

  tags$head(
    favicon(),
    bundle_resources(
      path = app_sys("app/www"),
      app_title = "Delcampe App"
    ),
    # Enhanced CSS for vertical layout
    tags$style(HTML("
      /* Enhanced card styling for the new vertical layout */
      .stamps-processing-card {
        border: 2px solid #e9ecef;
        border-radius: 10px;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        transition: box-shadow 0.3s ease;
      }
      
      .stamps-processing-card:hover {
        box-shadow: 0 6px 12px rgba(0, 0, 0, 0.15);
      }
      
      /* Better visual separation between face and verso columns */
      .face-column {
        border-right: 2px solid #f8f9fa;
        padding-right: 15px;
      }
      
      .verso-column {
        padding-left: 15px;
      }
      
      /* Enhanced processing status indicators */
      .processing-status {
        padding: 15px;
        border-radius: 8px;
        margin: 10px 0;
        text-align: center;
        font-weight: 500;
      }
      
      .processing-status.ready {
        background-color: #d1ecf1;
        border: 1px solid #b6d4fe;
        color: #0c5460;
      }
      
      .processing-status.complete {
        background-color: #d4edda;
        border: 1px solid #c3e6cb;
        color: #155724;
      }
      
      .processing-status.warning {
        background-color: #fff3cd;
        border: 1px solid #ffeaa7;
        color: #856404;
      }
      
      /* Combined image output styling - IMPROVED for top placement */
      .combined-output-card {
        border: 2px solid #e9ecef;
        border-radius: 10px;
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.08);
        margin-bottom: 15px; /* Reduced from 20px */
      }
      
      /* Compact status card - minimal height */
      .compact-status-card {
        max-height: 100px;
      }
      
      .compact-status-card .card-body {
        padding: 0 !important;
      }
      
      .combined-images-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
        gap: 15px;
        padding: 15px;
      }
      
      .combined-image-item {
        text-align: center;
        background-color: #f8f9fa;
        border: 1px solid #dee2e6;
        border-radius: 8px;
        padding: 10px;
      }
      
      .combined-image-item img {
        max-width: 100%;
        max-height: 150px;
        object-fit: contain;
        border-radius: 5px;
        border: 1px solid #dee2e6;
      }
    ")),
    # FIXED: Include draggable lines CSS and JavaScript with correct Golem paths
    tags$link(rel = "stylesheet", type = "text/css", href = "styles.css"),
    tags$script(src = "draggable_lines.js")
  )
}
