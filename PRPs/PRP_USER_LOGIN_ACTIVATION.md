# PRP: User Login System Activation

**Status**: Ready for Implementation
**Priority**: High (Production Blocker)
**Created**: 2025-11-03
**Updated**: 2025-11-03 (Enhanced BASE PRP)
**Category**: Authentication & Security
**Type**: BASE PRP (Implementation-Focused)

---

## Goal

**Feature Goal**: Activate a fully functional, production-ready user authentication system in the Delcampe R/Shiny application with proper session management, password security, and role-based access control.

**Deliverable**: Complete authentication infrastructure including:
- User database with master user protection
- Authentication functions (`authenticate_user`, `create_user`, `update_user_password`, `delete_user`)
- Login/logout UI integration
- Session management across all modules
- Comprehensive test suite

**Success Definition**:
- Users can log in with email/password credentials
- Passwords are stored as SHA-256 hashes
- Two master users exist with deletion protection
- All modules receive authenticated user context
- No hardcoded credentials in codebase
- All critical tests pass

---

## Why

### Business Value
- **Security Compliance**: Production deployment requires proper authentication
- **Multi-User Support**: Enable multiple users with different roles (master, admin, user)
- **Audit Trail**: Track who performed what actions in the system
- **Access Control**: Restrict sensitive operations to authorized users

### Integration with Existing Features
- **Session Tracking**: Link processing sessions to authenticated users
- **eBay Integration**: Associate eBay accounts with specific users
- **Settings Management**: Allow users to manage their own preferences
- **Tracking Viewer**: Filter data by user (admins see all, users see own)

### Problems This Solves
- **Security Risk**: Currently has hardcoded credentials in `R/mod_login.R`
- **No User Context**: Application doesn't track which user is performing actions
- **Incomplete Module**: Login UI exists but not integrated or functional
- **Testing Blocker**: Cannot properly test multi-user scenarios

---

## User Persona

**Target User**: System Administrator / Application User

**Primary Use Cases**:
1. **Login**: User opens application, enters credentials, gains access
2. **Daily Work**: User processes postal cards/stamps with tracking
3. **User Management**: Admin creates new users, manages passwords
4. **Logout**: User securely ends session

**User Journey**:
```
1. User opens Delcampe app → sees login screen
2. Enters email + password → clicks Login
3. System authenticates → shows main application
4. User performs work → all actions tracked to their account
5. Clicks Logout → returns to login screen
```

**Pain Points Addressed**:
- No login security (currently anyone can access)
- Cannot distinguish between users in tracking data
- Cannot manage multiple user accounts
- No way to restrict admin functions

---

## What

### Current State Analysis

**What Exists**:
1. **Login UI Module** (`R/mod_login.R`, 269 lines)
   - Styled interface (green/white theme)
   - **BLOCKER**: Hardcoded credentials (lines 167, 188)
   - Calls undefined functions: `authenticate_user()`, `init_users_file()`
   - **NOT integrated** in app_ui.R or app_server.R

2. **Password Settings Module** (`R/mod_settings_password.R`)
   - Password change functionality
   - Calls undefined: `authenticate_user()`, `update_user_password()`

3. **Database** (`inst/app/data/tracking.sqlite`)
   - Existing tracking tables
   - **MISSING**: `users` table

4. **App Structure** (`R/app_ui.R`, `R/app_server.R`)
   - No `vals` reactiveValues for session state
   - Hardcoded user: `"admin@delcampe.com"` (line 332 of app_server.R)
   - No login integration

**What's Missing**:
1. Authentication system functions (8 functions)
2. Users database table with proper schema
3. Session management via reactiveValues
4. Login/logout integration in main app
5. User context passing to modules
6. Removal of hardcoded credentials

### Success Criteria

**Must Have** (Blocking Production):
- [ ] Users table created with role-based access (master/admin/user)
- [ ] Two master users seeded with secure passwords
- [ ] All 8 authentication functions implemented and tested
- [ ] SHA-256 password hashing implemented (per CLAUDE.md)
- [ ] Login UI integrated and functional
- [ ] Logout button in navbar
- [ ] All hardcoded credentials removed
- [ ] Master user deletion protection enforced
- [ ] Session state (`vals`) available to all modules
- [ ] User context passed to settings and tracking modules
- [ ] All critical tests passing (100%)
- [ ] Manual testing checklist completed

**Should Have** (Post-Launch):
- [ ] User management UI for admins
- [ ] Password reset functionality
- [ ] Session timeout (auto-logout after inactivity)
- [ ] Login attempt rate limiting
- [ ] Audit log for user actions

**Nice to Have** (Future):
- [ ] Two-factor authentication
- [ ] Role-based UI hiding
- [ ] User activity dashboard
- [ ] Email notifications for password changes

---

## All Needed Context

### Context Completeness Check

✅ **"No Prior Knowledge" Test**: This PRP provides:
- Exact file paths and functions to create
- Specific patterns from existing codebase to follow
- Complete code examples for all critical components
- Step-by-step validation commands that work in this project
- Links to documentation with specific sections

### Documentation & References

```yaml
# R PACKAGE DOCUMENTATION (Critical for Password Hashing)
- url: https://cran.r-project.org/web/packages/digest/digest.pdf
  why: SHA-256 hashing per CLAUDE.md requirement (page 3, digest() function)
  critical: Must use serialize=FALSE for string input (not default)
  example: digest("password", algo="sha256", serialize=FALSE)

- url: https://cran.r-project.org/web/packages/sodium/vignettes/intro.html
  why: Alternative (more secure) password hashing if switching from SHA-256
  critical: password_store() auto-generates salts, password_verify() for checking
  note: Research shows this is more secure than SHA-256, but CLAUDE.md specifies SHA-256

- url: https://shiny.posit.co/r/articles/build/modules/
  why: Shiny module patterns for passing reactiveValues between modules
  critical: Section on "Returning values from modules" - pattern we use for user context

- url: https://rstudio.github.io/bslib/reference/page_navbar.html
  why: Our app uses bslib::page_navbar() - understanding structure for login integration
  critical: Conditional rendering pattern for hiding content when not logged in

# CODEBASE PATTERNS TO FOLLOW
- file: R/tracking_database.R
  why: Database connection pattern, tryCatch error handling, DBI usage
  pattern: |
    tryCatch({
      con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
      on.exit(DBI::dbDisconnect(con), add = TRUE)
      # Execute queries
    }, error = function(e) { message("❌ Error: ", e$message); return(NULL) })
  gotcha: Always use on.exit() with add=TRUE, use parameterized queries with params=list()

- file: R/app_server.R
  why: reactiveValues initialization pattern and module calling patterns
  pattern: |
    # Line 138-160: Where to add vals initialization
    # Line 195-200: How modules are called with callbacks
    # Line 332: Current hardcoded user that needs replacement
  gotcha: Module callbacks modify parent reactiveValues, not direct communication

- file: R/mod_login.R
  why: Existing login UI structure and server patterns
  pattern: Login overlay with shinyjs::toggle() for error messages
  gotcha: Lines 167, 188 have hardcoded credentials - MUST REMOVE
  gotcha: Lines 121-136 display test credentials - MUST DELETE ENTIRE SECTION

- file: R/mod_ebay_auth.R
  why: Example of module returning object with multiple properties
  pattern: |
    # Module returns list(api = ..., account_manager = ...)
    # Parent extracts: ebay_api <- ebay_auth$api
  gotcha: Use this pattern if auth system needs to expose multiple functions

- file: tests/testthat/helper-setup.R
  why: Test database setup pattern with_test_db()
  pattern: |
    with_test_db({
      # Automatic in-memory DB creation and cleanup
      # Tests run in isolated environment
    })
  gotcha: Use create_test_user() helper for test user creation

# EXISTING MEMORY FILES
- memory: .serena/memories/database_patterns_and_integration_guide_20251103.md
  why: Complete database patterns from tracking_database.R analysis
  critical: NULL handling (use NA_character_, NA_real_), COALESCE patterns, migration approach

- memory: .serena/memories/authentication_testing_comprehensive_patterns_20251103.md
  why: Complete testing patterns with 40+ ready-to-use test examples
  critical: with_test_db() usage, testServer() patterns, assertion examples

- memory: .serena/memories/testing_infrastructure_complete_20251023.md
  why: Two-suite testing strategy (critical vs discovery)
  critical: How to add tests to critical suite, what makes a test critical
```

### Known Gotchas & Library Quirks

```r
# CRITICAL: R NULL Handling in SQLite
# R's NULL doesn't convert to SQL NULL properly
# ALWAYS use type-specific NA values:
password_hash <- if (!is.null(hash)) as.character(hash) else NA_character_
user_id <- if (!is.null(id)) as.integer(id) else NA_integer_
login_time <- if (!is.null(time)) as.character(time) else NA_character_

# CRITICAL: digest Package for SHA-256
# MUST use serialize=FALSE for password strings (not default!)
hash <- digest::digest(password, algo = "sha256", serialize = FALSE)
# Without serialize=FALSE, you'll hash the R object structure, not the string

# CRITICAL: DBI Parameterized Queries
# ALWAYS use ? placeholders with params list
# CORRECT:
result <- dbGetQuery(con, "SELECT * FROM users WHERE email = ?", params = list(email))
# WRONG (SQL injection risk):
result <- dbGetQuery(con, paste0("SELECT * FROM users WHERE email = '", email, "'"))

# CRITICAL: Shiny showNotification Types
# ONLY these values work: "message", "warning", "error"
# "success" and "default" will cause errors!
showNotification("Login successful", type = "message")  # CORRECT
showNotification("Login failed", type = "error")         # CORRECT
showNotification("Login successful", type = "success")   # ERROR!

# CRITICAL: Module Namespaces with bslib
# In modules, ALWAYS use native bslib components over custom JavaScript
# Custom jQuery/JS onclick handlers FAIL due to namespace issues
# USE: bslib::accordion(), bslib::card(), actionButton() with observeEvent()
# AVOID: Custom shinyjs onclick, HTML with JavaScript inline handlers

# CRITICAL: reactiveValues Initialization
# Must initialize BEFORE calling modules that use it
# Place after database init (line ~160 in app_server.R)
vals <- reactiveValues(
  login = FALSE,
  user_type = NULL,
  user_name = NULL,
  user_data = NULL
)

# CRITICAL: Master User Protection
# Use is_master column (BOOLEAN) to prevent deletion
# Check this in delete_user() function before allowing deletion
if (user$is_master == 1) {
  return(list(success = FALSE, message = "Cannot delete master users"))
}
```

### Current Codebase Structure

```bash
# Key files for authentication implementation
R/
├── app_server.R            # (700+ lines) - Add vals, login module, user context
├── app_ui.R                # (348 lines) - Add login UI, conditional rendering
├── mod_login.R             # (269 lines) - REMOVE hardcoded creds, keep structure
├── mod_settings_password.R # Uses update_user_password() - will work after impl
├── tracking_database.R     # (2600+ lines) - Add initialize_users_table()
└── auth_system.R           # (NEW) - Create all auth functions

inst/app/data/
└── tracking.sqlite         # Extend with users table

tests/testthat/
├── helper-setup.R          # (126 lines) - Has with_test_db(), create_test_user()
├── helper-mocks.R          # (204 lines) - Mock patterns
├── test-auth_system.R      # (NEW) - Create auth function tests
└── test-mod_login.R        # (Exists) - Enhance with integration tests

dev/
├── run_critical_tests.R    # (127 lines) - Add auth tests here when stable
├── cleanup_production_database.R  # (NEW) - Clear test data before production
└── TESTING_GUIDE.md        # Reference for test patterns
```

### Desired Files After Implementation

```bash
R/
├── auth_system.R           # NEW - 300-400 lines
│   ├── hash_password()
│   ├── verify_password()
│   ├── authenticate_user()
│   ├── create_user()
│   ├── get_user_by_email()
│   ├── update_user_password()
│   ├── list_users()
│   └── delete_user()

├── tracking_database.R     # MODIFY - Add initialize_users_table()
│   └── initialize_users_table()  # NEW function

├── app_server.R            # MODIFY - Add vals, login integration
│   ├── vals <- reactiveValues(...)  # NEW
│   └── mod_login_server("login", vals)  # NEW

├── app_ui.R                # MODIFY - Add login UI
│   └── mod_login_ui("login")  # NEW

tests/testthat/
└── test-auth_system.R      # NEW - 400-500 lines, 30+ tests

dev/
└── cleanup_production_database.R  # NEW - 60 lines
```

---

## Implementation Blueprint

### Data Models and Structure

```r
# SQLite Database Schema
# Location: inst/app/data/tracking.sqlite

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK(role IN ('master', 'admin', 'user')),
  is_master BOOLEAN NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  created_by TEXT,
  last_login TEXT,
  active BOOLEAN NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(active);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

# Seed Data (Two Master Users)
INSERT INTO users (email, password_hash, role, is_master, created_at, active)
VALUES
  ('master1@delcampe.com', '<SHA-256 hash>', 'master', 1, CURRENT_TIMESTAMP, 1),
  ('master2@delcampe.com', '<SHA-256 hash>', 'master', 1, CURRENT_TIMESTAMP, 1);
```

### Implementation Tasks (Dependency-Ordered)

```yaml
Task 1: CREATE R/auth_system.R (Core authentication functions)
  - IMPLEMENT: 8 authentication functions
  - FOLLOW pattern: R/tracking_database.R (DBI connection, tryCatch, on.exit)
  - NAMING: snake_case for functions, descriptive names
  - FUNCTIONS:
      hash_password(password) → character
      verify_password(password, stored_hash) → boolean
      authenticate_user(email, password) → list(success, message, user)
      create_user(email, password, role, created_by) → list(success, message)
      get_user_by_email(email) → list or NULL
      update_user_password(email, new_password, current_user_email, current_user_role) → list(success, message)
      list_users(current_user_role) → data.frame
      delete_user(email, current_user_email, current_user_role) → list(success, message)
  - DEPENDENCIES: digest package for SHA-256, DBI/RSQLite for database
  - PLACEMENT: R/ directory (Golem convention for business logic)
  - VALIDATION: Create test file, run devtools::load_all()

Task 2: MODIFY R/tracking_database.R (Add users table initialization)
  - IMPLEMENT: initialize_users_table() function
  - FOLLOW pattern: Existing table initialization in same file (lines 1-100)
  - PLACEMENT: Add function after existing table initialization functions
  - MODIFY: initialize_tracking_db() to call initialize_users_table()
  - INCLUDE: Table creation, indexes, master user seeding
  - DEPENDENCIES: Task 1 (needs hash_password())
  - VALIDATION: Run initialize_tracking_db(), check table with DBI::dbListTables()

Task 3: CREATE tests/testthat/test-auth_system.R (Unit tests)
  - IMPLEMENT: 30+ unit tests covering all auth functions
  - FOLLOW pattern: tests/testthat/helper-setup.R (with_test_db() usage)
  - NAMING: test_{function}_{scenario} pattern
  - COVERAGE:
      Password hashing (2 tests)
      User creation (7 tests: success, duplicate, invalid role, weak password, etc.)
      Authentication (8 tests: success, wrong password, inactive user, etc.)
      Password update (5 tests: own password, admin changing, permission check, etc.)
      User deletion (5 tests: success, master protection, self-deletion, etc.)
      User listing (3 tests: admin view, user view, role filtering)
  - DEPENDENCIES: Tasks 1, 2
  - PLACEMENT: tests/testthat/
  - VALIDATION: source("dev/run_critical_tests.R") - aim for 100% pass

Task 4: MODIFY R/app_server.R (Session management integration)
  - ADD: vals reactiveValues initialization (after line 160, after database init)
  - CALL: mod_login_server("login", vals) (before other modules, line ~170)
  - MODIFY: Replace hardcoded user (line 332) with reactive(vals$user_data)
  - UPDATE: start_processing_session() to use vals$user_name instead of "default_user"
  - PASS: vals$user_data to modules needing user context (settings, tracking)
  - DEPENDENCIES: Task 1 (authenticate_user() must exist)
  - VALIDATION: devtools::load_all(), check no errors on startup

Task 5: MODIFY R/app_ui.R (Login UI integration)
  - ADD: mod_login_ui("login") before main navbar
  - WRAP: Main app content in uiOutput("main_app_ui")
  - DEPENDENCIES: Task 4
  - VALIDATION: Load app, verify login screen appears

Task 6: MODIFY R/app_server.R again (Conditional rendering + logout)
  - ADD: output$main_app_ui <- renderUI({ req(vals$login); <main app> })
  - ADD: Logout button in navbar using nav_item()
  - ADD: observeEvent(input$logout, { reset vals, session$reload() })
  - DEPENDENCIES: Task 5
  - VALIDATION: Login/logout flow works, main app only visible after login

Task 7: MODIFY R/mod_login.R (Remove hardcoded credentials)
  - DELETE: Lines 121-136 (test credentials display section)
  - MODIFY: Line 167 (remove value parameter from textInput)
  - MODIFY: Line 188 (remove value parameter from passwordInput)
  - DEPENDENCIES: None (cleanup task)
  - VALIDATION: No hardcoded credentials in any file (grep search)

Task 8: CREATE dev/cleanup_production_database.R (Production prep)
  - IMPLEMENT: cleanup_production_database() function
  - CLEAR: All tracking tables (preserve schema and users table)
  - INCLUDE: User confirmation prompt, backup reminder
  - DEPENDENCIES: Task 2 (users table must exist)
  - VALIDATION: Run on copy of DB, verify data cleared, users preserved

Task 9: INTEGRATION TESTING (Full system validation)
  - MANUAL TEST: Complete testing checklist (see Validation section)
  - UPDATE: tests/testthat/test-mod_login.R with integration tests
  - RUN: source("dev/run_critical_tests.R") - must pass 100%
  - DEPENDENCIES: All previous tasks
  - VALIDATION: All manual and automated tests pass
```

### Implementation Patterns & Key Details

```r
# ==== PATTERN 1: Password Hashing (SHA-256 per CLAUDE.md) ====
# Location: R/auth_system.R

library(digest)

hash_password <- function(password) {
  # CRITICAL: Use serialize=FALSE for string input (not default)
  digest::digest(password, algo = "sha256", serialize = FALSE)
}

verify_password <- function(password, stored_hash) {
  # Compare hashes (constant-time comparison would be ideal, but identical() is acceptable)
  computed_hash <- hash_password(password)
  identical(computed_hash, stored_hash)
}

# ==== PATTERN 2: Database Connection (From tracking_database.R) ====
# Standard pattern used throughout codebase

authenticate_user <- function(email, password) {
  tryCatch({
    # Open connection
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    # CRITICAL: Always use on.exit for cleanup with add=TRUE
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    # CRITICAL: Use parameterized query (prevent SQL injection)
    user <- DBI::dbGetQuery(
      con,
      "SELECT * FROM users WHERE email = ? AND active = 1",
      params = list(email)
    )

    # Check if user exists
    if (nrow(user) == 0) {
      return(list(
        success = FALSE,
        message = "Invalid email or password",  # Generic message (security)
        user = NULL
      ))
    }

    # Verify password
    if (!verify_password(password, user$password_hash[1])) {
      return(list(
        success = FALSE,
        message = "Invalid email or password",  # Same message (security)
        user = NULL
      ))
    }

    # Update last login
    DBI::dbExecute(
      con,
      "UPDATE users SET last_login = ? WHERE id = ?",
      params = list(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), user$id[1])
    )

    # Success
    return(list(
      success = TRUE,
      message = "Authentication successful",
      user = as.list(user[1, ])  # Convert first row to list
    ))

  }, error = function(e) {
    # PATTERN: Consistent error message format
    message("❌ Error in authenticate_user: ", e$message)
    return(list(success = FALSE, message = "Authentication error", user = NULL))
  })
}

# ==== PATTERN 3: Master User Protection ====
delete_user <- function(email, current_user_email, current_user_role) {
  # Check permissions
  if (!current_user_role %in% c("admin", "master")) {
    return(list(success = FALSE, message = "Insufficient permissions"))
  }

  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    # Get target user
    target_user <- DBI::dbGetQuery(
      con,
      "SELECT id, email, is_master FROM users WHERE email = ?",
      params = list(email)
    )

    if (nrow(target_user) == 0) {
      return(list(success = FALSE, message = "User not found"))
    }

    # CRITICAL: Master user protection (per CLAUDE.md)
    if (target_user$is_master[1] == 1) {
      return(list(success = FALSE, message = "Cannot delete master users"))
    }

    # Cannot delete yourself
    if (email == current_user_email) {
      return(list(success = FALSE, message = "Cannot delete your own account"))
    }

    # Soft delete (set active = 0)
    DBI::dbExecute(
      con,
      "UPDATE users SET active = 0 WHERE email = ?",
      params = list(email)
    )

    message("✅ User deleted: ", email)
    return(list(success = TRUE, message = "User deleted successfully"))

  }, error = function(e) {
    message("❌ Error deleting user: ", e$message)
    return(list(success = FALSE, message = paste("Error:", e$message)))
  })
}

# ==== PATTERN 4: reactiveValues Initialization (app_server.R) ====
# Location: R/app_server.R, line ~160 (after database initialization)

app_server <- function(input, output, session) {
  # ... existing error handling and database init ...

  # Initialize authentication state
  vals <- reactiveValues(
    login = FALSE,           # Boolean: user logged in?
    user_type = NULL,        # String: "master", "admin", or "user"
    user_name = NULL,        # String: user email
    user_data = NULL         # List: complete user record
  )

  # Login module (MUST be called before other modules)
  mod_login_server("login", vals)

  # ... rest of server logic ...
}

# ==== PATTERN 5: Conditional UI Rendering (app_server.R) ====
# Location: R/app_server.R

output$main_app_ui <- renderUI({
  # CRITICAL: req() stops execution if login is FALSE
  req(vals$login)

  # Main application (only shown when logged in)
  bslib::page_navbar(
    title = "Delcampe Image Processor",
    # ... all existing navbar content ...
  )
})

# ==== PATTERN 6: User Context Passing to Modules ====
# Location: R/app_server.R

# BEFORE (hardcoded):
mod_settings_server(
  "settings",
  reactive(list(email = "admin@delcampe.com", role = "admin"))
)

# AFTER (dynamic from login):
mod_settings_server(
  "settings",
  current_user = reactive(vals$user_data)
)

# Tracking viewer with user filter
mod_tracking_viewer_server(
  "tracking_viewer_1",
  current_user = reactive(vals$user_data)
)

# ==== PATTERN 7: Test Database Setup ====
# Location: tests/testthat/test-auth_system.R

test_that("authenticate_user succeeds with valid credentials", {
  # Helper function creates isolated in-memory DB
  with_test_db({
    # Create test user
    create_user("alice@example.com", "password123", "user", "admin@example.com")

    # Test authentication
    result <- authenticate_user("alice@example.com", "password123")

    # Assertions
    expect_true(result$success)
    expect_equal(result$user$email, "alice@example.com")
    expect_equal(result$user$role, "user")
  })
  # DB automatically cleaned up after test
})

# ==== PATTERN 8: Logout Implementation ====
# Location: R/app_server.R

# In UI (navbar):
bslib::nav_item(
  actionButton(
    "logout",
    "Logout",
    icon = icon("sign-out-alt"),
    class = "btn-outline-secondary"
  )
)

# In server:
observeEvent(input$logout, {
  # Optional: Log the logout event
  if (!is.null(vals$user_name)) {
    message("✅ User logged out: ", vals$user_name)
  }

  # Reset session state
  vals$login <- FALSE
  vals$user_type <- NULL
  vals$user_name <- NULL
  vals$user_data <- NULL

  # Reload app to show login screen
  session$reload()
})
```

### Integration Points

```yaml
DATABASE:
  - table: users (new table in tracking.sqlite)
  - migration: ALTER TABLE tracking_sessions ADD COLUMN user_id TEXT (future)
  - index: CREATE INDEX idx_users_email, idx_users_active, idx_users_role

MODULES_REQUIRING_USER_CONTEXT:
  - mod_settings_server: Pass reactive(vals$user_data) as current_user
  - mod_tracking_viewer_server: Pass reactive(vals$user_data) for filtering
  - mod_ebay_auth_server: Consider linking eBay accounts to users (future)

SESSION_TRACKING:
  - update: start_processing_session(session_id, user_id = vals$user_name, ...)
  - update: track_session_activity() to include user_id

UI_CHANGES:
  - app_ui.R: Add mod_login_ui("login") before main content
  - app_ui.R: Wrap main app in uiOutput("main_app_ui")
  - app_server.R: Add renderUI for conditional display
  - navbar: Add logout button in nav_item()
```

---

## Validation Loop

### Level 1: Syntax & Development (Immediate Feedback)

```bash
# After creating R/auth_system.R
devtools::load_all()                 # Load all functions into environment
# Expected: No errors, functions available

# After modifying any R file
devtools::load_all()
# Expected: Changes reflected, no syntax errors

# Check for hardcoded credentials (MUST return nothing)
grep -r "marius.tita81@gmail.com" R/
grep -r "admin123" R/
# Expected: No matches (after Task 7 complete)
```

### Level 2: Unit Tests (Component Validation)

```bash
# Test authentication functions
devtools::load_all()
testthat::test_file("tests/testthat/test-auth_system.R")
# Expected: All tests pass (30+ tests)

# Run all critical tests
source("dev/run_critical_tests.R")
# Expected: ~200+ tests pass (existing ~170 + new auth ~30)

# Test coverage (optional but recommended)
covr::package_coverage()
# Expected: Auth system functions >80% covered
```

### Level 3: Integration Testing (System Validation)

```bash
# Manual Testing Checklist

## 1. Database Initialization
devtools::load_all()
initialize_tracking_db()
# Verify:
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
DBI::dbListTables(con)  # Should include "users"
DBI::dbGetQuery(con, "SELECT email, role, is_master FROM users WHERE is_master = 1")
# Expected: 2 master users
DBI::dbDisconnect(con)

## 2. Authentication Functions
# Test in R console:
result <- authenticate_user("master1@delcampe.com", "<master_password>")
result$success  # Should be TRUE

result <- authenticate_user("master1@delcampe.com", "wrong_password")
result$success  # Should be FALSE

## 3. User Management
create_user("test@example.com", "testpass123", "user", "master1@delcampe.com")
# Expected: success = TRUE

create_user("test@example.com", "different", "user", "master1@delcampe.com")
# Expected: success = FALSE (duplicate email)

## 4. Launch Application
devtools::load_all()
golem::run_dev()
# Expected: Login screen appears

## 5. Login Flow
# In browser:
# - Enter master1@delcampe.com + password
# - Click Login
# Expected: Main app appears, no errors

## 6. User Context Verification
# While logged in:
# - Navigate to Settings
# - Verify correct email shown
# - Navigate to Tracking
# - Verify user context available

## 7. Logout Flow
# Click Logout button
# Expected: Return to login screen, session cleared

## 8. Master User Protection
# Login as master1
# Try to delete master2 via console:
delete_user("master2@delcampe.com", "master1@delcampe.com", "master")
# Expected: success = FALSE, message about master protection

## 9. Password Change
# In Settings → Password:
# - Change password
# - Logout
# - Login with new password
# Expected: Works correctly

## 10. Multi-User Test
# Create regular user via console
# Logout, login as regular user
# Try to access admin functions
# Expected: Proper permission checks
```

### Level 4: Production Preparation

```bash
# Clean test data
source("dev/cleanup_production_database.R")
# Follow prompts, type "YES" to confirm
# Expected: All tracking tables cleared, users table with only master users

# Verify clean state
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
DBI::dbGetQuery(con, "SELECT COUNT(*) FROM users WHERE is_master = 1")
# Expected: 2 (master users)
DBI::dbGetQuery(con, "SELECT COUNT(*) FROM users WHERE is_master = 0")
# Expected: 0 (test users removed)
DBI::dbGetQuery(con, "SELECT COUNT(*) FROM processing_sessions")
# Expected: 0 (sessions cleared)
DBI::dbDisconnect(con)

# Final security check
grep -r "password.*=" R/ | grep -v "password_hash"
# Expected: No hardcoded passwords

# Test production startup
devtools::load_all()
golem::run_dev()
# Expected: Clean login screen, no test data visible
```

---

## Final Validation Checklist

### Technical Validation

- [ ] All 8 authentication functions implemented in `R/auth_system.R`
- [ ] Users table exists with correct schema (9 columns, 3 indexes)
- [ ] Two master users seeded with secure passwords
- [ ] All unit tests pass: `source("dev/run_critical_tests.R")` shows 100%
- [ ] No syntax errors: `devtools::load_all()` succeeds
- [ ] No hardcoded credentials: `grep` searches return empty

### Feature Validation

- [ ] Login with valid credentials succeeds
- [ ] Login with invalid credentials fails with generic error
- [ ] Logout resets session and returns to login screen
- [ ] Main app only visible when `vals$login == TRUE`
- [ ] Settings page shows correct logged-in user email
- [ ] Tracking viewer receives user context
- [ ] Master user deletion returns error
- [ ] Regular user creation/deletion works
- [ ] Password change works for own password
- [ ] Admin can change any non-master user password

### Code Quality Validation

- [ ] Follows `R/tracking_database.R` patterns (tryCatch, on.exit, DBI)
- [ ] Uses parameterized queries (no SQL injection risk)
- [ ] Proper error messages (❌, ✅ emojis per project convention)
- [ ] Functions return consistent list(success, message, ...) format
- [ ] Tests use `with_test_db()` pattern from helper-setup.R
- [ ] Module integration follows existing patterns from app_server.R

### Security Validation

- [ ] All passwords stored as SHA-256 hashes (verified in DB)
- [ ] Master user deletion protection enforced
- [ ] Generic error messages (don't reveal if email exists)
- [ ] Session cleanup on disconnect (session$onSessionEnded)
- [ ] No passwords in logs or console output
- [ ] Active user check (active = 1) in authentication

### Documentation & Cleanup

- [ ] Production database cleaned: `cleanup_production_database.R` executed
- [ ] Only master users remain in database
- [ ] All test sessions/cards/stamps removed
- [ ] Database file size optimized (VACUUM executed)
- [ ] Backup of previous state created in `Delcampe_BACKUP/`

---

## Anti-Patterns to Avoid

**Authentication**:
- ❌ Don't use plain text passwords (always hash with SHA-256)
- ❌ Don't reveal whether email exists in error messages (always "Invalid email or password")
- ❌ Don't skip master user protection checks
- ❌ Don't allow users to delete themselves
- ❌ Don't implement custom crypto (use digest package)

**Database**:
- ❌ Don't concatenate SQL strings (use parameterized queries)
- ❌ Don't forget on.exit(dbDisconnect()) (causes connection leaks)
- ❌ Don't use R NULL for SQL NULL (use NA_character_, NA_real_, NA_integer_)
- ❌ Don't hard-delete users (use soft delete with active = 0)

**Shiny Patterns**:
- ❌ Don't use showNotification(type = "success") (will error, use "message")
- ❌ Don't pass reactiveValues directly to modules (wrap in reactive())
- ❌ Don't use conditionalPanel for security (use server-side req())
- ❌ Don't forget req(vals$login) before rendering protected content

**Testing**:
- ❌ Don't skip tests (they're mandatory per CLAUDE.md)
- ❌ Don't test against production database (use with_test_db())
- ❌ Don't add tests to critical suite until they're stable (start in discovery)

---

## Risk Assessment & Mitigation

### Risk 1: Breaking Existing Modules
**Impact**: High
**Likelihood**: Medium
**Mitigation**:
- Pass `vals` only to modules that explicitly need it
- Make `current_user` parameter optional with default `NULL`
- Test each module individually after integration
- Run full test suite after each integration change

### Risk 2: Database Migration Issues
**Impact**: High
**Likelihood**: Low
**Mitigation**:
- Backup `tracking.sqlite` before any changes: `cp inst/app/data/tracking.sqlite inst/app/data/tracking.sqlite.backup.$(date +%Y%m%d)`
- Test migration on copy first
- Use `CREATE TABLE IF NOT EXISTS` for idempotency
- Verify with `DBI::dbListTables()` after migration

### Risk 3: Password Security Vulnerability
**Impact**: Critical
**Likelihood**: Low (with proper implementation)
**Mitigation**:
- Use digest package exactly as specified in patterns
- Test hash/verify functions thoroughly
- Never log passwords (not even in error messages)
- Use generic error messages
- Consider upgrading to sodium package if security requirements increase

### Risk 4: Test Failures
**Impact**: Medium
**Likelihood**: Medium
**Mitigation**:
- Run critical tests frequently during development
- Fix tests immediately when they break
- Use `with_test_db()` to isolate tests
- Start with discovery suite, move to critical when stable

---

## Timeline Estimate

**Total**: 12-15 hours of focused development

| Phase | Tasks | Estimate | Cumulative |
|-------|-------|----------|------------|
| Phase 1: Core Auth | Tasks 1-3 | 5 hours | 5 hours |
| Phase 2: Integration | Tasks 4-6 | 3 hours | 8 hours |
| Phase 3: Cleanup | Tasks 7-8 | 2 hours | 10 hours |
| Phase 4: Testing | Task 9 | 3 hours | 13 hours |
| Contingency | - | 2 hours | 15 hours |

**Recommended Schedule**: Split across 2-3 days
- Day 1: Tasks 1-3 (core auth + tests)
- Day 2: Tasks 4-7 (integration + cleanup)
- Day 3: Tasks 8-9 (production prep + validation)

---

## Dependencies

### Required Before Starting
1. ✅ Backup current database: `cp inst/app/data/tracking.sqlite inst/app/data/tracking.sqlite.backup`
2. ✅ Review CLAUDE.md authentication principles
3. ✅ Review testing infrastructure: `dev/TESTING_GUIDE.md`
4. ✅ Install required packages: `install.packages(c("digest", "DBI", "RSQLite"))`

### Blocking This Work
None - ready to start immediately

---

## References & Documentation

### Project Documentation
- **Architecture**: `CLAUDE.md` - Authentication Architecture, Security Principles
- **Testing**: `dev/TESTING_GUIDE.md` - Comprehensive testing guide
- **Database**: `R/tracking_database.R` - Existing database patterns (2600+ lines)
- **Modules**: `R/mod_login.R` (269 lines), `R/mod_settings_password.R` - Existing auth UI

### Memory Files
- `.serena/memories/database_patterns_and_integration_guide_20251103.md` - Complete DB patterns
- `.serena/memories/authentication_testing_comprehensive_patterns_20251103.md` - Testing patterns
- `.serena/memories/authentication_testing_ready_examples_20251103.md` - 40+ test examples
- `.serena/memories/testing_infrastructure_complete_20251023.md` - Two-suite strategy

### External Documentation
- **digest Package**: https://cran.r-project.org/web/packages/digest/digest.pdf (SHA-256, page 3)
- **sodium Package**: https://cran.r-project.org/web/packages/sodium/vignettes/intro.html (Alternative)
- **Shiny Modules**: https://shiny.posit.co/r/articles/build/modules/ (Module patterns)
- **bslib**: https://rstudio.github.io/bslib/reference/page_navbar.html (UI framework)
- **Security Best Practices**: https://mastering-shiny.org/scaling-security.html

---

## Implementation Confidence Score: 9/10

**Why High Confidence**:
- ✅ Complete codebase analysis with exact patterns
- ✅ All integration points identified and documented
- ✅ Comprehensive test infrastructure ready
- ✅ Database patterns well-established
- ✅ Clear dependency ordering
- ✅ Existing UI already built and styled
- ✅ All helper functions and patterns documented
- ✅ Security requirements clearly defined

**Remaining 10% Risk**:
- Edge cases in module integration
- Potential reactivity chain issues
- First-time implementation challenges

**Mitigation**: Incremental implementation with testing after each task ensures early detection of issues.

---

## Notes

- The login module UI is already beautifully styled and ready to use (no UI work needed)
- The password management module is well-structured (will work immediately after auth system is implemented)
- Main work is backend infrastructure (auth functions, database, integration)
- This is a **production blocker** - application cannot be deployed without proper authentication
- Consider this PRP "Phase 1" - user management UI can be added as "Phase 2" post-launch
- The two-suite testing strategy allows rapid development (critical tests) while preserving exploration value (discovery tests)

---

**Status**: This PRP is complete and ready for implementation. All context, patterns, and validation procedures are specified. An AI agent or developer unfamiliar with the codebase should be able to implement this feature successfully using only this document and the referenced files.
