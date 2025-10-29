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
      ),

      # Account Overview Accordion (shown when connected) - AT BOTTOM
      div(
        class = "mt-4",
        uiOutput(ns("account_overview_accordion"))
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
      update_account_overview()
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

    # Update account overview accordion
    update_account_overview <- function() {
      active_account <- account_manager$get_active_account()

      output$account_overview_accordion <- renderUI({
        if (!is.null(active_account)) {
          # Get token status
          token_status <- get_token_status(active_account$token_expiry)

          # Environment badge styling
          env_style <- if (active_account$environment == "production") {
            "background-color: #d4edda; color: #155724; padding: 4px 8px; border-radius: 4px; font-weight: bold;"
          } else {
            "background-color: #fff3cd; color: #856404; padding: 4px 8px; border-radius: 4px; font-weight: bold;"
          }

          # Token status styling
          token_style <- switch(
            token_status$status,
            "healthy" = "color: green; font-weight: bold;",
            "warning" = "color: orange; font-weight: bold;",
            "critical" = "color: red; font-weight: bold;",
            "expired" = "color: red; font-weight: bold;",
            "color: gray;"
          )

          bslib::accordion(
            id = session$ns("account_overview"),
            open = FALSE,  # Collapsed by default
            bslib::accordion_panel(
              title = HTML(paste0(
                "<span style='font-weight: 600;'>Account Overview</span>",
                " <span style='color: #666; font-size: 0.9em;'>(",
                active_account$username,
                ")</span>"
              )),
              icon = icon("user-circle"),
              div(
                style = "padding: 10px;",
                # Username row
                div(
                  style = "margin-bottom: 12px; padding: 8px; background-color: #f8f9fa; border-radius: 4px;",
                  div(
                    style = "display: flex; align-items: center; gap: 10px;",
                    icon("user", style = "color: #52B788; font-size: 18px;"),
                    div(
                      div(style = "font-size: 11px; color: #666; text-transform: uppercase;", "Username"),
                      div(style = "font-size: 15px; font-weight: 600;", active_account$username)
                    )
                  )
                ),
                # Environment row
                div(
                  style = "margin-bottom: 12px; padding: 8px; background-color: #f8f9fa; border-radius: 4px;",
                  div(
                    style = "display: flex; align-items: center; gap: 10px;",
                    icon("globe", style = "color: #52B788; font-size: 18px;"),
                    div(
                      div(style = "font-size: 11px; color: #666; text-transform: uppercase;", "Environment"),
                      div(
                        style = "font-size: 15px; margin-top: 2px;",
                        tags$span(
                          style = env_style,
                          toupper(active_account$environment)
                        )
                      )
                    )
                  )
                ),
                # Token status row
                div(
                  style = "margin-bottom: 0; padding: 8px; background-color: #f8f9fa; border-radius: 4px;",
                  div(
                    style = "display: flex; align-items: center; gap: 10px;",
                    token_status$icon,
                    div(
                      div(style = "font-size: 11px; color: #666; text-transform: uppercase;", "Token Status"),
                      div(
                        style = "font-size: 15px; margin-top: 2px;",
                        tags$span(style = token_style, token_status$status_text),
                        tags$span(
                          style = "color: #666; font-size: 13px; margin-left: 8px;",
                          paste0("(expires ", token_status$time_remaining, ")")
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        } else {
          NULL  # No accordion when not connected
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
        update_account_overview()
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
      # Reload tokens for active account
      active_account <- account_manager$get_active_account()
      if (!is.null(active_account)) {
        api <- ebay_api()
        api$oauth$set_tokens(
          access_token = active_account$access_token,
          refresh_token = active_account$refresh_token,
          token_expiry = active_account$token_expiry
        )
        ebay_api(api)
      }

      update_account_overview()
      update_connection_status()
      update_account_selector()

      if (!is.null(active_account)) {
        showNotification(
          paste("Refreshed tokens for:", active_account$username),
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
      if (is.null(auth_url) || nchar(auth_url) == 0) {
        showNotification(
          "Error: Could not generate authorization URL. Check eBay API credentials.",
          duration = NULL,
          type = "error"
        )
        return()
      }

      # Try to open browser
      tryCatch({
        browseURL(auth_url)
      }, error = function(e) {
        # Silently continue - will show modal anyway
      })

      # Always show modal with URL (in case browser doesn't open)
      showModal(modalDialog(
        title = "eBay Authorization Required",
        size = "l",
        tags$div(
          style = "padding: 15px;",
          tags$p(
            style = "font-size: 16px; margin-bottom: 15px;",
            "We attempted to open your browser automatically. If it didn't open, please copy the URL below:"
          ),
          tags$div(
            style = "background: #f5f5f5; border: 1px solid #ddd; border-radius: 4px; padding: 12px; margin-bottom: 15px; word-break: break-all;",
            tags$code(
              style = "font-size: 12px; color: #333;",
              auth_url
            )
          ),
          tags$div(
            style = "margin-bottom: 15px;",
            tags$button(
              class = "btn btn-primary btn-sm",
              onclick = sprintf("navigator.clipboard.writeText('%s'); alert('URL copied to clipboard!');", auth_url),
              tags$i(class = "fa fa-copy"),
              " Copy URL"
            ),
            tags$a(
              href = auth_url,
              target = "_blank",
              class = "btn btn-success btn-sm",
              style = "margin-left: 10px;",
              tags$i(class = "fa fa-external-link"),
              " Open in New Tab"
            )
          ),
          tags$hr(),
          tags$p(
            style = "font-size: 14px; color: #666;",
            tags$strong("Instructions:"),
            tags$ol(
              tags$li("Copy the URL above or click 'Open in New Tab'"),
              tags$li("Sign in to your eBay account"),
              tags$li("Click 'Agree' to authorize this application"),
              tags$li("Copy the authorization code that appears"),
              tags$li("Paste it below and click 'Submit'")
            )
          )
        ),
        footer = modalButton("Close")
      ))

      # Show code input
      updateCheckboxInput(
        session = session,
        inputId = "show_code_input",
        value = TRUE
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

          # DEBUG: Log what eBay returned
          cat("\n=== eBay User Info Retrieved ===\n")
          cat("  User ID:", user_info$user_id, "\n")
          cat("  Username:", user_info$username, "\n")
          cat("  Environment:", api$config$environment, "\n")
          cat("================================\n\n")

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

            # Update the global ebay_api reactive value with fresh tokens
            ebay_api(api)

            # Update UI
            update_account_overview()
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
          update_account_overview()
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
