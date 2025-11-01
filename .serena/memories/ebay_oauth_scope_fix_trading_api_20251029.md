# eBay OAuth Scope Fix for Trading API

**Date**: 2025-10-29  
**Status**: ✅ Fixed - Requires User Re-authentication  
**Priority**: CRITICAL - Blocks all eBay sending functionality

## Problem Discovered

### Symptom
Error when creating eBay listings via Trading API:
```
Error 21916984: IAF token supplied is invalid
```

### Root Cause
**OAuth token scope mismatch**

When we migrated from Inventory API to Trading API (Oct 28, 2025), we updated the code but **forgot to update the OAuth scopes**. Existing user tokens were created with Inventory API scopes only, which don't grant access to Trading API endpoints.

### Diagnostic Evidence

1. **GetUser API call** (simple Trading API call): ✅ **WORKS**
2. **AddFixedPriceItem** (listing creation): ❌ **FAILS** with "invalid token"

This proves:
- Token itself is valid (not expired, not corrupted)
- Token has basic API access
- Token lacks specific Trading API scopes for listing creation

### Why It Happened
Timeline:
1. **Oct 28, 2025**: Switched from Inventory API to Trading API for cross-border listing support
2. Updated code to use Trading API endpoints
3. **Forgot to update OAuth scopes** in `generate_auth_url()`
4. Existing user tokens created before Oct 28 don't have Trading API permissions

## OAuth Scopes Explained

### Before Fix (Inventory API only)
```r
scope <- paste(
  "https://api.ebay.com/oauth/api_scope/sell.inventory",
  "https://api.ebay.com/oauth/api_scope/sell.account",
  "https://api.ebay.com/oauth/api_scope/sell.fulfillment",
  sep = " "
)
```

**Grants access to:**
- ✅ Inventory API (create inventory items, offers)
- ✅ Account info (GetUser, registration address)
- ✅ Order fulfillment
- ❌ Trading API listing creation (AddFixedPriceItem, etc.)

### After Fix (Trading API + Inventory API)
```r
scope <- paste(
  "https://api.ebay.com/oauth/api_scope",  # ← ADDED: General API (Trading API)
  "https://api.ebay.com/oauth/api_scope/sell.inventory",
  "https://api.ebay.com/oauth/api_scope/sell.account",
  "https://api.ebay.com/oauth/api_scope/sell.fulfillment",
  sep = " "
)
```

**Grants access to:**
- ✅ **Trading API** (AddFixedPriceItem, ReviseItem, etc.)
- ✅ Inventory API (backward compatibility)
- ✅ Account info
- ✅ Order fulfillment

## Solution Implementation

### Code Changes

**File**: `R/ebay_api.R` (lines 81-92)

**Before**:
```r
generate_auth_url = function(scope = NULL) {
  # Default scopes for postcard selling
  if (is.null(scope)) {
    scope <- paste(
      "https://api.ebay.com/oauth/api_scope/sell.inventory",
      "https://api.ebay.com/oauth/api_scope/sell.account",
      "https://api.ebay.com/oauth/api_scope/sell.fulfillment",
      sep = " "
    )
  }
```

**After**:
```r
generate_auth_url = function(scope = NULL) {
  # Default scopes for postcard selling via Trading API
  # NOTE: Trading API requires different scopes than Inventory API
  if (is.null(scope)) {
    scope <- paste(
      "https://api.ebay.com/oauth/api_scope",  # General API access (Trading API)
      "https://api.ebay.com/oauth/api_scope/sell.inventory",  # Inventory API (backup)
      "https://api.ebay.com/oauth/api_scope/sell.account",  # Account info
      "https://api.ebay.com/oauth/api_scope/sell.fulfillment",  # Order fulfillment
      sep = " "
    )
  }
```

**Impact**: All new OAuth tokens will include Trading API access

### User Action Required

**Existing users MUST re-authenticate** to get a token with new scopes:

1. Launch app: `run_app()`
2. Go to "eBay Auth" tab
3. Remove existing account (button in UI)
4. Click "Connect New Account"
5. Complete OAuth flow in browser
6. New token will have all required scopes

**Helper Script**: `dev/reauth_for_trading_api.R` - Explains issue and steps

## Testing

### Diagnostic Scripts Created

1. **`dev/test_ebay_sending_flow.R`**
   - End-to-end test of listing creation
   - Simulates "Send to eBay" button
   - Used to discover scope issue

2. **`dev/diagnose_ebay_token.R`**
   - Checks token validity and expiry
   - Attempts token refresh
   - Tests with simple GetUser API call
   - Revealed that GetUser works but AddFixedPriceItem doesn't

3. **`dev/fix_account_timestamps.R`**
   - Sets token expiry timestamps
   - Fixed separate token_expiry issue

4. **`dev/reauth_for_trading_api.R`**
   - Explains scope issue to user
   - Provides clear re-auth steps

### Verification Steps

After user re-authenticates:

```r
# 1. Verify new scopes
account_manager <- EbayAccountManager$new()
account <- account_manager$get_active_account()
# Check that token was created after fix (after Oct 29, 2025 09:00)

# 2. Test sending
source("dev/test_ebay_sending_flow.R")
# Should succeed and create listing

# 3. Configure Imgur (optional but recommended)
# See IMGUR_SETUP_INSTRUCTIONS.md
```

## Related Issues Fixed

### Issue 1: Missing Token Expiry Timestamps
**Problem**: `token_expiry` field was empty  
**Symptom**: Unnecessary refresh attempts  
**Fix**: `dev/fix_account_timestamps.R` sets proper expiry  
**Status**: ✅ Fixed

### Issue 2: Image Upload Failure
**Problem**: eBay Picture Services auth issues  
**Solution**: Imgur integration (primary), EPS fallback  
**Status**: ✅ Implemented, awaiting Imgur setup

## Files Modified

1. **`R/ebay_api.R`** - Updated OAuth scopes
2. **Backup**: `Delcampe_BACKUP/ebay_api_BEFORE_SCOPE_FIX_20251029.R`

## Files Created

1. **`dev/test_ebay_sending_flow.R`** - E2E sending test
2. **`dev/diagnose_ebay_token.R`** - Token diagnostics
3. **`dev/fix_account_timestamps.R`** - Timestamp fix
4. **`dev/reauth_for_trading_api.R`** - Re-auth instructions

## Documentation

**User-facing**: `dev/reauth_for_trading_api.R` contains clear explanation  
**Technical**: This memory file

## Lessons Learned

1. **When changing APIs, audit OAuth scopes** - Don't just update code
2. **Scopes are API-specific** - Trading API ≠ Inventory API
3. **Test with real accounts** - Sandbox might have different scope requirements
4. **Document scope requirements** - Add to memory files when implementing new APIs
5. **Diagnostic scripts are invaluable** - GetUser test isolated the scope issue

## Impact

### Before Re-auth
- ❌ "Send to eBay" button doesn't work
- ❌ All listing creation fails with "invalid token"
- ✅ Token itself is valid (GetUser works)

### After Re-auth
- ✅ "Send to eBay" button works
- ✅ Listings created successfully
- ✅ Full Trading API access
- ⏳ Imgur setup needed for instant thumbnails (separate issue)

## Next Steps

1. **User**: Re-authenticate via eBay Auth tab (5 minutes)
2. **User**: Test sending: `source("dev/test_ebay_sending_flow.R")`
3. **User**: Set up Imgur (5 minutes) - See `IMGUR_SETUP_INSTRUCTIONS.md`
4. **Optional**: Clean up diagnostic scripts after verification

## Related Memories

- `ebay_trading_api_implementation_complete_20251028.md` - Original Trading API migration
- `ebay_inventory_api_limitation_20251028.md` - Why we switched to Trading API
- `ebay_sending_fix_and_imgur_integration_20251029.md` - Complete fix summary

## Key Takeaway

**OAuth scopes are not just configuration - they're code dependencies.** When you change which APIs your code calls, you MUST update the scopes requested during OAuth. Existing tokens won't magically gain new permissions; users must re-authenticate.
