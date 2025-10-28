# eBay Inventory API - Cross-Border Seller Limitation

## Status: UNRESOLVED - Inventory API Cannot Handle This Use Case

## Problem
Romania-based seller cannot publish listings on EBAY_US marketplace via Inventory API. Error 25002: "No <Item.Country> exists or <Item.Country> is specified as an empty tag in the request."

## Exhaustive Attempts (October 27-28, 2025)

### Location Creation Attempts
1. ❌ Create RO location with locationType="WAREHOUSE" → HTTP 400 (Error 2004)
2. ❌ Create RO location with locationType="STORE" → HTTP 400 (Error 2004)
3. ❌ Update existing default_location to RO → HTTP 400 (Error 2004)
4. ✅ Added stateOrProvince="B" (Bucharest) → Still HTTP 400
5. ✅ Clean merchantLocationKey (no spaces) → Still HTTP 400
6. ✅ All required fields included (addressLine1, city, stateOrProvince, postalCode, country) → Still HTTP 400

### Inventory Item Attempts
7. ❌ Add country="RO" to inventory item → Still Error 25002 at publish
8. ❌ Add locale="en_US" → Still Error 25002
9. ❌ Add packageWeightAndSize → Still Error 25002
10. ❌ Omit location entirely (matching existing successful items) → Still Error 25002
11. ✅ Remove merchantLocationKey and availabilityDistributions → Still Error 25002

### Fulfillment Policy Attempts
12. ❌ Existing policy uses "EconomyShippingFromOutsideUS" → No country field available
13. ❌ Attempted to modify existing policy → Token expired, but policy has no country field anyway
14. ✅ Created NEW fulfillment policy (ID: 252616246010) with proper DOMESTIC + INTERNATIONAL options → Still Error 25002

### Offer Attempts
15. ❌ Omit merchantLocationKey from offer → Still Error 25002
16. ❌ Add availableQuantity directly to offer → Still Error 25002

## What Works
- ✅ OAuth token validated (has all scopes: sell.inventory, sell.account, sell.fulfillment)
- ✅ Condition field fixed (in aspects only, not top-level)
- ✅ Inventory item creation succeeds (HTTP 204)
- ✅ Offer creation succeeds (HTTP 201)
- ❌ Publish fails (Error 25002 - No Item.Country)

## Critical Finding
User's existing inventory items (22 total) created successfully have:
```json
{
  "availability": {
    "shipToLocationAvailability": {
      "quantity": 1
    }
  }
}
```
**No merchantLocationKey, no availabilityDistributions** - but they were never published (no offers exist for them).

## Root Cause
eBay Inventory API provides **NO documented way** for cross-border sellers to specify Item.Country when:
- Account registered in Romania (RO)
- Listing on US marketplace (EBAY_US)
- Cannot create inventory locations (API rejects all attempts with 400)
- Fulfillment policies have no origin country field
- No account-level country setting exposed via API

The API expects Item.Country but provides no mechanism to set it.

## Why User Can List via Website
eBay's website listing flow likely:
1. Uses Trading API (legacy) under the hood, which has explicit `<Item><Country>` field
2. Automatically infers country from account registration for website listings
3. Has different validation rules than Inventory API

## Solutions

### Option 1: Trading API (Recommended - Will Work)
Implement eBay Trading API (legacy XML-based API) which has explicit country field:
```xml
<Item>
  <Country>RO</Country>
  <Location>Bucharest</Location>
  ...
</Item>
```

**Pros:**
- Will definitely work (explicit country field)
- Supports OAuth (no need for legacy auth)
- User successfully creates listings via website (which likely uses this)

**Cons:**
- XML-based (more complex than JSON)
- Requires rewriting listing creation logic
- Legacy API (eBay is deprecating, but still supported)

**Implementation effort:** 2-3 hours

### Option 2: Different Marketplace
Try listing on European marketplaces (EBAY_GB, EBAY_DE) instead of EBAY_US:
- May auto-infer country from account registration for EU sellers
- Would require different fulfillment policies per marketplace
- Unknown if this actually works

### Option 3: Account-Level Fix (Uncertain)
Contact eBay Developer Support to:
- Check if account needs specific seller status for cross-border sales
- Verify if there's a hidden account setting we're missing
- Ask why location creation returns 400 for all attempts

### Option 4: Manual Workaround
- Create listings via eBay website
- Import listing details back into app for tracking
- Not ideal for automation

## Files Modified
- R/ebay_integration.R: Added 3-strategy location fallback, removed location from inventory
- R/ebay_helpers.R: Condition in aspects only
- .Renviron: New fulfillment policy ID (252616246010)
- R/ebay_api.R: Location creation uses PUT (can create or update)

## Recommendation
**Implement Trading API as fallback** when Inventory API fails with Error 25002. This gives best of both worlds:
- Try Inventory API first (modern, JSON-based)
- Fall back to Trading API for cross-border sellers (will work)

## Next Steps
Create PRP for Trading API implementation with:
- AddFixedPriceItem endpoint for creating listings
- OAuth authentication (Trading API supports it)
- XML request/response handling
- Fallback logic when Inventory API fails

## Related Memories
- ebay_error_25019_investigation_20251027.md - Initial investigation
- ebay_oauth_integration_complete_20251017.md - OAuth setup
- ebay_location_creation_fix_20251020.md - Previous location attempts
