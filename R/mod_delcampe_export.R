#' Delcampe Export UI Function  
#'
#' @description A shiny Module for exporting images to eBay with AI extraction support.
#' USING bslib::accordion() for proper namespace handling
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#'
#' @importFrom shiny NS tagList
#' @importFrom bslib accordion accordion_panel
mod_delcampe_export_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    # Accordion will be dynamically generated
    uiOutput(ns("accordion_container"))
  )
}

#' Delcampe Export Server Functions
#'
#' @param image_paths Reactive containing vector of image web URLs
#' @param image_file_paths Reactive containing vector of actual file system paths (optional)
#' @param image_type Character string ("lot" or "combined") to distinguish image types
#'
#' @noRd
mod_delcampe_export_server <- function(id, image_paths = reactive(NULL), image_file_paths = reactive(NULL), image_type = "combined") {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # State management
    rv <- reactiveValues(
      sent_images = character(0),
      pending_images = character(0),
      failed_images = character(0),
      image_drafts = list(),
      current_image_index = NULL,
      ai_extracting = FALSE,
      ai_result = NULL,
      selected_model = NULL,
      ai_status = ""
    )
    
    # Generate accordion dynamically
    output$accordion_container <- renderUI({
      req(image_paths())
      paths <- image_paths()
      
      if (length(paths) == 0) {
        return(div(
          style = "padding: 40px; text-align: center; color: #868e96;",
          icon("image", style = "font-size: 48px; margin-bottom: 16px;"),
          h4("No images to export"),
          p("Process some images first to export them to eBay.")
        ))
      }
      
      # Create accordion panels for each image
      panels <- lapply(seq_along(paths), function(i) {
        create_accordion_panel(i, paths[i])
      })
      
      # Use bslib::accordion with open = FALSE to start collapsed
      # multiple = FALSE means only one panel can be open at a time (auto-collapse)
      bslib::accordion(
        id = ns("export_accordion"),
        open = FALSE,  # All closed by default
        multiple = FALSE,  # Auto-collapse: only one open at a time
        !!!panels  # Splice in the list of panels
      )
    })
    
    # Create individual accordion panel
    create_accordion_panel <- function(idx, path) {
      status <- get_image_status(idx)
      status_badge <- get_status_badge(status)
      
      # Panel title with thumbnail and status
      panel_title <- div(
        style = "display: flex; align-items: center; gap: 12px;",
        tags$img(
          src = path,
          style = "width: 80px; height: 60px; object-fit: cover; border-radius: 4px; border: 2px solid #dee2e6;"
        ),
        div(
          style = "flex: 1;",
          strong(paste0(tools::toTitleCase(image_type), " ", idx))
        ),
        status_badge
      )
      
      # Panel content (form)
      panel_content <- create_form_content(idx, path)
      
      bslib::accordion_panel(
        title = panel_title,
        value = paste0("panel_", idx),
        panel_content
      )
    }
    
    # Get status badge HTML
    get_status_badge <- function(status) {
      badge_data <- switch(status,
        "ready" = list(label = "Ready", color = "#1971c2", bg = "#e7f5ff"),
        "draft" = list(label = "Draft", color = "#f08c00", bg = "#fff3bf"),
        "sent" = list(label = "Sent", color = "#2f9e44", bg = "#d3f9d8"),
        "pending" = list(label = "Sending...", color = "#7950f2", bg = "#e5dbff"),
        "failed" = list(label = "Failed", color = "#c92a2a", bg = "#ffe3e3"),
        list(label = "Ready", color = "#1971c2", bg = "#e7f5ff")
      )
      
      span(
        style = paste0(
          "padding: 4px 12px; border-radius: 12px; font-size: 13px; font-weight: 500; ",
          "background: ", badge_data$bg, "; color: ", badge_data$color, ";"
        ),
        badge_data$label
      )
    }
    
    # Get image status
    get_image_status <- function(idx) {
      paths <- image_paths()
      if (is.null(paths) || idx > length(paths)) return("ready")
      
      path <- paths[idx]
      
      if (path %in% isolate(rv$sent_images)) return("sent")
      if (path %in% isolate(rv$pending_images)) return("pending")
      if (path %in% isolate(rv$failed_images)) return("failed")
      
      draft_key <- as.character(idx)
      drafts <- isolate(rv$image_drafts)
      if (!is.null(drafts) && draft_key %in% names(drafts)) return("draft")
      
      return("ready")
    }
    
    # Create form content for accordion panel
    create_form_content <- function(idx, path) {
      div(
        style = "padding: 20px;",
        
        fluidRow(
          # Left: Image preview (width 6)
          column(
            6,
            div(
              style = "text-align: center;",
              tags$img(
                src = path,
                style = "width: 100%; max-height: 300px; object-fit: contain; border-radius: 8px; border: 1px solid #dee2e6;"
              )
            )
          ),
          
          # Right: AI controls (width 6)
          column(
            6,
            div(
              style = "padding: 16px; background: #f1f3f5; border-radius: 6px; border-left: 4px solid #4c6ef5; height: 100%;",
              h5(icon("robot"), " AI Assistant", style = "margin-top: 0;"),
              selectInput(
                ns(paste0("ai_model_", idx)),
                "Model",
                choices = c("Claude" = "claude", "GPT-4" = "gpt4"),
                selected = "claude",
                width = "100%"
              ),
              uiOutput(ns(paste0("ai_button_", idx)))
            )
          )
        ),
        
        # AI Status output (width 12)
        fluidRow(
          column(
            12,
            uiOutput(ns(paste0("ai_status_", idx)))
          )
        ),
        
        # Title (width 12)
        fluidRow(
          column(
            12,
            textAreaInput(
              ns(paste0("item_title_", idx)),
              "Title *",
              rows = 2,
              placeholder = "Enter listing title...",
              width = "100%"
            )
          )
        ),
        
        # Description (width 12)
        fluidRow(
          column(
            12,
            textAreaInput(
              ns(paste0("item_description_", idx)),
              "Description *",
              rows = 6,
              placeholder = "Enter detailed description...",
              width = "100%"
            )
          )
        ),
        
        # Price and Condition (width 6 each)
        fluidRow(
          column(
            6,
            numericInput(
              ns(paste0("starting_price_", idx)),
              "Price (€) *",
              value = 2.50,
              min = 0.50,
              step = 0.50,
              width = "100%"
            )
          ),
          column(
            6,
            selectInput(
              ns(paste0("condition_", idx)),
              "Condition *",
              choices = c(
                "Used" = "used",
                "Excellent" = "excellent",
                "Good" = "good",
                "Fair" = "fair",
                "Poor" = "poor"
              ),
              selected = "used",
              width = "100%"
            )
          )
        ),
        
        # Action button - Send to eBay
        fluidRow(
          column(
            12,
            div(
              style = "margin-top: 16px;",
              actionButton(
                ns(paste0("send_to_ebay_", idx)),
                "Send to eBay",
                icon = icon("upload"),
                class = "btn-success",
                style = "width: 100%;"
              )
            )
          )
        )
      )
    }
    
    # Helper function to convert web URL to file system path
    convert_web_path_to_file_path <- function(web_path) {
      cat("   🔍 Converting web path to file path...\n")
      cat("      Web path:", web_path, "\n")
      
      # Remove any resource prefix (e.g., "combined_session_images/" or "lot_session_images/")
      # Extract just the filename and relative directory structure
      cleaned_path <- sub("^[^/]+/", "", web_path)  # Remove first directory
      
      cat("      Cleaned path:", cleaned_path, "\n")
      
      # Get the basename to search for
      filename <- basename(web_path)
      cat("      Looking for file:", filename, "\n")
      
      # Search in tempdir() and its subdirectories
      temp_base <- tempdir()
      cat("      Searching in:", temp_base, "\n")
      
      # List all subdirectories in tempdir
      temp_dirs <- list.dirs(temp_base, full.names = TRUE, recursive = TRUE)
      
      # Search for the file in all temp directories
      for (dir in temp_dirs) {
        possible_path <- file.path(dir, cleaned_path)
        if (file.exists(possible_path)) {
          real_path <- normalizePath(possible_path, winslash = "/")
          cat("      ✅ Found file:", real_path, "\n")
          return(real_path)
        }
      }
      
      # If not found with cleaned path, search by filename only
      cat("      ⚠ Not found with relative path, searching by filename only...\n")
      for (dir in temp_dirs) {
        files <- list.files(dir, pattern = filename, full.names = TRUE, recursive = FALSE)
        if (length(files) > 0) {
          real_path <- normalizePath(files[1], winslash = "/")
          cat("      ✅ Found file:", real_path, "\n")
          return(real_path)
        }
      }
      
      # Last resort: check working directory
      wd_path <- file.path(getwd(), web_path)
      if (file.exists(wd_path)) {
        real_path <- normalizePath(wd_path, winslash = "/")
        cat("      ✅ Found in working directory:", real_path, "\n")
        return(real_path)
      }
      
      cat("      ❌ File not found anywhere\n")
      return(NULL)
    }
    
    # Draft management functions (kept simple)
    save_current_draft <- function(idx) {
      draft_key <- as.character(idx)
      rv$image_drafts[[draft_key]] <- list(
        title = input[[paste0("item_title_", idx)]] %||% "",
        description = input[[paste0("item_description_", idx)]] %||% "",
        price = input[[paste0("starting_price_", idx)]] %||% 2.50,
        condition = input[[paste0("condition_", idx)]] %||% "used",
        ai_extracted = TRUE,
        timestamp = Sys.time()
      )
    }
    
    # Store existing AI data for each image (to be used when accordion opens)
    existing_ai_data <- reactiveVal(list())

    # Pre-load existing AI data from database (runs once when images load)
    observe({
      req(image_paths())
      paths <- image_paths()
      file_paths <- image_file_paths()

      cat("\n=== PRE-LOADING AI DATA FROM DATABASE ===\n")
      cat("   Number of images:", length(paths), "\n")

      ai_data_list <- lapply(seq_along(paths), function(i) {
        cat("\n   --- Checking image", i, "for existing AI data ---\n")
        cat("      Web path:", paths[i], "\n")

        # Get the actual file path to calculate hash
        actual_path <- if (!is.null(file_paths) && i <= length(file_paths)) {
          cat("      Using image_file_paths mapping\n")
          file_paths[i]
        } else {
          cat("      No file_paths mapping, converting web path\n")
          convert_web_path_to_file_path(paths[i])
        }

        cat("      Actual path:", if(is.null(actual_path)) "NULL" else actual_path, "\n")
        cat("      File exists:", if(is.null(actual_path)) FALSE else file.exists(actual_path), "\n")

        if (is.null(actual_path) || !file.exists(actual_path)) {
          cat("      ⚠️ Cannot pre-populate - file not found\n")
          return(NULL)
        }

        # Calculate hash to check for existing AI data
        cat("      Calculating hash...\n")
        image_hash <- calculate_image_hash(actual_path)
        cat("      Hash:", if(is.null(image_hash)) "NULL" else image_hash, "\n")

        if (is.null(image_hash)) {
          cat("      ⚠️ Cannot calculate hash\n")
          return(NULL)
        }

        # Check for existing card processing with AI data (combined images)
        cat("      Querying database for existing AI data (image_type='combined')...\n")
        existing <- find_card_processing(image_hash, "combined")

        cat("      Database lookup result:\n")
        if (is.null(existing)) {
          cat("         ❌ No existing card found\n")
        } else {
          cat("         ✅ Found card_id:", existing$card_id, "\n")
          cat("         - ai_title:", if(is.null(existing$ai_title)) "NULL" else substr(existing$ai_title, 1, 50), "\n")
          cat("         - ai_description:", if(is.null(existing$ai_description)) "NULL" else paste0(nchar(existing$ai_description), " chars"), "\n")
          cat("         - ai_price:", if(is.null(existing$ai_price)) "NULL" else existing$ai_price, "\n")
          cat("         - ai_condition:", if(is.null(existing$ai_condition)) "NULL" else existing$ai_condition, "\n")
          cat("         - ai_model:", if(is.null(existing$ai_model)) "NULL" else existing$ai_model, "\n")
        }

        # Check if AI data actually exists (not NULL and not NA)
        has_ai_data <- !is.null(existing) &&
                       !is.null(existing$ai_title) &&
                       !is.na(existing$ai_title) &&
                       nchar(as.character(existing$ai_title)) > 0

        if (has_ai_data) {
          cat("      ✨ Found existing AI data - storing for later\n")

          # Save as draft immediately
          draft_key <- as.character(i)
          isolate({
            rv$image_drafts[[draft_key]] <- list(
              title = existing$ai_title,
              description = existing$ai_description,
              price = existing$ai_price,
              condition = existing$ai_condition,
              ai_extracted = TRUE,
              pre_populated = TRUE,
              timestamp = Sys.time()
            )
          })

          # Return the AI data for this image
          return(list(
            index = i,
            has_data = TRUE,
            ai_title = existing$ai_title,
            ai_description = existing$ai_description,
            ai_price = existing$ai_price,
            ai_condition = existing$ai_condition,
            ai_model = existing$ai_model
          ))
        } else {
          cat("   ℹ️ No existing AI data found for image", i, "\n")
          return(list(index = i, has_data = FALSE))
        }
      })

      # Store the AI data list
      existing_ai_data(ai_data_list)
      cat("=== AI DATA PRE-LOAD COMPLETE ===\n\n")
    })

    # Populate fields when accordion panel opens
    observeEvent(input$export_accordion, {
      opened_panel <- input$export_accordion

      if (is.null(opened_panel) || length(opened_panel) == 0) {
        return()
      }

      cat("\n=== ACCORDION PANEL OPENED ===\n")
      cat("   Panel:", opened_panel, "\n")

      # Extract image index from panel value (e.g., "panel_1" -> 1)
      panel_match <- regexpr("panel_(\\d+)", opened_panel, perl = TRUE)
      if (panel_match > 0) {
        i <- as.integer(sub("panel_", "", opened_panel))
        cat("   Image index:", i, "\n")

        # Get AI data for this image
        ai_data_list <- existing_ai_data()
        if (!is.null(ai_data_list) && i <= length(ai_data_list)) {
          ai_data <- ai_data_list[[i]]

          if (!is.null(ai_data) && isTRUE(ai_data$has_data)) {
            cat("   ✨ Found AI data for image", i, "- populating fields with delay\n")

            # Use later::later() to ensure UI is rendered before updating
            later::later(function() {
              tryCatch({
                cat("   🔄 Delayed update triggered for image", i, "\n")

                # Update title
                if (!is.null(ai_data$ai_title) && !is.na(ai_data$ai_title)) {
                  updateTextAreaInput(session, paste0("item_title_", i), value = ai_data$ai_title)
                  cat("   ✓ Title populated\n")
                }

                # Update description
                if (!is.null(ai_data$ai_description) && !is.na(ai_data$ai_description)) {
                  updateTextAreaInput(session, paste0("item_description_", i), value = ai_data$ai_description)
                  cat("   ✓ Description populated\n")
                }

                # Update price
                if (!is.null(ai_data$ai_price) && !is.na(ai_data$ai_price)) {
                  updateNumericInput(session, paste0("starting_price_", i), value = ai_data$ai_price)
                  cat("   ✓ Price populated\n")
                }

                # Update condition
                if (!is.null(ai_data$ai_condition) && !is.na(ai_data$ai_condition)) {
                  updateSelectInput(session, paste0("condition_", i), selected = ai_data$ai_condition)
                  cat("   ✓ Condition populated\n")
                }

                # Show success status
                output[[paste0("ai_status_", i)]] <- renderUI({
                  div(
                    style = "padding: 12px; background: #e8f5e9; border-left: 4px solid #4caf50; margin-top: 10px;",
                    icon("check-circle", style = "color: #2e7d32;"),
                    sprintf(" Previous AI extraction loaded (Model: %s)", ai_data$ai_model %||% "Unknown")
                  )
                })

                cat("   ✅ Field updates complete\n")

              }, error = function(e) {
                cat("   ❌ Error populating fields:", e$message, "\n")
              })
            }, delay = 0.15)  # 150ms delay to allow UI to render

          } else {
            cat("   ℹ️ No AI data to populate for image", i, "\n")
          }
        }
      }
    })

    # Render AI buttons dynamically based on extraction history
    observe({
      req(image_paths())
      paths <- image_paths()

      lapply(seq_along(paths), function(i) {
        output[[paste0("ai_button_", i)]] <- renderUI({
          # Get image ID from path to check extraction history
          image_id <- get_image_by_path(paths[i])

          button_label <- "Extract with AI"
          button_icon <- icon("wand-magic-sparkles")
          button_class <- "btn-primary"

          if (!is.null(image_id)) {
            # Check if there's a previous extraction
            history <- get_ai_extraction_history(image_id)

            if (nrow(history) > 0) {
              # There's a previous extraction
              button_label <- "Re-extract with AI"
              button_icon <- icon("rotate")
              button_class <- "btn-warning"
            }
          }

          actionButton(
            ns(paste0("extract_ai_", i)),
            button_label,
            icon = button_icon,
            class = button_class,
            style = "width: 100%; margin-top: 10px;"
          )
        })
      })
    })
    
    # AI Extraction Handlers - Create observers for each image's Extract AI button
    observe({
      req(image_paths())
      paths <- image_paths()
      
      lapply(seq_along(paths), function(i) {
        observeEvent(input[[paste0("extract_ai_", i)]], {

          cat("\n🎯 Extract AI button clicked for image", i, "\n")

          # Get current path and model
          current_path <- paths[i]
          selected_model <- input[[paste0("ai_model_", i)]] %||% "claude"

          cat("   Path:", current_path, "\n")
          cat("   Model:", selected_model, "\n")

          # Get LLM config
          config <- get_llm_config()

          # Validate API key exists
          api_key <- if (selected_model == "claude") {
            config$claude_api_key
          } else {
            config$openai_api_key
          }

          if (is.null(api_key) || api_key == "") {
            cat("   ❌ No API key configured for", selected_model, "\n")
            output[[paste0("ai_status_", i)]] <- renderUI({
              div(
                style = "padding: 12px; background: #fff3cd; border-left: 4px solid #ffc107; margin-top: 10px;",
                icon("exclamation-triangle", style = "color: #856404;"),
                sprintf(" Please configure %s API key in Settings menu",
                        if(selected_model == "claude") "Claude" else "OpenAI")
              )
            })
            return()
          }

          cat("   ✅ API key found, length:", nchar(api_key), "\n")

          # Set extracting state
          isolate({
            rv$ai_extracting <- TRUE
            rv$current_image_index <- i
          })

          # Show progress
          output[[paste0("ai_status_", i)]] <- renderUI({
            div(
              style = "padding: 12px; background: #e3f2fd; border-left: 4px solid #2196f3; margin-top: 10px;",
              icon("spinner", class = "fa-spin", style = "color: #1976d2;"),
              sprintf(" Extracting with %s...", if(selected_model == "claude") "Claude" else "GPT-4")
            )
          })

          # Call AI API directly (no later::later() - it breaks namespace context for form updates)
          tryCatch({
            cat("\n🔍 Starting AI extraction\n")

              # Get actual file system path from mapping (if provided)
              file_paths <- image_file_paths()
              actual_path <- if (!is.null(file_paths) && i <= length(file_paths)) {
                file_paths[i]
              } else {
                # Fallback to old conversion method if no mapping provided
                convert_web_path_to_file_path(current_path)
              }

              if (is.null(actual_path) || !file.exists(actual_path)) {
                cat("   ❌ Could not find image file\n")
                cat("      Attempted path:", actual_path, "\n")
                output[[paste0("ai_status_", i)]] <- renderUI({
                  div(
                    style = "padding: 12px; background: #ffebee; border-left: 4px solid #f44336; margin-top: 10px;",
                    icon("exclamation-circle", style = "color: #c62828;"),
                    " Error: Could not locate image file for AI processing"
                  )
                })
                isolate({ rv$ai_extracting <- FALSE })
                return()
              }

              cat("   ✅ Using file path:", actual_path, "\n")
              
              # Build enhanced prompt with price recommendation
              prompt <- build_enhanced_postal_card_prompt(
                extraction_type = if(image_type == "lot") "lot" else "individual",
                card_count = 1
              )
              
              cat("   Prompt built, calling API...\n")
              
              # Call appropriate API (using actual file path)
              result <- if (selected_model == "claude") {
                call_claude_api(
                  image_path = actual_path,
                  model_name = config$default_model,
                  api_key = api_key,
                  prompt = prompt,
                  temperature = config$temperature %||% 0.0,
                  max_tokens = config$max_tokens %||% 1000
                )
              } else {
                call_openai_api(
                  image_path = actual_path,
                  model_name = "gpt-4o",
                  api_key = api_key,
                  prompt = prompt,
                  temperature = config$temperature %||% 0.0,
                  max_tokens = config$max_tokens %||% 1000
                )
              }
              
              cat("   API call complete, success:", result$success, "\n")
              
              if (result$success) {
                # Debug: Log raw AI response
                cat("\n   📄 Raw AI Response:\n")
                cat("   ", paste(rep("-", 60), collapse=""), "\n")
                cat(result$content, "\n")
                cat("   ", paste(rep("-", 60), collapse=""), "\n\n")
                
                # Parse enhanced response with price
                parsed <- parse_enhanced_ai_response(result$content)
                
                cat("   ✅ Parsing successful\n")
                cat("      Title:", substr(parsed$title, 1, 50), "...\n")
                cat("      Description:", substr(parsed$description, 1, 100), "...\n")
                cat("      Condition:", parsed$condition, "\n")
                cat("      Price: €", parsed$price, "\n")
                
                # Auto-fill form fields (both title and description are now textAreaInput)
                cat("   📝 Updating form fields...\n")

                # Update title (now a textAreaInput)
                shiny::updateTextAreaInput(session, paste0("item_title_", i), value = parsed$title)
                cat("      Title updated (length:", nchar(parsed$title), ")\n")

                # Update description
                shiny::updateTextAreaInput(session, paste0("item_description_", i), value = parsed$description)
                cat("      Description updated (length:", nchar(parsed$description), ")\n")

                updateNumericInput(session, paste0("starting_price_", i), value = parsed$price)
                cat("      Price updated\n")

                updateSelectInput(session, paste0("condition_", i), selected = parsed$condition)
                cat("      Condition updated\n")
                
                # Save draft
                draft_key <- as.character(i)
                isolate({
                  rv$image_drafts[[draft_key]] <- list(
                    title = parsed$title,
                    description = parsed$description,
                    price = parsed$price,
                    condition = parsed$condition,
                    ai_extracted = TRUE,
                    timestamp = Sys.time()
                  )
                })
                
                cat("   💾 Draft saved\n")

                # Save AI data to card_processing table for pre-population on next upload
                cat("\n=== SAVING AI DATA TO DATABASE ===\n")
                tryCatch({
                  cat("   Step 1: Calculate hash for file:", actual_path, "\n")

                  # Calculate hash to find card_id
                  image_hash <- calculate_image_hash(actual_path)
                  cat("   Hash result:", if(is.null(image_hash)) "NULL" else image_hash, "\n")

                  if (!is.null(image_hash)) {
                    cat("   Step 2: Looking up card_id from postal_cards table\n")

                    # First, get card_id from postal_cards directly (not using find_card_processing)
                    # because combined images may not have a card_processing record yet
                    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
                    on.exit(DBI::dbDisconnect(con), add = TRUE)

                    card_result <- DBI::dbGetQuery(con, "
                      SELECT card_id FROM postal_cards
                      WHERE file_hash = ? AND image_type = ?
                    ", list(image_hash, "combined"))

                    cat("   Query result:\n")
                    if (nrow(card_result) == 0) {
                      cat("      ❌ No card found in postal_cards\n")
                      cat("         Hash:", image_hash, "\n")
                      cat("         Type: combined\n")
                      cat("         This means the combined image wasn't tracked when created!\n")
                    } else {
                      cat("      ✅ Found card_id:", card_result$card_id[1], "\n")
                    }

                    if (nrow(card_result) > 0) {
                      card_id <- card_result$card_id[1]

                      # Now check if a card_processing record exists
                      cat("   Step 3: Checking if card_processing record exists\n")
                      existing_processing <- find_card_processing(image_hash, "combined")

                      if (is.null(existing_processing)) {
                        cat("      ⚠️ No card_processing record exists - will be created\n")
                      } else {
                        cat("      ✅ card_processing record exists\n")
                        cat("         Has AI data:", !is.null(existing_processing$ai_title), "\n")
                      }

                      cat("   Step 4: Preparing AI data to save\n")

                      # Save AI data to card_processing table
                      ai_data <- list(
                        title = parsed$title,
                        description = parsed$description,
                        condition = parsed$condition,
                        price = parsed$price,
                        model = if(selected_model == "claude") config$default_model else "gpt-4o"
                      )

                      cat("      AI data prepared:\n")
                      cat("         - Title:", substr(ai_data$title, 1, 50), "...\n")
                      cat("         - Description length:", nchar(ai_data$description), "chars\n")
                      cat("         - Condition:", ai_data$condition, "\n")
                      cat("         - Price:", ai_data$price, "\n")
                      cat("         - Model:", ai_data$model, "\n")

                      cat("   Step 5: Calling save_card_processing()\n")
                      save_success <- save_card_processing(
                        card_id = card_id,  # Use card_id from postal_cards query
                        crop_paths = NULL,  # Not updating crops, just AI data
                        h_boundaries = NULL,
                        v_boundaries = NULL,
                        grid_rows = NULL,
                        grid_cols = NULL,
                        extraction_dir = NULL,
                        ai_data = ai_data
                      )

                      cat("   Save result:", save_success, "\n")

                      if (save_success) {
                        cat("   ✅ AI data saved to card_processing (card_id:", card_id, ")\n")

                        # Verify the save by reading back
                        cat("   Step 6: Verifying save by reading back from database\n")
                        verify <- find_card_processing(image_hash, "combined")
                        if (!is.null(verify)) {
                          cat("      Verification successful:\n")
                          cat("         - ai_title:", if(is.null(verify$ai_title)) "NULL" else substr(verify$ai_title, 1, 50), "\n")
                          cat("         - ai_price:", if(is.null(verify$ai_price)) "NULL" else verify$ai_price, "\n")
                          cat("         - ai_condition:", if(is.null(verify$ai_condition)) "NULL" else verify$ai_condition, "\n")
                          cat("         - ai_model:", if(is.null(verify$ai_model)) "NULL" else verify$ai_model, "\n")
                        } else {
                          cat("      ⚠️ Verification failed - could not read back data\n")
                          cat("         This might be OK if it's the first save (no last_processed yet)\n")
                        }
                      } else {
                        cat("   ❌ save_card_processing() returned FALSE\n")
                      }
                    } else {
                      cat("   ❌ No card found in postal_cards table\n")
                      cat("      This means combined image wasn't tracked when created\n")
                    }
                  } else {
                    cat("   ❌ Could not calculate hash for file\n")
                  }
                }, error = function(e) {
                  cat("   💥 ERROR in save AI data block:\n")
                  cat("      Message:", e$message, "\n")
                  cat("      Call:", deparse(e$call), "\n")
                })
                cat("=== END SAVING AI DATA ===\n\n")

                # Track AI extraction in legacy ai_extractions table
                tryCatch({
                  image_id <- get_image_by_path(current_path)
                  if (!is.null(image_id)) {
                    extraction_id <- track_ai_extraction(
                      image_id = image_id,
                      model = if(selected_model == "claude") config$default_model else "gpt-4o",
                      title = parsed$title,
                      description = parsed$description,
                      condition = parsed$condition,
                      recommended_price = parsed$price,
                      success = TRUE
                    )
                    cat("   📊 Extraction tracked with ID:", extraction_id, "\n")
                  } else {
                    cat("   ⚠️ Could not find image_id for tracking\n")
                  }
                }, error = function(e) {
                  cat("   ⚠️ Failed to track extraction:", e$message, "\n")
                })
                
                # Note: Accordion color change would require JavaScript in later() context
                # which has caused issues before (see showNotification problems)
                # Skipping visual indicator to keep code simple and reliable
                
                # Show success
                output[[paste0("ai_status_", i)]] <- renderUI({
                  div(
                    style = "padding: 12px; background: #e8f5e9; border-left: 4px solid #4caf50; margin-top: 10px;",
                    icon("check-circle", style = "color: #2e7d32;"),
                    sprintf(" Extraction complete! Recommended price: €%.2f", parsed$price)
                  )
                })
                
              } else {
                # Track failed extraction
                tryCatch({
                  image_id <- get_image_by_path(current_path)
                  if (!is.null(image_id)) {
                    track_ai_extraction(
                      image_id = image_id,
                      model = if(selected_model == "claude") config$default_model else "gpt-4o",
                      success = FALSE,
                      error_message = result$error
                    )
                    cat("   📊 Failed extraction tracked\n")
                  }
                }, error = function(e) {
                  cat("   ⚠️ Failed to track error:", e$message, "\n")
                })
                
                # Show error
                cat("   ❌ API error:", result$error, "\n")
                output[[paste0("ai_status_", i)]] <- renderUI({
                  div(
                    style = "padding: 12px; background: #ffebee; border-left: 4px solid #f44336; margin-top: 10px;",
                    icon("exclamation-circle", style = "color: #c62828;"),
                    paste(" Error:", result$error)
                  )
                })
              }
          }, error = function(e) {
            cat("   💥 Unexpected error:", e$message, "\n")
            output[[paste0("ai_status_", i)]] <- renderUI({
              div(
                style = "padding: 12px; background: #ffebee; border-left: 4px solid #f44336; margin-top: 10px;",
                icon("exclamation-circle", style = "color: #c62828;"),
                paste(" Unexpected error:", e$message)
              )
            })
          }, finally = {
            isolate({ rv$ai_extracting <- FALSE })
            cat("   🏁 AI extraction complete\n\n")
          })
        })
      })
    })
    
    # Return module interface
    return(list(
      get_sent_count = reactive(length(rv$sent_images)),
      get_pending_count = reactive(length(rv$pending_images)),
      get_failed_count = reactive(length(rv$failed_images))
    ))
  })
}
