# Authentication Implementation Consistency Checklist

## CRITICAL PATTERNS TO PRESERVE

### Must Always Use
- [ ] **Namespace function**: `ns <- NS(id)` in UI, `ns <- session$ns` in server
- [ ] **Reactive values**: Use `reactiveValues()` for multi-value state, `reactiveVal()` for single values
- [ ] **Module isolation**: All HTML IDs use `ns()` namespacing, all jQuery uses namespaced IDs
- [ ] **Isolation in observes**: Use `isolate()` to prevent reactive dependency on button clicks
- [ ] **Early returns**: Use `return()` to exit observeEvent on validation failure
- [ ] **Modal patterns**: Use `showModal(modalDialog(...))` with `easyClose = TRUE`
- [ ] **Error messages**: Set to `alerts$user_message` and `alerts$user_type`
- [ ] **Notification types**: Use ONLY "message", "warning", "error" (never "success" or "default")
- [ ] **UI components**: Prefer `bslib::card()`, `bslib::accordion()` over raw divs
- [ ] **Icons**: Use `icon()` function consistently
- [ ] **Function returns**: Always return `list(success = T/F, message = "...", data = ...)`

### Must NOT Do
- [ ] Don't use `type = "success"` in `showNotification()` - use `type = "message"`
- [ ] Don't use `type = "default"` in `showNotification()` - not a valid value
- [ ] Don't pass plain values to child modules - use reactive functions or reactiveValues
- [ ] Don't use getElementById() or querySelector() - use fully namespaced jQuery with `ns()`
- [ ] Don't mix custom JavaScript onclick handlers with modules - use `observeEvent()` instead
- [ ] Don't create backup files in `R/` folder - use `Delcampe_BACKUP/` directory
- [ ] Don't modify the R-Python integration setup - it's battle-tested
- [ ] Don't exceed 400 lines per R file - split into modules
- [ ] Don't call `removeModal()` after a delay without checking if modal exists
- [ ] Don't rely on `.Renviron` for credentials without fallback to file storage

## REACTIVE PATTERN CHECKLIST

### For login/authentication flows:
```
[ ] Create vals <- reactiveValues(login = FALSE, user_name = NULL, user_type = NULL, user_data = NULL)
[ ] Pass vals to mod_login_server("id", vals)
[ ] In observe block: check vals$login == FALSE before processing
[ ] Use isolate() on input values: isolate(input$userName)
[ ] Call authenticate_user() function
[ ] On success: set vals$login <- TRUE and other user fields
[ ] On failure: show error with shinyjs::html() and shinyjs::toggle()
[ ] Auto-hide errors after 3 seconds with shinyjs::delay()
```

### For modal dialogs:
```
[ ] Use observeEvent(input$button, { showModal(...) })
[ ] Include footer with actionButton and modalButton
[ ] Set easyClose = TRUE
[ ] Use ns() to namespace all input IDs inside modal
[ ] In separate observeEvent for submit button: validate inputs first
[ ] Return early with alert message if validation fails
[ ] Call removeModal() only on success
[ ] Clear input fields with updateTextInput(session, "id", value = "")
```

### For alerts/notifications:
```
[ ] Create alerts <- reactiveValues(user_message = "", user_type = "")
[ ] Pass alerts to module as parameter
[ ] Set alerts$user_message and alerts$user_type when action happens
[ ] Use type values: "message", "warning", "error" only
[ ] Parent module renders alerts with showNotification(alerts$user_message, type = alerts$user_type)
[ ] For multi-step modals: clear alerts when reopening modal
```

### For returning values from modules:
```
[ ] Create reactive values for each return value
[ ] Example: ebay_api <- reactiveVal(NULL), account_manager <- EbayAccountManager$new()
[ ] Return list(api = ebay_api, account_manager = account_manager) from server
[ ] In parent: ebay_auth <- mod_ebay_auth_server("id")
[ ] Access with: api <- ebay_auth$api (call as function), mgr <- ebay_auth$account_manager
```

## UI COMPONENT CHECKLIST

### All modules must:
- [ ] Use `NS(id)` in UI function
- [ ] Call `shinyjs::useShinyjs()` in tagList if using shinyjs
- [ ] Namespace EVERY HTML ID with `ns()`
- [ ] Namespace EVERY input with `inputId = ns("name")`
- [ ] Scope all CSS with namespaced IDs: `#" ns("id") " { ... }`
- [ ] Use `bslib::` components for consistency (card, accordion, card_header)
- [ ] Use `icon()` function from Font Awesome
- [ ] Use `modalDialog()` for forms, not custom divs
- [ ] Hide/show elements with `shinyjs::hidden()` and `shinyjs::toggle()`

### Conditional visibility:
- [ ] Use `conditionalPanel(condition = ..., div(...))` for UI rendering
- [ ] Pair with hidden `checkboxInput()` to control visibility
- [ ] Format condition: `paste0("input['", ns("id"), "'] == true")`
- [ ] Update with `updateCheckboxInput(session = session, inputId = "id", value = TRUE)`

## FUNCTION IMPLEMENTATION CHECKLIST

### For new auth helper functions:
- [ ] Use snake_case naming: `authenticate_user`, `update_user_password`, `validate_password`
- [ ] Return `list(success = TRUE/FALSE, message = "...", data = ...)`
- [ ] Include error message in return list (don't throw errors to UI)
- [ ] Validate inputs before processing
- [ ] Use SHA-256 for password hashing (per CLAUDE.md)
- [ ] Write comprehensive error messages
- [ ] Add roxygen2 documentation with `#'` comments
- [ ] Include `@param` for each parameter
- [ ] Include `@return` describing return structure
- [ ] Add `@noRd` if internal, `@export` if public

### Expected signature template:
```r
#' Authenticate User
#' @description Verify username and password against database
#' @param email User email address
#' @param password User password (plain text)
#' @return List with success (TRUE/FALSE), message (string), user (list if success)
#' @noRd
authenticate_user <- function(email, password) {
  # Implementation
  list(
    success = TRUE/FALSE,
    message = "error or status message",
    user = list(email = "...", role = "...", id = "...")
  )
}
```

## TESTING CHECKLIST

### For each new authentication module:
- [ ] Create corresponding test file: `tests/testthat/test-mod_XXX.R`
- [ ] Write test for UI generation: `expect_s3_class(ui, "shiny.tag")`
- [ ] Write test for namespacing: `expect_true(grepl(id, as.character(ui)))`
- [ ] Mock auth helper functions if not yet implemented
- [ ] Test successful path: `expect_true(vals$login)`
- [ ] Test failure path: `expect_false(vals$login)`
- [ ] Test error display: check `shinyjs::toggle()` behavior
- [ ] Use `testServer()` for reactive logic testing
- [ ] Set up test database with `with_test_db()` helper
- [ ] Run critical tests before commit: `source("dev/run_critical_tests.R")`

### Test database setup pattern:
```r
with_test_db({
  # Create test users
  create_test_user(db, "testuser", "testpass", FALSE)
  
  # Create reactive values
  vals <- reactiveValues(login = FALSE)
  
  # Test module
  testServer(mod_login_server, args = list(vals = vals), {
    session$setInputs(userName = "testuser", passwd = "testpass", login = 1)
    session$flushReact()
    expect_true(vals$login)
  })
})
```

## SECURITY CHECKLIST

### Authentication specific:
- [ ] Never log or display passwords
- [ ] Always use `isolate()` on password inputs
- [ ] Clear password fields after operations with `updateTextInput(..., value = "")`
- [ ] Verify current password before allowing password changes
- [ ] Hash passwords with SHA-256 (never store plain text)
- [ ] Use HTTPS in production (enforced at deployment)
- [ ] Store API tokens securely in reactiveVal, not in localStorage
- [ ] Implement token expiry checks
- [ ] Support token refresh for OAuth flows
- [ ] Validate authorization codes before exchanging for tokens

### Master user protection:
- [ ] Master users can manage their own credentials
- [ ] Master users CANNOT delete each other (hard constraint)
- [ ] Track master user status in database
- [ ] Check master user status before delete operations
- [ ] Regular master users can be deleted by masters only
- [ ] Document master user creation process

## DOCUMENTATION CHECKLIST

### Each new module needs:
- [ ] `@description` in roxygen2 comments explaining purpose
- [ ] Parameter documentation for non-standard parameters
- [ ] Return documentation for server functions that return values
- [ ] `@examples` section for complex usage patterns
- [ ] Comments for non-obvious reactive logic
- [ ] Architecture decision explanation if breaking new ground

### Code organization:
- [ ] Section headers with `# ==== SECTION NAME ====`
- [ ] Related observables grouped together
- [ ] Helper functions before they're used
- [ ] Clear variable names (not abbreviated)
- [ ] Inline comments only for "why", not "what"

## DEPLOYMENT CHECKLIST

### Before deploying auth system:
- [ ] All critical tests pass: `source("dev/run_critical_tests.R")`
- [ ] No backup files in `R/` folder
- [ ] API keys only in `.Renviron`, not hardcoded
- [ ] Default credentials removed (test values in mod_login.R, line 167-188)
- [ ] Database initialized on first run
- [ ] Master user creation documented
- [ ] Error messages don't expose system details
- [ ] Logs capture auth failures for security monitoring
- [ ] Token refresh logic tested with expired tokens
- [ ] Multi-user session isolation tested

## INTEGRATION CHECKLIST

### In app_server.R:
- [ ] Create vals <- reactiveValues(...) for login state
- [ ] Call mod_login_server("id", vals) 
- [ ] Conditionally initialize other modules based on vals$login
- [ ] Pass vals$user_data (reactive) to child modules as current_user
- [ ] Update hardcoded user in mod_settings_server to use actual current_user
- [ ] Handle logout: set vals$login <- FALSE, clear vals$user_data

### In app_ui.R:
- [ ] Add mod_login_ui("id") at top level
- [ ] Show main UI only if logged in (use `uiOutput()` with reactive logic)
- [ ] Hide eBay/processing tabs until user is authenticated

## MODULE SIZE CHECKLIST

### File organization (max 400 lines each):
- [ ] mod_login.R: UI (200 lines) + Server (65 lines) = 265 total ✓
- [ ] mod_settings_password.R: Server only (112 lines) ✓
- [ ] auth_system.R: May exceed 400 - split into auth_helpers.R and auth_database.R
- [ ] Database extension: Use tracking_database.R pattern for organization

---

**Document created**: 2025-11-03
**Purpose**: Ensure consistency across all authentication-related code
**Scope**: Complete checklist for implementing auth system in Delcampe
**Audience**: Developers implementing authentication features
