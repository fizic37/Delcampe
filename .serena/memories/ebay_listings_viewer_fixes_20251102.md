# eBay Listings Viewer - Fixes and Issues (2025-11-02)

## Summary
Attempted to fix eBay Listings Viewer issues including category assignment, SKU prefixes, and sync functionality. Multiple critical bugs discovered and partially fixed.

## User's Critical Issues

### Issue #1: Stamps Listed in Wrong eBay Category ✅ FIXED
**Problem**: Stamps were being exported to eBay category 262042 (Topographical Postcards) instead of category 260 (Stamps)

**Root Cause**: `build_trading_item_data()` in `R/ebay_helpers.R` line 305 had hardcoded `category_id = 262042`

**Fix Applied**:
1. Added `category_id` parameter to `build_trading_item_data()` (line 289)
2. Added `is_stamp` and `sku_prefix` parameters to `create_ebay_listing_from_card()` (lines 23-24, 32)
3. Updated `R/ebay_integration.R` to detect stamp vs postcard and set category accordingly (lines 120-126)
4. Updated `R/mod_stamp_export.R` to pass `is_stamp=TRUE` and `sku_prefix="STAMP"` (lines 1916-1917)

**Files Modified**:
- `R/ebay_helpers.R` - Added category_id parameter
- `R/ebay_integration.R` - Added stamp detection logic
- `R/mod_stamp_export.R` - Pass stamp flags on export

### Issue #2: eBay Listings Viewer Should Fetch from API ⚠️ PARTIALLY FIXED
**Problem**: Viewer only showed listings that exist in local database, not all eBay listings

**Root Cause**: `update_listings_cache()` only UPDATE'd existing records, didn't INSERT new ones from eBay

**Fix Applied**:
Modified `update_listings_cache()` in `R/ebay_sync_helpers.R` (lines 175-247) to:
- Check if listing exists in database
- UPDATE if exists
- INSERT with SKU `EBAY-{ItemID}` if new from eBay
- Should now show ALL eBay listings regardless of how they were created

### Issue #3: Refresh Error "missing value where TRUE/FALSE needed" ⚠️ PARTIALLY FIXED
**Problem**: Clicking "Refresh from eBay" button caused error

**Root Causes Found**:
1. Line 87 in `parse_seller_list_response()`: `has_more` comparison failed if node missing
2. Line 44: `ack` comparison failed if node missing/NA
3. Various NULL/NA handling issues in XML parsing

**Fixes Applied**:
1. Added safe node extraction with length checks for `HasMoreItems` (lines 87-92)
2. Added safe node extraction for `Ack` (lines 44-56)
3. Added comprehensive NULL/NA handling in `update_listings_cache()` (lines 177-190)
4. Added tryCatch blocks for database queries (lines 205-211)
5. Added detailed error logging to show actual eBay API errors (lines 60-89)

**Current Status**: 
- Error changed from generic to "GetSellerList failed: Unknown error"
- eBay Trading API call is failing, need to see actual error code/message from console
- Added debug logging but user reported "of no good"

## Additional Issues Discovered

### SKU Prefix for Stamps
**Problem**: Stamps getting SKU with "PC-" prefix instead of "STAMP-"

**Fix Applied**: 
- Modified `generate_sku()` call to use `prefix` parameter (line 121 in ebay_integration.R)
- Stamp exports now use `sku_prefix = "STAMP"`

### Placeholder card_id in Stamp Export
**Problem**: Line 1904 in `mod_stamp_export.R` used `paste0("CARD_", i, "_", timestamp)`

**Fix Applied**: Changed to `paste0("STAMP_", i, "_", timestamp)` for differentiation

**Outstanding Issue**: Still using placeholder instead of real stamp_id from database

## Database Investigation Results

From diagnostics run by user:

### Stamps Table
- 3 stamps exist: stamp_ids 4, 6, 7 (face, verso, combined)
- Created around 2025-11-01 14:28-14:29

### eBay Listings Table  
- 6 total listings exist
- 0 stamp listings (no listings with SKU starting with ST- or STAMP-)
- 0 auction listings
- 0 scheduled listings

### Conclusion
The scheduled stamp auction was **never successfully exported to eBay**. The stamp exists in stamps table but no corresponding eBay listing was created.

## Files Modified

1. **R/ebay_helpers.R**
   - Added `category_id` parameter to `build_trading_item_data()` (default: 262042)
   - Lines changed: 277-312

2. **R/ebay_integration.R**
   - Added `is_stamp` and `sku_prefix` parameters to `create_ebay_listing_from_card()`
   - Added category detection logic: 260 for stamps, 262042 for postcards
   - Added SKU generation with correct prefix
   - Lines changed: 19-32, 116-135

3. **R/mod_stamp_export.R**
   - Changed card_id placeholder from "CARD_" to "STAMP_"
   - Added `is_stamp = TRUE` parameter
   - Added `sku_prefix = "STAMP"` parameter
   - Lines changed: 1904, 1916-1917

4. **R/ebay_sync_helpers.R**
   - Enhanced XML parsing with comprehensive error handling
   - Added detailed error logging for eBay API failures
   - Modified `update_listings_cache()` to INSERT new listings from eBay
   - Added NULL/NA safety checks throughout
   - Lines changed: 40-94, 175-247

5. **R/mod_ebay_listings.R**
   - Added debug console output for sync operations
   - Shows item counts and first item details
   - Lines changed: 141-162

6. **R/ebay_sync_helpers.R** (earlier fixes)
   - Added "cancelled" status badge (line 282)
   - Updated `render_status_badge()` test expectations

7. **R/mod_ebay_listings.R** (earlier fixes)
   - Added "Cancelled" to status filter dropdown (line 33)
   - Made header more compact (reduced padding, font sizes)

8. **R/app_ui.R** (earlier fixes)
   - Moved eBay Listings to first menu position (lines 21-26)
   - Removed duplicate panel entry (previously at lines 144-147)

## Outstanding Issues

### Critical - eBay API Call Failing
**Status**: UNRESOLVED
- GetSellerList Trading API call returns error
- Error message shows "Unknown error" 
- Need to see actual eBay error code and message from console
- Possible causes:
  - Token expired
  - Invalid date range
  - Missing API permissions
  - Incorrect API credentials
  - Rate limiting

### Database Schema Issues
**Status**: NOT ADDRESSED
1. No `stamp_id` column in `ebay_listings` table
2. `card_id` column has foreign key constraint to `postal_cards` only
3. Cannot properly link stamp listings to stamps table
4. Need migration to add `stamp_id` column

### Stamp Aspects
**Status**: NOT ADDRESSED
- Currently using `extract_postcard_aspects()` for stamps
- Need stamp-specific aspects function
- Should extract stamp metadata (year, country, denomination, etc.)

## Next Steps (If Continuing)

1. **Debug eBay API Failure**
   - Run app with console visible
   - Click "Refresh from eBay"
   - Look for error output showing:
     - Error Code
     - Short Message
     - Long Message
   - Check if token is valid/expired
   - Verify eBay account has Trading API access

2. **Database Schema**
   - Add `stamp_id` column to `ebay_listings`
   - Update foreign key constraints
   - Migrate existing data

3. **Stamp Export**
   - Fix to use real `stamp_id` instead of placeholder
   - Implement stamp-specific aspects extraction
   - Test full export flow with auction and scheduling

4. **Testing**
   - Test stamp export with category 260
   - Verify SKU prefix is STAMP-
   - Verify auction settings work
   - Verify scheduling works
   - Test eBay sync with valid credentials

## Key Insights

1. **Category hardcoding was a fundamental bug** - all stamps went to wrong category
2. **Sync only updated, didn't insert** - viewer couldn't show external eBay listings
3. **XML parsing had no NULL safety** - caused mysterious TRUE/FALSE errors
4. **User correctly identified** that database state doesn't matter - eBay API should be source of truth
5. **Stamp export may have never worked** - no evidence of successful exports in database

## Lessons Learned

1. Always check for NULL/NA in XML parsing before comparisons
2. INSERT or UPDATE pattern needed for API sync, not just UPDATE
3. Hardcoded values (like category_id) should be parameters
4. Database schema needs to support both postcards AND stamps properly
5. Better error logging helps debug API issues faster
6. Listen to user feedback - they often spot the real issue quickly
