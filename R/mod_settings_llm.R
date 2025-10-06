#' Settings LLM Configuration Module
#'
#' @description Server logic for LLM configuration management
#' Handles model selection, API key management, configuration persistence,
#' and connection testing for Claude and OpenAI providers
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
      default_model = "claude-sonnet-4-20250514",
      temperature = 0,  # Changed default to 0
      max_tokens = 1000,
      claude_api_key = "",
      openai_api_key = "",
      claude_configured = FALSE,
      openai_configured = FALSE
    )

    # Load existing configuration on module start
    observe({
      config_file <- "data/llm_config.rds"

      # Check for .Renviron keys first
      claude_key_env <- Sys.getenv("CLAUDE_API_KEY", "")
      openai_key_env <- Sys.getenv("OPENAI_API_KEY", "")

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

          # Handle Claude API key - prioritize .Renviron
          if (claude_key_env != "") {
            llm_config$claude_api_key <- claude_key_env
            updateTextInput(session, "claude_api_key",
                          value = "✅ Auto-detected from .Renviron",
                          placeholder = "Key detected from .Renviron file")
            llm_config$claude_configured <- TRUE
          } else if (!is.null(config$claude_api_key) && is.character(config$claude_api_key) && config$claude_api_key != "") {
            llm_config$claude_api_key <- config$claude_api_key
            display_key <- if(nchar(config$claude_api_key) > 8) {
              paste0(substr(config$claude_api_key, 1, 8), "...")
            } else {
              ""
            }
            updateTextInput(session, "claude_api_key", value = display_key)
            llm_config$claude_configured <- TRUE
          }

          # Handle OpenAI API key - prioritize .Renviron
          if (openai_key_env != "") {
            llm_config$openai_api_key <- openai_key_env
            updateTextInput(session, "openai_api_key",
                          value = "✅ Auto-detected from .Renviron",
                          placeholder = "Key detected from .Renviron file")
            llm_config$openai_configured <- TRUE
          } else if (!is.null(config$openai_api_key) && is.character(config$openai_api_key) && config$openai_api_key != "") {
            llm_config$openai_api_key <- config$openai_api_key
            display_key <- if(nchar(config$openai_api_key) > 8) {
              paste0(substr(config$openai_api_key, 1, 8), "...")
            } else {
              ""
            }
            updateTextInput(session, "openai_api_key", value = display_key)
            llm_config$openai_configured <- TRUE
          }
        }, error = function(e) {
          message("Error loading LLM config: ", e$message)

          # Even if config fails, check .Renviron
          if (claude_key_env != "") {
            llm_config$claude_api_key <- claude_key_env
            updateTextInput(session, "claude_api_key",
                          value = "✅ Auto-detected from .Renviron")
            llm_config$claude_configured <- TRUE
          }
          if (openai_key_env != "") {
            llm_config$openai_api_key <- openai_key_env
            updateTextInput(session, "openai_api_key",
                          value = "✅ Auto-detected from .Renviron")
            llm_config$openai_configured <- TRUE
          }
        })
      } else {
        # No config file - check .Renviron
        if (claude_key_env != "") {
          llm_config$claude_api_key <- claude_key_env
          updateTextInput(session, "claude_api_key",
                        value = "✅ Auto-detected from .Renviron")
          llm_config$claude_configured <- TRUE
        }
        if (openai_key_env != "") {
          llm_config$openai_api_key <- openai_key_env
          updateTextInput(session, "openai_api_key",
                        value = "✅ Auto-detected from .Renviron")
          llm_config$openai_configured <- TRUE
        }
      }
    })

    # ==== LLM CONFIGURATION DISPLAYS ====

    # Quick configuration display in header
    output$quick_config_display <- renderUI({
      current_model_name <- get_model_display_name(llm_config$default_model)

      div(
        div(
          style = "font-size: 14px; font-weight: 500;",
          current_model_name
        ),
        div(
          style = "font-size: 12px; opacity: 0.8;",
          paste0("Temp: ", llm_config$temperature, " | Tokens: ", llm_config$max_tokens)
        )
      )
    })

    # Current model badge - FIXED
    output$current_model_badge <- renderUI({
      current_model_name <- get_model_display_name(llm_config$default_model)
      tags$small(
        paste0("(", current_model_name, ")"),
        style = "color: #40916C; font-weight: 500;"
      )
    })

    # Current values display - FIXED
    output$current_temp_display <- renderUI({
      tags$small(
        paste("Current:", llm_config$temperature),
        style = "color: #6c757d; font-weight: 500;"
      )
    })

    output$current_tokens_display <- renderUI({
      tags$small(
        paste("Current:", llm_config$max_tokens),
        style = "color: #6c757d; font-weight: 500;"
      )
    })

    # Configuration summary
    output$config_summary <- renderUI({
      current_model_name <- get_model_display_name(llm_config$default_model)

      div(
        div(
          style = "margin-bottom: 5px;",
          tags$strong("Model: "), current_model_name
        ),
        div(
          style = "margin-bottom: 5px;",
          tags$strong("Temperature: "), llm_config$temperature
        ),
        div(
          tags$strong("Max Tokens: "), llm_config$max_tokens
        )
      )
    })

    # API Key status indicators
    output$claude_key_status <- renderUI({
      if (llm_config$claude_configured) {
        span("✓ Configured", style = "color: #28a745; font-size: 12px; font-weight: 500;")
      } else {
        span("⚠ Not Set", style = "color: #ffc107; font-size: 12px; font-weight: 500;")
      }
    })

    output$openai_key_status <- renderUI({
      if (llm_config$openai_configured) {
        span("✓ Configured", style = "color: #28a745; font-size: 12px; font-weight: 500;")
      } else {
        span("⚠ Not Set", style = "color: #ffc107; font-size: 12px; font-weight: 500;")
      }
    })

    # Service status icons
    output$claude_status_icon <- renderUI({
      if (llm_config$claude_configured) {
        span(icon("check-circle"), style = "color: #28a745;")
      } else {
        span(icon("times-circle"), style = "color: #dc3545;")
      }
    })

    output$openai_status_icon <- renderUI({
      if (llm_config$openai_configured) {
        span(icon("check-circle"), style = "color: #28a745;")
      } else {
        span(icon("times-circle"), style = "color: #dc3545;")
      }
    })

    # ==== LLM CONFIGURATION FUNCTIONS ====

    # Save LLM configuration - SIMPLIFIED VERSION
    observeEvent(input$save_llm_config, {
      if (current_user()$role != "admin") return()

      cat("Save LLM config button clicked\n")

      # Get values from inputs
      model <- input$default_model %||% "claude-sonnet-4-20250514"
      temp <- input$temperature %||% 0
      tokens <- input$max_tokens %||% 1000

      # Handle API keys - use current values or from inputs
      claude_key <- if (grepl("Auto-detected", input$claude_api_key %||% "")) {
        llm_config$claude_api_key  # Use existing key
      } else {
        input$claude_api_key %||% ""
      }

      openai_key <- if (grepl("Auto-detected", input$openai_api_key %||% "")) {
        llm_config$openai_api_key  # Use existing key
      } else {
        input$openai_api_key %||% ""
      }

      cat("Calling save_llm_config_simple...\n")

      # Use the simplified save function
      result <- save_llm_config_simple(
        default_model = model,
        temperature = temp,
        max_tokens = tokens,
        claude_api_key = claude_key,
        openai_api_key = openai_key
      )

      if (result$success) {
        # Update reactive values
        llm_config$default_model <- model
        llm_config$temperature <- temp
        llm_config$max_tokens <- tokens
        llm_config$claude_api_key <- claude_key
        llm_config$openai_api_key <- openai_key
        llm_config$claude_configured <- nchar(claude_key) > 0
        llm_config$openai_configured <- nchar(openai_key) > 0

        alerts$llm_message <- paste("Configuration saved successfully to:", result$config_file)
        alerts$llm_type <- "success"
        cat("Save successful!\n")
      } else {
        alerts$llm_message <- paste("Save failed:", result$message)
        alerts$llm_type <- "danger"
        cat("Save failed:", result$message, "\n")
      }
    })

    # Test Claude connection
    observeEvent(input$test_claude, {
      if (current_user()$role != "admin") return()

      if (!llm_config$claude_configured) {
        alerts$llm_message <- "Claude API key not configured"
        alerts$llm_type <- "danger"
        return()
      }

      # Simulate test (replace with actual API test)
      alerts$llm_message <- "Claude connection test: Simulated success (implement actual API test)"
      alerts$llm_type <- "info"
    })

    # Test OpenAI connection
    observeEvent(input$test_openai, {
      if (current_user()$role != "admin") return()

      if (!llm_config$openai_configured) {
        alerts$llm_message <- "OpenAI API key not configured"
        alerts$llm_type <- "danger"
        return()
      }

      # Simulate test (replace with actual API test)
      alerts$llm_message <- "OpenAI connection test: Simulated success (implement actual API test)"
      alerts$llm_type <- "info"
    })

    # Return configuration access for other modules
    return(list(
      get_llm_config = function() {
        config_file <- "data/llm_config.rds"
        if (file.exists(config_file)) {
          readRDS(config_file)
        } else {
          list(
            default_model = "claude-sonnet-4-20250514",
            temperature = 0.7,
            max_tokens = 1000,
            claude_api_key = "",
            openai_api_key = ""
          )
        }
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