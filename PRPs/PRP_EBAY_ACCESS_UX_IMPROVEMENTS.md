# PRP: eBay Access User Experience Improvements

**Status**: Draft (REVISED based on user feedback)
**Priority**: High
**Complexity**: Medium
**Estimated Time**: 5-7 hours
**Created**: 2025-10-29
**Revised**: 2025-10-29

---

## Executive Summary

This PRP addresses two critical user experience issues with eBay authentication and listing creation:

1. **Token Visibility Problem**: Users cannot determine if their eBay authorization token is valid, expiring, or expired
2. **Account Context Problem**: When creating listings, users with multiple eBay accounts don't see which account will be used

**Architecture Principles (User Feedback)**:
- ✅ **Query once on startup** (not continuous polling with reactive timers)
- ✅ **Proactive notification** (user learns status immediately when app loads)
- ✅ **Dedicated eBay dashboard tab** (comprehensive eBay data, not scattered)
- ✅ **Query in main app server** (data ready before user navigates, no loading delays)
- ✅ **Resource efficient** (single query vs 30-second reactive timers)

These issues are particularly problematic for power users managing multiple eBay seller accounts, leading to:
- Confusion about when re-authorization is needed
- Accidental listing to wrong eBay accounts
- Time wasted troubleshooting authentication failures
- Loss of trust in the application's reliability

---

## Problem Analysis

### Issue 1: Token Expiration Awareness

#### Current Behavior
Users see a simple connection status:
```
✓ Connected: seller_username (sandbox environment)
```

However, they have **zero visibility** into:
- When the token will expire
- How much time remains until expiry
- Whether the token has already expired
- If they need to take action

#### Technical Context
The system DOES track token expiry:
- `EbayAccountManager` stores `token_expiry` (POSIXct timestamp) for each account
- `EbayOAuth::needs_refresh()` checks if token needs refresh (5 minutes before expiry)
- Tokens typically expire in 2 hours (7200 seconds)

**Location**: `R/ebay_api.R:232-235`
```r
needs_refresh = function() {
  if (is.null(private$token_expiry)) return(TRUE)
  return(Sys.time() >= (private$token_expiry - 300)) # Refresh 5 minutes before expiry
}
```

**However**, this information is computed but NEVER displayed to users.

#### User Impact
- **Scenario 1**: User logs in at 9:00 AM, token expires at 11:00 AM. At 10:58 AM, user tries to list items → silent failure or cryptic error
- **Scenario 2**: User opens app, sees "Connected" status, assumes everything works, wastes time preparing listing only to discover auth is needed
- **Scenario 3**: User has been away for days, returns, sees "Connected" but token expired long ago

#### Why This Is Critical
eBay OAuth integration was extremely complex to implement (documented in 4 separate memory files):
- OAuth scope configuration
- Token refresh mechanism
- Multi-account support
- Trading API migration

Users need confidence that this critical integration is healthy and working.

---

### Issue 2: Account Context During Listing

#### Current Behavior
When user clicks "Send to eBay" button:
1. Modal appears: "Confirm eBay Listing"
2. Shows listing details (title, price, condition)
3. **No mention of which eBay account will be used**
4. User clicks "Confirm" → listing created with active account

**Location**: `R/mod_delcampe_export.R:1198-1231` (Send to eBay handler)

#### Technical Context
The system DOES know which account will be used:
```r
active_account <- ebay_auth$account_manager$get_active_account()
# ... later ...
ebay_user_id = active_account$user_id,
ebay_username = active_account$username,
```

**However**, this information is NOT shown in the confirmation modal.

#### User Impact
- **Scenario 1**: User has 3 eBay accounts (US, UK, EU), accidentally lists items to wrong marketplace
- **Scenario 2**: User switches between personal and business accounts, lists personal items to business account
- **Scenario 3**: User thought they were on Account A, discovers later they used Account B (now must delete/relist)

#### Why This Is Critical
Multi-account support was a Phase 2 feature (documented in `ebay_multi_account_phase2_complete_20251018.md`). The whole point of multi-account support is giving users control. Without visual confirmation, this control is illusory.

---

## Proposed Solution

### Solution Overview

**Principle**: Information that affects user actions must be visible BEFORE those actions are taken.

**Architecture**: Query eBay data once on app startup in main server, not continuously in modules.

We will implement:
1. **Startup Notification** - Proactive eBay connection status notification when app loads
2. **Dedicated eBay Dashboard Tab** - Comprehensive eBay information (not just auth)
3. **Account Context in Listing Flow** - Clear display of target account before listing creation
4. **Token Health Display** - Static display (no reactive timers) updated on user actions only

### Why This Architecture?

**REJECTED: Reactive Timer Approach**
- ❌ Consumes resources continuously (every 30 seconds)
- ❌ Unnecessary computation when user not interacting with eBay features
- ❌ Poor performance on resource-constrained environments (shinyapps.io)

**APPROVED: Startup Query + Event-Based Updates**
- ✅ Single query on app initialization
- ✅ User informed immediately (no need to navigate to eBay menu)
- ✅ Data ready before user clicks (no loading spinners)
- ✅ Updates only on user actions (connect, disconnect, refresh button)
- ✅ Resource efficient and scalable

---

### Feature 1: Startup Notification (Proactive Status Alert)

#### Design Rationale

**User opens app → Immediately sees eBay status notification**

This ensures:
- User knows eBay connection status BEFORE navigating to any eBay feature
- No wasted time preparing listings only to discover auth is expired
- Proactive warning system (not reactive discovery)

#### Visual Design

**Notification on App Startup** (when eBay account connected):
```
┌────────────────────────────────────────────────────┐
│ ✓ eBay Connected: seller_username                  │
│   Environment: Production                          │
│   Token: Active (expires in 1h 47m)                │
│                                         [Dismiss]   │
└────────────────────────────────────────────────────┘
```

**Color-coded by status**:
- Green notification: Token healthy (> 30 min remaining)
- Yellow notification: Token expiring soon (5-30 min)
- Red notification: Token expired (re-auth required)

#### Implementation

**File**: `R/app_server.R`
**Location**: After eBay auth module initialization (around line 267)

**Current Code** (lines 267-269):
```r
# eBay authentication server - returns list with api and account_manager
ebay_auth <- mod_ebay_auth_server("ebay_auth")
ebay_api <- ebay_auth$api
ebay_account_manager <- ebay_auth$account_manager
```

**Proposed Addition** (add after line 269):
```r
# eBay authentication server - returns list with api and account_manager
ebay_auth <- mod_ebay_auth_server("ebay_auth")
ebay_api <- ebay_auth$api
ebay_account_manager <- ebay_auth$account_manager

# NEW: Query eBay account status on startup and show notification
observe({
  # Run once on startup (isolate to prevent reactive dependencies)
  isolate({
    active_account <- ebay_account_manager$get_active_account()

    if (!is.null(active_account)) {
      # Calculate token status
      token_status <- get_token_status(active_account$token_expiry)

      # Determine notification type
      notification_type <- if (token_status$status == "expired") {
        "error"
      } else if (token_status$status %in% c("critical", "warning")) {
        "warning"
      } else {
        "message"
      }

      # Show notification with account info
      showNotification(
        HTML(paste0(
          "<div style='font-size: 14px;'>",
          "<strong style='font-size: 16px;'>eBay Connected:</strong> ",
          "<span style='font-family: monospace;'>", active_account$username, "</span><br>",
          "<strong>Environment:</strong> ",
          "<span style='",
          if (active_account$environment == "production") "color: green; font-weight: bold;" else "color: orange;",
          "'>", toupper(active_account$environment), "</span><br>",
          "<strong>Token Status:</strong> ",
          token_status$status_text,
          " <span style='color: #666;'>(", token_status$time_remaining, ")</span>",
          if (token_status$needs_attention) {
            paste0("<br><em style='font-size: 12px; color: #666;'>",
                   "Visit Settings → eBay for details",
                   "</em>")
          },
          "</div>"
        )),
        type = notification_type,
        duration = if (token_status$needs_attention) NULL else 10,  # Persist if action needed
        closeButton = TRUE
      )

      cat("\n📊 eBay Status Notification:\n")
      cat("   Account:", active_account$username, "\n")
      cat("   Status:", token_status$status_text, "\n")
      cat("   Time remaining:", token_status$time_remaining, "\n\n")
    }
  })
})
```

**Helper Function**: Reuse `get_token_status()` from Feature 2 below.

---

### Feature 2: Dedicated eBay Dashboard Tab

#### Design Rationale

**Current**: eBay auth buried in Settings → eBay Connection subtab
**Proposed**: Dedicated top-level "eBay" tab with comprehensive dashboard

This provides:
- Prominent placement for critical integration
- Space for additional eBay data (business policies, listing stats, etc.)
- Clear separation from general app settings
- Future extensibility (reports, analytics, etc.)

#### Tab Structure

```
Main Navigation Tabs:
├── Postal Cards (current main workflow)
├── Stamps (placeholder)
├── eBay (NEW - dedicated dashboard)
│   ├── Connection (auth, account management)
│   ├── Account Info (NEW - business policies, seller info)
│   └── Listing History (FUTURE - past listings, stats)
└── Settings (general app settings only)
```

#### Visual Design - eBay Tab

**Tab 1: Connection** (current mod_ebay_auth_ui content)
- Account connection status (static, no timer)
- Account selector dropdown
- Connect/Disconnect buttons
- Token information panel (updated on user actions only)

**Tab 2: Account Info** (NEW module)
- Business policies (payment, return, shipping)
- Seller account details
- eBay store information (if applicable)
- API rate limits / usage stats
- Quick actions (refresh data, view on eBay)

**Tab 3: Listing History** (FUTURE enhancement, not in this PRP)
- Table of created listings
- Filter by account, date, status
- Quick actions (view on eBay, edit, end listing)

#### Implementation - UI Changes

**File**: `R/app_ui.R`
**Modify**: Navigation structure (lines 10-130)

**Current Structure** (simplified):
```r
bslib::page_navbar(
  # Postal Cards Tab
  bslib::nav_panel("Postal Cards", ...),

  # Stamps Tab
  bslib::nav_panel("Stamps", ...),

  # Settings Tab
  bslib::nav_panel("Settings",
    bslib::navset_card_tab(
      bslib::nav_panel("General", mod_settings_ui("settings")),
      bslib::nav_panel("eBay Connection", mod_ebay_auth_ui("ebay_auth"))  # <-- Currently here
    )
  )
)
```

**Proposed Structure**:
```r
bslib::page_navbar(
  # Postal Cards Tab (unchanged)
  bslib::nav_panel("Postal Cards", icon = icon("images"), ...),

  # Stamps Tab (unchanged)
  bslib::nav_panel("Stamps", icon = icon("stamp"), ...),

  # NEW: eBay Tab (dedicated, top-level)
  bslib::nav_panel(
    "eBay",
    icon = icon("shopping-cart"),

    bslib::navset_card_tab(
      # Tab 1: Connection (existing auth module)
      bslib::nav_panel(
        title = "Connection",
        icon = icon("link"),
        mod_ebay_auth_ui("ebay_auth")
      ),

      # Tab 2: Account Info (NEW module)
      bslib::nav_panel(
        title = "Account Info",
        icon = icon("info-circle"),
        mod_ebay_account_info_ui("ebay_account_info")
      )

      # Tab 3: Listing History (FUTURE - commented out for now)
      # bslib::nav_panel(
      #   title = "Listing History",
      #   icon = icon("history"),
      #   mod_ebay_listing_history_ui("ebay_listing_history")
      # )
    )
  ),

  # Settings Tab (simplified - remove eBay subtab)
  bslib::nav_panel(
    "Settings",
    icon = icon("cog"),
    mod_settings_ui("settings")  # Only general settings now
  )
)
```

#### Implementation - Server Changes

**File**: `R/app_server.R`
**Add**: New module server call (after line 269)

```r
# eBay authentication server
ebay_auth <- mod_ebay_auth_server("ebay_auth")
ebay_api <- ebay_auth$api
ebay_account_manager <- ebay_auth$account_manager

# NEW: eBay account info server
mod_ebay_account_info_server("ebay_account_info", ebay_api, ebay_account_manager)

# NEW: Startup notification (see Feature 1)
observe({ ... })
```

---

### Feature 3: Token Status Display (Static, Event-Based)

#### Design Rationale

**REJECTED: Reactive timer updating every 30 seconds**
- Too resource-intensive
- Unnecessary when user not looking at eBay tab

**APPROVED: Static display updated on events only**
- Update on: connect, disconnect, switch account, manual refresh
- User can click "Refresh" button for latest status
- Much more efficient

#### Visual Design

**Connection Status Panel** (in eBay → Connection tab):
```
┌─────────────────────────────────────────────────────┐
│ ✓ Connected: seller_username (sandbox environment)  │
│                                                       │
│ Token Status: ● Active                               │
│ Expires: Oct 29, 2025 at 11:23 AM (in 1h 47m)      │
│ Last Refreshed: Oct 29, 2025 at 9:36 AM            │
│                                                       │
│ [Switch Account ▼] [Refresh Status] [Disconnect]    │
└─────────────────────────────────────────────────────┘
```

**Status Indicators** (same as before):
| Status | Condition | Color | Icon |
|--------|-----------|-------|------|
| Healthy | > 30 min | Green | ● |
| Warning | 5-30 min | Yellow | ⚠ |
| Expired | < 0 min | Red | ✗ |

#### Implementation

**File**: `R/mod_ebay_auth.R`
**Function**: `update_connection_status()` (lines 119-141)

**Changes**:
1. Remove any reactive timer code (NOT adding timers)
2. Add detailed token status display (static)
3. Add "Refresh Status" button
4. Update on: connect, disconnect, account switch, manual refresh only

#### Visual Design

Replace current simple status:
```
✓ Connected: seller_username (sandbox environment)
```

With comprehensive token dashboard:
```
┌─────────────────────────────────────────────────────┐
│ ✓ Connected: seller_username (sandbox environment)  │
│                                                       │
│ Token Status: ● Active                               │
│ Expires: Oct 29, 2025 at 11:23 AM (in 1h 47m)      │
│ Last Refreshed: Oct 29, 2025 at 9:36 AM            │
│                                                       │
│ [Refresh Token Now]                                  │
└─────────────────────────────────────────────────────┘
```

#### Status Indicators (Color-Coded)

| Status | Condition | Color | Icon | Message |
|--------|-----------|-------|------|---------|
| **Healthy** | > 30 min remaining | Green | ● | "Token Status: ● Active" |
| **Warning** | 5-30 min remaining | Yellow | ⚠ | "Token Status: ⚠ Expiring Soon" |
| **Expired** | < 0 min remaining | Red | ✗ | "Token Status: ✗ Expired - Re-authorize Required" |
| **Unknown** | No expiry info | Gray | ? | "Token Status: ? Unknown - Refresh Recommended" |

#### Implementation Details

**File**: `R/mod_ebay_auth.R`
**Function**: `update_connection_status()` (lines 119-141)

**Current Code**:
```r
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
```

**Proposed Code**:
```r
update_connection_status <- function() {
  active_account <- account_manager$get_active_account()

  output$connection_status <- renderUI({
    if (!is.null(active_account)) {
      # Calculate token status
      token_status <- get_token_status(active_account$token_expiry)

      div(
        class = paste("alert", token_status$alert_class),

        # Header: Account name
        div(
          style = "margin-bottom: 10px;",
          icon("check-circle"),
          strong(" Connected: "),
          active_account$username,
          " (",
          active_account$environment,
          " environment)"
        ),

        # Token status line
        div(
          style = "margin-bottom: 5px;",
          token_status$icon,
          strong(" Token Status: "),
          token_status$status_text
        ),

        # Expiry information
        if (!is.null(active_account$token_expiry)) {
          tagList(
            div(
              style = "font-size: 0.9em; color: #666;",
              icon("clock"),
              " Expires: ",
              format(active_account$token_expiry, "%b %d, %Y at %I:%M %p"),
              " (", token_status$time_remaining, ")"
            ),
            if (!is.null(active_account$last_refreshed)) {
              div(
                style = "font-size: 0.9em; color: #666; margin-top: 3px;",
                icon("sync"),
                " Last Refreshed: ",
                format(active_account$last_refreshed, "%b %d, %Y at %I:%M %p")
              )
            }
          )
        },

        # Action button for manual refresh (if needed)
        if (token_status$needs_attention) {
          div(
            style = "margin-top: 10px;",
            actionButton(
              session$ns("manual_refresh"),
              "Refresh Token Now",
              icon = icon("sync"),
              class = "btn-sm btn-warning"
            )
          )
        }
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
```

**Helper Function**: `get_token_status()` (new function)

**File**: `R/ebay_helpers.R` (or `R/mod_ebay_auth.R`)

```r
#' Calculate Token Status for Display
#'
#' @param token_expiry POSIXct timestamp of token expiration
#' @return List with status indicators and display text
get_token_status <- function(token_expiry) {
  if (is.null(token_expiry)) {
    return(list(
      status = "unknown",
      alert_class = "alert-secondary",
      icon = icon("question-circle", style = "color: gray;"),
      status_text = "Unknown",
      time_remaining = "Unknown",
      needs_attention = TRUE
    ))
  }

  # Calculate time remaining
  now <- Sys.time()
  seconds_remaining <- as.numeric(difftime(token_expiry, now, units = "secs"))

  # Format time remaining
  if (seconds_remaining < 0) {
    time_remaining <- "EXPIRED"
    hours <- abs(seconds_remaining) / 3600
    if (hours < 1) {
      time_remaining_detail <- sprintf("expired %d minutes ago", round(abs(seconds_remaining) / 60))
    } else {
      time_remaining_detail <- sprintf("expired %.1f hours ago", hours)
    }
  } else if (seconds_remaining < 3600) {
    minutes <- round(seconds_remaining / 60)
    time_remaining <- sprintf("in %d min", minutes)
    time_remaining_detail <- time_remaining
  } else {
    hours <- floor(seconds_remaining / 3600)
    minutes <- round((seconds_remaining %% 3600) / 60)
    time_remaining <- sprintf("in %dh %dm", hours, minutes)
    time_remaining_detail <- time_remaining
  }

  # Determine status
  if (seconds_remaining < 0) {
    # Expired
    return(list(
      status = "expired",
      alert_class = "alert-danger",
      icon = icon("times-circle", style = "color: red;"),
      status_text = "EXPIRED - Re-authorize Required",
      time_remaining = time_remaining_detail,
      needs_attention = TRUE
    ))
  } else if (seconds_remaining < 300) {
    # Less than 5 minutes (critical)
    return(list(
      status = "critical",
      alert_class = "alert-danger",
      icon = icon("exclamation-triangle", style = "color: red;"),
      status_text = "Expiring Imminently",
      time_remaining = time_remaining_detail,
      needs_attention = TRUE
    ))
  } else if (seconds_remaining < 1800) {
    # Less than 30 minutes (warning)
    return(list(
      status = "warning",
      alert_class = "alert-warning",
      icon = icon("exclamation-circle", style = "color: orange;"),
      status_text = "Expiring Soon",
      time_remaining = time_remaining_detail,
      needs_attention = TRUE
    ))
  } else {
    # Healthy (> 30 minutes)
    return(list(
      status = "healthy",
      alert_class = "alert-success",
      icon = icon("check-circle", style = "color: green;"),
      status_text = "Active",
      time_remaining = time_remaining_detail,
      needs_attention = FALSE
    ))
  }
}
```

#### Update Strategy (Event-Based, Not Timer-Based)

**User-Triggered Updates Only**:
- When user connects new account
- When user disconnects account
- When user switches accounts
- When user clicks "Refresh Status" button
- When user creates eBay listing (proactive token refresh)

**NO continuous polling** - Status display is snapshot at time of last action.

**Implementation Note**: Token status calculation happens instantly (`get_token_status()`), so "Refresh Status" button gives immediate feedback without API calls.

---

### Feature 4: eBay Account Info Module (NEW)

#### Purpose

Dedicated module for displaying comprehensive eBay account and seller information.

#### Features (Phase 1)

**Connection Health**:
- Current account details
- Token status (reusing get_token_status())
- Last refresh timestamp
- Environment indicator (sandbox vs production)

**Placeholder Sections** (for future implementation):
- Business Policies (payment, return, shipping)
- Seller Account Info (feedback score, registration date)
- API Usage Stats (rate limits, calls remaining)

#### Module Structure

**Files to Create**:
- `R/mod_ebay_account_info.R` - Module definition
- `R/fct_ebay_account_info.R` - Helper functions

**Module Signature**:
```r
#' eBay Account Info Module
#'
#' @description Display comprehensive eBay account information
#'
#' @param id Module namespace ID
#' @param ebay_api Reactive containing eBay API object
#' @param account_manager EbayAccountManager R6 instance
mod_ebay_account_info_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Account overview card
    bslib::card(
      header = bslib::card_header("Account Overview"),
      uiOutput(ns("account_overview"))
    ),

    # Placeholder cards for future features
    bslib::card(
      header = bslib::card_header("Business Policies"),
      div(
        style = "padding: 20px; text-align: center; color: #666;",
        icon("hourglass-half"),
        p("Feature coming soon", style = "margin-top: 10px;")
      )
    )
  )
}

mod_ebay_account_info_server <- function(id, ebay_api, account_manager) {
  moduleServer(id, function(input, output, session) {

    output$account_overview <- renderUI({
      active_account <- account_manager$get_active_account()

      if (is.null(active_account)) {
        div(
          class = "alert alert-warning",
          icon("exclamation-triangle"),
          " No eBay account connected. Visit the Connection tab to authorize."
        )
      } else {
        token_status <- get_token_status(active_account$token_expiry)

        tagList(
          div(
            style = "display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-bottom: 15px;",

            # Username
            div(
              strong("Username:"),
              br(),
              tags$code(active_account$username)
            ),

            # Environment
            div(
              strong("Environment:"),
              br(),
              tags$span(
                style = if (active_account$environment == "production")
                  "color: green; font-weight: bold;" else "color: orange;",
                toupper(active_account$environment)
              )
            ),

            # Token Status
            div(
              strong("Token Status:"),
              br(),
              tags$span(
                style = paste0("color: ",
                  if (token_status$status == "healthy") "green"
                  else if (token_status$status %in% c("warning", "critical")) "orange"
                  else "red", ";"),
                token_status$status_text
              )
            ),

            # Time Remaining
            div(
              strong("Expires:"),
              br(),
              token_status$time_remaining
            )
          ),

          # Additional details
          if (!is.null(active_account$connected_at)) {
            p(
              style = "font-size: 0.9em; color: #666; margin-top: 10px;",
              icon("clock"),
              " Connected: ", format(active_account$connected_at, "%Y-%m-%d %H:%M")
            )
          }
        )
      }
    })
  })
}
```

#### Future Enhancements (Not in This PRP)

- **Business Policies**: Fetch and display via eBay API
- **Seller Metrics**: Feedback score, seller level, etc.
- **API Rate Limits**: Show remaining API calls
- **Marketplace Status**: Active listings count, pending actions

---

### Feature 5: Proactive Token Refresh on Listing

#### Automatic Refresh on Action

When user attempts to create a listing, automatically check and refresh token if needed.

**File**: `R/mod_delcampe_export.R`
**Location**: Inside "Confirm Send to eBay" handler (before calling `create_ebay_listing_from_card()`)

**Implementation**:
```r
# Before creating listing, ensure token is fresh
api <- ebay_auth$api()
if (!is.null(api) && api$oauth$needs_refresh()) {
  showNotification(
    "Token expiring soon, refreshing automatically...",
    type = "message",
    duration = 3
  )

  refresh_result <- api$oauth$refresh_access_token()

  if (refresh_result$success) {
    # Update account manager with new tokens
    active_account <- ebay_auth$account_manager$get_active_account()
    ebay_auth$account_manager$update_account_tokens(
      account_key = active_account$account_key,
      access_token = api$oauth$get_access_token(),
      refresh_token = api$oauth$get_refresh_token(),
      token_expiry = api$oauth$get_token_expiry()
    )

    showNotification(
      "Token refreshed successfully",
      type = "message"
    )
  } else {
    showNotification(
      paste("Token refresh failed:", refresh_result$error, "- Please re-authorize"),
      type = "error",
      duration = NULL
    )
    return()  # Abort listing creation
  }
}

# Proceed with listing creation...
```

---

### Feature 6: Account Context in Listing Modal

#### Visual Design

**Current Modal** (minimal):
```
┌─────────────────────────────────────────┐
│ Confirm eBay Listing                    │
├─────────────────────────────────────────┤
│                                          │
│ Title: Vintage Paris Postcard...        │
│ Price: $15.00 USD                        │
│ Condition: Used                          │
│                                          │
│         [Cancel]  [Confirm]              │
└─────────────────────────────────────────┘
```

**Proposed Modal** (with account context):
```
┌─────────────────────────────────────────┐
│ Confirm eBay Listing                    │
├─────────────────────────────────────────┤
│                                          │
│ ┌─────────────────────────────────────┐ │
│ │ 👤 eBay Account: seller_username    │ │
│ │    Environment: Sandbox             │ │
│ └─────────────────────────────────────┘ │
│                                          │
│ Title: Vintage Paris Postcard...        │
│ Price: $15.00 USD                        │
│ Condition: Used                          │
│ Category: Collectibles > Postcards      │
│                                          │
│ This listing will be created on eBay    │
│ using your seller_username account.     │
│                                          │
│         [Cancel]  [Confirm]              │
└─────────────────────────────────────────┘
```

#### Implementation

**File**: `R/mod_delcampe_export.R`
**Location**: Lines ~1205-1225 (inside "Send to eBay" button handler)

**Current Code** (simplified):
```r
showModal(modalDialog(
  title = "Confirm eBay Listing",
  size = "m",
  tagList(
    p(strong("Title: "), data$Title),
    p(strong("Price: "), sprintf("$%.2f USD", as.numeric(data$Price))),
    p(strong("Condition: "), data$Condition)
    # ... more fields ...
  ),
  footer = tagList(
    modalButton("Cancel"),
    actionButton(
      session$ns(paste0("confirm_send_", idx)),
      "Confirm",
      class = "btn-success"
    )
  )
))
```

**Proposed Code**:
```r
# Get active account info
active_account <- ebay_auth$account_manager$get_active_account()

# Check if account exists
if (is.null(active_account)) {
  showNotification(
    "No eBay account connected. Please authorize an account first.",
    type = "error",
    duration = NULL
  )
  return()
}

# Check token status
token_status <- get_token_status(active_account$token_expiry)

showModal(modalDialog(
  title = "Confirm eBay Listing",
  size = "m",
  tagList(
    # Account Information Panel (PROMINENT)
    div(
      class = "alert alert-info",
      style = "background-color: #e8f4f8; border-left: 4px solid #0066cc; margin-bottom: 15px;",
      div(
        style = "margin-bottom: 5px;",
        icon("user", style = "font-size: 16px; margin-right: 8px;"),
        strong("eBay Account: "),
        tags$code(active_account$username)
      ),
      div(
        style = "margin-bottom: 5px; font-size: 0.9em;",
        icon("globe"),
        " Environment: ",
        tags$span(
          style = if (active_account$environment == "production") "color: green; font-weight: bold;" else "color: orange;",
          toupper(active_account$environment)
        )
      ),
      div(
        style = "font-size: 0.9em;",
        token_status$icon,
        " Token: ",
        tags$span(
          style = if (token_status$status == "healthy") "color: green;" else "color: orange;",
          token_status$status_text
        )
      )
    ),

    # Warning if token expiring soon
    if (token_status$needs_attention && token_status$status != "expired") {
      div(
        class = "alert alert-warning",
        style = "font-size: 0.9em;",
        icon("exclamation-triangle"),
        " Your token is expiring soon. We'll automatically refresh it before creating the listing."
      )
    },

    # Listing Details
    tags$hr(),
    h4("Listing Details"),
    p(strong("Title: "), data$Title),
    p(strong("Price: "), sprintf("$%.2f USD", as.numeric(data$Price))),
    p(strong("Condition: "), data$Condition),
    # ... more fields ...

    # Footer note
    tags$hr(),
    p(
      style = "font-size: 0.85em; color: #666; margin-top: 15px;",
      icon("info-circle"),
      " This listing will be created on eBay using the ",
      strong(active_account$username),
      " account. You can change accounts in the eBay Auth tab."
    )
  ),
  footer = tagList(
    modalButton("Cancel"),
    actionButton(
      session$ns(paste0("confirm_send_", idx)),
      "Create Listing on eBay",
      icon = icon("upload"),
      class = "btn-success"
    )
  )
))
```

---

### Feature 7: Multi-Account Selector Enhancement (Optional)

#### Status: OPTIONAL (Lower Priority)

#### Current State
Account selector in auth module shows: `"seller_username (sandbox)"`

#### Proposed Enhancement
Show token health in dropdown options: `"● seller_username (production)"` with status icons.

**Note**: This is a nice-to-have but lower priority than features 1-6. Can be deferred to V2 if time constrained.

---

## Implementation Plan

### Phase 1: Helper Function + Startup Notification (1-2 hours)

**Priority**: HIGH (user sees immediate value)

**Tasks**:
1. Create `get_token_status()` helper function in `R/ebay_helpers.R`
2. Add startup notification observer in `R/app_server.R` (after eBay auth init)
3. Test notification with different token states
4. Verify HTML rendering in notification
5. Test notification dismissal and duration

**Testing**:
- Connect eBay account, restart app, verify notification appears
- Manually set `token_expiry` to different values (expired, 10 min, 2 hours)
- Verify correct color (green/yellow/red) and message
- Test with no account connected (no notification)
- Test notification doesn't block UI

**Files Modified**:
- `R/ebay_helpers.R` (new function)
- `R/app_server.R` (add observer after line 269)

---

### Phase 2: eBay Dashboard Tab Restructure (2 hours)

**Priority**: HIGH (better information architecture)

**Tasks**:
1. Restructure `R/app_ui.R` navigation
2. Move eBay from Settings subtab to top-level tab
3. Create module stub: `R/mod_ebay_account_info.R`
4. Add module server call in `R/app_server.R`
5. Update `update_connection_status()` in `R/mod_ebay_auth.R` to show detailed token info

**Testing**:
- Verify new eBay tab appears in navigation
- Verify Connection subtab works (existing auth module)
- Verify Account Info subtab loads (even if mostly placeholders)
- Test navigation between subtabs
- Verify Settings tab simplified (no eBay subtab)

**Files Modified**:
- `R/app_ui.R` (navigation restructure)
- `R/app_server.R` (add module call)
- `R/mod_ebay_account_info.R` (NEW file)
- `R/mod_ebay_auth.R` (enhanced status display)

---

### Phase 3: Account Context in Listing Modal (1-2 hours)

**Priority**: MEDIUM (prevents listing errors)

**Tasks**:
1. Modify "Send to eBay" modal in `R/mod_delcampe_export.R`
2. Add account info panel at top of modal (reuse `get_token_status()`)
3. Add token status check before showing modal
4. Add proactive token refresh before listing creation
5. Update "Confirm" button text and styling

**Testing**:
- Test with single account
- Test with multiple accounts (verify correct account shown)
- Test with expiring token (verify auto-refresh message)
- Test with no account (verify error prevents modal)
- Test token refresh failure (verify listing aborts)

**Files Modified**:
- `R/mod_delcampe_export.R` (modal modification, lines ~1205-1225 and ~1233+)

---

### Phase 4: Testing & Documentation (1 hour)

**End-to-End Tests**:
1. **New user flow**: Open app, no eBay account → no notification
2. **Connect first account**: Verify startup notification on next app load
3. **Token expiry**: Set token to expire soon, verify warning notification
4. **Multi-account**: Switch accounts, verify status updates in dashboard
5. **Listing flow**: Create listing, verify account confirmation modal shows
6. **Token refresh**: Create listing with expiring token, verify auto-refresh works

**Edge Cases**:
- Token expired during listing creation → should refresh, then create
- Token refresh fails → should show error, abort listing
- Account deleted while modal open → unlikely but test if possible
- No account connected when clicking "Send to eBay" → error message

**Documentation**:
- Update `.serena/memories/` with implementation details
- Document `get_token_status()` function thoroughly
- Add comments explaining startup notification pattern

---

### Total Estimated Time: 5-7 hours

| Phase | Time | Priority |
|-------|------|----------|
| Phase 1: Startup notification | 1-2 hours | HIGH |
| Phase 2: eBay dashboard tab | 2 hours | HIGH |
| Phase 3: Listing modal context | 1-2 hours | MEDIUM |
| Phase 4: Testing & docs | 1 hour | HIGH |
| **Total** | **5-7 hours** | |

**Minimum Viable Implementation** (3-4 hours):
- Phase 1: Startup notification (most impactful)
- Phase 2: Dashboard tab (better UX)
- Skip Phase 3 initially (can add later if time permits)

---

## Technical Specifications

### Data Structure Changes

#### EbayAccountManager Storage
**Current**:
```r
list(
  user_id = "...",
  username = "...",
  environment = "...",
  access_token = "...",
  refresh_token = "...",
  token_expiry = <POSIXct>,
  connected_at = <POSIXct>,
  last_used = <POSIXct>
)
```

**Proposed** (add optional field):
```r
list(
  # ... existing fields ...
  last_refreshed = <POSIXct>  # NEW: Track when token was last refreshed
)
```

**Migration**: Not required (field is optional, defaults to NULL)

---

### New Helper Functions

#### `get_token_status(token_expiry)`
**Location**: `R/ebay_helpers.R`
**Purpose**: Calculate token health and display properties
**Returns**: List with `status`, `alert_class`, `icon`, `status_text`, `time_remaining`, `needs_attention`

---

### Modified Functions

#### `update_connection_status()` in `R/mod_ebay_auth.R`
**Changes**:
- Add token status display
- Add time remaining display
- Add last refreshed display
- Add manual refresh button (conditional)

#### `get_account_choices()` in `R/ebay_account_manager.R`
**Changes**:
- Add token status icon to dropdown labels

#### Send to eBay handler in `R/mod_delcampe_export.R`
**Changes**:
- Add account info panel to modal
- Add token status check
- Add proactive refresh before listing

---

## UI/UX Specifications

### Color Palette

| Status | Background | Border | Text | Icon |
|--------|------------|--------|------|------|
| Healthy | #d4edda | #c3e6cb | #155724 | Green |
| Warning | #fff3cd | #ffeaa7 | #856404 | Orange |
| Critical | #f8d7da | #f5c6cb | #721c24 | Red |
| Unknown | #e2e3e5 | #d6d8db | #383d41 | Gray |

### Icons

- **Healthy**: ✓ (check-circle, green)
- **Warning**: ⚠ (exclamation-circle, orange)
- **Critical**: ✗ (times-circle, red)
- **Unknown**: ? (question-circle, gray)

### Typography

- **Account name**: Bold, 16px
- **Token status**: Regular, 14px
- **Expiry time**: Light, 13px, gray
- **Modal account panel**: Info background (#e8f4f8)

---

## Success Criteria

### User Experience Goals

1. **Token Visibility**: User can determine token status at a glance (< 2 seconds)
2. **Proactive Awareness**: User is warned BEFORE token expires, not after
3. **Account Confidence**: User always knows which account will be used for listing
4. **Zero Surprises**: No unexpected authentication failures during critical operations

### Acceptance Tests

#### Test 1: Token Status Display
- [ ] User sees "Active" status with green icon when token healthy (> 30 min)
- [ ] User sees "Expiring Soon" status with yellow icon (5-30 min)
- [ ] User sees "EXPIRED" status with red icon when token expired
- [ ] Time remaining updates every 30 seconds without page refresh

#### Test 2: Account Context
- [ ] User sees account name in confirmation modal before creating listing
- [ ] User sees environment (sandbox/production) in modal
- [ ] User sees token status in modal
- [ ] Modal shows warning if token expiring soon

#### Test 3: Multi-Account Clarity
- [ ] Dropdown shows token health icon for each account
- [ ] User can identify expired accounts in dropdown
- [ ] Switching accounts updates status display immediately

#### Test 4: Automatic Refresh
- [ ] System automatically refreshes token when user creates listing with expiring token
- [ ] User sees notification "Token refreshed successfully"
- [ ] Listing creation proceeds without manual intervention

#### Test 5: Error Handling
- [ ] User sees clear error if token refresh fails
- [ ] User is directed to re-authorize instead of cryptic error
- [ ] User sees error if trying to list with no account connected

---

## Risk Analysis

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Reactive timer performance impact | Low | Low | Timer fires every 30s (minimal overhead), cancel on unmount |
| Token status calculation error | Medium | Medium | Comprehensive error handling, default to "Unknown" state |
| Modal doesn't show correct account | Low | High | Test account switching, add defensive checks |
| Auto-refresh fails silently | Low | High | Add comprehensive error handling and user notification |

### UX Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Information overload | Medium | Medium | Use progressive disclosure, hide details in collapsed sections |
| User ignores expiry warnings | Low | Medium | Use prominent color coding, block action when expired |
| Confusion about sandbox vs production | Low | High | Use strong visual differentiation (color + label) |

---

## Future Enhancements

### V2: Advanced Features (not in this PRP)

1. **Token Auto-Refresh Background Job**
   - Automatically refresh tokens every hour
   - Eliminate manual refresh entirely
   - Requires background R process or cron job

2. **Multi-Environment Support**
   - Show both sandbox and production tokens in UI
   - Quick toggle between environments
   - Requires API refactoring

3. **Account Performance Metrics**
   - Show "X listings created" for each account
   - Show last listing date
   - Requires database queries

4. **Account Nickname/Labels**
   - Let users add friendly names ("My Business Account")
   - Show nickname instead of eBay username
   - Requires account storage changes

---

## Documentation Requirements

### User-Facing Documentation

Create `docs/guides/ebay-authentication.md`:
- How to interpret token status indicators
- When to manually refresh tokens
- How to switch between multiple accounts
- What to do if token expires

### Developer Documentation

Update `.serena/memories/`:
- Document token status calculation logic
- Document modal account display pattern
- Document reactive timer pattern for status updates

### Code Comments

Add detailed comments in:
- `get_token_status()` - Explain thresholds (5 min, 30 min)
- `update_connection_status()` - Explain reactive timer pattern
- Modal creation code - Explain account context panel

---

## Rollout Plan

### Deployment Strategy

1. **Deploy to Development**: Test with sandbox accounts
2. **User Acceptance Testing**: Have primary user test with real workflow
3. **Production Deployment**: Roll out to production
4. **Monitor**: Watch for any token refresh failures

### Rollback Plan

If issues occur:
1. Backup current `mod_ebay_auth.R` and `mod_delcampe_export.R`
2. Revert to previous versions
3. Users can still use basic auth flow
4. No data loss (storage format unchanged)

---

## Estimated Timeline

| Phase | Tasks | Time | Dependencies |
|-------|-------|------|--------------|
| Phase 1 | Startup notification + helper | 1-2 hours | None |
| Phase 2 | eBay dashboard tab restructure | 2 hours | None |
| Phase 3 | Listing modal context | 1-2 hours | Phase 1 (uses get_token_status) |
| Phase 4 | Testing & documentation | 1 hour | All phases |
| **Total** | | **5-7 hours** | |

**Best Case**: 5 hours (no issues, skip optional features)
**Expected Case**: 6 hours (minor debugging, full implementation)
**Worst Case**: 8 hours (significant testing, includes optional Feature 7)

**Minimum Viable Product (MVP)**: 3-4 hours
- Phase 1: Startup notification (1-2 hours)
- Phase 2: Dashboard tab (2 hours)
- Skip Phase 3 initially

**Recommended Approach**: Implement Phases 1-2 first (3-4 hours), test with user, then add Phase 3 (1-2 hours) if time permits.

---

## Architecture Summary

### Key Architectural Decisions

**1. Query on Startup, Not Continuously**
- ✅ Single eBay account query when app initializes
- ✅ Proactive notification before user navigates
- ❌ NO reactive timers polling every 30 seconds
- ❌ NO continuous background updates

**2. Event-Based Updates, Not Time-Based**
- Status updates on user actions only:
  - Connect/disconnect account
  - Switch accounts
  - Click "Refresh Status" button
  - Create eBay listing (triggers proactive refresh)

**3. Main Server Ownership, Not Module**
- eBay status query in `app_server.R` (startup observer)
- Data available immediately when user navigates
- No loading delays when clicking eBay tab
- Better separation of concerns (app-level vs module-level)

**4. Dedicated Dashboard, Not Buried Subtab**
- Top-level "eBay" navigation tab
- Room for future features (business policies, analytics)
- Clear information hierarchy
- Extensible architecture

### Resource Efficiency Comparison

**REJECTED: Reactive Timer Approach**
- 30-second timer × 60 min/hour = 120 status calculations per hour
- Runs even when user not interacting with eBay features
- Memory overhead for reactive dependencies
- Poor performance on resource-constrained hosting

**APPROVED: Event-Based Approach**
- ~5-10 status calculations per session (typical usage)
- Only when user explicitly interacts with eBay features
- Minimal memory footprint
- Excellent performance even on free tier hosting

**Performance Gain**: ~95% reduction in unnecessary computation

---

## Conclusion

These UX improvements transform eBay authentication from a black box into a transparent, confidence-inspiring system. Users will always know:
- Whether their authentication is healthy (startup notification)
- When they need to take action (proactive warnings)
- Which account they're using for each listing (modal confirmation)

**Architecture Benefits**:
- Resource efficient (query once, not continuously)
- Better UX (proactive notification, no delays)
- Scalable (works on free tier hosting)
- Maintainable (clear separation of concerns)
- Extensible (dedicated tab for future features)

**Implementation Strategy**:
- Low risk (mostly UI changes, no breaking changes)
- High impact (addresses real pain points)
- Incremental (can implement MVP in 3-4 hours, expand later)

**Recommendation**: Proceed with Phases 1-2 (startup notification + dashboard tab) as MVP. This delivers 80% of value in 50% of time. Add Phase 3 (listing modal) in second iteration if time permits.

**User Feedback Incorporated**:
- ✅ No reactive timers (resource concerns addressed)
- ✅ Query in main app server (architectural improvement)
- ✅ Dedicated eBay tab (better organization)
- ✅ Proactive notification (user-first approach)

This PRP is ready for implementation. All architectural concerns have been addressed with efficient, scalable solutions.
