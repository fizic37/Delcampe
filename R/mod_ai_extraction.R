#' AI Extraction Module
#'
#' @description Server logic for AI text extraction from postal card images
#' Handles coordination with AI providers, manages extraction workflows,
#' and provides standardized extraction interface regardless of provider
#'
#' @param id,input,output,session Internal parameters for {shiny}
#' @param image_path Reactive containing current image path for extraction
#' @param session Parent session for notifications and updates
#'
#' @noRd
#' @import shiny
mod_ai_extraction_server <- function(id, image_path = reactive(NULL), session = NULL) {
  moduleServer(id, function(input, output, session_inner) {
    ns <- session_inner$ns
    `%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || all(is.na(a))) b else a

    # Use parent session if provided, otherwise use module session
    notification_session <- session %||% session_inner

    # Reactive values for extraction state
    rv <- reactiveValues(
      extracting = FALSE,
      last_result = NULL,
      extraction_history = list()
    )

    # Get AI provider configuration
    get_ai_config <- function() {
      config <- get_llm_config()
      return(list(
        primary_provider = determine_primary_provider(config),
        fallback_provider = determine_fallback_provider(config),
        default_model = config$default_model %||% "claude-sonnet-4-20250514",
        temperature = config$temperature %||% 0.7,
        max_tokens = config$max_tokens %||% 1000,
        claude_api_key = config$claude_api_key,
        openai_api_key = config$openai_api_key,
        claude_configured = !is.null(config$claude_api_key) && config$claude_api_key != "",
        openai_configured = !is.null(config$openai_api_key) && config$openai_api_key != ""
      ))
    }

    # Determine primary AI provider based on configuration
    determine_primary_provider <- function(config) {
      model <- config$default_model %||% "claude-sonnet-4-20250514"

      if (grepl("claude", model, ignore.case = TRUE)) {
        return("claude")
      } else if (grepl("gpt|openai", model, ignore.case = TRUE)) {
        return("openai")
      } else {
        return("claude")  # Default fallback
      }
    }

    # Determine fallback provider
    determine_fallback_provider <- function(config) {
      primary <- determine_primary_provider(config)
      return(if (primary == "claude") "openai" else "claude")
    }

    # Extract text using multi-provider fallback
    extract_with_ai_fallback <- function(image_path, extraction_type = "individual", 
                                        card_count = 1, model_override = NULL) {
      ai_config <- get_ai_config()

      # Determine which model to use
      if (!is.null(model_override)) {
        # User selected a specific model
        selected_model <- model_override
        selected_provider <- get_provider_from_model(selected_model)
      } else {
        # Use default model from config
        selected_model <- ai_config$default_model
        selected_provider <- ai_config$primary_provider
      }

      # Try selected provider first
      providers <- c(selected_provider)

      # Add fallback if both are configured and we're not forcing a specific model
      if (is.null(model_override) && ai_config$claude_configured && ai_config$openai_configured) {
        providers <- c(providers, ai_config$fallback_provider)
      }

      last_error <- NULL

      for (provider in providers) {
        cat("🤖 Attempting extraction with provider:", provider, "\n")

        # Determine model for this provider
        if (provider == selected_provider && !is.null(model_override)) {
          model_to_use <- model_override
        } else if (provider == "claude") {
          model_to_use <- if (grepl("claude", selected_model, ignore.case = TRUE)) {
            selected_model
          } else {
            "claude-sonnet-4-20250514"  # Default Claude model
          }
        } else {
          model_to_use <- if (grepl("gpt", selected_model, ignore.case = TRUE)) {
            selected_model
          } else {
            "gpt-4o"  # Default OpenAI model
          }
        }

        result <- tryCatch({
          switch(provider,
            "claude" = extract_with_claude(
              image_path = image_path,
              model_name = model_to_use,
              extraction_type = extraction_type,
              card_count = card_count,
              temperature = ai_config$temperature,
              max_tokens = ai_config$max_tokens,
              api_key = ai_config$claude_api_key
            ),
            "openai" = extract_with_openai(
              image_path = image_path,
              model_name = model_to_use,
              extraction_type = extraction_type,
              card_count = card_count,
              temperature = ai_config$temperature,
              max_tokens = ai_config$max_tokens,
              api_key = ai_config$openai_api_key
            )
          )
        }, error = function(e) {
          cat("❌ Provider", provider, "failed:", e$message, "\n")
          last_error <<- e$message
          NULL
        })

        if (!is.null(result) && result$success) {
          result$provider_used <- provider
          result$model_used <- model_to_use
          cat("✅ Extraction successful with", provider, "using", model_to_use, "\n")
          return(result)
        }
      }

      # All providers failed
      cat("❌ All providers failed\n")
      return(list(
        success = FALSE,
        title = "",
        description = "",
        error_message = paste("All AI providers failed. Last error:", last_error),
        provider_used = "none"
      ))
    }

    # Extract with Claude provider - REAL API IMPLEMENTATION
    extract_with_claude <- function(image_path, model_name, extraction_type, 
                                    card_count, temperature, max_tokens, api_key) {
      
      cat("📸 Calling Claude API with model:", model_name, "\n")
      cat("   Image:", basename(image_path), "\n")
      cat("   Type:", extraction_type, "\n")
      
      # Build prompt
      prompt <- build_postal_card_prompt(extraction_type, card_count)
      
      # Call Claude API
      api_result <- call_claude_api(
        image_path = image_path,
        model_name = model_name,
        api_key = api_key,
        prompt = prompt,
        temperature = temperature,
        max_tokens = max_tokens
      )
      
      if (!api_result$success) {
        cat("❌ Claude API error:", api_result$error, "\n")
        return(list(
          success = FALSE,
          title = "",
          description = "",
          error_message = api_result$error,
          extraction_method = "claude_api"
        ))
      }
      
      # Parse response
      cat("✅ Claude API success, parsing response...\n")
      parsed <- parse_ai_response(api_result$content)
      
      # Log token usage if available
      if (!is.null(api_result$usage)) {
        cat("   Tokens used - Input:", api_result$usage$input_tokens, 
            "Output:", api_result$usage$output_tokens, "\n")
      }
      
      return(list(
        success = TRUE,
        title = parsed$title,
        description = parsed$description,
        raw_response = api_result$content,
        model = api_result$model,
        usage = api_result$usage,
        extraction_method = "claude_api"
      ))
    }

    # Extract with OpenAI provider - REAL API IMPLEMENTATION
    extract_with_openai <- function(image_path, model_name, extraction_type, 
                                    card_count, temperature, max_tokens, api_key) {
      
      cat("📸 Calling OpenAI API with model:", model_name, "\n")
      cat("   Image:", basename(image_path), "\n")
      cat("   Type:", extraction_type, "\n")
      
      # Build prompt
      prompt <- build_postal_card_prompt(extraction_type, card_count)
      
      # Call OpenAI API
      api_result <- call_openai_api(
        image_path = image_path,
        model_name = model_name,
        api_key = api_key,
        prompt = prompt,
        temperature = temperature,
        max_tokens = max_tokens
      )
      
      if (!api_result$success) {
        cat("❌ OpenAI API error:", api_result$error, "\n")
        return(list(
          success = FALSE,
          title = "",
          description = "",
          error_message = api_result$error,
          extraction_method = "openai_api"
        ))
      }
      
      # Parse response
      cat("✅ OpenAI API success, parsing response...\n")
      parsed <- parse_ai_response(api_result$content)
      
      # Log token usage if available
      if (!is.null(api_result$usage)) {
        cat("   Tokens used - Prompt:", api_result$usage$prompt_tokens, 
            "Completion:", api_result$usage$completion_tokens, "\n")
      }
      
      return(list(
        success = TRUE,
        title = parsed$title,
        description = parsed$description,
        raw_response = api_result$content,
        model = api_result$model,
        usage = api_result$usage,
        extraction_method = "openai_api"
      ))
    }

    # Main extraction interface
    perform_extraction <- function(extraction_type = "individual", card_count = 1, model_override = NULL) {
      current_path <- image_path()
      if (is.null(current_path)) {
        return(list(
          success = FALSE,
          error_message = "No image path provided",
          title = "",
          description = ""
        ))
      }

      # Check if file exists
      if (!file.exists(current_path)) {
        return(list(
          success = FALSE,
          error_message = paste("Image file not found:", current_path),
          title = "",
          description = ""
        ))
      }

      # Check if at least one provider is configured
      ai_config <- get_ai_config()
      if (!ai_config$claude_configured && !ai_config$openai_configured) {
        return(list(
          success = FALSE,
          error_message = "No AI providers configured. Please add API keys in Settings.",
          title = "",
          description = ""
        ))
      }

      # Set extracting state
      rv$extracting <- TRUE

      # Show progress notification
      if (!is.null(notification_session)) {
        model_display <- if (!is.null(model_override)) {
          paste("using", get_model_display_name(model_override))
        } else {
          ""
        }
        showNotification(
          paste("Starting AI extraction", model_display, "..."),
          type = "message",
          duration = 2,
          session = notification_session
        )
      }

      # Perform extraction with fallback
      result <- extract_with_ai_fallback(
        image_path = current_path,
        extraction_type = extraction_type,
        card_count = card_count,
        model_override = model_override
      )

      # Update reactive values
      rv$extracting <- FALSE
      rv$last_result <- result

      # Add to extraction history
      rv$extraction_history <- append(rv$extraction_history, list(list(
        timestamp = Sys.time(),
        image_path = current_path,
        result = result
      )), after = 0)

      # Keep only last 10 extractions
      if (length(rv$extraction_history) > 10) {
        rv$extraction_history <- rv$extraction_history[1:10]
      }

      # Show completion notification
      if (!is.null(notification_session)) {
        if (result$success) {
          model_used <- get_model_display_name(result$model_used %||% "Unknown")
          showNotification(
            paste("✅ AI extraction completed using", model_used),
            type = "message",
            duration = 3,
            session = notification_session
          )
        } else {
          showNotification(
            paste("❌ AI extraction failed:", result$error_message),
            type = "error",
            duration = 5,
            session = notification_session
          )
        }
      }

      return(result)
    }

    # Test AI provider connection
    test_provider_connection <- function(provider) {
      ai_config <- get_ai_config()

      if (provider == "claude" && !ai_config$claude_configured) {
        return(list(
          success = FALSE,
          message = "Claude API key not configured"
        ))
      }

      if (provider == "openai" && !ai_config$openai_configured) {
        return(list(
          success = FALSE,
          message = "OpenAI API key not configured"
        ))
      }

      # For now, just check if key exists
      # TODO: Implement actual test API call
      return(list(
        success = TRUE,
        message = paste(provider, "API key is configured (connection test not yet implemented)")
      ))
    }

    # Get extraction status
    get_extraction_status <- function() {
      return(list(
        is_extracting = rv$extracting,
        last_result = rv$last_result,
        extraction_count = length(rv$extraction_history)
      ))
    }

    # Get AI configuration summary
    get_ai_summary <- function() {
      config <- get_ai_config()

      return(list(
        primary_provider = config$primary_provider,
        fallback_available = config$claude_configured && config$openai_configured,
        temperature = config$temperature,
        max_tokens = config$max_tokens,
        providers_configured = c(
          if (config$claude_configured) "claude",
          if (config$openai_configured) "openai"
        )
      ))
    }

    # Return interface for parent modules
    return(list(
      perform_extraction = perform_extraction,
      test_provider = test_provider_connection,
      get_status = reactive(get_extraction_status()),
      get_summary = reactive(get_ai_summary()),
      is_extracting = reactive(rv$extracting),
      last_result = reactive(rv$last_result)
    ))
  })
}
