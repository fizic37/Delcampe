#' Settings Module UI - SIMPLE CLEAN VERSION
#'
#' @description Simplified UI for LLM configuration
#' @import shiny
#' @import bslib
#' @noRd

# Render the simple LLM configuration UI (for Settings tab)
render_llm_config_ui_simple <- function(ns) {
  div(
    # Header with status
    div(
      style = "margin-bottom: 30px;",
      div(
        style = "display: flex; justify-content: space-between; align-items: center; padding: 20px; background: linear-gradient(135deg, #40916C 0%, #52B788 100%); border-radius: 12px; color: white;",
        div(
          h3("AI Model Configuration", style = "margin: 0; font-weight: 600;"),
          p("Configure which AI models to use for postal card analysis", style = "margin: 5px 0 0 0; opacity: 0.9; font-size: 14px;")
        ),
        uiOutput(ns("config_status_badge"))
      )
    ),
    
    # Main Configuration Area
    fluidRow(
      # Left Column - Model Selection & Parameters
      column(
        width = 6,
        
        # Model Selection Card
        bslib::card(
          style = "margin-bottom: 20px;",
          header = bslib::card_header(
            div(
              icon("brain", style = "margin-right: 8px;"),
              "Default Model Selection"
            ),
            style = "background-color: #40916C; color: white;"
          ),
          
          div(
            style = "padding: 25px;",
            
            p(
              "This model will be pre-selected in export dialogs. You can still choose a different model each time.",
              style = "color: #6c757d; margin-bottom: 20px; font-size: 14px;"
            ),
            
            # Current model display
            div(
              style = "margin-bottom: 15px; padding: 15px; background-color: #f8f9fa; border-radius: 8px; border-left: 4px solid #40916C;",
              div(
                style = "font-size: 12px; color: #6c757d; margin-bottom: 5px;",
                "CURRENT DEFAULT:"
              ),
              uiOutput(ns("current_model_display"))
            ),
            
            # Model selector
            selectInput(
              ns("default_model"),
              "Select Default Model:",
              choices = list(
                "Anthropic" = list(
                  "Claude Sonnet 4.5 (Recommended)" = "claude-sonnet-4.5-20250929",
                  "Claude Sonnet 4" = "claude-sonnet-4-20250514",
                  "Claude Opus 4.1 (Most Capable)" = "claude-opus-4.1-20250514",
                  "Claude Opus 4" = "claude-opus-4-20250514"
                ),
                "OpenAI" = list(
                  "GPT-4o (Fast)" = "gpt-4o",
                  "GPT-4o Mini (Economical)" = "gpt-4o-mini",
                  "GPT-4 Turbo" = "gpt-4-turbo"
                )
              ),
              selected = "claude-sonnet-4.5-20250929",
              width = "100%"
            ),
            
            div(
              style = "margin-top: 15px; padding: 12px; background-color: #e7f3ff; border-radius: 6px; border-left: 3px solid #0066cc;",
              div(
                style = "display: flex; align-items: start;",
                icon("lightbulb", style = "color: #0066cc; margin-right: 8px; margin-top: 2px;"),
                div(
                  tags$small(
                    tags$strong("Tip:"), " Claude models excel at detailed descriptions. GPT-4o is faster for bulk processing.",
                    style = "color: #004080; line-height: 1.5;"
                  )
                )
              )
            )
          )
        ),
        
        # Parameters Card
        bslib::card(
          header = bslib::card_header(
            div(
              icon("sliders-h", style = "margin-right: 8px;"),
              "Model Parameters"
            ),
            style = "background-color: #6c757d; color: white;"
          ),
          
          div(
            style = "padding: 25px;",
            
            # Temperature
            div(
              style = "margin-bottom: 25px;",
              tags$label(
                "Temperature",
                style = "font-weight: 600; color: #495057; display: block; margin-bottom: 8px;"
              ),
              numericInput(
                ns("temperature"),
                label = NULL,
                value = 0.7,
                min = 0.0,
                max = 1.0,
                step = 0.1,
                width = "100%"
              ),
              tags$small(
                "0.0 = Focused | 1.0 = Creative",
                style = "color: #6c757d; font-style: italic;"
              )
            ),
            
            # Max Tokens
            div(
              tags$label(
                "Maximum Response Length",
                style = "font-weight: 600; color: #495057; display: block; margin-bottom: 8px;"
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
                "Recommended: 1000 tokens (~750 words)",
                style = "color: #6c757d; font-style: italic;"
              )
            )
          )
        )
      ),
      
      # Right Column - API Keys
      column(
        width = 6,
        
        bslib::card(
          height = "100%",
          header = bslib::card_header(
            div(
              icon("key", style = "margin-right: 8px;"),
              "API Keys"
            ),
            style = "background-color: #ffc107; color: #000;"
          ),
          
          div(
            style = "padding: 25px;",
            
            p(
              "Enter your API keys to enable AI descriptions. Keys are stored securely.",
              style = "color: #6c757d; margin-bottom: 25px; font-size: 14px;"
            ),
            
            # Claude API Key
            div(
              style = "margin-bottom: 30px;",
              div(
                style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;",
                tags$label(
                  "Claude API Key",
                  style = "font-weight: 600; color: #495057; margin: 0;"
                ),
                uiOutput(ns("claude_status"))
              ),
              textInput(
                ns("claude_api_key"),
                label = NULL,
                placeholder = "sk-ant-api03-...",
                value = "",
                width = "100%"
              ),
              tags$small(
                HTML("Get your key at <a href='https://console.anthropic.com/' target='_blank'>console.anthropic.com</a>"),
                style = "color: #6c757d;"
              )
            ),
            
            # OpenAI API Key
            div(
              style = "margin-bottom: 30px;",
              div(
                style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;",
                tags$label(
                  "OpenAI API Key",
                  style = "font-weight: 600; color: #495057; margin: 0;"
                ),
                uiOutput(ns("openai_status"))
              ),
              textInput(
                ns("openai_api_key"),
                label = NULL,
                placeholder = "sk-...",
                value = "",
                width = "100%"
              ),
              tags$small(
                HTML("Get your key at <a href='https://platform.openai.com/api-keys' target='_blank'>platform.openai.com</a>"),
                style = "color: #6c757d;"
              )
            ),
            
            # .Renviron info
            div(
              style = "padding: 15px; background-color: #f8f9fa; border-radius: 8px; border-left: 3px solid #17a2b8;",
              div(
                style = "display: flex; align-items: start;",
                icon("info-circle", style = "color: #17a2b8; margin-right: 10px; margin-top: 2px;"),
                div(
                  tags$small(
                    tags$strong("Note:"), " If you see '✅ Loaded from .Renviron', your keys are already configured via .Renviron file.",
                    style = "color: #495057; line-height: 1.6;"
                  )
                )
              )
            )
          )
        )
      )
    ),
    
    # Save Button
    div(
      style = "margin-top: 30px; text-align: center; padding: 30px; background-color: #f8f9fa; border-radius: 12px;",
      actionButton(
        ns("save_llm_config"),
        "Save Configuration",
        icon = icon("save"),
        class = "btn-lg",
        style = "padding: 15px 50px; font-size: 18px; font-weight: 600; background: linear-gradient(135deg, #40916C 0%, #52B788 100%); border: none; color: white; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);"
      ),
      div(
        style = "margin-top: 15px; color: #6c757d; font-size: 13px;",
        "Your settings will be saved and used in all export dialogs"
      )
    ),
    
    # Alerts
    div(
      style = "margin-top: 20px;",
      uiOutput(ns("llm_alerts"))
    )
  )
}
