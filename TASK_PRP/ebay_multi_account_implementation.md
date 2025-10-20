# TASK PRP: eBay Multi-Account Implementation (Sandbox Testing)

## Overview

Implement multi-account support for eBay integration, allowing users to connect and switch between multiple eBay seller accounts. Focus on **sandbox testing** to validate architecture.

## Context

### Documentation
```yaml
docs:
  - url: https://developer.ebay.com/api-docs/commerce/identity/overview.html
    focus: GET /user/ endpoint for fetching eBay username
  - url: https://developer.ebay.com/api-docs/static/oauth-scopes.html
    focus: Verify identity scope included in existing OAuth

patterns:
  - file: R/ebay_api.R:62-272
    copy: EbayOAuth R6 class pattern for new methods
  - file: R/mod_ebay_auth.R
    context: Existing auth module to be enhanced
  - file: .serena/memories/ebay_oauth_integration_complete_20251017.md
    context: Current OAuth implementation details

gotchas:
  - issue: "User info API requires valid access token"
    fix: "Call get_user_info() AFTER successful token exchange"
  - issue: "Account key must be unique per user+environment"
    fix: "Format: {user_id}_{environment}"
  - issue: "Token refresh must update correct account in storage"
    fix: "Pass account_key to update_account_tokens()"
  - issue: "Switching accounts must reinitialize API with new tokens"
    fix: "Call init_ebay_api() then inject tokens with set_tokens()"
```

## Prerequisites

**User Actions Required:**
1. **Sandbox Test User 1** - Have credentials ready for first account
2. **Sandbox Test User 2** - Have different sandbox credentials for testing switching
3. **Backup Existing Tokens** - If any exist, copy `data/ebay_tokens.rds` to safe location

---

## Task Sequence

### PHASE 1: Core Account Manager

#### TASK 1.1: Create EbayAccountManager Class
**File:** `R/ebay_account_manager.R` (NEW)

**Action:** Create complete R6 class for multi-account management

**Implementation:**
```r
#' eBay Account Manager
#'
#' Manages multiple eBay seller accounts with token persistence
#'
#' @export
EbayAccountManager <- R6::R6Class("EbayAccountManager",
  private = list(
    accounts_file = "inst/app/data/ebay_accounts.rds",
    accounts = list(),
    active_account_key = NULL
  ),

  public = list(
    initialize = function() {
      # Load existing accounts
      self$load_accounts()

      # Auto-migrate old single-account tokens
      self$migrate_old_tokens()
    },

    # Add newly authenticated account
    add_account = function(user_id, username, environment,
                          access_token, refresh_token, token_expiry) {
      account_key <- paste(user_id, environment, sep = "_")

      private$accounts[[account_key]] <- list(
        user_id = user_id,
        username = username,
        environment = environment,
        access_token = access_token,
        refresh_token = refresh_token,
        token_expiry = token_expiry,
        connected_at = Sys.time(),
        last_used = Sys.time()
      )

      # Set as active if first account or no active account
      if (is.null(private$active_account_key) ||
          !private$active_account_key %in% names(private$accounts)) {
        private$active_account_key <- account_key
      }

      self$save_accounts()

      message("Added account: ", username, " (", environment, ")")
      return(account_key)
    },

    # Remove specific account
    remove_account = function(account_key) {
      if (!account_key %in% names(private$accounts)) {
        warning("Account not found: ", account_key)
        return(FALSE)
      }

      username <- private$accounts[[account_key]]$username
      private$accounts[[account_key]] <- NULL

      # If removed active account, switch to first available
      if (private$active_account_key == account_key) {
        if (length(private$accounts) > 0) {
          private$active_account_key <- names(private$accounts)[1]
          message("Switched to: ", private$accounts[[private$active_account_key]]$username)
        } else {
          private$active_account_key <- NULL
          message("No accounts remaining")
        }
      }

      self$save_accounts()
      message("Removed account: ", username)
      return(TRUE)
    },

    # Switch active account
    set_active_account = function(account_key) {
      if (!account_key %in% names(private$accounts)) {
        warning("Account not found: ", account_key)
        return(FALSE)
      }

      private$active_account_key <- account_key
      private$accounts[[account_key]]$last_used <- Sys.time()
      self$save_accounts()

      message("Active account: ", private$accounts[[account_key]]$username)
      return(TRUE)
    },

    # Get active account details
    get_active_account = function() {
      if (is.null(private$active_account_key)) return(NULL)
      if (!private$active_account_key %in% names(private$accounts)) return(NULL)

      account <- private$accounts[[private$active_account_key]]
      account$account_key <- private$active_account_key  # Include key
      return(account)
    },

    # Get all accounts
    get_all_accounts = function() {
      return(private$accounts)
    },

    # Get account choices for dropdown (formatted)
    get_account_choices = function() {
      if (length(private$accounts) == 0) return(NULL)

      choices <- sapply(names(private$accounts), function(key) {
        account <- private$accounts[[key]]
        paste0(account$username, " (", account$environment, ")")
      }, USE.NAMES = TRUE)

      return(choices)
    },

    # Update tokens for specific account (after refresh)
    update_account_tokens = function(account_key, access_token,
                                    refresh_token, token_expiry) {
      if (!account_key %in% names(private$accounts)) {
        warning("Account not found for token update: ", account_key)
        return(FALSE)
      }

      private$accounts[[account_key]]$access_token <- access_token
      private$accounts[[account_key]]$refresh_token <- refresh_token
      private$accounts[[account_key]]$token_expiry <- token_expiry

      self$save_accounts()
      return(TRUE)
    },

    # Save accounts to file
    save_accounts = function() {
      # Ensure directory exists
      dir.create(dirname(private$accounts_file), recursive = TRUE, showWarnings = FALSE)

      data <- list(
        accounts = private$accounts,
        active_account = private$active_account_key,
        last_updated = Sys.time()
      )

      saveRDS(data, file = private$accounts_file)
    },

    # Load accounts from file
    load_accounts = function() {
      if (file.exists(private$accounts_file)) {
        tryCatch({
          data <- readRDS(private$accounts_file)
          private$accounts <- data$accounts
          private$active_account_key <- data$active_account

          message("Loaded ", length(private$accounts), " account(s)")
        }, error = function(e) {
          warning("Failed to load accounts: ", e$message)
        })
      }
    },

    # Migrate old single-account tokens
    migrate_old_tokens = function() {
      old_file <- "inst/app/data/ebay_tokens.rds"
      new_file <- private$accounts_file

      # Only migrate if old exists and new doesn't
      if (file.exists(old_file) && !file.exists(new_file)) {
        message("Migrating old eBay tokens to multi-account format...")

        tryCatch({
          old_data <- readRDS(old_file)

          # Initialize temporary API with old tokens
          temp_api <- init_ebay_api(environment = old_data$environment)
          temp_api$oauth$set_tokens(
            old_data$access_token,
            old_data$refresh_token,
            old_data$token_expiry
          )

          # Fetch user identity
          user_info <- temp_api$oauth$get_user_info()

          if (user_info$success) {
            # Add as first account
            self$add_account(
              user_id = user_info$user_id,
              username = user_info$username,
              environment = old_data$environment,
              access_token = old_data$access_token,
              refresh_token = old_data$refresh_token,
              token_expiry = old_data$token_expiry
            )

            # Backup old file
            file.rename(old_file, paste0(old_file, ".backup"))

            message("✅ Migration successful: ", user_info$username)
          } else {
            warning("Failed to fetch user info during migration: ", user_info$error)
          }
        }, error = function(e) {
          warning("Token migration failed: ", e$message)
        })
      }
    }
  )
)
```

**Validate:**
```r
# Test in R console
source("R/ebay_account_manager.R")

# Create manager
manager <- EbayAccountManager$new()

# Add test account manually
manager$add_account(
  user_id = "test123",
  username = "test_seller",
  environment = "sandbox",
  access_token = "fake_token",
  refresh_token = "fake_refresh",
  token_expiry = Sys.time() + 3600
)

# Verify
manager$get_active_account()  # Should return account details
manager$get_account_choices()  # Should return formatted dropdown choices
```

**If_Fail:**
- R6 class error → Check R6 package installed
- File write error → Verify inst/app/data/ directory exists
- Method not found → Check method names and syntax

**Rollback:**
```bash
rm R/ebay_account_manager.R
```

---

#### TASK 1.2: Enhance EbayOAuth with User Info API
**File:** `R/ebay_api.R`
**Lines:** Add to EbayOAuth class (after line 272)

**Action:** Add two new methods to fetch user info and inject tokens

**Implementation:**
```r
# In EbayOAuth class, add to public list:

# Fetch eBay user identity
get_user_info = function() {
  token <- self$get_access_token()

  if (is.null(token)) {
    return(list(
      success = FALSE,
      error = "No access token available"
    ))
  }

  user_url <- paste0(
    private$config$get_base_url(),
    "/commerce/identity/v1/user/"
  )

  tryCatch({
    response <- request(user_url) |>
      req_headers("Authorization" = paste("Bearer", token)) |>
      req_perform()

    user_data <- resp_body_json(response)

    return(list(
      success = TRUE,
      user_id = user_data$userId,
      username = user_data$username
    ))

  }, error = function(e) {
    # Extract detailed error if possible
    error_msg <- tryCatch({
      if (exists("response")) {
        error_body <- resp_body_json(response)
        error_body$errors[[1]]$message
      } else {
        e$message
      }
    }, error = function(e2) e$message)

    return(list(
      success = FALSE,
      error = error_msg
    ))
  })
},

# Inject stored tokens (for account switching)
set_tokens = function(access_token, refresh_token, token_expiry) {
  private$access_token <- access_token
  private$refresh_token <- refresh_token
  private$token_expiry <- token_expiry

  message("Tokens injected (expires: ", format(token_expiry, "%H:%M"), ")")
}
```

**Validate:**
```r
# Test with existing sandbox token
source("R/ebay_api.R")
api <- init_ebay_api(environment = "sandbox")

# If you have valid token, test get_user_info
# (Otherwise this will fail until you authorize)
user_info <- api$oauth$get_user_info()
print(user_info)  # Should return success = TRUE, user_id, username

# Test set_tokens
api$oauth$set_tokens("test_token", "test_refresh", Sys.time() + 3600)
# Check private fields injected correctly
```

**If_Fail:**
- 401 Unauthorized → Token expired or invalid, authorize first
- 404 Not Found → Check endpoint URL (should be /commerce/identity/v1/user/)
- Network error → Check internet connection

**Rollback:**
```bash
git checkout R/ebay_api.R
```

---

### PHASE 2: UI Updates

#### TASK 2.1: Update mod_ebay_auth UI
**File:** `R/mod_ebay_auth.R`
**Lines:** Replace entire UI function (lines 6-68)

**Action:** Replace with multi-account aware UI

**New Code:**
```r
#' eBay Authentication UI Module
#' @export
mod_ebay_auth_ui <- function(id) {
  ns <- NS(id)

  bslib::card(
    bslib::card_header(
      class = "d-flex justify-content-between align-items-center",
      "eBay Account Management",
      uiOutput(ns("connection_badge"))
    ),
    bslib::card_body(
      # Active account display
      uiOutput(ns("active_account_status")),

      # Account switcher (shown when multiple accounts exist)
      conditionalPanel(
        condition = "output.has_multiple_accounts == true",
        ns = ns,
        div(
          class = "mb-3",
          selectInput(
            ns("account_selector"),
            "Switch to Account:",
            choices = NULL,
            width = "100%"
          ),
          actionButton(
            ns("switch_account"),
            "Switch Account",
            icon = icon("exchange-alt"),
            class = "btn-info btn-sm w-100"
          )
        )
      ),

      hr(),

      # Action buttons
      div(
        class = "d-grid gap-2",
        actionButton(
          ns("connect_new"),
          "Connect New Account",
          icon = icon("plus-circle"),
          class = "btn-success"
        ),
        actionButton(
          ns("disconnect_current"),
          "Disconnect Current Account",
          icon = icon("unlink"),
          class = "btn-warning"
        ),
        actionButton(
          ns("refresh_status"),
          "Refresh Status",
          icon = icon("sync"),
          class = "btn-secondary btn-sm"
        )
      ),

      # OAuth flow (shown when connecting new account)
      conditionalPanel(
        condition = paste0("input['", ns("show_oauth_flow"), "'] == true"),
        div(
          class = "mt-3 p-3 border rounded bg-light",
          h5("Connect eBay Account"),

          p(strong("Step 1:"), " Click to authorize"),
          actionButton(
            ns("start_oauth"),
            "Authorize with eBay (Sandbox)",
            icon = icon("external-link-alt"),
            class = "btn-primary w-100 mb-3"
          ),

          hr(),

          p(strong("Step 2:"), " After authorizing, paste the code here:"),
          textInput(
            ns("auth_code"),
            NULL,
            placeholder = "Paste authorization code from URL"
          ),
          actionButton(
            ns("submit_code"),
            "Submit Code",
            icon = icon("check"),
            class = "btn-success w-100"
          ),

          hr(),

          actionButton(
            ns("cancel_oauth"),
            "Cancel",
            class = "btn-secondary btn-sm w-100"
          )
        )
      ),

      # Hidden checkbox for conditional panel
      div(
        style = "display: none;",
        checkboxInput(ns("show_oauth_flow"), "", value = FALSE)
      )
    )
  )
}
```

**Validate:**
- Load app and navigate to eBay section
- UI should render without errors
- Buttons should be visible
- No OAuth flow shown initially (collapsed)

**If_Fail:**
- bslib error → Check bslib package version
- NS error → Verify ns() wrapping all IDs
- Layout broken → Check bslib::card syntax

**Rollback:**
```bash
git checkout R/mod_ebay_auth.R
```

---

#### TASK 2.2: Update mod_ebay_auth Server Logic
**File:** `R/mod_ebay_auth.R`
**Lines:** Replace entire server function (lines 72-240)

**Action:** Implement multi-account server logic

**New Code:**
```r
#' eBay Authentication Server Module
#' @export
mod_ebay_auth_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Initialize account manager
    account_manager <- EbayAccountManager$new()

    # Current API instance (for active account)
    current_api <- reactiveVal(NULL)

    # Initialize on startup
    observe({
      initialize_api_for_active_account()
      update_ui()
    })

    # Helper: Initialize API for active account
    initialize_api_for_active_account <- function() {
      active <- account_manager$get_active_account()

      if (!is.null(active)) {
        # Create API instance with account's environment
        api <- init_ebay_api(environment = active$environment)

        # Inject stored tokens
        api$oauth$set_tokens(
          access_token = active$access_token,
          refresh_token = active$refresh_token,
          token_expiry = active$token_expiry
        )

        current_api(api)
      } else {
        current_api(NULL)
      }
    }

    # Helper: Update all UI elements
    update_ui <- function() {
      update_active_account_display()
      update_account_selector()
      update_connection_badge()
    }

    # Update active account display
    update_active_account_display <- function() {
      output$active_account_status <- renderUI({
        active <- account_manager$get_active_account()

        if (is.null(active)) {
          div(
            class = "alert alert-warning",
            icon("exclamation-circle"),
            strong(" No eBay account connected"),
            br(),
            small("Click 'Connect New Account' to get started")
          )
        } else {
          div(
            class = "alert alert-success",
            icon("check-circle"),
            strong(" Active Account: "), active$username,
            br(),
            small("Environment: ", active$environment),
            br(),
            small("Connected: ", format(active$connected_at, "%Y-%m-%d %H:%M"))
          )
        }
      })
    }

    # Update account selector dropdown
    update_account_selector <- function() {
      choices <- account_manager$get_account_choices()
      active <- account_manager$get_active_account()
      active_key <- if (!is.null(active)) active$account_key else NULL

      if (!is.null(choices) && length(choices) > 0) {
        updateSelectInput(
          session,
          "account_selector",
          choices = choices,
          selected = active_key
        )
      }
    }

    # Update connection badge
    output$connection_badge <- renderUI({
      active <- account_manager$get_active_account()
      all_accounts <- account_manager$get_all_accounts()

      if (is.null(active)) {
        span(class = "badge bg-secondary", "Not Connected")
      } else {
        span(
          class = "badge bg-success",
          length(all_accounts), " Account(s)"
        )
      }
    })

    # Has multiple accounts? (for conditional panel)
    output$has_multiple_accounts <- reactive({
      length(account_manager$get_all_accounts()) > 1
    })
    outputOptions(output, "has_multiple_accounts", suspendWhenHidden = FALSE)

    # Connect new account
    observeEvent(input$connect_new, {
      updateCheckboxInput(session, "show_oauth_flow", value = TRUE)
    })

    # Cancel OAuth flow
    observeEvent(input$cancel_oauth, {
      updateCheckboxInput(session, "show_oauth_flow", value = FALSE)
      updateTextInput(session, "auth_code", value = "")
    })

    # Start OAuth flow
    observeEvent(input$start_oauth, {
      # Always use sandbox for testing
      temp_api <- init_ebay_api(environment = "sandbox")
      auth_url <- temp_api$oauth$generate_auth_url()

      # Open browser
      browseURL(auth_url)

      showNotification(
        "Browser opened for eBay authorization. After authorizing, paste the code below.",
        duration = 10,
        type = "message"
      )
    })

    # Submit authorization code
    observeEvent(input$submit_code, {
      req(input$auth_code)

      withProgress(message = "Connecting eBay account...", {
        # Create temp API for sandbox
        temp_api <- init_ebay_api(environment = "sandbox")

        # Exchange code for token
        setProgress(0.3, detail = "Exchanging code for token")
        token_result <- temp_api$oauth$get_user_token(input$auth_code)

        if (!token_result$success) {
          showNotification(
            paste("Authentication failed:", token_result$error),
            type = "error",
            duration = 10
          )
          return()
        }

        # Fetch user info
        setProgress(0.6, detail = "Fetching user information")
        user_info <- temp_api$oauth$get_user_info()

        if (!user_info$success) {
          showNotification(
            paste("Failed to fetch user info:", user_info$error),
            type = "error",
            duration = 10
          )
          return()
        }

        # Add account to manager
        setProgress(0.8, detail = "Saving account")
        account_key <- account_manager$add_account(
          user_id = user_info$user_id,
          username = user_info$username,
          environment = "sandbox",
          access_token = token_result$access_token,
          refresh_token = token_result$refresh_token,
          token_expiry = Sys.time() + as.numeric(token_result$expires_in)
        )

        # Reinitialize API
        initialize_api_for_active_account()

        # Update UI
        update_ui()

        # Hide OAuth flow
        updateCheckboxInput(session, "show_oauth_flow", value = FALSE)
        updateTextInput(session, "auth_code", value = "")

        setProgress(1, detail = "Complete")

        showNotification(
          paste("✅ Connected:", user_info$username),
          type = "success",
          duration = 5
        )
      })
    })

    # Switch account
    observeEvent(input$switch_account, {
      req(input$account_selector)

      selected_key <- input$account_selector

      withProgress(message = "Switching account...", {
        success <- account_manager$set_active_account(selected_key)

        if (success) {
          # Reinitialize API with new account
          initialize_api_for_active_account()

          # Update UI
          update_ui()

          active <- account_manager$get_active_account()

          showNotification(
            paste("Switched to:", active$username),
            type = "success"
          )
        } else {
          showNotification(
            "Failed to switch account",
            type = "error"
          )
        }
      })
    })

    # Disconnect current account
    observeEvent(input$disconnect_current, {
      active <- account_manager$get_active_account()
      req(active)

      showModal(modalDialog(
        title = "Disconnect eBay Account",
        p("Are you sure you want to disconnect this account?"),
        div(
          class = "alert alert-warning",
          strong("Account: "), active$username, br(),
          strong("Environment: "), active$environment
        ),
        p("This will remove the stored credentials. You can reconnect anytime."),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(
            session$ns("confirm_disconnect"),
            "Disconnect",
            class = "btn-danger"
          )
        )
      ))
    })

    observeEvent(input$confirm_disconnect, {
      active <- account_manager$get_active_account()
      username <- active$username

      success <- account_manager$remove_account(active$account_key)

      if (success) {
        # Reinitialize with new active (if any)
        initialize_api_for_active_account()

        # Update UI
        update_ui()

        removeModal()

        showNotification(
          paste("Disconnected:", username),
          type = "info"
        )
      }
    })

    # Refresh status
    observeEvent(input$refresh_status, {
      initialize_api_for_active_account()
      update_ui()

      showNotification("Status refreshed", type = "message", duration = 2)
    })

    # Return API and account manager for use by other modules
    return(list(
      api = current_api,
      account_manager = reactive({ account_manager }),
      get_active_account = reactive({ account_manager$get_active_account() })
    ))
  })
}
```

**Validate:**
```r
# Run app
golem::run_dev()

# Navigate to eBay section
# Should show "No eBay account connected" initially
# Click "Connect New Account" → OAuth flow appears
# Click "Authorize with eBay (Sandbox)" → browser opens
# (Don't complete auth yet, just verify flow works)
```

**If_Fail:**
- Module error → Check moduleServer syntax
- account_manager not found → Source R/ebay_account_manager.R first
- UI not updating → Check reactive dependencies

**Rollback:**
```bash
git checkout R/mod_ebay_auth.R
```

---

### PHASE 3: Database Integration

#### TASK 3.1: Add User Columns to Database
**File:** `R/ebay_database_extension.R`
**Location:** Add at top of file

**Action:** Create migration function and update schema

**Implementation:**
```r
#' Migrate eBay listings table for multi-account support
#' @export
migrate_ebay_listings_for_multi_account <- function() {
  con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
  on.exit(DBI::dbDisconnect(con))

  # Check if columns already exist
  columns <- DBI::dbListFields(con, "ebay_listings")

  if (!"ebay_user_id" %in% columns) {
    message("Adding ebay_user_id column...")
    DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN ebay_user_id TEXT")
  }

  if (!"ebay_username" %in% columns) {
    message("Adding ebay_username column...")
    DBI::dbExecute(con, "ALTER TABLE ebay_listings ADD COLUMN ebay_username TEXT")
  }

  # Create index for filtering by user
  tryCatch({
    DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_user ON ebay_listings(ebay_username)")
    message("Created index on ebay_username")
  }, error = function(e) {
    message("Index may already exist: ", e$message)
  })

  message("✅ Migration complete")
}
```

**Run Migration:**
```r
source("R/ebay_database_extension.R")
migrate_ebay_listings_for_multi_account()
```

**Validate:**
```r
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
columns <- DBI::dbListFields(con, "ebay_listings")
print(columns)  # Should include ebay_user_id and ebay_username
DBI::dbDisconnect(con)
```

**If_Fail:**
- Table not found → Ensure tracking.sqlite exists
- Permission error → Check file permissions
- Syntax error → Verify SQL syntax for SQLite

**Rollback:**
```r
# Remove columns manually if needed
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
# Note: SQLite doesn't support DROP COLUMN easily
# Better to restore from backup
DBI::dbDisconnect(con)
```

---

#### TASK 3.2: Update save_ebay_listing Function
**File:** `R/ebay_database_extension.R`
**Lines:** Update function signature and SQL (lines 56-112)

**Action:** Add user parameters to function

**Find and Replace:**

**OLD function signature (line 56):**
```r
save_ebay_listing <- function(card_id, session_id, ebay_item_id = NULL,
                              ebay_offer_id = NULL, sku, status = "draft",
                              title = NULL, description = NULL, price = NULL,
                              condition = NULL, aspects = NULL, environment = "sandbox") {
```

**NEW function signature:**
```r
save_ebay_listing <- function(card_id, session_id, ebay_item_id = NULL,
                              ebay_offer_id = NULL, sku, status = "draft",
                              title = NULL, description = NULL, price = NULL,
                              condition = NULL, aspects = NULL, environment = "sandbox",
                              ebay_user_id = NULL, ebay_username = NULL) {
```

**OLD INSERT statement (around line 78):**
```r
DBI::dbExecute(con, "
  INSERT INTO ebay_listings (
    card_id, session_id, ebay_item_id, ebay_offer_id, sku,
    status, environment, title, description, price,
    condition, aspects, listed_at
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
    CASE WHEN ? = 'listed' THEN CURRENT_TIMESTAMP ELSE NULL END)
", list(card_id, session_id, ebay_item_id, ebay_offer_id, sku,
        status, environment, title, description, price,
        condition, aspects_json, status))
```

**NEW INSERT statement:**
```r
DBI::dbExecute(con, "
  INSERT INTO ebay_listings (
    card_id, session_id, ebay_item_id, ebay_offer_id, sku,
    status, environment, title, description, price,
    condition, aspects, ebay_user_id, ebay_username, listed_at
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
    CASE WHEN ? = 'listed' THEN CURRENT_TIMESTAMP ELSE NULL END)
", list(card_id, session_id, ebay_item_id, ebay_offer_id, sku,
        status, environment, title, description, price,
        condition, aspects_json, ebay_user_id, ebay_username, status))
```

**Also UPDATE statement (if exists around line 68):**
Add `ebay_user_id = ?, ebay_username = ?` to UPDATE clause and add to params list

**Validate:**
```r
# Test save function
source("R/ebay_database_extension.R")

save_ebay_listing(
  card_id = 999,
  session_id = "test",
  sku = "TEST-SKU-001",
  status = "draft",
  environment = "sandbox",
  ebay_user_id = "testuser123",
  ebay_username = "test_seller"
)

# Check database
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
result <- DBI::dbGetQuery(con, "SELECT * FROM ebay_listings WHERE sku = 'TEST-SKU-001'")
print(result)  # Should show ebay_username = "test_seller"
DBI::dbDisconnect(con)
```

**If_Fail:**
- SQL error → Check column names match database
- Param count mismatch → Verify number of ? matches params
- NULL values → Ensure params passed in correct order

**Rollback:**
```bash
git checkout R/ebay_database_extension.R
```

---

#### TASK 3.3: Update Listing Creation to Pass Account Info
**File:** `R/ebay_integration.R`
**Lines:** Around 210-230 (in save_ebay_listing call)

**Action:** Pass active account info when saving listing

**Find the save_ebay_listing call and update:**

**OLD:**
```r
save_success <- save_ebay_listing(
  card_id = card_id,
  session_id = session_id,
  ebay_item_id = publish_result$listing_id,
  ebay_offer_id = offer_result$offer_id,
  sku = sku,
  status = "listed",
  title = title_truncated,
  description = ai_data$description,
  price = ai_data$price,
  condition = inventory_data$condition,
  aspects = inventory_data$product$aspects,
  environment = ebay_api$config$environment
)
```

**NEW:**
```r
# Get active account info (passed from calling module)
# Note: This requires account_manager to be passed to this function
# For now, we'll get it from a global/reactive source

save_success <- save_ebay_listing(
  card_id = card_id,
  session_id = session_id,
  ebay_item_id = publish_result$listing_id,
  ebay_offer_id = offer_result$offer_id,
  sku = sku,
  status = "listed",
  title = title_truncated,
  description = ai_data$description,
  price = ai_data$price,
  condition = inventory_data$condition,
  aspects = inventory_data$product$aspects,
  environment = ebay_api$config$environment,
  ebay_user_id = ebay_api$user_id,        # NEW - will add to API object
  ebay_username = ebay_api$username       # NEW - will add to API object
)
```

**Also need to update `create_ebay_listing_from_card` signature to accept account info:**

Add to function parameters:
```r
create_ebay_listing_from_card <- function(card_id, ai_data, ebay_api, session_id,
                                         image_url = NULL,
                                         ebay_user_id = NULL,     # NEW
                                         ebay_username = NULL) {  # NEW
```

**Validate:**
- Will validate in end-to-end testing (Phase 4)

**If_Fail:**
- Function signature error → Check all callers updated
- NULL values saved → Ensure account info passed from module

**Rollback:**
```bash
git checkout R/ebay_integration.R
```

---

### PHASE 4: End-to-End Testing

#### TASK 4.1: Test Scenario 1 - Connect First Account
**Action:** Manual test with sandbox credentials

**Steps:**
1. Delete `inst/app/data/ebay_accounts.rds` if exists
2. Run: `golem::run_dev()`
3. Navigate to eBay section
4. Verify UI shows "No eBay account connected"
5. Click "Connect New Account"
6. Click "Authorize with eBay (Sandbox)"
7. Browser opens - log in with **Sandbox Test User 1**
8. Authorize app
9. Copy authorization code from URL
10. Paste in app, click "Submit Code"

**Expected:**
- ✅ Progress indicator shows
- ✅ Success notification: "Connected: [username]"
- ✅ Active account display shows username and environment
- ✅ OAuth flow collapses
- ✅ File created: `inst/app/data/ebay_accounts.rds`
- ✅ Console shows: "Added account: [username] (sandbox)"

**If_Fail:**
- Review error message
- Check console for detailed logs
- Verify sandbox credentials correct
- Ensure internet connection

**Document Results:**
```
Test 1: Connect First Account
Date: [DATE]
Account: [username]
Result: [PASS/FAIL]
Notes: [any issues]
```

---

#### TASK 4.2: Test Scenario 2 - Connect Second Account
**Action:** Connect different sandbox user

**Steps:**
1. Click "Connect New Account" again
2. Authorize with **Sandbox Test User 2** (different credentials)
3. Paste code, submit

**Expected:**
- ✅ Second account added
- ✅ Dropdown now shows 2 options
- ✅ Active account is STILL first user (doesn't auto-switch)
- ✅ Badge shows "2 Account(s)"
- ✅ Both accounts in ebay_accounts.rds file

**Validate:**
```r
# Check file contents
data <- readRDS("inst/app/data/ebay_accounts.rds")
print(names(data$accounts))  # Should show 2 account keys
print(data$active_account)   # Should be first account
```

**If_Fail:**
- First account overwritten → Account manager logic error
- Both accounts same key → user_id extraction issue

**Document Results:**
```
Test 2: Connect Second Account
Accounts: [user1], [user2]
Result: [PASS/FAIL]
```

---

#### TASK 4.3: Test Scenario 3 - Switch Between Accounts
**Action:** Test account switching

**Steps:**
1. Dropdown shows Account 1 selected
2. Select Account 2 from dropdown
3. Click "Switch Account"
4. Observe UI update

**Expected:**
- ✅ Active account display updates to Account 2
- ✅ Success notification
- ✅ No browser redirect
- ✅ Switch happens instantly
- ✅ Console shows: "Active account: [user2]"

**Validate:**
```r
# Check last_used timestamp updated
data <- readRDS("inst/app/data/ebay_accounts.rds")
account2_key <- data$active_account
print(data$accounts[[account2_key]]$last_used)  # Should be very recent
```

**If_Fail:**
- UI doesn't update → Check reactive dependencies
- Error on switch → Review set_active_account logic

**Document Results:**
```
Test 3: Switch Accounts
Switch from: [user1] to [user2]
Result: [PASS/FAIL]
```

---

#### TASK 4.4: Test Scenario 4 - Create Listings on Different Accounts
**Action:** Create listings and verify database tracking

**Steps:**
1. Ensure Account 1 is active
2. Navigate to listing creation
3. Create a test listing (can fail at publish, that's OK)
4. Check database for listing record
5. Switch to Account 2
6. Create another test listing
7. Check database again

**Expected:**
- ✅ Listing 1: `ebay_username = "[account1_username]"`
- ✅ Listing 2: `ebay_username = "[account2_username]"`
- ✅ Both listings stored
- ✅ Can query: "SELECT * FROM ebay_listings WHERE ebay_username = '[account1]'"

**Validate:**
```r
con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
listings <- DBI::dbGetQuery(con, "
  SELECT sku, ebay_username, environment, created_at
  FROM ebay_listings
  ORDER BY created_at DESC
  LIMIT 5
")
print(listings)
DBI::dbDisconnect(con)
```

**If_Fail:**
- NULL username → Account info not passed to save function
- Same username for both → Active account not switching

**Document Results:**
```
Test 4: Multi-Account Listings
Listing 1 user: [user1]
Listing 2 user: [user2]
Result: [PASS/FAIL]
```

---

#### TASK 4.5: Test Scenario 5 - App Restart Persistence
**Action:** Verify accounts persist

**Steps:**
1. Have 2 accounts connected, Account 2 active
2. Stop Shiny app (Ctrl+C or stop button)
3. Restart: `golem::run_dev()`
4. Navigate to eBay section

**Expected:**
- ✅ Both accounts still in dropdown
- ✅ Account 2 is active (restored)
- ✅ No re-authentication required
- ✅ Can create listing immediately

**Validate:**
```r
# Check console on startup
# Should see: "Loaded 2 account(s)"
```

**If_Fail:**
- Accounts lost → File not saving, check save_accounts()
- Wrong active account → Check active_account field in RDS

**Document Results:**
```
Test 5: Persistence
Accounts restored: [YES/NO]
Active account correct: [YES/NO]
Result: [PASS/FAIL]
```

---

#### TASK 4.6: Test Scenario 6 - Disconnect Account
**Action:** Test account removal

**Steps:**
1. Have 2 accounts, Account 1 active
2. Click "Disconnect Current Account"
3. Confirm in modal

**Expected:**
- ✅ Account 1 removed
- ✅ Active switches to Account 2
- ✅ Dropdown shows only 1 account
- ✅ Badge shows "1 Account(s)"
- ✅ Can still create listings on Account 2

**Validate:**
```r
data <- readRDS("inst/app/data/ebay_accounts.rds")
print(length(data$accounts))  # Should be 1
print(data$active_account)    # Should be account2 key
```

**If_Fail:**
- Both accounts removed → Logic error in remove_account
- No active account → Auto-switch logic not working

**Document Results:**
```
Test 6: Disconnect Account
Remaining accounts: [count]
Active switched: [YES/NO]
Result: [PASS/FAIL]
```

---

#### TASK 4.7: Create Test Summary Document
**File:** `.serena/memories/ebay_multi_account_testing_complete_[date].md`

**Action:** Document all test results

**Template:**
```markdown
# eBay Multi-Account Testing Complete - [Date]

## Test Environment
- Sandbox environment
- 2 test user accounts
- App version: [version]

## Test Results Summary

| Test Scenario | Result | Notes |
|---------------|--------|-------|
| Connect Account 1 | [PASS/FAIL] | [notes] |
| Connect Account 2 | [PASS/FAIL] | [notes] |
| Switch Accounts | [PASS/FAIL] | [notes] |
| Multi-Account Listings | [PASS/FAIL] | [notes] |
| App Restart | [PASS/FAIL] | [notes] |
| Disconnect Account | [PASS/FAIL] | [notes] |

## Issues Found
[List any issues encountered]

## Files Modified
- R/ebay_account_manager.R (NEW)
- R/ebay_api.R (+2 methods)
- R/mod_ebay_auth.R (complete rewrite)
- R/ebay_database_extension.R (+migration, +params)
- R/ebay_integration.R (+account params)

## Database Changes
- Added: ebay_user_id column
- Added: ebay_username column
- Added: idx_ebay_user index

## Next Steps
- [ ] Update production switch PRP
- [ ] Test with production credentials
- [ ] Add account filtering to tracking viewer

## Success Criteria Met
- [x] Multiple accounts stored
- [x] Account switching works
- [x] Database tracks username
- [x] Persistence across restarts
- [x] Migration of old tokens
```

---

## Success Criteria

✅ **Implementation Complete When:**

1. ✅ EbayAccountManager class created and tested
2. ✅ get_user_info() API call working
3. ✅ Multi-account UI functional
4. ✅ Database schema updated
5. ✅ Can connect 2+ sandbox accounts
6. ✅ Can switch between accounts without re-auth
7. ✅ Listings track correct username
8. ✅ Accounts persist across app restarts
9. ✅ Can disconnect specific accounts
10. ✅ All 6 test scenarios pass

## Rollback Strategy

**Complete Rollback:**
```bash
# Restore all files
git checkout R/ebay_account_manager.R
git checkout R/ebay_api.R
git checkout R/mod_ebay_auth.R
git checkout R/ebay_database_extension.R
git checkout R/ebay_integration.R

# Remove new data file
rm inst/app/data/ebay_accounts.rds

# Database rollback (if needed)
# Restore from backup or manually drop columns
```

**Partial Rollback (Keep Database Changes):**
- Only rollback code files
- Keep ebay_user_id and ebay_username columns for future use

## Timeline

- Phase 1 (Core): 4 hours
- Phase 2 (UI): 3 hours
- Phase 3 (Database): 2 hours
- Phase 4 (Testing): 2 hours
- **Total: 11 hours**

## Dependencies

**Must Have:**
- ✅ R6 package installed
- ✅ Existing eBay OAuth working
- ✅ 2 sandbox test user accounts

**Blocks:**
- Production switch (cannot proceed until this is complete)

---

**Ready to implement?** All tasks are sequenced with clear validation and rollback steps.
