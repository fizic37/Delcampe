#' AI API Helper Functions
#'
#' @description Functions for calling Claude and OpenAI APIs for image analysis
#' @noRd
NULL

#' Get LLM Configuration
#' 
#' @description Reads LLM configuration from data/llm_config.rds with fallback to environment variables
#' @return List with configuration including API keys, default model, temperature, and max_tokens
#' @noRd
get_llm_config <- function() {
  config_file <- "data/llm_config.rds"
  
  # Default configuration
  config <- list(
    default_model = "claude-sonnet-4-5-20250929",
    temperature = 0.0,
    max_tokens = 1000,
    claude_api_key = "",
    openai_api_key = "",
    last_updated = NULL
  )
  
  cat("\n=== get_llm_config() called ===\n")
  cat("Config file path:", config_file, "\n")
  cat("File exists:", file.exists(config_file), "\n")
  cat("Working directory:", getwd(), "\n")
  
  # Try to load from file
  if (file.exists(config_file)) {
    tryCatch({
      saved_config <- readRDS(config_file)
      cat("Successfully read config file\n")
      cat("Keys in config:", paste(names(saved_config), collapse = ", "), "\n")
      
      # Merge saved config with defaults
      for (key in names(saved_config)) {
        config[[key]] <- saved_config[[key]]
      }
      
      # Debug: Show key lengths
      claude_key <- if (is.null(config$claude_api_key) || config$claude_api_key == "") "" else config$claude_api_key
      openai_key <- if (is.null(config$openai_api_key) || config$openai_api_key == "") "" else config$openai_api_key
      cat("Claude key length from file:", nchar(claude_key), "\n")
      cat("OpenAI key length from file:", nchar(openai_key), "\n")
    }, error = function(e) {
      cat("ERROR reading config file:", e$message, "\n")
    })
  } else {
    cat("Config file does not exist, using defaults\n")
  }
  
  # Final debug output
  claude_key_final <- if (is.null(config$claude_api_key) || config$claude_api_key == "") "" else config$claude_api_key
  openai_key_final <- if (is.null(config$openai_api_key) || config$openai_api_key == "") "" else config$openai_api_key
  cat("Final Claude key length:", nchar(claude_key_final), "\n")
  cat("Final OpenAI key length:", nchar(openai_key_final), "\n")
  cat("=== get_llm_config() complete ===\n\n")
  
  return(config)
}

#' Compress Image if Needed
#' 
#' @param image_path Path to the image file
#' @param max_size_mb Maximum file size in MB (default 4.5 to leave buffer)
#' @return Path to compressed image (or original if small enough)
#' @noRd
compress_image_if_needed <- function(image_path, max_size_mb = 4.5) {
  
  file_size_mb <- file.info(image_path)$size / (1024 * 1024)
  
  if (file_size_mb <= max_size_mb) {
    cat("Image size OK:", round(file_size_mb, 2), "MB\n")
    return(image_path)
  }
  
  cat("Image too large:", round(file_size_mb, 2), "MB - compressing...\n")
  
  # Don't show notifications - they fail in later::later() context
  
  tryCatch({
    # Load image using magick
    img <- magick::image_read(image_path)
    
    # Get original dimensions
    info <- magick::image_info(img)
    original_width <- info$width
    original_height <- info$height
    
    # Calculate scale factor to get under size limit
    # Start with 80% quality and scale down if needed
    scale_factor <- sqrt(max_size_mb / file_size_mb) * 0.9
    new_width <- as.integer(original_width * scale_factor)
    new_height <- as.integer(original_height * scale_factor)
    
    cat("Resizing from", original_width, "x", original_height, 
        "to", new_width, "x", new_height, "\n")
    
    # Resize image
    img_resized <- magick::image_resize(img, paste0(new_width, "x", new_height))
    
    # Save to temporary file with compression
    temp_path <- tempfile(fileext = ".jpg")
    magick::image_write(img_resized, temp_path, format = "jpg", quality = 80)
    
    # Check new size
    new_size_mb <- file.info(temp_path)$size / (1024 * 1024)
    cat("Compressed to:", round(new_size_mb, 2), "MB\n")
    
    # If still too large, try with lower quality
    if (new_size_mb > max_size_mb) {
      cat("Still too large, reducing quality...\n")
      magick::image_write(img_resized, temp_path, format = "jpg", quality = 60)
      new_size_mb <- file.info(temp_path)$size / (1024 * 1024)
      cat("Final size:", round(new_size_mb, 2), "MB\n")
    }
    
    return(temp_path)
    
  }, error = function(e) {
    cat("Error compressing image:", e$message, "\n")
    cat("Returning original image (may fail API call)\n")
    return(image_path)
  })
}

#' Call Claude API for Image Analysis
#' 
#' @param image_path Path to the image file
#' @param model_name Claude model name (e.g., "claude-sonnet-4-20250514")
#' @param api_key Claude API key
#' @param prompt Text prompt for image analysis
#' @param temperature Sampling temperature (0-1)
#' @param max_tokens Maximum tokens in response
#' 
#' @return List with success, content, and error information
#' @noRd
call_claude_api <- function(image_path, model_name, api_key, prompt, temperature = 0.7, max_tokens = 1000) {
  
  # Validate inputs
  if (is.null(api_key) || api_key == "") {
    return(list(
      success = FALSE,
      content = NULL,
      error = "Claude API key not configured"
    ))
  }
  
  if (!file.exists(image_path)) {
    return(list(
      success = FALSE,
      content = NULL,
      error = paste("Image file not found:", image_path)
    ))
  }
  
  tryCatch({
    # Compress image if needed (Claude has 5 MB limit for base64-encoded images)
    # Base64 increases size by ~33%, so target 3.7 MB to stay under 5 MB after encoding
    processed_image_path <- compress_image_if_needed(image_path, max_size_mb = 3.7)
    
    # Read and encode image as base64
    image_data <- readBin(processed_image_path, "raw", file.info(processed_image_path)$size)
    image_base64 <- base64enc::base64encode(image_data)
    
    # Clean up temporary compressed file if created
    if (processed_image_path != image_path && file.exists(processed_image_path)) {
      unlink(processed_image_path)
    }
    
    # Determine media type from file extension
    ext <- tolower(tools::file_ext(image_path))
    media_type <- switch(ext,
      "jpg" = "image/jpeg",
      "jpeg" = "image/jpeg",
      "png" = "image/png",
      "gif" = "image/gif",
      "webp" = "image/webp",
      "image/jpeg" # default
    )
    
    # Construct request body
    body <- list(
      model = model_name,
      max_tokens = as.integer(max_tokens),
      temperature = as.numeric(temperature),
      messages = list(
        list(
          role = "user",
          content = list(
            list(
              type = "image",
              source = list(
                type = "base64",
                media_type = media_type,
                data = image_base64
              )
            ),
            list(
              type = "text",
              text = prompt
            )
          )
        )
      )
    )
    
    # Make API request
    response <- httr2::request("https://api.anthropic.com/v1/messages") %>%
      httr2::req_headers(
        "x-api-key" = api_key,
        "anthropic-version" = "2023-06-01",
        "content-type" = "application/json"
      ) %>%
      httr2::req_body_json(body) %>%
      httr2::req_timeout(60) %>%
      httr2::req_retry(max_tries = 2) %>%
      httr2::req_error(is_error = function(resp) FALSE) %>%
      httr2::req_perform()
    
    # Check response status
    if (httr2::resp_status(response) != 200) {
      error_body <- httr2::resp_body_json(response)
      error_msg <- if (!is.null(error_body$error$message)) {
        error_body$error$message
      } else {
        paste("API error with status", httr2::resp_status(response))
      }
      
      return(list(
        success = FALSE,
        content = NULL,
        error = error_msg,
        status_code = httr2::resp_status(response)
      ))
    }
    
    # Parse response
    result <- httr2::resp_body_json(response)
    
    # Extract text content
    if (!is.null(result$content) && length(result$content) > 0) {
      text_content <- result$content[[1]]$text
      
      return(list(
        success = TRUE,
        content = text_content,
        model = result$model,
        usage = result$usage,
        error = NULL
      ))
    } else {
      return(list(
        success = FALSE,
        content = NULL,
        error = "No content in API response"
      ))
    }
    
  }, error = function(e) {
    # Enhanced error reporting with more context
    error_details <- list(
      message = e$message,
      class = class(e),
      call = deparse(e$call)
    )

    # Try to extract more specific error information
    detailed_error <- if (inherits(e, "httr2_http")) {
      # HTTP-specific error
      sprintf("HTTP Error: %s (Status: %s)", e$message, e$status %||% "unknown")
    } else if (grepl("timeout", e$message, ignore.case = TRUE)) {
      sprintf("Request Timeout: %s (Check internet connection or increase timeout)", e$message)
    } else if (grepl("api[_-]?key", e$message, ignore.case = TRUE)) {
      sprintf("API Key Error: %s (Check Settings tab for valid API key)", e$message)
    } else if (grepl("host|resolve|connect", e$message, ignore.case = TRUE)) {
      sprintf("Network Error: %s (Check internet connection)", e$message)
    } else {
      sprintf("Claude API Error: %s\nType: %s\nCall: %s",
              e$message,
              paste(class(e), collapse = ", "),
              paste(deparse(e$call), collapse = " "))
    }

    # Log full error details to console for debugging
    cat("\n❌ DETAILED ERROR:\n")
    cat("   Message:", e$message, "\n")
    cat("   Class:", paste(class(e), collapse = ", "), "\n")
    cat("   Call:", paste(deparse(e$call), collapse = " "), "\n")
    if (!is.null(e$parent)) {
      cat("   Parent error:", e$parent$message, "\n")
    }

    return(list(
      success = FALSE,
      content = NULL,
      error = detailed_error,
      error_details = error_details
    ))
  })
}

#' Call OpenAI API for Image Analysis
#' 
#' @param image_path Path to the image file
#' @param model_name OpenAI model name (e.g., "gpt-4o")
#' @param api_key OpenAI API key
#' @param prompt Text prompt for image analysis
#' @param temperature Sampling temperature (0-1)
#' @param max_tokens Maximum tokens in response
#' 
#' @return List with success, content, and error information
#' @noRd
call_openai_api <- function(image_path, model_name, api_key, prompt, temperature = 0.7, max_tokens = 1000) {
  
  # Validate inputs
  if (is.null(api_key) || api_key == "") {
    return(list(
      success = FALSE,
      content = NULL,
      error = "OpenAI API key not configured"
    ))
  }
  
  if (!file.exists(image_path)) {
    return(list(
      success = FALSE,
      content = NULL,
      error = paste("Image file not found:", image_path)
    ))
  }
  
  tryCatch({
    # Compress image if needed (OpenAI also has size limits)
    # Base64 increases size by ~33%, so target 3.7 MB to stay under 5 MB after encoding
    processed_image_path <- compress_image_if_needed(image_path, max_size_mb = 3.7)
    
    # Read and encode image as base64
    image_data <- readBin(processed_image_path, "raw", file.info(processed_image_path)$size)
    image_base64 <- base64enc::base64encode(image_data)
    
    # Clean up temporary compressed file if created
    if (processed_image_path != image_path && file.exists(processed_image_path)) {
      unlink(processed_image_path)
    }
    
    # Determine media type from file extension
    ext <- tolower(tools::file_ext(image_path))
    media_type <- switch(ext,
      "jpg" = "image/jpeg",
      "jpeg" = "image/jpeg",
      "png" = "image/png",
      "gif" = "image/gif",
      "webp" = "image/webp",
      "image/jpeg" # default
    )
    
    # Construct data URL for OpenAI
    data_url <- paste0("data:", media_type, ";base64,", image_base64)
    
    # Construct request body
    body <- list(
      model = model_name,
      max_tokens = as.integer(max_tokens),
      temperature = as.numeric(temperature),
      messages = list(
        list(
          role = "user",
          content = list(
            list(
              type = "text",
              text = prompt
            ),
            list(
              type = "image_url",
              image_url = list(
                url = data_url
              )
            )
          )
        )
      )
    )
    
    # Make API request
    response <- httr2::request("https://api.openai.com/v1/chat/completions") %>%
      httr2::req_headers(
        "Authorization" = paste("Bearer", api_key),
        "Content-Type" = "application/json"
      ) %>%
      httr2::req_body_json(body) %>%
      httr2::req_timeout(60) %>%
      httr2::req_retry(max_tries = 2) %>%
      httr2::req_error(is_error = function(resp) FALSE) %>%
      httr2::req_perform()
    
    # Check response status
    if (httr2::resp_status(response) != 200) {
      error_body <- httr2::resp_body_json(response)
      error_msg <- if (!is.null(error_body$error$message)) {
        error_body$error$message
      } else {
        paste("API error with status", httr2::resp_status(response))
      }
      
      return(list(
        success = FALSE,
        content = NULL,
        error = error_msg,
        status_code = httr2::resp_status(response)
      ))
    }
    
    # Parse response
    result <- httr2::resp_body_json(response)
    
    # Extract text content
    if (!is.null(result$choices) && length(result$choices) > 0) {
      text_content <- result$choices[[1]]$message$content
      
      return(list(
        success = TRUE,
        content = text_content,
        model = result$model,
        usage = result$usage,
        error = NULL
      ))
    } else {
      return(list(
        success = FALSE,
        content = NULL,
        error = "No content in API response"
      ))
    }
    
  }, error = function(e) {
    # Enhanced error reporting with more context
    error_details <- list(
      message = e$message,
      class = class(e),
      call = deparse(e$call)
    )

    # Try to extract more specific error information
    detailed_error <- if (inherits(e, "httr2_http")) {
      # HTTP-specific error
      sprintf("HTTP Error: %s (Status: %s)", e$message, e$status %||% "unknown")
    } else if (grepl("timeout", e$message, ignore.case = TRUE)) {
      sprintf("Request Timeout: %s (Check internet connection or increase timeout)", e$message)
    } else if (grepl("api[_-]?key", e$message, ignore.case = TRUE)) {
      sprintf("API Key Error: %s (Check Settings tab for valid API key)", e$message)
    } else if (grepl("host|resolve|connect", e$message, ignore.case = TRUE)) {
      sprintf("Network Error: %s (Check internet connection)", e$message)
    } else {
      sprintf("OpenAI API Error: %s\nType: %s\nCall: %s",
              e$message,
              paste(class(e), collapse = ", "),
              paste(deparse(e$call), collapse = " "))
    }

    # Log full error details to console for debugging
    cat("\n❌ DETAILED ERROR:\n")
    cat("   Message:", e$message, "\n")
    cat("   Class:", paste(class(e), collapse = ", "), "\n")
    cat("   Call:", paste(deparse(e$call), collapse = " "), "\n")
    if (!is.null(e$parent)) {
      cat("   Parent error:", e$parent$message, "\n")
    }

    return(list(
      success = FALSE,
      content = NULL,
      error = detailed_error,
      error_details = error_details
    ))
  })
}

#' Get Model Display Name
#' 
#' @param model_id Model identifier string
#' @return Human-readable model name
#' @noRd
get_model_display_name <- function(model_id) {
  model_names <- list(
    "claude-sonnet-4-20250514" = "Claude Sonnet 4",
    "claude-sonnet-4-5-20250929" = "Claude Sonnet 4.5",
    "claude-opus-4-20250514" = "Claude Opus 4",
    "claude-opus-4-1-20250514" = "Claude Opus 4.1",
    "gpt-4o" = "GPT-4o",
    "gpt-4o-mini" = "GPT-4o Mini",
    "gpt-4-turbo" = "GPT-4 Turbo",
    "gpt-4" = "GPT-4"
  )
  
  display_name <- model_names[[model_id]]
  if (is.null(display_name)) {
    return(model_id)  # Return original if not found
  }
  return(display_name)
}

#' Build Postal Card Analysis Prompt
#' 
#' @param extraction_type "individual" or "lot"
#' @param card_count Number of cards (for lot type)
#' @return Formatted prompt string
#' @noRd
build_postal_card_prompt <- function(extraction_type = "individual", card_count = 1) {
  
  base_prompt <- "You are an expert postal history analyst and vintage postcard appraiser. Analyze this image carefully and provide:\n\n"
  
  if (extraction_type == "lot") {
    prompt <- paste0(base_prompt,
      "1. A concise TITLE (max 80 characters) suitable for an online auction listing\n",
      "2. A detailed DESCRIPTION (150-300 words) including:\n",
      "   - Overall theme or collection type\n",
      "   - Notable cards or highlights\n",
      "   - Approximate time period(s)\n",
      "   - General condition assessment\n",
      "   - Historical significance or collecting value\n",
      "   - Any visible text, postmarks, or identifying marks\n\n",
      "Note: This is a lot of ", card_count, " postal cards.\n\n",
      "Format your response EXACTLY as:\n",
      "TITLE: [your title here]\n",
      "DESCRIPTION: [your description here]"
    )
  } else {
    prompt <- paste0(base_prompt,
      "1. A concise TITLE (max 80 characters) suitable for an online auction listing\n",
      "2. A detailed DESCRIPTION (150-300 words) including:\n",
      "   - Subject matter and scene depicted\n",
      "   - Approximate date or era\n",
      "   - Location (if identifiable)\n",
      "   - Condition (mint/used/damaged)\n",
      "   - Any visible text, postmarks, stamps, or messages\n",
      "   - Publisher or printer (if visible)\n",
      "   - Historical or collecting significance\n",
      "   - Notable details or features\n\n",
      "Format your response EXACTLY as:\n",
      "TITLE: [your title here]\n",
      "DESCRIPTION: [your description here]"
    )
  }
  
  return(prompt)
}

#' Build Enhanced Postal Card Prompt with Price Recommendation
#' 
#' @param extraction_type "individual" or "lot" 
#' @param card_count Number of cards (for lot type)
#' @return Formatted prompt string with price recommendation
#' @noRd
build_enhanced_postal_card_prompt <- function(extraction_type = "individual", card_count = 1) {
  
  # CRITICAL: ASCII-only instruction at the top
  ascii_instruction <- "IMPORTANT: Use ONLY ASCII characters in your output. Replace all diacritics:
- Romanian: ă→a, â→a, î→i, ș→s, ț→t
- European: é→e, è→e, ü→u, ö→o, ñ→n, ç→c
- Examples: București → Bucuresti, Buziaș → Buzias, café → cafe, Timișoara → Timisoara

"
  
  base_prompt <- "You are an expert postal history analyst and vintage postcard appraiser. Analyze this image carefully and provide:\n\n"
  
  if (extraction_type == "lot") {
    prompt <- paste0(ascii_instruction, base_prompt,
      "IMPORTANT: This is a lot of ", card_count, " postal cards.\n",
      "The image shows BOTH SIDES of each card:\n",
      "- TOP ROW: Front/face sides (", card_count, " images)\n",
      "- BOTTOM ROW: Back/verso sides (", card_count, " images)\n",
      "- TOTAL POSTCARDS: ", card_count, " (not ", card_count * 2, "!)\n\n",

      "REQUIRED FIELDS:\n\n",
      "1. TITLE: eBay-optimized title (MAXIMUM 80 characters)\n",
      "   - ALL UPPERCASE format\n",
      "   - Use dashes (-) to separate sections\n",
      "   - ASCII only (e.g., Buzias not Buziaș)\n",
      "   - Element order: COUNTRY - YEAR TYPE LOCATION FEATURES\n",
      "   - Front-load important search terms (country, year, city)\n",
      "   - Include special features: PERFIN, OVERPRINT, CANCELLATION\n",
      "   - No articles (a, an, the) or filler words\n",
      "   - Examples:\n",
      "     * 'AUSTRIA - 1912 PARCEL POST ROMANIA REICHENBERG PERFIN REVENUE'\n",
      "     * 'ROMANIA - POSTAL HISTORY LOT FERDINAND ARAD FOCSANI IASI'\n",
      "     * 'FRANCE - 1920s PARIS VIEWS EIFFEL TOWER NOTRE DAME LOT 5'\n\n",

      "2. DESCRIPTION: Detailed description (150-300 characters, ASCII only)\n",
      "   - Overall theme or collection type\n",
      "   - Notable cards or highlights\n",
      "   - Approximate time period(s)\n",
      "   - Visible characteristics (colors, printing style)\n",
      "   - Historical significance or collecting value\n",
      "   - DO NOT assess condition - seller will determine that\n\n",

      "3. RECOMMENDED_PRICE: Suggest eBay sale price in US Dollars (USD)\n",
      "   - Price for ALL ", card_count, " postcards combined\n",
      "   - Typical range per card: $2.00 - $12.00\n",
      "   - Format: numeric value only (e.g., 15.00 for 3 cards at $5 each)\n\n",

      "EBAY METADATA (extract from most prominent/clear card):\n",
      "IMPORTANT: These fields improve eBay search ranking - extract when visible!\n\n",

      "4. YEAR: Year visible on any postcard or postmark (e.g., 1957)\n",
      "   - Look carefully at postmarks, printed dates\n",
      "   - If multiple years visible, use earliest\n",
      "   - If not visible, omit this field\n\n",

      "5. ERA: Postcard era (only if year is determined)\n",
      "   - pre-1907: Undivided Back\n",
      "   - 1907-1915: Divided Back\n",
      "   - 1930-1945: Linen\n",
      "   - 1939+: Chrome\n\n",

      "6. CITY: City/town name visible (ASCII only, e.g., Buzias not Buziaș)\n",
      "   - Extract from visible text, labels, or postmarks\n",
      "   - If multiple cities, use most prominent\n",
      "   - VERY IMPORTANT for eBay collectors\n\n",

      "7. COUNTRY: Country name (e.g., Romania, France, Germany)\n",
      "   - Extract from text or identify from landmarks/language\n",
      "   - If multiple countries, use most prominent\n\n",

      "8. REGION: State/region/county if visible (ASCII only, e.g., Timis County not Timiș)\n\n",

      "9. THEME_KEYWORDS: Keywords for theme detection (e.g., view, town, church, landscape)\n",
      "   - Use 2-4 keywords that describe the overall collection theme\n\n",

      "Provide response in this EXACT format:\n",
      "TITLE: [title here]\n",
      "DESCRIPTION: [description here]\n",
      "PRICE: [numeric value]\n",
      "YEAR: [year or omit if not visible]\n",
      "ERA: [era or omit if no year]\n",
      "CITY: [city or omit if not visible]\n",
      "COUNTRY: [country or omit if not visible]\n",
      "REGION: [region or omit if not visible]\n",
      "THEME_KEYWORDS: [keywords or omit if not identifiable]"
    )
  } else if (extraction_type == "combined") {
    # Combined face+verso image
    prompt <- paste0(ascii_instruction, base_prompt,
      "IMPORTANT: This image shows ONE postcard with BOTH SIDES:\n",
      "- Left side: Face (front showing the picture/view)\n",
      "- Right side: Verso (back showing the address/message area)\n",
      "You are analyzing 1 postcard, not 2 separate cards.\n\n",

      "Analyze this single postcard.\n\n",
      "REQUIRED FIELDS:\n\n",
      "1. TITLE: eBay-optimized title (MAXIMUM 80 characters)\n",
      "   - ALL UPPERCASE format\n",
      "   - Use dashes (-) to separate sections\n",
      "   - ASCII only (e.g., Buzias not Buziaș)\n",
      "   - Element order: COUNTRY - YEAR TYPE LOCATION FEATURES\n",
      "   - Front-load important search terms (country, year, city)\n",
      "   - Extract from BOTH face and verso sides\n",
      "   - Include postmarks, cancellations, visible routes\n",
      "   - No articles (a, an, the) or filler words\n",
      "   - Examples:\n",
      "     * 'ROMANIA - 1905 BUZIAS TIMIS POSTMARK UNDIVIDED BACK BATHS'\n",
      "     * 'AUSTRIA - 1910 WIEN RINGSTRASSE TRAM POSTED PRAGUE'\n",
      "     * 'GERMANY - 1935 BERLIN OLYMPIC POSTMARKS HITLER ERA'\n\n",
      "2. DESCRIPTION: Detailed description (150-300 characters, ASCII only)\n",
      "   - Describe ALL cards visible\n",
      "   - Note any visible text, postmarks, or landmarks\n",
      "   - Mention visible characteristics (colors, clarity, printing style)\n",
      "   - Historical context if applicable\n",
      "   - DO NOT assess condition - seller will determine that\n\n",
      "3. RECOMMENDED_PRICE: Suggest eBay sale price in US Dollars (USD)\n",
      "   - Count ALL postcards in the image\n",
      "   - Price per card: $2.00 - $12.00 depending on age/rarity\n",
      "   - Format: numeric value only (e.g., 15.00 for 3 cards at $5 each)\n\n",
      "EBAY METADATA (OPTIONAL - from the most prominent/clear card):\n\n",
      "5. YEAR: Year visible on postcard or postmark (e.g., 1957)\n",
      "6. ERA: Postcard era (pre-1907: Undivided Back, 1907-1915: Divided Back, 1930-1945: Linen, 1939+: Chrome)\n",
      "7. CITY: City/town name visible (ASCII only, e.g., Buzias not Buziaș)\n",
      "8. COUNTRY: Country name (e.g., Romania)\n",
      "9. REGION: State/region/county if visible (ASCII only)\n",
      "10. THEME_KEYWORDS: Keywords for theme detection (e.g., view, town, church)\n\n",
      "Provide response in this EXACT format:\n",
      "TITLE: [title here]\n",
      "DESCRIPTION: [description here]\n",
      "PRICE: [numeric value]\n",
      "YEAR: [year or omit if not visible]\n",
      "ERA: [era or omit if no year]\n",
      "CITY: [city or omit if not visible]\n",
      "COUNTRY: [country or omit if not visible]\n",
      "REGION: [region or omit if not visible]\n",
      "THEME_KEYWORDS: [keywords or omit if not identifiable]"
    )
  } else {
    # Individual image
    prompt <- paste0(ascii_instruction, base_prompt,
      "REQUIRED FIELDS:\n\n",
      "1. TITLE: eBay-optimized title (MAXIMUM 80 characters)\n",
      "   - ALL UPPERCASE format\n",
      "   - Use dashes (-) to separate sections\n",
      "   - ASCII only (e.g., Buzias not Buziaș)\n",
      "   - Element order: COUNTRY - YEAR TYPE LOCATION FEATURES\n",
      "   - Front-load important search terms (country, year, city)\n",
      "   - Look for postmarks, cancellations, special markings\n",
      "   - Include visible postal routes or destinations\n",
      "   - No articles (a, an, the) or filler words\n",
      "   - Examples:\n",
      "     * 'ROMANIA - 1905 BUZIAS TIMIS POSTMARK UNDIVIDED BACK BATHS'\n",
      "     * 'FRANCE - 1898 EXPOSITION UNIVERSELLE EIFFEL TOWER EARLY'\n",
      "     * 'AUSTRIA - 1910 WIEN VIENNA RINGSTRASSE TRAM POSTED PRAGUE'\n\n",
      "2. DESCRIPTION: Detailed description (150-300 characters, ASCII only)\n",
      "   - Describe the scene/subject\n",
      "   - Note any visible text or landmarks\n",
      "   - Mention visible characteristics (colors, clarity, printing style)\n",
      "   - Historical context if applicable\n",
      "   - DO NOT assess condition - seller will determine that\n\n",
      "3. RECOMMENDED_PRICE: Suggest eBay sale price in US Dollars (USD)\n",
      "   - Consider age (older = more valuable)\n",
      "   - Consider subject (tourist landmarks > generic scenes)\n",
      "   - Consider printing quality visible in image\n",
      "   - Typical range: $2.00 - $12.00\n",
      "   - Format: numeric value only (e.g., 3.50)\n\n",
      "EBAY METADATA (OPTIONAL - provide if visible on postcard):\n\n",
      "5. YEAR: Year visible on postcard or postmark (e.g., 1957)\n",
      "   - Look for postmark dates, printed dates, or visible year text\n",
      "   - If not visible, omit this field\n\n",
      "6. ERA: Postcard era (only if year is present)\n",
      "   - pre-1907: Undivided Back\n",
      "   - 1907-1915: Divided Back\n",
      "   - 1930-1945: Linen\n",
      "   - 1939+: Chrome\n\n",
      "7. CITY: City/town name visible on postcard (ASCII only, e.g., Buzias not Buziaș)\n\n",
      "8. COUNTRY: Country name (e.g., Romania, France, Germany)\n\n",
      "9. REGION: State/region/county if visible (ASCII only, e.g., Timis County not Timiș)\n\n",
      "10. THEME_KEYWORDS: Keywords for theme detection (e.g., view, town, church, landscape, railway)\n\n",
      "Provide response in this EXACT format:\n",
      "TITLE: [title here]\n",
      "DESCRIPTION: [description here]\n",
      "PRICE: [numeric value]\n",
      "YEAR: [year or omit if not visible]\n",
      "ERA: [era or omit if no year]\n",
      "CITY: [city or omit if not visible]\n",
      "COUNTRY: [country or omit if not visible]\n",
      "REGION: [region or omit if not visible]\n",
      "THEME_KEYWORDS: [keywords or omit if not identifiable]"
    )
  }
  
  return(prompt)
}

#' Parse AI Response for Title and Description
#' 
#' @param ai_response Raw text response from AI
#' @return List with title and description
#' @noRd
parse_ai_response <- function(ai_response) {
  
  if (is.null(ai_response) || ai_response == "") {
    return(list(
      title = "",
      description = ""
    ))
  }
  
  # Try to parse structured format first
  title_match <- regexpr("TITLE:\\s*(.+?)(?=\n|$)", ai_response, perl = TRUE)
  desc_match <- regexpr("DESCRIPTION:\\s*(.+?)$", ai_response, perl = TRUE)
  
  if (title_match > 0) {
    # Extract title
    title_start <- attr(title_match, "capture.start")[1]
    title_length <- attr(title_match, "capture.length")[1]
    title <- substr(ai_response, title_start, title_start + title_length - 1)
    title <- trimws(title)
  } else {
    # Fallback: use first line as title
    first_line <- strsplit(ai_response, "\n")[[1]][1]
    title <- trimws(first_line)
    # Limit to 80 characters
    if (nchar(title) > 80) {
      title <- substr(title, 1, 77)
      title <- paste0(title, "...")
    }
  }
  
  if (desc_match > 0) {
    # Extract description
    desc_start <- attr(desc_match, "capture.start")[1]
    desc_length <- attr(desc_match, "capture.length")[1]
    description <- substr(ai_response, desc_start, desc_start + desc_length - 1)
    description <- trimws(description)
  } else {
    # Fallback: use everything after first line
    lines <- strsplit(ai_response, "\n")[[1]]
    if (length(lines) > 1) {
      description <- paste(lines[-1], collapse = "\n")
      description <- trimws(description)
    } else {
      description <- ai_response
    }
  }
  
  return(list(
    title = title,
    description = description
  ))
}

#' Parse Enhanced AI Response with Price and Condition
#' 
#' @param ai_response Raw text response from AI
#' @return List with title, description, condition, and price
#' @noRd
parse_enhanced_ai_response <- function(ai_response) {
  
  if (is.null(ai_response) || ai_response == "") {
    return(list(
      title = "",
      description = "",
      condition = "used",
      price = 2.50,
      year = NULL,
      era = NULL,
      city = NULL,
      country = NULL,
      region = NULL,
      theme_keywords = NULL
    ))
  }
  
  # Extract title
  title_match <- regexpr("TITLE:\\s*(.+?)(?=\\n|$)", ai_response, perl = TRUE)
  if (title_match > 0) {
    title_start <- attr(title_match, "capture.start")[1]
    title_length <- attr(title_match, "capture.length")[1]
    title <- substr(ai_response, title_start, title_start + title_length - 1)
    title <- trimws(title)
  } else {
    # Fallback: use first line
    first_line <- strsplit(ai_response, "\\n")[[1]][1]
    title <- trimws(first_line)
    if (nchar(title) > 80) {
      title <- substr(title, 1, 77)
      title <- paste0(title, "...")
    }
  }
  
  # Extract description (match up to CONDITION or end) - use DOTALL to match newlines
  desc_match <- regexpr("DESCRIPTION:\\s*(.+?)(?=\\nCONDITION:|\\nPRICE:|$)", ai_response, perl = TRUE)
  if (desc_match > 0) {
    desc_start <- attr(desc_match, "capture.start")[1]
    desc_length <- attr(desc_match, "capture.length")[1]
    description <- substr(ai_response, desc_start, desc_start + desc_length - 1)
    description <- trimws(description)
  } else {
    # Fallback: try to find text between DESCRIPTION and CONDITION
    desc_parts <- strsplit(ai_response, "DESCRIPTION:")[[1]]
    if (length(desc_parts) > 1) {
      # Get everything after DESCRIPTION:
      after_desc <- desc_parts[2]
      # Split at CONDITION: if present
      before_condition <- strsplit(after_desc, "\\nCONDITION:")[[1]][1]
      description <- trimws(before_condition)
    } else {
      description <- ""
    }
  }
  
  # Condition: Always default to "used" (seller will manually adjust if needed)
  # AI no longer assesses condition - this is subjective and best determined by seller
  condition <- "used"
  
  # Extract price
  price_match <- regexpr("PRICE:\\s*([0-9]+\\.?[0-9]*)", ai_response, perl = TRUE)
  if (price_match > 0) {
    price_start <- attr(price_match, "capture.start")[1]
    price_length <- attr(price_match, "capture.length")[1]
    price_text <- substr(ai_response, price_start, price_start + price_length - 1)
    price <- as.numeric(trimws(price_text))
    
    # Validate and clamp price to reasonable range
    if (!is.na(price) && price > 0) {
      price <- max(0.50, min(price, 60.00))  # Clamp between $0.50 and $60.00
    } else {
      price <- 2.50  # Default
    }
  } else {
    price <- 2.50  # Default fallback
  }
  
  # Extract optional eBay metadata fields (NULL if not present)
  # Note: AI prompt ensures ASCII-only output, so no diacritic removal needed!
  
  # Extract year
  year_match <- regexpr("YEAR:\\s*([0-9]{4})", ai_response, perl = TRUE)
  year <- if (year_match > 0) {
    year_start <- attr(year_match, "capture.start")[1]
    year_length <- attr(year_match, "capture.length")[1]
    trimws(substr(ai_response, year_start, year_start + year_length - 1))
  } else {
    NULL
  }
  
  # Extract era
  era_match <- regexpr("ERA:\\s*(.+?)(?=\\n|$)", ai_response, perl = TRUE)
  era <- if (era_match > 0) {
    era_start <- attr(era_match, "capture.start")[1]
    era_length <- attr(era_match, "capture.length")[1]
    trimws(substr(ai_response, era_start, era_start + era_length - 1))
  } else {
    NULL
  }
  
  # Extract city
  city_match <- regexpr("CITY:\\s*(.+?)(?=\\n|$)", ai_response, perl = TRUE)
  city <- if (city_match > 0) {
    city_start <- attr(city_match, "capture.start")[1]
    city_length <- attr(city_match, "capture.length")[1]
    trimws(substr(ai_response, city_start, city_start + city_length - 1))
  } else {
    NULL
  }
  
  # Extract country
  country_match <- regexpr("COUNTRY:\\s*(.+?)(?=\\n|$)", ai_response, perl = TRUE)
  country <- if (country_match > 0) {
    country_start <- attr(country_match, "capture.start")[1]
    country_length <- attr(country_match, "capture.length")[1]
    trimws(substr(ai_response, country_start, country_start + country_length - 1))
  } else {
    NULL
  }
  
  # Extract region
  region_match <- regexpr("REGION:\\s*(.+?)(?=\\n|$)", ai_response, perl = TRUE)
  region <- if (region_match > 0) {
    region_start <- attr(region_match, "capture.start")[1]
    region_length <- attr(region_match, "capture.length")[1]
    trimws(substr(ai_response, region_start, region_start + region_length - 1))
  } else {
    NULL
  }
  
  # Extract theme keywords
  theme_match <- regexpr("THEME_KEYWORDS:\\s*(.+?)(?=\\n|$)", ai_response, perl = TRUE)
  theme_keywords <- if (theme_match > 0) {
    theme_start <- attr(theme_match, "capture.start")[1]
    theme_length <- attr(theme_match, "capture.length")[1]
    trimws(substr(ai_response, theme_start, theme_start + theme_length - 1))
  } else {
    NULL
  }
  
  return(list(
    title = title,
    description = description,
    condition = condition,
    price = price,
    year = year,
    era = era,
    city = city,
    country = country,
    region = region,
    theme_keywords = theme_keywords
  ))
}

#' Get Available AI Models
#' 
#' @return Named list of available models grouped by provider
#' @noRd
get_available_models <- function() {
  config <- get_llm_config()
  
  models <- list()
  
  # Claude models (if configured)
  if (!is.null(config$claude_api_key) && config$claude_api_key != "") {
    models$claude <- list(
      "claude-sonnet-4-5-20250929" = "Claude Sonnet 4.5 (Recommended)",
      "claude-sonnet-4-20250514" = "Claude Sonnet 4",
      "claude-opus-4-1-20250514" = "Claude Opus 4.1 (Most Capable)",
      "claude-opus-4-20250514" = "Claude Opus 4"
    )
  }
  
  # OpenAI models (if configured)
  if (!is.null(config$openai_api_key) && config$openai_api_key != "") {
    models$openai <- list(
      "gpt-4o" = "GPT-4o (Fast)",
      "gpt-4o-mini" = "GPT-4o Mini (Economical)",
      "gpt-4-turbo" = "GPT-4 Turbo"
    )
  }
  
  return(models)
}

#' Determine Provider from Model Name
#'
#' @param model_name Model identifier string
#' @return "claude" or "openai"
#' @noRd
get_provider_from_model <- function(model_name) {
  if (grepl("claude", model_name, ignore.case = TRUE)) {
    return("claude")
  } else if (grepl("gpt", model_name, ignore.case = TRUE)) {
    return("openai")
  } else {
    return("claude")  # Default
  }
}

#' Get extraction prompt for combined images
#'
#' @description Returns the prompt for extracting metadata from combined face+verso images
#' @return Character string with the extraction prompt
#' @export
get_extraction_prompt <- function() {
  # Use the existing enhanced prompt for individual cards
  build_enhanced_postal_card_prompt(extraction_type = "individual", card_count = 1)
}

#' Extract metadata with LLM from combined image
#'
#' @description Wrapper function to extract postal card metadata using configured LLM
#' @param image_path Path to the combined image file
#' @param api_key API key for the LLM provider (optional, uses config if not provided)
#' @param model Model name (optional, uses config default if not provided)
#' @param prompt Custom prompt (optional, uses default extraction prompt if not provided)
#' @return List with success status, extracted data (title, description, condition, price), and error info
#' @export
extract_with_llm <- function(image_path, api_key = NULL, model = NULL, prompt = NULL) {

  # Get configuration
  config <- get_llm_config()

  # Use provided values or fall back to config
  if (is.null(model)) {
    model <- config$default_model
  }

  if (is.null(prompt)) {
    prompt <- get_extraction_prompt()
  }

  # Determine provider and get API key
  provider <- get_provider_from_model(model)

  if (is.null(api_key)) {
    if (provider == "claude") {
      api_key <- config$claude_api_key
    } else {
      api_key <- config$openai_api_key
    }
  }

  # Validate API key
  if (is.null(api_key) || api_key == "") {
    return(list(
      success = FALSE,
      title = NULL,
      description = NULL,
      condition = NULL,
      price = NULL,
      model = model,
      error = paste(tools::toTitleCase(provider), "API key not configured")
    ))
  }

  # Call appropriate API
  if (provider == "claude") {
    result <- call_claude_api(
      image_path = image_path,
      model_name = model,
      api_key = api_key,
      prompt = prompt,
      temperature = config$temperature,
      max_tokens = config$max_tokens
    )
  } else {
    result <- call_openai_api(
      image_path = image_path,
      model_name = model,
      api_key = api_key,
      prompt = prompt,
      temperature = config$temperature,
      max_tokens = config$max_tokens
    )
  }

  # Parse response if successful
  if (result$success) {
    parsed <- parse_enhanced_ai_response(result$content)

    return(list(
      success = TRUE,
      title = parsed$title,
      description = parsed$description,
      condition = parsed$condition,
      price = parsed$price,
      model = model,
      error = NULL
    ))
  } else {
    return(list(
      success = FALSE,
      title = NULL,
      description = NULL,
      condition = NULL,
      price = NULL,
      model = model,
      error = result$error
    ))
  }
}
