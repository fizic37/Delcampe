#' Delcampe Export UI Function
#'
#' @description A shiny Module for handling Delcampe export actions.
#' Provides UI for sending processed images to Delcampe with AI extraction support.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @export
#'
#' @importFrom shiny NS tagList
mod_delcampe_export_ui <- function(id) {
  ns <- NS(id)
  tagList(
    # Status display area
    uiOutput(ns("export_status_display")),
    
    # Export controls
    uiOutput(ns("export_controls"))
  )
}

#' Delcampe Export Server Functions
#'
#' @param image_paths Reactive containing vector of image paths
#' @param image_type Character string ("lot" or "combined") to distinguish image types
#'
#' @export
mod_delcampe_export_server <- function(id, image_paths = reactive(NULL), image_type = "combined") {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # Reactive values to track export status
    rv <- reactiveValues(
      sent_images = character(0),      # Vector of image paths that have been sent
      pending_images = character(0),   # Vector of image paths currently being sent
      failed_images = character(0),    # Vector of image paths that failed to send
      current_image_path = NULL,       # Currently selected image for modal
      current_image_index = NULL,      # Current image index for display
      ai_extracting = FALSE,           # Whether AI extraction is in progress
      ai_result = NULL                 # Latest AI extraction result
    )
    
    # Export status display
    output$export_status_display <- renderUI({
      paths <- image_paths()
      if (is.null(paths) || length(paths) == 0) {
        return(div(
          style = "text-align: center; color: #aaa; padding: 20px;",
          icon("upload", style = "font-size: 24px; margin-bottom: 8px;"),
          p("No images available for export", style = "margin: 0; font-size: 12px;")
        ))
      }
      
      sent_count <- length(rv$sent_images)
      total_count <- length(paths)
      pending_count <- length(rv$pending_images)
      failed_count <- length(rv$failed_images)
      
      div(
        style = "padding: 10px; background-color: #f8f9fa; border-radius: 5px; margin-bottom: 15px;",
        div(
          style = "display: flex; justify-content: space-between; align-items: center;",
          div(
            h6(paste(total_count, image_type, "images"), style = "margin: 0; color: #495057;"),
            p(paste("Sent:", sent_count, "| Pending:", pending_count, "| Failed:", failed_count), 
              style = "margin: 0; font-size: 11px; color: #6c757d;")
          ),
          if (total_count > 0) {
            actionButton(
              inputId = ns("send_all"),
              label = "Send All",
              icon = icon("paper-plane"),
              class = "btn-primary btn-sm",
              disabled = pending_count > 0
            )
          }
        )
      )
    })
    
    # Export controls - individual image buttons
    output$export_controls <- renderUI({
      paths <- image_paths()
      if (is.null(paths) || length(paths) == 0) {
        return(NULL)
      }
      
      image_controls <- lapply(seq_along(paths), function(i) {
        image_path <- paths[i]
        button_id <- paste0("send_btn_", i)
        
        # Determine button state
        button_class <- "btn-outline-primary"
        button_label <- "Send to Delcampe"
        button_icon <- icon("paper-plane")
        button_disabled <- FALSE
        
        if (image_path %in% rv$sent_images) {
          button_class <- "btn-success"
          button_label <- "Sent ✓"
          button_icon <- icon("check")
          button_disabled <- TRUE
        } else if (image_path %in% rv$pending_images) {
          button_class <- "btn-warning"
          button_label <- "Sending..."
          button_icon <- icon("spinner", class = "fa-spin")
          button_disabled <- TRUE
        } else if (image_path %in% rv$failed_images) {
          button_class <- "btn-danger"
          button_label <- "Failed - Retry"
          button_icon <- icon("exclamation-triangle")
        }
        
        div(
          style = "border: 1px solid #ddd; border-radius: 8px; padding: 12px; background-color: white; margin-bottom: 12px;",
          div(
            style = "display: flex; align-items: center; gap: 15px;",
            # Image thumbnail
            div(
              style = "flex: 0 0 100px;",
              tags$img(
                src = image_path,
                style = "width: 100px; height: 75px; object-fit: contain; border-radius: 4px; border: 1px solid #eee; cursor: pointer;",
                onclick = paste0("Shiny.setInputValue('", ns("preview_image"), "', {path: '", image_path, "', index: ", i, "}, {priority: 'event'});")
              )
            ),
            # Image info
            div(
              style = "flex: 1;",
              h6(paste(tools::toTitleCase(image_type), i), style = "margin: 0 0 5px 0; font-size: 14px; color: #495057;"),
              p("Click image to preview", style = "margin: 0; font-size: 11px; color: #6c757d;")
            ),
            # Action button
            div(
              style = "flex: 0 0 auto;",
              actionButton(
                inputId = ns(button_id),
                label = button_label,
                icon = button_icon,
                class = paste("btn-sm", button_class),
                disabled = button_disabled
              )
            )
          )
        )
      })
      
      do.call(tagList, image_controls)
    })
    
    # Handle individual send buttons
    observe({
      paths <- image_paths()
      if (is.null(paths) || length(paths) == 0) return()
      
      lapply(seq_along(paths), function(i) {
        button_id <- paste0("send_btn_", i)
        
        observeEvent(input[[button_id]], {
          image_path <- paths[i]
          
          # Show send confirmation modal with AI extraction
          show_send_modal(image_path, i)
        }, ignoreInit = TRUE)
      })
    })
    
    # Handle send all button
    observeEvent(input$send_all, {
      paths <- image_paths()
      if (is.null(paths) || length(paths) == 0) return()
      
      # Send all images that haven't been sent yet
      unsent_paths <- setdiff(paths, c(rv$sent_images, rv$pending_images))
      
      if (length(unsent_paths) > 0) {
        showModal(modalDialog(
          title = "Confirm Send All",
          paste("Send", length(unsent_paths), "images to Delcampe?"),
          footer = tagList(
            modalButton("Cancel"),
            actionButton(ns("confirm_send_all"), "Send All", class = "btn-primary")
          )
        ))
      }
    })
    
    # Handle confirm send all
    observeEvent(input$confirm_send_all, {
      paths <- image_paths()
      unsent_paths <- setdiff(paths, c(rv$sent_images, rv$pending_images))
      
      # Add to pending
      rv$pending_images <- c(rv$pending_images, unsent_paths)
      
      # Simulate sending process (replace with actual Delcampe API calls)
      lapply(unsent_paths, function(path) {
        # Simulate delay
        later::later(function() {
          # Remove from pending
          rv$pending_images <- setdiff(rv$pending_images, path)
          
          # Simulate success/failure (90% success rate)
          if (runif(1) < 0.9) {
            rv$sent_images <- c(rv$sent_images, path)
            showNotification(paste("Successfully sent", basename(path)), type = "success")
          } else {
            rv$failed_images <- c(rv$failed_images, path)
            showNotification(paste("Failed to send", basename(path)), type = "error")
          }
        }, delay = runif(1, 1, 3))
      })
      
      removeModal()
      showNotification("Sending images...", type = "message")
    })
    
    # Handle image preview
    observeEvent(input$preview_image, {
      image_data <- input$preview_image
      rv$current_image_path <- image_data$path
      rv$current_image_index <- image_data$index
      
      showModal(modalDialog(
        title = paste("Preview -", tools::toTitleCase(image_type), image_data$index),
        size = "l",
        
        div(
          style = "text-align: center;",
          tags$img(
            src = image_data$path,
            style = "max-width: 100%; max-height: 500px; object-fit: contain;"
          )
        ),
        
        footer = tagList(
          modalButton("Close"),
          actionButton(
            ns("send_from_modal"),
            "Send to Delcampe",
            class = "btn-primary",
            icon = icon("paper-plane")
          )
        )
      ))
    })
    
    # Handle send from modal
    observeEvent(input$send_from_modal, {
      if (!is.null(rv$current_image_path)) {
        image_path <- rv$current_image_path
        
        # Add to pending
        rv$pending_images <- c(rv$pending_images, image_path)
        
        # Simulate sending (replace with actual implementation)
        later::later(function() {
          rv$pending_images <- setdiff(rv$pending_images, image_path)
          
          if (runif(1) < 0.9) {
            rv$sent_images <- c(rv$sent_images, image_path)
            showNotification("Successfully sent to Delcampe!", type = "success")
          } else {
            rv$failed_images <- c(rv$failed_images, image_path)
            showNotification("Failed to send to Delcampe", type = "error")
          }
        }, delay = 2)
        
        removeModal()
        showNotification("Sending to Delcampe...", type = "message")
      }
    })
    
    # Show send confirmation modal with AI extraction
    show_send_modal <- function(image_path, image_index) {
      rv$current_image_path <- image_path
      rv$current_image_index <- image_index
      rv$ai_result <- NULL
      
      showModal(modalDialog(
        title = paste("Send to Delcampe -", tools::toTitleCase(image_type), image_index),
        size = "xl",
        
        fluidRow(
          # Left column - Image preview
          column(
            width = 6,
            div(
              style = "text-align: center; border: 1px solid #ddd; border-radius: 8px; padding: 15px;",
              h5("Image Preview", style = "margin-top: 0;"),
              tags$img(
                src = image_path,
                style = "max-width: 100%; max-height: 400px; object-fit: contain; border-radius: 4px;"
              )
            )
          ),
          
          # Right column - AI extraction and form
          column(
            width = 6,
            div(
              style = "border: 1px solid #ddd; border-radius: 8px; padding: 15px;",
              h5("AI Description Extraction", style = "margin-top: 0;"),
              
              div(
                style = "margin-bottom: 15px;",
                actionButton(
                  ns("extract_ai_description"),
                  "Extract Description with AI",
                  icon = icon("magic"),
                  class = "btn-info btn-sm"
                )
              ),
              
              # AI extraction result
              uiOutput(ns("ai_extraction_result")),
              
              # Delcampe form fields
              div(
                style = "margin-top: 20px;",
                h6("Delcampe Details"),
                textInput(ns("item_title"), "Title:", placeholder = "Enter item title"),
                textAreaInput(ns("item_description"), "Description:", 
                             placeholder = "Enter item description", rows = 4),
                numericInput(ns("starting_price"), "Starting Price (€):", value = 1.0, min = 0.01, step = 0.01),
                selectInput(ns("condition"), "Condition:", 
                           choices = list("Mint" = "mint", "Used" = "used", "Fair" = "fair"))
              )
            )
          )
        ),
        
        footer = tagList(
          modalButton("Cancel"),
          actionButton(
            ns("confirm_send_to_delcampe"),
            "Send to Delcampe",
            class = "btn-success",
            icon = icon("paper-plane")
          )
        )
      ))
    }
    
    # AI extraction result display
    output$ai_extraction_result <- renderUI({
      if (rv$ai_extracting) {
        div(
          style = "padding: 10px; background-color: #e3f2fd; border-radius: 4px; margin: 10px 0;",
          div(
            style = "text-align: center;",
            icon("spinner", class = "fa-spin", style = "margin-right: 8px;"),
            "Extracting description with AI..."
          )
        )
      } else if (!is.null(rv$ai_result)) {
        div(
          style = "padding: 10px; background-color: #e8f5e8; border-radius: 4px; margin: 10px 0;",
          h6("AI Extracted Information:", style = "margin: 0 0 8px 0; color: #2e7d32;"),
          div(
            style = "background-color: white; padding: 8px; border-radius: 4px; font-size: 12px;",
            rv$ai_result$description
          ),
          if (!is.null(rv$ai_result$suggested_title)) {
            div(
              style = "margin-top: 8px;",
              strong("Suggested Title: "), rv$ai_result$suggested_title
            )
          },
          div(
            style = "margin-top: 8px;",
            actionButton(
              ns("apply_ai_result"),
              "Apply to Form",
              class = "btn-success btn-xs",
              icon = icon("check")
            )
          )
        )
      }
    })
    
    # Handle AI extraction
    observeEvent(input$extract_ai_description, {
      rv$ai_extracting <- TRUE
      
      # Simulate AI extraction (replace with actual AI API call)
      later::later(function() {
        rv$ai_extracting <- FALSE
        rv$ai_result <- list(
          description = paste("Vintage postal card featuring beautiful architectural details.",
                             "Good condition with minor signs of age.",
                             "Ideal for collectors of European postal history."),
          suggested_title = paste("Vintage European Postal Card -", tools::toTitleCase(image_type), rv$current_image_index)
        )
      }, delay = 2)
    })
    
    # Handle apply AI result
    observeEvent(input$apply_ai_result, {
      if (!is.null(rv$ai_result)) {
        updateTextInput(session, "item_title", value = rv$ai_result$suggested_title)
        updateTextAreaInput(session, "item_description", value = rv$ai_result$description)
      }
    })
    
    # Handle final send to Delcampe
    observeEvent(input$confirm_send_to_delcampe, {
      image_path <- rv$current_image_path
      
      # Validate form
      if (is.null(input$item_title) || input$item_title == "") {
        showNotification("Please enter a title", type = "error")
        return()
      }
      
      # Add to pending
      rv$pending_images <- c(rv$pending_images, image_path)
      
      # Simulate sending with form data (replace with actual Delcampe API)
      form_data <- list(
        title = input$item_title,
        description = input$item_description,
        price = input$starting_price,
        condition = input$condition
      )
      
      later::later(function() {
        rv$pending_images <- setdiff(rv$pending_images, image_path)
        
        if (runif(1) < 0.9) {
          rv$sent_images <- c(rv$sent_images, image_path)
          showNotification("Successfully sent to Delcampe!", type = "success")
        } else {
          rv$failed_images <- c(rv$failed_images, image_path)
          showNotification("Failed to send to Delcampe", type = "error")
        }
      }, delay = 3)
      
      removeModal()
      showNotification("Sending to Delcampe...", type = "message")
    })
    
    # Return module interface
    return(list(
      get_sent_count = reactive(length(rv$sent_images)),
      get_pending_count = reactive(length(rv$pending_images)),
      get_failed_count = reactive(length(rv$failed_images)),
      reset_status = function() {
        rv$sent_images <- character(0)
        rv$pending_images <- character(0)
        rv$failed_images <- character(0)
      }
    ))
  })
}
