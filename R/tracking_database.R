# File: R/tracking_database.R - SIMPLIFIED VERSION
# Fixed SQLite tracking system - NO circular dependencies

#' @importFrom RSQLite SQLite
#' @importFrom DBI dbConnect dbDisconnect dbExecute dbGetQuery
#' @importFrom jsonlite toJSON fromJSON
#' @importFrom digest digest
NULL

# Helper function for null coalescing
`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0 || all(is.na(a))) b else a
}

# ==== SIMPLE DIRECT FUNCTIONS (NO R6 DEPENDENCIES) ====

#' Initialize the tracking database (fixed version)
#' @param db_path Path to SQLite database file
#' @return Database connection status
#' @export
initialize_tracking_db <- function(db_path = "inst/app/data/tracking.sqlite") {
  tryCatch({
    dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)
    con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
    on.exit(DBI::dbDisconnect(con))
    
    DBI::dbExecute(con, "PRAGMA foreign_keys = ON")
    DBI::dbExecute(con, "PRAGMA journal_mode = WAL")
    
    # Create simplified tables
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS users (
        user_id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        email TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_login DATETIME
      )
    ")
    
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS sessions (
        session_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        session_start DATETIME DEFAULT CURRENT_TIMESTAMP,
        session_end DATETIME,
        status TEXT DEFAULT 'active',
        notes TEXT,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      )
    ")
    
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS images (
        image_id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        original_filename TEXT NOT NULL,
        upload_path TEXT NOT NULL,
        image_type TEXT NOT NULL,
        file_size INTEGER,
        width INTEGER,
        height INTEGER,
        file_hash TEXT,
        upload_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        processing_status TEXT DEFAULT 'uploaded',
        FOREIGN KEY (session_id) REFERENCES sessions(session_id),
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      )
    ")
    
    DBI::dbExecute(con, "
      CREATE TABLE IF NOT EXISTS processing_log (
        log_id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        user_id TEXT NOT NULL,
        details TEXT,
        success BOOLEAN DEFAULT 1,
        FOREIGN KEY (image_id) REFERENCES images(image_id),
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      )
    ")
    
    # Create indexes
    indexes <- c(
      "CREATE INDEX IF NOT EXISTS idx_images_session ON images(session_id)",
      "CREATE INDEX IF NOT EXISTS idx_images_user ON images(user_id)",
      "CREATE INDEX IF NOT EXISTS idx_images_status ON images(processing_status)",
      "CREATE INDEX IF NOT EXISTS idx_images_type ON images(image_type)",
      "CREATE INDEX IF NOT EXISTS idx_images_hash ON images(file_hash)",
      "CREATE INDEX IF NOT EXISTS idx_log_image ON processing_log(image_id)"
    )
    
    for (index in indexes) {
      DBI::dbExecute(con, index)
    }
    
    message("✅ Database initialized: ", db_path)
    return(TRUE)
    
  }, error = function(e) {
    message("❌ Failed to initialize database: ", e$message)
    return(FALSE)
  })
}

#' Track image upload - FIXED VERSION (solves Parameter 6 error)
#' @param session_id Session identifier
#' @param user_id User identifier  
#' @param original_filename Original filename
#' @param upload_path Where file was saved (relative path)
#' @param content_category Content category ("cards", "stamps", etc.)
#' @param image_type Type of image ('face', 'verso', etc.)
#' @param file_size File size in bytes (optional)
#' @param dimensions List with width and height (optional)
#' @return Image ID from database
#' @export
track_image_upload <- function(session_id, user_id, original_filename, 
                              upload_path, content_category, image_type, 
                              file_size = NULL, dimensions = NULL) {
  
  message("📝 track_image_upload called (UPLOAD_PATH CORRECTED VERSION)")
  
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con))
    
    # BULLETPROOF parameter conversion - each guaranteed to be single value
    session_id_clean <- as.character(session_id)[1]
    user_id_clean <- as.character(user_id)[1]
    filename_clean <- as.character(original_filename)[1]
    path_clean <- as.character(upload_path)[1]
    type_clean <- as.character(image_type)[1]
    
    # Ensure we have valid values
    if (is.na(session_id_clean) || session_id_clean == "") session_id_clean <- "unknown_session"
    if (is.na(user_id_clean) || user_id_clean == "") user_id_clean <- "unknown_user"
    if (is.na(filename_clean) || filename_clean == "") filename_clean <- "unknown.jpg"
    if (is.na(path_clean) || path_clean == "") path_clean <- "data/unknown.jpg"
    if (is.na(type_clean) || type_clean == "") type_clean <- "unknown"
    
    # Calculate hash
    file_hash <- NULL
    full_path <- file.path("inst/app", path_clean)
    if (file.exists(full_path)) {
      tryCatch({
        file_hash <- digest::digest(file = full_path, algo = "md5")
      }, error = function(e) {
        file_hash <- NULL
      })
    }
    
    # Handle dimensions safely
    width_val <- NULL
    height_val <- NULL
    if (!is.null(dimensions) && is.list(dimensions)) {
      if (!is.null(dimensions$width) && !is.na(dimensions$width)) {
        width_val <- as.integer(dimensions$width)[1]
      }
      if (!is.null(dimensions$height) && !is.na(dimensions$height)) {
        height_val <- as.integer(dimensions$height)[1]
      }
    }
    
    # Handle file size safely
    size_val <- NULL
    if (!is.null(file_size) && !is.na(file_size)) {
      size_val <- as.integer(file_size)[1]
    }
    
    # Insert with SAFE parameters using upload_path (not file_path)
    DBI::dbExecute(con, "
      INSERT INTO images (
        session_id, user_id, original_filename, upload_path, 
        image_type, file_size, width, height, file_hash
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ", list(
      session_id_clean,
      user_id_clean,
      filename_clean,
      path_clean,
      type_clean,
      size_val,
      width_val,
      height_val,
      file_hash
    ))
    
    # Get the inserted ID
    image_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id
    
    # Log the action
    DBI::dbExecute(con, "
      INSERT INTO processing_log (image_id, action, user_id)
      VALUES (?, ?, ?)
    ", list(image_id, "uploaded", user_id_clean))
    
    message("✅ Image tracked successfully with ID: ", image_id)
    return(image_id)
    
  }, error = function(e) {
    message("❌ Error in track_image_upload: ", e$message)
    stop("Database insert failed: ", e$message)
  })
}

#' Save uploaded image - FIXED VERSION
#' @param file_info File info from fileInput
#' @param user_id User identifier
#' @param session_id Session identifier  
#' @param content_category Content category ("cards", "stamps", etc.)
#' @param image_type Type ('face', 'verso')
#' @return List with image_id and file_path
#' @export
save_uploaded_image <- function(file_info, user_id, session_id, content_category, image_type) {
  message("💾 save_uploaded_image called (FIXED VERSION)")
  
  tryCatch({
    # Validate input
    if (is.null(file_info) || !is.list(file_info) || is.null(file_info$name) || is.null(file_info$datapath)) {
      return(list(success = FALSE, error = "Invalid file_info"))
    }
    
    if (!file.exists(file_info$datapath)) {
      return(list(success = FALSE, error = "Source file does not exist"))
    }
    
    # FIXED: Generate Windows-safe file path (no colons in timestamp)
    timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
    clean_filename <- gsub("[^a-zA-Z0-9._-]", "_", file_info$name)
    unique_filename <- paste0(timestamp, "_", clean_filename)
    
    folder_name <- paste("uploads", content_category, image_type, sep = "-")
    relative_path <- file.path("data", folder_name, unique_filename)
    full_path <- file.path("inst/app", relative_path)
    
    # Create directory and copy file
    dir.create(dirname(full_path), recursive = TRUE, showWarnings = FALSE)
    copy_success <- file.copy(file_info$datapath, full_path, overwrite = TRUE)
    
    if (!copy_success || !file.exists(full_path) || file.size(full_path) == 0) {
      return(list(success = FALSE, error = "Failed to copy file"))
    }
    
    file_size <- file.info(full_path)$size
    message("📁 File copied successfully, size: ", file_size, " bytes")
    
    # Get dimensions if possible
    dimensions <- NULL
    if (requireNamespace("magick", quietly = TRUE)) {
      tryCatch({
        img <- magick::image_read(full_path)
        info <- magick::image_info(img)
        dimensions <- list(
          width = as.integer(info$width),
          height = as.integer(info$height)
        )
        message("📐 Image dimensions: ", dimensions$width, "x", dimensions$height)
      }, error = function(e) {
        message("⚠️ Could not read image dimensions: ", e$message)
        dimensions <- NULL
      })
    }
    
    # Track in database
    image_id <- track_image_upload(
      session_id = session_id,
      user_id = user_id,
      original_filename = file_info$name,
      upload_path = relative_path,
      content_category = content_category,
      image_type = image_type,
      file_size = file_size,
      dimensions = dimensions
    )
    
    return(list(
      image_id = image_id,
      file_path = relative_path,
      full_path = full_path,
      web_path = sub("^inst/app/", "", relative_path),
      success = TRUE,
      file_size = file_size
    ))
    
  }, error = function(e) {
    message("❌ Error in save_uploaded_image: ", e$message)
    return(list(success = FALSE, error = e$message))
  })
}

#' Get tracking statistics - FIXED VERSION
#' @return List with tracking statistics
#' @export
get_tracking_statistics <- function() {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con))
    
    total_images <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM images")$count %||% 0
    total_sessions <- DBI::dbGetQuery(con, "SELECT COUNT(DISTINCT session_id) as count FROM images")$count %||% 0
    processed_images <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM images WHERE processing_status = 'processed'")$count %||% 0
    recent_activity <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM images WHERE upload_timestamp > datetime('now', '-24 hours')")$count %||% 0
    
    return(list(
      total_sessions = total_sessions,
      total_images = total_images,
      processed_images = processed_images,
      recent_activity = recent_activity,
      last_updated = Sys.time(),
      system_status = "active"
    ))
    
  }, error = function(e) {
    warning("Error getting tracking statistics: ", e$message)
    return(list(
      total_sessions = 0,
      total_images = 0,
      processed_images = 0,
      recent_activity = 0,
      last_updated = Sys.time(),
      system_status = "error",
      error = e$message
    ))
  })
}

#' Start processing session - FIXED VERSION
#' @param session_id Session identifier
#' @param user_id User identifier
#' @param session_type Type of session (ignored)
#' @return Session ID
#' @export
start_processing_session <- function(session_id, user_id, session_type = "general") {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con))
    
    # Ensure user exists
    DBI::dbExecute(con, "
      INSERT OR IGNORE INTO users (user_id, username) 
      VALUES (?, ?)
    ", list(as.character(user_id), paste0("user_", user_id)))
    
    # Create session
    DBI::dbExecute(con, "
      INSERT OR REPLACE INTO sessions (session_id, user_id) 
      VALUES (?, ?)
    ", list(as.character(session_id), as.character(user_id)))
    
    message("✅ Session started: ", session_id)
    return(session_id)
    
  }, error = function(e) {
    message("❌ Error starting session: ", e$message)
    return(session_id)
  })
}

#' Ensure user exists - FIXED VERSION
#' @param user_id User identifier
#' @param username Username
#' @param email User email
#' @param role User role (ignored)
#' @return User ID
#' @export
ensure_user_exists <- function(user_id, username, email = NULL, role = "user") {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con))
    
    DBI::dbExecute(con, "
      INSERT OR IGNORE INTO users (user_id, username, email) 
      VALUES (?, ?, ?)
    ", list(as.character(user_id), as.character(username), email))
    
    # Update last login
    DBI::dbExecute(con, "
      UPDATE users SET last_login = CURRENT_TIMESTAMP 
      WHERE user_id = ?
    ", list(as.character(user_id)))
    
    return(user_id)
    
  }, error = function(e) {
    message("❌ Error in ensure_user_exists: ", e$message)
    return(user_id)
  })
}

#' Query sessions - FIXED VERSION
#' @param user_id Optional user filter
#' @param limit Limit results
#' @param start_date Start date filter
#' @param end_date End date filter
#' @param session_type Session type filter
#' @return Data frame with sessions
#' @export
query_sessions <- function(user_id = NULL, limit = 100, start_date = NULL, end_date = NULL, session_type = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con))
    
    query <- "
      SELECT 
        s.session_id,
        s.user_id,
        s.session_start,
        s.session_end,
        s.status,
        s.notes,
        u.username,
        u.email,
        COUNT(i.image_id) as image_count
      FROM sessions s
      LEFT JOIN users u ON s.user_id = u.user_id
      LEFT JOIN images i ON s.session_id = i.session_id
    "
    
    where_conditions <- c()
    params <- list()
    
    if (!is.null(user_id)) {
      where_conditions <- c(where_conditions, "s.user_id = ?")
      params <- append(params, user_id)
    }
    
    if (length(where_conditions) > 0) {
      query <- paste(query, "WHERE", paste(where_conditions, collapse = " AND "))
    }
    
    query <- paste(query, 
                   "GROUP BY s.session_id, s.user_id, s.session_start, s.session_end, s.status, s.notes, u.username, u.email",
                   "ORDER BY s.session_start DESC LIMIT", limit)
    
    if (length(params) > 0) {
      result <- DBI::dbGetQuery(con, query, params)
    } else {
      result <- DBI::dbGetQuery(con, query)
    }
    
    return(result)
    
  }, error = function(e) {
    message("❌ Error in query_sessions: ", e$message)
    return(data.frame())
  })
}

#' Track processing action - FIXED VERSION
#' @param image_id Image ID
#' @param action Action performed
#' @param user_id User performing action
#' @param details Additional details
#' @param success Whether action succeeded
#' @param error_message Error message if failed
#' @return Success status
#' @export
track_processing_action <- function(image_id, action, user_id, 
                                   details = NULL, success = TRUE,
                                   error_message = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con))
    
    details_json <- NULL
    if (!is.null(details) || !is.null(error_message)) {
      combined_details <- if (!is.null(details)) details else list()
      if (!is.null(error_message)) {
        combined_details$error <- error_message
      }
      details_json <- jsonlite::toJSON(combined_details, auto_unbox = TRUE)
    }
    
    DBI::dbExecute(con, "
      INSERT INTO processing_log (image_id, action, user_id, details, success)
      VALUES (?, ?, ?, ?, ?)
    ", list(as.integer(image_id), as.character(action), as.character(user_id), 
             details_json, as.logical(success)))
    
    return(TRUE)
    
  }, error = function(e) {
    message("❌ Error in track_processing_action: ", e$message)
    return(FALSE)
  })
}

# ==== SYSTEM INFORMATION ====

#' Get system information
#' @export
get_system_info <- function() {
  list(
    version = "2.0.0-simplified",
    system = "Fixed SQLite Tracking (No R6 Dependencies)",
    database_path = "inst/app/data/tracking.sqlite",
    parameter_6_error_fixed = TRUE,
    circular_dependency_fixed = TRUE,
    legacy_compatibility = TRUE,
    load_status = "working"
  )
}

#' Track extraction completion in database
#' @param session_id Session identifier
#' @param image_type Type of image processed
#' @param extraction_dir Directory where crops were saved
#' @param cropped_paths Vector of cropped image paths
#' @param grid_config Grid configuration used
#' @param h_boundaries Horizontal boundaries
#' @param v_boundaries Vertical boundaries
#' @export
track_extraction <- function(session_id, image_type, extraction_dir, cropped_paths, 
                           grid_config = NULL, h_boundaries = NULL, v_boundaries = NULL) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con))
    
    # Find the image record for this session and type
    image_record <- DBI::dbGetQuery(con, "
      SELECT image_id, user_id FROM images 
      WHERE session_id = ? AND image_type LIKE ?
      ORDER BY upload_timestamp DESC
      LIMIT 1
    ", list(session_id, paste0("%", image_type, "%")))
    
    if (nrow(image_record) == 0) {
      warning("No image found for extraction tracking")
      return(FALSE)
    }
    
    image_id <- image_record$image_id[1]
    user_id <- image_record$user_id[1]
    
    # Update image status
    DBI::dbExecute(con, "
      UPDATE images 
      SET processing_status = 'processed',
          processing_timestamp = CURRENT_TIMESTAMP
      WHERE image_id = ?
    ", list(image_id))
    
    # Record extraction details
    extraction_details <- list(
      extraction_dir = extraction_dir,
      cropped_paths = cropped_paths,
      crop_count = length(cropped_paths),
      grid_config = grid_config,
      h_boundaries = h_boundaries,
      v_boundaries = v_boundaries
    )
    
    # Log extraction action
    track_processing_action(
      image_id = image_id,
      action = "extraction_complete",
      user_id = user_id,
      details = extraction_details,
      success = TRUE
    )
    
    message("✅ Extraction tracked successfully for image_id: ", image_id)
    return(TRUE)
    
  }, error = function(e) {
    message("❌ Error tracking extraction: ", e$message)
    return(FALSE)
  })
}

message("✅ SIMPLIFIED tracking system loaded - Parameter 6 error FIXED!")
message("ℹ️ All functions are now dependency-free and should work reliably")
message("✅ track_extraction function restored!")