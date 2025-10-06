#' Helper Utilities
#'
#' @description Collection of utility functions used across modules
#' @noRd
NULL

#' Get LLM Configuration
#' @description Returns default LLM configuration if no settings module available
#' @noRd
get_llm_config <- function() {
  # Default configuration - will be overridden by settings module
  return(list(
    default_model = "claude-sonnet-4-20250514",
    temperature = 0.7,
    max_tokens = 1000,
    claude_api_key = Sys.getenv("CLAUDE_API_KEY", ""),
    openai_api_key = Sys.getenv("OPENAI_API_KEY", "")
  ))
}

#' Safe Session ID
#' @description Get a safe session ID for database operations
#' @param session Shiny session object
#' @noRd
safe_session_id <- function(session) {
  if (is.null(session) || is.null(session$token)) {
    return("unknown_session")
  }
  return(session$token)
}

#' Update Delcampe Status
#' @description Update the status of Delcampe export operations
#' @param session_id Session identifier
#' @param image_path Path to the image
#' @param new_status New status to set
#' @param error_message Optional error message
#' @noRd
update_delcampe_status <- function(session_id, image_path, new_status, error_message = NULL) {
  # Stub implementation - will be connected to actual database later
  cat("Delcampe status update:", new_status, "for", basename(image_path), "\n")
}