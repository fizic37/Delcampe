#' Settings Module Server - FIXED VERSION
#' @export
mod_settings_server <- function(id, current_user) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    `%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || all(is.na(a))) b else a
    
    # Reactive values for alerts and state
    alerts <- reactiveValues(
      user_message = "",
      user_type = "",
      llm_message = "",
      llm_type = ""
    )
    
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
            llm_config$claude_api_key <- config$claude_api_key  # Store FULL key
            display_key <- if(nchar(config$claude_api_key) > 8) {
              paste0(substr(config$claude_api_key, 1, 8), "...")
            } else {
              ""
            }
            updateTextInput(session, "claude_api_key", value = display_key, placeholder = "Key is configured (hidden for security)")
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
    
    # Render different UI based on user role
    output$settings_content <- renderUI({
      # CRITICAL: Check if current_user exists and has role
      user <- current_user()
      if (is.null(user) || is.null(user$role)) {
        return(div(class = "alert alert-warning", "Please log in to access settings."))
      }

      user_role <- user$role

      if (user_role %in% c("master", "admin")) {
        # Master and admin users see full interface
        render_admin_ui(ns)
      } else {
        # Regular users see only password change
        render_user_ui(ns)
      }
    })
    
    # Only call tracking viewer for master and admin users
    observe({
      # CRITICAL: Check if current_user exists and has required fields
      user <- current_user()
      if (!is.null(user) && !is.null(user$role) && user$role %in% c("master", "admin")) {
        mod_tracking_viewer_server("tracking_viewer_1")
      }
    })
    
    # ==== FIXED LLM CONFIGURATION DISPLAYS ====
    
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
      # CRITICAL: Check permissions
      user <- current_user()
      if (is.null(user) || is.null(user$role) || !user$role %in% c("master", "admin")) return()
      
      cat("Save LLM config button clicked\n")
      
      # Get values from inputs
      model <- input$default_model %||% "claude-sonnet-4-20250514"
      temp <- input$temperature %||% 0
      tokens <- input$max_tokens %||% 1000
      
      # CRITICAL FIX: Load existing keys from file first
      existing_keys <- list(
        claude = "",
        openai = ""
      )
      
      config_file <- "data/llm_config.rds"
      if (file.exists(config_file)) {
        tryCatch({
          saved_config <- readRDS(config_file)
          if (!is.null(saved_config$claude_api_key) && nchar(saved_config$claude_api_key) > 0) {
            existing_keys$claude <- saved_config$claude_api_key
          }
          if (!is.null(saved_config$openai_api_key) && nchar(saved_config$openai_api_key) > 0) {
            existing_keys$openai <- saved_config$openai_api_key
          }
          cat("Loaded existing keys from file:\n")
          cat("  Claude key length:", nchar(existing_keys$claude), "\n")
          cat("  OpenAI key length:", nchar(existing_keys$openai), "\n")
        }, error = function(e) {
          cat("Error loading existing config:", e$message, "\n")
        })
      }
      
      # Handle API keys - FIXED LOGIC
      # If the input shows a masked key (contains "...") or auto-detected text, use the stored full key from FILE
      # Otherwise, use the new key entered by the user
      claude_key_input <- input$claude_api_key %||% ""
      claude_key <- if (grepl("Auto-detected|\\.\\.\\.", claude_key_input)) {
        cat("Claude: Using existing key from file (masked/auto-detected in input)\n")
        existing_keys$claude  # Use stored FULL key from FILE
      } else if (nchar(claude_key_input) >= 20) {
        cat("Claude: Using new key from input\n")
        claude_key_input  # New full key entered
      } else if (nchar(claude_key_input) == 0) {
        cat("Claude: Empty input, keeping existing key\n")
        existing_keys$claude
      } else {
        cat("Claude: Input too short, keeping existing key\n")
        existing_keys$claude
      }
      
      openai_key_input <- input$openai_api_key %||% ""
      openai_key <- if (grepl("Auto-detected|\\.\\.\\.", openai_key_input)) {
        cat("OpenAI: Using existing key from file (masked/auto-detected in input)\n")
        existing_keys$openai  # Use stored FULL key from FILE
      } else if (nchar(openai_key_input) >= 20) {
        cat("OpenAI: Using new key from input\n")
        openai_key_input  # New full key entered
      } else if (nchar(openai_key_input) == 0) {
        cat("OpenAI: Empty input, keeping existing key\n")
        existing_keys$openai
      } else {
        cat("OpenAI: Input too short, keeping existing key\n")
        existing_keys$openai
      }
      
      cat("Calling save_llm_config_simple...\n")
      cat("  Model:", model, "\n")
      cat("  Temp:", temp, "\n")
      cat("  Tokens:", tokens, "\n")
      cat("  Claude key length:", nchar(claude_key), "\n")
      cat("  OpenAI key length:", nchar(openai_key), "\n")
      
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
      user <- current_user()
      if (is.null(user) || is.null(user$role) || !user$role %in% c("master", "admin")) return()
      
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
      user <- current_user()
      if (is.null(user) || is.null(user$role) || !user$role %in% c("master", "admin")) return()
      
      if (!llm_config$openai_configured) {
        alerts$llm_message <- "OpenAI API key not configured"
        alerts$llm_type <- "danger"
        return()
      }
      
      # Simulate test (replace with actual API test)
      alerts$llm_message <- "OpenAI connection test: Simulated success (implement actual API test)"
      alerts$llm_type <- "info"
    })
    
    # ==== PASSWORD CHANGE FUNCTIONALITY (FOR ALL USERS) ====
    
    # User password change functionality
    observeEvent(input$change_password_btn, {
      showModal(modalDialog(
        title = "Change Password",
        size = "m",
        
        passwordInput(
          ns("current_password"),
          "Current Password",
          placeholder = "Enter current password"
        ),
        
        passwordInput(
          ns("new_password"),
          "New Password",
          placeholder = "Minimum 6 characters"
        ),
        
        passwordInput(
          ns("confirm_new_password"),
          "Confirm New Password",
          placeholder = "Re-enter new password"
        ),
        
        footer = div(
          actionButton(
            ns("submit_password_change"),
            "Change Password",
            icon = icon("key"),
            class = "btn-success"
          ),
          modalButton("Cancel")
        ),
        easyClose = TRUE
      ))
    })
    
    # Handle password change submission
    observeEvent(input$submit_password_change, {
      req(input$current_password, input$new_password, input$confirm_new_password)

      # Get current user
      user <- current_user()
      if (is.null(user) || is.null(user$email)) {
        alerts$user_message <- "User session not found"
        alerts$user_type <- "danger"
        return()
      }

      # Validate password confirmation
      if (input$new_password != input$confirm_new_password) {
        alerts$user_message <- "New passwords do not match"
        alerts$user_type <- "danger"
        return()
      }

      # Verify current password
      auth_result <- authenticate_user(user$email, input$current_password)
      if (!auth_result$success) {
        alerts$user_message <- "Current password is incorrect"
        alerts$user_type <- "danger"
        return()
      }

      # Update password
      update_result <- update_user_password(
        email = user$email,
        new_password = input$new_password,
        current_user_email = user$email,
        current_user_role = user$role
      )

      if (update_result$success) {
        alerts$user_message <- "Password updated successfully"
        alerts$user_type <- "success"
        removeModal()
      } else {
        alerts$user_message <- paste("Error:", update_result$message)
        alerts$user_type <- "danger"
      }
    })
    
    # ==== ALERT RENDERING ====
    
    # Render LLM alerts
    output$llm_alerts <- renderUI({
      user <- current_user()
      if (is.null(user) || is.null(user$role) || !user$role %in% c("master", "admin")) return(NULL)
      
      if (alerts$llm_message != "") {
        div(
          class = paste("alert alert", alerts$llm_type, sep = "-"),
          style = "border-radius: 8px;",
          icon(if (alerts$llm_type == "success") "check-circle" else if (alerts$llm_type == "danger") "exclamation-triangle" else "info-circle"),
          " ",
          alerts$llm_message,
          tags$button(
            type = "button", 
            class = "btn-close",
            `data-bs-dismiss` = "alert",
            onclick = paste0("Shiny.setInputValue('", ns("clear_llm_alert"), "', Math.random());")
          )
        )
      }
    })
    
    # Clear LLM alerts
    observeEvent(input$clear_llm_alert, {
      alerts$llm_message <- ""
      alerts$llm_type <- ""
    })
    
    # Render user alerts
    output$user_alerts <- renderUI({
      if (alerts$user_message != "") {
        div(
          class = paste("alert alert", alerts$user_type, sep = "-"),
          style = "border-radius: 8px;",
          icon(if (alerts$user_type == "success") "check-circle" else "exclamation-triangle"),
          " ",
          alerts$user_message,
          tags$button(
            type = "button",
            class = "btn-close",
            `data-bs-dismiss` = "alert",
            onclick = paste0("Shiny.setInputValue('", ns("clear_user_alert"), "', Math.random());")
          )
        )
      }
    })
    
    # Clear user alerts
    observeEvent(input$clear_user_alert, {
      alerts$user_message <- ""
      alerts$user_type <- ""
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
      }
    ))
  })
}

# Helper function for safe assignment
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || all(is.na(a))) b else a

# Simplified save function - MOCK VERSION
save_llm_config_simple <- function(default_model, temperature, max_tokens, claude_api_key = "", openai_api_key = "") {
  cat("SAVE_LLM_CONFIG_SIMPLE - Starting save...\n")
  
  tryCatch({
    # Create config object
    config <- list(
      default_model = default_model,
      temperature = as.numeric(temperature),
      max_tokens = as.numeric(max_tokens),
      claude_api_key = claude_api_key,
      openai_api_key = openai_api_key,
      last_updated = Sys.time(),
      version = "1.0"
    )
    
    # Ensure data directory exists
    if (!dir.exists("data")) {
      dir.create("data", recursive = TRUE, showWarnings = FALSE)
    }
    
    # Save config file
    config_file <- "data/llm_config.rds"
    saveRDS(config, config_file)
    
    # Verify the save worked
    if (file.exists(config_file)) {
      return(list(
        success = TRUE,
        message = "Configuration saved successfully",
        config_file = config_file
      ))
    } else {
      stop("Config file was not created")
    }
    
  }, error = function(e) {
    return(list(
      success = FALSE,
      message = paste("Failed to save LLM config:", e$message),
      error = e$message
    ))
  })
}
