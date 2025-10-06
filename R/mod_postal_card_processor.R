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
          width = 4,
          bslib::card(
            header = bslib::card_header(paste("Uploaded", card_type, "image")),
            uiOutput(ns("images_panel"))
          )
        ),
        column(
          width = 8,
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
  cat("\n🚀 INITIALIZING MODULE:", id, "(", card_type, ")\n")
  cat("⏳ About to call moduleServer...\n")
  
  result <- moduleServer(id, function(input, output, session) {
    cat("✅ moduleServer INNER FUNCTION EXECUTING for", id, "\n")
    
    # ===== DIAGNOSTIC BLOCK =====
    cat("\n", rep("#", 80), "\n")
    cat("### MODULE INITIALIZED: ", id, " (", card_type, ")\n")
    cat("### Timestamp: ", format(Sys.time(), "%H:%M:%OS3"), "\n")
    cat("### Namespace: ", session$ns(""), "\n")
    cat(rep("#", 80), "\n\n")
    # ===== END DIAGNOSTIC BLOCK =====
    
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
      is_extracting = FALSE  # Track extraction state to prevent unwanted observer triggers
    )
    
    # ---- Python setup ----
    # Check if Python is already loaded globally
    python_sourced <- exists(".postal_card_python_loaded", envir = .GlobalEnv) &&
                      isTRUE(get(".postal_card_python_loaded", envir = .GlobalEnv)) &&
                      exists("detect_grid_layout", envir = .GlobalEnv) &&
                      exists("crop_image_with_boundaries", envir = .GlobalEnv)

    if (python_sourced) {
      cat("✅ [", card_type, "] Using globally loaded Python module\n")
    } else {
      cat("⚠️ [", card_type, "] Python not available - will use fallback methods\n")
      cat("   .postal_card_python_loaded:", exists(".postal_card_python_loaded", envir = .GlobalEnv), "\n")
      if (exists(".postal_card_python_loaded", envir = .GlobalEnv)) {
        cat("   Value:", get(".postal_card_python_loaded", envir = .GlobalEnv), "\n")
      }
      cat("   detect_grid_layout in .GlobalEnv:", exists("detect_grid_layout", envir = .GlobalEnv), "\n")
      cat("   crop_image_with_boundaries in .GlobalEnv:", exists("crop_image_with_boundaries", envir = .GlobalEnv), "\n")
      python_sourced <- FALSE
    }
    
    # ---- Image upload handling ----
    observeEvent(input$image_upload, {
      cat("\n🔥🔥🔥 UPLOAD OBSERVER TRIGGERED [", toupper(card_type), "] 🔥🔥🔥\n")
      
      # CRITICAL: Skip if extraction is in progress to prevent cascade
      if (isTRUE(rv$is_extracting)) {
        cat("\n⚠️⚠️⚠️ SKIPPING upload observer [", toupper(card_type), "] - extraction in progress ⚠️⚠️⚠️\n")
        return()
      }

      file_info <- input$image_upload

      cat("\n🎯 IMAGE UPLOAD [", toupper(card_type), "] MODULE:\n")
      cat("   Module ID:", id, "\n")
      cat("   Namespace prefix:", session$ns(""), "\n")
      cat("   Timestamp:", Sys.time(), "\n")
      cat("   is_extracting flag:", rv$is_extracting, "\n")

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
      
      # Save uploaded file
      timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
      safe_filename <- paste0("uploaded_", card_type, "_", timestamp, ".jpg")
      upload_path <- file.path(session_temp_dir, safe_filename)
      file.copy(file_info$datapath, upload_path)
      rv$image_path_original <- upload_path
      
      # Create web URL
      norm_session_dir <- normalizePath(session_temp_dir, winslash = "/")
      norm_upload_path <- normalizePath(upload_path, winslash = "/")
      rel_path <- sub(paste0("^", gsub("/", "\\\\/", norm_session_dir), "/*"), "", norm_upload_path)
      rel_path <- sub("^/*", "", rel_path)
      # CRITICAL FIX: Use paste with forward slash for web URLs, not file.path
      rv$image_url_display <- paste(resource_prefix, rel_path, sep = "/")
      
      cat("   📁 Session temp dir:", session_temp_dir, "\n")
      cat("   📄 Upload path:", upload_path, "\n")
      cat("   🔗 Resource prefix:", resource_prefix, "\n")
      cat("   📍 Relative path:", rel_path, "\n")
      cat("   🌐 Final URL:", rv$image_url_display, "\n")
      
      # Get image dimensions and detect grid
      cat("   🐍 Python sourced:", python_sourced, "\n")
      cat("   🔍 detect_grid_layout exists:", exists("detect_grid_layout"), "\n")
      
      if (python_sourced && exists("detect_grid_layout")) {
        cat("   📞 CALLING detect_grid_layout() from upload observer\n")
        cat("   📂 Image path:", rv$image_path_original, "\n")
        cat("   📊 File exists:", file.exists(rv$image_path_original), "\n")
        cat("   📏 File size:", file.size(rv$image_path_original), "bytes\n")
        
        py_results <- tryCatch({
          result <- detect_grid_layout(rv$image_path_original)
          cat("   ✅ Python call successful\n")
          cat("   📐 Result structure:", names(result), "\n")
          result
        }, error = function(e) {
          cat("   ❌ Python detection error:", e$message, "\n")
          cat("   Stack trace:", paste(capture.output(traceback()), collapse="\n"), "\n")
          NULL
        })
        
        cat("   🔬 py_results is NULL:", is.null(py_results), "\n")
        
        if (!is.null(py_results)) {
          cat("   ✅ Processing Python results...\n")
          rv$image_dims_original <- c(py_results$image_width, py_results$image_height)
          cat("   📏 Image dimensions set:", rv$image_dims_original, "\n")
          
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
          
          cat("   Grid:", rv$current_grid_rows, "x", rv$current_grid_cols, "\n")
          cat("   H boundaries:", paste(rv$h_boundaries, collapse = ", "), "\n")
          cat("   V boundaries:", paste(rv$v_boundaries, collapse = ", "), "\n")
          
          # Update numeric inputs
          updateNumericInput(session, "num_rows_input", value = rv$current_grid_rows)
          updateNumericInput(session, "num_cols_input", value = rv$current_grid_cols)
          
          rv$force_grid_redraw <- rv$force_grid_redraw + 1
        } else {
          cat("   ⚠️ Python detection returned NULL - using fallback\n")
        }
      } else {
        cat("   ⚠️ Python not available - using fallback\n")
      }
      
      # FALLBACK: If Python detection failed or unavailable, use image library to get dims
      if (is.null(rv$image_dims_original)) {
        cat("   🔧 Using fallback method to get image dimensions...\n")
        
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
          cat("   ❌ Fallback image read error:", e$message, "\n")
          NULL
        })
        
        if (!is.null(dims_result)) {
          rv$image_dims_original <- dims_result
          cat("   ✅ Got dimensions from fallback:", rv$image_dims_original, "\n")
          
          # Set default 1x1 grid
          rv$h_boundaries <- c(0, rv$image_dims_original[2])
          rv$v_boundaries <- c(0, rv$image_dims_original[1])
          rv$current_grid_rows <- 1
          rv$current_grid_cols <- 1
          
          updateNumericInput(session, "num_rows_input", value = 1)
          updateNumericInput(session, "num_cols_input", value = 1)
          
          rv$force_grid_redraw <- rv$force_grid_redraw + 1
          
          cat("   🎯 Default 1x1 grid set\n")
        } else {
          cat("   ❌ Could not determine image dimensions!\n")
          cat("   Please install 'magick' package: install.packages('magick')\n")
          showNotification(
            "Could not read image dimensions. Please install the 'magick' package.",
            type = "error",
            duration = 10
          )
        }
      }
      
      # Show controls
      shinyjs::show("rows_control")
      shinyjs::show("cols_control")
      shinyjs::show("extract_control")
      
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
    
    # ---- Draggable line handlers (FIXED) ----
    observeEvent(input$hline_moved_direct, {
      req(input$hline_moved_direct)
      d <- input$hline_moved_direct
      
      cat("🔴 H-line moved [", toupper(card_type), "] MODULE:\n")
      cat("   ID:", d$id, "| Pos:", d$pos_px_wrapper, "| Wrapper H:", d$wrapper_dim, "\n")
      
      if (!is.null(d$pos_px_wrapper) && !is.null(d$wrapper_dim) && !is.null(d$id)) {
        # Convert to original image coordinates
        scale_factor <- as.numeric(rv$image_dims_original[2]) / as.numeric(d$wrapper_dim)
        orig_y <- round(as.numeric(d$pos_px_wrapper) * scale_factor)
        line_index <- as.numeric(d$id)
        
        if (line_index > 0 && line_index <= length(rv$h_boundaries)) {
          rv$h_boundaries[line_index] <- orig_y
          rv$boundaries_manually_adjusted <- TRUE
          rv$force_grid_redraw <- rv$force_grid_redraw + 1
          cat("   ✅ Updated to", orig_y, "px\n")
        }
      }
    })
    
    observeEvent(input$vline_moved_direct, {
      req(input$vline_moved_direct)
      d <- input$vline_moved_direct
      
      cat("🔵 V-line moved [", toupper(card_type), "] MODULE:\n")
      cat("   ID:", d$id, "| Pos:", d$pos_px_wrapper, "| Wrapper W:", d$wrapper_dim, "\n")
      
      if (!is.null(d$pos_px_wrapper) && !is.null(d$wrapper_dim) && !is.null(d$id)) {
        # Convert to original image coordinates
        scale_factor <- as.numeric(rv$image_dims_original[1]) / as.numeric(d$wrapper_dim)
        orig_x <- round(as.numeric(d$pos_px_wrapper) * scale_factor)
        line_index <- as.numeric(d$id)
        
        if (line_index > 0 && line_index <= length(rv$v_boundaries)) {
          rv$v_boundaries[line_index] <- orig_x
          rv$boundaries_manually_adjusted <- TRUE
          rv$force_grid_redraw <- rv$force_grid_redraw + 1
          cat("   ✅ Updated to", orig_x, "px\n")
        }
      }
    })
    
    # ---- UI Rendering ----
    output$images_panel <- renderUI({
      cat("\n🎨 RENDERING images_panel for", toupper(card_type), "\n")
      cat("   image_url_display:", rv$image_url_display, "\n")
      cat("   is.null(rv$image_url_display):", is.null(rv$image_url_display), "\n")
      
      if (is.null(rv$image_url_display)) {
        cat("   ⚠️ Showing placeholder message\n")
        return(div(
          style = "width:100%; height:400px; display:flex; align-items:center; justify-content:center; color:#aaa; font-style:italic;",
          paste("Upload a", card_type, "image to start.")
        ))
      }
      
      cat("   ✅ Creating grid wrapper\n")
      cat("   Grid wrapper ID:", ns("grid_ui_wrapper"), "\n")
      
      tags$div(
        id = ns("grid_ui_wrapper"),
        `data-draggrid` = "true", 
        style = "position:relative; width:100%; height:400px; overflow:visible; border:1px solid #eee; margin-bottom:8px; background-color: #f5f5f5;",
        uiOutput(ns("image_with_draggable_grid"))
      )
    })
    
    output$image_with_draggable_grid <- renderUI({
      cat("\n🖼️ RENDERING image_with_draggable_grid for", toupper(card_type), "\n")
      cat("   Checking requirements...\n")
      cat("   rv$image_url_display:", rv$image_url_display, "\n")
      cat("   rv$image_dims_original:", rv$image_dims_original, "\n")
      cat("   length(rv$h_boundaries):", length(rv$h_boundaries), "\n")
      cat("   length(rv$v_boundaries):", length(rv$v_boundaries), "\n")
      
      req(rv$image_url_display, rv$image_dims_original, length(rv$h_boundaries) >= 2, length(rv$v_boundaries) >= 2)
      
      cat("   ✅ All requirements met!\n")
      
      force_redraw_trigger <- rv$force_grid_redraw  # Trigger reactivity
      cat("   force_redraw_trigger:", force_redraw_trigger, "\n")
      
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
      
      cat("   📸 Image source:", img_src_with_nonce, "\n")
      cat("   📏 Image dimensions:", rv$image_dims_original[1], "x", rv$image_dims_original[2], "\n")
      cat("   🔴 H boundaries:", paste(h_boundaries_px, collapse=", "), "\n")
      cat("   🔵 V boundaries:", paste(v_boundaries_px, collapse=", "), "\n")
      cat("   Creating", length(h_boundaries_px), "horizontal and", length(v_boundaries_px), "vertical lines\n")
      
      tags$div(
        style = "position:relative; width:100%; height:100%; overflow:visible;",
        tags$img(
          id = ns("preview_image"),
          src = img_src_with_nonce,
          style = "display:block; position:absolute; top:0; left:0; width:100%; height:100%; object-fit:contain; pointer-events:none; z-index:5;",
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

      # Set extraction flag to prevent any reactive cascade from triggering detection
      rv$is_extracting <- TRUE
      on.exit(rv$is_extracting <- FALSE)  # Always reset flag when done

      py_out_dir <- file.path(session_temp_dir, python_output_subdir_name, paste0("extract_", as.integer(Sys.time())))
      dir.create(py_out_dir, showWarnings = FALSE, recursive = TRUE)
      rv$extracted_paths_web <- NULL

      cat("\n🚀 EXTRACTION STARTED [", toupper(card_type), "] MODULE:\n")
      cat("   Module ID:", id, "\n")
      cat("   Timestamp:", Sys.time(), "\n")
      cat("   Image path:", rv$image_path_original, "\n")
      cat("   H boundaries:", paste(rv$h_boundaries, collapse = ", "), "\n")
      cat("   V boundaries:", paste(rv$v_boundaries, collapse = ", "), "\n")
      cat("   ⚠️ CALLING crop_image_with_boundaries ONLY (NOT detect_grid_layout)\n")
      
      # CRITICAL DEBUG: Verify the function exists and show what we're calling
      cat("   🔍 Checking function availability:\n")
      cat("      crop_image_with_boundaries exists:", exists("crop_image_with_boundaries", envir = .GlobalEnv), "\n")
      if (exists("crop_image_with_boundaries", envir = .GlobalEnv)) {
        func <- get("crop_image_with_boundaries", envir = .GlobalEnv)
        cat("      Function type:", typeof(func), "\n")
        cat("      Is function:", is.function(func), "\n")
      }
      
      # Convert boundaries to the exact format Python expects
      h_bounds_list <- as.list(as.integer(round(rv$h_boundaries)))
      v_bounds_list <- as.list(as.integer(round(rv$v_boundaries)))
      
      cat("   📦 Prepared arguments for Python:\n")
      cat("      image_path:", rv$image_path_original, "\n")
      cat("      h_boundaries (list):", paste(unlist(h_bounds_list), collapse=", "), "\n")
      cat("      v_boundaries (list):", paste(unlist(v_bounds_list), collapse=", "), "\n")
      cat("      output_dir:", py_out_dir, "\n")
      cat("\n   🐍 CALLING Python function NOW...\n\n")

      py_results <- tryCatch({
        crop_image_with_boundaries(
          image_path = rv$image_path_original,
          h_boundaries = as.list(as.integer(round(rv$h_boundaries))),
          v_boundaries = as.list(as.integer(round(rv$v_boundaries))),
          output_dir = py_out_dir
        )
      }, error = function(e) {
        cat("❌ Python error:", e$message, "\n")
        showNotification(paste("Extraction error:", e$message), type = "error", duration = 5)
        NULL
      })
      
      if (!is.null(py_results) && !is.null(py_results$extracted_paths) && length(unlist(py_results$extracted_paths)) > 0) {
        abs_paths <- normalizePath(unlist(py_results$extracted_paths), winslash = "/")
        abs_sess_dir <- normalizePath(session_temp_dir, winslash = "/")
        rel_paths <- sub(paste0("^", gsub("/", "\\\\/", abs_sess_dir), "/*"), "", abs_paths)
        rel_paths <- sub("^/*", "", rel_paths)
        # CRITICAL FIX: Use paste with forward slash for web URLs, not file.path
        rv$extracted_paths_web <- paste(resource_prefix, rel_paths, sep = "/")

        cat("✅ EXTRACTION COMPLETED [", toupper(card_type), "] MODULE:\n")
        cat("   Extracted", length(rv$extracted_paths_web), "images\n")
        cat("   Module ID:", id, "\n")
        cat("   Timestamp:", Sys.time(), "\n\n")
        
        if (!is.null(on_extraction_complete)) {
          on_extraction_complete(length(rv$extracted_paths_web), py_out_dir)
        }
        
        showNotification(
          paste("Extracted", length(rv$extracted_paths_web), card_type, "cards"),
          type = "message",
          duration = 3
        )
      } else {
        cat("❌ Extraction failed\n")
        showNotification("Extraction failed. Check console.", type = "error", duration = 5)
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
      get_extracted_count = reactive(length(rv$extracted_paths_web %||% c()))
    ))
  })
  
  cat("✅ moduleServer completed for", id, "- returning result\n\n")
  return(result)
}

## To be copied in the UI
# mod_postal_card_processor_ui("postal_card_processor_1")

## To be copied in the server
# mod_postal_card_processor_server("postal_card_processor_1")
