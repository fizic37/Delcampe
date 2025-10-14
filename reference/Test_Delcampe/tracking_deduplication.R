#' Image Deduplication and Reuse Functions
#'
#' @description Functions to detect duplicate images and reuse existing processing results
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
    
    # Try different approaches for hashing
    
    # Method 1: File-based hash (fast but sensitive to metadata changes)
    file_hash <- digest::digest(file = image_path, algo = "sha256")
    
    # Method 2: Image content hash (slower but more robust for identical visual content)
    # This requires the image to be loaded and processed
    content_hash <- tryCatch({
      img <- magick::image_read(image_path)
      # Normalize the image to remove metadata and minor variations
      img <- magick::image_resize(img, "100x100!")  # Resize to standard size
      img <- magick::image_modulate(img, brightness = 100, saturation = 100, hue = 100)  # Normalize
      img <- magick::image_convert(img, "png")  # Standard format
      
      # Get raw image data and hash it
      img_data <- magick::image_data(img, channels = "rgb")
      digest::digest(img_data, algo = "md5")
    }, error = function(e) {
      # If content hashing fails, use file info as backup
      info <- file.info(image_path)
      paste0("fileinfo_", info$size, "_", as.numeric(info$mtime))
    })
    
    # Combine both hashes for more robust matching
    paste0(file_hash, "_", content_hash)
    
  }, error = function(e) {
    warning(paste("Could not calculate image hash for:", image_path, "-", e$message))
    return(NULL)
  })
}

#' Find existing processing results for an image
#'
#' @param image_hash Hash of the image to search for
#' @param image_type Type of image ("face" or "verso")
#'
#' @return List with existing session info and file paths, or NULL if not found
#' @noRd
find_existing_processing <- function(image_hash, image_type) {
  if (is.null(image_hash)) {
    return(NULL)
  }
  
  tryCatch({
    # Load all tracking data
    data <- load_tracking_data()
    
    # Collect all matching sessions
    matching_sessions <- list()
    
    # Search through all sessions for matching image hash
    for (session_id in names(data$sessions)) {
      session <- data$sessions[[session_id]]
      
      # Check the appropriate image type
      image_data <- if (image_type == "face") session$face_image else session$verso_image
      
      if (!is.null(image_data) && !is.null(image_data$image_hash)) {
        if (image_data$image_hash == image_hash) {
          # Found a match! Add to candidates
          candidate <- list(
            session_id = session_id,
            original_file = image_data$original_file,
            dimensions = image_data$dimensions,
            grid_config = image_data$grid_config,
            extraction_dir = image_data$extraction_dir,
            cropped_images = image_data$cropped_images,
            upload_time = image_data$upload_time,
            file_size = image_data$file_size,
            h_boundaries = image_data$h_boundaries,
            v_boundaries = image_data$v_boundaries,
            has_boundaries = !is.null(image_data$h_boundaries) && !is.null(image_data$v_boundaries) && 
                            length(image_data$h_boundaries) > 0 && length(image_data$v_boundaries) > 0
          )
          
          matching_sessions[[session_id]] <- candidate
        }
      }
    }
    
    if (length(matching_sessions) == 0) {
      return(NULL)
    }
    
    # Prefer sessions with boundary data, then most recent
    best_session <- NULL
    
    # First, try to find a session with boundaries
    for (candidate in matching_sessions) {
      if (candidate$has_boundaries) {
        if (is.null(best_session) || 
            (candidate$has_boundaries && as.POSIXct(candidate$upload_time) > as.POSIXct(best_session$upload_time))) {
          best_session <- candidate
        }
      }
    }
    
    # If no session with boundaries found, use the most recent one
    if (is.null(best_session)) {
      for (candidate in matching_sessions) {
        if (is.null(best_session) || 
            as.POSIXct(candidate$upload_time) > as.POSIXct(best_session$upload_time)) {
          best_session <- candidate
        }
      }
    }
    
    return(best_session)
    
  }, error = function(e) {
    warning(paste("Error searching for existing processing:", e$message))
    return(NULL)
  })
}

#' Check if cropped images still exist on disk
#'
#' @param cropped_paths Vector of paths to cropped images
#'
#' @return List with existing_paths and missing_paths
#' @noRd
validate_existing_crops <- function(cropped_paths) {
  if (is.null(cropped_paths) || length(cropped_paths) == 0) {
    return(list(existing_paths = character(0), missing_paths = character(0)))
  }
  
  existing_paths <- character(0)
  missing_paths <- character(0)
  
  for (path in cropped_paths) {
    if (file.exists(path)) {
      existing_paths <- c(existing_paths, path)
    } else {
      missing_paths <- c(missing_paths, path)
    }
  }
  
  return(list(
    existing_paths = existing_paths,
    missing_paths = missing_paths
  ))
}

#' Copy existing crops to new session directory
#'
#' @param existing_paths Vector of existing crop file paths
#' @param new_session_dir New session directory to copy files to
#'
#' @return Vector of new file paths, or NULL if error
#' @noRd
copy_existing_crops <- function(existing_paths, new_session_dir) {
  if (length(existing_paths) == 0) {
    return(character(0))
  }
  
  tryCatch({
    # Ensure destination directory exists
    if (!dir.exists(new_session_dir)) {
      dir.create(new_session_dir, recursive = TRUE, showWarnings = FALSE)
    }
    
    new_paths <- character(0)
    
    for (old_path in existing_paths) {
      if (file.exists(old_path)) {
        filename <- basename(old_path)
        new_path <- file.path(new_session_dir, filename)
        
        # Copy the file
        success <- file.copy(old_path, new_path, overwrite = TRUE)
        
        if (success) {
          new_paths <- c(new_paths, new_path)
        } else {
          warning(paste("Failed to copy:", old_path, "to", new_path))
        }
      }
    }
    
    return(new_paths)
    
  }, error = function(e) {
    warning(paste("Error copying existing crops:", e$message))
    return(NULL)
  })
}

#' Create web-accessible paths from file system paths
#'
#' @param file_paths Vector of file system paths
#' @param session_temp_dir Session temporary directory
#' @param resource_prefix Web resource prefix
#'
#' @return Vector of web-accessible paths
#' @noRd
create_web_paths <- function(file_paths, session_temp_dir, resource_prefix) {
  if (length(file_paths) == 0) {
    return(character(0))
  }
  
  tryCatch({
    abs_paths <- normalizePath(file_paths, mustWork = FALSE)
    abs_sess_dir <- normalizePath(session_temp_dir, mustWork = FALSE)
    rel_paths <- gsub(paste0("^", gsub("\\\\", "\\\\\\\\", abs_sess_dir), "[/\\\\]*"), "", abs_paths)
    rel_paths <- sub("^[/\\\\]+", "", rel_paths)
    file.path(resource_prefix, rel_paths)
  }, error = function(e) {
    warning(paste("Error creating web paths:", e$message))
    return(character(0))
  })
}

#' Get summary of existing processing results
#'
#' @param existing_result Result from find_existing_processing
#'
#' @return Character string with summary
#' @noRd
get_existing_processing_summary <- function(existing_result) {
  if (is.null(existing_result)) {
    return("No previous processing found")
  }
  
  crop_count <- length(existing_result$cropped_images %||% character(0))
  grid_info <- existing_result$grid_config
  
  summary_parts <- c()
  summary_parts <- c(summary_parts, paste("Found", crop_count, "existing crops"))
  
  if (!is.null(grid_info)) {
    summary_parts <- c(summary_parts, paste("Grid:", grid_info$rows, "x", grid_info$cols))
  }
  
  if (!is.null(existing_result$upload_time)) {
    upload_date <- format_timestamp(existing_result$upload_time, "%Y-%m-%d %H:%M")
    summary_parts <- c(summary_parts, paste("From:", upload_date))
  }
  
  paste(summary_parts, collapse = " | ")
}

#' Update image tracking with hash information
#'
#' @param session_id Session identifier
#' @param image_type Type of image ("face" or "verso")
#' @param image_hash Hash of the image
#'
#' @return Updated session tracker
#' @noRd
update_image_hash <- function(session_id, image_type, image_hash) {
  tracker <- load_session_tracker(session_id)
  
  if (is.null(tracker)) {
    warning(paste("Session not found:", session_id))
    return(NULL)
  }
  
  # Update the appropriate image record with hash
  if (image_type == "face" && !is.null(tracker$face_image)) {
    tracker$face_image$image_hash <- image_hash
  } else if (image_type == "verso" && !is.null(tracker$verso_image)) {
    tracker$verso_image$image_hash <- image_hash
  } else {
    warning(paste("Cannot update hash: no", image_type, "image found"))
    return(tracker)
  }
  
  # Update metadata
  tracker$metadata$last_updated <- Sys.time()
  
  # Save tracker
  save_session_tracker(tracker)
  
  return(tracker)
}

#' Mark processing as reused from previous session
#'
#' @param session_id Current session identifier
#' @param image_type Type of image ("face" or "verso")
#' @param source_session_id Session ID where the processing originally occurred
#'
#' @return Updated session tracker
#' @noRd
mark_processing_reused <- function(session_id, image_type, source_session_id) {
  tracker <- load_session_tracker(session_id)
  
  if (is.null(tracker)) {
    return(NULL)
  }
  
  # Add reuse information
  if (image_type == "face" && !is.null(tracker$face_image)) {
    tracker$face_image$reused_from_session <- source_session_id
    tracker$face_image$processing_reused <- TRUE
  } else if (image_type == "verso" && !is.null(tracker$verso_image)) {
    tracker$verso_image$reused_from_session <- source_session_id
    tracker$verso_image$processing_reused <- TRUE
  }
  
  # Update metadata
  tracker$metadata$last_updated <- Sys.time()
  
  # Save tracker
  save_session_tracker(tracker)
  
  return(tracker)
}
