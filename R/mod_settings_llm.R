#' Settings LLM Configuration Module - REDESIGNED SIMPLE VERSION
#'
#' @description Clean, simple server logic for LLM configuration
#' Properly integrated with modal dialog model selection
#'
#' @param id,input,output,session Internal parameters for {shiny}
#' @param current_user Reactive function returning current user information
#' @param alerts ReactiveValues object for managing alert messages
#'
#' @noRd
#' @import shiny
mod_settings_llm_server <- function(id, current_user, alerts) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    `%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || all(is.na(a))) b else a

    # LLM configuration reactive values
    llm_config <- reactiveValues(
      default_model = "claude-sonnet-4-5-20250929",
      temperature = 0.7,
      max_tokens = 1000,
      claude_api_key = "",
      openai_api_key = "",
      claude_configured = FALSE,
      openai_configured = FALSE
    )

    # Load existing configuration on module start
    observe({
      config_file <- "data/llm_config.rds"
      
      if (file.exists(config_file)) {
        tryCatch({
          config <- readRDS(config_file)
          
          # Update reactive values with safe checks
          if (!is.null(config$default_model) && is.character(config$default_model)) {
            llm_config$default_model <- config$default_model
            updateSelectInput(session, "default_model", selected = config$default_model)
          }
          if (!is.null(config$temperature) && is.numeric(config$temperature)) {
            llm_config$temperature <- config$temperature
            updateNumericInput(session, "temperature", value = config$temperature)
          }
          if (!is.null(config$max_tokens) && is.numeric(config$max_tokens)) {
            llm_config$max_tokens <- config$max_tokens
            updateNumericInput(session, "max_tokens", value = config$max_tokens)
          }
          
          # Handle Claude API key - load from file only
          if (!is.null(config$claude_api_key) && is.character(config$claude_api_key) && config$claude_api_key != "") {
            llm_config$claude_api_key <- config$claude_api_key
            display_key <- paste0(substr(config$claude_api_key, 1, 10), "...")
            updateTextInput(session, "claude_api_key", value = display_key)
            llm_config$claude_configured <- TRUE
          }
          
          # Handle OpenAI API key - load from file only
          if (!is.null(config$openai_api_key) && is.character(config$openai_api_key) && config$openai_api_key != "") {
            llm_config$openai_api_key <- config$openai_api_key
            display_key <- paste0(substr(config$openai_api_key, 1, 10), "...")
            updateTextInput(session, "openai_api_key", value = display_key)
            llm_config$openai_configured <- TRUE
          }
        }, error = function(e) {
          message("Error loading LLM config: ", e$message)
        })
      }
    })

    # ==== UI OUTPUTS ====

    # Status badge
    output$config_status_badge <- renderUI({
      if (llm_config$claude_configured || llm_config$openai_configured) {
        span(
          icon("check-circle"),
          " Configured",
          style = "color: #28a745; font-weight: 600;"
        )
      } else {
        span(
          icon("exclamation-triangle"),
          " Not Configured",
          style = "color: #ffc107; font-weight: 600;"
        )
      }
    })

    # Current model display
    output$current_model_display <- renderUI({
      model_name <- get_model_display_name(llm_config$default_model)
      div(
        style = "font-size: 16px; font-weight: 600; color: #40916C;",
        model_name
      )
    })

    # API key status
    output$claude_status <- renderUI({
      if (llm_config$claude_configured) {
        div(
          icon("check-circle", style = "color: #28a745; margin-right: 5px;"),
          span("Configured", style = "color: #28a745; font-weight: 500;")
        )
      } else {
        div(
          icon("times-circle", style = "color: #dc3545; margin-right: 5px;"),
          span("Not Set", style = "color: #dc3545; font-weight: 500;")
        )
      }
    })

    output$openai_status <- renderUI({
      if (llm_config$openai_configured) {
        div(
          icon("check-circle", style = "color: #28a745; margin-right: 5px;"),
          span("Configured", style = "color: #28a745; font-weight: 500;")
        )
      } else {
        div(
          icon("times-circle", style = "color: #dc3545; margin-right: 5px;"),
          span("Not Set", style = "color: #dc3545; font-weight: 500;")
        )
      }
    })

    # ==== SAVE CONFIGURATION ====
    
    observeEvent(input$save_llm_config, {
      if (current_user()$role != "admin") return()
      
      cat("\n💾 Saving LLM configuration...\n")
      
      # Get values from inputs
      model <- input$default_model %||% "claude-sonnet-4.5-20250929"
      temp <- input$temperature %||% 0.7
      tokens <- input$max_tokens %||% 1000
      
      # Handle API keys - FIXED: Don't save truncated display values
      # If the input field contains a truncated key (ends with ...), use the stored key instead
      claude_key_input <- input$claude_api_key %||% ""
      claude_key <- if (grepl("\\.\\.\\.\\s*$", claude_key_input) || nchar(claude_key_input) < 20) {
        # Input is a truncated display value or too short - keep existing key
        llm_config$claude_api_key
      } else if (nchar(claude_key_input) > 0) {
        claude_key_input  # Use newly entered full key
      } else {
        llm_config$claude_api_key  # Keep existing if input is empty
      }
      
      openai_key_input <- input$openai_api_key %||% ""
      openai_key <- if (grepl("\\.\\.\\.\\s*$", openai_key_input) || nchar(openai_key_input) < 20) {
        # Input is a truncated display value or too short - keep existing key
        llm_config$openai_api_key
      } else if (nchar(openai_key_input) > 0) {
        openai_key_input  # Use newly entered full key
      } else {
        llm_config$openai_api_key  # Keep existing if input is empty
      }
      
      # Create config object
      config <- list(
        default_model = model,
        temperature = as.numeric(temp),
        max_tokens = as.integer(tokens),
        claude_api_key = claude_key,
        openai_api_key = openai_key,
        last_updated = Sys.time()
      )
      
      # Ensure data directory exists
      if (!dir.exists("data")) {
        dir.create("data", recursive = TRUE, showWarnings = FALSE)
      }
      
      # Save configuration
      tryCatch({
        config_file <- "data/llm_config.rds"
        saveRDS(config, config_file)
        
        # Update reactive values
        llm_config$default_model <- model
        llm_config$temperature <- temp
        llm_config$max_tokens <- tokens
        llm_config$claude_api_key <- claude_key
        llm_config$openai_api_key <- openai_key
        llm_config$claude_configured <- nchar(claude_key) > 0
        llm_config$openai_configured <- nchar(openai_key) > 0
        
        cat("✅ Configuration saved successfully!\n")
        cat("   File:", config_file, "\n")
        cat("   Model:", model, "\n")
        cat("   Temperature:", temp, "\n")
        cat("   Max Tokens:", tokens, "\n")
        cat("   Claude:", if (llm_config$claude_configured) "✓" else "✗", "\n")
        cat("   OpenAI:", if (llm_config$openai_configured) "✓" else "✗", "\n\n")
        
        alerts$llm_message <- "✅ Configuration saved successfully! Modal dialogs will now use these settings."
        alerts$llm_type <- "success"
        
      }, error = function(e) {
        cat("❌ Error saving configuration:", e$message, "\n")
        alerts$llm_message <- paste("❌ Failed to save configuration:", e$message)
        alerts$llm_type <- "danger"
      })
    })

    # ==== TEST CONNECTION ====
    
    observeEvent(input$test_claude, {
      if (current_user()$role != "admin") return()
      
      if (!llm_config$claude_configured) {
        alerts$llm_message <- "⚠ Claude API key not configured. Please add a key and save."
        alerts$llm_type <- "warning"
        return()
      }
      
      alerts$llm_message <- "ℹ Connection test: API key is configured. (Full connection test coming soon)"
      alerts$llm_type <- "info"
    })
    
    observeEvent(input$test_openai, {
      if (current_user()$role != "admin") return()
      
      if (!llm_config$openai_configured) {
        alerts$llm_message <- "⚠ OpenAI API key not configured. Please add a key and save."
        alerts$llm_type <- "warning"
        return()
      }
      
      alerts$llm_message <- "ℹ Connection test: API key is configured. (Full connection test coming soon)"
      alerts$llm_type <- "info"
    })

    # Return configuration access for other modules
    return(list(
      get_llm_config = function() {
        list(
          default_model = llm_config$default_model,
          temperature = llm_config$temperature,
          max_tokens = llm_config$max_tokens,
          claude_api_key = llm_config$claude_api_key,
          openai_api_key = llm_config$openai_api_key,
          claude_configured = llm_config$claude_configured,
          openai_configured = llm_config$openai_configured
        )
      },
      get_current_config = reactive({
        list(
          default_model = llm_config$default_model,
          temperature = llm_config$temperature,
          max_tokens = llm_config$max_tokens,
          claude_configured = llm_config$claude_configured,
          openai_configured = llm_config$openai_configured
        )
      })
    ))
  })
}
