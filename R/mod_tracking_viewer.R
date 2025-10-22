#' Enhanced Tracking Viewer UI
#'
#' @description Shows processing history with DT::datatable, filters, and search
#'
#' @param id Module ID
#' @export
#' @importFrom shiny NS tagList
#' @importFrom DT dataTableOutput
mod_tracking_viewer_ui <- function(id) {
  ns <- NS(id)

  tagList(
    bslib::card(
      header = bslib::card_header(
        "Processing History",
        class = "bg-primary text-white"
      ),

      # Filter controls
      div(
        style = "padding: 15px; background: #f8f9fa; border-bottom: 1px solid #dee2e6;",
        div(
          style = "display: flex; gap: 15px; align-items: end;",
          div(
            style = "flex: 1;",
            selectInput(
              ns("date_range"),
              "Date Range:",
              choices = c(
                "Last 7 days" = "7",
                "Last 30 days" = "30",
                "Last 90 days" = "90",
                "Last 6 months" = "180",
                "Last year" = "365",
                "All time" = "all"
              ),
              selected = "7"
            )
          ),
          div(
            style = "flex: 1;",
            selectInput(
              ns("ebay_filter"),
              "eBay Status:",
              choices = c(
                "All" = "all",
                "Listed" = "listed",
                "Draft" = "draft",
                "Failed" = "failed",
                "Pending" = "pending",
                "Not Posted" = "none"
              ),
              selected = "all"
            )
          )
        )
      ),

      # DataTable
      div(
        style = "padding: 20px;",
        DT::dataTableOutput(ns("tracking_table"))
      )
    )
  )
}

#' Enhanced Tracking Viewer Server
#'
#' @description Server logic for tracking viewer with DT::datatable
#'
#' @param id Module ID
#' @export
#' @importFrom DT renderDataTable datatable
mod_tracking_viewer_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive: fetch filtered session data
    tracking_data <- reactive({
      # Get date filter
      days_back <- input$date_range
      date_filter <- if (days_back == "all") {
        ""
      } else {
        # Validate input to prevent SQL injection
        days <- as.integer(days_back)
        if (is.na(days)) days <- 7  # Fallback to default
        sprintf("AND sa.timestamp >= datetime('now', '-%d days')", days)
      }

      # Get eBay filter
      ebay_status <- input$ebay_filter
      ebay_filter <- if (ebay_status == "all") {
        ""
      } else if (ebay_status == "none") {
        "AND (el.status IS NULL OR el.status = '')"
      } else {
        # Sanitize input (whitelist approach)
        allowed_statuses <- c("listed", "draft", "failed", "pending")
        if (ebay_status %in% allowed_statuses) {
          sprintf("AND el.status = '%s'", ebay_status)
        } else {
          ""  # Invalid status, show all
        }
      }

      # Query database for session-based data
      get_session_tracking_data(date_filter, ebay_filter)
    })

    # Render DataTable
    output$tracking_table <- DT::renderDataTable({
      data <- tracking_data()

      if (nrow(data) == 0) {
        # Empty state
        return(data.frame(
          Message = "No processing sessions found for selected filters. Try adjusting your filters or process some images first."
        ))
      }

      # Format data for display with factors for better filtering
      # Show session-level summary with image type indicators
      display_data <- data.frame(
        SessionID = as.character(data$session_id),
        Time = format(as.POSIXct(data$session_time), "%Y-%m-%d %H:%M"),
        User = ifelse(
          is.na(data$username) | data$username == "",
          "Unknown",
          as.character(data$username)
        ),
        Cards = as.integer(data$cards_processed),
        Images = sprintf("%s%s%s",
          ifelse(data$has_face > 0, "F", ""),
          ifelse(data$has_verso > 0, "V", ""),
          ifelse(data$has_combined > 0, "C", "")
        ),
        AIExtractions = as.integer(data$ai_extractions),
        EbayPosts = as.integer(data$ebay_posts),
        EbayStatus = ifelse(
          is.na(data$ebay_status) | data$ebay_status == "",
          "Not Posted",
          tools::toTitleCase(data$ebay_status)
        ),
        stringsAsFactors = FALSE
      )

      # Convert categorical columns to factors for better DT filtering
      display_data$User <- factor(display_data$User)
      display_data$Images <- factor(display_data$Images)
      display_data$EbayStatus <- factor(display_data$EbayStatus)

      dt <- DT::datatable(
        display_data,
        selection = "single",
        filter = "top",  # Add column filters at the top
        options = list(
          pageLength = 25,
          lengthMenu = c(10, 25, 50, 100),
          order = list(list(1, "desc")),  # Sort by Time descending
          autoWidth = TRUE,
          columnDefs = list(
            list(width = "100px", targets = 0),  # SessionID
            list(width = "140px", targets = 1),  # Time
            list(width = "100px", targets = 2),  # User
            list(width = "80px", targets = 3),   # Cards
            list(width = "80px", targets = 4),   # Images (F/V/C)
            list(width = "100px", targets = 5),  # AI Extractions
            list(width = "100px", targets = 6),  # eBay Posts
            list(width = "110px", targets = 7)   # EbayStatus
          ),
          language = list(
            search = "Search sessions:",
            lengthMenu = "Show _MENU_ sessions per page",
            info = "Showing _START_ to _END_ of _TOTAL_ processing sessions",
            infoEmpty = "No sessions to display",
            infoFiltered = "(filtered from _MAX_ total sessions)",
            zeroRecords = "No matching sessions found"
          )
        ),
        rownames = FALSE,
        class = "table table-striped table-hover"
      )

      # Add visual styling to EbayStatus column
      dt <- DT::formatStyle(
        dt,
        'EbayStatus',
        backgroundColor = DT::styleEqual(
          c('Listed', 'Draft', 'Failed', 'Pending', 'Not Posted'),
          c('#d1fcd3', '#fff3cd', '#f8d7da', '#cfe2ff', '#e9ecef')
        ),
        color = DT::styleEqual(
          c('Listed', 'Draft', 'Failed', 'Pending', 'Not Posted'),
          c('#0f5132', '#997404', '#842029', '#084298', '#6c757d')
        ),
        fontWeight = 'bold'
      )

      dt
    })

    # Handle row click - open session detail modal
    observeEvent(input$tracking_table_rows_selected, {
      selected_row <- input$tracking_table_rows_selected

      if (length(selected_row) > 0) {
        data <- tracking_data()
        if (nrow(data) > 0 && selected_row <= nrow(data)) {
          session_id <- data$session_id[selected_row]
          show_session_modal(session_id, data[selected_row, ])
        }
      }
    })

    # Helper function: Extract crop directories from JSON paths
    extract_crop_directories <- function(crop_paths_json, extraction_dir) {
      # Parse JSON crop paths
      crop_paths <- tryCatch(
        jsonlite::fromJSON(crop_paths_json),
        error = function(e) NULL
      )

      if (is.null(crop_paths) || length(crop_paths) == 0) {
        return(NULL)
      }

      # Extract directory from first crop path
      # Assuming format: /path/to/crops/face|verso/card_id/extract_timestamp/crop_row0_col0.jpg
      first_path <- crop_paths[1]
      crop_dir <- dirname(first_path)

      return(crop_dir)
    }

    # Helper function: Recreate combined images from stored crop data
    recreate_combined_images_for_session <- function(session_id, cards_df) {
      # Filter for face and verso cards with processing data
      face_cards <- cards_df[cards_df$image_type == "face" & !is.na(cards_df$crop_paths), ]
      verso_cards <- cards_df[cards_df$image_type == "verso" & !is.na(cards_df$crop_paths), ]

      # Check for mismatches and build warnings
      warnings <- c()
      if (nrow(face_cards) == 0 && nrow(verso_cards) == 0) {
        return(NULL)  # No crops at all, nothing to recreate
      }

      if (nrow(face_cards) == 0) {
        return(list(
          error = TRUE,
          message = "No face images with crop data found. Cannot recreate combined images.",
          warnings = "Missing face images"
        ))
      }

      if (nrow(verso_cards) == 0) {
        return(list(
          error = TRUE,
          message = "No verso images with crop data found. Cannot recreate combined images.",
          warnings = "Missing verso images"
        ))
      }

      # Warn about count mismatches
      if (nrow(face_cards) != nrow(verso_cards)) {
        warnings <- c(warnings, sprintf(
          "Count mismatch: %d face image(s) but %d verso image(s). Will process %d pair(s).",
          nrow(face_cards), nrow(verso_cards), min(nrow(face_cards), nrow(verso_cards))
        ))
      }

      tryCatch({
        # Sort both by card_id to ensure proper pairing
        face_cards <- face_cards[order(face_cards$card_id), ]
        verso_cards <- verso_cards[order(verso_cards$card_id), ]

        # Process pairs up to the minimum count
        num_pairs <- min(nrow(face_cards), nrow(verso_cards))

        # Check if Python function exists
        if (!exists("combine_face_verso_images", envir = .GlobalEnv)) {
          message("Python combine function not available")
          return(list(
            error = TRUE,
            message = "Combined image recreation is not available. Please restart the app.",
            warnings = paste(warnings, collapse = " ")
          ))
        }

        # Create temp output directory for recreated combined images
        temp_combined_dir <- file.path(tempdir(), "tracking_combined", session_id)
        dir.create(temp_combined_dir, recursive = TRUE, showWarnings = FALSE)

        # Register resource path once for all images
        resource_prefix_tracking <- paste0("tracking_combined_", session_id)
        shiny::addResourcePath(resource_prefix_tracking, normalizePath(temp_combined_dir, winslash = "/"))

        # Collect all results
        all_combined_paths <- c()
        all_web_urls <- c()
        all_lot_paths <- c()
        all_lot_web_urls <- c()

        message("Recreating combined images for ", num_pairs, " face/verso pair(s)...")

        # Process each pair
        for (i in 1:num_pairs) {
          face_card <- face_cards[i, ]
          verso_card <- verso_cards[i, ]

          message("  Processing pair ", i, "/", num_pairs, "...")

          # Extract crop directories
          face_dir <- extract_crop_directories(face_card$crop_paths, face_card$extraction_dir)
          verso_dir <- extract_crop_directories(verso_card$crop_paths, verso_card$extraction_dir)

          if (is.null(face_dir) || is.null(verso_dir)) {
            message("    ⚠️  Skipping pair ", i, ": Could not extract crop directories")
            warnings <- c(warnings, sprintf("Pair %d: Could not extract crop directories", i))
            next
          }

          # Verify directories exist
          if (!dir.exists(face_dir) || !dir.exists(verso_dir)) {
            message("    ⚠️  Skipping pair ", i, ": Crop directories do not exist")
            warnings <- c(warnings, sprintf("Pair %d: Crop files no longer available", i))
            next
          }

          # Get grid dimensions
          num_rows <- face_card$grid_rows
          num_cols <- face_card$grid_cols

          if (is.na(num_rows) || is.na(num_cols)) {
            h_bounds <- tryCatch(jsonlite::fromJSON(face_card$h_boundaries), error = function(e) NULL)
            v_bounds <- tryCatch(jsonlite::fromJSON(face_card$v_boundaries), error = function(e) NULL)

            if (!is.null(h_bounds)) num_rows <- length(h_bounds) - 1
            if (!is.null(v_bounds)) num_cols <- length(v_bounds) - 1
          }

          if (is.na(num_rows) || is.null(num_rows)) num_rows <- 1
          if (is.na(num_cols) || is.null(num_cols)) num_cols <- 1

          # Create subdirectory for this pair
          pair_output_dir <- file.path(temp_combined_dir, paste0("pair_", i))
          dir.create(pair_output_dir, recursive = TRUE, showWarnings = FALSE)

          # Call Python function
          py_result <- combine_face_verso_images(
            face_dir = face_dir,
            verso_dir = verso_dir,
            output_dir = pair_output_dir,
            num_rows = as.integer(num_rows),
            num_cols = as.integer(num_cols)
          )

          if (!is.null(py_result$combined_paths) && length(py_result$combined_paths) > 0) {
            message("    ✓ Created ", length(py_result$combined_paths), " combined image(s)")

            # Collect combined paths
            abs_combined <- normalizePath(unlist(py_result$combined_paths), winslash = "/")
            all_combined_paths <- c(all_combined_paths, abs_combined)

            # Create web URLs
            abs_temp_dir <- normalizePath(temp_combined_dir, winslash = "/")
            rel_paths <- sub(paste0("^", gsub("/", "\\\\/", abs_temp_dir), "/*"), "", abs_combined)
            rel_paths <- sub("^/*", "", rel_paths)
            web_urls <- paste(resource_prefix_tracking, rel_paths, sep = "/")
            all_web_urls <- c(all_web_urls, web_urls)

            # Collect lot paths
            if (!is.null(py_result$lot_paths) && length(py_result$lot_paths) > 0) {
              abs_lot <- normalizePath(unlist(py_result$lot_paths), winslash = "/")
              all_lot_paths <- c(all_lot_paths, abs_lot)

              rel_lot_paths <- sub(paste0("^", gsub("/", "\\\\/", abs_temp_dir), "/*"), "", abs_lot)
              rel_lot_paths <- sub("^/*", "", rel_lot_paths)
              lot_web_urls <- paste(resource_prefix_tracking, rel_lot_paths, sep = "/")
              all_lot_web_urls <- c(all_lot_web_urls, lot_web_urls)
            }
          } else {
            message("    ⚠️  Pair ", i, " failed to create combined images")
            warnings <- c(warnings, sprintf("Pair %d: Failed to create combined images", i))
          }
        }

        if (length(all_combined_paths) > 0) {
          message("✓ Total: ", length(all_combined_paths), " combined image(s) recreated")

          return(list(
            combined_paths = all_combined_paths,
            web_urls = all_web_urls,
            lot_paths = if (length(all_lot_paths) > 0) all_lot_paths else NULL,
            lot_web_urls = if (length(all_lot_web_urls) > 0) all_lot_web_urls else NULL,
            temp_dir = temp_combined_dir,
            resource_prefix = resource_prefix_tracking,
            warnings = if (length(warnings) > 0) paste(warnings, collapse = " ") else NULL,
            num_pairs_processed = num_pairs
          ))
        } else {
          return(list(
            error = TRUE,
            message = "Failed to recreate any combined images from available face/verso pairs.",
            warnings = paste(warnings, collapse = " ")
          ))
        }

      }, error = function(e) {
        message("Error recreating combined images: ", e$message)
        return(list(
          error = TRUE,
          message = paste("Error recreating combined images:", e$message),
          warnings = paste(warnings, collapse = " ")
        ))
      })
    }

    # Modal builder - Show all session images grouped by type
    show_session_modal <- function(session_id, session_row) {
      # Get all cards for this session
      cards <- get_session_cards(session_id)

      # Recreate combined images if face/verso crops exist
      combined_recreation <- recreate_combined_images_for_session(session_id, cards)

      # Build mapping of combined card_id to image index
      # IMPORTANT: Only map cards that have corresponding recreated images
      combined_image_map <- list()
      if (!is.null(combined_recreation) && !isTRUE(combined_recreation$error)) {
        combined_cards <- cards[cards$image_type == "combined", ]
        if (nrow(combined_cards) > 0 && !is.null(combined_recreation$web_urls)) {
          # Sort by card_id to match order of recreated images
          combined_cards <- combined_cards[order(combined_cards$card_id), ]

          # Only map cards up to the number of recreated images
          num_images <- length(combined_recreation$web_urls)
          num_cards_to_map <- min(nrow(combined_cards), num_images)

          for (i in 1:num_cards_to_map) {
            combined_image_map[[as.character(combined_cards$card_id[i])]] <- i
          }

          # Log a warning if there are more cards than images
          if (nrow(combined_cards) > num_images) {
            message("⚠️  Found ", nrow(combined_cards), " combined cards but only ",
                    num_images, " images recreated. Only showing first ", num_images, " cards.")
          }
        }
      }

      # Filter cards to only show those with valid image mappings
      if (nrow(cards) > 0) {
        cards_to_display <- cards[cards$image_type != "combined", ]
        combined_cards_to_display <- cards[cards$image_type == "combined", ]
        if (nrow(combined_cards_to_display) > 0) {
          # Only keep combined cards that have a mapping
          combined_cards_to_display <- combined_cards_to_display[
            sapply(combined_cards_to_display$card_id, function(id) {
              !is.null(combined_image_map[[as.character(id)]])
            }),
          ]
        }
        cards <- rbind(cards_to_display, combined_cards_to_display)
      }

      if (nrow(cards) == 0) {
        content <- tagList(
          div(
            class = "alert alert-warning",
            "No card data found for this session."
          )
        )
      } else {
        # Helper function to extract web path from various formats
        get_web_path <- function(crop_paths_json, upload_path, card_type = NULL, card_id = NULL) {
          # Special handling for combined images with recreation
          if (!is.null(card_type) && card_type == "combined" &&
              !is.null(combined_recreation) &&
              !isTRUE(combined_recreation$error) &&
              !is.null(combined_recreation$web_urls) &&
              !is.null(card_id)) {
            # Look up the correct image for this card_id
            img_index <- combined_image_map[[as.character(card_id)]]
            if (!is.null(img_index) && img_index <= length(combined_recreation$web_urls)) {
              return(combined_recreation$web_urls[img_index])
            }
          }
          # Try crop first
          crop_paths <- tryCatch(
            jsonlite::fromJSON(crop_paths_json),
            error = function(e) NULL
          )

          if (!is.null(crop_paths) && length(crop_paths) > 0) {
            path <- crop_paths[1]
            if (grepl("Delcampe/", path)) {
              return(sub("^inst/app/", "", sub(".*Delcampe/", "", path)))
            } else if (grepl("^inst/app/", path)) {
              return(sub("^inst/app/", "", path))
            } else {
              return(path)
            }
          }

          # Fallback to upload_path
          if (!is.na(upload_path) && !is.null(upload_path) && upload_path != "") {
            if (grepl("^data/", upload_path)) {
              return(upload_path)
            } else if (grepl("Delcampe/", upload_path)) {
              return(sub("^inst/app/", "", sub(".*Delcampe/", "", upload_path)))
            } else if (grepl("^inst/app/", upload_path)) {
              return(sub("^inst/app/", "", upload_path))
            } else {
              return(upload_path)
            }
          }

          return(NULL)
        }

        # Helper function to create card display
        create_card_display <- function(card) {
          web_path <- get_web_path(card$crop_paths, card$upload_path, card$image_type, card$card_id)
          has_image <- !is.null(web_path)
          has_ai <- !is.na(card$ai_title) && !is.null(card$ai_title) && nchar(as.character(card$ai_title)) > 0

          tagList(
            div(
              style = "margin-bottom: 30px; padding: 15px; background: #f8f9fa; border-radius: 8px;",

              # Image type header
              h4(tools::toTitleCase(card$image_type), style = "margin-bottom: 15px; color: #495057;"),

              div(
                style = "display: grid; grid-template-columns: 1fr 1fr; gap: 20px;",

                # Left: Image
                div(
                  if (has_image) {
                    tags$img(
                      src = web_path,
                      style = "width: 100%; max-height: 300px; object-fit: contain; border: 2px solid #dee2e6; border-radius: 4px; background: white;",
                      alt = card$original_filename,
                      onerror = "this.style.display='none'; this.nextElementSibling.style.display='block';"
                    )
                  } else {
                    div(
                      style = "padding: 40px; text-align: center; color: #6c757d; border: 2px dashed #dee2e6; border-radius: 4px;",
                      tags$i(class = "bi bi-image", style = "font-size: 48px;"),
                      tags$p("Image not available", style = "margin-top: 10px;")
                    )
                  },
                  if (has_image) {
                    div(style = "display: none; padding: 40px; text-align: center; color: #6c757d;",
                        "Image failed to load")
                  }
                ),

                # Right: AI Extraction
                div(
                  if (has_ai) {
                    tagList(
                      h5("AI Extraction", style = "margin-bottom: 10px;"),
                      tags$table(
                        class = "table table-sm",
                        tags$tr(tags$th("Model:"), tags$td(card$ai_model)),
                        tags$tr(tags$th("Title:"), tags$td(card$ai_title)),
                        tags$tr(tags$th("Condition:"), tags$td(card$ai_condition)),
                        tags$tr(tags$th("Price:"), tags$td(sprintf("$%.2f", card$ai_price)))
                      ),
                      div(
                        style = "margin-top: 10px;",
                        h6("Description:"),
                        div(
                          style = "padding: 10px; background: white; border-radius: 4px; border: 1px solid #dee2e6; max-height: 150px; overflow-y: auto;",
                          p(card$ai_description, style = "margin: 0; font-size: 0.9em;")
                        )
                      )
                    )
                  } else {
                    div(
                      class = "alert alert-secondary",
                      style = "margin: 0;",
                      "No AI extraction available for this image"
                    )
                  }
                )
              )
            )
          )
        }

        # Build status messages
        status_message <- NULL
        if (!is.null(combined_recreation)) {
          if (isTRUE(combined_recreation$error)) {
            # Error recreating combined images
            status_message <- tagList(
              div(
                class = "alert alert-warning",
                style = "margin-bottom: 15px;",
                icon("exclamation-triangle"),
                " ", combined_recreation$message
              ),
              if (!is.null(combined_recreation$warnings)) {
                div(
                  class = "alert alert-warning",
                  style = "margin-bottom: 15px;",
                  icon("info-circle"),
                  " ", combined_recreation$warnings
                )
              }
            )
          } else {
            # Success recreating combined images
            status_message <- tagList(
              div(
                class = "alert alert-info",
                style = "margin-bottom: 15px;",
                icon("info-circle"),
                " Combined images recreated from stored crop data (",
                length(combined_recreation$combined_paths), " images",
                if (!is.null(combined_recreation$num_pairs_processed)) {
                  paste0(" from ", combined_recreation$num_pairs_processed, " face/verso pair(s)")
                },
                ")"
              ),
              if (!is.null(combined_recreation$warnings)) {
                div(
                  class = "alert alert-warning",
                  style = "margin-bottom: 15px;",
                  icon("exclamation-triangle"),
                  " ", combined_recreation$warnings
                )
              }
            )
          }
        }

        # Build lot images section (if available)
        lot_images_section <- NULL
        if (!is.null(combined_recreation) &&
            !isTRUE(combined_recreation$error) &&
            !is.null(combined_recreation$lot_web_urls) &&
            length(combined_recreation$lot_web_urls) > 0) {

          # Get all combined cards with AI extraction data
          combined_cards_with_ai <- cards[cards$image_type == "combined", ]
          combined_cards_with_ai <- combined_cards_with_ai[order(combined_cards_with_ai$card_id), ]

          lot_images_section <- div(
            style = "margin-top: 30px; padding-top: 30px; border-top: 3px solid #dee2e6;",
            h3("Lot Combined Images", style = "margin-bottom: 20px; color: #495057;"),
            p(
              style = "margin-bottom: 15px; color: #6c757d;",
              "These images show all cards from this session combined into lot views."
            ),
            lapply(1:length(combined_recreation$lot_web_urls), function(i) {
              div(
                style = "margin-bottom: 30px; padding: 15px; background: #f8f9fa; border-radius: 8px;",

                h4(paste("Lot View", i), style = "margin-bottom: 15px; color: #495057;"),

                div(
                  style = "display: grid; grid-template-columns: 1fr 1fr; gap: 20px;",

                  # Left: Lot Image
                  div(
                    tags$img(
                      src = combined_recreation$lot_web_urls[i],
                      style = "width: 100%; max-height: 400px; object-fit: contain; border: 2px solid #dee2e6; border-radius: 4px; background: white;",
                      alt = paste("Lot combined image", i),
                      onerror = "this.style.display='none'; this.nextElementSibling.style.display='block';"
                    ),
                    div(
                      style = "display: none; padding: 40px; text-align: center; color: #6c757d;",
                      "Image failed to load"
                    )
                  ),

                  # Right: All AI Extractions from combined cards
                  div(
                    h5("AI Extractions in This Lot", style = "margin-bottom: 10px;"),
                    if (nrow(combined_cards_with_ai) > 0) {
                      tagList(
                        lapply(1:nrow(combined_cards_with_ai), function(j) {
                          card <- combined_cards_with_ai[j, ]
                          has_ai <- !is.na(card$ai_title) && !is.null(card$ai_title) && nchar(as.character(card$ai_title)) > 0

                          if (has_ai) {
                            div(
                              style = "margin-bottom: 15px; padding: 10px; background: white; border-radius: 4px; border: 1px solid #dee2e6;",
                              h6(paste("Card", j), style = "margin-bottom: 5px; color: #495057;"),
                              tags$table(
                                class = "table table-sm",
                                style = "margin-bottom: 5px;",
                                tags$tr(tags$th("Model:"), tags$td(card$ai_model)),
                                tags$tr(tags$th("Title:"), tags$td(card$ai_title)),
                                tags$tr(tags$th("Condition:"), tags$td(card$ai_condition)),
                                tags$tr(tags$th("Price:"), tags$td(sprintf("$%.2f", card$ai_price)))
                              ),
                              div(
                                style = "margin-top: 5px;",
                                strong("Description:"),
                                p(card$ai_description, style = "margin: 5px 0 0 0; font-size: 0.85em;")
                              )
                            )
                          }
                        })
                      )
                    } else {
                      div(
                        class = "alert alert-secondary",
                        style = "margin: 0;",
                        "No AI extractions available for this lot"
                      )
                    }
                  )
                )
              )
            })
          )
        }

        # Build content: group cards by type
        content <- tagList(
          # Session info
          div(
            style = "margin-bottom: 20px; padding: 15px; background: #e9ecef; border-radius: 8px;",
            div(style = "display: flex; justify-content: space-between; align-items: center;",
                h5(sprintf("Session: %s", session_id), style = "margin: 0;"),
                span(sprintf("%s | %d cards processed",
                           format(as.POSIXct(session_row$session_time), "%Y-%m-%d %H:%M"),
                           session_row$cards_processed),
                     style = "color: #6c757d;")
            )
          ),

          # Status message (if any)
          status_message,

          # Display cards by type
          lapply(1:nrow(cards), function(i) {
            create_card_display(cards[i, ])
          }),

          # Lot combined images section (if any)
          lot_images_section
        )
      }

      # Show modal
      showModal(
        modalDialog(
          title = sprintf("Session Details: %s", format(as.POSIXct(session_row$session_time), "%Y-%m-%d %H:%M")),
          content,
          size = "xl",
          easyClose = TRUE,
          footer = modalButton("Close")
        )
      )
    }
  })
}
