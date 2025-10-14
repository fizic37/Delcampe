#' postal_cards_face UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd 
#'
#' @importFrom shiny NS tagList 
mod_postal_cards_face_ui <- function(id) {
  ns <- NS(id)
  tagList(
    shinyjs::useShinyjs(),
    bslib::page_fluid(
      # Controls row - all elements aligned horizontally
      fluidRow(
        column(
          width = 3,
          div(
            class = "custom-file-input",
            fileInput(
              inputId = ns("image_upload"),
              label = "Upload Face image",
              accept = "image/*"
            ),
            p("Upload the FACE side of your postal cards", style = "font-size: 12px; color: #666; margin-top: -10px;")
          )
        ),
        column(
          width = 2,
          div(
            id = ns("rows_control"),
            style = "display: none;",
            uiOutput(ns("num_rows_ui"))
          )
        ),
        column(
          width = 2,
          div(
            id = ns("cols_control"),
            style = "display: none;",
            uiOutput(ns("num_cols_ui"))
          )
        ),
        column(
          width = 3,
          div(
            id = ns("extract_control"),
            style = "display: none;",
            br(),
            actionButton(
              inputId = ns("extract_postcards"),
              label = "Extract Face Postal Cards",
              icon = icon("scissors"),
              class = "btn-success", # Changed from btn-primary
              style = "margin-top: 6px; background-color: #40916C; border-color: #40916C;" # Custom mint green
            )
          )
        )
      ),
      # Images row
      fluidRow(
        style = "margin-top: 20px;",
        # Uploaded face image panel
        column(
          width = 4,
          bslib::card(
            header = bslib::card_header("Uploaded face image"),
            uiOutput(ns("images_panel"))
          )
        ),
        # Extracted face images panel
        column(
          width = 8,
          bslib::card(
            header = bslib::card_header("Extracted face images"),
            uiOutput(ns("extracted_cards_display"))
          )
        )
      )
    )
  )
}

#' postal_cards_face Server Functions
#'
#' @noRd 
mod_postal_cards_face_server <- function(id, on_grid_update=NULL, on_image_upload=NULL, on_extraction_complete=NULL){
  moduleServer(id, function(input, output, session){
    ns <- session$ns
    `%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || all(is.na(a))) b else a
    
    # ---- Session directory for images ----
    session_temp_dir <- tempfile("shiny_session_images_")
    dir.create(session_temp_dir, showWarnings = FALSE, recursive = TRUE)
    # register a module-scoped session_images folder
    resource_prefix <- ns("session_images")
    shiny::addResourcePath(prefix = resource_prefix, directoryPath = session_temp_dir)
    python_output_subdir_name <- "py_extracted"
    
    # ---- Reactive state ----
    rv <- reactiveValues(
      # Recto
      image_path_original = NULL,
      image_url_display = NULL,
      image_dims_original = NULL,
      
      # Grid
      h_boundaries = numeric(0),
      v_boundaries = numeric(0),
      boundaries_manually_adjusted = FALSE,
      force_grid_redraw = 0,
      current_grid_rows = NULL,
      current_grid_cols = NULL,
      is_extracting = FALSE,
      extracted_paths_web = NULL,
      
      # Deduplication
      pending_existing_processing = NULL,
      pending_crop_validation = NULL
    )
    
    # ---- Python ----
    python_sourced <- FALSE
    try({
      reticulate::source_python("inst/python/extract_postcards.py")
      python_sourced <- TRUE
    }, silent = TRUE)
    
    # ---- UI: Display recto (and verso, if present) ----
    output$images_panel <- renderUI({
      if (is.null(rv$image_url_display)) {
        return(div(
          style = "width:100%; height:400px; display:flex; align-items:center; justify-content:center; color:#aaa; font-style:italic;",
          "Upload a recto image to start."
        ))
      }
      
      # Add indicator if showing reused configuration
      reused_indicator <- if (isTRUE(rv$show_reused_grid)) {
        # Check if boundaries are exact (non-evenly spaced) or approximate (evenly spaced)
        has_exact_boundaries <- !is.null(rv$h_boundaries) && !is.null(rv$v_boundaries) &&
                               length(rv$h_boundaries) > 2 && length(rv$v_boundaries) > 1
        
        # Check if boundaries are evenly spaced (approximate) or custom (exact)
        is_exact <- if (has_exact_boundaries) {
          # Calculate what evenly spaced boundaries would look like
          rows <- length(rv$h_boundaries) - 1
          cols <- length(rv$v_boundaries) - 1
          
          if (!is.null(rv$image_dims_original) && length(rv$image_dims_original) >= 2) {
            expected_h <- round(seq(0, rv$image_dims_original[2], length.out = rows + 1))
            expected_v <- round(seq(0, rv$image_dims_original[1], length.out = cols + 1))
            
            # If actual boundaries differ from evenly spaced, they're exact/custom
            h_diff <- !identical(as.numeric(rv$h_boundaries), as.numeric(expected_h))
            v_diff <- !identical(as.numeric(rv$v_boundaries), as.numeric(expected_v))
            
            h_diff || v_diff  # True if any boundaries are custom
          } else {
            TRUE  # Assume exact if we can't check
          }
        } else {
          FALSE
        }
        
        indicator_text <- if (is_exact) {
          paste(icon("check-circle"), "Showing exact gridlines from original processing")
        } else {
          paste(icon("info-circle"), "Showing approximate gridlines (evenly spaced)")
        }
        
        div(
          style = "background-color: #d1ecf1; color: #0c5460; padding: 8px; border-radius: 4px; margin-bottom: 8px; font-size: 12px;",
          indicator_text
        )
      } else {
        NULL
      }
      
      recto_panel <- tags$div(
        id = ns("grid_ui_wrapper"),
        `data-draggrid`  = "true", 
        style = "position:relative; width:100%; height:400px; overflow:visible; border:1px solid #eee; margin-bottom:8px;",
        uiOutput(ns("image_with_draggable_grid"))
      )
      
      if (!is.null(rv$image_url_display_verso)) {
        verso_panel <- tags$div(
          id = ns("grid_ui_wrapper"),
          style = "position:relative; width:100%; height:400px; overflow:visible; border:1px solid #eee; margin-bottom:8px;",
          uiOutput(ns("image_with_draggable_grid_verso"))
        )
        tagList(
          reused_indicator,
          fluidRow(
            column(6, recto_panel),
            column(6, verso_panel)
          )
        )
      } else {
        tagList(
          reused_indicator,
          recto_panel
        )
      }
    })
    
    # ---- Face image upload ----
    observeEvent(input$image_upload, {
      req(input$image_upload)
      file_info <- input$image_upload
      
      # Load tracking functions
      source("R/tracking_database.R")
      
      # Get user info (you may need to adjust this based on your auth system)
      user_id <- "current_user"  # TODO: Replace with actual user from your auth system
      
      # FIXED: Use safe session ID generation
      safe_session <- safe_session_id(session)
      
      cat("🔍 DEBUG: session$token =", deparse(session$token), "\n")
      cat("🔍 DEBUG: safe_session =", safe_session, "\n")
      
      # Use new content-based tracking system
      tracking_result <- save_uploaded_image(
        file_info = file_info,
        user_id = user_id,
        session_id = safe_session,
        content_category = "cards",
        image_type = "face"
      )
      
      # Check if tracking was successful
      if (!tracking_result$success) {
        showModal(modalDialog(
          title = "Upload Error",
          paste("Failed to upload image:", tracking_result$error),
          easyClose = TRUE,
          footer = modalButton("OK")
        ))
        return()
      }
      
      # Use the tracked image path instead of temp directory
      local_image_path <- tracking_result$full_path
      
      # Validate that the file exists and is accessible
      if (!file.exists(local_image_path)) {
        showModal(modalDialog(
          title = "Upload Error", 
          paste("Image file could not be found at:", local_image_path),
          easyClose = TRUE,
          footer = modalButton("OK")
        ))
        return()
      }
      
      # Reset relevant reactive values
      rv$image_path_original <- NULL
      rv$image_url_display <- NULL
      rv$image_dims_original <- NULL
      rv$h_boundaries <- numeric(0) # Will be repopulated
      rv$v_boundaries <- numeric(0) # Will be repopulated
      rv$extracted_paths_web <- NULL
      rv$current_grid_rows <- NULL # Will be repopulated
      rv$current_grid_cols <- NULL # Will be repopulated
      rv$boundaries_manually_adjusted <- FALSE
      rv$show_reused_grid <- FALSE
      
      rv$image_path_original <- local_image_path
      rv$image_url_display <- tracking_result$web_path # Use web path for display
      
      cat("✅ Face card uploaded and tracked!\n")
      cat("   📁 Saved to:", tracking_result$file_path, "\n")
      cat("   🆔 Image ID:", tracking_result$image_id, "\n")
      
      # Get original image dimensions with better error handling
      tryCatch({
        img_magick_obj <- magick::image_read(local_image_path)
        img_dims_orig_magick <- magick::image_info(img_magick_obj)[1, c("width", "height")]
        rv$image_dims_original <- as.numeric(c(img_dims_orig_magick$width, img_dims_orig_magick$height))
      }, error = function(e) {
        showModal(modalDialog(
          title = "Image Processing Error",
          paste("Could not read image dimensions:", e$message),
          easyClose = TRUE,
          footer = modalButton("OK")
        ))
        return()
      })
      
      default_rows <- 1
      default_cols <- 1
      
      # Attempt Python detection for initial grid lines (internal lines only)
      py_detected_h_internal <- numeric(0)
      py_detected_v_internal <- numeric(0)
      
      if (python_sourced && exists("detect_grid_layout")) {
        py_results <- tryCatch({
          detect_grid_layout(rv$image_path_original)
        }, error = function(e) {
          warning(paste("Python detect_grid_layout error:", e$message))
          NULL
        })
        
        if (!is.null(py_results)) {
          if (!is.null(py_results$h_boundaries) && length(py_results$h_boundaries) > 0) {
            py_h_temp <- as.numeric(unlist(py_results$h_boundaries))
            py_detected_h_internal <- sort(unique(round(py_h_temp[py_h_temp > 1e-6 & py_h_temp < (rv$image_dims_original[2] - 1e-6)])))
            if (length(py_detected_h_internal) > 0) default_rows <- length(py_detected_h_internal) + 1
          }
          if (!is.null(py_results$v_boundaries) && length(py_results$v_boundaries) > 0) {
            py_v_temp <- as.numeric(unlist(py_results$v_boundaries))
            py_detected_v_internal <- sort(unique(round(py_v_temp[py_v_temp > 1e-6 & py_v_temp < (rv$image_dims_original[1] - 1e-6)])))
            if (length(py_detected_v_internal) > 0) default_cols <- length(py_detected_v_internal) + 1
          }
        }
      }
      
      # Construct full boundary lists (0, internal_lines, max_dimension)
      rv$h_boundaries <- sort(unique(round(c(0, py_detected_h_internal, rv$image_dims_original[2]))))
      rv$h_boundaries <- rv$h_boundaries[rv$h_boundaries >= 0 & rv$h_boundaries <= rv$image_dims_original[2]]
      rv$h_boundaries <- unique(rv$h_boundaries)
      
      rv$v_boundaries <- sort(unique(round(c(0, py_detected_v_internal, rv$image_dims_original[1]))))
      rv$v_boundaries <- rv$v_boundaries[rv$v_boundaries >= 0 & rv$v_boundaries <= rv$image_dims_original[1]]
      rv$v_boundaries <- unique(rv$v_boundaries)
      
      # If Python detection failed to provide any internal lines, fall back to even spacing
      if (length(rv$h_boundaries) <= 2 && default_rows > 0) {
        num_initial_rows <- isolate(input$num_rows_input) %||% default_rows %||% 1
        rv$h_boundaries <- round(seq(0, rv$image_dims_original[2], length.out = max(1, num_initial_rows) + 1))
      }
      if (length(rv$v_boundaries) <= 2 && default_cols > 0) {
        num_initial_cols <- isolate(input$num_cols_input) %||% default_cols %||% 1
        rv$v_boundaries <- round(seq(0, rv$image_dims_original[1], length.out = max(1, num_initial_cols) + 1))
      }
      
      # Final check and update for current_grid_rows/cols
      rv$current_grid_rows <- max(0, length(rv$h_boundaries) - 1)
      rv$current_grid_cols <- max(0, length(rv$v_boundaries) - 1)
      
      # Update numeric inputs to reflect the actual grid state
      if (is.null(isolate(input$num_rows_input)) || isolate(input$num_rows_input) != rv$current_grid_rows) {
        updateNumericInput(session, "num_rows_input", value = rv$current_grid_rows)
      }
      if (is.null(isolate(input$num_cols_input)) || isolate(input$num_cols_input) != rv$current_grid_cols) {
        updateNumericInput(session, "num_cols_input", value = rv$current_grid_cols)
      }
      
      rv$force_grid_redraw <- rv$force_grid_redraw + 1
      output$processing_status <- renderUI({NULL})
      
      # Optional: Check for existing processing (deduplication)
      # This section can be safely commented out if you don't want deduplication
      tryCatch({
        file_size <- file.size(local_image_path)
        image_hash <- calculate_image_hash(local_image_path)
        
        # Check if this image has been processed before
        existing_processing <- find_existing_processing(image_hash, "face")
        
        if (!is.null(existing_processing)) {
          # Image has been processed before!
          crop_validation <- validate_existing_crops(existing_processing$cropped_images)
          
          if (length(crop_validation$existing_paths) > 0) {
            # Ask user if they want to reuse existing crops
            showModal(modalDialog(
              title = "Existing Processing Found",
              size = "l",
              fluidRow(
                column(
                  width = 6,
                  h5("Current Image"),
                  div(
                    style = "text-align: center; border: 2px solid #dee2e6; border-radius: 8px; padding: 10px;",
                    tags$img(
                      src = rv$image_url_display,
                      style = "max-width: 100%; max-height: 250px; object-fit: contain;"
                    )
                  )
                ),
                column(
                  width = 6,
                  h5("Found Existing Processing"),
                  div(
                    style = "padding: 15px; background-color: #f8f9fa; border-radius: 8px;",
                    p(paste("Grid:", existing_processing$grid_config$rows, "x", existing_processing$grid_config$cols)),
                    p(paste("Crops found:", length(crop_validation$existing_paths))),
                    p(paste("Originally processed:", format_timestamp(existing_processing$upload_time))),
                    if (length(crop_validation$missing_paths) > 0) {
                      div(
                        style = "color: #856404; background-color: #fff3cd; padding: 8px; border-radius: 4px; margin-top: 10px;",
                        paste("Note:", length(crop_validation$missing_paths), "crop files are missing and will be skipped")
                      )
                    }
                  )
                )
              ),
              footer = tagList(
                actionButton(
                  ns("reuse_existing"),
                  "Use Existing Crops",
                  class = "btn-success",
                  icon = icon("check")
                ),
                actionButton(
                  ns("process_new"),
                  "Process New",
                  class = "btn-warning",
                  icon = icon("cog")
                ),
                modalButton("Cancel")
              )
            ))
            
            # Store existing processing info for potential reuse
            rv$pending_existing_processing <- existing_processing
            rv$pending_crop_validation <- crop_validation
          }
        }
      }, error = function(e) {
        # Deduplication failed, but that's OK - just log it and continue
        warning("Deduplication check failed: ", e$message)
      })
      
      # Notify parent app about image upload
      if (!is.null(on_image_upload)) {
        on_image_upload()
      }
      
      # Show controls after image upload
      shinyjs::show("rows_control")
      shinyjs::show("cols_control")
      shinyjs::show("extract_control")
      
    }, ignoreNULL = TRUE, ignoreInit = TRUE) # ignoreNULL for input$image_upload
    
    # ---- Handle reuse existing crops ----
    observeEvent(input$reuse_existing, {
      req(rv$pending_existing_processing, rv$pending_crop_validation)
      
      removeModal()
      
      existing <- rv$pending_existing_processing
      validation <- rv$pending_crop_validation
      
      if (length(validation$existing_paths) > 0) {
        # Copy existing crops to current session directory
        py_out_dir <- file.path(session_temp_dir, python_output_subdir_name, paste0("reused_", as.integer(Sys.time())))
        dir.create(py_out_dir, showWarnings = FALSE, recursive = TRUE)
        
        # Copy the existing crop files
        copied_paths <- copy_existing_crops(validation$existing_paths, py_out_dir)
        
        if (length(copied_paths) > 0) {
          # Update grid configuration from existing processing
          if (!is.null(existing$grid_config)) {
            rv$current_grid_rows <- existing$grid_config$rows
            rv$current_grid_cols <- existing$grid_config$cols
            
            # Restore exact boundaries from existing processing if available
            if (!is.null(existing$h_boundaries) && !is.null(existing$v_boundaries)) {
              # Use the exact same boundaries that were used for original cropping
              # Ensure boundaries are numeric (JSON might load them as strings)
              rv$h_boundaries <- as.numeric(existing$h_boundaries)
              rv$v_boundaries <- as.numeric(existing$v_boundaries)
            } else {
              # Fallback to evenly spaced boundaries if exact boundaries not stored
              rv$h_boundaries <- round(seq(0, rv$image_dims_original[2], length.out = rv$current_grid_rows + 1))
              rv$v_boundaries <- round(seq(0, rv$image_dims_original[1], length.out = rv$current_grid_cols + 1))
            }
            
            # Update numeric inputs
            updateNumericInput(session, "num_rows_input", value = rv$current_grid_rows)
            updateNumericInput(session, "num_cols_input", value = rv$current_grid_cols)
            
            # Notify parent app about grid update
            if (!is.null(on_grid_update)) {
              on_grid_update(rv$current_grid_rows, rv$current_grid_cols)
            }
            
            # Mark that we're showing a reused configuration to enable grid display
            rv$show_reused_grid <- TRUE
            rv$force_grid_redraw <- rv$force_grid_redraw + 1
          }
          
          # Create web paths for display
          rv$extracted_paths_web <- create_web_paths(copied_paths, session_temp_dir, resource_prefix)
          
          # Track the reuse in tracking system
          track_extraction(
            session_id = session$token,
            image_type = "face",
            extraction_dir = py_out_dir,
            cropped_paths = copied_paths,
            grid_config = existing$grid_config,
            h_boundaries = existing$h_boundaries,
            v_boundaries = existing$v_boundaries
          )
          
          # Mark as reused processing
          mark_processing_reused(
            session_id = safe_session_id(session),
            image_type = "face",
            source_session_id = existing$session_id
          )
          
          # Notify parent app about extraction completion
          if (!is.null(on_extraction_complete)) {
            on_extraction_complete(length(rv$extracted_paths_web), py_out_dir)
          }
        }
      }
      
      # Clear pending data
      rv$pending_existing_processing <- NULL
      rv$pending_crop_validation <- NULL
      rv$show_reused_grid <- FALSE
    })
    
    # ---- Handle process new (ignore existing) ----
    observeEvent(input$process_new, {
      removeModal()
      
      # Clear pending data
      rv$pending_existing_processing <- NULL
      rv$pending_crop_validation <- NULL
    })
    
    
    
    
    # ---- Numeric grid config ----
    observeEvent({
      input$num_rows_input
      input$num_cols_input
    }, {
      # This observer should only run if an image is loaded and its dimensions are known.
      # It also should not run during the initial population of num_rows_input/num_cols_input
      # by the image upload observer, hence ignoreNULL = TRUE, ignoreInit = TRUE.
      req(rv$image_path_original, rv$image_dims_original,
          !is.null(input$num_rows_input), !is.null(input$num_cols_input))
      
      # Get the desired number of rows and columns, ensuring they are at least 1.
      # nr and nc represent the number of cells/cards, so num_boundaries = nr + 1.
      nr <- max(1, as.integer(input$num_rows_input %||% 1))
      nc <- max(1, as.integer(input$num_cols_input %||% 1))
      
      # Only proceed if the new number of rows/cols is different from the current grid state.
      # This prevents re-calculation if the inputs were updated programmatically to match rv state.
      # Or if the user just clicked away from the input without changing value.
      current_derived_rows <- if (length(rv$h_boundaries) > 1) length(rv$h_boundaries) - 1 else 0
      current_derived_cols <- if (length(rv$v_boundaries) > 1) length(rv$v_boundaries) - 1 else 0
      
      if (nr == current_derived_rows && nc == current_derived_cols && !rv$boundaries_manually_adjusted) {
        # If the number of rows/cols matches what's already derived from boundaries,
        # and boundaries haven't been manually adjusted since last number change,
        # then no need to reset to evenly spaced lines.
        # If boundaries WERE manually adjusted, then changing num_rows/cols should reset them.
        return()
      }
      
      # Re-calculate evenly spaced boundaries based on original image dimensions
      # length.out = nr + 1 because n rows means n+1 boundary lines.
      rv$h_boundaries <- round(seq(0, rv$image_dims_original[2], length.out = nr + 1))
      rv$v_boundaries <- round(seq(0, rv$image_dims_original[1], length.out = nc + 1))
      
      # Ensure uniqueness and correct range, though seq should handle this.
      rv$h_boundaries <- unique(rv$h_boundaries[rv$h_boundaries >= 0 & rv$h_boundaries <= rv$image_dims_original[2]])
      rv$v_boundaries <- unique(rv$v_boundaries[rv$v_boundaries >= 0 & rv$v_boundaries <= rv$image_dims_original[1]])
      
      # Update current grid rows/cols based on the new boundaries
      rv$current_grid_rows <- max(0, length(rv$h_boundaries) - 1)
      rv$current_grid_cols <- max(0, length(rv$v_boundaries) - 1)
      
      # If the actual number of rows/cols after rounding/uniqueness differs from input, update input.
      # This path is less likely with seq but good for robustness.
      if (rv$current_grid_rows != nr) {
        updateNumericInput(session, "num_rows_input", value = rv$current_grid_rows)
      }
      if (rv$current_grid_cols != nc) {
        updateNumericInput(session, "num_cols_input", value = rv$current_grid_cols)
      }
      
      rv$boundaries_manually_adjusted <- FALSE # Reset this flag as we've set to an even grid
      rv$force_grid_redraw <- rv$force_grid_redraw + 1
      
      if (!is.null(on_grid_update)) on_grid_update(rv$current_grid_rows, rv$current_grid_cols)
      
    }, ignoreNULL = TRUE, ignoreInit = TRUE) # Important to prevent premature firing
    # ---- Draggable line observers ----
    handle_drag_update <- function(axis_type, new_val_px, line_idx_js) {
      if (axis_type == "H") {
        boundaries <- rv$h_boundaries
        if (line_idx_js < 1 || line_idx_js > length(boundaries)) return()
        boundaries[line_idx_js] <- new_val_px
        rv$h_boundaries <- sort(unique(boundaries))
      } else {
        boundaries <- rv$v_boundaries
        if (line_idx_js < 1 || line_idx_js > length(boundaries)) return()
        boundaries[line_idx_js] <- new_val_px
        rv$v_boundaries <- sort(unique(boundaries))
      }
      rv$boundaries_manually_adjusted <- TRUE
      rv$force_grid_redraw <- rv$force_grid_redraw + 1
    }
    observeEvent(input$hline_moved_direct, {
      d <- input$hline_moved_direct
      # d$pos_px_wrapper = px from top of DISPLAY wrapper  
      # d$wrapper_dim      = height of DISPLAY wrapper in px  
      if (!is.null(d$pos_px_wrapper) && !is.null(d$wrapper_dim) && !is.null(d$id)) {
        # convert back to ORIGINAL image px:
        orig_y <- round(
          as.numeric(d$pos_px_wrapper) /
            as.numeric(d$wrapper_dim) *
            rv$image_dims_original[2]
        )
        handle_drag_update("H", orig_y, as.numeric(d$id))
      }
    })
    
    observeEvent(input$vline_moved_direct, {
      d <- input$vline_moved_direct
      # d$pos_px_wrapper = px from left of DISPLAY wrapper  
      # d$wrapper_dim      = width of DISPLAY wrapper in px  
      if (!is.null(d$pos_px_wrapper) && !is.null(d$wrapper_dim) && !is.null(d$id)) {
        orig_x <- round(
          as.numeric(d$pos_px_wrapper) /
            as.numeric(d$wrapper_dim) *
            rv$image_dims_original[1]
        )
        handle_drag_update("V", orig_x, as.numeric(d$id))
      }
    })
    
    
    
    # ---- Draggable grid image renderers (recto only) ----
    output$image_with_draggable_grid <- renderUI({
      # Essential reactive dependencies
      req(rv$image_url_display, rv$image_dims_original)
      
      # Trigger re-render when force_grid_redraw changes
      force_redraw_trigger <- rv$force_grid_redraw 
      
      # Local copies of boundaries for rendering this snapshot
      # These should already be sorted, unique, and include 0 and max_dim in original pixel units.
      # Ensure there are at least two boundaries (0 and max_dim) to define a space.
      req(length(rv$h_boundaries) >= 2, length(rv$v_boundaries) >= 2)
      
      # Use the boundaries directly from rv (they are now managed to be complete)
      h_boundaries_px <- rv$h_boundaries 
      v_boundaries_px <- rv$v_boundaries
      
      # Debug print to check boundaries just before rendering lines
      # print("Rendering grid with H-boundaries (px):")
      # print(h_boundaries_px)
      # print("Rendering grid with V-boundaries (px):")
      # print(v_boundaries_px)
      # print(paste("Original Dims (W,H):", rv$image_dims_original[1], rv$image_dims_original[2]))
      
      # Create horizontal line divs
      # The index `i` will be used for data-line-index and must be 1-based.
      h_lines <- lapply(seq_along(h_boundaries_px), function(i) {
        # Don't allow dragging the first (0%) or last (100%) line by omitting pointer-events
        # or by not making them 'draggable-line' if JS specifically targets that.
        # However, JS is already set up to handle this.
        # The line itself should always be rendered for visual consistency.
        
        # Calculate percentage position. Avoid division by zero if dim is 0 (should not happen with req).
        # Ensure dimensions are numeric
        img_height <- as.numeric(rv$image_dims_original[2])
        boundary_pos <- as.numeric(h_boundaries_px[i])
        
        top_percent <- if (!is.na(img_height) && img_height > 0) {
          (boundary_pos / img_height) * 100
        } else {
          0 # Should not happen if image_dims_original[2] is valid
        }
        
        tags$div(
          id = ns(paste0("hline_", i)), # Unique ID for the line
          class = "draggable-line horizontal-line",
          `data-line-index` = i, # 1-based index for JS to identify the line
          style = sprintf("top: %.4f%%;", top_percent)
          # Other styles like height, background-color are in CSS or JS init
        )
      })
      
      # Create vertical line divs
      v_lines <- lapply(seq_along(v_boundaries_px), function(i) {
        # Ensure dimensions are numeric
        img_width <- as.numeric(rv$image_dims_original[1])
        boundary_pos <- as.numeric(v_boundaries_px[i])
        
        left_percent <- if (!is.na(img_width) && img_width > 0) {
          (boundary_pos / img_width) * 100
        } else {
          0 # Should not happen
        }
        
        tags$div(
          id = ns(paste0("vline_", i)),
          class = "draggable-line vertical-line",
          `data-line-index` = i,
          style = sprintf("left: %.4f%%;", left_percent)
        )
      })
      
      # Image source with a cache-busting query parameter
      img_src_with_nonce <- paste0("/", rv$image_url_display, "?v=", timestamp_nonce())
      
      tags$div(
        # This outer div is the one JS `initDraggableGrid` targets.
        # It's already in output$images_panel with id = ns("grid_ui_wrapper")
        # So this div is *inside* that.
        style = "position:relative; width:100%; height:100%; overflow:visible;", # Keep this for internal layout
        tags$img(
          id = ns("preview_image"), # ID for the image itself
          src = img_src_with_nonce,
          style = paste(
            "display:block; position:absolute; top:0; left:0;",
            "width:100%; height:100%; object-fit:contain;",
            "pointer-events:none; z-index:5;" # Image below lines
          ),
          `data-original-width` = rv$image_dims_original[1],
          `data-original-height` = rv$image_dims_original[2]
        ),
        h_lines, 
        v_lines,
        # The initDraggableGrid script is now more crucial here to ensure it runs
        # every time this UI re-renders, especially if the wrapper is static
        # and only its contents (this UI output) change.
        tags$script(HTML(
          sprintf(
            "if (typeof initDraggableGrid === 'function') { initDraggableGrid(document.getElementById('%s')); } else { console.error('initDraggableGrid not defined when trying to re-init grid for %s'); }",
            session$ns("grid_ui_wrapper"), # Target the main wrapper
            session$ns("grid_ui_wrapper")
          )
        ))
      )
    })
    
    # Helper for cache-busting nonce for image
    timestamp_nonce <- reactive({
      gsub("[^0-9]", "", as.character(as.numeric(Sys.time()) * 1000))
    })
    
    output$image_with_draggable_grid_verso <- renderUI({
      req(rv$image_url_display_verso, rv$image_dims_verso)
      img_src <- paste0(rv$image_url_display_verso, "?v=", as.numeric(Sys.time()))
      tags$img(
        src = img_src,
        style = "display:block; width:100%; height:100%; object-fit:contain; border:1px solid #ccc;"
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
    observeEvent(input$extract_postcards, {
      req(rv$image_path_original, length(rv$h_boundaries) > 1, length(rv$v_boundaries) > 1, python_sourced)
      py_out_dir <- file.path(session_temp_dir, python_output_subdir_name, paste0("extract_", as.integer(Sys.time())))
      dir.create(py_out_dir, showWarnings = FALSE, recursive = TRUE)
      rv$extracted_paths_web <- NULL
      
      py_results <- crop_image_with_boundaries(
        image_path = rv$image_path_original,
        h_boundaries = as.list(as.integer(round(rv$h_boundaries))),
        v_boundaries = as.list(as.integer(round(rv$v_boundaries))),
        output_dir = py_out_dir
      )
      
      if (!is.null(py_results$extracted_paths) && length(unlist(py_results$extracted_paths)) > 0) {
        abs_paths <- normalizePath(unlist(py_results$extracted_paths))
        abs_sess_dir <- normalizePath(session_temp_dir)
        rel_paths <- gsub(paste0("^", gsub("\\\\", "\\\\\\\\", abs_sess_dir), "[/\\\\]*"), "", abs_paths)
        rel_paths <- sub("^[/\\\\]+", "", rel_paths)
        rv$extracted_paths_web <- file.path(resource_prefix, rel_paths)
        
        # Track extraction completion
        track_extraction(
          session_id = safe_session_id(session),
          image_type = "face",
          extraction_dir = py_out_dir,
          cropped_paths = unlist(py_results$extracted_paths),
          grid_config = list(rows = rv$current_grid_rows, cols = rv$current_grid_cols),
          h_boundaries = rv$h_boundaries,
          v_boundaries = rv$v_boundaries
        )
        
        # Notify parent app about extraction completion
        if (!is.null(on_extraction_complete)) {
          on_extraction_complete(length(rv$extracted_paths_web), py_out_dir)
        }
        
        # No status message - extraction complete silently
      } else {
        output$processing_status <- renderUI(tags$p("Extraction failed or no cards found.", style = "color:red;"))
      }
    })
    
    
    
    
    # ---- Display extracted cards ----
    output$extracted_cards_display <- renderUI({
      paths <- rv$extracted_paths_web
      if (is.null(paths) || length(paths) == 0) {
        return(p("No cards extracted yet or extraction failed.", style = "text-align:center; color:#aaa;"))
      }
      
      # Get current grid dimensions
      num_rows <- rv$current_grid_rows %||% 1
      num_cols <- rv$current_grid_cols %||% 1
      
      # Create grid layout based on extraction dimensions
      grid_rows <- list()
      
      for (row in 1:num_rows) {
        row_images <- list()
        
        for (col in 1:num_cols) {
          # Calculate index in the paths array (row-major order)
          index <- (row - 1) * num_cols + col
          
          if (index <= length(paths)) {
            row_images[[col]] <- column(
              width = floor(12 / num_cols),
              div(
                style = "text-align: center; margin-bottom: 10px;",
                div(
                  style = "background-color: #f8f9fa; border: 1px solid #dee2e6; border-radius: 5px; padding: 5px;",
                  p(paste("R", row, "C", col), style = "margin: 0; font-size: 12px; color: #6c757d;"),
                  tags$img(
                    src = paths[index], 
                    style = "max-width: 100%; max-height: 120px; object-fit: contain; border-radius: 3px;"
                  )
                )
              )
            )
          } else {
            # Empty cell if not enough images
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
        
        grid_rows[[row]] <- fluidRow(
          style = "margin-bottom: 5px;",
          row_images
        )
      }
      
      div(
        style = "border: 1px solid #dee2e6; border-radius: 5px; padding: 10px; background-color: white;",
        h6(paste("Grid Layout:", num_rows, "x", num_cols), style = "margin-bottom: 15px; color: #495057; text-align: center;"),
        grid_rows
      )
    })
    
    
  })
}

## To be copied in the UI
# mod_postal_cards_face_ui("postal_cards_face_1")

## To be copied in the server
# mod_postal_cards_face_server("postal_cards_face_1")
