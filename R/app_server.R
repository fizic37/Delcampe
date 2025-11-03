#' The application server-side - FIXED with import_from_path
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  # ==== GLOBAL ERROR HANDLER FOR PRODUCTION LOGGING ====
  # Catches all unhandled Shiny errors and logs to stderr for shinyapps.io visibility
  options(shiny.error = function() {
    cat(file = stderr(),
        "\n========================================\n",
        "SHINY ERROR DETECTED\n",
        "========================================\n",
        "Time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n",
        "Session: ", session$token, "\n",
        "Error: ", geterrmessage(), "\n",
        "========================================\n\n",
        sep = "")
  })

  # ==== INITIALIZE TRACKING DATABASE ====
  cat("
📊 Initializing tracking database...
")
  db_initialized <- tryCatch({
    initialize_tracking_db("inst/app/data/tracking.sqlite")
  }, error = function(e) {
    cat("⚠️ Failed to initialize database:", e$message, "
")
    FALSE
  })
  
  if (db_initialized) {
    cat("✅ Tracking database ready\n")

    # Initialize eBay tables (includes api_type migration)
    tryCatch({
      initialize_ebay_tables("inst/app/data/tracking.sqlite")
    }, error = function(e) {
      cat("⚠️ Failed to initialize eBay tables:", e$message, "\n")
    })

    # Start session tracking
    tryCatch({
      start_processing_session(
        session_id = session$token,
        user_id = "default_user",
        session_type = "postal_cards"
      )
      cat("✅ Session started:", session$token, "\n")
    }, error = function(e) {
      cat("⚠️ Failed to start session tracking:", e$message, "\n")
    })
  }
  
  # Load Python module using import_from_path (proper reticulate pattern)
  if (!exists(".postal_card_py_module", envir = .GlobalEnv)) {
    cat("\n✨ Importing Python module...\n")
    
    python_script <- system.file("python", "extract_postcards.py", package = "Delcampe")
    if (python_script == "" || !file.exists(python_script)) {
      python_script <- "inst/python/extract_postcards.py"
    }
    
    if (!file.exists(python_script)) {
      cat("❌ Python not found\n\n")
      assign(".postal_card_python_loaded", FALSE, envir = .GlobalEnv)
    } else {
      tryCatch({
        # Use import_from_path - proper reticulate method
        py_module <- reticulate::import_from_path(
          "extract_postcards", 
          path = dirname(python_script),
          delay_load = FALSE
        )
        
        assign(".postal_card_py_module", py_module, envir = .GlobalEnv)
        
        # Create wrapper functions
        detect_grid_layout <- function(image_path) {
          get(".postal_card_py_module", envir = .GlobalEnv)$detect_grid_layout(image_path)
        }
        crop_image_with_boundaries <- function(image_path, h_boundaries, v_boundaries, output_dir) {
          get(".postal_card_py_module", envir = .GlobalEnv)$crop_image_with_boundaries(
            image_path, h_boundaries, v_boundaries, output_dir
          )
        }
        combine_face_verso_images <- function(face_dir, verso_dir, output_dir, num_rows, num_cols) {
          get(".postal_card_py_module", envir = .GlobalEnv)$combine_face_verso_images(
            face_dir, verso_dir, output_dir, num_rows, num_cols
          )
        }
        
        assign("detect_grid_layout", detect_grid_layout, envir = .GlobalEnv)
        assign("crop_image_with_boundaries", crop_image_with_boundaries, envir = .GlobalEnv)
        assign("combine_face_verso_images", combine_face_verso_images, envir = .GlobalEnv)
        assign(".postal_card_python_loaded", TRUE, envir = .GlobalEnv)
        
        cat("✅ Python imported: detect_grid_layout, crop_image_with_boundaries\n\n")
      }, error = function(e) {
        cat("❌ Import failed:", e$message, "\n\n")
        assign(".postal_card_python_loaded", FALSE, envir = .GlobalEnv)
      })
    }
  } else {
    cat("✅ Python already imported\n")
    
    # CRITICAL: Create wrapper functions even if module already exists
    detect_grid_layout <- function(image_path) {
      get(".postal_card_py_module", envir = .GlobalEnv)$detect_grid_layout(image_path)
    }
    crop_image_with_boundaries <- function(image_path, h_boundaries, v_boundaries, output_dir) {
      get(".postal_card_py_module", envir = .GlobalEnv)$crop_image_with_boundaries(
        image_path, h_boundaries, v_boundaries, output_dir
      )
    }
    combine_face_verso_images <- function(face_dir, verso_dir, output_dir, num_rows, num_cols) {
      get(".postal_card_py_module", envir = .GlobalEnv)$combine_face_verso_images(
        face_dir, verso_dir, output_dir, num_rows, num_cols
      )
    }
    
    assign("detect_grid_layout", detect_grid_layout, envir = .GlobalEnv)
    assign("crop_image_with_boundaries", crop_image_with_boundaries, envir = .GlobalEnv)
    assign("combine_face_verso_images", combine_face_verso_images, envir = .GlobalEnv)
    
    cat("✅ Wrapper functions created\n\n")
  }
  
  # Initialize application-wide reactive values
  app_rv <- reactiveValues(
    # Individual extraction status
    face_grid_info = NULL,
    verso_grid_info = NULL,
    face_extraction_complete = FALSE,
    verso_extraction_complete = FALSE,
    
    # Combined processing status
    face_image_uploaded = FALSE,
    verso_image_uploaded = FALSE,
    face_extracted_count = 0,
    verso_extracted_count = 0,
    face_extraction_dir = NULL,
    verso_extraction_dir = NULL,
    
    # Combined processing results
    images_processed = FALSE,
    lot_paths = NULL,
    combined_paths = NULL,
    combined_image_paths = NULL, # For displaying combined images
    combined_file_paths = NULL, # Actual file system paths for combined images (for AI extraction)
    
    # Grid configuration (shared between face/verso)
    num_rows = NULL,
    num_cols = NULL,
    
    # Upload tracking for state management
    last_face_upload_time = NULL,
    last_verso_upload_time = NULL,
    
    # Track extraction source (for auto-combine logic)
    face_used_existing = FALSE,
    verso_used_existing = FALSE
  )

  # Session directory for combined images - CREATE ONCE, not reactive!
  session_temp_dir_path <- tempfile("shiny_combined_images_")
  dir.create(session_temp_dir_path, showWarnings = FALSE, recursive = TRUE)

  # Helper function to get the session temp dir
  session_temp_dir <- function() {
    return(session_temp_dir_path)
  }

  # Resource prefix for combined images - register ONCE at startup
  resource_prefix_combined <- "combined_session_images"
  shiny::addResourcePath(prefix = resource_prefix_combined, directoryPath = session_temp_dir_path)

  # Face processor module with callbacks
  face_server_return <- tryCatch({
    mod_postal_card_processor_server(
      "face_processor",
      card_type = "face",
      on_extraction_complete = function(count, dir, used_existing = FALSE) {
        app_rv$face_extraction_complete <- TRUE
        app_rv$face_extracted_count <- count
        app_rv$face_extraction_dir <- dir
        app_rv$face_used_existing <- used_existing
      },
      on_grid_update = function(rows, cols) {
        app_rv$num_rows <- rows
        app_rv$num_cols <- cols
      },
      on_image_upload = function() {
        app_rv$face_image_uploaded <- TRUE
        app_rv$last_face_upload_time <- Sys.time()
        # Only reset combined images (don't mess with extractions)
        app_rv$images_processed <- FALSE
        app_rv$lot_paths <- NULL
        app_rv$combined_paths <- NULL
        app_rv$combined_image_paths <- NULL
        # Reset face extraction for THIS upload
        app_rv$face_extraction_complete <- FALSE
        app_rv$face_extracted_count <- 0
        app_rv$face_used_existing <- FALSE
      }
    )
  }, error = function(e) {
    cat("❌ ERROR calling face module:", e$message, "\n")
    print(e)
    NULL
  })

  # Verso processor module with callbacks
  verso_server_return <- mod_postal_card_processor_server(
    "verso_processor", 
    card_type = "verso",
    on_extraction_complete = function(count, dir, used_existing = FALSE) {
      app_rv$verso_extraction_complete <- TRUE
      app_rv$verso_extracted_count <- count
      app_rv$verso_extraction_dir <- dir
      app_rv$verso_used_existing <- used_existing
    },
    on_grid_update = function(rows, cols) {
      # Verso can also update grid if needed
      if (is.null(app_rv$num_rows) || is.null(app_rv$num_cols)) {
        app_rv$num_rows <- rows
        app_rv$num_cols <- cols
      }
    },
    on_image_upload = function() {
      app_rv$verso_image_uploaded <- TRUE
      app_rv$last_verso_upload_time <- Sys.time()
      # Only reset combined images (don't mess with extractions)
      app_rv$images_processed <- FALSE
      app_rv$lot_paths <- NULL
      app_rv$combined_paths <- NULL
      app_rv$combined_image_paths <- NULL
      # Reset verso extraction for THIS upload
      app_rv$verso_extraction_complete <- FALSE
      app_rv$verso_extracted_count <- 0
      app_rv$verso_used_existing <- FALSE
    }
  )

  # ======================================================================
  # STAMP PROCESSING MODULES (Parallel to Postal Cards)
  # ======================================================================

  # Stamp Face processor module with callbacks
  stamp_face_server_return <- tryCatch({
    mod_stamp_face_processor_server(
      "stamp_face_processor",
      stamp_type = "face",
      on_extraction_complete = function(count, dir, used_existing = FALSE) {
        app_rv$stamp_face_extraction_complete <- TRUE
        app_rv$stamp_face_extracted_count <- count
        app_rv$stamp_face_extraction_dir <- dir
        app_rv$stamp_face_used_existing <- used_existing
      },
      on_grid_update = function(rows, cols) {
        app_rv$stamp_num_rows <- rows
        app_rv$stamp_num_cols <- cols
      },
      on_image_upload = function() {
        app_rv$stamp_face_image_uploaded <- TRUE
        app_rv$stamp_last_face_upload_time <- Sys.time()
        # Reset stamp combined images
        app_rv$stamp_images_processed <- FALSE
        app_rv$stamp_lot_paths <- NULL
        app_rv$stamp_combined_paths <- NULL
        app_rv$stamp_combined_image_paths <- NULL
        # Reset stamp face extraction for THIS upload
        app_rv$stamp_face_extraction_complete <- FALSE
        app_rv$stamp_face_extracted_count <- 0
        app_rv$stamp_face_used_existing <- FALSE
      }
    )
  }, error = function(e) {
    cat("❌ ERROR calling stamp face module:", e$message, "\n")
    print(e)
    NULL
  })

  # Stamp Verso processor module with callbacks
  stamp_verso_server_return <- tryCatch({
    mod_stamp_verso_processor_server(
      "stamp_verso_processor",
      stamp_type = "verso",
      on_extraction_complete = function(count, dir, used_existing = FALSE) {
        app_rv$stamp_verso_extraction_complete <- TRUE
        app_rv$stamp_verso_extracted_count <- count
        app_rv$stamp_verso_extraction_dir <- dir
        app_rv$stamp_verso_used_existing <- used_existing
      },
      on_grid_update = function(rows, cols) {
        # Stamp verso can also update grid if needed
        if (is.null(app_rv$stamp_num_rows) || is.null(app_rv$stamp_num_cols)) {
          app_rv$stamp_num_rows <- rows
          app_rv$stamp_num_cols <- cols
        }
      },
      on_image_upload = function() {
        app_rv$stamp_verso_image_uploaded <- TRUE
        app_rv$stamp_last_verso_upload_time <- Sys.time()
        # Reset stamp combined images
        app_rv$stamp_images_processed <- FALSE
        app_rv$stamp_lot_paths <- NULL
        app_rv$stamp_combined_paths <- NULL
        app_rv$stamp_combined_image_paths <- NULL
        # Reset stamp verso extraction for THIS upload
        app_rv$stamp_verso_extraction_complete <- FALSE
        app_rv$stamp_verso_extracted_count <- 0
        app_rv$stamp_verso_used_existing <- FALSE
      }
    )
  }, error = function(e) {
    cat("❌ ERROR calling stamp verso module:", e$message, "\n")
    print(e)
    NULL
  })

  # Settings server - FIXED: Changed role to "admin" to show LLM Models tab
  mod_settings_server("settings", reactive(list(email = "admin@delcampe.com", role = "admin")))

  # Tracking viewer server
  mod_tracking_viewer_server("tracking_viewer_1")

  # eBay authentication server - returns list with api and account_manager
  ebay_auth <- mod_ebay_auth_server("ebay_auth")
  ebay_api <- ebay_auth$api
  ebay_account_manager <- ebay_auth$account_manager

  # eBay Listings Viewer server
  mod_ebay_listings_server("ebay_listings", ebay_api = ebay_api, session_id = reactive(session$token))

  # ======================================================================
  # eBay STARTUP NOTIFICATION - Proactive Status Alert
  # ======================================================================
  # Architecture: Query ONCE on startup, not continuously
  # Shows user eBay connection status before they navigate to eBay tab
  # No reactive timers - resource efficient approach per user feedback
  observe({
    # Run once on startup (isolate to prevent reactive dependencies)
    isolate({
      active_account <- ebay_account_manager$get_active_account()

      # Only show notification if an account is connected
      if (!is.null(active_account)) {
        # Calculate token status using helper function
        token_status <- get_token_status(active_account$token_expiry)

        # Determine notification type based on status
        notification_type <- if (token_status$status == "expired") {
          "error"
        } else if (token_status$status %in% c("critical", "warning")) {
          "warning"
        } else {
          "message"
        }

        # Build notification message with HTML formatting
        notification_message <- HTML(paste0(
          "<div style='font-size: 14px;'>",
          "<strong style='font-size: 16px;'>eBay Connected:</strong> ",
          "<span style='font-family: monospace;'>", active_account$username, "</span><br>",
          "<strong>Environment:</strong> ",
          "<span style='",
          if (active_account$environment == "production") {
            "color: green; font-weight: bold;"
          } else {
            "color: orange; font-weight: bold;"
          },
          "'>", toupper(active_account$environment), "</span><br>",
          "<strong>Token Status:</strong> ",
          token_status$status_text,
          " <span style='color: #666;'>- expires ", token_status$time_remaining, "</span>",
          if (token_status$needs_attention) {
            paste0("<br><em style='font-size: 12px; color: #666;'>",
                   "Visit Settings → eBay Connection for details",
                   "</em>")
          } else {
            ""
          },
          "</div>"
        ))

        # Show notification
        showNotification(
          notification_message,
          type = notification_type,
          duration = if (token_status$needs_attention) NULL else 10,  # Persist if action needed
          closeButton = TRUE
        )

        # Log to console for debugging (production logging)
        cat("\n📊 eBay Status Notification (Startup):\n")
        cat("   Account:", active_account$username, "\n")
        cat("   Environment:", active_account$environment, "\n")
        cat("   Status:", token_status$status_text, "\n")
        cat("   Time remaining:", token_status$time_remaining, "\n")
        cat("   Needs attention:", token_status$needs_attention, "\n\n")
      } else {
        # No account connected - silent (no notification spam)
        cat("📊 eBay Status: No account connected\n\n")
      }
    })
  })

  # Update grid info from active modules (SINGLE observer per module, no duplicates)
  observe({
    face_grid <- face_server_return$get_grid_info()
    if (!is.null(face_grid)) {
      app_rv$face_grid_info <- face_grid
    }
  })

  observe({
    verso_grid <- verso_server_return$get_grid_info()
    if (!is.null(verso_grid)) {
      app_rv$verso_grid_info <- verso_grid
    }
  })

  # FIXED: Smart combined image output display - shows button OR results at top
  output$combined_image_output_display <- renderUI({
    # Show "Start Over" button if any processing has been done
    show_reset_button <- app_rv$face_image_uploaded || app_rv$verso_image_uploaded

    # State 1: Nothing uploaded yet OR images uploaded but not extracted
    if (!app_rv$face_extraction_complete || !app_rv$verso_extraction_complete) {
      bslib::card(
        header = bslib::card_header(
          div(
            style = "display: flex; justify-content: space-between; align-items: center;",
            span("Processing Status"),
            if (show_reset_button) {
              actionButton(
                inputId = "start_over",
                label = "Start Over",
                icon = icon("redo"),
                class = "btn-sm btn-outline-light",
                style = "border-color: white; color: white;"
              )
            }
          ),
          style = "background-color: #6c757d; color: white;"
        ),
        class = "combined-output-card compact-status-card",
        div(
          style = "padding: 12px 20px; display: flex; align-items: center; justify-content: space-between; gap: 15px;",
          div(
            style = "font-weight: 600; color: #6c757d;",
            "📸 Upload and extract both sides"
          ),
          div(
            style = "display: flex; gap: 10px;",
            div(
              style = paste0("padding: 6px 16px; border-radius: 15px; font-size: 13px; font-weight: 600; ",
                            if(app_rv$face_extraction_complete) "background-color: #d4edda; color: #155724;" else "background-color: #f8d7da; color: #721c24;"),
              if(app_rv$face_extraction_complete) "✓ Face Extracted" else "○ Face Needed"
            ),
            div(
              style = paste0("padding: 6px 16px; border-radius: 15px; font-size: 13px; font-weight: 600; ",
                            if(app_rv$verso_extraction_complete) "background-color: #d4edda; color: #155724;" else "background-color: #f8d7da; color: #721c24;"),
              if(app_rv$verso_extraction_complete) "✓ Verso Extracted" else "○ Verso Needed"
            )
          )
        )
      )
    }
    # State 2: Both extractions complete - decide auto vs manual
    else if (app_rv$face_extraction_complete && app_rv$verso_extraction_complete && !app_rv$images_processed) {

      # Check if BOTH used existing (Task 09: auto-combine only in this case)
      both_used_existing <- app_rv$face_used_existing && app_rv$verso_used_existing

      if (both_used_existing) {
        # AUTO-COMBINE: Both used existing crops
      
      # Automatically trigger processing when both extractions are complete
      # This runs once per reactive cycle, then images_processed becomes TRUE
      isolate({
        tryCatch({
          # Check if Python is available
          if (!exists("combine_face_verso_images", envir = .GlobalEnv)) {
            showNotification("Python functions not available. Please restart the app.", type = "error")
            return(NULL)
          }
          
          # Save combined images directly to session temp dir (no subdirectory)
          # This ensures web resource path matches file system location
          combined_output_dir <- session_temp_dir()
          
          # Get grid dimensions
          num_rows <- app_rv$num_rows %||% 1
          num_cols <- app_rv$num_cols %||% 1
          
          cat("
🎨 AUTO-PROCESSING COMBINED IMAGES:
")
          cat("   Face dir:", app_rv$face_extraction_dir, "
")
          cat("   Verso dir:", app_rv$verso_extraction_dir, "
")
          cat("   Output dir:", combined_output_dir, "
")
          cat("   Grid:", num_rows, "x", num_cols, "
")
          
          # Call Python function to combine images
          py_results <- combine_face_verso_images(
            face_dir = app_rv$face_extraction_dir,
            verso_dir = app_rv$verso_extraction_dir,
            output_dir = combined_output_dir,
            num_rows = as.integer(num_rows),
            num_cols = as.integer(num_cols)
          )
          
          cat("   Python results:
")
          cat("     Lot paths:", length(py_results$lot_paths), "
")
          cat("     Combined paths:", length(py_results$combined_paths), "
")
          
          if (!is.null(py_results$lot_paths) && length(py_results$lot_paths) > 0) {
            # Convert file paths to web URLs
            abs_lot_paths <- normalizePath(unlist(py_results$lot_paths), winslash = "/")
            abs_combined_paths <- normalizePath(unlist(py_results$combined_paths), winslash = "/")
            abs_session_dir <- normalizePath(session_temp_dir(), winslash = "/")
            
            rel_lot_paths <- sub(paste0("^", gsub("/", "\\/", abs_session_dir), "/*"), "", abs_lot_paths)
            rel_combined_paths <- sub(paste0("^", gsub("/", "\\/", abs_session_dir), "/*"), "", abs_combined_paths)
            
            rel_lot_paths <- sub("^/*", "", rel_lot_paths)
            rel_combined_paths <- sub("^/*", "", rel_combined_paths)
            
            # Create web URLs
            app_rv$lot_paths <- paste("combined_session_images", rel_lot_paths, sep = "/")
            app_rv$combined_paths <- paste("combined_session_images", rel_combined_paths, sep = "/")
            app_rv$combined_image_paths <- app_rv$combined_paths

            # Store actual file system paths for AI extraction
            app_rv$combined_file_paths <- abs_combined_paths

            app_rv$images_processed <- TRUE

            # Track combined images in database
            tryCatch({
              # For each combined image, create a card entry
              combined_card_ids <- list()
              for (i in seq_along(abs_combined_paths)) {
                combined_path <- abs_combined_paths[i]

                # Calculate hash for combined image
                combined_hash <- calculate_image_hash(combined_path)

                if (!is.null(combined_hash)) {
                  # Create card entry for combined image
                  card_id <- get_or_create_card(
                    file_hash = combined_hash,
                    image_type = "combined",
                    original_filename = basename(combined_path),
                    file_size = file.info(combined_path)$size
                  )

                  combined_card_ids[[i]] <- card_id

                  # Save processing details (no crops, but track grid info)
                  save_card_processing(
                    card_id = card_id,
                    crop_paths = NULL,
                    h_boundaries = NULL,
                    v_boundaries = NULL,
                    grid_rows = as.integer(num_rows),
                    grid_cols = as.integer(num_cols),
                    extraction_dir = as.character(combined_output_dir),
                    ai_data = NULL
                  )

                  # Track session activity
                  track_session_activity(
                    session_id = session$token,
                    card_id = card_id,
                    action = "images_combined",
                    details = list(
                      combined_index = i,
                      combined_path = combined_path,
                      grid = paste0(num_rows, "x", num_cols),
                      auto_combined = TRUE
                    )
                  )
                }
              }

              # Store combined card IDs for AI extraction
              app_rv$combined_card_ids <- combined_card_ids

              message("✅ Combined images tracked in database: ", length(combined_card_ids), " cards")
            }, error = function(e) {
              message("⚠️ Failed to track combined images: ", e$message)
            })

            # Track lot images in database (if they exist)
            tryCatch({
              lot_card_ids <- list()
              for (i in seq_along(abs_lot_paths)) {
                lot_path <- abs_lot_paths[i]

                # Calculate hash for lot image
                lot_hash <- calculate_image_hash(lot_path)

                if (!is.null(lot_hash)) {
                  # Create card entry for lot image
                  card_id <- get_or_create_card(
                    file_hash = lot_hash,
                    image_type = "lot",
                    original_filename = basename(lot_path),
                    file_size = file.info(lot_path)$size
                  )

                  lot_card_ids[[i]] <- card_id

                  # Save processing details for lot
                  save_card_processing(
                    card_id = card_id,
                    crop_paths = NULL,
                    h_boundaries = NULL,
                    v_boundaries = NULL,
                    grid_rows = as.integer(num_rows),
                    grid_cols = as.integer(num_cols),
                    extraction_dir = as.character(combined_output_dir),
                    ai_data = NULL
                  )

                  # Track session activity
                  track_session_activity(
                    session_id = session$token,
                    card_id = card_id,
                    action = "lot_created",
                    details = list(
                      lot_index = i,
                      lot_path = lot_path,
                      grid = paste0(num_rows, "x", num_cols)
                    )
                  )
                }
              }

              # Store lot card IDs for AI extraction
              app_rv$lot_card_ids <- lot_card_ids

              message("✅ Lot images tracked in database: ", length(lot_card_ids), " lot images")
            }, error = function(e) {
              message("⚠️ Failed to track lot images: ", e$message)
            })

            cat("✅ Auto-processing complete!

")

            # NOTE: AI extraction removed - was causing long waits without user consent
            # TODO: Add opt-in "Extract with AI" button if needed

          } else {
            showNotification("No images were generated. Check the console for details.", type = "warning")
          }
          
        }, error = function(e) {
          cat("❌ ERROR in auto-processing:
")
          cat("   Message:", e$message, "
")
          cat("   Call:", deparse(e$call), "
")
          showNotification(paste("Processing failed:", e$message), type = "error")
        })
      })
      
      # Show processing indicator while waiting
      bslib::card(
        header = bslib::card_header(
          "Processing Combined Images...",
          style = "background-color: #28a745; color: white;"
        ),
        class = "combined-output-card compact-status-card",
        div(
          style = "padding: 20px; text-align: center;",
          div(
            style = "display: inline-block; width: 40px; height: 40px; border: 4px solid #f3f3f3; border-radius: 50%; border-top: 4px solid #28a745; animation: spin 1s linear infinite;",
            tags$style(HTML("@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }"))
          ),
          p(
            paste(app_rv$face_extracted_count, "face +", 
                 app_rv$verso_extracted_count, "verso images"), 
            style = "margin-top: 15px; font-size: 14px; color: #666;"
          )
        )
      )
      } else {
        # MANUAL BUTTON: One or both extracted normally
        bslib::card(
          header = bslib::card_header(
            div(
              style = "display: flex; justify-content: space-between; align-items: center;",
              span("Ready to Combine Images"),
              actionButton(
                inputId = "start_over",
                label = "Start Over",
                icon = icon("redo"),
                class = "btn-sm btn-outline-light",
                style = "border-color: white; color: white;"
              )
            ),
            style = "background-color: #28a745; color: white;"
          ),
          class = "combined-output-card compact-status-card",
          div(
            style = "padding: 15px; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap;",
            div(
              style = "flex: 1; min-width: 200px;",
              h5("🎯 Both sides processed!", style = "color: #28a745; margin: 0 0 5px 0;"),
              p(paste(app_rv$face_extracted_count, "face +",
                     app_rv$verso_extracted_count, "verso images"),
                style = "margin: 0; font-size: 14px; color: #666;")
            ),
            actionButton(
              inputId = "process_combined",
              label = "Combine Images",
              icon = icon("wand-magic-sparkles"),
              class = "btn-lg btn-success",
              style = "background: linear-gradient(135deg, #52B788 0%, #40916C 100%); border: none; color: white; padding: 15px 40px; border-radius: 12px; font-weight: 700; font-size: 18px; box-shadow: 0 4px 15px rgba(82, 183, 136, 0.4); transition: all 0.3s ease; cursor: pointer;"
            )
          )
        )
      }
    }
    # State 3: Images processed - show success message with Start Over button
    else if (app_rv$images_processed) {
      div(
        style = "background-color: #d4edda; border: 2px solid #28a745; border-radius: 8px; padding: 20px; margin-bottom: 20px;",
        div(
          style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;",
          h4(
            style = "margin: 0; color: #155724;",
            "Processing Complete!"
          ),
          actionButton(
            inputId = "start_over",
            label = "Start Over",
            icon = icon("redo"),
            class = "btn btn-success",
            style = "background-color: #28a745;"
          )
        ),
        p(
          style = "margin: 0; color: #155724; font-weight: 600;",
          "Combined images are ready for export below. Click Start Over to process new images."
        )
      )
    }
  })

  # Reset button handler - allows processing new images without refreshing
  observeEvent(input$reset_processing, {
    # Reset combined processing state but keep face/verso extractions
    app_rv$images_processed <- FALSE
    app_rv$lot_paths <- NULL
    app_rv$combined_paths <- NULL
    app_rv$combined_image_paths <- NULL
    
    showNotification(
      "Ready to process new combination. You can adjust grid or upload new images.",
      type = "message",
      duration = 5
    )
  })
  
  # "Start Over" button - complete workflow reset for new upload session
  observeEvent(input$start_over, {
    # Reset Face module
    if (!is.null(face_server_return) && !is.null(face_server_return$reset_module)) {
      face_server_return$reset_module()
    }

    # Reset Verso module
    if (!is.null(verso_server_return) && !is.null(verso_server_return$reset_module)) {
      verso_server_return$reset_module()
    }

    # Reset all app-level reactive values
    app_rv$face_grid_info <- NULL
    app_rv$verso_grid_info <- NULL
    app_rv$face_extraction_complete <- FALSE
    app_rv$verso_extraction_complete <- FALSE
    app_rv$face_image_uploaded <- FALSE
    app_rv$verso_image_uploaded <- FALSE
    app_rv$face_extracted_count <- 0
    app_rv$verso_extracted_count <- 0
    app_rv$face_extraction_dir <- NULL
    app_rv$verso_extraction_dir <- NULL
    app_rv$images_processed <- FALSE
    app_rv$lot_paths <- NULL
    app_rv$combined_paths <- NULL
    app_rv$combined_image_paths <- NULL
    app_rv$num_rows <- NULL
    app_rv$num_cols <- NULL
    app_rv$last_face_upload_time <- NULL
    app_rv$last_verso_upload_time <- NULL

    showNotification(
      "🔄 Ready for new upload session. Upload Face and Verso images to begin.",
      type = "message",
      duration = 5
    )
  })

  # Process combined images
  observeEvent(input$process_combined, {
    if (app_rv$face_extraction_complete && app_rv$verso_extraction_complete) {
      
      tryCatch({
        # Check if Python is available
        if (!exists("combine_face_verso_images", envir = .GlobalEnv)) {
          showNotification("Python functions not available. Please restart the app.", type = "error")
          return()
        }
        
        # Save combined images directly to session temp dir (no subdirectory)
        # This ensures web resource path matches file system location
        combined_output_dir <- session_temp_dir()
        
        # Get grid dimensions
        num_rows <- app_rv$num_rows %||% 1
        num_cols <- app_rv$num_cols %||% 1
        
        cat("\n🎨 PROCESSING COMBINED IMAGES:\n")
        cat("   Face dir:", app_rv$face_extraction_dir, "\n")
        cat("   Verso dir:", app_rv$verso_extraction_dir, "\n")
        cat("   Output dir:", combined_output_dir, "\n")
        cat("   Grid:", num_rows, "x", num_cols, "\n")
        
        # Call Python function to combine images
        py_results <- combine_face_verso_images(
          face_dir = app_rv$face_extraction_dir,
          verso_dir = app_rv$verso_extraction_dir,
          output_dir = combined_output_dir,
          num_rows = as.integer(num_rows),
          num_cols = as.integer(num_cols)
        )
        
        cat("   Python results:\n")
        cat("     Lot paths:", length(py_results$lot_paths), "\n")
        cat("     Combined paths:", length(py_results$combined_paths), "\n")
        
        if (!is.null(py_results$lot_paths) && length(py_results$lot_paths) > 0) {
          # Convert file paths to web URLs
          abs_lot_paths <- normalizePath(unlist(py_results$lot_paths), winslash = "/")
          abs_combined_paths <- normalizePath(unlist(py_results$combined_paths), winslash = "/")
          abs_session_dir <- normalizePath(session_temp_dir(), winslash = "/")
          
          rel_lot_paths <- sub(paste0("^", gsub("/", "\\\\/", abs_session_dir), "/*"), "", abs_lot_paths)
          rel_combined_paths <- sub(paste0("^", gsub("/", "\\\\/", abs_session_dir), "/*"), "", abs_combined_paths)
          
          rel_lot_paths <- sub("^/*", "", rel_lot_paths)
          rel_combined_paths <- sub("^/*", "", rel_combined_paths)
          
          # Create web URLs
          app_rv$lot_paths <- paste("combined_session_images", rel_lot_paths, sep = "/")
          app_rv$combined_paths <- paste("combined_session_images", rel_combined_paths, sep = "/")
          app_rv$combined_image_paths <- app_rv$combined_paths

          # Store actual file system paths for AI extraction
          app_rv$combined_file_paths <- abs_combined_paths

          app_rv$images_processed <- TRUE

          # Track combined images in database
          tryCatch({
            # For each combined image, create a card entry
            combined_card_ids <- list()
            for (i in seq_along(abs_combined_paths)) {
              combined_path <- abs_combined_paths[i]

              # Calculate hash for combined image
              combined_hash <- calculate_image_hash(combined_path)

              if (!is.null(combined_hash)) {
                # Create card entry for combined image
                card_id <- get_or_create_card(
                  file_hash = combined_hash,
                  image_type = "combined",
                  original_filename = basename(combined_path),
                  file_size = file.info(combined_path)$size
                )

                combined_card_ids[[i]] <- card_id

                # Save processing details (no crops, but track grid info)
                save_card_processing(
                  card_id = card_id,
                  crop_paths = NULL,
                  h_boundaries = NULL,
                  v_boundaries = NULL,
                  grid_rows = as.integer(num_rows),
                  grid_cols = as.integer(num_cols),
                  extraction_dir = as.character(combined_output_dir),
                  ai_data = NULL
                )

                # Track session activity
                track_session_activity(
                  session_id = session$token,
                  card_id = card_id,
                  action = "images_combined",
                  details = list(
                    combined_index = i,
                    combined_path = combined_path,
                    grid = paste0(num_rows, "x", num_cols)
                  )
                )
              }
            }

            # Store combined card IDs for AI extraction
            app_rv$combined_card_ids <- combined_card_ids

            message("✅ Combined images tracked in database: ", length(combined_card_ids), " cards")
          }, error = function(e) {
            message("⚠️ Failed to track combined images: ", e$message)
          })

          # Track lot images in database (if they exist)
          tryCatch({
            lot_card_ids <- list()
            for (i in seq_along(abs_lot_paths)) {
              lot_path <- abs_lot_paths[i]

              # Calculate hash for lot image
              lot_hash <- calculate_image_hash(lot_path)

              if (!is.null(lot_hash)) {
                # Create card entry for lot image
                card_id <- get_or_create_card(
                  file_hash = lot_hash,
                  image_type = "lot",
                  original_filename = basename(lot_path),
                  file_size = file.info(lot_path)$size
                )

                lot_card_ids[[i]] <- card_id

                # Save processing details for lot
                save_card_processing(
                  card_id = card_id,
                  crop_paths = NULL,
                  h_boundaries = NULL,
                  v_boundaries = NULL,
                  grid_rows = as.integer(num_rows),
                  grid_cols = as.integer(num_cols),
                  extraction_dir = as.character(combined_output_dir),
                  ai_data = NULL
                )

                # Track session activity
                track_session_activity(
                  session_id = session$token,
                  card_id = card_id,
                  action = "lot_created",
                  details = list(
                    lot_index = i,
                    lot_path = lot_path,
                    grid = paste0(num_rows, "x", num_cols)
                  )
                )
              }
            }

            # Store lot card IDs for AI extraction
            app_rv$lot_card_ids <- lot_card_ids

            message("✅ Lot images tracked in database: ", length(lot_card_ids), " lot images")
          }, error = function(e) {
            message("⚠️ Failed to track lot images: ", e$message)
          })

          cat("✅ Manual processing complete!\n\n")

          # NOTE: AI extraction removed - was causing long waits without user consent
          # TODO: Add opt-in "Extract with AI" button if needed
        } else {
          showNotification("No images were generated. Check the console for details.", type = "warning")
        }
        
      }, error = function(e) {
        cat("❌ ERROR in process_combined:\n")
        cat("   Message:", e$message, "\n")
        cat("   Call:", deparse(e$call), "\n")
        showNotification(paste("Processing failed:", e$message), type = "error")
      })
    }
  })

  # Export section display - shown below Face/Verso columns after processing
  output$export_section_display <- renderUI({
    if (app_rv$images_processed) {
      bslib::card(
        header = bslib::card_header(
          "Export Images to Delcampe",
          style = "background-color: #40916C; color: white;"
        ),
        div(
          style = "padding: 20px;",
          fluidRow(
            column(
              width = 12,
              h5("📦 Postal Card Lots", style = "margin-bottom: 15px; color: #495057;"),
              p("Export complete lots (vertical stacks by column)",
                style = "font-size: 13px; color: #666; margin-bottom: 15px;"),
              mod_delcampe_export_ui("lot_export")
            )
          ),
          fluidRow(
            column(
              width = 12,
              h5("🖼️ Individual Combined Images", style = "margin-bottom: 15px; color: #495057;"),
              p("Export individual face+verso pairs",
                style = "font-size: 13px; color: #666; margin-bottom: 15px;"),
              mod_delcampe_export_ui("combined_export")
            )
          )
        )
      )
    }
  })

  # Export modules - must be initialized outside reactive context
  mod_delcampe_export_server(
    "lot_export",
    image_paths = reactive(app_rv$lot_paths),
    image_type = "lot",
    ebay_api = ebay_api,
    ebay_account_manager = ebay_account_manager
  )

  mod_delcampe_export_server(
    "combined_export",
    image_paths = reactive(app_rv$combined_paths),
    image_file_paths = reactive(app_rv$combined_file_paths),
    image_type = "combined",
    ebay_api = ebay_api,
    ebay_account_manager = ebay_account_manager
  )

  # ======================================================================
  # STAMP EXPORT MODULES (Parallel to Postal Cards)
  # ======================================================================

  mod_stamp_export_server(
    "stamp_lot_export",
    image_paths = reactive(app_rv$stamp_lot_paths),
    image_type = "lot",
    ebay_api = ebay_api,
    ebay_account_manager = ebay_account_manager
  )

  mod_stamp_export_server(
    "stamp_combined_export",
    image_paths = reactive(app_rv$stamp_combined_paths),
    image_file_paths = reactive(app_rv$stamp_combined_file_paths),
    image_type = "combined",
    ebay_api = ebay_api,
    ebay_account_manager = ebay_account_manager
  )

  # ======================================================================
  # STAMP OUTPUT DISPLAYS (Parallel to Postal Cards)
  # ======================================================================

  # ======================================================================
  # STAMP OUTPUT DISPLAYS - Purple Theme for Visual Distinction
  # ======================================================================

  output$stamp_combined_image_output_display <- renderUI({
    # Show "Start Over" button if any processing has been done
    show_reset_button <- isTRUE(app_rv$stamp_face_image_uploaded) || isTRUE(app_rv$stamp_verso_image_uploaded)

    # State 1: Nothing uploaded yet OR images uploaded but not extracted
    if (!isTRUE(app_rv$stamp_face_extraction_complete) || !isTRUE(app_rv$stamp_verso_extraction_complete)) {
      bslib::card(
        header = bslib::card_header(
          div(
            style = "display: flex; justify-content: space-between; align-items: center;",
            span("🟣 Stamp Processing Status"),
            if (show_reset_button) {
              actionButton(
                inputId = "stamp_start_over",
                label = "Start Over",
                icon = icon("redo"),
                class = "btn-sm btn-outline-light",
                style = "border-color: white; color: white;"
              )
            }
          ),
          style = "background-color: #7B2CBF; color: white;"  # Purple theme
        ),
        class = "combined-output-card compact-status-card",
        div(
          style = "padding: 12px 20px; display: flex; align-items: center; justify-content: space-between; gap: 15px;",
          div(
            style = "font-weight: 600; color: #7B2CBF;",
            "🟣 Upload and extract both stamp sides"
          ),
          div(
            style = "display: flex; gap: 10px;",
            div(
              style = paste0("padding: 6px 16px; border-radius: 15px; font-size: 13px; font-weight: 600; ",
                            if(isTRUE(app_rv$stamp_face_extraction_complete)) "background-color: #e0d4f7; color: #4c1d95;" else "background-color: #f3e5f5; color: #7B2CBF; border: 2px solid #9D4EDD;"),
              if(isTRUE(app_rv$stamp_face_extraction_complete)) "✓ Face Extracted" else "○ Face Needed"
            ),
            div(
              style = paste0("padding: 6px 16px; border-radius: 15px; font-size: 13px; font-weight: 600; ",
                            if(isTRUE(app_rv$stamp_verso_extraction_complete)) "background-color: #e0d4f7; color: #4c1d95;" else "background-color: #f3e5f5; color: #7B2CBF; border: 2px solid #9D4EDD;"),
              if(isTRUE(app_rv$stamp_verso_extraction_complete)) "✓ Verso Extracted" else "○ Verso Needed"
            )
          )
        )
      )
    }
    # State 2: Both extractions complete but not yet combined
    else if (isTRUE(app_rv$stamp_face_extraction_complete) && isTRUE(app_rv$stamp_verso_extraction_complete) &&
             (is.null(app_rv$stamp_combined_paths) || length(app_rv$stamp_combined_paths) == 0)) {

      bslib::card(
        header = bslib::card_header(
          div(
            style = "display: flex; justify-content: space-between; align-items: center;",
            span("🟣 Ready to Combine Stamp Images"),
            actionButton(
              inputId = "stamp_start_over",
              label = "Start Over",
              icon = icon("redo"),
              class = "btn-sm btn-outline-light",
              style = "border-color: white; color: white;"
            )
          ),
          style = "background-color: #9D4EDD; color: white;"  # Lighter purple
        ),
        class = "combined-output-card compact-status-card",
        div(
          style = "padding: 15px; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap;",
          div(
            style = "flex: 1; min-width: 200px;",
            h5("🎯 Both stamp sides processed!", style = "color: #9D4EDD; margin: 0 0 5px 0;"),
            p(paste(app_rv$stamp_face_extracted_count, "face +",
                   app_rv$stamp_verso_extracted_count, "verso images"),
              style = "margin: 0; font-size: 14px; color: #666;")
          ),
          actionButton(
            inputId = "process_stamp_combined",
            label = "Combine Stamp Images",
            icon = icon("wand-magic-sparkles"),
            class = "btn-lg",
            style = "background: linear-gradient(135deg, #9D4EDD 0%, #7B2CBF 100%); border: none; color: white; padding: 15px 40px; border-radius: 12px; font-weight: 700; font-size: 18px; box-shadow: 0 4px 15px rgba(157, 78, 221, 0.4); transition: all 0.3s ease; cursor: pointer;"
          )
        )
      )
    }
    # State 3: Images combined - show success message with Start Over button
    else if (!is.null(app_rv$stamp_combined_paths) && length(app_rv$stamp_combined_paths) > 0) {
      div(
        style = "background-color: #e0d4f7; border: 2px solid #9D4EDD; border-radius: 8px; padding: 20px; margin-bottom: 20px;",
        div(
          style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;",
          h4(
            style = "margin: 0; color: #4c1d95;",
            "🟣 Stamp Processing Complete!"
          ),
          actionButton(
            inputId = "stamp_start_over",
            label = "Start Over",
            icon = icon("redo"),
            class = "btn",
            style = "background-color: #9D4EDD; color: white; border: none;"
          )
        ),
        p(
          style = "margin: 0; color: #4c1d95; font-weight: 600;",
          "Combined stamp images are ready for export below. Click Start Over to process new stamps."
        )
      )
    }
  })

  output$stamp_export_section_display <- renderUI({
    if (!is.null(app_rv$stamp_combined_paths) && length(app_rv$stamp_combined_paths) > 0) {
      bslib::card(
        header = bslib::card_header(
          "🟣 Export Stamps to eBay",
          style = "background-color: #7B2CBF; color: white;"  # Purple theme
        ),
        div(
          style = "padding: 20px;",
          fluidRow(
            column(
              width = 12,
              h5("📦 Stamp Lots", style = "margin-bottom: 15px; color: #7B2CBF;"),
              p("Export complete stamp lots (vertical stacks by column)",
                style = "font-size: 13px; color: #666; margin-bottom: 15px;"),
              mod_stamp_export_ui("stamp_lot_export")
            )
          ),
          fluidRow(
            column(
              width = 12,
              h5("🖼️ Individual Combined Stamp Images", style = "margin-bottom: 15px; color: #7B2CBF;"),
              p("Export individual face+verso stamp pairs",
                style = "font-size: 13px; color: #666; margin-bottom: 15px;"),
              mod_stamp_export_ui("stamp_combined_export")
            )
          )
        )
      )
    }
  })

  # ======================================================================
  # STAMP BUTTON HANDLERS - Purple Theme
  # ======================================================================

  # "Combine Stamp Images" button handler
  observeEvent(input$process_stamp_combined, {
    if (isTRUE(app_rv$stamp_face_extraction_complete) && isTRUE(app_rv$stamp_verso_extraction_complete)) {

      tryCatch({
        # Check if Python is available
        if (!exists("combine_face_verso_images", envir = .GlobalEnv)) {
          showNotification("Python functions not available. Please restart the app.", type = "error")
          return()
        }

        # Save combined images directly to session temp dir
        combined_output_dir <- session_temp_dir()

        # Get grid dimensions
        num_rows <- app_rv$stamp_num_rows %||% 1
        num_cols <- app_rv$stamp_num_cols %||% 1

        cat("\n🟣 PROCESSING COMBINED STAMP IMAGES:\n")
        cat("   Face dir:", app_rv$stamp_face_extraction_dir, "\n")
        cat("   Verso dir:", app_rv$stamp_verso_extraction_dir, "\n")
        cat("   Output dir:", combined_output_dir, "\n")
        cat("   Grid:", num_rows, "x", num_cols, "\n")

        # Call Python function to combine images
        py_results <- combine_face_verso_images(
          face_dir = app_rv$stamp_face_extraction_dir,
          verso_dir = app_rv$stamp_verso_extraction_dir,
          output_dir = combined_output_dir,
          num_rows = as.integer(num_rows),
          num_cols = as.integer(num_cols)
        )

        if (!is.null(py_results$lot_paths) && length(py_results$lot_paths) > 0) {
          # Convert file paths to web URLs
          abs_lot_paths <- normalizePath(unlist(py_results$lot_paths), winslash = "/")
          abs_combined_paths <- normalizePath(unlist(py_results$combined_paths), winslash = "/")
          abs_session_dir <- normalizePath(session_temp_dir(), winslash = "/")

          rel_lot_paths <- sub(paste0("^", gsub("/", "\\/", abs_session_dir), "/*"), "", abs_lot_paths)
          rel_combined_paths <- sub(paste0("^", gsub("/", "\\/", abs_session_dir), "/*"), "", abs_combined_paths)

          rel_lot_paths <- sub("^/*", "", rel_lot_paths)
          rel_combined_paths <- sub("^/*", "", rel_combined_paths)

          # Create web URLs
          app_rv$stamp_lot_paths <- paste("combined_session_images", rel_lot_paths, sep = "/")
          app_rv$stamp_combined_paths <- paste("combined_session_images", rel_combined_paths, sep = "/")
          app_rv$stamp_combined_file_paths <- abs_combined_paths

          # Track combined stamp images in database
          tryCatch({
            combined_stamp_ids <- list()
            for (i in seq_along(abs_combined_paths)) {
              combined_path <- abs_combined_paths[i]
              combined_hash <- calculate_image_hash(combined_path)

              if (!is.null(combined_hash)) {
                stamp_id <- get_or_create_stamp(
                  file_hash = combined_hash,
                  image_type = "combined",
                  original_filename = basename(combined_path),
                  file_size = file.info(combined_path)$size
                )

                combined_stamp_ids[[i]] <- stamp_id

                save_stamp_processing(
                  stamp_id = stamp_id,
                  crop_paths = NULL,
                  h_boundaries = NULL,
                  v_boundaries = NULL,
                  grid_rows = as.integer(num_rows),
                  grid_cols = as.integer(num_cols),
                  extraction_dir = as.character(combined_output_dir),
                  ai_data = NULL
                )

                track_stamp_activity(
                  session_id = session$token,
                  stamp_id = stamp_id,
                  action = "images_combined",
                  details = list(
                    combined_index = i,
                    combined_path = combined_path,
                    grid = paste0(num_rows, "x", num_cols)
                  )
                )
              }
            }

            app_rv$stamp_combined_stamp_ids <- combined_stamp_ids
            message("✅ Combined stamp images tracked: ", length(combined_stamp_ids), " stamps")
          }, error = function(e) {
            message("⚠️ Failed to track combined stamps: ", e$message)
          })

          # Track stamp lot images
          tryCatch({
            lot_stamp_ids <- list()
            for (i in seq_along(abs_lot_paths)) {
              lot_path <- abs_lot_paths[i]
              lot_hash <- calculate_image_hash(lot_path)

              if (!is.null(lot_hash)) {
                stamp_id <- get_or_create_stamp(
                  file_hash = lot_hash,
                  image_type = "lot",
                  original_filename = basename(lot_path),
                  file_size = file.info(lot_path)$size
                )

                lot_stamp_ids[[i]] <- stamp_id

                save_stamp_processing(
                  stamp_id = stamp_id,
                  crop_paths = NULL,
                  h_boundaries = NULL,
                  v_boundaries = NULL,
                  grid_rows = as.integer(num_rows),
                  grid_cols = as.integer(num_cols),
                  extraction_dir = as.character(combined_output_dir),
                  ai_data = NULL
                )

                track_stamp_activity(
                  session_id = session$token,
                  stamp_id = stamp_id,
                  action = "lot_created",
                  details = list(
                    lot_index = i,
                    lot_path = lot_path,
                    grid = paste0(num_rows, "x", num_cols)
                  )
                )
              }
            }

            app_rv$stamp_lot_stamp_ids <- lot_stamp_ids
            message("✅ Stamp lot images tracked: ", length(lot_stamp_ids), " lots")
          }, error = function(e) {
            message("⚠️ Failed to track stamp lots: ", e$message)
          })

          cat("✅ Stamp processing complete!\n\n")

        } else {
          showNotification("No images were generated. Check the console for details.", type = "warning")
        }

      }, error = function(e) {
        cat("❌ ERROR in process_stamp_combined:\n")
        cat("   Message:", e$message, "\n")
        showNotification(paste("Stamp processing failed:", e$message), type = "error")
      })
    }
  })

  # "Start Over" button for stamps - complete workflow reset
  observeEvent(input$stamp_start_over, {
    # Reset Stamp Face module
    if (!is.null(stamp_face_server_return) && !is.null(stamp_face_server_return$reset_module)) {
      stamp_face_server_return$reset_module()
    }

    # Reset Stamp Verso module
    if (!is.null(stamp_verso_server_return) && !is.null(stamp_verso_server_return$reset_module)) {
      stamp_verso_server_return$reset_module()
    }

    # Reset all stamp-level reactive values
    app_rv$stamp_face_extraction_complete <- FALSE
    app_rv$stamp_verso_extraction_complete <- FALSE
    app_rv$stamp_face_image_uploaded <- FALSE
    app_rv$stamp_verso_image_uploaded <- FALSE
    app_rv$stamp_face_extracted_count <- 0
    app_rv$stamp_verso_extracted_count <- 0
    app_rv$stamp_face_extraction_dir <- NULL
    app_rv$stamp_verso_extraction_dir <- NULL
    app_rv$stamp_combined_paths <- NULL
    app_rv$stamp_lot_paths <- NULL
    app_rv$stamp_combined_file_paths <- NULL
    app_rv$stamp_num_rows <- NULL
    app_rv$stamp_num_cols <- NULL
    app_rv$stamp_last_face_upload_time <- NULL
    app_rv$stamp_last_verso_upload_time <- NULL
    app_rv$stamp_face_used_existing <- FALSE
    app_rv$stamp_verso_used_existing <- FALSE

    showNotification(
      "🟣 Ready for new stamp upload session. Upload Face and Verso stamp images to begin.",
      type = "message",
      duration = 5
    )
  })
}
