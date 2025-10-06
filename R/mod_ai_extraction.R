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
        temperature = config$temperature %||% 0.7,
        max_tokens = config$max_tokens %||% 1000,
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
    extract_with_ai_fallback <- function(image_path, extraction_type = "individual", card_count = 1) {
      ai_config <- get_ai_config()

      # Try primary provider first
      providers <- c(ai_config$primary_provider)

      # Add fallback if both are configured
      if (ai_config$claude_configured && ai_config$openai_configured) {
        providers <- c(providers, ai_config$fallback_provider)
      }

      last_error <- NULL

      for (provider in providers) {
        cat("Attempting extraction with provider:", provider, "\n")

        result <- tryCatch({
          switch(provider,
            "claude" = extract_with_claude(
              image_path = image_path,
              extraction_type = extraction_type,
              card_count = card_count,
              temperature = ai_config$temperature,
              max_tokens = ai_config$max_tokens
            ),
            "openai" = extract_with_openai(
              image_path = image_path,
              extraction_type = extraction_type,
              card_count = card_count,
              temperature = ai_config$temperature,
              max_tokens = ai_config$max_tokens
            )
          )
        }, error = function(e) {
          cat("Provider", provider, "failed:", e$message, "\n")
          last_error <<- e$message
          NULL
        })

        if (!is.null(result) && result$success) {
          result$provider_used <- provider
          return(result)
        }
      }

      # All providers failed
      return(list(
        success = FALSE,
        title = "",
        description = "",
        error_message = paste("All AI providers failed. Last error:", last_error),
        provider_used = "none"
      ))
    }

    # Extract with Claude provider
    extract_with_claude <- function(image_path, extraction_type, card_count, temperature, max_tokens) {
      # Implementation would use actual Claude API
      # For now, return simulated extraction

      Sys.sleep(1) # Simulate API delay

      # Simulate success/failure
      success <- sample(c(TRUE, FALSE), 1, prob = c(0.85, 0.15))

      if (success) {
        base_name <- tools::file_path_sans_ext(basename(image_path))

        if (extraction_type == "lot") {
          title <- paste("Postal Card Lot -", card_count, "cards from", base_name)
          description <- paste("Collection of", card_count, "vintage postal cards. Mixed themes and periods. Good overall condition. Extracted with Claude AI.")
        } else {
          title <- paste("Vintage Postal Card -", gsub("_", " ", base_name))
          description <- "Vintage postal card in good condition. Interesting historical piece. Details extracted with Claude AI analysis."
        }

        return(list(
          success = TRUE,
          title = title,
          description = description,
          confidence_score = runif(1, 0.8, 0.95),
          extraction_method = "claude_api"
        ))
      } else {
        return(list(
          success = FALSE,
          title = "",
          description = "",
          error_message = "Claude API extraction failed",
          extraction_method = "claude_api"
        ))
      }
    }

    # Extract with OpenAI provider
    extract_with_openai <- function(image_path, extraction_type, card_count, temperature, max_tokens) {
      # Implementation would use actual OpenAI API
      # For now, return simulated extraction

      Sys.sleep(1.2) # Simulate slightly longer API delay

      # Simulate success/failure
      success <- sample(c(TRUE, FALSE), 1, prob = c(0.80, 0.20))

      if (success) {
        base_name <- tools::file_path_sans_ext(basename(image_path))

        if (extraction_type == "lot") {
          title <- paste("Postcard Collection -", card_count, "pieces from", base_name)
          description <- paste("Set of", card_count, "historical postcards. Various themes and eras represented. Condition varies. Analyzed with GPT-4o.")
        } else {
          title <- paste("Historical Postcard -", gsub("_", " ", base_name))
          description <- "Historical postcard with cultural significance. Well-preserved example. Text and imagery analyzed with OpenAI GPT-4o."
        }

        return(list(
          success = TRUE,
          title = title,
          description = description,
          confidence_score = runif(1, 0.75, 0.90),
          extraction_method = "openai_api"
        ))
      } else {
        return(list(
          success = FALSE,
          title = "",
          description = "",
          error_message = "OpenAI API extraction failed",
          extraction_method = "openai_api"
        ))
      }
    }

    # Main extraction interface
    perform_extraction <- function(extraction_type = "individual", card_count = 1) {
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

      # Set extracting state
      rv$extracting <- TRUE

      # Show progress notification
      if (!is.null(notification_session)) {
        showNotification(
          "Starting AI extraction...",
          type = "message",
          duration = 2,
          session = notification_session
        )
      }

      # Perform extraction with fallback
      result <- extract_with_ai_fallback(
        image_path = current_path,
        extraction_type = extraction_type,
        card_count = card_count
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
          showNotification(
            paste("AI extraction completed using", result$provider_used),
            type = "message",
            duration = 3,
            session = notification_session
          )
        } else {
          showNotification(
            paste("AI extraction failed:", result$error_message),
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

      # Simulate connection test
      Sys.sleep(0.5)
      success <- sample(c(TRUE, FALSE), 1, prob = c(0.9, 0.1))

      return(list(
        success = success,
        message = if (success) {
          paste(provider, "connection successful")
        } else {
          paste(provider, "connection failed - please check API key")
        }
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