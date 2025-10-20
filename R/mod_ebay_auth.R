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
      
      # Account selector (shown when accounts exist)
      uiOutput(ns("account_selector")),
      
      # Authentication buttons
      div(
        class = "auth-controls mt-3",
        actionButton(
          ns("connect_new"),
          "Connect New Account",
          icon = icon("user-plus"),
          class = "btn-primary"
        ),
        actionButton(
          ns("disconnect"),
          "Disconnect Current",
          icon = icon("unlink"),
          class = "btn-warning"
        ),
        actionButton(
          ns("refresh_status"),
          "Refresh",
          icon = icon("sync"),
          class = "btn-info"
        )
      ),
      
      # Authorization code input (conditional)
      conditionalPanel(
        condition = paste0("input['", ns("show_code_input"), "'] == true"),
        div(
          class = "auth-code-input mt-3 p-3 border rounded bg-light",
          h4(icon("key"), " Step 2: Enter Authorization Code"),
          div(
            class = "alert alert-info",
            p(strong("After authorizing in eBay:")),
            tags$ol(
              tags$li("Look at the browser URL bar"),
              tags$li("Copy everything after ", tags$code("code="), " (the long encoded string)"),
              tags$li("Paste it below (with or without URL encoding)")
            ),
            p(
              class = "mb-0",
              strong("Example: "), tags$code("v%5E1.1%23i%5E1%23...")
            )
          ),
          textAreaInput(
            ns("auth_code"),
            label = "Authorization Code:",
            rows = 3,
            placeholder = "Paste the long code from the URL here..."
          ),
          actionButton(
            ns("submit_code"),
            "Submit Code & Connect",
            icon = icon("check"),
            class = "btn-success w-100"
          )
        )
      ),
      
      # Hidden input to control conditional panel
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
    
    # Initialize Account Manager
    account_manager <- EbayAccountManager$new()
    
    # Initialize eBay API
    ebay_api <- reactiveVal(NULL)
    
    # Initialize API on startup and load active account tokens
    observe({
      api <- init_ebay_api()
      
      # Load active account tokens if available
      active_account <- account_manager$get_active_account()
      if (!is.null(active_account)) {
        api$oauth$set_tokens(
          access_token = active_account$access_token,
          refresh_token = active_account$refresh_token,
          token_expiry = active_account$token_expiry
        )
      }
      
      ebay_api(api)
      
      # Update UI
      update_connection_status()
      update_account_selector()
    })
    
    # Update connection status UI
    update_connection_status <- function() {
      active_account <- account_manager$get_active_account()
      
      output$connection_status <- renderUI({
        if (!is.null(active_account)) {
          div(
            class = "alert alert-success",
            icon("check-circle"),
            strong(" Connected: "),
            active_account$username,
            " (",
            active_account$environment,
            " environment)"
          )
        } else {
          div(
            class = "alert alert-warning",
            icon("exclamation-triangle"),
            " No eBay accounts connected"
          )
        }
      })
    }
    
    # Update account selector dropdown
    update_account_selector <- function() {
      choices <- account_manager$get_account_choices()
      active_account <- account_manager$get_active_account()

      output$account_selector <- renderUI({
        if (!is.null(choices) && length(choices) > 0) {
          div(
            class = "account-selector mt-3",
            selectInput(
              session$ns("selected_account"),
              "Active Account:",
              choices = choices,
              selected = if (!is.null(active_account)) active_account$account_key else NULL,
              width = "100%"
            )
          )
        } else {
          NULL
        }
      })
    }
    
    # Handle account switching
    observeEvent(input$selected_account, {
      req(input$selected_account)

      # Prevent reactive loop on initialization
      active_account <- account_manager$get_active_account()
      if (!is.null(active_account) && input$selected_account == active_account$account_key) {
        return()
      }

      # Switch account
      success <- account_manager$set_active_account(input$selected_account)
      
      if (success) {
        # Load new account's tokens into API
        new_account <- account_manager$get_active_account()
        api <- ebay_api()
        api$oauth$set_tokens(
          access_token = new_account$access_token,
          refresh_token = new_account$refresh_token,
          token_expiry = new_account$token_expiry
        )
        ebay_api(api)
        
        # Update UI
        update_connection_status()
        
        showNotification(
          paste("Switched to:", new_account$username),
          type = "message"
        )
      } else {
        showNotification(
          "Failed to switch account",
          type = "error"
        )
      }
    })
    
    # Refresh status
    observeEvent(input$refresh_status, {
      update_connection_status()
      update_account_selector()
      
      active_account <- account_manager$get_active_account()
      if (!is.null(active_account)) {
        showNotification(
          paste("Active:", active_account$username),
          type = "message"
        )
      } else {
        showNotification(
          "No accounts connected",
          type = "warning"
        )
      }
    })
    
    # Start OAuth flow for new account
    observeEvent(input$connect_new, {
      api <- ebay_api()
      if (is.null(api)) {
        api <- init_ebay_api()
        ebay_api(api)
      }
      
      auth_url <- api$oauth$generate_auth_url()
      
      # Open authorization URL in browser
      browseURL(auth_url)

      # Show code input
      updateCheckboxInput(
        session = session,
        inputId = "show_code_input",
        value = TRUE
      )

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

      # Clean up the authorization code
      auth_code <- trimws(input$auth_code)

      # Try URL decoding in case user pasted encoded version
      auth_code_decoded <- tryCatch({
        URLdecode(auth_code)
      }, error = function(e) {
        auth_code
      })

      cat("\n=== SUBMITTING AUTHORIZATION CODE ===\n")
      cat("   Original length:", nchar(auth_code), "\n")
      cat("   Decoded length:", nchar(auth_code_decoded), "\n")

      withProgress(message = "Exchanging code for token...", {
        result <- api$oauth$get_user_token(auth_code_decoded)
        
        if (result$success) {
          # Get user info
          user_info <- api$oauth$get_user_info()
          
          if (user_info$success) {
            # Add account to manager
            account_key <- account_manager$add_account(
              user_id = user_info$user_id,
              username = user_info$username,
              environment = api$config$environment,
              access_token = api$oauth$get_access_token(),
              refresh_token = api$oauth$get_refresh_token(),
              token_expiry = api$oauth$get_token_expiry()
            )
            
            showNotification(
              paste("Successfully connected:", user_info$username),
              type = "message"
            )
            
            # Update UI
            update_connection_status()
            update_account_selector()
          } else {
            showNotification(
              paste("Failed to get user info:", user_info$error),
              type = "error"
            )
          }

          # Hide code input
          updateCheckboxInput(
            session = session,
            inputId = "show_code_input",
            value = FALSE
          )
          
          # Clear the code input
          updateTextAreaInput(session, "auth_code", value = "")
          
        } else {
          showNotification(
            paste("Authentication failed:", result$error),
            type = "error"
          )
        }
      })
    })
    
    # Disconnect current account
    observeEvent(input$disconnect, {
      active_account <- account_manager$get_active_account()
      
      if (is.null(active_account)) {
        showNotification(
          "No active account to disconnect",
          type = "warning"
        )
        return()
      }
      
      showModal(
        modalDialog(
          title = "Confirm Disconnection",
          paste("Are you sure you want to disconnect", active_account$username, "?"),
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
      active_account <- account_manager$get_active_account()
      
      if (!is.null(active_account)) {
        username <- active_account$username
        account_key <- active_account$account_key
        
        # Remove account
        success <- account_manager$remove_account(account_key)
        
        if (success) {
          # Check if there's a new active account
          new_active <- account_manager$get_active_account()
          
          if (!is.null(new_active)) {
            # Load new active account tokens
            api <- ebay_api()
            api$oauth$set_tokens(
              access_token = new_active$access_token,
              refresh_token = new_active$refresh_token,
              token_expiry = new_active$token_expiry
            )
            ebay_api(api)
          } else {
            # No accounts left, reinitialize empty API
            api <- init_ebay_api()
            ebay_api(api)
          }
          
          # Update UI
          update_connection_status()
          update_account_selector()
          
          showNotification(
            paste("Disconnected:", username),
            type = "message"
          )
        } else {
          showNotification(
            "Failed to disconnect account",
            type = "error"
          )
        }
      }
      
      removeModal()
    })
    
    # Return both API object and account manager for use in other modules
    return(list(
      api = ebay_api,
      account_manager = account_manager
    ))
  })
}
