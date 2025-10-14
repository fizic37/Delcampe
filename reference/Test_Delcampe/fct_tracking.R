# File: R/fct_tracking.R
# Business logic functions for tracking modules (golem pattern)

#' Calculate Session Statistics
#' 
#' Processes session data from SQLite database and calculates meaningful stats
#' @param session_data Session data from query_sessions() or session_id
#' @return List with calculated statistics
#' @export
calculate_session_stats <- function(session_data) {
  
  # Handle different input types
  if (is.null(session_data) || length(session_data) == 0) {
    return(create_empty_session_stats())
  }
  
  # Extract session_id based on input type
  if (is.data.frame(session_data) && nrow(session_data) == 1) {
    session_id <- session_data$session_id[1]
  } else if (is.data.frame(session_data) && "session_id" %in% colnames(session_data)) {
    session_id <- session_data$session_id[1]
  } else if (is.character(session_data)) {
    session_id <- session_data[1]
  } else if (is.list(session_data) && "session_id" %in% names(session_data)) {
    session_id <- session_data$session_id
  } else {
    # Legacy format or unknown - return empty stats
    return(create_empty_session_stats())
  }
  
  # Query detailed session information from database
  tryCatch({
    con <- get_tracking_db()
    on.exit(DBI::dbDisconnect(con))
    
    # Get images for this session
    images <- DBI::dbGetQuery(con, "
      SELECT 
        image_type,
        processing_status,
        sent_to_delcampe,
        delcampe_status,
        ai_extracted
      FROM images 
      WHERE session_id = ?
    ", list(session_id))
    
    # Calculate statistics
    has_face <- any(grepl("face", images$image_type, ignore.case = TRUE))
    has_verso <- any(grepl("verso", images$image_type, ignore.case = TRUE))
    
    face_crops <- sum(grepl("face", images$image_type, ignore.case = TRUE) & 
                      images$processing_status == "processed")
    verso_crops <- sum(grepl("verso", images$image_type, ignore.case = TRUE) & 
                       images$processing_status == "processed")
    
    delcampe_sent <- sum(images$sent_to_delcampe == 1, na.rm = TRUE)
    delcampe_pending <- sum(!is.na(images$delcampe_status) & 
                            images$delcampe_status == "pending", na.rm = TRUE)
    delcampe_failed <- sum(!is.na(images$delcampe_status) & 
                           images$delcampe_status == "failed", na.rm = TRUE)
    
    # Get LLM statistics
    ai_extractions <- sum(images$ai_extracted == 1, na.rm = TRUE)
    
    return(list(
      has_face = has_face,
      has_verso = has_verso,
      face_crops = face_crops,
      verso_crops = verso_crops,
      delcampe_sent = delcampe_sent,
      delcampe_pending = delcampe_pending,
      delcampe_failed = delcampe_failed,
      llm_calls = ai_extractions,
      llm_success = ai_extractions
    ))
    
  }, error = function(e) {
    message("Error calculating session stats for session ", session_id, ": ", e$message)
    return(create_empty_session_stats())
  })
}

#' Create Empty Session Stats
#' @return List with empty statistics
create_empty_session_stats <- function() {
  list(
    has_face = FALSE,
    has_verso = FALSE,
    face_crops = 0,
    verso_crops = 0,
    delcampe_sent = 0,
    delcampe_pending = 0,
    delcampe_failed = 0,
    llm_calls = 0,
    llm_success = 0
  )
}

#' Calculate Overall Tracking Statistics
#' 
#' Calculates meaningful statistics across all sessions
#' @return List with overall statistics
#' @export
calculate_overall_stats <- function() {
  
  tryCatch({
    con <- get_tracking_db()
    on.exit(DBI::dbDisconnect(con))
    
    # Get overall statistics from database
    overall_stats <- DBI::dbGetQuery(con, "
      SELECT 
        COUNT(DISTINCT s.session_id) as total_sessions,
        COUNT(DISTINCT s.user_id) as unique_users,
        COUNT(DISTINCT i.image_id) as total_images,
        COUNT(DISTINCT CASE WHEN i.image_type LIKE '%face%' THEN i.image_id END) as face_images,
        COUNT(DISTINCT CASE WHEN i.image_type LIKE '%verso%' THEN i.image_id END) as verso_images,
        COUNT(DISTINCT CASE WHEN i.sent_to_delcampe = 1 THEN i.image_id END) as delcampe_sent,
        COUNT(DISTINCT CASE WHEN i.ai_extracted = 1 THEN i.image_id END) as ai_extractions,
        COUNT(DISTINCT CASE WHEN s.status = 'active' THEN s.session_id END) as active_sessions
      FROM sessions s
      LEFT JOIN images i ON s.session_id = i.session_id
    ")
    
    if (nrow(overall_stats) == 0) {
      overall_stats <- data.frame(
        total_sessions = 0, unique_users = 0, total_images = 0,
        face_images = 0, verso_images = 0, delcampe_sent = 0,
        ai_extractions = 0, active_sessions = 0
      )
    }
    
    return(list(
      total_sessions = overall_stats$total_sessions[1] %||% 0,
      unique_users = overall_stats$unique_users[1] %||% 0,
      unique_images_uploaded = (overall_stats$face_images[1] %||% 0) + (overall_stats$verso_images[1] %||% 0),
      combined_images_generated = 0, # Will be calculated separately if needed
      delcampe_sent = overall_stats$delcampe_sent[1] %||% 0,
      active_sessions = overall_stats$active_sessions[1] %||% 0,
      completion_rate = 0,
      llm_api_calls = overall_stats$ai_extractions[1] %||% 0,
      llm_success_rate = 100,
      ai_extractions = overall_stats$ai_extractions[1] %||% 0
    ))
    
  }, error = function(e) {
    message("Error calculating overall stats: ", e$message)
    return(list(
      total_sessions = 0,
      unique_users = 0,
      unique_images_uploaded = 0,
      combined_images_generated = 0,
      delcampe_sent = 0,
      active_sessions = 0,
      completion_rate = 0,
      llm_api_calls = 0,
      llm_success_rate = 0,
      ai_extractions = 0
    ))
  })
}

