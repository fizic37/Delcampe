# PRP: eBay Multi-Account Support (Sandbox Testing)

## Overview

Implement multi-account support for the eBay integration, allowing users to connect and switch between multiple eBay seller accounts. This PRP focuses on **sandbox testing** to validate the architecture before production deployment.

## Problem Statement

**Current Critical Limitations:**

1. **Single Token Storage**: App stores only ONE eBay account's tokens at a time
2. **Token Overwrite**: Connecting a new account overwrites the previous account's credentials
3. **No Account Switching**: Must disconnect and re-authenticate to change accounts
4. **No User Identity**: Don't know which eBay user's credentials are currently active
5. **Database Gap**: Listings don't track which eBay seller account created them
6. **Production Blocker**: Cannot manage multiple storefronts or test/prod accounts simultaneously

**Immediate Impact:**
- User wants to test with multiple sandbox accounts → BLOCKED
- User wants to switch between test and production → BLOCKED (must re-auth)
- User wants to track which account created which listing → BLOCKED (no data)

## Goals - Sandbox Testing Phase

### Primary Goals
1. ✅ Store multiple eBay account credentials simultaneously
2. ✅ Fetch and display eBay username for each connected account
3. ✅ Switch between accounts without re-authentication
4. ✅ Track which eBay user created each listing in database
5. ✅ Validate architecture with 2+ sandbox accounts
6. ✅ Migrate existing single-account tokens automatically

### Success Criteria - Sandbox Testing
- [ ] Connect 2 different sandbox accounts
- [ ] Switch between accounts via UI dropdown
- [ ] Create listing on Account A
- [ ] Switch to Account B
- [ ] Create listing on Account B
- [ ] Database shows correct username for each listing
- [ ] Restart app - both accounts still connected
- [ ] Disconnect one account - other remains active
- [ ] All without re-authenticating

### Out of Scope (Future Production Phase)
- Production account management (tested in sandbox only)
- Account performance metrics
- Bulk operations on accounts
- Per-account listing filters (database support added, UI later)

## Technical Design

### Architecture Overview

```
┌─────────────────────────────────────────────┐
│  EbayAccountManager (NEW)                   │
│  - Stores multiple account credentials      │
│  - Manages active account selection         │
│  - Persists to data/ebay_accounts.rds       │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│  EbayOAuth (ENHANCED)                       │
│  + get_user_info() - Fetch eBay username    │
│  + set_tokens() - Inject stored tokens      │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│  mod_ebay_auth (UPDATED)                    │
│  - Account selector dropdown                │
│  - "Connect New Account" flow               │
│  - Active account indicator                 │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│  Database (EXTENDED)                        │
│  + ebay_user_id column                      │
│  + ebay_username column                     │
└─────────────────────────────────────────────┘
```

### 1. Account Manager Class

**File**: `R/ebay_account_manager.R` (NEW)

**Responsibilities:**
- Store multiple account credentials
- Track active account
- Provide account switching logic
- Persist accounts across app restarts

**Key Methods:**
```r
EbayAccountManager <- R6Class("EbayAccountManager",
  public = list(
    # Add newly authenticated account
    add_account(user_id, username, environment, tokens),

    # Remove specific account
    remove_account(account_key),

    # Switch active account
    set_active_account(account_key),

    # Get active account details
    get_active_account(),

    # Get all connected accounts
    get_all_accounts(),

    # Get formatted choices for dropdown
    get_account_choices(),

    # Update tokens after refresh
    update_account_tokens(account_key, tokens),

    # Persistence
    save_accounts(),
    load_accounts()
  )
)
```

**Storage Format:**
```r
# data/ebay_accounts.rds
list(
  accounts = list(
    "testuser1_sandbox" = list(
      user_id = "testuser1",
      username = "test_seller_1",
      environment = "sandbox",
      access_token = "v^1.1#...",
      refresh_token = "v^1.1#...",
      token_expiry = POSIXct("2025-10-18 12:00:00"),
      connected_at = POSIXct("2025-10-18 10:00:00"),
      last_used = POSIXct("2025-10-18 11:30:00")
    ),
    "testuser2_sandbox" = list(
      user_id = "testuser2",
      username = "test_seller_2",
      environment = "sandbox",
      access_token = "v^1.1#...",
      refresh_token = "v^1.1#...",
      token_expiry = POSIXct("2025-10-18 12:30:00"),
      connected_at = POSIXct("2025-10-18 10:15:00"),
      last_used = POSIXct("2025-10-18 10:45:00")
    )
  ),
  active_account = "testuser1_sandbox"
)
```

**Account Key Format:** `{user_id}_{environment}`
- Unique identifier for each account+environment combination
- Allows same user in sandbox and production
- Human-readable for debugging

### 2. Enhanced OAuth Class

**File**: `R/ebay_api.R` (MODIFY)

**Add to `EbayOAuth` class:**

```r
# Fetch eBay user identity after authentication
get_user_info = function() {
  token <- self$get_access_token()

  if (is.null(token)) {
    return(list(success = FALSE, error = "No access token"))
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
    return(list(
      success = FALSE,
      error = e$message
    ))
  })
}

# Inject stored tokens (for account switching)
set_tokens = function(access_token, refresh_token, token_expiry) {
  private$access_token <- access_token
  private$refresh_token <- refresh_token
  private$token_expiry <- token_expiry
}
```

**API Endpoint:** `GET /commerce/identity/v1/user/`
- **Scope Required:** Included in existing OAuth scopes
- **Response:** `{userId, username, email}`
- **Usage:** Called immediately after successful OAuth to identify account

### 3. Updated Authentication Module

**File**: `R/mod_ebay_auth.R` (MAJOR UPDATE)

**New UI Features:**
- Active account display with username
- Account selector dropdown (when multiple accounts exist)
- "Switch Account" button
- "Connect New Account" button
- "Disconnect Current" button

**UI Structure:**
```r
mod_ebay_auth_ui <- function(id) {
  ns <- NS(id)

  bslib::card(
    bslib::card_header("eBay Account Management"),
    bslib::card_body(
      # Active account status
      uiOutput(ns("active_account_status")),

      # Account switcher (shown when multiple accounts exist)
      conditionalPanel(
        condition = "output.has_multiple_accounts",
        ns = ns,
        selectInput(
          ns("account_selector"),
          "Switch to Account:",
          choices = NULL
        ),
        actionButton(
          ns("switch_account"),
          "Switch",
          icon = icon("exchange-alt"),
          class = "btn-info btn-sm"
        )
      ),

      hr(),

      # Action buttons
      div(
        class = "d-flex gap-2",
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
        )
      ),

      # OAuth flow (shown when connecting new account)
      uiOutput(ns("oauth_flow_ui"))
    )
  )
}
```

**Server Logic Flow:**

1. **On Startup:**
   - Initialize `EbayAccountManager`
   - Load saved accounts
   - Display active account (if any)
   - Populate dropdown with all accounts

2. **Connect New Account:**
   - User clicks "Connect New Account"
   - Show OAuth flow UI (environment already set to sandbox for testing)
   - User clicks "Authorize with eBay"
   - Browser opens → user authorizes
   - User pastes code back
   - Exchange code for tokens
   - **Call `get_user_info()` to fetch username**
   - Add account to manager
   - Update UI with new account

3. **Switch Account:**
   - User selects different account from dropdown
   - Clicks "Switch"
   - Account manager updates active account
   - Re-initialize API with selected account's tokens
   - Update UI to show new active account
   - **No re-authentication required**

4. **Disconnect Account:**
   - User clicks "Disconnect Current"
   - Confirmation modal
   - Remove from account manager
   - If was active, switch to next available account
   - Update UI

### 4. Database Schema Extension

**File**: `inst/app/data/tracking.sqlite` (SCHEMA UPDATE)

**Add Columns:**
```sql
-- Migration script
ALTER TABLE ebay_listings ADD COLUMN ebay_user_id TEXT;
ALTER TABLE ebay_listings ADD COLUMN ebay_username TEXT;

-- Create index for filtering by user
CREATE INDEX idx_ebay_user ON ebay_listings(ebay_username);
```

**Updated Insert:**
```r
# In save_ebay_listing function (R/ebay_database_extension.R)
DBI::dbExecute(con, "
  INSERT INTO ebay_listings (
    card_id, session_id, ebay_item_id, ebay_offer_id, sku,
    status, environment, title, description, price,
    condition, aspects,
    ebay_user_id, ebay_username,  -- NEW COLUMNS
    listed_at
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ...)
", params)
```

### 5. Integration with Listing Creation

**File**: `R/ebay_integration.R` (MINOR UPDATE)

**Pass Active Account Info:**
```r
# In create_ebay_listing_from_card function
# After successful listing creation

# Get active account from account manager
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

### 6. Token Migration (Backward Compatibility)

**File**: `R/ebay_account_manager.R` (in initialize method)

**Auto-Migration Logic:**
```r
# In EbayAccountManager$initialize()
migrate_old_tokens <- function() {
  old_file <- "data/ebay_tokens.rds"
  new_file <- "data/ebay_accounts.rds"

  # Only migrate if old exists and new doesn't
  if (file.exists(old_file) && !file.exists(new_file)) {
    message("Migrating old eBay tokens to multi-account format...")

    tryCatch({
      old_data <- readRDS(old_file)

      # Initialize API with old tokens to fetch user info
      temp_api <- init_ebay_api(environment = old_data$environment)
      temp_api$oauth$set_tokens(
        old_data$access_token,
        old_data$refresh_token,
        old_data$token_expiry
      )

      # Fetch user identity
      user_info <- temp_api$oauth$get_user_info()

      if (user_info$success) {
        # Create new multi-account structure
        account_key <- paste(
          user_info$user_id,
          old_data$environment,
          sep = "_"
        )

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

        # Save new format
        saveRDS(new_data, file = new_file)

        # Backup old file
        file.rename(old_file, paste0(old_file, ".backup"))

        message("✅ Migration successful: ", user_info$username)
      } else {
        warning("Failed to fetch user info during migration")
      }
    }, error = function(e) {
      warning("Token migration failed: ", e$message)
    })
  }
}
```

## Sandbox Testing Plan

### Test Scenario 1: Connect First Account

**Steps:**
1. Start fresh app (no existing tokens)
2. Navigate to eBay section
3. See: "No eBay account connected"
4. Click "Connect New Account"
5. OAuth flow shows (environment = sandbox)
6. Click "Authorize with eBay"
7. Log in with **Sandbox Test User 1**
8. Copy authorization code
9. Paste code, click "Submit Code"

**Expected:**
- ✅ Token exchange succeeds
- ✅ `get_user_info()` called automatically
- ✅ Account stored with username
- ✅ Display shows: "Active: test_seller_1 (sandbox)"
- ✅ File created: `data/ebay_accounts.rds`
- ✅ Account added to manager

### Test Scenario 2: Connect Second Account

**Steps:**
1. Click "Connect New Account" again
2. Authorize with **Sandbox Test User 2** (different credentials)
3. Paste code, submit

**Expected:**
- ✅ Second account added
- ✅ First account remains in storage (not overwritten!)
- ✅ Dropdown shows 2 accounts:
  - test_seller_1 (sandbox)
  - test_seller_2 (sandbox)
- ✅ Active account is still test_seller_1
- ✅ Both accounts in `ebay_accounts.rds`

### Test Scenario 3: Switch Between Accounts

**Steps:**
1. Dropdown shows: test_seller_1 (selected)
2. Select "test_seller_2 (sandbox)"
3. Click "Switch"
4. Observe UI update

**Expected:**
- ✅ Display updates: "Active: test_seller_2 (sandbox)"
- ✅ Green success notification
- ✅ No browser redirect (no re-auth)
- ✅ API re-initialized with test_seller_2's tokens
- ✅ Switch happens instantly (<100ms)

### Test Scenario 4: Create Listings on Different Accounts

**Steps:**
1. Active account: test_seller_1
2. Create listing for postcard A
3. Check database - note username
4. Switch to test_seller_2
5. Create listing for postcard B
6. Check database - note username

**Expected:**
- ✅ Listing A: `ebay_username = "test_seller_1"`
- ✅ Listing B: `ebay_username = "test_seller_2"`
- ✅ Both listings in database
- ✅ Correct environment tracked (sandbox)
- ✅ Can query: "Show me all listings by test_seller_1"

### Test Scenario 5: App Restart Persistence

**Steps:**
1. Have 2 accounts connected
2. Active account: test_seller_2
3. Stop Shiny app
4. Restart app
5. Navigate to eBay section

**Expected:**
- ✅ Both accounts still in dropdown
- ✅ Active account restored: test_seller_2
- ✅ Can immediately create listing (no re-auth)
- ✅ Token refresh works if expired

### Test Scenario 6: Disconnect Account

**Steps:**
1. Active account: test_seller_1
2. Dropdown shows 2 accounts
3. Click "Disconnect Current"
4. Confirm in modal

**Expected:**
- ✅ test_seller_1 removed from storage
- ✅ Active account switches to test_seller_2
- ✅ Dropdown now shows only 1 account
- ✅ Display updates: "Active: test_seller_2 (sandbox)"
- ✅ Can still create listings (on test_seller_2)

### Test Scenario 7: Token Migration

**Setup:**
1. Create old-format token file manually:
```r
saveRDS(list(
  access_token = "old_token",
  refresh_token = "old_refresh",
  token_expiry = Sys.time() + 3600,
  environment = "sandbox"
), "data/ebay_tokens.rds")
```

**Steps:**
2. Delete `data/ebay_accounts.rds` if exists
3. Start app

**Expected:**
- ✅ Migration runs automatically
- ✅ Fetches username from old token
- ✅ Creates new multi-account file
- ✅ Old file renamed to `.backup`
- ✅ App shows: "Active: [username] (sandbox)"
- ✅ Can connect additional accounts

## Implementation Tasks

### Phase 1: Core Account Manager (4 hours)

**Task 1.1: Create EbayAccountManager class**
- File: `R/ebay_account_manager.R`
- Implement all public methods
- Add comprehensive error handling
- Include logging for debugging

**Task 1.2: Enhance EbayOAuth**
- File: `R/ebay_api.R`
- Add `get_user_info()` method
- Add `set_tokens()` method
- Test API endpoint with sandbox credentials

**Task 1.3: Token Migration**
- Add migration logic to account manager
- Test with manually created old token file
- Verify backup creation

### Phase 2: UI Updates (3 hours)

**Task 2.1: Update mod_ebay_auth UI**
- File: `R/mod_ebay_auth.R`
- Add account selector dropdown
- Add active account display
- Add "Connect New Account" button
- Add "Disconnect Current" button

**Task 2.2: Update mod_ebay_auth Server**
- Initialize account manager
- Implement account switching logic
- Update OAuth flow to add accounts
- Handle disconnect with confirmation

**Task 2.3: UI Polish**
- Add loading indicators
- Add success/error notifications
- Ensure proper button states
- Test conditional panels

### Phase 3: Database Integration (2 hours)

**Task 3.1: Database Migration**
- File: `R/ebay_database_extension.R`
- Add migration script for new columns
- Test migration with existing data
- Verify index creation

**Task 3.2: Update save_ebay_listing**
- Add `ebay_user_id` and `ebay_username` parameters
- Update INSERT statement
- Update UPDATE statement (if exists)

**Task 3.3: Integration Testing**
- Pass active account to save function
- Create test listings
- Verify database records
- Query by username

### Phase 4: Testing & Validation (2 hours)

**Task 4.1: Execute Sandbox Test Scenarios**
- Run all 7 test scenarios
- Document results
- Fix any issues found

**Task 4.2: Edge Case Testing**
- Expired tokens during switch
- Network errors during user info fetch
- Simultaneous listing creation attempts
- Disconnect while creating listing

**Task 4.3: Documentation**
- Update user guide
- Add code comments
- Create memory file with learnings

## Files to Create/Modify

**New Files:**
- `R/ebay_account_manager.R` - Account manager class

**Modified Files:**
- `R/ebay_api.R` - Add get_user_info() and set_tokens()
- `R/mod_ebay_auth.R` - Complete UI/server rewrite
- `R/ebay_database_extension.R` - Add user columns, migration
- `R/ebay_integration.R` - Pass active account to save function
- `inst/app/data/tracking.sqlite` - Schema update

**Data Files:**
- `data/ebay_accounts.rds` - New multi-account storage
- `data/ebay_tokens.rds.backup` - Backup of old format (if existed)

## Success Criteria

✅ **Sandbox Testing Complete When:**

1. Can connect 2+ sandbox accounts
2. Can switch between accounts without re-auth
3. Account switcher UI works smoothly
4. Each listing tracks correct username in database
5. Tokens persist across app restarts
6. Can disconnect specific accounts
7. Old single-account tokens migrate successfully
8. All 7 test scenarios pass
9. No errors in console
10. Token refresh works for all accounts

## Dependencies

**Required Before:**
- Current eBay OAuth implementation (DONE ✅)
- Database table `ebay_listings` exists (DONE ✅)
- Working sandbox credentials (DONE ✅)

**Required For:**
- Production switch (blocked by this)
- Multi-account production deployment
- Account-specific reporting features

## Risks & Mitigation

**Risk 1: User Info API Fails**
- **Mitigation:** Use user_id from token claims as fallback
- **Fallback:** Store as "User_{user_id}" until can fetch username

**Risk 2: Migration Issues**
- **Mitigation:** Comprehensive backup before migration
- **Rollback:** Restore `.backup` file if migration fails

**Risk 3: Token Refresh Complexity**
- **Mitigation:** Each account refreshes independently
- **Test:** Manually expire tokens and verify refresh

**Risk 4: UI State Management**
- **Mitigation:** Use reactiveVal for account manager
- **Test:** Rapid account switching, concurrent operations

## Timeline

**Estimated Effort:**
- Phase 1 (Core): 4 hours
- Phase 2 (UI): 3 hours
- Phase 3 (Database): 2 hours
- Phase 4 (Testing): 2 hours
- **Total: 11 hours**

**Recommended Schedule:**
- Day 1: Phase 1 (Core account manager)
- Day 2: Phase 2 (UI updates)
- Day 3: Phase 3 (Database) + Phase 4 (Testing)

## Next Steps After Sandbox Success

1. **Document Learnings** - Create memory file with insights
2. **Update Production PRP** - Modify production switch PRP to assume multi-account
3. **Production Testing** - Test multi-account with production credentials
4. **Consider Enhancements:**
   - Account management modal (view all accounts, usage stats)
   - Per-account filtering in tracking viewer
   - Account performance metrics

## Questions to Resolve Before Implementation

1. **Sandbox Credentials**: Do you have 2 different sandbox test user accounts to test with?
2. **UI Placement**: Where should the account switcher appear in the app layout?
3. **Default Behavior**: When connecting 2nd account, should it auto-switch or stay on 1st?
4. **Disconnect Confirmation**: Should disconnecting require password or just confirmation modal?

---

**Priority:** HIGH - Blocking production multi-account use case

**Complexity:** MEDIUM - Well-defined R6 class pattern, clear API endpoints

**Testing Environment:** Sandbox only (safe to test, no production impact)
