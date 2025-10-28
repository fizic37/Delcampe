# PRP: Fix eBay Error 25019 with Automated Testing

## Context
**CRITICAL: Read these serena memories FIRST before starting:**
- `.serena/memories/ebay_error_25019_investigation_20251027.md` - Complete investigation findings
- `.serena/memories/ebay_oauth_integration_complete_20251017.md` - OAuth implementation
- `.serena/memories/testing_infrastructure_complete_20251023.md` - Testing framework

## Problem Statement
Creating eBay listings fails with Error 25019 (Overseas Warehouse Block). User successfully creates listings via eBay website, but API fails. OAuth token is confirmed working.

**Root Cause:** Location country mismatch - API uses US location but account is registered in Romania (RO).

## Requirements

### 1. Create Automated Test Suite (NOT Manual UI Testing)
Create `dev/test_ebay_location_fix.R` that:
- Loads the package without UI (no Shiny required)
- Tests API access directly using existing eBay account
- Does NOT require user to click buttons or test manually
- Outputs clear diagnostic information to console
- Can be run with `Rscript dev/test_ebay_location_fix.R`

### 2. Investigate User's Existing Listings
Create automated script to:
- Fetch user's existing eBay listings via API (if any exist)
- Inspect what location those listings use
- Determine if user has other locations we're not detecting
- Output: What location structure works for this user's account

### 3. Try Multiple Location Fix Approaches

#### Approach A: Update Existing Location
- Use PATCH/PUT to update `default_location` country to RO
- Test with minimal data first, then add fields if needed
- Document exact API request/response

#### Approach B: Research Location Requirements
- GET /sell/inventory/v1/location to see existing location structure
- Compare required vs optional fields
- Try creating RO location with exact same structure as existing US location
- Test different address formats (with/without addressLine2, stateOrProvince, etc.)

#### Approach C: Use Business Policies Location
- Investigate if fulfillment policy has location settings
- Check if location can be specified at offer level instead of inventory level
- Try omitting location from inventory, only specify in offer

#### Approach D: Fetch eBay's Location Requirements
- Call eBay metadata API to get location requirements for Romania
- Determine if specific fields are required for RO that we're missing
- Implement based on actual API requirements, not assumptions

### 4. Implement Working Solution
Once a working approach is found:
- Update R/ebay_integration.R location detection logic
- Add proper error handling and fallbacks
- Update .Renviron if manual location key is needed
- Add comments explaining the solution

### 5. Create Integration Test
Create `tests/testthat/test-ebay_location_romania.R`:
- Mock the eBay API responses
- Test location detection prefers RO over US
- Test location creation with correct RO data
- Test listing creation with RO location succeeds
- Add to critical test suite

## Constraints
- DO NOT ask user to test manually in UI
- DO NOT create test files that require Shiny app running
- All tests must be runnable via `Rscript dev/test_*.R`
- Must work with existing OAuth token (already validated as working)
- Do NOT modify OAuth or authentication code (confirmed working)
- Must use existing EbayAPI and EbayAccountManager classes

## Success Criteria
- `Rscript dev/test_ebay_location_fix.R` successfully creates a test listing
- Listing uses Romania location
- No Error 25019
- Solution is automated (no manual Seller Hub steps)
- Integration tests pass

## Testing Approach
1. Create test script that initializes API programmatically (no UI)
2. Test each approach A-D sequentially with clear output
3. Log all API requests/responses for debugging
4. When solution found, implement in main code
5. Verify with automated test, not manual UI testing

## Files to Modify
- NEW: `dev/test_ebay_location_fix.R` - Main automated test script
- R/ebay_integration.R - Update location detection/creation logic
- NEW: `tests/testthat/test-ebay_location_romania.R` - Integration test
- .Renviron - Only if manual override is the final solution

## Implementation Notes
- User is a developer, not an eBay seller - cannot access Seller Hub UI
- Solution MUST be API-based, not manual configuration
- Focus on programmatic testing, not user interaction
- Read the investigation memory to avoid repeating failed approaches
