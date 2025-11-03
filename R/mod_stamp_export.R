#' Stamp Export UI Function  
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
mod_stamp_export_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    # Accordion will be dynamically generated
    uiOutput(ns("accordion_container"))
  )
}

# Standard description template constant
STANDARD_DESCRIPTION_TEMPLATE <- "THIS ITEM IS SOLD AS IT IS PLEASE LOOK CAREFULLY AT THE PHOTOS!!! - All items are part of my private collection. Your satisfaction is guaranteed, full refund if the item is not as described.

AT THE MOMENT ROMANIAN POST DOES NOT SEND ITEMS IN UKRAINE, BELARUS AND RUSSIAN FEDERATION SO I WILL NOT BE ABLE TO COMPLETE ORDERS FROM THIS COUNTRIES UNLESS YOU HAVE A SECOND SHIPPING ADDRESS IN OTHER COUNTRY.


Shipping rates worldwide (economy, not registered):


 50 - 100g     - 4$
100 - 500g    - 7$
500 - 1000g  - 10$

For registered shipping there is an extra 2$ to be added. If you want registered shipping, please let me know after the auction is finished. I am not responsible for any items lost or stolen in shipments that are not registered."

#' Build template description from title and standard text
#' @param title Character string with extracted title
#' @return Character string with formatted description
build_template_description <- function(title) {
  # Use fallback if title is empty
  if (is.null(title) || trimws(title) == "") {
    title <- "Vintage Stamp"
  }

  # Concatenate title + standard template
  paste(title, STANDARD_DESCRIPTION_TEMPLATE, sep = "\n\n")
}

#' Sort images so lot cards combined images appear first
#' @param image_paths Character vector of image paths
#' @return Sorted character vector
sort_images_lot_first <- function(image_paths) {
  if (length(image_paths) == 0) {
    return(image_paths)
  }

  # Define priority order
  priority_order <- data.frame(
    path = image_paths,
    priority = sapply(image_paths, function(path) {
      # Lot images: lot_column_X.jpg or lot_row_X_col_Y.jpg
      if (grepl("lot_column", path, ignore.case = TRUE) || grepl("lot_row", path, ignore.case = TRUE)) {
        return(1)  # Lot images first
      }
      # Combined face+verso images: combined_rowX_colY.jpg
      if (grepl("combined_row", path, ignore.case = TRUE) || grepl("combined", path, ignore.case = TRUE)) {
        return(2)  # Combined images second
      }
      return(3)  # Everything else
    }),
    stringsAsFactors = FALSE
  )

  # Sort by priority first, then alphabetically within priority
  priority_order <- priority_order[order(priority_order$priority, priority_order$path), ]

  cat("📋 Image ordering:\n")
  cat("   Lot images (lot_column/lot_row):", sum(priority_order$priority == 1), "\n")
  cat("   Combined images (combined_row):", sum(priority_order$priority == 2), "\n")
  cat("   Other images:", sum(priority_order$priority == 3), "\n")

  return(priority_order$path)
}

#' Stamp Export Server Functions
#'
#' @param image_paths Reactive containing vector of image web URLs
#' @param image_file_paths Reactive containing vector of actual file system paths (optional)
#' @param image_type Character string ("lot" or "combined") to distinguish image types
#' @param ebay_api Reactive eBay API object from mod_ebay_auth_server (optional)
#' @param ebay_account_manager EbayAccountManager object for multi-account support (optional)
#'
#' @noRd
mod_stamp_export_server <- function(id, image_paths = reactive(NULL), image_file_paths = reactive(NULL), image_type = "combined", ebay_api = reactive(NULL), ebay_account_manager = NULL) {
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

      # Sort images so lot cards appear first
      sorted_paths <- sort_images_lot_first(paths)

      # Create accordion panels for each image (using sorted paths)
      panels <- lapply(seq_along(sorted_paths), function(i) {
        create_accordion_panel(i, sorted_paths[i])
      })

      # Wrap accordion in full-width container
      div(
        class = "container-fluid",
        style = "padding: 0; margin: 0; width: 100%;",

        # Use bslib::accordion with open = FALSE to start collapsed
        # multiple = FALSE means only one panel can be open at a time (auto-collapse)
        bslib::accordion(
          id = ns("export_accordion"),
          open = FALSE,  # All closed by default
          multiple = FALSE,  # Auto-collapse: only one open at a time
          !!!panels  # Splice in the list of panels
        )
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

        # Row 1: Image preview (4 cols) + AI Controls (8 cols)
        fluidRow(
          # Image preview
          column(
            4,
            div(
              style = "text-align: center;",
              actionLink(
                ns(paste0("enlarge_img_", idx)),
                tags$img(
                  src = path,
                  style = "width: 100%; max-height: 250px; object-fit: contain; border-radius: 8px; border: 1px solid #dee2e6; cursor: pointer;"
                )
              ),
              div(
                style = "margin-top: 8px; font-size: 12px; color: #868e96;",
                icon("search-plus"), " Click to enlarge"
              )
            )
          ),

          # AI controls
          column(
            8,
            div(
              style = "padding: 16px; background: #f1f3f5; border-radius: 6px; border-left: 4px solid #4c6ef5; height: 100%;",
              h5(icon("robot"), " AI Assistant", style = "margin-top: 0; margin-bottom: 16px;"),
              fluidRow(
                column(
                  6,
                  selectInput(
                    ns(paste0("ai_model_", idx)),
                    "Model",
                    choices = c("Claude" = "claude", "GPT-4" = "gpt4"),
                    selected = "claude",
                    width = "100%"
                  )
                ),
                column(
                  6,
                  div(
                    style = "padding-top: 5px;",
                    checkboxInput(
                      ns(paste0("fetch_ai_description_", idx)),
                      "Fetch AI description",
                      value = FALSE
                    )
                  )
                )
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

        # Row 2: Title (8 cols) + Price (2 cols) + Condition (2 cols)
        fluidRow(
          column(
            8,
            textAreaInput(
              ns(paste0("item_title_", idx)),
              "Title *",
              rows = 2,
              placeholder = "Enter listing title (max 80 characters)...",
              width = "100%"
            )
          ),
          column(
            2,
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
            2,
            selectInput(
              ns(paste0("condition_", idx)),
              "Condition *",
              choices = c(
                "Used" = "used",
                "Mint" = "mint",
                "Near Mint" = "near mint",
                "Excellent" = "excellent",
                "Very Good" = "very good",
                "Good" = "good",
                "Fair" = "fair",
                "Poor" = "poor"
              ),
              selected = "used",
              width = "100%"
            )
          )
        ),

        # Row 3: Description (full width)
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

        # Row 4: Listing Type (4 cols) + Auction Duration (4 cols) + Buy It Now (4 cols)
        fluidRow(
          column(
            4,
            selectInput(
              ns(paste0("listing_type_", idx)),
              "Listing Type *",
              choices = c(
                "Auction" = "auction",
                "Buy It Now (Fixed Price)" = "fixed_price"
              ),
              selected = "auction",
              width = "100%"
            )
          ),
          # Auction Duration (conditional - shown only for auctions)
          column(
            4,
            conditionalPanel(
              condition = sprintf("input['%s'] == 'auction'", ns(paste0("listing_type_", idx))),
              selectInput(
                ns(paste0("auction_duration_", idx)),
                "Auction Duration *",
                choices = c(
                  "3 Days" = "Days_3",
                  "5 Days" = "Days_5",
                  "7 Days" = "Days_7",
                  "10 Days" = "Days_10"
                ),
                selected = "Days_7",
                width = "100%"
              )
            )
          ),
          # Buy It Now Price (conditional - shown only for auctions)
          column(
            4,
            conditionalPanel(
              condition = sprintf("input['%s'] == 'auction'", ns(paste0("listing_type_", idx))),
              numericInput(
                ns(paste0("buy_it_now_price_", idx)),
                "Buy It Now (€) - Optional",
                value = NA,
                min = 0,
                step = 0.50,
                width = "100%"
              )
            )
          )
        ),

        # Row 5: Reserve Price (4 cols) + Year (4 cols) + Country (4 cols)
        fluidRow(
          # Reserve Price (conditional - shown only for auctions)
          column(
            4,
            conditionalPanel(
              condition = sprintf("input['%s'] == 'auction'", ns(paste0("listing_type_", idx))),
              numericInput(
                ns(paste0("reserve_price_", idx)),
                "Reserve (€) - Optional",
                value = NA,
                min = 0,
                step = 0.50,
                width = "100%"
              )
            )
          ),
          column(
            4,
            textInput(
              ns(paste0("year_", idx)),
              "Year",
              placeholder = "e.g., 1920",
              width = "100%"
            )
          ),
          column(
            4,
            textInput(
              ns(paste0("country_", idx)),
              "Country",
              placeholder = "e.g., Romania",
              width = "100%"
            )
          )
        ),

        # eBay Category Selection Section
        tags$hr(style = "margin-top: 20px; margin-bottom: 10px;"),
        tags$h5("eBay Category *", style = "margin-bottom: 10px; color: #495057;"),
        tags$div(
          style = "background: #fff3cd; border-left: 4px solid #ffc107; padding: 10px; margin-bottom: 15px; border-radius: 4px;",
          icon("exclamation-triangle", class = "text-warning"),
          tags$span(" Category is required for eBay listing. AI will auto-select based on detected country.", style = "color: #856404; margin-left: 8px;")
        ),

        # Row 5b: Region (6 cols) + Country/Subcategory (6 cols)
        fluidRow(
          column(
            6,
            selectInput(
              ns(paste0("ebay_region_", idx)),
              "Region *",
              choices = c(
                "Select region..." = "",
                "United States" = "US",
                "Canada" = "CA",
                "Great Britain" = "GB",
                "Europe" = "EU",
                "Asia" = "AS",
                "Africa" = "AF",
                "Latin America" = "LA",
                "Caribbean" = "CB",
                "Middle East" = "ME",
                "Australia & Oceania" = "OC",
                "British Colonies & Territories" = "BC",
                "Topical Stamps" = "TP",
                "Worldwide" = "WW",
                "Specialty Philately" = "SP",
                "Publications & Supplies" = "PS",
                "Other Stamps" = "OT"
              ),
              selected = "",
              width = "100%"
            )
          ),
          column(
            6,
            # Country dropdown will be populated dynamically based on region selection
            uiOutput(ns(paste0("ebay_country_ui_", idx)))
          )
        ),

        # Category validation indicator
        fluidRow(
          column(
            12,
            uiOutput(ns(paste0("category_validation_", idx)))
          )
        ),

        # Row 6: Scheduling Controls
        tags$hr(style = "margin-top: 20px; margin-bottom: 10px;"),
        tags$h5("Listing Schedule", style = "margin-bottom: 10px; color: #495057;"),

        fluidRow(
          column(
            3,
            checkboxInput(
              ns(paste0("list_immediately_", idx)),
              "List Immediately (skip scheduling)",
              value = FALSE
            )
          ),
          column(
            3,
            conditionalPanel(
              condition = sprintf("!input['%s']", ns(paste0("list_immediately_", idx))),
              dateInput(
                ns(paste0("schedule_date_", idx)),
                "Start Date (Pacific)",
                value = Sys.Date(),
                min = Sys.Date(),
                max = Sys.Date() + 21,
                width = "100%"
              )
            )
          ),
          column(
            2,
            conditionalPanel(
              condition = sprintf("!input['%s']", ns(paste0("list_immediately_", idx))),
              selectInput(
                ns(paste0("schedule_hour_", idx)),
                "Hour",
                choices = sprintf("%02d", 0:23),
                selected = "10",
                width = "100%"
              )
            )
          ),
          column(
            2,
            conditionalPanel(
              condition = sprintf("!input['%s']", ns(paste0("list_immediately_", idx))),
              selectInput(
                ns(paste0("schedule_minute_", idx)),
                "Minute",
                choices = sprintf("%02d", c(0, 15, 30, 45)),
                selected = "00",
                width = "100%"
              )
            )
          ),
          column(
            2,
            conditionalPanel(
              condition = sprintf("!input['%s']", ns(paste0("list_immediately_", idx))),
              uiOutput(ns(paste0("schedule_display_", idx)))
            )
          )
        ),

        # Stamp-Specific Metadata Section Header
        tags$hr(style = "margin-top: 20px; margin-bottom: 10px;"),
        tags$h5("Stamp Metadata (Optional)", style = "margin-bottom: 10px; color: #495057;"),

        # Row 6: Denomination (4 cols) + Scott Number (4 cols) + Perforation (4 cols)
        fluidRow(
          column(
            4,
            textInput(
              ns(paste0("denomination_", idx)),
              "Denomination",
              placeholder = "e.g., 5 LEI, 10c",
              width = "100%"
            )
          ),
          column(
            12,
            tags$div(
              style = "border-left: 3px solid #9370DB; padding-left: 10px; margin-top: 10px;",
              tags$label("Advanced Philatelic Details (Manual Entry Only)", style = "font-weight: bold; color: #9370DB;"),
              tags$small("Scott Number, Perforation, Watermark - fill in if you know them", style = "color: #666; display: block; margin-bottom: 10px;")
            )
          )
        ),
        fluidRow(
          column(
            12,
            textAreaInput(
              ns(paste0("scott_number_", idx)),
              "Scott Catalog Number",
              value = "",
              placeholder = "e.g., US-1234, RO-567",
              width = "100%",
              rows = 1
            )
          )
        ),
        fluidRow(
          column(
            6,
            textAreaInput(
              ns(paste0("perforation_", idx)),
              "Perforation Type",
              value = "",
              placeholder = "e.g., Perf 12, Imperf, Rouletted",
              width = "100%",
              rows = 1
            )
          ),
          column(
            6,
            textAreaInput(
              ns(paste0("watermark_", idx)),
              "Watermark",
              value = "",
              placeholder = "e.g., Crown, Star, None visible",
              width = "100%",
              rows = 1
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

    # Helper function to show eBay confirmation modal
    # idx: Image index for unique button identification
    show_ebay_confirmation_modal <- function(idx, title, price, condition, category = "Stamps",
                                             listing_type = "fixed_price", duration = "GTC",
                                             buy_it_now = NULL, reserve = NULL,
                                             schedule_time = NULL) {
      button_id <- ns(paste0("confirm_send_to_ebay_", idx))

      cat("   Creating modal with button ID:", button_id, "\n")

      # Format listing type display
      type_label <- if (listing_type == "auction") {
        duration_friendly <- gsub("Days_", "", duration)
        paste0("Auction (", duration_friendly, " days)")
      } else {
        "Buy It Now (Fixed Price)"
      }

      # Format price label based on listing type
      price_label <- if (listing_type == "auction") "Starting Bid:" else "Price:"

      showModal(
        modalDialog(
          title = "Confirm eBay Listing",
          size = "m",
          easyClose = FALSE,

          # Warning banner
          div(
            style = "padding: 12px; background: #fff3cd; border-left: 4px solid #ffc107; margin-bottom: 16px;",
            icon("exclamation-triangle", style = "color: #856404;"),
            strong(" Note: "),
            "eBay charges listing fees. Please review details before creating the listing."
          ),

          # Listing details
          tags$dl(
            class = "row",
            tags$dt(class = "col-sm-3", "Listing Type:"),
            tags$dd(class = "col-sm-9", type_label),

            tags$dt(class = "col-sm-3", "Title:"),
            tags$dd(class = "col-sm-9", title),

            tags$dt(class = "col-sm-3", price_label),
            tags$dd(class = "col-sm-9", sprintf("€%.2f", price)),

            # Show Buy It Now if specified
            if (!is.null(buy_it_now) && !is.na(buy_it_now) && buy_it_now > 0) {
              tagList(
                tags$dt(class = "col-sm-3", "Buy It Now:"),
                tags$dd(class = "col-sm-9", sprintf("€%.2f", buy_it_now))
              )
            } else { NULL },

            # Show Reserve if specified
            if (!is.null(reserve) && !is.na(reserve) && reserve > 0) {
              tagList(
                tags$dt(class = "col-sm-3", "Reserve Price:"),
                tags$dd(class = "col-sm-9", sprintf("€%.2f", reserve))
              )
            } else { NULL },

            tags$dt(class = "col-sm-3", "Condition:"),
            tags$dd(class = "col-sm-9", condition),

            tags$dt(class = "col-sm-3", "Category:"),
            tags$dd(class = "col-sm-9", category),

            # Schedule display
            if (!is.null(schedule_time)) {
              tagList(
                tags$dt(class = "col-sm-3", "Scheduled Start:"),
                tags$dd(
                  class = "col-sm-9",
                  tags$pre(
                    style = "font-size: 0.9em; margin: 0; white-space: pre-wrap;",
                    format_display_time(schedule_time)
                  ),
                  tags$br(),
                  tags$small(
                    style = "color: #856404;",
                    "⚠️ Listing will NOT be visible on eBay until scheduled time"
                  ),
                  tags$br(),
                  tags$small(
                    style = "color: #856404;",
                    "💵 eBay charges $0.10 scheduling fee"
                  )
                )
              )
            } else {
              tagList(
                tags$dt(class = "col-sm-3", "Start Time:"),
                tags$dd(class = "col-sm-9", "Immediately after creation")
              )
            }
          ),

          footer = tagList(
            modalButton("Cancel"),
            actionButton(
              button_id,
              "Create Listing",
              class = "btn-success",
              icon = icon("check")
            )
          )
        )
      )

      cat("   Modal created with button ID:", button_id, "\n")
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

      cat("\n🔍🔍🔍 === AI EXTRACTION DEDUPLICATION DEBUG === 🔍🔍🔍\n")
      cat("   Number of images to check:", length(paths), "\n")
      cat("   Image type:", image_type, "\n")
      cat("   file_paths available:", !is.null(file_paths), "\n")

      # Load AI data for each path - use path as key, not index
      ai_data_list <- lapply(seq_along(paths), function(i) {
        cat("\n📸 --- Image", i, "---\n")
        cat("   Web path:", paths[i], "\n")

        # Get the actual file path to calculate hash
        actual_path <- if (!is.null(file_paths) && i <= length(file_paths)) {
          cat("   ✅ Using image_file_paths mapping\n")
          file_paths[i]
        } else {
          cat("   ⚠️ No file_paths mapping, converting web path\n")
          convert_web_path_to_file_path(paths[i])
        }

        cat("   File path:", if(is.null(actual_path)) "NULL" else actual_path, "\n")
        cat("   File exists:", if(is.null(actual_path)) FALSE else file.exists(actual_path), "\n")

        if (is.null(actual_path) || !file.exists(actual_path)) {
          cat("   ❌ File not accessible - skipping deduplication\n")
          return(NULL)
        }

        # Calculate hash to check for existing AI data
        cat("   🔐 Calculating image hash...\n")
        image_hash <- calculate_image_hash(actual_path)
        cat("   Hash:", if(is.null(image_hash)) "NULL" else paste0(substr(image_hash, 1, 12), "..."), "\n")

        if (is.null(image_hash)) {
          cat("   ❌ Hash calculation failed\n")
          return(NULL)
        }

        # Check for existing stamp processing with AI data
        cat("   🔎 Querying database...\n")
        cat("      Searching for: hash=", substr(image_hash, 1, 12), "... + image_type='", image_type, "'\n", sep = "")

        existing <- find_stamp_processing(image_hash, image_type)

        cat("   📊 Query result:\n")
        if (is.null(existing)) {
          cat("      ❌ No existing stamp found\n")
          cat("      Reason: Either stamp doesn't exist OR no processing record exists\n")
        } else {
          cat("      ✅ Found stamp_id:", existing$stamp_id, "\n")
          cat("      Last processed:", if(is.null(existing$last_processed)) "NULL" else existing$last_processed, "\n")
          cat("      Has crop_paths:", !is.null(existing$crop_paths) && length(existing$crop_paths) > 0, "\n")
          cat("      AI Fields:\n")
          cat("         - ai_title: ", if(is.null(existing$ai_title)) "NULL" else if(is.na(existing$ai_title)) "NA" else paste0("'", substr(existing$ai_title, 1, 40), "...'"), "\n", sep = "")
          cat("         - ai_description: ", if(is.null(existing$ai_description)) "NULL" else if(is.na(existing$ai_description)) "NA" else paste0(nchar(existing$ai_description), " chars"), "\n", sep = "")
          cat("         - ai_price: ", if(is.null(existing$ai_price)) "NULL" else if(is.na(existing$ai_price)) "NA" else existing$ai_price, "\n", sep = "")
          cat("         - ai_condition: ", if(is.null(existing$ai_condition)) "NULL" else if(is.na(existing$ai_condition)) "NA" else existing$ai_condition, "\n", sep = "")
          cat("         - ai_model: ", if(is.null(existing$ai_model)) "NULL" else if(is.na(existing$ai_model)) "NA" else existing$ai_model, "\n", sep = "")
        }

        # Check if AI data actually exists (not NULL and not NA)
        has_ai_data <- !is.null(existing) &&
                       !is.null(existing$ai_title) &&
                       !is.na(existing$ai_title) &&
                       nchar(as.character(existing$ai_title)) > 0

        cat("   🎯 Has usable AI data:", has_ai_data, "\n")

        if (has_ai_data) {
          cat("   ✨✨✨ DEDUPLICATION SUCCESS ✨✨✨\n")
          cat("      Reusing AI data from stamp_id:", existing$stamp_id, "\n")
          cat("      Last processed:", existing$last_processed %||% "Unknown", "\n")

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
            path = paths[i],  # Include path for matching after sorting
            has_data = TRUE,
            ai_title = existing$ai_title,
            ai_description = existing$ai_description,
            ai_price = existing$ai_price,
            ai_condition = existing$ai_condition,
            ai_model = existing$ai_model,
            ai_year = existing$ai_year,
            ai_era = existing$ai_era,
            ai_city = existing$ai_city,
            ai_country = existing$ai_country,
            ai_region = existing$ai_region,
            ai_theme_keywords = existing$ai_theme_keywords
          ))
        } else {
          cat("   ⚠️ No usable AI data - will extract fresh\n")
          cat("      Reason: ", if(is.null(existing)) "Stamp not found" else "AI fields are NULL/NA/empty", "\n")
          return(list(index = i, path = paths[i], has_data = FALSE))
        }
      })

      # Store the AI data list
      existing_ai_data(ai_data_list)

      # Summary
      cat("\n📊 === DEDUPLICATION SUMMARY === 📊\n")
      cat("   Total images checked:", length(ai_data_list), "\n")
      found_count <- sum(sapply(ai_data_list, function(x) !is.null(x) && isTRUE(x$has_data)))
      cat("   Images with existing AI data:", found_count, "\n")
      cat("   Images needing fresh extraction:", length(ai_data_list) - found_count, "\n")
      cat("🔍🔍🔍 === END DEDUPLICATION DEBUG === 🔍🔍🔍\n\n")
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
        cat("   Panel index (sorted):", i, "\n")

        # Get sorted paths to find which image this panel represents
        paths <- image_paths()
        sorted_paths <- sort_images_lot_first(paths)

        if (i > length(sorted_paths)) {
          cat("   ⚠️ Panel index out of range\n")
          return()
        }

        current_path <- sorted_paths[i]
        cat("   Current path:", current_path, "\n")

        # Find AI data by matching path (not by index!)
        ai_data_list <- existing_ai_data()
        ai_data <- NULL

        if (!is.null(ai_data_list)) {
          # Search for matching path in AI data list
          for (data_item in ai_data_list) {
            if (!is.null(data_item) && !is.null(data_item$path) && data_item$path == current_path) {
              ai_data <- data_item
              cat("   ✅ Found AI data by path matching\n")
              break
            }
          }
        }

        if (!is.null(ai_data)) {

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

                # Update metadata fields if available
                if (!is.null(ai_data$ai_year) && !is.na(ai_data$ai_year) && ai_data$ai_year != "") {
                  updateTextInput(session, paste0("year_", i), value = ai_data$ai_year)
                  cat("   ✓ Year populated\n")
                }

                if (!is.null(ai_data$ai_country) && !is.na(ai_data$ai_country) && ai_data$ai_country != "") {
                  updateTextInput(session, paste0("country_", i), value = ai_data$ai_country)
                  cat("   ✓ Country populated\n")

                  # Auto-select eBay category based on country
                  category_mapping <- map_country_to_category(ai_data$ai_country)
                  if (!is.null(category_mapping$region_code) && category_mapping$region_code != "") {
                    updateSelectInput(session, paste0("ebay_region_", i), selected = category_mapping$region_code)
                    cat("   ✓ eBay Region auto-selected:", category_mapping$region_code, "\n")

                    # If we have a specific country label, select it after a short delay (to allow region dropdown to populate)
                    if (!is.null(category_mapping$country_label) && category_mapping$country_label != "" &&
                        !is.null(category_mapping$category_id) && !is.na(category_mapping$category_id)) {
                      Sys.sleep(0.2)  # Small delay for dropdown to populate
                      updateSelectInput(session, paste0("ebay_country_", i), selected = as.character(category_mapping$category_id))
                      cat("   ✓ eBay Country auto-selected:", category_mapping$country_label, "(", category_mapping$category_id, ")\n")
                    }
                  }
                }

                # Stamp-specific metadata fields
                if (!is.null(ai_data$ai_denomination) && !is.na(ai_data$ai_denomination) && ai_data$ai_denomination != "") {
                  updateTextInput(session, paste0("denomination_", i), value = ai_data$ai_denomination)
                  cat("   ✓ Denomination populated\n")
                }

                # Advanced fields - only populate from database if previously manually entered
                if (!is.null(ai_data$ai_scott_number) && !is.na(ai_data$ai_scott_number) && ai_data$ai_scott_number != "") {
                  updateTextAreaInput(session, paste0("scott_number_", i), value = ai_data$ai_scott_number)
                  cat("   ✓ Scott Number populated (manual entry)\n")
                }

                if (!is.null(ai_data$ai_perforation) && !is.na(ai_data$ai_perforation) && ai_data$ai_perforation != "") {
                  updateTextAreaInput(session, paste0("perforation_", i), value = ai_data$ai_perforation)
                  cat("   ✓ Perforation populated (manual entry)\n")
                }

                if (!is.null(ai_data$ai_watermark) && !is.na(ai_data$ai_watermark) && ai_data$ai_watermark != "") {
                  updateTextAreaInput(session, paste0("watermark_", i), value = ai_data$ai_watermark)
                  cat("   ✓ Watermark populated (manual entry)\n")
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
      req(existing_ai_data())  # Wait for AI data to be loaded
      paths <- image_paths()
      sorted_paths <- sort_images_lot_first(paths)
      ai_data_list <- existing_ai_data()

      lapply(seq_along(sorted_paths), function(i) {
        current_path <- sorted_paths[i]

        output[[paste0("ai_button_", i)]] <- renderUI({
          button_label <- "Extract with AI"
          button_icon <- icon("wand-magic-sparkles")
          button_class <- "btn-primary"

          # Find AI data by matching path (not by index!)
          has_existing_data <- FALSE
          if (!is.null(ai_data_list)) {
            for (data_item in ai_data_list) {
              if (!is.null(data_item) && !is.null(data_item$path) &&
                  data_item$path == current_path && isTRUE(data_item$has_data)) {
                has_existing_data <- TRUE
                break
              }
            }
          }

          if (has_existing_data) {
            # This is a duplicate with existing AI data
            button_label <- "Re-extract with AI"
            button_icon <- icon("rotate")
            button_class <- "btn-warning"
          }

          actionButton(
            ns(paste0("extract_ai_", i)),
            button_label,
            icon = button_icon,
            class = button_class,
            style = "width: 100%; margin-top: 10px;"
          )
        })

        # Dynamic country dropdown based on selected region
        output[[paste0("ebay_country_ui_", i)]] <- renderUI({
          region <- input[[paste0("ebay_region_", i)]]

          if (is.null(region) || region == "") {
            return(
              selectInput(
                ns(paste0("ebay_country_", i)),
                "Country/Subcategory *",
                choices = c("Select region first..." = ""),
                selected = "",
                width = "100%"
              )
            )
          }

          # Get country choices from STAMP_CATEGORIES
          if (!exists("STAMP_CATEGORIES")) {
            return(
              selectInput(
                ns(paste0("ebay_country_", i)),
                "Country/Subcategory *",
                choices = c("Error: Category data not loaded" = ""),
                selected = "",
                width = "100%"
              )
            )
          }

          region_data <- STAMP_CATEGORIES[[region]]
          if (is.null(region_data)) {
            return(
              selectInput(
                ns(paste0("ebay_country_", i)),
                "Country/Subcategory *",
                choices = c("Error: Invalid region" = ""),
                selected = "",
                width = "100%"
              )
            )
          }

          # Special case: "Other Stamps" is a leaf category (no countries)
          if (region == "OT" && !is.null(region_data$region_id)) {
            return(
              div(
                style = "padding: 10px; background: #d1f2eb; border-left: 4px solid #20c997; border-radius: 4px;",
                icon("check-circle", style = "color: #0c5e3e;"),
                tags$span(
                  paste0(" Category: ", region_data$label, " (", region_data$region_id, ")"),
                  style = "color: #0c5e3e; margin-left: 8px; font-weight: 500;"
                )
              )
            )
          }

          # Build country choices
          countries <- region_data$countries
          if (is.null(countries) || length(countries) == 0) {
            return(
              selectInput(
                ns(paste0("ebay_country_", i)),
                "Country/Subcategory *",
                choices = c("No countries available" = ""),
                selected = "",
                width = "100%"
              )
            )
          }

          # Create choices with names as labels and values as category IDs
          country_choices <- c("Select country..." = "", countries)

          selectInput(
            ns(paste0("ebay_country_", i)),
            "Country/Subcategory *",
            choices = country_choices,
            selected = "",
            width = "100%"
          )
        })

        # Category validation indicator
        output[[paste0("category_validation_", i)]] <- renderUI({
          region <- input[[paste0("ebay_region_", i)]]
          country_id <- input[[paste0("ebay_country_", i)]]

          # No selection yet
          if (is.null(region) || region == "" || is.null(country_id) || country_id == "") {
            return(
              div(
                style = "padding: 10px; background: #fff3cd; border-left: 4px solid #ffc107; border-radius: 4px; margin-top: 10px;",
                icon("exclamation-triangle", style = "color: #856404;"),
                tags$span(" Please select region and country/subcategory to enable eBay sending", style = "color: #856404; margin-left: 8px;")
              )
            )
          }

          # Special case: "Other Stamps" region (OT) is a leaf
          if (region == "OT") {
            region_data <- STAMP_CATEGORIES[[region]]
            if (!is.null(region_data$region_id)) {
              return(
                div(
                  style = "padding: 10px; background: #d1f2eb; border-left: 4px solid #20c997; border-radius: 4px; margin-top: 10px;",
                  icon("check-circle", style = "color: #0c5e3e;"),
                  tags$span(
                    paste0(" Valid leaf category: ", region_data$label, " (", region_data$region_id, ")"),
                    style = "color: #0c5e3e; margin-left: 8px; font-weight: 500;"
                  )
                )
              )
            }
          }

          # Valid selection (region + country both selected)
          region_data <- STAMP_CATEGORIES[[region]]
          country_name <- names(region_data$countries)[region_data$countries == as.numeric(country_id)]

          if (length(country_name) > 0) {
            return(
              div(
                style = "padding: 10px; background: #d1f2eb; border-left: 4px solid #20c997; border-radius: 4px; margin-top: 10px;",
                icon("check-circle", style = "color: #0c5e3e;"),
                tags$span(
                  paste0(" Valid leaf category: ", region_data$label, " > ", country_name, " (", country_id, ")"),
                  style = "color: #0c5e3e; margin-left: 8px; font-weight: 500;"
                )
              )
            )
          }

          # Invalid state
          div(
            style = "padding: 10px; background: #f8d7da; border-left: 4px solid #dc3545; border-radius: 4px; margin-top: 10px;",
            icon("times-circle", style = "color: #721c24;"),
            tags$span(" Invalid category selection", style = "color: #721c24; margin-left: 8px;")
          )
        })
      })
    })
    
    # AI Extraction Handlers - Create observers for each image's Extract AI button
    observe({
      req(image_paths())
      paths <- image_paths()
      sorted_paths <- sort_images_lot_first(paths)

      lapply(seq_along(sorted_paths), function(i) {
        observeEvent(input[[paste0("extract_ai_", i)]], ignoreNULL = TRUE, ignoreInit = TRUE, {

          cat("\n🎯 Extract AI button clicked for image", i, "\n")

          # Get checkbox state for description fetching
          fetch_description <- input[[paste0("fetch_ai_description_", i)]] %||% FALSE

          # Show notification
          notification_id <- showNotification(
            "Starting AI extraction...",
            duration = NULL,  # Don't auto-close
            closeButton = FALSE,
            type = "message"
          )

          # Get current path from sorted paths
          current_path <- sorted_paths[i]
          selected_model <- input[[paste0("ai_model_", i)]] %||% "claude"

          cat("   Path:", current_path, "\n")
          cat("   Model:", selected_model, "\n")
          cat("   Fetch AI description:", fetch_description, "\n")

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
              cat("   Image type:", image_type, "\n")

              # CONDITIONAL PROMPT SELECTION based on checkbox
              # If checkbox is checked: full prompt (description + metadata)
              # If checkbox is unchecked: minimal prompt (title + price + grade only) - saves ~70% tokens
              prompt <- if (fetch_description) {
                cat("   Using FULL prompt (description requested)\n")
                # Full prompt with description request
                build_stamp_prompt(
                  extraction_type = if(image_type == "lot") "lot" else if(image_type == "combined") "combined" else "individual",
                  stamp_count = 1
                )
              } else {
                cat("   Using MINIMAL prompt (title/price/grade only - saves tokens)\n")
                # Title-only prompt (skip description to save tokens)
                build_stamp_prompt_title_only(
                  extraction_type = if(image_type == "lot") "lot" else if(image_type == "combined") "combined" else "individual",
                  stamp_count = 1
                )
              }

              cat("   Prompt built, calling API...\n")

              # Update notification
              showNotification(
                sprintf("Analyzing with %s...", if(selected_model == "claude") "Claude" else "GPT-4"),
                id = notification_id,
                duration = NULL,
                closeButton = FALSE,
                type = "message"
              )

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

                # Parse stamp-specific response (NOT postal card parser!)
                parsed <- parse_stamp_response(result$content)
                
                cat("   ✅ Parsing successful\n")
                cat("      Title:", substr(parsed$title, 1, 50), "...\n")
                cat("      Description:", substr(parsed$description, 1, 100), "...\n")
                cat("      Recommended Price: $", parsed$recommended_price, "\n")
                cat("      Grade:", if(is.null(parsed$grade)) "NULL" else if(is.na(parsed$grade)) "NA" else parsed$grade, "\n")
                cat("      Year:", if(is.null(parsed$year)) "NULL" else if(is.na(parsed$year)) "NA" else parsed$year, "\n")
                cat("      Country:", if(is.null(parsed$country)) "NULL" else if(is.na(parsed$country)) "NA" else parsed$country, "\n")
                cat("      Denomination:", if(is.null(parsed$denomination)) "NULL" else if(is.na(parsed$denomination)) "NA" else parsed$denomination, "\n")
                cat("      Scott Number:", if(is.null(parsed$scott_number)) "NULL" else if(is.na(parsed$scott_number)) "NA" else parsed$scott_number, "\n")
                cat("      Perforation:", if(is.null(parsed$perforation)) "NULL" else if(is.na(parsed$perforation)) "NA" else parsed$perforation, "\n")
                cat("      Watermark:", if(is.null(parsed$watermark)) "NULL" else if(is.na(parsed$watermark)) "NA" else parsed$watermark, "\n")

                # Auto-fill form fields (both title and description are now textAreaInput)
                cat("   📝 Updating form fields...\n")

                # Use later::later() to ensure UI updates work properly
                later::later(function() {
                  # Update title (now a textAreaInput)
                  shiny::updateTextAreaInput(session, paste0("item_title_", i), value = parsed$title)
                  cat("      Title updated (length:", nchar(parsed$title), ")\n")

                  # CONDITIONAL: Update description based on checkbox
                  if (fetch_description) {
                    # AI-generated description
                    shiny::updateTextAreaInput(session, paste0("item_description_", i), value = parsed$description)
                    cat("      Description updated with AI content (length:", nchar(parsed$description), ")\n")
                  } else {
                    # Template-based description
                    template_description <- build_template_description(parsed$title)
                    shiny::updateTextAreaInput(session, paste0("item_description_", i), value = template_description)
                    cat("      Description updated with template (length:", nchar(template_description), ")\n")
                  }

                  updateNumericInput(session, paste0("starting_price_", i), value = parsed$recommended_price)
                  cat("      Price updated\n")

                  updateSelectInput(session, paste0("condition_", i), selected = parsed$grade)
                  cat("      Condition updated\n")

                  # Update metadata fields if available
                  if (!is.null(parsed$year) && !is.na(parsed$year) && parsed$year != "") {
                    updateTextInput(session, paste0("year_", i), value = parsed$year)
                    cat("      Year updated:", parsed$year, "\n")
                  }

                  if (!is.null(parsed$denomination) && !is.na(parsed$denomination) && parsed$denomination != "") {
                    updateTextInput(session, paste0("denomination_", i), value = parsed$denomination)
                    cat("      Denomination updated:", parsed$denomination, "\n")
                  }

                  if (!is.null(parsed$country) && !is.na(parsed$country) && parsed$country != "") {
                    updateTextInput(session, paste0("country_", i), value = parsed$country)
                    cat("      Country updated:", parsed$country, "\n")

                    # Auto-select eBay category based on country
                    category_mapping <- map_country_to_category(parsed$country)
                    if (!is.null(category_mapping$region_code) && category_mapping$region_code != "") {
                      updateSelectInput(session, paste0("ebay_region_", i), selected = category_mapping$region_code)
                      cat("      ✓ eBay Region auto-selected:", category_mapping$region_code, "\n")

                      # If we have a specific country label, select it after a short delay (to allow region dropdown to populate)
                      if (!is.null(category_mapping$country_label) && category_mapping$country_label != "" &&
                          !is.null(category_mapping$category_id) && !is.na(category_mapping$category_id)) {
                        Sys.sleep(0.2)  # Small delay for dropdown to populate
                        updateSelectInput(session, paste0("ebay_country_", i), selected = as.character(category_mapping$category_id))
                        cat("      ✓ eBay Country auto-selected:", category_mapping$country_label, "(", category_mapping$category_id, ")\n")
                      }
                    }
                  }

                  # NOTE: Scott number, perforation, and watermark are NOT populated by AI
                  # These are manual-entry fields only (AI cannot reliably extract them from photos)

                  cat("   ✅ Form fields updated\n")
                }, delay = 0.1)

                # Save draft
                draft_key <- as.character(i)
                isolate({
                  rv$image_drafts[[draft_key]] <- list(
                    title = parsed$title,
                    description = parsed$description,
                    price = parsed$recommended_price,
                    condition = parsed$grade,
                    ai_extracted = TRUE,
                    timestamp = Sys.time()
                  )
                })

                cat("   💾 Draft saved\n")

                # Save AI data to card_processing table for pre-population on next upload
                cat("\n=== SAVING AI DATA TO DATABASE ===\n")
                tryCatch({
                  cat("   Step 1: Calculate hash for file:", actual_path, "\n")

                  # Calculate hash to find stamp_id
                  image_hash <- calculate_image_hash(actual_path)
                  cat("   Hash result:", if(is.null(image_hash)) "NULL" else image_hash, "\n")

                  if (!is.null(image_hash)) {
                    cat("   Step 2: Looking up stamp_id from stamps table\n")

                    # Get stamp_id by hash only (same image can have multiple types)
                    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
                    on.exit(DBI::dbDisconnect(con), add = TRUE)

                    card_result <- DBI::dbGetQuery(con, "
                      SELECT stamp_id FROM stamps
                      WHERE file_hash = ?
                    ", list(image_hash))

                    cat("   Query result:\n")
                    if (nrow(card_result) == 0) {
                      cat("      ❌ No card found in stamps\n")
                      cat("         Hash:", image_hash, "\n")
                      cat("         Type: combined\n")
                      cat("         This means the combined image wasn't tracked when created!\n")
                    } else {
                      cat("      ✅ Found stamp_id:", card_result$stamp_id[1], "\n")
                    }

                    if (nrow(card_result) > 0) {
                      stamp_id <- card_result$stamp_id[1]

                      # Now check if a card_processing record exists
                      cat("   Step 3: Checking if card_processing record exists\n")
                      existing_processing <- find_stamp_processing(image_hash, image_type)

                      if (is.null(existing_processing)) {
                        cat("      ⚠️ No card_processing record exists - will be created\n")
                      } else {
                        cat("      ✅ card_processing record exists\n")
                        cat("         Has AI data:", !is.null(existing_processing$ai_title), "\n")
                      }

                      cat("   Step 4: Preparing AI data to save\n")

                      # Determine which description to save based on checkbox
                      description_to_save <- if (fetch_description) {
                        # AI-generated description (from full prompt)
                        parsed$description
                      } else {
                        # Template description (checkbox unchecked - minimal prompt)
                        build_template_description(parsed$title)
                      }

                      # Save AI data to stamp_processing table (stamp-specific fields)
                      ai_data <- list(
                        title = parsed$title,
                        description = description_to_save,  # Conditional description
                        condition = parsed$grade,  # For ai_condition column
                        grade = parsed$grade,      # For ai_grade column (both set to "used")
                        price = parsed$recommended_price,  # Stamp field: recommended_price instead of price
                        model = if(selected_model == "claude") config$default_model else "gpt-4o",
                        year = parsed$year,
                        country = parsed$country,
                        denomination = parsed$denomination,
                        scott_number = parsed$scott_number,
                        perforation = parsed$perforation,
                        watermark = parsed$watermark
                      )

                      cat("      AI data prepared:\n")
                      cat("         - Title:", substr(ai_data$title, 1, 50), "...\n")
                      cat("         - Description length:", nchar(ai_data$description), "chars\n")
                      cat("         - Grade:", ai_data$condition, "\n")
                      cat("         - Recommended Price:", ai_data$price, "\n")
                      cat("         - Model:", ai_data$model, "\n")
                      cat("         - Year:", if(is.null(parsed$year)) "NULL" else parsed$year, "\n")
                      cat("         - Country:", if(is.null(parsed$country)) "NULL" else parsed$country, "\n")
                      cat("         - Denomination:", if(is.null(parsed$denomination)) "NULL" else parsed$denomination, "\n")
                      cat("         - Scott Number:", if(is.null(parsed$scott_number)) "NULL" else parsed$scott_number, "\n")
                      cat("         - Perforation:", if(is.null(parsed$perforation)) "NULL" else parsed$perforation, "\n")
                      cat("         - Watermark:", if(is.null(parsed$watermark)) "NULL" else parsed$watermark, "\n")

                      cat("   Step 5: Calling save_stamp_processing()\n")
                      save_success <- save_stamp_processing(
                        stamp_id = stamp_id,  # Use stamp_id from stamps query
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
                        cat("   ✅ AI data saved to card_processing (stamp_id:", stamp_id, ")\n")

                        # Verify the save by reading back
                        cat("   Step 6: Verifying save by reading back from database\n")
                        verify <- find_stamp_processing(image_hash, image_type)
                        if (!is.null(verify)) {
                          cat("      Verification successful:\n")
                          cat("         - ai_title:", if(is.null(verify$ai_title)) "NULL" else substr(verify$ai_title, 1, 50), "\n")
                          cat("         - ai_price:", if(is.null(verify$ai_price)) "NULL" else verify$ai_price, "\n")
                          cat("         - ai_condition:", if(is.null(verify$ai_condition)) "NULL" else verify$ai_condition, "\n")
                          cat("         - ai_model:", if(is.null(verify$ai_model)) "NULL" else verify$ai_model, "\n")
                          cat("         - ai_year:", if(is.null(verify$ai_year)) "NULL" else verify$ai_year, "\n")
                          cat("         - ai_era:", if(is.null(verify$ai_era)) "NULL" else verify$ai_era, "\n")
                          cat("         - ai_city:", if(is.null(verify$ai_city)) "NULL" else verify$ai_city, "\n")
                          cat("         - ai_country:", if(is.null(verify$ai_country)) "NULL" else verify$ai_country, "\n")
                        } else {
                          cat("      ⚠️ Verification failed - could not read back data\n")
                          cat("         This might be OK if it's the first save (no last_processed yet)\n")
                        }
                      } else {
                        cat("   ❌ save_stamp_processing() returned FALSE\n")
                      }
                    } else {
                      cat("   ❌ No card found in stamps table\n")
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
                
                # Build success message with token usage
                success_msg <- sprintf("Extraction complete! Price: €%.2f", parsed$price)
                if (!is.null(result$usage)) {
                  total_tokens <- result$usage$input_tokens + result$usage$output_tokens
                  success_msg <- sprintf("Extraction complete! Price: €%.2f (%d tokens)", parsed$price, total_tokens)
                }

                # Close notification with success message
                removeNotification(notification_id)
                showNotification(
                  success_msg,
                  duration = 5,
                  type = "message"
                )

                # Show success in UI
                output[[paste0("ai_status_", i)]] <- renderUI({
                  div(
                    style = "padding: 12px; background: #e8f5e9; border-left: 4px solid #4caf50; margin-top: 10px;",
                    icon("check-circle", style = "color: #2e7d32;"),
                    paste("✅", success_msg)
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

                # Close notification with error
                removeNotification(notification_id)
                showNotification(
                  paste("Error:", result$error),
                  duration = NULL,  # Keep error visible
                  type = "error"
                )

                output[[paste0("ai_status_", i)]] <- renderUI({
                  div(
                    style = "padding: 12px; background: #ffebee; border-left: 4px solid #f44336; margin-top: 10px;",
                    icon("exclamation-circle", style = "color: #c62828;"),
                    paste("❌ Error:", result$error)
                  )
                })
              }
          }, error = function(e) {
            cat("   💥 Unexpected error:", e$message, "\n")

            # Close notification with error
            removeNotification(notification_id)
            showNotification(
              paste("Unexpected error:", e$message),
              duration = NULL,
              type = "error"
            )

            output[[paste0("ai_status_", i)]] <- renderUI({
              div(
                style = "padding: 12px; background: #ffebee; border-left: 4px solid #f44336; margin-top: 10px;",
                icon("exclamation-circle", style = "color: #c62828;"),
                paste("❌ Unexpected error:", e$message)
              )
            })
          }, finally = {
            isolate({ rv$ai_extracting <- FALSE })
            cat("   🏁 AI extraction complete\n\n")
          })
        })
      })
    })

    # Send to eBay Handlers - Show confirmation modal
    observe({
      req(image_paths())
      paths <- image_paths()
      sorted_paths <- sort_images_lot_first(paths)

      lapply(seq_along(sorted_paths), function(i) {
        # Observer: Set default schedule time when accordion opens
        observe({
          # Only run once when image paths are available
          req(image_paths())
          req(length(image_paths()) >= i)

          # Calculate next 10:00 AM Pacific
          next_10am <- calculate_next_10am_pacific()

          # Convert to Pacific timezone for UI display
          pacific_time <- as.POSIXct(
            format(next_10am, tz = "America/Los_Angeles"),
            tz = "America/Los_Angeles"
          )

          # Update date input
          updateDateInput(
            session,
            paste0("schedule_date_", i),
            value = as.Date(pacific_time)
          )

          # Update hour select (should be "10")
          updateSelectInput(
            session,
            paste0("schedule_hour_", i),
            selected = sprintf("%02d", as.integer(format(pacific_time, "%H")))
          )

          # Update minute select (should be "00")
          updateSelectInput(
            session,
            paste0("schedule_minute_", i),
            selected = sprintf("%02d", as.integer(format(pacific_time, "%M")))
          )

          cat("   ✅ Default schedule set for image", i, ":",
              format(pacific_time, "%Y-%m-%d %H:%M %Z"), "\n")
        })

        # Dynamic schedule display: Show Pacific and Romania times
        output[[paste0("schedule_display_", i)]] <- renderUI({
          # Require schedule inputs to be set
          req(input[[paste0("schedule_date_", i)]])
          req(input[[paste0("schedule_hour_", i)]])
          req(input[[paste0("schedule_minute_", i)]])

          # Build Pacific time from user inputs
          pacific_str <- sprintf(
            "%s %s:%s:00",
            input[[paste0("schedule_date_", i)]],
            input[[paste0("schedule_hour_", i)]],
            input[[paste0("schedule_minute_", i)]]
          )

          # Parse as Pacific time
          pacific_time <- as.POSIXct(
            pacific_str,
            tz = "America/Los_Angeles",
            format = "%Y-%m-%d %H:%M:%S"
          )

          # Convert to UTC
          utc_time <- as.POSIXct(format(pacific_time, tz = "UTC"), tz = "UTC")

          # Convert to Romania time
          romania_time <- as.POSIXct(
            format(utc_time, tz = "Europe/Bucharest"),
            tz = "Europe/Bucharest"
          )

          # Render display
          div(
            style = "margin-top: 10px; font-size: 0.85em; padding: 8px; background-color: #d1ecf1; border-radius: 4px;",
            strong("Scheduled Start:"),
            tags$br(),
            sprintf("🇺🇸 Pacific: %s", format(pacific_time, "%a %b %d, %I:%M %p %Z")),
            tags$br(),
            sprintf("🇷🇴 Romania: %s", format(romania_time, "%a %b %d, %H:%M %Z")),
            tags$br(),
            tags$small(
              style = "color: #856404;",
              "⚠️ Listing will NOT be visible until scheduled time"
            )
          )
        })

        observeEvent(input[[paste0("send_to_ebay_", i)]], ignoreNULL = TRUE, ignoreInit = TRUE, {
          # Get form inputs
          title <- input[[paste0("item_title_", i)]]
          description <- input[[paste0("item_description_", i)]]
          price <- input[[paste0("starting_price_", i)]]
          condition <- input[[paste0("condition_", i)]]
          listing_type <- input[[paste0("listing_type_", i)]] %||% "fixed_price"

          # Get auction-specific inputs
          duration <- if (listing_type == "auction") {
            input[[paste0("auction_duration_", i)]] %||% "Days_7"
          } else {
            "GTC"
          }

          buy_it_now <- if (listing_type == "auction") {
            input[[paste0("buy_it_now_price_", i)]]
          } else {
            NULL
          }

          reserve <- if (listing_type == "auction") {
            input[[paste0("reserve_price_", i)]]
          } else {
            NULL
          }

          # Determine if scheduled or immediate
          list_immediately <- input[[paste0("list_immediately_", i)]]
          schedule_time_utc <- NULL

          if (!isTRUE(list_immediately)) {
            # User wants scheduled listing - build time from inputs
            schedule_date <- input[[paste0("schedule_date_", i)]]
            schedule_hour <- input[[paste0("schedule_hour_", i)]]
            schedule_minute <- input[[paste0("schedule_minute_", i)]]

            # Build Pacific time string
            pacific_str <- sprintf(
              "%s %s:%s:00",
              schedule_date, schedule_hour, schedule_minute
            )

            # Parse as Pacific time
            pacific_time <- as.POSIXct(
              pacific_str,
              tz = "America/Los_Angeles",
              format = "%Y-%m-%d %H:%M:%S"
            )

            # Convert to UTC for API/database
            schedule_time_utc <- as.POSIXct(format(pacific_time, tz = "UTC"), tz = "UTC")

            # Validate schedule time
            validation <- validate_schedule_time(schedule_time_utc)
            if (!validation$valid) {
              showNotification(validation$error, type = "error")
              return()
            }

            cat("   📅 Scheduled listing:\n")
            cat("      Pacific:", format(pacific_time, "%Y-%m-%d %H:%M %Z"), "\n")
            cat("      UTC:", format(schedule_time_utc, "%Y-%m-%d %H:%M:%S"), "\n")
          } else {
            cat("   ⚡ Immediate listing (no schedule)\n")
          }

          # Validate inputs
          if (is.null(title) || trimws(title) == "") {
            showNotification("Please enter a title", type = "error")
            return()
          }

          if (is.null(description) || trimws(description) == "") {
            showNotification("Please enter a description", type = "error")
            return()
          }

          if (is.null(price) || is.na(price) || price <= 0) {
            showNotification("Please enter a valid price", type = "error")
            return()
          }

          # Validate auction-specific requirements
          if (listing_type == "auction") {
            # Check eBay minimum
            if (price < 0.99) {
              showNotification("Starting bid must be at least €0.99 for auctions", type = "error")
              return()
            }

            # Validate Buy It Now if specified
            if (!is.null(buy_it_now) && !is.na(buy_it_now) && buy_it_now > 0) {
              if (buy_it_now < price * 1.3) {
                showNotification(
                  sprintf("Buy It Now price (€%.2f) must be at least 30%% higher than starting bid (€%.2f)",
                          buy_it_now, price),
                  type = "error"
                )
                return()
              }
            }

            # Validate Reserve if specified
            if (!is.null(reserve) && !is.na(reserve) && reserve > 0) {
              if (reserve < price) {
                showNotification(
                  sprintf("Reserve price (€%.2f) must be >= starting bid (€%.2f)", reserve, price),
                  type = "error"
                )
                return()
              }
            }
          }

          # Validate eBay category selection
          ebay_region <- input[[paste0("ebay_region_", i)]]
          ebay_country_id <- input[[paste0("ebay_country_", i)]]

          # Check if category is selected
          if (is.null(ebay_region) || ebay_region == "") {
            showNotification("Please select an eBay region category", type = "error")
            return()
          }

          # Determine final category ID and label
          category_id <- NULL
          category_label <- "Unknown Category"

          # Special case: "Other Stamps" is a leaf at region level
          if (ebay_region == "OT") {
            region_data <- STAMP_CATEGORIES[[ebay_region]]
            if (!is.null(region_data$region_id)) {
              category_id <- region_data$region_id
              category_label <- region_data$label
            }
          } else {
            # Normal case: need country selection
            if (is.null(ebay_country_id) || ebay_country_id == "") {
              showNotification("Please select an eBay country/subcategory", type = "error")
              return()
            }

            category_id <- as.numeric(ebay_country_id)
            region_data <- STAMP_CATEGORIES[[ebay_region]]
            country_name <- names(region_data$countries)[region_data$countries == category_id]
            if (length(country_name) > 0) {
              category_label <- paste0(region_data$label, " > ", country_name)
            }
          }

          # Final validation: must have a valid category ID
          if (is.null(category_id) || is.na(category_id)) {
            showNotification("Invalid category selection. Please select both region and country/subcategory.", type = "error")
            return()
          }

          cat("   ✅ Category validated:", category_label, "(", category_id, ")\n")

          # Show confirmation modal with auction details and selected category
          show_ebay_confirmation_modal(i, title, price, condition, category_label,
                                       listing_type, duration, buy_it_now, reserve, schedule_time_utc)
        })
      })
    })

    # Confirm Send to eBay Handlers - Create eBay listing after confirmation
    observe({
      req(image_paths())
      paths <- image_paths()
      sorted_paths <- sort_images_lot_first(paths)

      # Get file paths - may be NULL for some image types
      file_paths <- if (!is.null(image_file_paths)) {
        image_file_paths()
      } else {
        NULL
      }

      # Sort file_paths to match sorted_paths order
      sorted_file_paths <- if (!is.null(file_paths)) {
        # Create a mapping from original paths to file paths
        path_to_file <- setNames(file_paths, paths)
        # Map sorted paths to file paths
        sapply(sorted_paths, function(p) path_to_file[[p]])
      } else {
        NULL
      }

      lapply(seq_along(sorted_paths), function(i) {
        button_id <- paste0("confirm_send_to_ebay_", i)

        observeEvent(input[[button_id]], ignoreNULL = TRUE, ignoreInit = TRUE, {
          # Close the modal
          removeModal()

          # Get form inputs
          title <- input[[paste0("item_title_", i)]]
          description <- input[[paste0("item_description_", i)]]
          price <- input[[paste0("starting_price_", i)]]
          condition <- input[[paste0("condition_", i)]]
          listing_type <- input[[paste0("listing_type_", i)]] %||% "fixed_price"

          # Get metadata inputs
          year <- input[[paste0("year_", i)]]
          denomination <- input[[paste0("denomination_", i)]]
          scott_number <- input[[paste0("scott_number_", i)]]
          country <- input[[paste0("country_", i)]]
          perforation <- input[[paste0("perforation_", i)]]
          watermark <- input[[paste0("watermark_", i)]]

          # Get auction-specific inputs
          duration <- if (listing_type == "auction") {
            input[[paste0("auction_duration_", i)]] %||% "Days_7"
          } else {
            "GTC"
          }

          buy_it_now <- if (listing_type == "auction") {
            bin <- input[[paste0("buy_it_now_price_", i)]]
            if (!is.null(bin) && !is.na(bin) && bin > 0) bin else NULL
          } else {
            NULL
          }

          reserve <- if (listing_type == "auction") {
            res <- input[[paste0("reserve_price_", i)]]
            if (!is.null(res) && !is.na(res) && res > 0) res else NULL
          } else {
            NULL
          }

          # Rebuild schedule time (same logic as send_to_ebay observer)
          list_immediately <- input[[paste0("list_immediately_", i)]]
          schedule_time_utc <- NULL

          if (!isTRUE(list_immediately)) {
            schedule_date <- input[[paste0("schedule_date_", i)]]
            schedule_hour <- input[[paste0("schedule_hour_", i)]]
            schedule_minute <- input[[paste0("schedule_minute_", i)]]

            pacific_str <- sprintf("%s %s:%s:00", schedule_date, schedule_hour, schedule_minute)
            pacific_time <- as.POSIXct(pacific_str, tz = "America/Los_Angeles", format = "%Y-%m-%d %H:%M:%S")
            schedule_time_utc <- as.POSIXct(format(pacific_time, tz = "UTC"), tz = "UTC")

            cat("   📅 Confirmed scheduled listing:", format(schedule_time_utc, "%Y-%m-%d %H:%M:%S UTC"), "\n")
          }

          # Get eBay category from user selection
          ebay_region <- input[[paste0("ebay_region_", i)]]
          ebay_country_id <- input[[paste0("ebay_country_", i)]]

          # Determine category ID (same logic as validation)
          category_id <- NULL
          if (ebay_region == "OT") {
            region_data <- STAMP_CATEGORIES[[ebay_region]]
            category_id <- region_data$region_id
          } else if (!is.null(ebay_country_id) && ebay_country_id != "") {
            category_id <- as.numeric(ebay_country_id)
          }

          if (is.null(category_id) || is.na(category_id)) {
            showNotification("Invalid category selection - cannot proceed", type = "error")
            return()
          }

          cat("   📂 Using eBay category ID:", category_id, "\n")

          # Check if eBay API is available
          api <- ebay_api()

          if (is.null(api)) {
            showNotification("Please authenticate with eBay first", type = "error")
            return()
          }

          # Get active eBay account
          if (is.null(ebay_account_manager)) {
            showNotification("eBay account manager not available", type = "error")
            return()
          }

          active_account <- ebay_account_manager$get_active_account()

          if (is.null(active_account)) {
            showNotification("No active eBay account found", type = "error")
            return()
          }

          # Create progress bar
          progress <- shiny::Progress$new()
          on.exit(progress$close(), add = TRUE)
          progress$set(message = "Starting...", value = 0)

          # Mark as pending
          isolate({ rv$pending_images <- c(rv$pending_images, paths[i]) })

          # Create AI data structure
          ai_data <- list(
            title = title,
            description = description,
            price = price,
            condition = condition,
            year = year,
            denomination = denomination,
            scott_number = scott_number,
            country = country,
            perforation = perforation,
            watermark = watermark
          )

          # Get image file path (using sorted arrays)
          image_file <- if (!is.null(sorted_file_paths) && i <= length(sorted_file_paths)) {
            sorted_file_paths[i]
          } else {
            # Fallback to web path conversion for lot images
            convert_web_path_to_file_path(sorted_paths[i])
          }

          # Call listing creation function with progress callback
          tryCatch({
            result <- create_ebay_listing_from_card(
              card_id = paste0("STAMP_", i, "_", format(Sys.time(), "%Y%m%d_%H%M%S")),
              ai_data = ai_data,
              ebay_api = api,
              session_id = "manual_export",
              image_url = image_file,
              ebay_user_id = active_account$user_id,
              ebay_username = active_account$username,
              listing_type = listing_type,
              listing_duration = duration,
              buy_it_now_price = buy_it_now,
              reserve_price = reserve,
              schedule_time_utc = schedule_time_utc,
              is_stamp = TRUE,  # Mark as stamp listing
              category_id = category_id,  # Use selected stamp category
              sku_prefix = "STAMP",  # Use STAMP- prefix for SKU
              progress_callback = function(msg, val) {
                progress$set(message = msg, value = val)
              }
            )

            # Update status based on result
            isolate({
              rv$pending_images <- setdiff(rv$pending_images, paths[i])

              if (result$success) {
                rv$sent_images <- c(rv$sent_images, paths[i])
                showNotification(
                  ui = div(
                    style = "font-size: 14px;",
                    tags$strong("✅ Successfully listed on eBay!"),
                    tags$br(),
                    tags$span("Item ID: ", tags$code(result$item_id)),
                    tags$br(),
                    tags$a(
                      href = result$listing_url,
                      target = "_blank",
                      style = "color: #0064d2; text-decoration: underline; word-break: break-all;",
                      result$listing_url
                    )
                  ),
                  type = "message",
                  duration = NULL,  # Stay until manually closed
                  closeButton = TRUE
                )
              } else {
                rv$failed_images <- c(rv$failed_images, paths[i])
                showNotification(
                  ui = div(
                    style = "font-size: 14px;",
                    tags$strong("❌ Failed to list on eBay"),
                    tags$br(),
                    tags$span("Error: ", result$error)
                  ),
                  type = "error",
                  duration = NULL,  # Stay until manually closed
                  closeButton = TRUE
                )
              }
            })

          }, error = function(e) {
            isolate({
              rv$pending_images <- setdiff(rv$pending_images, paths[i])
              rv$failed_images <- c(rv$failed_images, paths[i])
            })
            showNotification(
              ui = div(
                style = "font-size: 14px;",
                tags$strong("❌ Unexpected error"),
                tags$br(),
                tags$span("Error: ", e$message)
              ),
              type = "error",
              duration = NULL,  # Stay until manually closed
              closeButton = TRUE
            )
          })
        })
      })
    })

    # Image Enlargement Handlers - Show modal with full-size image
    observe({
      req(image_paths())
      paths <- image_paths()
      sorted_paths <- sort_images_lot_first(paths)

      lapply(seq_along(sorted_paths), function(i) {
        observeEvent(input[[paste0("enlarge_img_", i)]], ignoreNULL = TRUE, ignoreInit = TRUE, {
          showModal(modalDialog(
            title = paste0(tools::toTitleCase(image_type), " Image ", i),
            tags$img(
              src = sorted_paths[i],
              style = "width: 100%; height: auto; max-height: 80vh; object-fit: contain;"
            ),
            easyClose = TRUE,
            footer = modalButton("Close"),
            size = "l"
          ))
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
