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
    cat("✅ Python already imported\n\n")
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
    }
  )

  # Settings server
  mod_settings_server("settings", reactive(list(email = "user@example.com", role = "user")))
  
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

  # FIXED: Compact combined image output display
  output$combined_image_output_display <- renderUI({
    # Only show if at least one image is uploaded and processed
    if (app_rv$face_extraction_complete || app_rv$verso_extraction_complete) {
      
      # Check if both extractions are complete and ready for combination
      if (app_rv$face_extraction_complete && app_rv$verso_extraction_complete) {
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
              icon = icon("magic"),
              class = "btn-success",
              style = "background-color: #52B788; border-color: #52B788; color: white; padding: 10px 30px; border-radius: 6px; font-weight: 600;"
            )
          )
        )
      } else if (app_rv$images_processed) {
        # Show combined images when processing is complete
        bslib::card(
          header = bslib::card_header(
            "Combined Images Output",
            style = "background-color: #52B788; color: white;"
          ),
          class = "combined-output-card",
          div(
            class = "combined-images-grid",
            # Display combined images here
            if (!is.null(app_rv$combined_image_paths)) {
              lapply(seq_along(app_rv$combined_image_paths), function(i) {
                div(
                  class = "combined-image-item",
                  p(paste("Combined", i), style = "margin: 5px 0; font-size: 12px; color: #6c757d;"),
                  tags$img(
                    src = app_rv$combined_image_paths[i],
                    style = "max-width: 100%; max-height: 150px; object-fit: contain;"
                  )
                )
              })
            } else {
              p("No combined images available", style = "text-align: center; color: #aaa;")
            }
          )
        )
      } else {
        # Compact processing status
        bslib::card(
          header = bslib::card_header(
            "Processing Status",
            style = "background-color: #E76F51; color: white;"
          ),
          class = "combined-output-card compact-status-card",
          div(
            style = "padding: 12px 20px; display: flex; align-items: center; justify-content: space-between; gap: 15px;",
            div(
              style = "font-weight: 600; color: #E76F51;",
              "🔄 Extraction in Progress"
            ),
            div(
              style = "display: flex; gap: 10px; flex-wrap: wrap;",
              div(
                style = paste0("padding: 6px 16px; border-radius: 15px; font-size: 13px; font-weight: 600; white-space: nowrap; ",
                              if(app_rv$face_extraction_complete) "background-color: #d4edda; color: #155724;" else "background-color: #fff3cd; color: #856404;"),
                if(app_rv$face_extraction_complete) 
                  paste("✓ Face (", app_rv$face_extracted_count, ")")
                else "○ Face Pending"
              ),
              div(
                style = paste0("padding: 6px 16px; border-radius: 15px; font-size: 13px; font-weight: 600; white-space: nowrap; ",
                              if(app_rv$verso_extraction_complete) "background-color: #d4edda; color: #155724;" else "background-color: #fff3cd; color: #856404;"),
                if(app_rv$verso_extraction_complete) 
                  paste("✓ Verso (", app_rv$verso_extracted_count, ")")
                else "○ Verso Pending"
              )
            )
          )
        )
      }
    } else {
      # Compact upload status
      bslib::card(
        header = bslib::card_header(
          "Upload Status",
          style = "background-color: #6c757d; color: white;"
        ),
        class = "combined-output-card compact-status-card",
        div(
          style = "padding: 12px 20px; display: flex; align-items: center; justify-content: space-between; gap: 15px;",
          div(
            style = "font-weight: 600; color: #6c757d;",
            "📸 Upload Face and Verso images"
          ),
          div(
            style = "display: flex; gap: 10px;",
            div(
              style = paste0("padding: 6px 16px; border-radius: 15px; font-size: 13px; font-weight: 600; ",
                            if(app_rv$face_image_uploaded) "background-color: #d4edda; color: #155724;" else "background-color: #f8d7da; color: #721c24;"),
              if(app_rv$face_image_uploaded) "✓ Face" else "○ Face Needed"
            ),
            div(
              style = paste0("padding: 6px 16px; border-radius: 15px; font-size: 13px; font-weight: 600; ",
                            if(app_rv$verso_image_uploaded) "background-color: #d4edda; color: #155724;" else "background-color: #f8d7da; color: #721c24;"),
              if(app_rv$verso_image_uploaded) "✓ Verso" else "○ Verso Needed"
            )
          )
        )
      )
    }
  })

  # Combined results section UI (dynamic)
  output$combined_results_section <- renderUI({
    if (app_rv$images_processed) {
      bslib::card(
        header = bslib::card_header(
          "Export Options ✓",
          style = "background-color: #28a745; color: white;"
        ),
        div(
          style = "padding: 20px;",
          fluidRow(
            column(
              width = 6,
              h5("Postal Card Lots"),
              mod_delcampe_export_ui("lot_export")
            ),
            column(
              width = 6, 
              h5("Individual Combined Images"),
              mod_delcampe_export_ui("combined_export")
            )
          )
        )
      )
    }
  })

  # Process combined images
  observeEvent(input$process_combined, {
    if (app_rv$face_extraction_complete && app_rv$verso_extraction_complete) {
      
      tryCatch({
        # TODO: Add your Python processing logic here
        # This is where you'd call your Python functions to combine face and verso images
        
        # For now, simulate successful processing
        app_rv$images_processed <- TRUE
        
        # TODO: You would populate these with actual paths from Python processing
        app_rv$lot_paths <- c("path1.jpg", "path2.jpg")  # Replace with actual paths
        app_rv$combined_paths <- c("combined1.jpg", "combined2.jpg")  # Replace with actual paths
        
        # Create web paths for combined images display
        app_rv$combined_image_paths <- paste0("combined_session_images/", basename(app_rv$combined_paths))
        
        showNotification("Images processed successfully!", type = "success")
        
      }, error = function(e) {
        showNotification(paste("Processing failed:", e$message), type = "error")
      })
    }
  })

  # FIXED: Export modules - removed the export_type parameter that was causing the error
  observe({
    if (app_rv$images_processed) {
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
  })
}
