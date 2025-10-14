#' LLM Tracking System Functions
#'
#' @description Functions for tracking LLM API calls and responses
#' @noRd

#' Calculate image hash for deduplication
#'
#' @param image_path Path to the image file
#'
#' @return Character string with image hash, or NULL if error
#' @noRd
calculate_image_hash <- function(image_path) {
  tryCatch({
    if (!file.exists(image_path)) {
      return(NULL)
    }
    
    # Read file content
    file_content <- readBin(image_path, "raw", file.info(image_path)$size)
    
    # Generate hash using digest
    hash <- digest::digest(file_content, algo = "sha256", serialize = FALSE)
    
    return(hash)
  }, error = function(e) {
    warning(paste("Could not calculate hash for:", image_path, "-", e$message))
    return(NULL)
  })
}

#' Track LLM API Call
#'
#' @description Track each API call to LLM for postal card analysis
#'
#' @param session_id Session identifier
#' @param image_path Path to the image being analyzed
#' @param model Model used for analysis
#' @param prompt_type Type of prompt used ("individual" or "multiple")
#' @param status Status of the API call ("pending", "success", "failed")
#' @param response_data Response data from API (for successful calls)
#' @param error_message Error message (for failed calls)
#' @param tokens_used Number of tokens used in the API call
#' @param processing_time Time taken for the API call
#' @param temperature Temperature used for the API call
#' @param max_tokens Max tokens setting used
#'
#' @return Updated session tracker
#' @export
track_llm_api_call <- function(session_id, image_path, model, prompt_type, status, 
                               response_data = NULL, error_message = NULL, 
                               tokens_used = NULL, processing_time = NULL,
                               temperature = NULL, max_tokens = NULL) {
  # Load existing tracker
  tracker <- load_session_tracker(session_id)
  
  if (is.null(tracker)) {
    warning(paste("Session not found:", session_id, "- creating new tracker"))
    tracker <- create_session_tracker(session_id)
  }
  
  # Initialize llm_api_calls if it doesn't exist
  if (is.null(tracker$llm_api_calls)) {
    tracker$llm_api_calls <- list()
  }
  
  # Create API call record
  api_call_record <- list(
    image_path = image_path,
    model = model,
    prompt_type = prompt_type,
    status = status,
    timestamp = Sys.time(),
    response_data = response_data,
    error_message = error_message,
    tokens_used = tokens_used,
    processing_time = processing_time,
    temperature = temperature,
    max_tokens = max_tokens,
    call_id = paste0("llm_", as.integer(Sys.time()), "_", sample(1000:9999, 1))
  )
  
  # Add to API calls list
  tracker$llm_api_calls <- c(tracker$llm_api_calls, list(api_call_record))
  
  # Update metadata
  tracker$metadata$last_updated <- Sys.time()
  
  # Save tracker
  save_session_tracker(tracker)
  
  message(paste("LLM API call tracked:", model, "-", status, "for", basename(image_path)))
  return(tracker)
}

#' Get LLM API Call History
#'
#' @description Retrieve API call history for a session
#'
#' @param session_id Session identifier
#' @param model Optional filter by model
#' @param status Optional filter by status
#' @param prompt_type Optional filter by prompt type
#'
#' @return List of API call records
#' @export
get_llm_api_call_history <- function(session_id, model = NULL, status = NULL, prompt_type = NULL) {
  tracker <- load_session_tracker(session_id)
  
  if (is.null(tracker) || is.null(tracker$llm_api_calls)) {
    return(list())
  }
  
  api_calls <- tracker$llm_api_calls
  
  # Apply filters
  if (!is.null(model)) {
    api_calls <- api_calls[sapply(api_calls, function(x) x$model == model)]
  }
  
  if (!is.null(status)) {
    api_calls <- api_calls[sapply(api_calls, function(x) x$status == status)]
  }
  
  if (!is.null(prompt_type)) {
    api_calls <- api_calls[sapply(api_calls, function(x) x$prompt_type == prompt_type)]
  }
  
  return(api_calls)
}

#' Get LLM Usage Statistics
#'
#' @description Get usage statistics for LLM API calls
#'
#' @param session_id Session identifier
#'
#' @return List with usage statistics
#' @export
get_llm_usage_stats <- function(session_id) {
  api_calls <- get_llm_api_call_history(session_id)
  
  if (length(api_calls) == 0) {
    return(list(
      total_calls = 0,
      successful_calls = 0,
      failed_calls = 0,
      models_used = character(0),
      prompt_types_used = character(0),
      total_tokens = 0,
      average_processing_time = 0,
      total_processing_time = 0,
      average_temperature = 0,
      average_max_tokens = 0
    ))
  }
  
  successful_calls <- sum(sapply(api_calls, function(x) x$status == "success"))
  failed_calls <- sum(sapply(api_calls, function(x) x$status == "failed"))
  
  models_used <- unique(sapply(api_calls, function(x) x$model))
  prompt_types_used <- unique(sapply(api_calls, function(x) x$prompt_type))
  
  total_tokens <- sum(sapply(api_calls, function(x) x$tokens_used %||% 0))
  
  processing_times <- sapply(api_calls, function(x) x$processing_time %||% 0)
  processing_times <- processing_times[processing_times > 0]
  
  temperatures <- sapply(api_calls, function(x) x$temperature %||% 0)
  temperatures <- temperatures[temperatures > 0]
  
  max_tokens <- sapply(api_calls, function(x) x$max_tokens %||% 0)
  max_tokens <- max_tokens[max_tokens > 0]
  
  return(list(
    total_calls = length(api_calls),
    successful_calls = successful_calls,
    failed_calls = failed_calls,
    models_used = models_used,
    prompt_types_used = prompt_types_used,
    total_tokens = total_tokens,
    average_processing_time = if (length(processing_times) > 0) mean(processing_times) else 0,
    total_processing_time = sum(processing_times),
    average_temperature = if (length(temperatures) > 0) mean(temperatures) else 0,
    average_max_tokens = if (length(max_tokens) > 0) mean(max_tokens) else 0
  ))
}

#' Get LLM Usage Statistics by Model
#'
#' @description Get usage statistics broken down by model
#'
#' @param session_id Session identifier
#'
#' @return List with usage statistics by model
#' @export
get_llm_usage_stats_by_model <- function(session_id) {
  api_calls <- get_llm_api_call_history(session_id)
  
  if (length(api_calls) == 0) {
    return(list())
  }
  
  models <- unique(sapply(api_calls, function(x) x$model))
  
  stats_by_model <- list()
  
  for (model in models) {
    model_calls <- api_calls[sapply(api_calls, function(x) x$model == model)]
    
    successful_calls <- sum(sapply(model_calls, function(x) x$status == "success"))
    failed_calls <- sum(sapply(model_calls, function(x) x$status == "failed"))
    
    total_tokens <- sum(sapply(model_calls, function(x) x$tokens_used %||% 0))
    
    processing_times <- sapply(model_calls, function(x) x$processing_time %||% 0)
    processing_times <- processing_times[processing_times > 0]
    
    stats_by_model[[model]] <- list(
      total_calls = length(model_calls),
      successful_calls = successful_calls,
      failed_calls = failed_calls,
      total_tokens = total_tokens,
      average_processing_time = if (length(processing_times) > 0) mean(processing_times) else 0,
      total_processing_time = sum(processing_times)
    )
  }
  
  return(stats_by_model)
}

#' Get Recent LLM API Calls
#'
#' @description Get recent API calls for a session
#'
#' @param session_id Session identifier
#' @param hours_back Number of hours to look back (default: 24)
#' @param limit Maximum number of calls to return (default: 50)
#'
#' @return List of recent API call records
#' @export
get_recent_llm_api_calls <- function(session_id, hours_back = 24, limit = 50) {
  api_calls <- get_llm_api_call_history(session_id)
  
  if (length(api_calls) == 0) {
    return(list())
  }
  
  # Filter by time
  cutoff_time <- Sys.time() - (hours_back * 3600)
  recent_calls <- api_calls[sapply(api_calls, function(x) {
    call_time <- x$timestamp
    !is.null(call_time) && call_time >= cutoff_time
  })]
  
  # Sort by timestamp (most recent first)
  recent_calls <- recent_calls[order(sapply(recent_calls, function(x) x$timestamp), decreasing = TRUE)]
  
  # Apply limit
  if (length(recent_calls) > limit) {
    recent_calls <- recent_calls[1:limit]
  }
  
  return(recent_calls)
}

#' Clear LLM API Call History
#'
#' @description Clear API call history for a session
#'
#' @param session_id Session identifier
#' @param older_than_hours Optional: only clear calls older than this many hours
#'
#' @return Updated session tracker
#' @export
clear_llm_api_call_history <- function(session_id, older_than_hours = NULL) {
  tracker <- load_session_tracker(session_id)
  
  if (is.null(tracker) || is.null(tracker$llm_api_calls)) {
    return(tracker)
  }
  
  if (is.null(older_than_hours)) {
    # Clear all API calls
    tracker$llm_api_calls <- list()
  } else {
    # Clear only older calls
    cutoff_time <- Sys.time() - (older_than_hours * 3600)
    tracker$llm_api_calls <- tracker$llm_api_calls[sapply(tracker$llm_api_calls, function(x) {
      call_time <- x$timestamp
      !is.null(call_time) && call_time >= cutoff_time
    })]
  }
  
  # Update metadata
  tracker$metadata$last_updated <- Sys.time()
  
  # Save tracker
  save_session_tracker(tracker)
  
  message(paste("LLM API call history cleared for session:", session_id))
  return(tracker)
}

#' Export LLM API Call History
#'
#' @description Export API call history to CSV
#'
#' @param session_id Session identifier
#' @param output_file Output file path
#' @param model Optional filter by model
#' @param status Optional filter by status
#'
#' @return Logical indicating success
#' @export
export_llm_api_call_history <- function(session_id, output_file, model = NULL, status = NULL) {
  api_calls <- get_llm_api_call_history(session_id, model = model, status = status)
  
  if (length(api_calls) == 0) {
    warning("No API calls found for export")
    return(FALSE)
  }
  
  tryCatch({
    # Convert to data frame
    df <- data.frame(
      call_id = sapply(api_calls, function(x) x$call_id %||% ""),
      timestamp = sapply(api_calls, function(x) format(x$timestamp %||% Sys.time())),
      image_path = sapply(api_calls, function(x) x$image_path %||% ""),
      model = sapply(api_calls, function(x) x$model %||% ""),
      prompt_type = sapply(api_calls, function(x) x$prompt_type %||% ""),
      status = sapply(api_calls, function(x) x$status %||% ""),
      tokens_used = sapply(api_calls, function(x) x$tokens_used %||% 0),
      processing_time = sapply(api_calls, function(x) x$processing_time %||% 0),
      temperature = sapply(api_calls, function(x) x$temperature %||% 0),
      max_tokens = sapply(api_calls, function(x) x$max_tokens %||% 0),
      error_message = sapply(api_calls, function(x) x$error_message %||% ""),
      stringsAsFactors = FALSE
    )
    
    # Write to CSV
    write.csv(df, output_file, row.names = FALSE)
    
    message(paste("LLM API call history exported to:", output_file))
    return(TRUE)
  }, error = function(e) {
    warning(paste("Error exporting LLM API call history:", e$message))
    return(FALSE)
  })
}

#' Get LLM API Call by ID
#'
#' @description Get a specific API call by its ID
#'
#' @param session_id Session identifier
#' @param call_id Call ID to retrieve
#'
#' @return API call record, or NULL if not found
#' @export
get_llm_api_call_by_id <- function(session_id, call_id) {
  api_calls <- get_llm_api_call_history(session_id)
  
  for (api_call in api_calls) {
    if (!is.null(api_call$call_id) && api_call$call_id == call_id) {
      return(api_call)
    }
  }
  
  return(NULL)
}

#' Get LLM API Call Summary
#'
#' @description Get a formatted summary of API call statistics
#'
#' @param session_id Session identifier
#'
#' @return Character vector with formatted summary
#' @export
get_llm_api_call_summary <- function(session_id) {
  stats <- get_llm_usage_stats(session_id)
  
  if (stats$total_calls == 0) {
    return("No LLM API calls found for this session.")
  }
  
  summary_lines <- c()
  summary_lines <- c(summary_lines, paste("Total API calls:", stats$total_calls))
  summary_lines <- c(summary_lines, paste("Successful calls:", stats$successful_calls))
  
  if (stats$failed_calls > 0) {
    summary_lines <- c(summary_lines, paste("Failed calls:", stats$failed_calls))
  }
  
  if (length(stats$models_used) > 0) {
    summary_lines <- c(summary_lines, paste("Models used:", paste(stats$models_used, collapse = ", ")))
  }
  
  if (length(stats$prompt_types_used) > 0) {
    summary_lines <- c(summary_lines, paste("Prompt types used:", paste(stats$prompt_types_used, collapse = ", ")))
  }
  
  if (stats$total_tokens > 0) {
    summary_lines <- c(summary_lines, paste("Total tokens used:", stats$total_tokens))
  }
  
  if (stats$average_processing_time > 0) {
    summary_lines <- c(summary_lines, paste("Average processing time:", round(stats$average_processing_time, 2), "seconds"))
  }
  
  if (stats$total_processing_time > 0) {
    summary_lines <- c(summary_lines, paste("Total processing time:", round(stats$total_processing_time, 2), "seconds"))
  }
  
  return(summary_lines)
}
