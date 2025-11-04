# Authentication Code Patterns Reference - Copy & Adapt Examples

## 1. REACTIVE VALUE PATTERNS

### 1.1 Login State Pattern
```r
# In parent (app_server.R)
vals <- reactiveValues(
  login = FALSE,
  user_type = NULL,
  user_name = NULL,
  user_data = NULL
)

# Pass to login module
mod_login_server("login_1", vals)
```

### 1.2 Alert Messages Pattern
```r
# In module that needs alerts
alerts <- reactiveValues(
  user_message = "",
  user_type = "",
  llm_message = "",
  llm_type = ""
)

# Set alerts on events
alerts$user_message <- "Password changed successfully"
alerts$user_type <- "message"  # Use "message" not "success"
```

### 1.3 Single Value Reactive (Like eBay API)
```r
# For single complex object
ebay_api <- reactiveVal(NULL)

# Access
api <- ebay_api()

# Update
ebay_api(new_api_object)
```

## 2. OBSERVE PATTERNS

### 2.1 Login Flow Observe Pattern (from mod_login_server)
```r
observe({
  if (vals$login == FALSE) {
    if (!is.null(input$login)) {
      if (input$login > 0) {  # Button clicked
        # Isolate inputs to prevent reactive dependency
        Username <- isolate(input$userName)
        Password <- isolate(input$passwd)
        
        # Call auth function
        auth_result <- authenticate_user(Username, Password)
        
        if(auth_result$success) {
          # Update reactive values
          vals$login <- TRUE
          vals$user_type <- auth_result$user$role
          vals$user_name <- auth_result$user$email
          vals$user_data <- auth_result$user
          
          # Remove UI overlay
          removeUI(selector = paste0("#", ns("login_overlay")))
        } else {
          # Show error
          shinyjs::html("nomatch", paste(icon("exclamation-triangle"), auth_result$message))
          shinyjs::toggle(id = "nomatch", anim = TRUE, time = 1, animType = "fade")
          shinyjs::delay(3000, shinyjs::toggle(id = "nomatch", anim = TRUE, time = 1, animType = "fade"))
        }
      }
    }
  }
})
```

### 2.2 Observable Event Pattern (from mod_settings_password_server)
```r
observeEvent(input$change_password_btn, {
  showModal(modalDialog(
    title = "Change Password",
    size = "m",
    passwordInput(ns("current_password"), "Current Password"),
    passwordInput(ns("new_password"), "New Password"),
    passwordInput(ns("confirm_new_password"), "Confirm New Password"),
    footer = div(
      actionButton(ns("submit_password_change"), "Change Password", class = "btn-success"),
      modalButton("Cancel")
    ),
    easyClose = TRUE
  ))
})
```

### 2.3 Action Event with Validation Pattern
```r
observeEvent(input$submit_password_change, {
  req(input$current_password, input$new_password, input$confirm_new_password)
  
  # Validation checks
  if (input$new_password != input$confirm_new_password) {
    alerts$user_message <- "New passwords do not match"
    alerts$user_type <- "warning"
    return()
  }
  
  if (nchar(input$new_password) < 6) {
    alerts$user_message <- "New password must be at least 6 characters"
    alerts$user_type <- "warning"
    return()
  }
  
  # Call update function
  result <- update_user_password(
    email = current_user()$email,
    new_password = input$new_password,
    current_user_email = current_user()$email,
    current_user_role = current_user()$role
  )
  
  if (result$success) {
    alerts$user_message <- "Password changed successfully"
    alerts$user_type <- "message"
    removeModal()
  } else {
    alerts$user_message <- result$message
    alerts$user_type <- "error"
  }
})
```

## 3. MODULE PARAMETER PATTERNS

### 3.1 Module Taking Parent Reactive Values
```r
mod_my_module_server <- function(id, vals) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # Access parent's reactive values
    observe({
      if (vals$login) {
        # User is logged in
        cat("User:", vals$user_name, "\n")
      }
    })
  })
}
```

### 3.2 Module Taking Reactive Function (Current User)
```r
mod_my_module_server <- function(id, current_user) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # current_user is a reactive function - must call it
    observe({
      user <- current_user()
      cat("Current user email:", user$email, "\n")
    })
  })
}
```

### 3.3 Module Returning Values to Parent
```r
mod_ebay_auth_server <- function(id, parent_session = NULL) {
  moduleServer(id, function(input, output, session) {
    
    account_manager <- EbayAccountManager$new()
    ebay_api <- reactiveVal(NULL)
    
    # ... module logic ...
    
    # Return list for parent access
    return(list(
      api = ebay_api,
      account_manager = account_manager
    ))
  })
}

# In parent
ebay_auth <- mod_ebay_auth_server("ebay_auth")
ebay_api <- ebay_auth$api  # Get reactive value
ebay_account_manager <- ebay_auth$account_manager  # Get R6 object
```

## 4. UI PATTERNS

### 4.1 Namespaced Login UI Pattern
```r
mod_login_ui <- function(id){
  ns <- NS(id)
  tagList(
    shinyjs::useShinyjs(),
    # Use ns() to namespace ALL IDs
    div(
      id = ns("login_overlay"),  # Namespaced ID
      style = "position: fixed; top: 0; left: 0; ...",
      
      # Inline CSS with namespaced IDs
      tags$head(
        tags$style(HTML(paste0("
          #", ns("login_container"), " {
            background: white;
            border-radius: 20px;
          }
        ")))
      ),
      
      div(
        id = ns("login_container"),
        
        textInput(inputId = ns("userName"), label = NULL, placeholder = "Email"),
        passwordInput(inputId = ns("passwd"), label = NULL, placeholder = "Password"),
        actionButton(inputId = ns("login"), "SIGN IN", class = "login-button"),
        
        # Hidden error message
        shinyjs::hidden(
          div(
            id = ns("nomatch"),
            class = "error-message",
            "Oops! Incorrect credentials!"
          )
        )
      )
    )
  )
}
```

### 4.2 Modal Dialog Pattern
```r
showModal(modalDialog(
  title = "Change Password",
  size = "m",
  
  # Form inputs
  passwordInput(ns("current_password"), "Current Password", placeholder = "Enter current password"),
  passwordInput(ns("new_password"), "New Password", placeholder = "Minimum 6 characters"),
  passwordInput(ns("confirm_new_password"), "Confirm New Password"),
  
  # Footer with buttons
  footer = div(
    actionButton(ns("submit_password_change"), "Change Password", icon = icon("key"), class = "btn-success"),
    modalButton("Cancel")  # Built-in cancel button
  ),
  
  easyClose = TRUE  # Allow clicking outside to close
))
```

### 4.3 Conditional Panel with Hidden Checkbox
```r
# Hidden checkbox to control visibility
div(
  style = "display: none;",
  checkboxInput(ns("show_code_input"), "", value = FALSE)
)

# Conditional panel that shows when checkbox is TRUE
conditionalPanel(
  condition = paste0("input['", ns("show_code_input"), "'] == true"),
  div(
    class = "auth-code-input mt-3 p-3",
    textAreaInput(ns("auth_code"), "Authorization Code:", rows = 3),
    actionButton(ns("submit_code"), "Submit Code & Connect", class = "btn-success w-100")
  )
)

# In server, toggle the hidden checkbox
updateCheckboxInput(session = session, inputId = "show_code_input", value = TRUE)
```

### 4.4 Accordion with Status Display
```r
bslib::accordion(
  id = session$ns("account_overview"),
  open = FALSE,
  bslib::accordion_panel(
    title = HTML(paste0(
      "<span style='font-weight: 600;'>Account Overview</span>",
      " <span style='color: #666;'>(", active_account$username, ")</span>"
    )),
    icon = icon("user-circle"),
    div(
      style = "padding: 10px;",
      # Content rows
      div(
        style = "margin-bottom: 12px; padding: 8px; background-color: #f8f9fa;",
        div(
          style = "display: flex; align-items: center; gap: 10px;",
          icon("user", style = "color: #52B788; font-size: 18px;"),
          div(
            div(style = "font-size: 11px; color: #666; text-transform: uppercase;", "Username"),
            div(style = "font-size: 15px; font-weight: 600;", active_account$username)
          )
        )
      )
    )
  )
)
```

## 5. SHINYJS PATTERNS

### 5.1 Error Display with Auto-Hide
```r
# In UI: create hidden error message
shinyjs::hidden(
  div(
    id = ns("nomatch"),
    class = "error-message",
    "Error message here"
  )
)

# In server: show with animation, auto-hide after 3 seconds
shinyjs::html(ns("nomatch"), paste(icon("exclamation-triangle"), "New error message"))
shinyjs::toggle(id = ns("nomatch"), anim = TRUE, time = 1, animType = "fade")
shinyjs::delay(3000, shinyjs::toggle(id = ns("nomatch"), anim = TRUE, time = 1, animType = "fade"))
```

### 5.2 JavaScript for Enter Key Support
```r
tags$script(HTML(paste0("
  $(document).ready(function() {
    $('#", ns("userName"), ", #", ns("passwd"), "').on('keypress', function(e) {
      if (e.which === 13) {  // Enter key code
        e.preventDefault();
        $('#", ns("login"), "').click();  // Trigger login button
      }
    });
  });
")))
```

### 5.3 Copy to Clipboard Button
```r
tags$button(
  class = "btn btn-primary btn-sm",
  onclick = sprintf("navigator.clipboard.writeText('%s'); alert('Copied!');", auth_url),
  tags$i(class = "fa fa-copy"),
  " Copy URL"
)
```

## 6. FUNCTION CALLING PATTERNS

### 6.1 With Error Handling (tryCatch)
```r
result <- tryCatch({
  api$oauth$get_user_token(auth_code)
}, error = function(e) {
  cat("Error:", e$message, "\n")
  return(list(success = FALSE, error = e$message))
})

if (result$success) {
  # Handle success
} else {
  showNotification(
    paste("Authentication failed:", result$error),
    type = "error"
  )
}
```

### 6.2 With Progress Bar
```r
withProgress(message = "Exchanging code for token...", {
  result <- api$oauth$get_user_token(auth_code)
  # Long operation updates automatically
})
```

## 7. NOTIFICATION PATTERNS

### 7.1 showNotification() Types
```r
# CORRECT TYPES
showNotification("Success!", type = "message")  # Blue info box
showNotification("Warning!", type = "warning")  # Yellow box
showNotification("Error!", type = "error")      # Red box

# INCORRECT - will cause error
showNotification("Success!", type = "success")  # DOES NOT EXIST
showNotification("Success!", type = "default")  # DOES NOT EXIST

# With options
showNotification(
  "Account switched",
  type = "message",
  duration = 5,           # 5 seconds, NULL = persist
  closeButton = TRUE      # Show X button
)
```

### 7.2 HTML in Notifications
```r
showNotification(
  HTML(paste0(
    "<div style='font-size: 14px;'>",
    "<strong>eBay Connected:</strong> ",
    "<span style='font-family: monospace;'>", username, "</span><br>",
    "<strong>Token Status:</strong> Healthy",
    "</div>"
  )),
  type = "message",
  duration = NULL
)
```

## 8. EXPECTED AUTHENTICATION HELPER FUNCTIONS

### 8.1 Function Signatures (from comments in code)
```r
# Initialize users database
init_users_file()

# Authenticate user
auth_result <- authenticate_user(username, password)
# Returns: list(success = T/F, message = "error text", user = list(email = "...", role = "..."))

# Update user password
update_result <- update_user_password(
  email = "user@example.com",
  new_password = "newpass",
  current_user_email = "admin@example.com",
  current_user_role = "admin"
)
# Returns: list(success = T/F, message = "status text")
```

## 9. INTEGRATION IN app_server.R

### 9.1 How Settings Module is Currently Called (Line 332)
```r
# CURRENT (HARDCODED FOR TESTING)
mod_settings_server("settings", reactive(list(email = "admin@delcampe.com", role = "admin")))

# SHOULD BE (when auth system is ready)
# Assuming vals$user_data contains logged-in user info
mod_settings_server(
  "settings",
  reactive(vals$user_data)  # Pass current user as reactive
)
```

### 9.2 eBay Module Integration
```r
# Create eBay auth and get api/account_manager
ebay_auth <- mod_ebay_auth_server("ebay_auth")
ebay_api <- ebay_auth$api
ebay_account_manager <- ebay_auth$account_manager

# Use in other modules
mod_ebay_listings_server("ebay_listings", ebay_api = ebay_api, session_id = reactive(session$token))
```

---

**Document created**: 2025-11-03
**Purpose**: Copy-and-adapt code examples for auth system implementation
**Patterns covered**: 15+ common patterns in existing codebase
