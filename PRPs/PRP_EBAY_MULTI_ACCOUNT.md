# PRP: eBay Multi-Account Support

## Overview

Enable users to manage multiple eBay seller accounts within the Delcampe app, allowing them to switch between accounts and create listings on different accounts without re-authenticating each time.

## Problem Statement

**Current Limitation:**
- App stores only ONE eBay account's tokens at a time
- Connecting a new account overwrites the previous account's tokens
- No way to switch between accounts without re-authenticating
- Database doesn't track which eBay seller created each listing
- Cannot manage multiple storefronts or test/production accounts simultaneously

**User Stories:**

1. **As a seller with multiple eBay accounts**, I want to switch between my US and EU accounts to list items in different regions
2. **As a power user**, I want to test listings on my sandbox account AND create real listings on my production account without re-authenticating every time
3. **As a business owner**, I want to see which listings belong to which eBay account in my tracking data
4. **As a seller**, I want to quickly switch between accounts from a dropdown without going through OAuth again
5. **As a seller**, I want to disconnect a specific account without affecting my other connected accounts

## Goals

1. **Multi-Account Storage**: Store tokens for multiple eBay accounts
2. **Account Switching UI**: Simple dropdown to switch active account
3. **Account Management**: View, connect, disconnect specific accounts
4. **User Identity**: Fetch and display eBay username for each connected account
5. **Database Tracking**: Track which eBay user created each listing
6. **Token Persistence**: Keep all accounts authenticated across app restarts
7. **Active Account Indication**: Clear visual indicator of which account is active

## Technical Design

### Architecture Changes

#### 1. Token Storage - Multi-Account Structure

**Current (Single Account):**
```r
# data/ebay_tokens.rds
list(
  access_token = "...",
  refresh_token = "...",
  token_expiry = POSIXct,
  environment = "sandbox"
)
```

**New (Multi-Account):**
```r
# data/ebay_accounts.rds
list(
  accounts = list(
    "user123_production" = list(
      user_id = "user123",
      username = "john_seller",
      environment = "production",
      access_token = "...",
      refresh_token = "...",
      token_expiry = POSIXct,
      connected_at = POSIXct,
      last_used = POSIXct
    ),
    "user456_sandbox" = list(
      user_id = "user456",
      username = "test_user",
      environment = "sandbox",
      access_token = "...",
      refresh_token = "...",
      token_expiry = POSIXct,
      connected_at = POSIXct,
      last_used = POSIXct
    )
  ),
  active_account = "user123_production"
)
```

**Account Key Format:** `{user_id}_{environment}`
- Allows same user in different environments
- Unique identifier for account selection
- Human-readable for debugging

#### 2. Fetch eBay User Identity

**API Endpoint:** `GET /commerce/identity/v1/user/`

**Response:**
```json
{
  "userId": "user123",
  "username": "john_seller",
  "email": "john@example.com"
}
```

**Implementation:**
```r
# New function in R/ebay_api.R
EbayOAuth$get_user_info = function() {
  token <- self$get_access_token()
  user_url <- paste0(private$config$get_base_url(), "/commerce/identity/v1/user/")

  response <- request(user_url) |>
    req_headers("Authorization" = paste("Bearer", token)) |>
    req_perform()

  user_data <- resp_body_json(response)

  return(list(
    user_id = user_data$userId,
    username = user_data$username
  ))
}
```

#### 3. Account Manager Class

**New R6 Class:** `EbayAccountManager`

```r
# R/ebay_account_manager.R
EbayAccountManager <- R6::R6Class("EbayAccountManager",
  private = list(
    accounts_file = "data/ebay_accounts.rds",
    accounts = list(),
    active_account_key = NULL
  ),

  public = list(
    initialize = function() {
      self$load_accounts()
    },

    # Add new account after OAuth
    add_account = function(user_id, username, environment, access_token, refresh_token, token_expiry) {
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
      if (is.null(private$active_account_key)) {
        private$active_account_key <- account_key
      }

      self$save_accounts()
      return(account_key)
    },

    # Remove specific account
    remove_account = function(account_key) {
      private$accounts[[account_key]] <- NULL

      # If removed active account, switch to first available
      if (private$active_account_key == account_key) {
        if (length(private$accounts) > 0) {
          private$active_account_key <- names(private$accounts)[1]
        } else {
          private$active_account_key <- NULL
        }
      }

      self$save_accounts()
    },

    # Switch active account
    set_active_account = function(account_key) {
      if (account_key %in% names(private$accounts)) {
        private$active_account_key <- account_key
        private$accounts[[account_key]]$last_used <- Sys.time()
        self$save_accounts()
        return(TRUE)
      }
      return(FALSE)
    },

    # Get active account details
    get_active_account = function() {
      if (is.null(private$active_account_key)) return(NULL)
      private$accounts[[private$active_account_key]]
    },

    # Get all accounts
    get_all_accounts = function() {
      private$accounts
    },

    # Get accounts for dropdown (formatted)
    get_account_choices = function() {
      if (length(private$accounts) == 0) return(NULL)

      choices <- sapply(names(private$accounts), function(key) {
        account <- private$accounts[[key]]
        paste0(account$username, " (", account$environment, ")")
      })

      names(choices) <- names(private$accounts)
      return(choices)
    },

    # Update tokens for specific account
    update_account_tokens = function(account_key, access_token, refresh_token, token_expiry) {
      if (account_key %in% names(private$accounts)) {
        private$accounts[[account_key]]$access_token <- access_token
        private$accounts[[account_key]]$refresh_token <- refresh_token
        private$accounts[[account_key]]$token_expiry <- token_expiry
        self$save_accounts()
        return(TRUE)
      }
      return(FALSE)
    },

    # Save accounts to file
    save_accounts = function() {
      data <- list(
        accounts = private$accounts,
        active_account = private$active_account_key
      )
      saveRDS(data, file = private$accounts_file)
    },

    # Load accounts from file
    load_accounts = function() {
      if (file.exists(private$accounts_file)) {
        data <- readRDS(private$accounts_file)
        private$accounts <- data$accounts
        private$active_account_key <- data$active_account
      }
    }
  )
)
```

#### 4. Updated UI Module

**Enhanced `mod_ebay_auth_ui`:**

```r
mod_ebay_auth_ui <- function(id) {
  ns <- NS(id)

  tagList(
    bslib::card(
      bslib::card_header("eBay Account Management"),
      bslib::card_body(
        # Active account display
        uiOutput(ns("active_account_display")),

        # Account switcher dropdown
        conditionalPanel(
          condition = "output.has_accounts",
          ns = ns,
          selectInput(
            ns("account_selector"),
            "Active Account:",
            choices = NULL,
            width = "100%"
          ),
          actionButton(
            ns("switch_account"),
            "Switch Account",
            icon = icon("exchange-alt"),
            class = "btn-info btn-sm"
          )
        ),

        hr(),

        # Account management buttons
        div(
          class = "d-flex gap-2 flex-wrap",
          actionButton(
            ns("connect_new"),
            "Connect New Account",
            icon = icon("plus-circle"),
            class = "btn-success"
          ),
          actionButton(
            ns("disconnect_current"),
            "Disconnect Current",
            icon = icon("unlink"),
            class = "btn-warning"
          ),
          actionButton(
            ns("manage_accounts"),
            "Manage All Accounts",
            icon = icon("users-cog"),
            class = "btn-secondary"
          )
        ),

        # OAuth flow (hidden until triggered)
        conditionalPanel(
          condition = paste0("input['", ns("show_oauth_flow"), "'] == true"),
          div(
            class = "mt-3 p-3 border rounded",
            h5("Connect eBay Account"),
            p("Step 1: Choose environment"),
            selectInput(
              ns("oauth_environment"),
              NULL,
              choices = c("Production" = "production", "Sandbox" = "sandbox"),
              selected = "production"
            ),
            actionButton(
              ns("start_oauth"),
              "Authorize with eBay",
              icon = icon("external-link-alt"),
              class = "btn-primary"
            ),
            hr(),
            p("Step 2: After authorizing, paste the code here:"),
            textInput(
              ns("auth_code"),
              NULL,
              placeholder = "Paste authorization code"
            ),
            actionButton(
              ns("submit_code"),
              "Submit Code",
              icon = icon("check"),
              class = "btn-success"
            )
          )
        ),

        div(style = "display: none;",
          checkboxInput(ns("show_oauth_flow"), "", value = FALSE)
        )
      )
    )
  )
}
```

**Server Updates:**

```r
mod_ebay_auth_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Initialize account manager
    account_manager <- EbayAccountManager$new()

    # Current API instance (for active account)
    current_api <- reactiveVal(NULL)

    # Update active account display
    output$active_account_display <- renderUI({
      active <- account_manager$get_active_account()

      if (is.null(active)) {
        div(
          class = "alert alert-warning",
          icon("exclamation-circle"),
          " No eBay account connected"
        )
      } else {
        div(
          class = "alert alert-success",
          icon("check-circle"),
          strong(" Active: "), active$username,
          " (", active$environment, ")",
          br(),
          small("Connected: ", format(active$connected_at, "%Y-%m-%d %H:%M"))
        )
      }
    })

    # Update account selector
    output$has_accounts <- reactive({
      length(account_manager$get_all_accounts()) > 0
    })
    outputOptions(output, "has_accounts", suspendWhenHidden = FALSE)

    observe({
      choices <- account_manager$get_account_choices()
      active_key <- names(Filter(function(x) !is.null(x),
                                  list(account_manager$get_active_account())))

      updateSelectInput(
        session,
        "account_selector",
        choices = choices,
        selected = active_key
      )
    })

    # Switch account
    observeEvent(input$switch_account, {
      req(input$account_selector)

      success <- account_manager$set_active_account(input$account_selector)

      if (success) {
        # Reinitialize API with new account
        initialize_api_for_active_account()

        showNotification(
          paste("Switched to account:",
                account_manager$get_active_account()$username),
          type = "success"
        )
      }
    })

    # Connect new account
    observeEvent(input$connect_new, {
      updateCheckboxInput(session, "show_oauth_flow", value = TRUE)
    })

    # Start OAuth flow
    observeEvent(input$start_oauth, {
      req(input$oauth_environment)

      # Initialize temporary API for this environment
      temp_api <- init_ebay_api(environment = input$oauth_environment)
      auth_url <- temp_api$oauth$generate_auth_url()

      browseURL(auth_url)

      showNotification(
        "Browser opened. Authorize and paste code below.",
        duration = 10,
        type = "message"
      )
    })

    # Submit OAuth code
    observeEvent(input$submit_code, {
      req(input$auth_code, input$oauth_environment)

      withProgress(message = "Connecting account...", {
        temp_api <- init_ebay_api(environment = input$oauth_environment)

        # Exchange code for token
        result <- temp_api$oauth$get_user_token(input$auth_code)

        if (result$success) {
          # Fetch user info
          user_info <- temp_api$oauth$get_user_info()

          # Add account to manager
          account_manager$add_account(
            user_id = user_info$user_id,
            username = user_info$username,
            environment = input$oauth_environment,
            access_token = result$access_token,
            refresh_token = result$refresh_token,
            token_expiry = Sys.time() + result$expires_in
          )

          # Initialize API for new account
          initialize_api_for_active_account()

          # Hide OAuth flow
          updateCheckboxInput(session, "show_oauth_flow", value = FALSE)
          updateTextInput(session, "auth_code", value = "")

          showNotification(
            paste("Connected:", user_info$username),
            type = "success"
          )
        } else {
          showNotification(
            paste("Failed:", result$error),
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
        title = "Disconnect Account",
        paste("Disconnect", active$username, "?"),
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
      active_key <- paste(active$user_id, active$environment, sep = "_")

      account_manager$remove_account(active_key)

      # Reinitialize with new active (if any)
      initialize_api_for_active_account()

      removeModal()
      showNotification("Account disconnected", type = "info")
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

    # Initialize on startup
    initialize_api_for_active_account()

    # Return current API and account info
    return(list(
      api = current_api,
      get_active_account = reactive({ account_manager$get_active_account() })
    ))
  })
}
```

#### 5. Database Schema Update

**Add to `ebay_listings` table:**

```sql
ALTER TABLE ebay_listings ADD COLUMN ebay_user_id TEXT;
ALTER TABLE ebay_listings ADD COLUMN ebay_username TEXT;
```

**Update `save_ebay_listing` function:**

```r
save_ebay_listing <- function(card_id, session_id, ebay_item_id = NULL,
                              ebay_offer_id = NULL, sku, status = "draft",
                              title = NULL, description = NULL, price = NULL,
                              condition = NULL, aspects = NULL,
                              environment = "sandbox",
                              ebay_user_id = NULL,      # NEW
                              ebay_username = NULL) {   # NEW
  # ... existing code ...

  # Insert with user tracking
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
}
```

#### 6. Update Listing Creation Flow

**In `create_ebay_listing_from_card`:**

```r
# After successful publish, get active account info
active_account <- account_manager$get_active_account()

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
  ebay_user_id = active_account$user_id,        # NEW
  ebay_username = active_account$username       # NEW
)
```

## UI/UX Flow

### Connecting First Account

1. User opens eBay section
2. Sees: "No eBay account connected"
3. Clicks "Connect New Account"
4. OAuth flow appears with environment selector
5. Selects "Production" or "Sandbox"
6. Clicks "Authorize with eBay"
7. Browser opens, user logs in with eBay
8. Copies code, pastes back
9. App fetches username, saves account
10. Shows: "Active: john_seller (production)"

### Connecting Second Account

1. User clicks "Connect New Account" again
2. Selects different environment or same environment (different user)
3. Authorizes with different eBay account
4. Now has 2 accounts in dropdown
5. Current account remains active (doesn't auto-switch)

### Switching Between Accounts

1. Dropdown shows:
   - john_seller (production)  ← currently selected
   - test_user (sandbox)
2. User selects "test_user (sandbox)"
3. Clicks "Switch Account"
4. App updates active account
5. All new listings will use test_user's credentials
6. Display updates: "Active: test_user (sandbox)"

### Managing Accounts Modal

**Triggered by "Manage All Accounts" button:**

```
┌─────────────────────────────────────────┐
│  Connected eBay Accounts                │
├─────────────────────────────────────────┤
│  ✓ john_seller (production)             │
│    Connected: 2025-10-15 14:23          │
│    Last used: 2025-10-18 10:45          │
│    [Make Active] [Disconnect]           │
├─────────────────────────────────────────┤
│  □ test_user (sandbox)                  │
│    Connected: 2025-10-10 09:15          │
│    Last used: 2025-10-12 16:30          │
│    [Make Active] [Disconnect]           │
└─────────────────────────────────────────┘
```

## Implementation Phases

### Phase 1: Core Multi-Account Storage (Required)
- Create `EbayAccountManager` class
- Update token storage to multi-account format
- Implement `get_user_info()` API call
- Migrate existing single token (if exists) to new format

### Phase 2: UI Updates (Required)
- Update `mod_ebay_auth_ui` with account selector
- Update server logic for account switching
- Add "Connect New Account" flow
- Update disconnect to handle specific accounts

### Phase 3: Database Integration (Required)
- Add `ebay_user_id` and `ebay_username` columns
- Update `save_ebay_listing` function
- Pass active account info from listing creation

### Phase 4: Account Management UI (Nice-to-Have)
- Create "Manage All Accounts" modal
- Show account details, connection dates
- Bulk disconnect option
- Account usage statistics

### Phase 5: Advanced Features (Optional)
- Account-specific listing history in tracking viewer
- Filter tracking by eBay account
- Account performance metrics
- Export listings by account

## Backward Compatibility

**Migration Strategy:**

If `data/ebay_tokens.rds` exists (old single-account format):
1. Read old tokens
2. Fetch user info with existing token
3. Convert to new multi-account format
4. Set as active account
5. Rename old file to `ebay_tokens.rds.backup`
6. Save as `data/ebay_accounts.rds`

```r
migrate_old_tokens <- function() {
  old_file <- "data/ebay_tokens.rds"
  new_file <- "data/ebay_accounts.rds"

  if (file.exists(old_file) && !file.exists(new_file)) {
    old_data <- readRDS(old_file)

    # Create API with old tokens
    api <- init_ebay_api(environment = old_data$environment)
    api$oauth$set_tokens(
      old_data$access_token,
      old_data$refresh_token,
      old_data$token_expiry
    )

    # Fetch user info
    user_info <- api$oauth$get_user_info()

    # Create new format
    account_key <- paste(user_info$user_id, old_data$environment, sep = "_")
    new_data <- list(
      accounts = list(),
      active_account = account_key
    )
    new_data$accounts[[account_key]] <- list(
      user_id = user_info$user_id,
      username = user_info$username,
      environment = old_data$environment,
      access_token = old_data$access_token,
      refresh_token = old_data$refresh_token,
      token_expiry = old_data$token_expiry,
      connected_at = Sys.time(),
      last_used = Sys.time()
    )

    saveRDS(new_data, file = new_file)
    file.rename(old_file, paste0(old_file, ".backup"))

    message("Migrated old eBay tokens to multi-account format")
  }
}
```

## Testing Strategy

### Test Cases

1. **Connect first account**
   - Verify user info fetched correctly
   - Verify account stored with correct key
   - Verify set as active account

2. **Connect second account (same environment)**
   - Verify both accounts stored
   - Verify first account remains active
   - Verify can switch between them

3. **Connect second account (different environment)**
   - Verify production and sandbox can coexist
   - Verify environment correctly tracked
   - Verify correct API base URL used per environment

4. **Switch accounts**
   - Create listing with Account A
   - Switch to Account B
   - Create listing with Account B
   - Verify database tracks correct username for each

5. **Disconnect account**
   - Disconnect non-active account → active unchanged
   - Disconnect active account → switches to next available
   - Disconnect last account → shows "no account connected"

6. **Token refresh**
   - Verify refresh updates correct account's tokens
   - Verify other accounts' tokens unchanged

7. **App restart**
   - Verify all accounts persist
   - Verify active account restored
   - Verify can immediately create listing without re-auth

## Success Criteria

✅ **Feature Complete When:**

1. Can connect multiple eBay accounts
2. Can switch between accounts via dropdown
3. Each listing tracks which eBay user created it
4. Tokens persist across app restarts for all accounts
5. Can disconnect specific accounts
6. User identity (username) displayed for each account
7. Old single-account tokens migrate automatically
8. No authentication required when switching between stored accounts
9. Each account's tokens refresh independently
10. Clear visual indication of active account

## Files to Create/Modify

**New Files:**
- `R/ebay_account_manager.R` - Account manager R6 class

**Modified Files:**
- `R/ebay_api.R` - Add `get_user_info()` method to EbayOAuth
- `R/mod_ebay_auth.R` - Complete UI/server rewrite for multi-account
- `R/ebay_integration.R` - Pass active account to save function
- `R/ebay_database_extension.R` - Add user columns, update save function
- `inst/app/data/tracking.sqlite` - Schema update (migration script)

## Estimated Effort

- **Phase 1 (Core)**: 4 hours
- **Phase 2 (UI)**: 3 hours
- **Phase 3 (Database)**: 2 hours
- **Phase 4 (Management UI)**: 2 hours
- **Testing**: 2 hours
- **Total**: ~13 hours active development

## Priority

**HIGH** - This is a blocking issue for production use if the user needs multiple accounts. Should be implemented BEFORE production switch if user requires multi-account support.

## Dependencies

- Must be implemented before or alongside production switch
- Requires eBay Identity API access (should be included in existing scopes)
- Database migration must run before any multi-account listing creation

## Risks

**Low Risk:**
- API is proven (same endpoints as existing OAuth)
- Migration path is clear (old tokens → new format)
- Backward compatible design

**Mitigation:**
- Backup old tokens before migration
- Extensive testing with 2+ accounts
- Rollback: Delete new file, restore backup

---

## Alternative: Simplified Single Active Account

If multi-account is too complex for initial release, consider:

**Minimal Implementation:**
- Still fetch and display username
- Track username in database
- Allow disconnect/reconnect different user
- But don't store multiple tokens simultaneously

**Pros:**
- Much simpler (2-3 hours development)
- Addresses database tracking requirement
- Allows account switching (with re-auth)

**Cons:**
- Must re-authenticate when switching
- Can't quick-switch between test/production
- Less convenient for multi-account sellers

**Recommendation:** Implement full multi-account. The complexity is manageable and the UX improvement is significant.
