# eBay Error 25019 Investigation - October 27, 2025

## Problem Statement
Creating eBay listings from the Delcampe app fails with Error 25019 (Overseas Warehouse Block Policy). User can successfully create listings via eBay website with same account/settings.

## Key Findings

### OAuth Token Status ✅
- Token is VALID and has ALL required scopes
- Token length: 2480 characters
- Verified with direct curl test: `curl -H "Authorization: Bearer TOKEN" https://api.ebay.com/sell/inventory/v1/location` returned HTTP 200
- Scopes confirmed: sell.inventory, sell.account, sell.fulfillment
- **OAuth is NOT the problem**

### Condition Field ✅ SOLVED
- Category 262042 (Topographical Postcards) requires condition in aspects array, NOT as top-level field
- Fixed in R/ebay_helpers.R extract_postcard_aspects() - adds condition to aspects
- Fixed in R/ebay_integration.R - removed top-level condition field from inventory_data
- Successfully creating inventory items (HTTP 204) and offers (HTTP 201)

### Location Country Mismatch ❌ UNRESOLVED
- Current location: `default_location` with country=US, postal code=10001
- User's eBay account registration: Romania (RO)
- Error 25019 occurs because location country (US) doesn't match account registration (RO)

### Failed Approaches
1. **Auto-create RO location** - API returns HTTP 400 Bad Request
   ```json
   {
     "name": "Romania Warehouse",
     "location": {"address": {"addressLine1": "Str. Turda 1", "city": "Bucharest", "postalCode": "011321", "country": "RO"}},
     "locationType": "WAREHOUSE",
     "merchantLocationStatus": "ENABLED"
   }
   ```
   Error: "Invalid request" - likely missing required fields or incorrect format

2. **Manual override in .Renviron** - Commented out, doesn't solve underlying issue

## File Locations
- OAuth code: R/ebay_api.R lines 81-101 (generate_auth_url with scopes)
- Condition mapping: R/ebay_helpers.R lines 8-40 (map_condition_to_ebay)
- Aspects extraction: R/ebay_helpers.R lines 54-90 (extract_postcard_aspects)
- Listing creation: R/ebay_integration.R lines 66-231 (location detection and creation)
- Location auto-create: R/ebay_integration.R lines 100-144

## Critical Insight
User successfully creates listings on eBay website but NOT via API. This suggests:
- Account configuration is correct
- eBay website uses different location or has different validation
- API location detection/creation is failing
- Need to investigate what location eBay website uses for user's successful listings

## Next Steps
1. Create automated test script (NOT manual UI testing) to:
   - Fetch user's existing listings from eBay API
   - Inspect what location those listings use
   - Determine correct location structure for RO
2. Try updating default_location country instead of creating new location
3. Research eBay Inventory API location requirements for non-US countries
4. Consider using Business Policies location instead of inventory location

## Environment
- Active account: ebay_user_d8833956 (production)
- Username: eBay_production_d8833956
- Token expires: 2025-10-27 19:38:44
- Business policies: Fulfillment=231172857010, Payment=206693427010, Return=208331180010
