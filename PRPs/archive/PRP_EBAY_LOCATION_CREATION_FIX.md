# PRP: Fix eBay Inventory Location Creation (Error 2004)

## Problem Statement

eBay's Inventory Location API consistently returns HTTP 400 "Invalid request" (error 2004) when attempting to create/update inventory locations in production environment. This blocks the entire listing creation flow.

## Current Error

```
DEBUG - Location Request:
   URL: https://api.ebay.com/sell/inventory/v1/location/location_011321
   Method: PUT
   Body: {"location":{"address":{"addressLine1":"Turda 1","city":"Bucharest","postalCode":"011321","country":"RO"}},"name":"Primary Location","locationTypes":["WAREHOUSE"]}
DEBUG - Location Error Response:
   Status: 400 Bad Request
   Raw body: {"errors":[{"errorId":2004,"domain":"ACCESS","category":"REQUEST","message":"Invalid request","longMessage":"The request has errors. For help, see the documentation for this API."}]}
```

## What We've Tried

1. ✅ Fixed HTTP method from POST to PUT (per eBay docs)
2. ✅ Removed read-only field `merchantLocationStatus`
3. ✅ Added all required address fields (addressLine1, city, postalCode, country)
4. ✅ Tried different location keys (default_location, location_011321)
5. ✅ Matched address exactly to eBay account registration
6. ✅ Added comprehensive error logging
7. ❌ Still getting generic error 2004 with no specific details

## Acceptance Criteria

1. eBay location creation succeeds with HTTP 200/201/204
2. Can create inventory items using the location key
3. Full listing flow works end-to-end
4. Solution works for any eBay account (no hardcoding)

## Implementation Tasks

### Phase 1: Diagnostics (1-2 hours)

1. **Run diagnostic script** (`diagnose_location.R`)
   - Test GET locations (confirms OAuth works)
   - Try minimal payload
   - Test in sandbox environment
   - Compare sandbox vs production behavior

2. **Verify eBay Account Setup**
   - [ ] Check production app has Inventory API access
   - [ ] Verify seller registration is complete
   - [ ] Confirm payment/bank details verified
   - [ ] Check for pending account verification

3. **Test Manual Location Creation**
   - [ ] Log into eBay Seller Hub
   - [ ] Try creating location manually through UI
   - [ ] Document results (success/failure)

### Phase 2: Solution Implementation (depends on findings)

Based on diagnostic results, implement appropriate fix:

1. **Fix API Request Format**
   - Adjust payload based on sandbox testing results
   - Try alternative field formats
   - Add optional fields that may be required

2. **Account Setup Resolution**
   - Complete any pending verifications
   - Apply for necessary API access
   - Re-authenticate with correct scopes

3. **Implement Workaround (if needed)**
   - Skip location creation temporarily
   - Use existing locations if available
   - Provide manual setup instructions

### Phase 3: Robust Solution

1. **Pre-flight Account Check**
   - Detect if account is approved for Inventory API
   - Provide clear error messages to user
   - Guide user through account setup process

2. **Graceful Degradation**
   - Fall back to Trading API if Inventory API unavailable
   - Or provide manual listing creation option
   - Don't block entire flow on location issue

3. **Better Error Handling**
   - Map error 2004 to actionable user messages
   - Provide links to eBay setup pages
   - Guide user through troubleshooting

## Files Affected

- `R/ebay_api.R` - Location API methods
- `R/ebay_integration.R` - Location setup in listing flow
- `.Renviron` - Location configuration
- `diagnose_location.R` - Diagnostic script (NEW)

## Current Configuration

```bash
EBAY_LOCATION_COUNTRY=RO
EBAY_LOCATION_POSTAL=011321
EBAY_LOCATION_CITY=Bucharest
EBAY_LOCATION_ADDRESS_LINE1=Turda 1
EBAY_LOCATION_STATE_OR_PROVINCE=
EBAY_ENVIRONMENT=production
```

## Testing Steps

1. Run diagnostic: `source("diagnose_location.R")`
2. Check eBay Developer account status
3. Verify seller registration complete
4. Try manual location creation in Seller Hub
5. Re-authenticate if needed
6. Test with fresh credentials
7. Contact eBay support if all else fails

## Success Metrics

- ✅ Location creation succeeds
- ✅ Full listing created on eBay
- ✅ Works in both sandbox and production
- ✅ Clear error messages guide users

## Workaround Options (if needed)

```r
# Option 1: Use existing location
# Get locations, use first available
# Fall back to hardcoded if none exist

# Option 2: Skip location validation
# Allow listing creation without location
# Handle location requirement at offer level

# Option 3: Manual location setup
# Provide instructions for user to create location in UI
# Detect and use existing locations
```

## Timeline Estimate

- Diagnostics: 1-2 hours
- Account verification: 1-5 days (if needed)
- Implementation: 2-4 hours
- Testing: 1 hour

## Priority: HIGH

This blocks all eBay listing creation functionality.
