#' postal_card_processor UI Function
#'
#' @description A shiny Module for processing postal cards with draggable gridlines and Python integration.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @export
#'
#' @importFrom shiny NS tagList 
mod_postal_card_processor_ui <- function(id, card_type = "face") {
  ns <- NS(id)
  tagList(
    bslib::page_fluid(
      # Controls row - Reorganized for better layout
      fluidRow(
        # Upload section with inline file status
        column(
          width = 12,
          div(
            class = "upload-controls-wrapper",
            # First row: File upload with grid controls
            fluidRow(
              column(
                width = 6,  # Even distribution: 6+3+3=12
                div(
                  class = "styled-file-input-wrapper",
                  tags$label(
                    class = "upload-label",
                    paste("Upload", tools::toTitleCase(card_type), "image")
                  ),
                  div(
                    class = "file-input-inline",
                    fileInput(
                      inputId = ns("image_upload"),
                      label = NULL,
                      accept = "image/*",
                      buttonLabel = "Browse...",
                      placeholder = "No file selected"
                    )
                  ),
                  p(
                    class = "upload-hint",
                    paste("Upload the", toupper(card_type), "side of your postal cards")
                  )
                )
              ),
              column(
                width = 3,  # Even with cols control
                div(
                  id = ns("rows_control"),
                  style = "display: none;",
                  uiOutput(ns("num_rows_ui"))
                )
              ),
              column(
                width = 3,  # Even with rows control
                div(
                  id = ns("cols_control"),
                  style = "display: none;",
                  uiOutput(ns("num_cols_ui"))
                )
              )
            ),
            # Second row: Extract button (full width when visible)
            fluidRow(
              column(
                width = 12,
                div(
                  id = ns("extract_control"),
                  class = "extract-button-wrapper",
                  style = "display: none; margin-top: 15px;",
                  actionButton(
                    inputId = ns("extract_postcards"),
                    label = paste("Extract", tools::toTitleCase(card_type), "Cards"),
                    icon = icon("scissors"),
                    class = "btn-extract"
                  )
                )
              )
            )
          )
        )
      ),
      # Images row
      fluidRow(
        style = "margin-top: 20px;",
        column(
          width = 7,
          bslib::card(
            header = bslib::card_header(paste("Uploaded", card_type, "image")),
            uiOutput(ns("images_panel"))
          )
        ),
        column(
          width = 5,
          bslib::card(
            header = bslib::card_header(paste("Extracted", card_type, "images")),
            uiOutput(ns("extracted_cards_display"))
          )
        )
      )
    )
  )
}

#' postal_card_processor Server Functions
#'
#' @export
mod_postal_card_processor_server <- function(id, card_type = "face", on_grid_update = NULL, on_image_upload = NULL, on_extraction_complete = NULL) {
  result <- moduleServer(id, function(input, output, session) {
    
    ns <- session$ns
    `%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || all(is.na(a))) b else a
    
    # ---- Session directory for images ----
    session_temp_dir <- tempfile("shiny_session_images_")
    dir.create(session_temp_dir, showWarnings = FALSE, recursive = TRUE)
    resource_prefix <- ns("session_images")
    shiny::addResourcePath(prefix = resource_prefix, directoryPath = session_temp_dir)
    python_output_subdir_name <- "py_extracted"
    
    # ---- Reactive state ----
    rv <- reactiveValues(
      image_path_original = NULL,
      image_url_display = NULL,
      image_dims_original = NULL,
      h_boundaries = numeric(0),
      v_boundaries = numeric(0),
      boundaries_manually_adjusted = FALSE,
      force_grid_redraw = 0,
      current_grid_rows = NULL,
      current_grid_cols = NULL,
      extracted_paths_web = NULL,
      is_extracting = FALSE,  # Track extraction state to prevent unwanted observer triggers
      reset_in_progress = FALSE,  # NEW: Track reset to prevent upload observer from running
      crop_card_mapping = NULL,  # NEW: Track mapping of crop rows to card_id for AI extraction
      trigger_extraction = 0,  # NEW: Reactive trigger for extraction (incremented to trigger)
      current_image_hash = NULL,  # FIX: Hash of current uploaded image for duplicate detection
      current_card_id = NULL,  # FIX: Card ID from database tracking
      processing_status = "idle"  # NEW: Track upload/processing state for double-click prevention and error handling
    )
    
    # ---- Python setup ----
    # Check if Python is already loaded globally
    python_sourced <- exists(".postal_card_python_loaded", envir = .GlobalEnv) &&
                      isTRUE(get(".postal_card_python_loaded", envir = .GlobalEnv)) &&
                      exists("detect_grid_layout", envir = .GlobalEnv) &&
                      exists("crop_image_with_boundaries", envir = .GlobalEnv)
    
    # ---- Image upload handling ----
    observeEvent(input$image_upload, {
      # CRITICAL: Skip if reset is in progress
      if (isTRUE(rv$reset_in_progress)) {
        return()
      }

      # CRITICAL: Skip if extraction is in progress to prevent cascade
      if (isTRUE(rv$is_extracting)) {
        return()
      }

      # CRITICAL: Prevent double-click / simultaneous uploads while processing
      if (rv$processing_status %in% c("uploading", "verifying", "detecting", "tracking")) {
        message("  ⚠️ Upload already in progress, ignoring duplicate trigger (status: ", rv$processing_status, ")")
        return()
      }

      file_info <- input$image_upload

      # Reset state
      rv$image_path_original <- NULL
      rv$image_url_display <- NULL
      rv$image_dims_original <- NULL
      rv$h_boundaries <- numeric(0)
      rv$v_boundaries <- numeric(0)
      rv$extracted_paths_web <- NULL
      rv$current_grid_rows <- NULL
      rv$current_grid_cols <- NULL
      rv$boundaries_manually_adjusted <- FALSE
      rv$current_image_hash <- NULL  # FIX: Clear hash for new upload
      rv$current_card_id <- NULL  # FIX: Clear card ID for new upload
      rv$processing_status <- "uploading"  # NEW: Set to uploading (for double-click prevention)

      # Save uploaded file with verification
      timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
      safe_filename <- paste0("uploaded_", card_type, "_", timestamp, ".jpg")
      upload_path <- file.path(session_temp_dir, safe_filename)

      # CRITICAL FIX: Verify file copy succeeded
      copy_success <- file.copy(file_info$datapath, upload_path, overwrite = TRUE)
      if (!copy_success) {
        showNotification(
          paste("Failed to save uploaded", card_type, "image. Please try again."),
          type = "error",
          duration = 5
        )
        return()
      }

      rv$image_path_original <- upload_path

      # Update status: file copied, now verifying readability
      rv$processing_status <- "verifying"

      # CRITICAL FIX: Wait for file to be readable (with retry logic)
      # This prevents race conditions where browser tries to load before file is ready
      # Increased wait for WSL2 filesystem lag
      max_wait <- 20  # iterations (increased from 10)
      wait_count <- 0
      file_ready <- FALSE

      while (wait_count < max_wait && !file_ready) {
        if (file.exists(upload_path) && file.size(upload_path) > 0) {
          # Additional check: try to read first few bytes to ensure file is accessible
          can_read <- tryCatch({
            con <- file(upload_path, "rb")
            test_bytes <- readBin(con, "raw", n = 10)
            close(con)
            length(test_bytes) > 0
          }, error = function(e) {
            FALSE
          })

          if (can_read) {
            file_ready <- TRUE
          }
        }

        if (!file_ready) {
          Sys.sleep(0.1)  # Increased from 0.05 (100ms delay)
          wait_count <- wait_count + 1
        }
      }

      if (!file_ready) {
        showNotification(
          paste("Uploaded", card_type, "image is not readable. Please try again."),
          type = "error",
          duration = 5
        )
        return()
      }

      # Check for duplicate image before processing AND track upload
      rv$processing_status <- "tracking"
      message("=== UPLOAD TRACKING START (card_type: ", card_type, ") ===")
      image_hash <- calculate_image_hash(upload_path)
      message("  📌 Hash calculated: ", substr(image_hash, 1, 12), "...")
      rv$current_image_hash <- image_hash

      # NEW 3-LAYER ARCHITECTURE: Get or create postal card
      tryCatch({
        message("  🔍 Calling get_or_create_card with image_type = ", card_type)
        card_id <- get_or_create_card(
          file_hash = image_hash,
          image_type = card_type,
          original_filename = file_info$name,
          file_size = file.info(upload_path)$size,
          dimensions = NULL
        )

        rv$current_card_id <- card_id
        message("  ✅ Card ID stored in rv: ", card_id)

        # Track in session activity
        track_session_activity(
          session_id = session$token,
          card_id = card_id,
          action = "uploaded",
          details = list(upload_path = upload_path, filename = file_info$name)
        )

        message("  ✅ Card tracked: card_id = ", card_id)
      }, error = function(e) {
        message("  ❌ Failed to track upload: ", e$message)
      })
      message("=== UPLOAD TRACKING END ===")

      # Update status: starting grid detection
      rv$processing_status <- "detecting"

      # Get image dimensions and detect grid
      if (python_sourced && exists("detect_grid_layout")) {
        # FILE VERIFICATION: Ensure file is ready before calling Python
        if (!file.exists(rv$image_path_original) || file.size(rv$image_path_original) == 0) {
          Sys.sleep(0.05)
        }

        # RETRY LOGIC: Handle transient file system issues
        max_attempts <- 3
        attempt <- 1
        py_results <- NULL

        while (is.null(py_results) && attempt <= max_attempts) {
          if (attempt > 1) {
            Sys.sleep(0.1)
          }

          py_results <- tryCatch({
            detect_grid_layout(rv$image_path_original)
          }, error = function(e) {
            if (attempt == max_attempts) {
              showNotification("Grid detection failed", type = "error", duration = 3)
            }
            NULL
          })

          attempt <- attempt + 1
        }

        if (!is.null(py_results)) {
          rv$image_dims_original <- c(py_results$image_width, py_results$image_height)
          
          # Get detected boundaries (internal lines only)
          py_h_temp <- if (!is.null(py_results$h_boundaries)) as.numeric(unlist(py_results$h_boundaries)) else numeric(0)
          py_v_temp <- if (!is.null(py_results$v_boundaries)) as.numeric(unlist(py_results$v_boundaries)) else numeric(0)
          
          # Filter internal boundaries
          py_detected_h_internal <- sort(unique(round(py_h_temp[py_h_temp > 1e-6 & py_h_temp < (rv$image_dims_original[2] - 1e-6)])))
          py_detected_v_internal <- sort(unique(round(py_v_temp[py_v_temp > 1e-6 & py_v_temp < (rv$image_dims_original[1] - 1e-6)])))
          
          # Set defaults based on detection
          default_rows <- if (length(py_detected_h_internal) > 0) length(py_detected_h_internal) + 1 else 1
          default_cols <- if (length(py_detected_v_internal) > 0) length(py_detected_v_internal) + 1 else 1
          
          # Construct full boundary lists
          rv$h_boundaries <- sort(unique(round(c(0, py_detected_h_internal, rv$image_dims_original[2]))))
          rv$h_boundaries <- rv$h_boundaries[rv$h_boundaries >= 0 & rv$h_boundaries <= rv$image_dims_original[2]]
          
          rv$v_boundaries <- sort(unique(round(c(0, py_detected_v_internal, rv$image_dims_original[1]))))
          rv$v_boundaries <- rv$v_boundaries[rv$v_boundaries >= 0 & rv$v_boundaries <= rv$image_dims_original[1]]
          
          # Fallback to evenly spaced if detection failed
          if (length(rv$h_boundaries) <= 2) {
            rv$h_boundaries <- round(seq(0, rv$image_dims_original[2], length.out = default_rows + 1))
          }
          if (length(rv$v_boundaries) <= 2) {
            rv$v_boundaries <- round(seq(0, rv$image_dims_original[1], length.out = default_cols + 1))
          }
          
          # Update grid dimensions
          rv$current_grid_rows <- max(0, length(rv$h_boundaries) - 1)
          rv$current_grid_cols <- max(0, length(rv$v_boundaries) - 1)

          # Update numeric inputs
          updateNumericInput(session, "num_rows_input", value = rv$current_grid_rows)
          updateNumericInput(session, "num_cols_input", value = rv$current_grid_cols)

          rv$force_grid_redraw <- rv$force_grid_redraw + 1

          # === URL CREATION: ONLY after grid detection succeeds ===
          # CRITICAL FIX (2025-10-29): Delay URL creation until ALL data dependencies exist
          # This prevents broken image icon that appeared when image_with_draggable_grid
          # tried to render before rv$image_dims_original, rv$h_boundaries, and rv$v_boundaries were set.
          # Previous issue: URL at line 274 → UI render → req() blocks → broken icon for 200-500ms
          # New flow: Grid detection → set all data → create URL → UI renders complete image

          # Create web URL for display
          norm_session_dir <- normalizePath(session_temp_dir, winslash = "/")
          norm_upload_path <- normalizePath(upload_path, winslash = "/")
          rel_path <- sub(paste0("^", gsub("/", "\\\\/", norm_session_dir), "/*"), "", norm_upload_path)
          rel_path <- sub("^/*", "", rel_path)
          cache_buster <- format(Sys.time(), "%Y%m%d%H%M%OS6")
          rv$image_url_display <- paste0(resource_prefix, "/", rel_path, "?v=", cache_buster)

          # Update status: ready to display
          rv$processing_status <- "ready"

          message("  ✅ Image URL created, status = ready")
        } else {
          # Grid detection failed completely
          rv$processing_status <- "error"

          showNotification(
            paste("Failed to detect grid in", card_type, "image. Please check image quality."),
            type = "error",
            duration = 5
          )

          message("  ❌ Grid detection failed, status = error")
          return()  # Stop processing, don't create URL
        }
      }

      # FALLBACK: If Python detection failed or unavailable, use image library to get dims
      if (is.null(rv$image_dims_original)) {
        # Try to read image with magick or other methods
        dims_result <- tryCatch({
          # Method 1: Try magick if available
          if (requireNamespace("magick", quietly = TRUE)) {
            img <- magick::image_read(rv$image_path_original)
            info <- magick::image_info(img)
            c(info$width, info$height)
          } else if (requireNamespace("jpeg", quietly = TRUE) || requireNamespace("png", quietly = TRUE)) {
            # Method 2: Try jpeg/png packages
            ext <- tolower(tools::file_ext(rv$image_path_original))
            if (ext %in% c("jpg", "jpeg") && requireNamespace("jpeg", quietly = TRUE)) {
              img <- jpeg::readJPEG(rv$image_path_original, native = FALSE)
              c(ncol(img), nrow(img))
            } else if (ext == "png" && requireNamespace("png", quietly = TRUE)) {
              img <- png::readPNG(rv$image_path_original, native = FALSE)
              c(ncol(img), nrow(img))
            } else {
              NULL
            }
          } else {
            NULL
          }
        }, error = function(e) {
          NULL
        })

        if (!is.null(dims_result)) {
          rv$image_dims_original <- dims_result

          # Set default 1x1 grid
          rv$h_boundaries <- c(0, rv$image_dims_original[2])
          rv$v_boundaries <- c(0, rv$image_dims_original[1])
          rv$current_grid_rows <- 1
          rv$current_grid_cols <- 1

          updateNumericInput(session, "num_rows_input", value = 1)
          updateNumericInput(session, "num_cols_input", value = 1)

          rv$force_grid_redraw <- rv$force_grid_redraw + 1

          # Fallback succeeded, create URL and set ready
          norm_session_dir <- normalizePath(session_temp_dir, winslash = "/")
          norm_upload_path <- normalizePath(upload_path, winslash = "/")
          rel_path <- sub(paste0("^", gsub("/", "\\\\/", norm_session_dir), "/*"), "", norm_upload_path)
          rel_path <- sub("^/*", "", rel_path)
          cache_buster <- format(Sys.time(), "%Y%m%d%H%M%OS6")
          rv$image_url_display <- paste0(resource_prefix, "/", rel_path, "?v=", cache_buster)

          rv$processing_status <- "ready"

          message("  ✅ Fallback dimensions set, URL created, status = ready")
        } else {
          # Complete failure - no method worked
          rv$processing_status <- "error"

          showNotification(
            paste("Could not process", card_type, "image. Unsupported format or corrupted file."),
            type = "error",
            duration = 5
          )

          message("  ❌ All dimension detection methods failed, status = error")
          return()  # Don't create URL
        }
      }

      # Check dimensions were obtained before proceeding
      if (is.null(rv$image_dims_original)) {
        # Complete failure - dimensions still NULL after all methods
        rv$processing_status <- "error"

        showNotification(
          paste("Could not process", card_type, "image. Unsupported format or corrupted file."),
          type = "error",
          duration = 5
        )

        message("  ❌ All dimension detection methods failed, status = error")
        return()  # Don't proceed to show controls
      }
      
      # Show controls
      shinyjs::show("rows_control")
      shinyjs::show("cols_control")
      shinyjs::show("extract_control")
      
      # Check for duplicate image AFTER upload and grid detection
      message("\n=== DUPLICATE CHECK START (card_type: ", card_type, ") ===")
      if (!is.null(rv$current_image_hash)) {
        message("  🔍 Searching for existing processing...")
        message("     Hash: ", substr(rv$current_image_hash, 1, 12), "...")
        message("     Type: ", card_type)

        existing <- find_card_processing(rv$current_image_hash, card_type)

        if (!is.null(existing)) {
          message("  📋 FOUND existing processing!")
          message("     Card ID: ", existing$card_id)
          message("     Last processed: ", existing$last_processed)
          message("     Crop paths count: ", length(existing$crop_paths))

          validation <- validate_existing_crops(existing$crop_paths)
          message("  🔎 Validating crop files...")
          message("     All exist: ", validation$all_exist)
          if (!validation$all_exist) {
            message("     Missing files: ", paste(validation$missing_files, collapse = ", "))
          }

          if (validation$all_exist) {
            message("  ✅ Duplicate image detected - showing modal")

            # Store data for potential reuse
            rv$pending_existing_data <- existing
            
            # Show modal asking user if they want to reuse previous processing
            showModal(modalDialog(
              title = "Duplicate Image Detected",
              HTML(paste0(
                "<p>This image was previously processed on <strong>",
                format_timestamp(existing$last_processed),
                "</strong></p>",
                "<p>Would you like to reuse the previous crops?</p>",
                "<ul>",
                "<li><strong>Use Existing:</strong> Instantly restore ", length(existing$crop_paths), " crops</li>",
                "<li><strong>Process Anyway:</strong> Continue with current detection</li>",
                "</ul>"
              )),
              footer = tagList(
                actionButton(ns("use_existing_crops"), "Use Existing", class = "btn-primary"),
                actionButton(ns("process_anyway"), "Process Anyway", class = "btn-secondary"),
                modalButton("Cancel")
              ),
              size = "m",
              easyClose = FALSE
            ))
          } else {
            message("  ⚠️ Crops validation failed - not showing modal")
          }
        } else {
          message("  ℹ️ No existing processing found")
        }
      } else {
        message("  ⚠️ No image hash available - skipping duplicate check")
      }
      message("=== DUPLICATE CHECK END ===\n")

      if (!is.null(on_image_upload)) on_image_upload()
    })
    
    # ---- Grid controls ----
    observeEvent({
      input$num_rows_input
      input$num_cols_input
    }, {
      req(rv$image_path_original, rv$image_dims_original,
          !is.null(input$num_rows_input), !is.null(input$num_cols_input))
      
      nr <- max(1, as.integer(input$num_rows_input %||% 1))
      nc <- max(1, as.integer(input$num_cols_input %||% 1))
      
      current_derived_rows <- if (length(rv$h_boundaries) > 1) length(rv$h_boundaries) - 1 else 0
      current_derived_cols <- if (length(rv$v_boundaries) > 1) length(rv$v_boundaries) - 1 else 0
      
      if (nr == current_derived_rows && nc == current_derived_cols && !rv$boundaries_manually_adjusted) {
        return()
      }
      
      # Recalculate boundaries
      rv$h_boundaries <- round(seq(0, rv$image_dims_original[2], length.out = nr + 1))
      rv$v_boundaries <- round(seq(0, rv$image_dims_original[1], length.out = nc + 1))
      
      rv$h_boundaries <- unique(rv$h_boundaries[rv$h_boundaries >= 0 & rv$h_boundaries <= rv$image_dims_original[2]])
      rv$v_boundaries <- unique(rv$v_boundaries[rv$v_boundaries >= 0 & rv$v_boundaries <= rv$image_dims_original[1]])
      
      rv$current_grid_rows <- max(0, length(rv$h_boundaries) - 1)
      rv$current_grid_cols <- max(0, length(rv$v_boundaries) - 1)
      
      if (rv$current_grid_rows != nr) updateNumericInput(session, "num_rows_input", value = rv$current_grid_rows)
      if (rv$current_grid_cols != nc) updateNumericInput(session, "num_cols_input", value = rv$current_grid_cols)
      
      rv$boundaries_manually_adjusted <- FALSE
      rv$force_grid_redraw <- rv$force_grid_redraw + 1
      
      if (!is.null(on_grid_update)) on_grid_update(rv$current_grid_rows, rv$current_grid_cols)
      
    }, ignoreNULL = TRUE, ignoreInit = TRUE)
    
    # ---- Handle "Use Existing" button from duplicate modal ----
    observeEvent(input$use_existing_crops, {
      req(rv$pending_existing_data)

      # CRITICAL: Prevent double-click on modal button
      if (isTRUE(rv$is_extracting)) {
        message("  ⚠️ Already processing existing crops, ignoring duplicate click")
        return()
      }
      rv$is_extracting <- TRUE  # Set flag to prevent concurrent processing
      on.exit(rv$is_extracting <- FALSE)  # Always clear flag when done
      
      removeModal()
      
      tryCatch({
        existing <- rv$pending_existing_data

        # Copy crops to session temp dir for web display
        timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
        session_crops_dir <- file.path(session_temp_dir, "crops_display")
        dir.create(session_crops_dir, showWarnings = FALSE, recursive = TRUE)

        # Copy crops from persistent storage to session dir
        copy_result <- copy_existing_crops(existing$crop_paths, session_crops_dir)
        
        if (copy_result$success) {
          # Restore boundaries and grid configuration
          rv$h_boundaries <- existing$h_boundaries
          rv$v_boundaries <- existing$v_boundaries
          rv$current_grid_rows <- existing$grid_rows
          rv$current_grid_cols <- existing$grid_cols
          
          # Create web URLs for the copied crops
          abs_paths <- normalizePath(copy_result$new_paths, winslash = "/")
          abs_sess_dir <- normalizePath(session_temp_dir, winslash = "/")
          rel_paths <- sub(paste0("^", gsub("/", "\\/", abs_sess_dir), "/*"), "", abs_paths)
          rel_paths <- sub("^/*", "", rel_paths)
          rv$extracted_paths_web <- paste(resource_prefix, rel_paths, sep = "/")
          
          # Track reuse in session activity
          track_session_activity(
            session_id = session$token,
            card_id = rv$current_card_id,
            action = "reused",
            details = list(
              source_card_id = existing$card_id,
              crops_count = length(rv$extracted_paths_web)
            )
          )
          
          # Force UI update
          rv$force_grid_redraw <- rv$force_grid_redraw + 1

          message("Crops reused successfully from card_id: ", existing$card_id)

          # NEW: Store crop-to-card mapping for AI extraction (Use Existing case)
          rv$crop_card_mapping <- data.frame(
            row = 0:(length(abs_paths) - 1),
            card_id = rv$current_card_id,
            crop_path = abs_paths,
            stringsAsFactors = FALSE
          )
          message("Crop mapping created from existing: ", nrow(rv$crop_card_mapping), " crops for card_id: ", rv$current_card_id)

          # NEW: Trigger extraction complete callback
          # This allows the app to detect both modules are done and auto-combine
          if (!is.null(on_extraction_complete)) {
            on_extraction_complete(
              count = length(rv$extracted_paths_web),
              dir = session_crops_dir,
              used_existing = TRUE
            )
          }
        } else {
          showNotification("Failed to copy existing crops", type = "error", duration = 5)
        }
        
      }, error = function(e) {
        showNotification(paste("Error reusing crops:", e$message), type = "error", duration = 5)
        message("Error in use_existing_crops: ", e$message)
      })
      
      rv$pending_existing_data <- NULL
    })
    
    # ---- Handle "Process Anyway" button from duplicate modal ----
    observeEvent(input$process_anyway, {
      # CRITICAL: Prevent double-click on modal button (debounce)
      if (!is.null(rv$pending_existing_data)) {
        # Only process if modal data still exists (prevents double-click)
        rv$pending_existing_data <- NULL
      } else {
        return()  # Already processed, ignore duplicate click
      }

      removeModal()

      showNotification("Processing with current grid boundaries", type = "message", duration = 2)

      # Trigger extraction using native Shiny reactive system (no shinyjs needed)
      rv$trigger_extraction <- rv$trigger_extraction + 1
    })
    
    # ---- Draggable line handlers (FIXED) ----
    observeEvent(input$hline_moved_direct, {
      req(input$hline_moved_direct)
      d <- input$hline_moved_direct

      if (!is.null(d$pos_px_wrapper) && !is.null(d$wrapper_dim) && !is.null(d$id)) {
        # Convert to original image coordinates
        scale_factor <- as.numeric(rv$image_dims_original[2]) / as.numeric(d$wrapper_dim)
        orig_y <- round(as.numeric(d$pos_px_wrapper) * scale_factor)
        line_index <- as.numeric(d$id)

        if (line_index > 0 && line_index <= length(rv$h_boundaries)) {
          rv$h_boundaries[line_index] <- orig_y
          rv$boundaries_manually_adjusted <- TRUE
          rv$force_grid_redraw <- rv$force_grid_redraw + 1
        }
      }
    })

    observeEvent(input$vline_moved_direct, {
      req(input$vline_moved_direct)
      d <- input$vline_moved_direct

      if (!is.null(d$pos_px_wrapper) && !is.null(d$wrapper_dim) && !is.null(d$id)) {
        # Convert to original image coordinates
        scale_factor <- as.numeric(rv$image_dims_original[1]) / as.numeric(d$wrapper_dim)
        orig_x <- round(as.numeric(d$pos_px_wrapper) * scale_factor)
        line_index <- as.numeric(d$id)

        if (line_index > 0 && line_index <= length(rv$v_boundaries)) {
          rv$v_boundaries[line_index] <- orig_x
          rv$boundaries_manually_adjusted <- TRUE
          rv$force_grid_redraw <- rv$force_grid_redraw + 1
        }
      }
    })
    
    # ---- UI Rendering ----
    output$images_panel <- renderUI({
      # === ERROR STATE: Show error message with retry ===
      if (rv$processing_status == "error") {
        return(div(
          style = "width:100%; height:500px; display:flex; flex-direction: column; align-items:center; justify-content:center; background-color: #fff3cd; border: 2px solid #ffc107; border-radius: 8px;",
          div(
            style = "text-align: center; padding: 20px;",
            icon("exclamation-triangle", style = "font-size: 48px; color: #856404; margin-bottom: 16px;"),
            h5("Processing Failed", style = "color: #856404; margin-bottom: 8px;"),
            p("An error occurred during image processing. Please try again.",
              style = "color: #856404; font-size: 14px; margin: 0;"),
            actionButton(ns("retry_upload"), "Try Again",
                         class = "btn-warning",
                         style = "margin-top: 16px;")
          )
        ))
      }

      # === EMPTY STATE: No upload yet ===
      if (is.null(rv$image_url_display)) {
        return(div(
          style = "width:100%; height:500px; display:flex; align-items:center; justify-content:center; color:#aaa; font-style:italic;",
          paste("Upload a", card_type, "image to start.")
        ))
      }

      # === READY STATE: Show grid UI (original code) ===
      tags$div(
        id = ns("grid_ui_wrapper"),
        `data-draggrid` = "true",
        style = "position:relative; width:100%; height:500px; overflow:visible; border:1px solid #eee; margin-bottom:8px; background-color: #f5f5f5;",
        uiOutput(ns("image_with_draggable_grid"))
      )
    })
    
    output$image_with_draggable_grid <- renderUI({
      req(rv$image_url_display, rv$image_dims_original, length(rv$h_boundaries) >= 2, length(rv$v_boundaries) >= 2)

      force_redraw_trigger <- rv$force_grid_redraw  # Trigger reactivity
      
      h_boundaries_px <- rv$h_boundaries
      v_boundaries_px <- rv$v_boundaries
      
      # Create horizontal lines
      h_lines <- lapply(seq_along(h_boundaries_px), function(i) {
        img_height <- as.numeric(rv$image_dims_original[2])
        boundary_pos <- as.numeric(h_boundaries_px[i])
        top_percent <- if (!is.na(img_height) && img_height > 0) (boundary_pos / img_height) * 100 else 0
        
        tags$div(
          id = ns(paste0("hline_", i)),
          class = "draggable-line horizontal-line",
          `data-line-index` = i,
          `data-boundary-value` = boundary_pos,  # Store original boundary value
          style = sprintf("top: %.4f%%;", top_percent)
        )
      })
      
      # Create vertical lines
      v_lines <- lapply(seq_along(v_boundaries_px), function(i) {
        img_width <- as.numeric(rv$image_dims_original[1])
        boundary_pos <- as.numeric(v_boundaries_px[i])
        left_percent <- if (!is.na(img_width) && img_width > 0) (boundary_pos / img_width) * 100 else 0
        
        tags$div(
          id = ns(paste0("vline_", i)),
          class = "draggable-line vertical-line",
          `data-line-index` = i,
          `data-boundary-value` = boundary_pos,  # Store original boundary value
          style = sprintf("left: %.4f%%;", left_percent)
        )
      })
      
      # Cache-busting image source
      img_src_with_nonce <- paste0("/", rv$image_url_display, "?v=", gsub("[^0-9]", "", as.character(as.numeric(Sys.time()) * 1000)))
      
      tags$div(
        style = "position:relative; width:100%; height:100%; overflow:visible;",
        tags$img(
          id = ns("preview_image"),
          src = img_src_with_nonce,
          style = "display:block; position:absolute; top:50%; left:50%; transform:translate(-50%, -50%); max-width:100%; max-height:500px; width:auto; height:auto; object-fit:contain; pointer-events:none; z-index:5;",
          `data-original-width` = rv$image_dims_original[1],
          `data-original-height` = rv$image_dims_original[2],
          onload = "console.log('✅ Image loaded successfully!');",
          onerror = "console.error('❌ Image failed to load:', this.src);"
        ),
        h_lines, 
        v_lines,
        # Re-initialize grid after each render
        tags$script(HTML(sprintf(
          "if (typeof initDraggableGrid === 'function') { 
             initDraggableGrid(document.getElementById('%s')); 
           }",
          session$ns("grid_ui_wrapper")
        )))
      )
    })

    # === RETRY UPLOAD HANDLER ===
    # Reset status when user clicks retry after error
    observeEvent(input$retry_upload, {
      rv$processing_status <- "idle"
      rv$image_url_display <- NULL

      showNotification(
        paste("Please upload a new", card_type, "image."),
        type = "message",
        duration = 3
      )
    })

    output$num_rows_ui <- renderUI({
      req(rv$current_grid_rows)
      numericInput(ns("num_rows_input"), "Grid Rows", value = rv$current_grid_rows, min = 1, max = 20)
    })
    
    output$num_cols_ui <- renderUI({
      req(rv$current_grid_cols)
      numericInput(ns("num_cols_input"), "Grid Columns", value = rv$current_grid_cols, min = 1, max = 20)
    })
    
    # ---- Extraction logic ----
    observeEvent({
      input$extract_postcards
      rv$trigger_extraction
    }, {
      req(rv$image_path_original, length(rv$h_boundaries) > 1, length(rv$v_boundaries) > 1, python_sourced)

      # Set extraction flag to prevent any reactive cascade from triggering detection
      rv$is_extracting <- TRUE
      on.exit(rv$is_extracting <- FALSE)  # Always reset flag when done

      # CRITICAL FIX: Use persistent directory for crops, not temp session dir
      # This allows deduplication to work across app restarts
      persistent_crops_dir <- file.path("inst/app/data/crops", card_type, rv$current_card_id)
      dir.create(persistent_crops_dir, showWarnings = FALSE, recursive = TRUE)

      py_out_dir <- file.path(persistent_crops_dir, paste0("extract_", as.integer(Sys.time())))
      dir.create(py_out_dir, showWarnings = FALSE, recursive = TRUE)

      message("  📂 Persistent crop directory: ", py_out_dir)
      rv$extracted_paths_web <- NULL

      py_results <- tryCatch({
        crop_image_with_boundaries(
          image_path = rv$image_path_original,
          h_boundaries = as.list(as.integer(round(rv$h_boundaries))),
          v_boundaries = as.list(as.integer(round(rv$v_boundaries))),
          output_dir = py_out_dir
        )
      }, error = function(e) {
        showNotification(paste("Extraction error:", e$message), type = "error", duration = 5)
        NULL
      })

      if (!is.null(py_results) && !is.null(py_results$extracted_paths) && length(unlist(py_results$extracted_paths)) > 0) {
        abs_paths <- normalizePath(unlist(py_results$extracted_paths), winslash = "/")

        # Copy crops to session temp dir for web serving
        session_crops_dir <- file.path(session_temp_dir, "crops_display")
        dir.create(session_crops_dir, showWarnings = FALSE, recursive = TRUE)

        web_paths <- character(length(abs_paths))
        for (i in seq_along(abs_paths)) {
          filename <- basename(abs_paths[i])
          dest_file <- file.path(session_crops_dir, filename)
          file.copy(abs_paths[i], dest_file, overwrite = TRUE)
          web_paths[i] <- dest_file
        }

        # Create web URLs from copied files
        abs_sess_dir <- normalizePath(session_temp_dir, winslash = "/")
        norm_web_paths <- normalizePath(web_paths, winslash = "/")
        rel_paths <- sub(paste0("^", gsub("/", "\\\\/", abs_sess_dir), "/*"), "", norm_web_paths)
        rel_paths <- sub("^/*", "", rel_paths)
        rv$extracted_paths_web <- paste(resource_prefix, rel_paths, sep = "/")

        # Save processing with 3-layer architecture
        message("\n=== SAVING EXTRACTION (card_type: ", card_type, ") ===")
        tryCatch({
          message("  💾 Saving processing to database...")
          message("     Card ID: ", rv$current_card_id)
          message("     Crops: ", length(abs_paths))
          message("     Grid: ", rv$current_grid_rows, "x", rv$current_grid_cols)

          save_card_processing(
            card_id = rv$current_card_id,
            crop_paths = abs_paths,
            h_boundaries = rv$h_boundaries,
            v_boundaries = rv$v_boundaries,
            grid_rows = rv$current_grid_rows,
            grid_cols = rv$current_grid_cols,
            extraction_dir = py_out_dir,
            ai_data = NULL
          )

          track_session_activity(
            session_id = session$token,
            card_id = rv$current_card_id,
            action = "processed",
            details = list(crops_count = length(abs_paths))
          )

          message("  ✅ Processing saved for card_id: ", rv$current_card_id)
        }, error = function(e) {
          message("  ❌ Failed to save processing: ", e$message)
        })
        message("=== SAVING EXTRACTION END ===\n")

        # Store crop-to-card mapping for AI extraction
        rv$crop_card_mapping <- data.frame(
          row = 0:(length(abs_paths) - 1),
          card_id = rv$current_card_id,
          crop_path = abs_paths,
          stringsAsFactors = FALSE
        )

        # Trigger callback
        if (!is.null(on_extraction_complete)) {
          on_extraction_complete(
            count = length(rv$extracted_paths_web),
            dir = py_out_dir,
            used_existing = FALSE
          )
        }
      } else {
        showNotification("Extraction failed", type = "error", duration = 5)
      }
    })
    
    # ---- Display extracted cards ----
    output$extracted_cards_display <- renderUI({
      paths <- rv$extracted_paths_web
      if (is.null(paths) || length(paths) == 0) {
        return(p("No cards extracted yet.", style = "text-align:center; color:#aaa;"))
      }
      
      num_rows <- rv$current_grid_rows %||% 1
      num_cols <- rv$current_grid_cols %||% 1
      
      grid_rows <- list()
      
      for (row in 1:num_rows) {
        row_images <- list()
        for (col in 1:num_cols) {
          index <- (row - 1) * num_cols + col
          
          if (index <= length(paths)) {
            row_images[[col]] <- column(
              width = floor(12 / num_cols),
              div(
                style = "text-align: center; margin-bottom: 10px;",
                div(
                  style = "background-color: #f8f9fa; border: 1px solid #dee2e6; border-radius: 5px; padding: 5px;",
                  p(paste("R", row, "C", col), style = "margin: 0; font-size: 12px; color: #6c757d;"),
                  tags$img(src = paths[index], style = "max-width: 100%; max-height: 120px; object-fit: contain; border-radius: 3px;")
                )
              )
            )
          } else {
            row_images[[col]] <- column(
              width = floor(12 / num_cols),
              div(
                style = "text-align: center; margin-bottom: 10px; height: 120px;",
                div(
                  style = "background-color: #f8f9fa; border: 1px dashed #dee2e6; border-radius: 5px; padding: 5px; height: 100%; display: flex; align-items: center; justify-content: center;",
                  p("Empty", style = "margin: 0; font-size: 12px; color: #adb5bd;")
                )
              )
            )
          }
        }
        
        grid_rows[[row]] <- fluidRow(style = "margin-bottom: 5px;", row_images)
      }
      
      div(
        style = "border: 1px solid #dee2e6; border-radius: 5px; padding: 10px; background-color: white;",
        h6(paste("Grid:", num_rows, "x", num_cols), style = "margin-bottom: 15px; color: #495057; text-align: center;"),
        grid_rows
      )
    })
    
    # Return interface
    return(list(
      has_image = reactive(!is.null(rv$image_path_original)),
      uploaded_image_path = reactive(rv$image_path_original),
      get_grid_info = reactive({
        if (!is.null(rv$current_grid_rows) && !is.null(rv$current_grid_cols)) {
          list(
            rows = rv$current_grid_rows,
            cols = rv$current_grid_cols,
            h_boundaries = rv$h_boundaries,
            v_boundaries = rv$v_boundaries,
            boundaries_manually_adjusted = rv$boundaries_manually_adjusted
          )
        } else {
          NULL
        }
      }),
      is_extraction_complete = reactive(!is.null(rv$extracted_paths_web) && length(rv$extracted_paths_web) > 0),
      get_extracted_paths = reactive(rv$extracted_paths_web),
      get_extraction_dir = reactive({
        if (!is.null(rv$extracted_paths_web) && length(rv$extracted_paths_web) > 0) {
          file.path(session_temp_dir, python_output_subdir_name)
        } else {
          NULL
        }
      }),
      get_extracted_count = reactive(length(rv$extracted_paths_web %||% c())),

      # NEW: Get crop-to-card mapping for AI extraction
      get_crop_card_mapping = reactive(rv$crop_card_mapping),

      # NEW: Reset function for "Start Over" functionality
      reset_module = function() {
        # Set flag to prevent upload observer from triggering
        rv$reset_in_progress <- TRUE

        # Hide UI controls
        shinyjs::hide("rows_control")
        shinyjs::hide("cols_control")
        shinyjs::hide("extract_control")

        # Clear all reactive values
        rv$image_path_original <- NULL
        rv$image_url_display <- NULL
        rv$image_dims_original <- NULL
        rv$h_boundaries <- numeric(0)
        rv$v_boundaries <- numeric(0)
        rv$boundaries_manually_adjusted <- FALSE
        rv$force_grid_redraw <- 0
        rv$current_grid_rows <- NULL
        rv$current_grid_cols <- NULL
        rv$extracted_paths_web <- NULL
        rv$is_extracting <- FALSE

        # NEW: Reset processing status
        rv$processing_status <- "idle"

        # Reset file input (will trigger observer, but flag prevents execution)
        shinyjs::reset("image_upload")

        # Use simple Sys.sleep to let the reset complete, then clear flag
        Sys.sleep(0.1)
        rv$reset_in_progress <- FALSE
      }
    ))
  })

  return(result)
}

## To be copied in the UI
# mod_postal_card_processor_ui("postal_card_processor_1")

## To be copied in the server
# mod_postal_card_processor_server("postal_card_processor_1")
