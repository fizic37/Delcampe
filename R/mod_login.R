#' login UI Function - CSS Isolated Version
#'
#' @description A shiny Module with proper CSS isolation to prevent main app interference.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd 
#'
#' @importFrom shiny NS tagList 
mod_login_ui <- function(id){
  ns <- NS(id)
  tagList(
    shinyjs::useShinyjs(),
    # Login overlay container - isolated CSS
    div(
      id = ns("login_overlay"),
      style = "position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: 9999; 
               background: linear-gradient(135deg, #B8E6C1 0%, #8FD5A6 100%); 
               display: flex; justify-content: center; align-items: center; padding: 20px;",
      
      # Isolated CSS styles and JavaScript - only affects login container
      tags$head(
        # Add Enter key functionality
        tags$script(HTML(paste0("
          $(document).ready(function() {
            // Add Enter key event listeners to both input fields
            $('#", ns("userName"), ", #", ns("passwd"), "').on('keypress', function(e) {
              if (e.which === 13) { // Enter key
                e.preventDefault();
                $('#", ns("login"), "').click();
              }
            });
          });
        "))),
        tags$style(HTML(paste0("
          #", ns("login_container"), " {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.15);
            border: none;
            padding: 50px 40px;
            max-width: 450px;
            width: 100%;
            position: relative;
            overflow: hidden;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
          }
          
          #", ns("login_container"), "::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 5px;
            background: linear-gradient(90deg, #52B788, #40916C, #52B788);
          }
          
          #", ns("login_container"), " .form-group {
            margin-bottom: 25px;
            width: 100%;
          }
          
          #", ns("login_container"), " .form-control {
            padding: 15px 15px 15px 50px !important;
            border-radius: 15px !important;
            border: 2px solid #e9ecef !important;
            font-size: 16px !important;
            background-color: #f8f9fa !important;
            transition: all 0.3s ease !important;
            width: 100% !important;
            max-width: none !important;
            box-sizing: border-box !important;
          }
          
          #", ns("login_container"), " .form-control:focus {
            border-color: #52B788 !important;
            background-color: white !important;
            box-shadow: 0 0 0 3px rgba(82, 183, 136, 0.1) !important;
          }
          
          #", ns("login_container"), " .input-icon {
            position: absolute;
            left: 18px;
            top: 50%;
            transform: translateY(-50%);
            color: #6c757d;
            z-index: 10;
            font-size: 18px;
          }
          
          #", ns("login_container"), " .login-button {
            background: linear-gradient(135deg, #52B788 0%, #40916C 100%);
            border: none;
            padding: 15px 35px;
            font-size: 18px;
            font-weight: 600;
            border-radius: 25px;
            color: white;
            width: 100%;
            transition: all 0.3s ease;
            letter-spacing: 0.5px;
            box-sizing: border-box;
          }
          
          #", ns("login_container"), " .login-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(82, 183, 136, 0.3);
          }
          
          #", ns("login_container"), " .error-message {
            background: linear-gradient(135deg, #dc3545, #c82333);
            color: white;
            padding: 12px 20px;
            border-radius: 10px;
            text-align: center;
            margin-top: 20px;
            font-weight: 500;
          }
        ")))
      ),
      
      div(
        id = ns("login_container"),
        
        # Header
        tags$h2("DELCAMPE APP", 
                class = "text-center", 
                style = "color:#52B788; font-weight:700; margin-bottom: 10px; font-size: 32px; letter-spacing: 1px;"),
        
        p("Postal Card Management System", 
          style = "color: #6c757d; text-align: center; margin-bottom: 40px; font-size: 16px;"),
        
        # Username input with icon
        div(
          class = "form-group",
          style = "position: relative; width: 100%;",
          tags$label(
            `for` = ns("userName"),
            style = "color: #495057; font-weight: 600; margin-bottom: 8px; display: flex; align-items: center; gap: 8px;",
            icon("user"), "Username"
          ),
          div(
            style = "position: relative; width: 100%;",
            icon("user", class = "input-icon"),
            textInput(
              inputId = ns("userName"),
              label = NULL,
              placeholder = "Email address"
            ),
            # JavaScript to handle Enter key press
            tags$script(HTML(sprintf("
              $(document).on('keypress', '#%s', function(e) {
                if(e.which == 13) {
                  $('#%s').click();
                }
              });
            ", ns("userName"), ns("login"))))
          )
        ),
        
        # Password input with icon  
        div(
          class = "form-group",
          style = "position: relative; width: 100%;",
          tags$label(
            `for` = ns("passwd"),
            style = "color: #495057; font-weight: 600; margin-bottom: 8px; display: flex; align-items: center; gap: 8px;",
            icon("unlock-alt"), "Password"
          ),
          div(
            style = "position: relative; width: 100%;",
            icon("unlock-alt", class = "input-icon"),
            passwordInput(
              inputId = ns("passwd"),
              label = NULL,
              placeholder = "Password"
            ),
            # JavaScript to handle Enter key press
            tags$script(HTML(sprintf("
              $(document).on('keypress', '#%s', function(e) {
                if(e.which == 13) {
                  $('#%s').click();
                }
              });
            ", ns("passwd"), ns("login"))))
          )
        ),
        
        # Login button
        div(
          style = "text-align: center; color: #ffffff; margin: 30px 0 20px 0;",
          actionButton(
            inputId = ns("login"), 
            "SIGN IN",
            class = "login-button"
          )
        ),
        
        # Error message
        shinyjs::hidden(
          div(
            id = ns("nomatch"),
            class = "error-message",
            icon("exclamation-triangle", style = "margin-right: 8px;"),
            "Oops! Incorrect username or password!"
          )
        )
      )
    )
  )
}
    
#' login Server Functions - Using Auth System
#'
#' @noRd 
mod_login_server <- function(id, vals){
  moduleServer(id, function(input, output, session){
    ns <- session$ns

    # Authentication logic using auth_system functions
    observe({
      if (vals$login == FALSE) {
        if (!is.null(input$login)) {
          if (input$login > 0) {
            Username <- isolate(input$userName)
            Password <- isolate(input$passwd)
            
            # Use the authenticate_user function from auth_system.R
            auth_result <- authenticate_user(Username, Password)
            
            if(auth_result$success) {
              # Authentication successful
              vals$login <- TRUE

              # Remove login UI overlay
              removeUI(selector = paste0("#", ns("login_overlay")))

              # Set user data from auth result
              vals$user_type <- auth_result$user$role
              vals$user_name <- auth_result$user$email

              # Store additional user info for the session
              vals$user_data <- auth_result$user

              # Create session record in database for eBay integration
              tryCatch({
                con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
                on.exit(DBI::dbDisconnect(con), add = TRUE)

                # Get user_id for this user (should be same as id after migration)
                user_id <- DBI::dbGetQuery(con,
                  "SELECT user_id FROM users WHERE id = ?",
                  list(auth_result$user$id))$user_id[1]

                if (is.na(user_id)) {
                  # Fallback: use id as text if user_id not set
                  user_id <- as.character(auth_result$user$id)
                }

                # This links the Shiny session to the database user
                DBI::dbExecute(con, "
                  INSERT OR REPLACE INTO sessions (session_id, user_id, status)
                  VALUES (?, ?, 'active')
                ", list(session$token, user_id))

                cat("✅ Session created for user:", auth_result$user$email, "(user_id:", user_id, ")\n")
              }, error = function(e) {
                cat("⚠️ Warning: Could not create session record:", e$message, "\n")
              })

            } else {
              # Authentication failed - show specific error message
              shinyjs::html("nomatch", paste(icon("exclamation-triangle", style = "margin-right: 8px;"), auth_result$message))
              shinyjs::toggle(id = "nomatch", anim = TRUE, time = 1, animType = "fade")
              shinyjs::delay(3000, shinyjs::toggle(id = "nomatch", anim = TRUE, time = 1, animType = "fade"))
            }
          } 
        }
      }    
    })
  })
}
    
## To be copied in the UI
# mod_login_ui("login_ui_1")
    
## To be copied in the server
# mod_login_server("login_ui_1")