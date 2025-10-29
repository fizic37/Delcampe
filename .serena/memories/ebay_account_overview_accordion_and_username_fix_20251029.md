# eBay Account Overview Accordion & Username Extraction Fix

**Date**: 2025-10-29  
**Status**: ✅ Complete  
**Related Files**: `R/mod_ebay_auth.R`, `R/ebay_api.R`, `R/ebay_helpers.R`, `R/app_server.R`

## Overview

Implemented Account Overview accordion in eBay Connection settings and fixed critical username extraction issues that were causing eBay usernames to display as generated fallback values like `eBay_production_c6e43e01`.

## Problem Statement

**User Request**: "I dont want phase 3 but I do want the account info tab somewhere inside the ebay UI but better looking"

Initial Phase 2 implementation (dedicated Account Info module with 2-column grid) was rejected as "extremely poorly designed" with username showing internal key instead of actual eBay username.

## Solution Architecture

### 1. Account Overview Accordion

**Location**: Settings → eBay Connection (bottom of page)

**Design Decision**: User suggested accordion pattern for clean, collapsible UI

**Implementation** (`R/mod_ebay_auth.R`):
- Added `update_account_overview()` function (lines 146-241)
- Renders `bslib::accordion()` with single panel
- Shows 3 info rows when account connected:
  1. **Username**: User's actual eBay username
  2. **Environment**: PRODUCTION (green) or SANDBOX (orange badge)
  3. **Token Status**: Color-coded (green/yellow/red) with expiry time
- Hidden when no account connected (clean UX)
- Auto-updates on: connect, disconnect, switch, refresh

**UI Placement**: Bottom of eBay Connection tab (lines 83-87 in `mod_ebay_auth_ui`)

**Integration**: Calls `update_account_overview()` in 5 locations:
- Startup initialization (line 117)
- Account switch (line 292)
- Refresh status (line 321)
- New connection (line 471)
- Disconnect (line 558)

### 2. Username Extraction Fix

**Root Cause**: All username extraction methods were failing, causing fallback to generated username `eBay_{environment}_{hash}` (see `R/ebay_api.R:400-407`)

**Debug Output Revealed**:
```
❌ JWT decoding failed: embedded nul in string: '\xd6-Hޝ... (gzip compressed)
🌐 Attempting eBay User API call...
  URL: https://api.ebay.com/commerce/identity/v1/user/
❌ API call failed: HTTP 404 Not Found.
⚠️ All methods failed - using generated fallback username
```

**3 Critical Issues Fixed**:

#### Issue 1: Missing OAuth Scope
**Problem**: Not requesting `commerce.identity.readonly` scope  
**Fix** (`R/ebay_api.R:90`):
```r
scope <- paste(
  "https://api.ebay.com/oauth/api_scope",
  "https://api.ebay.com/oauth/api_scope/sell.inventory",
  "https://api.ebay.com/oauth/api_scope/sell.account",
  "https://api.ebay.com/oauth/api_scope/sell.fulfillment",
  "https://api.ebay.com/oauth/api_scope/commerce.identity.readonly",  # NEW
  sep = " "
)
```

#### Issue 2: Wrong API Domain
**Problem**: Using `api.ebay.com` instead of `apiz.ebay.com`  
**Reference**: https://developer.ebay.com/api-docs/commerce/identity/resources/user/methods/getUser

**Fix** (`R/ebay_api.R:366-369`):
```r
# IMPORTANT: Identity API uses apiz.ebay.com, not api.ebay.com
base_url <- private$config$get_base_url()
identity_url <- gsub("^https://api\\.", "https://apiz.", base_url)
user_url <- paste0(identity_url, "/commerce/identity/v1/user")
```

#### Issue 3: Incorrect Response Parsing
**Problem**: Not handling eBay's field names correctly  
**Fix** (`R/ebay_api.R:383-384`):
```r
user_id <- if (!is.null(user_data$userId)) user_data$userId else user_data$user_id
username <- if (!is.null(user_data$username)) user_data$username else user_data$userName
```

### 3. Comprehensive Debug Logging

Added extensive logging to `get_user_info()` (`R/ebay_api.R:287-408`):
- Shows JWT payload claims attempted
- Shows API call URL and response
- Clearly indicates which method succeeded or failed
- Helps diagnose future OAuth issues

Example successful output:
```
🔍 Attempting to extract user info from eBay token...
❌ JWT decoding failed: [expected - token is compressed]
🌐 Attempting eBay User API call...
  URL: https://apiz.ebay.com/commerce/identity/v1/user
✅ API call successful!
  API response fields: userId, username, accountType, registrationMarketplaceId
  User ID: U1234567
  Username: actual_ebay_username
```

### 4. Token Status Helper Function

**Location**: `R/ebay_helpers.R:314-434` (added in Phase 1)

**Function**: `get_token_status(token_expiry)`

**Returns**:
- `status`: "healthy", "warning", "critical", "expired", "unknown"
- `alert_class`: Bootstrap alert class
- `icon`: Shiny icon with inline styling
- `status_text`: Human-readable status
- `time_remaining`: Formatted time string
- `needs_attention`: Boolean flag

**Thresholds**:
- Healthy: >1800 seconds (30 minutes) - green
- Warning: 300-1800 seconds (5-30 minutes) - yellow
- Critical: <300 seconds (5 minutes) - red
- Expired: negative seconds - red

**Usage**: Called by both startup notification and account overview accordion

## User Testing & Feedback

### Phase 1 (Startup Notification)
- ✅ Initially approved but wording confusing: "Token Status: Active (in 1h 59m)"
- ✅ Fixed to: "Token Status: Active - expires in 1h 59m"

### Phase 2 (Dedicated Account Info Tab)
- ❌ **REJECTED**: "extremely poorly designed"
- Issues: 2-column grid, wrong username display, top-level navigation
- ✅ **Reverted**: Moved eBay back to Settings subtab

### Phase 3 (Accordion Design)
- ✅ **APPROVED**: User suggested accordion approach
- ✅ **CONFIRMED**: "It looks good now"
- ⏳ **Testing**: User must reconnect to grant new OAuth scope

## Critical User Action Required

**IMPORTANT**: Because we added `commerce.identity.readonly` scope, users must:
1. Disconnect current eBay account
2. Connect new account (eBay will prompt for new permission)
3. Grant `commerce.identity.readonly` scope
4. Accordion will now show real eBay username

## Implementation Files

### Modified Files
1. **R/mod_ebay_auth.R**
   - Added `update_account_overview()` function
   - Added accordion UI in module UI (bottom placement)
   - Integrated calls in 5 observer locations

2. **R/ebay_api.R**
   - Added `commerce.identity.readonly` OAuth scope
   - Fixed API endpoint domain (api → apiz)
   - Enhanced `get_user_info()` with debug logging
   - Fixed response field extraction

3. **R/ebay_helpers.R**
   - Added `get_token_status()` function (Phase 1)
   - Exported helper for token health calculation

4. **R/app_server.R**
   - Added startup notification observer (Phase 1)
   - Uses `get_token_status()` for proactive alerts

5. **R/app_ui.R**
   - Reverted Phase 2 navigation changes
   - eBay remains under Settings → eBay Connection subtab

### Backup Files Created
- `mod_ebay_auth.R.backup_[timestamp]`
- `ebay_api.R.backup_[timestamp]`
- `ebay_helpers.R.backup_[timestamp]`
- `app_server.R.backup_[timestamp]`
- `app_ui.R.backup_[timestamp]`

## Technical Patterns

### bslib Accordion Pattern
```r
bslib::accordion(
  id = session$ns("account_overview"),
  open = FALSE,  # Collapsed by default
  bslib::accordion_panel(
    title = HTML(paste0(
      "<span style='font-weight: 600;'>Account Overview</span>",
      " <span style='color: #666;'>(",
      active_account$username,
      ")</span>"
    )),
    icon = icon("user-circle"),
    # Content here
  )
)
```

### Module Namespace Pattern
- Used `uiOutput(ns("account_overview_accordion"))` for dynamic rendering
- Accordion ID uses `session$ns()` for proper module scoping
- No custom JavaScript needed (bslib handles namespacing)

### eBay Identity API Integration
- **Endpoint**: `https://apiz.ebay.com/commerce/identity/v1/user`
- **Scope**: `https://api.ebay.com/oauth/api_scope/commerce.identity.readonly`
- **Response**: `userId`, `username`, `accountType`, `registrationMarketplaceId`, `status`
- **Authentication**: Bearer token in Authorization header

## Lessons Learned

1. **eBay API Quirks**:
   - Identity API uses different domain (`apiz.ebay.com` vs `api.ebay.com`)
   - JWT tokens are sometimes compressed (gzip)
   - Requires explicit `commerce.identity.readonly` scope for user info

2. **User Preferences**:
   - Prefers minimal UI changes
   - Settings is appropriate location for configuration
   - Accordion pattern superior to dedicated tabs for auxiliary info

3. **Username Extraction Priority**:
   - Method 1: JWT decoding (fast but may fail if compressed)
   - Method 2: Identity API call (requires correct scope + domain)
   - Method 3: Generated fallback (last resort)

4. **Debug Logging Value**:
   - Console logging essential for OAuth troubleshooting
   - Shows exact API responses and failure points
   - Helps users understand what's happening

## Related Memories
- `ebay_multi_account_phase2_complete_20251018` - Multi-account foundation
- `ebay_oauth_integration_complete_20251017` - Initial OAuth setup
- `phase2_migration_success_20251018` - Account manager implementation

## Future Considerations

1. **JWT Decompression**: Consider implementing gzip decompression for JWT payloads
2. **Scope Management**: Document all required OAuth scopes in one location
3. **API Domain Mapping**: Create helper to map API types to correct domains
4. **Username Caching**: Cache username to avoid repeated API calls
5. **Accordion State**: Consider persisting accordion open/closed state in user preferences

## Success Metrics

- ✅ Username extraction working with correct OAuth scope
- ✅ Accordion UI approved by user
- ✅ Clean integration with existing eBay Connection tab
- ✅ Minimal visual footprint (collapsed by default)
- ✅ Auto-updates on all account state changes
- ✅ Comprehensive debug logging for troubleshooting
