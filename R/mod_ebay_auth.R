# eBay Authentication Module
# This module handles the OAuth flow for eBay API

#' eBay Authentication UI Module
#' @export
mod_ebay_auth_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    div(
      class = "ebay-auth-container",
      h3("eBay API Connection"),
      
      # Connection status
      uiOutput(ns("connection_status")),
      
      # Authentication buttons
      div(
        class = "auth-controls",
        actionButton(
          ns("check_connection"),
          "Check Connection",
          icon = icon("refresh"),
          class = "btn-info"
        ),
        actionButton(
          ns("authorize"),
          "Connect to eBay",
          icon = icon("link"),
          class = "btn-primary"
        ),
        actionButton(
          ns("disconnect"),
          "Disconnect",
          icon = icon("unlink"),
          class = "btn-warning"
        )
      ),
      
      # Authorization code input
      conditionalPanel(
        condition = paste0("input['", ns("show_code_input"), "'] == true"),
        div(
          class = "auth-code-input mt-3",
          h4("Step 2: Enter Authorization Code"),
          p("After authorizing in eBay, copy the authorization code from the URL and paste it here:"),
          textInput(
            ns("auth_code"),
            label = NULL,
            placeholder = "Paste authorization code here"
          ),
          actionButton(
            ns("submit_code"),
            "Submit Code",
            icon = icon("check"),
            class = "btn-success"
          )
        )
      ),
      
      # Hidden input to control conditional panel (using inline style instead of shinyjs)
      div(
        style = "display: none;",
        checkboxInput(ns("show_code_input"), "", value = FALSE)
      )
    )
  )
}

#' eBay Authentication Server Module
#' @export
mod_ebay_auth_server <- function(id, parent_session = NULL) {
  moduleServer(id, function(input, output, session) {
    
    # Initialize eBay API
    ebay_api <- reactiveVal(NULL)
    
    # Initialize API on startup
    observe({
      api <- init_ebay_api()
      ebay_api(api)
      
      # Check initial connection status
      update_connection_status()
    })
    
    # Update connection status UI
    update_connection_status <- function() {
      req(ebay_api())
      
      api <- ebay_api()
      is_connected <- api$oauth$is_authenticated()
      
      output$connection_status <- renderUI({
        if (is_connected) {
          div(
            class = "alert alert-success",
            icon("check-circle"),
            " Connected to eBay API (",
            api$config$environment,
            " environment)"
          )
        } else {
          div(
            class = "alert alert-warning",
            icon("exclamation-triangle"),
            " Not connected to eBay API"
          )
        }
      })
      
      # Note: shinyjs::toggleState is a legitimate shinyjs function
      # Could be replaced with conditionalPanel in UI, but this works fine
      if (requireNamespace("shinyjs", quietly = TRUE)) {
        shinyjs::toggleState("authorize", !is_connected)
        shinyjs::toggleState("disconnect", is_connected)
      }
    }
    
    # Check connection
    observeEvent(input$check_connection, {
      update_connection_status()
      
      api <- ebay_api()
      if (api$oauth$is_authenticated()) {
        showNotification(
          "Successfully connected to eBay API",
          type = "success"
        )
      } else {
        showNotification(
          "Not connected. Please authorize the application.",
          type = "warning"
        )
      }
    })
    
    # Start OAuth flow
    observeEvent(input$authorize, {
      req(ebay_api())
      
      api <- ebay_api()
      auth_url <- api$oauth$generate_auth_url()
      
      # Open authorization URL in browser
      browseURL(auth_url)

      # Show code input
      updateCheckboxInput(
        session = session,
        inputId = "show_code_input",
        value = TRUE
      )

      # Show simple notification instead of modal
      showNotification(
        "Browser opened for eBay authorization. After authorizing, paste the code below.",
        duration = 10,
        type = "message"
      )
    })
    
    # Submit authorization code
    observeEvent(input$submit_code, {
      req(input$auth_code, ebay_api())
      
      api <- ebay_api()
      
      withProgress(message = "Exchanging code for token...", {
        result <- api$oauth$get_user_token(input$auth_code)
        
        if (result$success) {
          showNotification(
            "Successfully connected to eBay!",
            type = "success"
          )

          # Hide code input
          updateCheckboxInput(
            session = session,
            inputId = "show_code_input",
            value = FALSE
          )
          
          # Clear the code input
          updateTextInput(session, "auth_code", value = "")
          
          # Update status
          update_connection_status()
          
        } else {
          showNotification(
            paste("Authentication failed:", result$error),
            type = "error"
          )
        }
      })
    })
    
    # Disconnect
    observeEvent(input$disconnect, {
      showModal(
        modalDialog(
          title = "Confirm Disconnection",
          "Are you sure you want to disconnect from eBay API?",
          footer = tagList(
            modalButton("Cancel"),
            actionButton(
              session$ns("confirm_disconnect"),
              "Disconnect",
              class = "btn-warning"
            )
          )
        )
      )
    })
    
    observeEvent(input$confirm_disconnect, {
      # Clear tokens
      if (file.exists("data/ebay_tokens.rds")) {
        file.remove("data/ebay_tokens.rds")
      }
      
      # Reinitialize API
      api <- init_ebay_api()
      ebay_api(api)
      
      update_connection_status()
      removeModal()
      
      showNotification(
        "Disconnected from eBay API",
        type = "info"
      )
    })
    
    # Return the API object for use in other modules
    return(ebay_api)
  })
}
