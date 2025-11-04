# Authentication and Login Module Analysis - Delcampe Codebase

## Executive Summary
The Delcampe R/Shiny application implements a modular authentication system with distinct concerns: user login (mod_login.R), password management (mod_settings_password.R), and third-party auth (mod_ebay_auth.R). The system uses Golem framework conventions, modular Shiny patterns, and relies on helper functions from an external auth_system.R file.

## 1. MODULE STRUCTURE AND ORGANIZATION

### 1.1 mod_login.R - User Authentication
**Location**: `/mnt/c/Users/mariu/Documents/R_Projects/Delcampe/R/mod_login.R`

**Structure**:
- `mod_login_ui(id)` - UI function (lines 10-215)
- `mod_login_server(id, vals)` - Server function (lines 220-263)

**UI Architecture**:
- **Namespace Pattern**: Uses `NS(id)` to create namespaced IDs
- **Fixed positioning overlay**: Full-screen login form with gradient background
- **CSS isolation**: Inline CSS with `ns()` namespacing to prevent global app interference
- **Enter key support**: Custom JavaScript added via `tags$script()` to enable Enter key login
- **Icons**: Uses Font Awesome icons with `icon()` function
- **Styling**: Full custom styling with green (#52B788, #40916C) theme
- **Test credentials display**: Shows default login credentials in styled box at bottom

**Server Architecture**:
- **Reactive Pattern**: `observe({})` block watches `vals$login` state
- **Input isolation**: Uses `isolate()` to prevent reactive dependencies
- **Action button pattern**: Watches `input$login` button counter
- **Function calls**: 
  - `init_users_file()` - Initializes users database
  - `authenticate_user(Username, Password)` - Core auth function
  - `removeUI()` - Removes login overlay after successful auth
- **Reactive values set**:
  - `vals$login` - Boolean flag
  - `vals$user_type` - User role (from auth_result$user$role)
  - `vals$user_name` - User email
  - `vals$user_data` - Full user object
- **Error handling**: Uses `shinyjs::html()` and `shinyjs::toggle()` with animations
- **Error display**: 3-second auto-hiding error message with fade animation

### 1.2 mod_settings_password.R - Password Management
**Location**: `/mnt/c/Users/mariu/Documents/R_Projects/Delcampe/R/mod_settings_password.R`

**Structure**:
- `mod_settings_password_server(id, current_user, alerts)` - Server only (no UI module)

**Server Architecture**:
- **Modal pattern**: Uses `showModal(modalDialog(...))` for password change form
- **Input validation**: Multiple validation checks (password confirmation, minimum length)
- **Reactive dependencies**: 
  - `current_user` - Reactive function returning current user info
  - `alerts` - ReactiveValues object for notification state
- **Function calls**:
  - `authenticate_user(email, password)` - Verify current password before change
  - `update_user_password(email, new_password, current_user_email, current_user_role)` - Update password
  - `removeModal()` - Close dialog after success
- **Security**: Clears password fields after operation with `updateTextInput()`
- **Alert pattern**: 
  - Sets `alerts$user_message` and `alerts$user_type` ("success" or "danger")
  - Type "success" maps to actual "message" type (see constraint note below)
- **Error scenarios**: Returns early with alerts on validation failures

### 1.3 mod_ebay_auth.R - Third-Party OAuth
**Location**: `/mnt/c/Users/mariu/Documents/R_Projects/Delcampe/R/mod_ebay_auth.R`

**Structure**:
- `mod_ebay_auth_ui(id)` - UI function
- `mod_ebay_auth_server(id, parent_session = NULL)` - Server function

**Reactive Pattern**:
- Initializes `EbayAccountManager$new()` (R6 class)
- Creates `ebay_api <- reactiveVal(NULL)`
- Returns list with `api` and `account_manager` for parent module access

**Module Return Values**:
- Returns `list(api = ebay_api, account_manager = account_manager)`
- Allows parent modules to access reactive API object

## 2. REACTIVE PATTERNS AND STATE MANAGEMENT

### 2.1 Module Parameter Patterns

**Login Module Pattern**:
```r
mod_login_server(id, vals)
# vals is a reactiveValues object passed from parent
# Expects: vals$login (boolean flag)
# Sets: vals$login, vals$user_type, vals$user_name, vals$user_data
```

**Password Module Pattern**:
```r
mod_settings_password_server(id, current_user, alerts)
# current_user: reactive function returning user object
# alerts: reactiveValues object for notification state
```

**eBay Auth Module Pattern**:
```r
ebay_auth <- mod_ebay_auth_server(id)
# Returns: list(api = reactiveVal, account_manager = R6 instance)
```

### 2.2 Reactive Value Naming Conventions
- **Login state**: `vals$login` (boolean)
- **User info**: `vals$user_name`, `vals$user_type`, `vals$user_data`
- **Alerts/Messages**: `alerts$user_message`, `alerts$user_type` (in settings module)
- **Reactive values**: `reactiveVal()` for single values, `reactiveValues()` for objects

### 2.3 Observable Patterns
- **observe({})** - Runs when dependencies change, used for side effects
- **observeEvent(input$btn)** - Triggers on specific events (button clicks)
- **isolate()** - Prevents reactive dependency on a value

## 3. UI COMPONENTS AND STYLING

### 3.1 Component Hierarchy
**mod_login_ui**:
- Outer container: `div` with fixed positioning and gradient background
- Inner container: `div` with white background, rounded corners, shadow
- Form groups: Username and password inputs with icons
- Error message: Hidden by default, shown on authentication failure
- Login button: Full-width gradient button
- Custom styling: All CSS scoped with namespace IDs

### 3.2 Component Usage
- **Input types**: `textInput()`, `passwordInput()`, `textAreaInput()`
- **Buttons**: `actionButton()` with CSS classes
- **Modals**: `modalDialog()` with `footer` and `easyClose = TRUE`
- **Icons**: `icon()` function from Font Awesome
- **Conditional panels**: `conditionalPanel()` for showing/hiding sections
- **Accordions**: `bslib::accordion()` with `accordion_panel()`
- **Cards**: `bslib::card()` and `bslib::card_header()`

### 3.3 Hidden Elements
- Uses `shinyjs::hidden()` to pre-hide error messages
- Uses `shinyjs::toggle()` to show/hide with animations
- Uses `checkboxInput()` with hidden `div` to control `conditionalPanel()` visibility

## 4. ERROR HANDLING AND NOTIFICATIONS

### 4.1 Error Notification Patterns
**Login Module**:
- Catches authentication failures from `authenticate_user()` function
- Displays error via `shinyjs::html()` to inject HTML into error div
- Shows error with 3-second auto-hide using `shinyjs::delay()`
- Uses `shinyjs::toggle()` with fade animation

**Password Module**:
- Pre-validation checks before making changes
- Returns early with alert message on validation failure
- Sets `alerts$user_message` and `alerts$user_type` for parent to display
- Uses `showNotification()` for success/error messages (see critical constraint below)

**eBay Module**:
- Uses `showNotification()` for user feedback
- Proper error handling for OAuth flow failures
- Modal dialogs for instructions and confirmations

### 4.2 Notification Types - CRITICAL CONSTRAINT
The code uses `type = "success"` in mod_settings_password.R (line 91):
```r
alerts$user_type <- "success"
```
**ISSUE**: R Shiny's `showNotification()` does NOT accept `type = "success"`. Valid values are:
- `type = "message"` (blue/info, default)
- `type = "warning"` (yellow)
- `type = "error"` (red)
- Must map "success" to "message" type

## 5. JAVASCRIPT AND shinyjs PATTERNS

### 5.1 shinyjs Usage
- **useShinyjs()**: Called in UI to enable shinyjs functions
- **shinyjs::hidden()**: Pre-hide elements
- **shinyjs::toggle()**: Toggle visibility with animation
- **shinyjs::html()**: Inject HTML into elements
- **shinyjs::delay()**: Execute code after delay

### 5.2 Custom JavaScript
**Login module** (lines 24-34):
- Adds Enter key listener to username and password inputs
- Namespaced IDs with `ns()` function: `$('#', ns("userName"), "')` pattern
- Triggers login button click on Enter key

### 5.3 Module Namespace Handling
- All custom jQuery uses fully namespaced IDs: `$('#' + ns("id") + '...`
- Inline script HTML with `paste0()` to construct JavaScript strings
- Namespace function `ns()` available in module context via `session$ns`

## 6. DATABASE AND AUTHENTICATION HELPER FUNCTIONS

### 6.1 Called Functions (Not Yet Implemented)
The following functions are called but not defined in the codebase:
- `init_users_file()` - Initialize users database file
- `authenticate_user(username, password)` - Returns `list(success, user, message)`
- `update_user_password(email, new_password, current_user_email, current_user_role)` - Returns `list(success, message)`

These are referenced in mod_login.R (line 235) and mod_settings_password.R (line 73) with comment: "from auth_system.R"

### 6.2 Authentication Result Structure
Expected return structure from `authenticate_user()`:
```r
list(
  success = TRUE/FALSE,
  message = "error message if failed",
  user = list(
    email = "user@example.com",
    role = "admin" or "user",
    # potentially other fields
  )
)
```

## 7. INTEGRATION PATTERNS IN app_server.R

### 7.1 Settings Module Integration (Line 332)
```r
mod_settings_server("settings", reactive(list(email = "admin@delcampe.com", role = "admin")))
```
- Passes hardcoded user for testing (should be replaced with actual current_user)
- Current user is passed as a reactive function returning user object

### 7.2 Module Return Values
Some modules return values for parent access:
- **eBay auth** (line 338-340):
```r
ebay_auth <- mod_ebay_auth_server("ebay_auth")
ebay_api <- ebay_auth$api  # reactiveVal
ebay_account_manager <- ebay_auth$account_manager  # R6 object
```

## 8. NAMING CONVENTIONS AND STYLE

### 8.1 Naming Patterns
- **Modules**: `mod_` prefix, snake_case: `mod_login`, `mod_settings_password`
- **Functions**: snake_case: `authenticate_user`, `init_users_file`
- **Variables**: snake_case: `current_user`, `auth_result`, `auth_code`
- **HTML IDs**: snake_case with namespace: `ns("login_overlay")`, `ns("userName")`
- **Reactive values**: Lowercase: `vals$login`, `alerts$user_message`

### 8.2 Code Structure
- Comments use `# ====` for section headers
- Observable blocks organized by functionality
- Helper functions defined within server function when module-specific
- Proper isolation of reactive dependencies

## 9. SECURITY PATTERNS

### 9.1 Password Handling
- Never display passwords in placeholders (only in input for testing)
- Clear password fields after operations
- Verify current password before allowing password changes
- Use SHA-256 hashing (per CLAUDE.md constraints)

### 9.2 Session and Token Management
- Store tokens in memory via reactiveVal objects
- eBay auth stores tokens with expiry time
- Account manager (R6 class) handles multi-account switching

## 10. TESTING PATTERNS

### 10.1 Test Structure (test-mod_login.R)
- Tests are skipped pending auth_system implementation
- Uses `with_test_db()` helper function
- Tests use `testServer()` to test module logic
- Test database fixture setup required

### 10.2 Module Testing Pattern
```r
testServer(mod_login_server, args = list(vals = vals), {
  session$setInputs(userName = "...", passwd = "...", login = 1)
  session$flushReact()
  expect_true(vals$login)
})
```

## 11. ARCHITECTURE DECISIONS AND PRINCIPLES

### 11.1 Separation of Concerns
- **Login module**: Only handles authentication overlay and initial login
- **Settings module**: Handles user settings and password changes
- **eBay auth module**: Handles third-party OAuth flow
- **Helper functions**: Centralized in auth_system.R (to be created)

### 11.2 Module Parameter Passing
- User state passed via `vals` reactiveValues object
- Alert messages passed via `alerts` reactiveValues object
- Current user passed as reactive function (deferred evaluation)

### 11.3 UI/Server Separation
- Clear separation between UI generation and server logic
- UI modules return tag lists for rendering
- Server modules handle all reactive logic and state management

## 12. KEY IMPLEMENTATION NOTES FOR CONSISTENCY

### 12.1 When Creating New Auth-Related Code
1. **Function naming**: Use `authenticate_`, `validate_`, `update_` prefixes
2. **Return structure**: Always return list with `success`, `message`, and data fields
3. **Error messages**: Store in `alerts$user_message` or pass via return value
4. **Namespacing**: Always use `ns()` for all HTML IDs in modules
5. **Reactive values**: Use `reactiveValues()` for multiple related values, `reactiveVal()` for single values
6. **Module parameters**: Pass functional dependencies (reactive functions), not values

### 12.2 UI Component Patterns to Follow
- Use `bslib::card()` for containers (not div)
- Use `bslib::accordion()` for collapsible sections
- Use `icon()` function consistently for Font Awesome icons
- Keep custom CSS scoped with namespace IDs
- Use `conditionalPanel()` for conditional visibility (paired with checkbox)

### 12.3 Reactive Patterns to Follow
- `observe()` for side effects
- `observeEvent()` for triggered actions
- `isolate()` to prevent unwanted reactive dependencies
- `req()` to require inputs before processing
- `withProgress()` for long-running operations

### 12.4 Notification Patterns
- Login errors: Use `shinyjs::html()` and `shinyjs::toggle()` with animations
- Settings alerts: Use `showNotification()` with correct `type` values
- Modal dialogs: Use `showModal(modalDialog(...))` for confirmations
- Status updates: Use `showNotification()` with duration and closeButton

## 13. OUTSTANDING QUESTIONS FOR IMPLEMENTATION

1. **Auth system location**: auth_system.R functions need to be created
2. **User database**: How is users database structured? (SQLite, CSV, file?)
3. **Master user protection**: How are master users identified in database?
4. **Current user**: How is current user passed to child modules in real app?
5. **Session cleanup**: What session cleanup happens on logout?
6. **Multi-user**: What happens to module state when user switches?

---

**Document created**: 2025-11-03
**Delcampe Project**: Authentication Structure Analysis
**Framework**: Golem + Shiny + R6 classes
**Key Files**: mod_login.R, mod_settings_password.R, mod_ebay_auth.R, app_server.R
