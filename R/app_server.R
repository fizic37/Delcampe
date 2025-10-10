#' The application server-side - FIXED with import_from_path
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
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
    
    # Grid configuration (shared between face/verso)
    num_rows = NULL,
    num_cols = NULL,
    
    # Upload tracking for state management
    last_face_upload_time = NULL,
    last_verso_upload_time = NULL
  )

  # Session directory for combined images
  session_temp_dir <- reactive({
    temp_dir <- tempfile("shiny_combined_images_")
    dir.create(temp_dir, showWarnings = FALSE, recursive = TRUE)
    temp_dir
  })

  # Resource prefix for combined images
  observe({
    resource_prefix_combined <- "combined_session_images"
    shiny::addResourcePath(prefix = resource_prefix_combined, directoryPath = session_temp_dir())
  })

  # Face processor module with callbacks
  cat("\n🔵 ABOUT TO CALL FACE MODULE\n")
  face_server_return <- tryCatch({
    mod_postal_card_processor_server(
      "face_processor",
      card_type = "face",
      on_extraction_complete = function(count, dir) {
        app_rv$face_extraction_complete <- TRUE
        app_rv$face_extracted_count <- count
        app_rv$face_extraction_dir <- dir
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
      }
    )
  }, error = function(e) {
    cat("❌ ERROR calling face module:", e$message, "\n")
    print(e)
    NULL
  })

  cat("🔵 FACE MODULE CALL COMPLETED\n\n")
  
  # Verso processor module with callbacks
  cat("\n🟢 ABOUT TO CALL VERSO MODULE\n")
  verso_server_return <- mod_postal_card_processor_server(
    "verso_processor", 
    card_type = "verso",
    on_extraction_complete = function(count, dir) {
      app_rv$verso_extraction_complete <- TRUE
      app_rv$verso_extracted_count <- count
      app_rv$verso_extraction_dir <- dir
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
    }
  )

  # Settings server - FIXED: Changed role to "admin" to show LLM Models tab
  mod_settings_server("settings", reactive(list(email = "admin@delcampe.com", role = "admin")))
  
  # Tracking viewer server
  mod_tracking_viewer_server("tracking_viewer_1")

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
    cat("\n" , rep("=", 80), "\n")
    cat("⚡ RENDER TRIGGERED FOR combined_image_output_display\n")
    cat(rep("=", 80), "\n\n")
    
    # Show "Start Over" button if any processing has been done
    show_reset_button <- app_rv$face_image_uploaded || app_rv$verso_image_uploaded
    
    # DEBUG: Log button visibility state
    cat("📑 State Variables:\n")
    cat("   face_image_uploaded:", app_rv$face_image_uploaded, "\n")
    cat("   verso_image_uploaded:", app_rv$verso_image_uploaded, "\n")
    cat("   show_reset_button:", show_reset_button, "\n")
    cat("   face_extraction_complete:", app_rv$face_extraction_complete, "\n")
    cat("   verso_extraction_complete:", app_rv$verso_extraction_complete, "\n")
    cat("   images_processed:", app_rv$images_processed, "\n\n")
    
    # State 1: Nothing uploaded yet OR images uploaded but not extracted
    if (!app_rv$face_extraction_complete || !app_rv$verso_extraction_complete) {
      cat("🔵 Rendering STATE 1: Not all extracted\n\n")
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
    # State 2: Both extractions complete, ready to combine
    else if (app_rv$face_extraction_complete && app_rv$verso_extraction_complete && !app_rv$images_processed) {
      cat("🟢 Rendering STATE 2: Ready to combine\n\n")
      bslib::card(
        header = bslib::card_header(
          "Ready to Combine Images",
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
            label = "Process Combined Images",
            icon = icon("wand-magic-sparkles"),
            class = "btn-lg btn-success",
            style = "background: linear-gradient(135deg, #52B788 0%, #40916C 100%); border: none; color: white; padding: 15px 40px; border-radius: 12px; font-weight: 700; font-size: 18px; box-shadow: 0 4px 15px rgba(82, 183, 136, 0.4); transition: all 0.3s ease; cursor: pointer;"
          )
        )
      )
    } 
    # State 3: Images processed - show success message with Start Over button
    else if (app_rv$images_processed) {
      cat("🟢 Rendering STATE 3: Processing complete\n\n")
      
      # SIMPLIFIED VERSION - Test if this renders at all
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
    cat("\n🔄 START OVER INITIATED\n")
    cat("   Timestamp:", format(Sys.time(), "%H:%M:%S"), "\n")
    
    # Reset Face module
    if (!is.null(face_server_return) && !is.null(face_server_return$reset_module)) {
      face_server_return$reset_module()
      cat("   ✅ Face module reset called\n")
    }
    
    # Reset Verso module  
    if (!is.null(verso_server_return) && !is.null(verso_server_return$reset_module)) {
      verso_server_return$reset_module()
      cat("   ✅ Verso module reset called\n")
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
    
    cat("   ✅ App state reset\n")
    
    showNotification(
      "🔄 Ready for new upload session. Upload Face and Verso images to begin.",
      type = "message",
      duration = 5
    )
    
    cat("   ✅ START OVER COMPLETE\n\n")
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
        
        # Create output directory for combined images
        combined_output_dir <- file.path(session_temp_dir(), "combined_images")
        dir.create(combined_output_dir, showWarnings = FALSE, recursive = TRUE)
        
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
          
          app_rv$images_processed <- TRUE
          
          # No success notification - user can see the export section appear
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
              width = 6,
              h5("📦 Postal Card Lots", style = "margin-bottom: 15px; color: #495057;"),
              p("Export complete lots (vertical stacks by column)", 
                style = "font-size: 13px; color: #666; margin-bottom: 15px;"),
              mod_delcampe_export_ui("lot_export")
            ),
            column(
              width = 6, 
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
    image_type = "lot"
  )
  
  mod_delcampe_export_server(
    "combined_export", 
    image_paths = reactive(app_rv$combined_paths),
    image_type = "combined"
  )
}
