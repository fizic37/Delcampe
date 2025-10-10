#' Settings Module - FIXED VERSION
#'
#' @description UI and server logic for application settings with enhanced layout and real-time configuration display
#' @import shiny
#' @import bslib
#' @import DT
#' @export

# Settings Module UI
mod_settings_ui <- function(id) {
  ns <- NS(id)
  
  # This will be populated dynamically based on user role in the server
  uiOutput(ns("settings_content"))
}

# Helper function to render admin UI with improved layout
render_admin_ui <- function(ns) {
  bslib::page_fillable(
    padding = 20,
    
    bslib::navset_card_tab(
      height = "700px",
      
      # Tracking Tab
      bslib::nav_panel(
        title = "Tracking",
        icon = icon("chart-line"),
        mod_tracking_viewer_ui("tracking_viewer_1")
      ),
      
      # User Management Tab
      bslib::nav_panel(
        title = "User Management",
        icon = icon("users"),
        
        fluidRow(
          # Full width - User List with action buttons
          column(
            width = 12,
            bslib::card(
              class = "settings-panel",
              header = bslib::card_header(
                "User Accounts"
              ),
              
              # Action buttons - moved before table
              div(
                style = "margin-bottom: 15px; display: flex; justify-content: space-between; align-items: center;",
                div(
                  actionButton(
                    ns("create_user_btn"),
                    "Create User",
                    icon = icon("user-plus"),
                    class = "btn-success btn-sm",
                    style = "margin-right: 10px;"
                  ),
                  actionButton(
                    ns("update_user_btn"),
                    "Update User",
                    icon = icon("user-edit"),
                    class = "btn-warning btn-sm",
                    style = "margin-right: 10px;"
                  )
                ),
                actionButton(
                  ns("refresh_users"),
                  "Refresh",
                  icon = icon("sync"),
                  class = "btn-outline-secondary btn-sm"
                )
              ),
              
              # User table
              DT::DTOutput(ns("users_table"))
            )
          )
        ),
        
        # Alerts
        div(
          style = "margin-top: 20px;",
          uiOutput(ns("user_alerts"))
        )
      ),
      
      # LLM Configuration Tab - FIXED VERSION
      bslib::nav_panel(
        title = "LLM Models",
        icon = icon("robot"),
        
        # Configuration display header with current settings
        fluidRow(
          column(
            width = 12,
            div(
              style = "margin-bottom: 20px; padding: 15px; background: linear-gradient(135deg, #40916C 0%, #52B788 100%); border-radius: 12px; color: white;",
              div(
                style = "display: flex; justify-content: space-between; align-items: center;",
                div(
                  h4("LLM Configuration", style = "margin: 0; font-weight: 600;"),
                  p("Configure AI models for postal card analysis", style = "margin: 5px 0 0 0; opacity: 0.9;")
                ),
                div(
                  style = "text-align: right;",
                  uiOutput(ns("quick_config_display"))
                )
              )
            )
          )
        ),
        
        # Main configuration grid - FIXED LAYOUT
        fluidRow(
          # Model & Parameters Column
          column(
            width = 4,
            bslib::card(
              class = "settings-panel h-100",
              header = bslib::card_header(
                div(
                  style = "display: flex; align-items: center;",
                  icon("cog", style = "color: #40916C; margin-right: 8px;"),
                  "Model & Parameters"
                )
              ),
              
              div(
                style = "padding: 20px;",
                
                # Model Selection with current indication
                div(
                  style = "margin-bottom: 25px;",
                  div(
                    style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;",
                    tags$label("Default Model", style = "font-weight: 600; color: #495057;"),
                    uiOutput(ns("current_model_badge"))
                  ),
                  selectInput(
                    ns("default_model"),
                    label = NULL,
                    choices = list(
                      "Anthropic" = list(
                        "Claude Sonnet 4.5 (Recommended)" = "claude-sonnet-4-5-20250929",
                        "Claude Sonnet 4" = "claude-sonnet-4-20250514",
                        "Claude Opus 4.1 (Most Capable)" = "claude-opus-4-1-20250514",
                        "Claude Opus 4" = "claude-opus-4-20250514"
                      ),
                      "OpenAI" = list(
                        "GPT-4o (Fast)" = "gpt-4o",
                        "GPT-4o Mini (Economical)" = "gpt-4o-mini",
                        "GPT-4 Turbo" = "gpt-4-turbo"
                      )
                    ),
                    selected = "claude-sonnet-4-5-20250929"
                  )
                ),
                
                # Temperature setting with real-time display
                div(
                  style = "margin-bottom: 25px;",
                  div(
                    style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;",
                    tags$label("Temperature", style = "font-weight: 600; color: #495057;"),
                    uiOutput(ns("current_temp_display"))
                  ),
                  numericInput(
                    ns("temperature"),
                    label = NULL,
                    value = 0,  # Changed default to 0
                    min = 0.0,
                    max = 1.0,
                    step = 0.1,
                    width = "100%"
                  ),
                  tags$small(
                    "Higher values = more random, lower values = more focused",
                    style = "color: #6c757d; font-style: italic;"
                  )
                ),
                
                # Max tokens setting with real-time display
                div(
                  style = "margin-bottom: 25px;",
                  div(
                    style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;",
                    tags$label("Max Tokens", style = "font-weight: 600; color: #495057;"),
                    uiOutput(ns("current_tokens_display"))
                  ),
                  numericInput(
                    ns("max_tokens"),
                    label = NULL,
                    value = 1000,
                    min = 100,
                    max = 4000,
                    step = 100,
                    width = "100%"
                  ),
                  tags$small(
                    "Maximum response length in tokens",
                    style = "color: #6c757d; font-style: italic;"
                  )
                )
              )
            )
          ),
          
          # API Keys Column
          column(
            width = 4,
            bslib::card(
              class = "settings-panel h-100",
              header = bslib::card_header(
                div(
                  style = "display: flex; align-items: center;",
                  icon("key", style = "color: #40916C; margin-right: 8px;"),
                  "API Keys"
                )
              ),
              
              div(
                style = "padding: 20px;",
                
                # Claude API Key with status indicator
                div(
                  style = "margin-bottom: 25px;",
                  div(
                    style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;",
                    tags$label("Claude API Key", style = "font-weight: 600; color: #495057;"),
                    uiOutput(ns("claude_key_status"))
                  ),
                  textInput(
                    ns("claude_api_key"),
                    label = NULL,
                    placeholder = "sk-ant-...",
                    value = "",
                    width = "100%"
                  )
                ),
                
                # OpenAI API Key with status indicator
                div(
                  style = "margin-bottom: 25px;",
                  div(
                    style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;",
                    tags$label("OpenAI API Key", style = "font-weight: 600; color: #495057;"),
                    uiOutput(ns("openai_key_status"))
                  ),
                  textInput(
                    ns("openai_api_key"),
                    label = NULL,
                    placeholder = "sk-...",
                    value = "",
                    width = "100%"
                  )
                ),
                
                # Security note
                div(
                  style = "margin-top: 20px; padding: 10px; background-color: #f8f9fa; border-radius: 6px; border-left: 3px solid #28a745;",
                  div(
                    style = "display: flex; align-items: start;",
                    icon("lock", style = "color: #28a745; margin-right: 8px; margin-top: 2px;"),
                    div(
                      tags$small(
                        tags$strong("Secure Storage:"), br(),
                        "• API keys are stored locally in data/llm_config.rds", br(),
                        "• Keys are never sent to external servers", br(),
                        "• Only displayed as truncated values after saving",
                        style = "color: #495057;"
                      )
                    )
                  )
                )
              )
            )
          ),
          
          # Status & Testing Column
          column(
            width = 4,
            bslib::card(
              class = "settings-panel h-100",
              header = bslib::card_header(
                div(
                  style = "display: flex; align-items: center;",
                  icon("heartbeat", style = "color: #40916C; margin-right: 8px;"),
                  "Status & Testing"
                )
              ),
              
              div(
                style = "padding: 20px;",
                
                # Current Configuration Summary
                div(
                  style = "margin-bottom: 25px; padding: 15px; background-color: #f8f9fa; border-radius: 8px;",
                  h6("Active Configuration", style = "margin-bottom: 10px; color: #495057; font-weight: 600;"),
                  uiOutput(ns("config_summary"))
                ),
                
                # Service Status
                div(
                  style = "margin-bottom: 25px;",
                  h6("Service Status", style = "margin-bottom: 15px; color: #495057; font-weight: 600;"),
                  
                  # Claude Status
                  div(
                    style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; padding: 8px; background-color: #fff; border-radius: 6px; border: 1px solid #dee2e6;",
                    div(
                      style = "display: flex; align-items: center;",
                      span("Claude", style = "font-weight: 500; margin-right: 10px;"),
                      uiOutput(ns("claude_status_icon"))
                    ),
                    actionButton(
                      ns("test_claude"),
                      "Test",
                      icon = icon("vial"),
                      class = "btn-outline-primary btn-xs",
                      style = "font-size: 11px; padding: 2px 8px;"
                    )
                  ),
                  
                  # OpenAI Status
                  div(
                    style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; padding: 8px; background-color: #fff; border-radius: 6px; border: 1px solid #dee2e6;",
                    div(
                      style = "display: flex; align-items: center;",
                      span("OpenAI", style = "font-weight: 500; margin-right: 10px;"),
                      uiOutput(ns("openai_status_icon"))
                    ),
                    actionButton(
                      ns("test_openai"),
                      "Test",
                      icon = icon("vial"),
                      class = "btn-outline-primary btn-xs",
                      style = "font-size: 11px; padding: 2px 8px;"
                    )
                  )
                )
              )
            )
          )
        ),
        
        # Save Button Row
        fluidRow(
          style = "margin-top: 20px;",
          column(
            width = 12,
            div(
              style = "text-align: center; padding: 20px;",
              actionButton(
                ns("save_llm_config"),
                "Save Configuration",
                icon = icon("save"),
                class = "btn-success btn-lg",
                style = "padding: 12px 40px; font-size: 16px; font-weight: 600; background: linear-gradient(135deg, #40916C 0%, #52B788 100%); border: none; border-radius: 8px;"
              )
            )
          )
        ),
        
        # LLM Alerts
        div(
          style = "margin-top: 20px;",
          uiOutput(ns("llm_alerts"))
        )
      )
    )
  )
}

# Helper function to render regular user UI (password change only)
render_user_ui <- function(ns) {
  bslib::page_fillable(
    padding = 20,
    
    bslib::card(
      class = "settings-panel",
      header = bslib::card_header(
        "Account Settings"
      ),
      
      div(
        style = "padding: 30px; text-align: center;",
        
        div(
          style = "margin-bottom: 30px;",
          icon("user-circle", style = "font-size: 60px; color: var(--mint-primary); margin-bottom: 20px;"),
          h4("My Account", style = "color: #495057; margin-bottom: 10px;"),
          p("You can change your password here", style = "color: #6c757d;")
        ),
        
        div(
          style = "max-width: 400px; margin: 0 auto;",
          
          actionButton(
            ns("change_password_btn"),
            "Change Password",
            icon = icon("key"),
            class = "btn-success",
            style = "width: 100%; padding: 15px; font-size: 16px; font-weight: 600;"
          )
        ),
        
        # User alerts
        div(
          style = "margin-top: 30px;",
          uiOutput(ns("user_alerts"))
        )
      )
    )
  )
}

# Helper function to safely get model name
get_model_display_name <- function(model_id) {
  model_names <- list(
    "claude-sonnet-4-5-20250929" = "Claude Sonnet 4.5",
    "claude-sonnet-4-20250514" = "Claude Sonnet 4",
    "claude-opus-4-1-20250514" = "Claude Opus 4.1",
    "claude-opus-4-20250514" = "Claude Opus 4",
    "gpt-4o" = "GPT-4o",
    "gpt-4o-mini" = "GPT-4o Mini",
    "gpt-4-turbo" = "GPT-4 Turbo",
    "gpt-4" = "GPT-4"
  )
  
  # Safely get model name with fallback
  if (is.null(model_id) || !is.character(model_id) || length(model_id) == 0) {
    return("Unknown Model")
  }
  
  if (model_id %in% names(model_names)) {
    return(model_names[[model_id]])
  } else {
    return(model_id)
  }
}
