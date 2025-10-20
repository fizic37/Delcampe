#' Delcampe UI Module
#'
#' @description UI management for Delcampe export functionality
#' Handles modal dialogs, image previews, zoom functionality, and form interfaces.
#' Works in coordination with mod_delcampe_export for complete export workflow.
#'
#' @param id,input,output,session Internal parameters for {shiny}
#'
#' @noRd
#' @importFrom shinyjs runjs
mod_delcampe_ui_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    `%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || all(is.na(a))) b else a

    # Reactive values for UI state
    rv <- reactiveValues(
      current_image_path = NULL,
      current_image_index = NULL,
      modal_form_values = list(),
      zoom_level = 1
    )

    # Show send confirmation modal with AI extraction integration
    show_send_modal <- function(image_path, image_index, ai_extraction_callback = NULL) {
      rv$current_image_path <- image_path
      rv$current_image_index <- image_index
      rv$zoom_level <- 1

      showModal(modalDialog(
        title = div(
          style = "display: flex; justify-content: space-between; align-items: center;",
          h4(paste("Send to Delcampe - Image", image_index), style = "margin: 0; color: #495057;"),
          div(
            actionButton(
              ns("enlarge_image"),
              icon("expand-arrows-alt"),
              class = "btn-outline-secondary btn-sm",
              style = "padding: 5px 8px;",
              title = "View larger image"
            )
          )
        ),
        size = "l",
        easyClose = TRUE,

        fluidRow(
          # Left column: Image preview and zoom controls
          column(
            width = 6,
            div(
              style = "text-align: center; margin-bottom: 15px;",
              div(
                style = "border: 2px solid #dee2e6; border-radius: 8px; padding: 10px; background-color: #f8f9fa; position: relative; overflow: hidden; height: 300px; display: flex; align-items: center; justify-content: center;",
                img(
                  id = ns("modal_image"),
                  src = image_path,
                  style = "max-width: 100%; max-height: 280px; border-radius: 4px; transition: transform 0.2s ease-in-out;",
                  alt = "Image preview"
                )
              ),

              # Zoom controls
              div(
                style = "margin-top: 10px;",
                actionButton(ns("zoom_in"), icon("search-plus"), class = "btn-outline-secondary btn-sm", title = "Zoom In"),
                actionButton(ns("zoom_out"), icon("search-minus"), class = "btn-outline-secondary btn-sm", title = "Zoom Out", style = "margin-left: 5px;"),
                actionButton(ns("zoom_reset"), icon("search"), class = "btn-outline-secondary btn-sm", title = "Reset Zoom", style = "margin-left: 5px;")
              )
            )
          ),

          # Right column: Form fields and AI extraction
          column(
            width = 6,
            # AI Extraction Section
            div(
              style = "margin-bottom: 20px; padding: 15px; background: linear-gradient(135deg, #e3f2fd 0%, #bbdefb 100%); border-radius: 8px; border-left: 4px solid #2196f3;",

              div(
                style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;",
                h6("AI Text Extraction", style = "margin: 0; color: #1565c0; font-weight: 600;"),
                uiOutput(ns("current_model_info"))
              ),

              div(
                style = "margin-bottom: 10px;",
                actionButton(
                  ns("extract_ai_btn"),
                  "Extract with AI",
                  icon = icon("magic"),
                  class = "btn-primary btn-sm",
                  style = "background-color: #2196f3; border-color: #2196f3; font-weight: 500;"
                )
              ),

              uiOutput(ns("ai_status_display"))
            ),

            # Category selection
            selectInput(
              ns("image_category"),
              "Category:",
              choices = list(
                "Individual Cards" = "individual_cards",
                "Card Lots" = "card_lots",
                "Sets/Collections" = "sets_collections",
                "Other" = "other"
              ),
              selected = "individual_cards",
              width = "100%"
            ),

            # Form fields
            textAreaInput(
              ns("image_title"),
              "Title:",
              placeholder = "Enter title or use AI extraction",
              height = "60px",
              width = "100%"
            ),

            textAreaInput(
              ns("image_description"),
              "Description:",
              placeholder = "Enter description or use AI extraction",
              height = "100px",
              width = "100%"
            ),

            numericInput(
              ns("image_price"),
              "Starting Price ($):",
              value = 1.00,
              min = 0.01,
              step = 0.10,
              width = "100%"
            )
          )
        ),

        footer = div(
          style = "display: flex; justify-content: space-between; align-items: center;",
          div(
            style = "font-size: 12px; color: #6c757d;",
            "Fill in details and click Send to Delcampe"
          ),
          div(
            actionButton(
              ns("confirm_send"),
              "Send to Delcampe",
              icon = icon("paper-plane"),
              class = "btn-success",
              style = "background-color: #52B788; border-color: #52B788; font-weight: 600; padding: 8px 20px;"
            ),
            modalButton("Cancel", class = "btn-outline-secondary", style = "margin-left: 10px;")
          )
        )
      ))
    }

    # Show enlarged image modal
    show_enlarged_modal <- function() {
      req(rv$current_image_path)

      # Store current form values before switching modals
      store_form_values()

      showModal(modalDialog(
        title = div(
          style = "display: flex; justify-content: space-between; align-items: center;",
          h4("Image Preview", style = "margin: 0; color: #495057;"),
          actionButton(
            ns("restore_send_modal"),
            "Back to Send Form",
            icon = icon("arrow-left"),
            class = "btn-outline-primary btn-sm"
          )
        ),
        size = "xl",
        easyClose = TRUE,

        div(
          style = "text-align: center; max-height: 80vh; overflow: auto;",
          img(
            id = ns("enlarged_image"),
            src = rv$current_image_path,
            style = "max-width: 100%; height: auto; border-radius: 4px; transition: transform 0.2s ease-in-out;",
            alt = "Enlarged image preview"
          )
        ),

        footer = div(
          style = "text-align: center;",
          actionButton(ns("zoom_in_large"), icon("search-plus"), class = "btn-outline-secondary", title = "Zoom In"),
          actionButton(ns("zoom_out_large"), icon("search-minus"), class = "btn-outline-secondary", title = "Zoom Out", style = "margin-left: 5px;"),
          actionButton(ns("zoom_reset_large"), icon("search"), class = "btn-outline-secondary", title = "Reset Zoom", style = "margin-left: 5px;"),
          modalButton("Close", class = "btn-outline-secondary", style = "margin-left: 15px;")
        )
      ))
    }

    # Store current form values
    store_form_values <- function() {
      rv$modal_form_values <- list(
        category = input$image_category,
        title = input$image_title,
        description = input$image_description,
        price = input$image_price
      )
    }

    # Restore form values when returning from enlarged view
    restore_form_values <- function() {
      if (length(rv$modal_form_values) > 0) {
        updateSelectInput(session, "image_category", selected = rv$modal_form_values$category)
        updateTextAreaInput(session, "image_title", value = rv$modal_form_values$title)
        updateTextAreaInput(session, "image_description", value = rv$modal_form_values$description)
        updateNumericInput(session, "image_price", value = rv$modal_form_values$price)
      }
    }

    # Handle image enlargement
    observeEvent(input$enlarge_image, {
      show_enlarged_modal()
    })

    # Handle restore send modal
    observeEvent(input$restore_send_modal, {
      req(rv$current_image_path, rv$current_image_index)
      removeModal()
      show_send_modal(rv$current_image_path, rv$current_image_index)
      # Restore form values after modal is shown
      later::later(function() {
        restore_form_values()
      }, delay = 0.1)
    })

    # Zoom functionality for modal images
    observeEvent(input$zoom_in, {
      new_zoom <- min(rv$zoom_level * 1.2, 5)
      rv$zoom_level <- new_zoom

      runjs(paste0("
        $('#", ns("modal_image"), "').css('transform', 'scale(", new_zoom, ")');
        $('#", ns("modal_image"), "').css('transition', 'transform 0.2s ease-in-out');
      "))
    })

    observeEvent(input$zoom_out, {
      new_zoom <- max(rv$zoom_level / 1.2, 0.5)
      rv$zoom_level <- new_zoom

      runjs(paste0("
        $('#", ns("modal_image"), "').css('transform', 'scale(", new_zoom, ")');
        $('#", ns("modal_image"), "').css('transition', 'transform 0.2s ease-in-out');
      "))
    })

    observeEvent(input$zoom_reset, {
      rv$zoom_level <- 1

      runjs(paste0("
        $('#", ns("modal_image"), "').css('transform', 'scale(1)');
        $('#", ns("modal_image"), "').css('transition', 'transform 0.2s ease-in-out');
      "))
    })

    # Zoom functionality for enlarged modal
    observeEvent(input$zoom_in_large, {
      new_zoom <- min(rv$zoom_level * 1.2, 5)
      rv$zoom_level <- new_zoom

      runjs(paste0("
        $('#", ns("enlarged_image"), "').css('transform', 'scale(", new_zoom, ")');
        $('#", ns("enlarged_image"), "').css('transition', 'transform 0.2s ease-in-out');
      "))
    })

    observeEvent(input$zoom_out_large, {
      new_zoom <- max(rv$zoom_level / 1.2, 0.5)
      rv$zoom_level <- new_zoom

      runjs(paste0("
        $('#", ns("enlarged_image"), "').css('transform', 'scale(", new_zoom, ")');
        $('#", ns("enlarged_image"), "').css('transition', 'transform 0.2s ease-in-out');
      "))
    })

    observeEvent(input$zoom_reset_large, {
      rv$zoom_level <- 1

      runjs(paste0("
        $('#", ns("enlarged_image"), "').css('transform', 'scale(1)');
        $('#", ns("enlarged_image"), "').css('transition', 'transform 0.2s ease-in-out');
      "))
    })

    # Display current AI model information
    output$current_model_info <- renderUI({
      config <- get_llm_config()
      model_names <- list(
        "claude-sonnet-4-20250514" = "Claude Sonnet 4",
        "gpt-4o" = "GPT-4o",
        "gpt-4o-mini" = "GPT-4o Mini",
        "gpt-4.1" = "GPT-4.1",
        "gpt-4.1-mini" = "GPT-4.1 Mini"
      )
      model_display <- model_names[[config$default_model]] %||% config$default_model

      span(
        paste0("Current: ", model_display, " | Temperature: ", config$temperature, " | Max Tokens: ", config$max_tokens),
        style = "font-style: italic; font-size: 11px;"
      )
    })

    # AI status display (placeholder - actual logic handled by AI extraction module)
    output$ai_status_display <- renderUI({
      div(
        style = "margin-top: 10px; padding: 8px; background-color: #f8f9fa; border: 1px solid #dee2e6; border-radius: 4px;",
        div(
          "AI extraction status will be displayed here",
          style = "color: #6c757d; font-size: 12px; font-style: italic;"
        )
      )
    })

    # Get current form values
    get_form_values <- function() {
      return(list(
        category = input$image_category,
        title = input$image_title,
        description = input$image_description,
        price = input$image_price
      ))
    }

    # Update form with AI extraction results
    update_form_with_ai_results <- function(result) {
      if (!is.null(result) && result$success) {
        updateTextAreaInput(session, "image_title", value = result$title)
        updateTextAreaInput(session, "image_description", value = result$description)
      }
    }

    # Return interface for parent modules
    return(list(
      show_send_modal = show_send_modal,
      show_enlarged_modal = show_enlarged_modal,
      get_form_values = reactive(get_form_values()),
      update_ai_results = update_form_with_ai_results,
      current_image = reactive(rv$current_image_path),
      current_index = reactive(rv$current_image_index),

      # Event handlers that parent can observe
      confirm_send_event = reactive(input$confirm_send),
      extract_ai_event = reactive(input$extract_ai_btn)
    ))
  })
}