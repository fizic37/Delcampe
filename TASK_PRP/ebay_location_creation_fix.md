# TASK PRP: Fix eBay Inventory Location Creation (Error 2004)

**Generated**: 2025-10-20
**Source PRP**: PRPs/PRP_EBAY_LOCATION_CREATION_FIX.md
**Priority**: HIGH (blocks all eBay listing creation)
**Estimated Time**: 4-8 hours (depends on diagnostic findings)

---

## Context

### Problem Summary
eBay's Inventory Location API consistently returns HTTP 400 "Invalid request" (error 2004) when attempting to create/update inventory locations in production. The error message provides no specific details about what's wrong with the request.

### Current Implementation
- **Location Creation**: R/ebay_api.R:420-502 (`EbayInventoryAPI$create_location`)
- **Location Setup**: R/ebay_integration.R:66-152 (during listing creation)
- **Configuration**: .Renviron environment variables
- **Diagnostic Script**: diagnose_location.R (ready to use)
- **Check Script**: check_ebay_location.R (can list/delete existing locations)

### What We've Already Tried ✅
1. Fixed HTTP method from POST to PUT (per eBay docs)
2. Removed read-only field `merchantLocationStatus`
3. Added all required address fields (addressLine1, city, postalCode, country)
4. Tried different location keys (default_location, location_011321)
5. Matched address exactly to eBay account registration
6. Added comprehensive error logging

### Current Configuration (.Renviron)
```bash
EBAY_LOCATION_COUNTRY=RO
EBAY_LOCATION_POSTAL=011321
EBAY_LOCATION_CITY=Bucharest
EBAY_LOCATION_ADDRESS_LINE1=Turda 1
EBAY_LOCATION_STATE_OR_PROVINCE=
EBAY_ENVIRONMENT=production
```

### Documentation Resources

#### eBay API Documentation
- **URL**: https://developer.ebay.com/api-docs/sell/inventory/resources/location/methods/createInventoryLocation
- **Focus**:
  - Required vs optional fields for Romania (RO)
  - Field validation rules
  - Merchant location status requirements
  - Special considerations for non-US accounts

#### Account Setup Requirements
- **URL**: https://developer.ebay.com/my/keys
- **Check**: Production app has Inventory API access enabled
- **URL**: https://www.ebay.com/sh/ovw (Seller Hub)
- **Check**: Seller registration completed with verified payment/bank details
- **URL**: https://www.ebay.com/sh/set (Settings)
- **Check**: Registration address matches location API address exactly

### Existing Patterns to Follow

**Diagnostic Pattern** (from diagnose_location.R:12-34):
```r
# Test 1: Check permissions with GET request
loc_result <- ebay_api$inventory$get_locations()
if (loc_result$success) {
  cat("✅ GET locations successful - OAuth permissions are OK\n")
  # List existing locations
} else {
  cat("❌ GET locations failed - OAuth scope/permissions issue\n")
}
```

**Error Extraction Pattern** (from R/ebay_api.R:454-484):
```r
req_error(function(resp) {
  status <- resp_status(resp)
  body <- tryCatch(resp_body_json(resp), error = function(e) NULL)
  if (!is.null(body) && !is.null(body$errors)) {
    # Extract eBay error details
    errors <- sapply(body$errors, function(err) {
      cat("      Error ID:", err$errorId, "\n")
      cat("      Message:", err$message, "\n")
      if (!is.null(err$parameters)) {
        cat("      Parameters:\n")
        for (param in err$parameters) {
          cat("         -", param$name, "=", param$value, "\n")
        }
      }
    })
  }
})
```

### Known Gotchas

1. **Error 2004 "Invalid request"** - Generic error that can mean:
   - Account not approved for Inventory API in production
   - Missing seller registration or verification
   - Address validation failure (must match eBay registration exactly)
   - Missing required fields for specific country
   - Field format issues (spacing, special characters)

2. **Sandbox vs Production** - Sandbox is more lenient:
   - Production requires complete seller registration
   - Production validates addresses against postal databases
   - Production requires verified payment methods
   - Sandbox accepts test data more easily

3. **Romania-Specific Requirements**:
   - May require additional fields not documented in general API docs
   - Address format validation may be stricter
   - Check if phone number is required for RO

4. **Location Key Conflicts**:
   - If location already exists with different data, update may fail
   - GET existing locations first to check for conflicts
   - DELETE old location if needed before creating new one

---

## Task Sequence

### PHASE 1: DIAGNOSTICS (2-3 hours)

#### TASK 1.1: Run Full Diagnostic Script
**File**: diagnose_location.R
**Action**: Execute and analyze all diagnostic tests

**Steps**:
```r
devtools::load_all()
source("diagnose_location.R")
```

**Expected Outputs**:
1. TEST 1 result: GET locations success/failure
2. TEST 2 result: Minimal payload creation attempt
3. TEST 3 result: Sandbox environment test (if authenticated)
4. Recommendations from error pattern analysis

**VALIDATE**:
- [ ] Can successfully GET existing locations (permissions OK)
- [ ] Record minimal payload result
- [ ] Record sandbox result (if applicable)
- [ ] Capture all error messages verbatim

**IF_FAIL**: If GET locations fails, this is an OAuth scope issue:
- Re-authenticate with eBay account
- Verify RuName has correct scopes: `https://api.ebay.com/oauth/api_scope/sell.inventory`
- Check token expiry and refresh if needed

**SAVE_RESULTS**: Create diagnostic_results.txt with all console output

---

#### TASK 1.2: Check Existing Locations
**File**: check_ebay_location.R
**Action**: List any existing locations and analyze them

**Steps**:
```r
source("check_ebay_location.R")
# Review output
# If conflicts exist, consider deleting old locations
```

**VALIDATE**:
- [ ] Record all existing location keys
- [ ] Check if any match current configuration
- [ ] Note location statuses (ENABLED, DISABLED, VALIDATION_PENDING)

**IF_CONFLICT**: If `default_location` or `location_011321` exists with different data:
```r
# Option A: Use existing location as-is
location_key <- "existing_location_key"  # Update in code

# Option B: Delete conflicting location
# Follow prompts in check_ebay_location.R to delete
```

**ROLLBACK**: If you delete a location, you can recreate it manually via eBay Seller Hub

---

#### TASK 1.3: Manual UI Testing
**Action**: Verify seller account setup via eBay web interface

**Manual Steps**:
1. Log into eBay Seller Hub: https://www.ebay.com/sh/ovw
2. Check seller registration status:
   - Payment method verified? ✅/❌
   - Bank account added? ✅/❌
   - Address verified? ✅/❌
   - Seller limits active? (Check for beginner restrictions)

3. Navigate to Settings: https://www.ebay.com/sh/set
4. Check registration address:
   - Does it EXACTLY match .Renviron configuration?
   - Note any differences in formatting

5. Try creating location manually in Seller Hub:
   - Business > Locations
   - Attempt to add new inventory location
   - Record result (success/failure/validation errors)

**VALIDATE**:
- [ ] Seller registration is 100% complete
- [ ] Address matches exactly (no spacing/abbreviation differences)
- [ ] Manual location creation works in UI

**IF_FAIL**: If manual location creation fails:
- **Issue**: Account not approved for inventory management
- **Fix**: Complete seller verification process (may take 1-5 days)
- **Workaround**: Use Trading API instead (older API, different implementation)

**DOCUMENT**: Create account_status.md with findings

---

#### TASK 1.4: Compare Sandbox vs Production
**Action**: Test identical request in both environments

**Steps**:
```r
# Already authenticated in both sandbox and production?
# If not, authenticate in sandbox first

# Run diagnostic script test 3
# Compare results side-by-side
```

**VALIDATE**:
- [ ] Same payload succeeds in sandbox but fails in production?
- [ ] Same error in both? (suggests API request issue)
- [ ] Different errors? (suggests environment-specific issue)

**Analysis Matrix**:
| Sandbox Result | Production Result | Root Cause |
|---------------|------------------|------------|
| ✅ Success | ❌ Error 2004 | Account/verification issue |
| ❌ Error 2004 | ❌ Error 2004 | API request format issue |
| ❌ Different error | ❌ Error 2004 | Check sandbox error details |

**SAVE_RESULTS**: Update diagnostic_results.txt with comparison

---

### PHASE 2: ROOT CAUSE IDENTIFICATION (1 hour)

#### TASK 2.1: Analyze Diagnostic Results
**Action**: Synthesize findings from Phase 1 to identify root cause

**Decision Tree**:

**IF** GET locations fails:
- **Root Cause**: OAuth scope/authentication issue
- **Go to**: TASK 3.1 (Re-authentication)

**ELSE IF** Sandbox succeeds AND production fails:
- **Root Cause**: Production account not approved for Inventory API
- **Go to**: TASK 3.2 (Account Setup)

**ELSE IF** Manual UI location creation fails:
- **Root Cause**: Seller registration incomplete
- **Go to**: TASK 3.2 (Account Setup)

**ELSE IF** Both sandbox and production fail with same error:
- **Root Cause**: API request format issue
- **Go to**: TASK 3.3 (Fix API Request)

**ELSE IF** Existing location conflicts found:
- **Root Cause**: Location key collision
- **Go to**: TASK 3.4 (Use Existing Location)

**VALIDATE**:
- [ ] Root cause clearly identified
- [ ] Documented with supporting evidence
- [ ] Implementation path selected

**DOCUMENT**: Create root_cause_analysis.md

---

### PHASE 3: SOLUTION IMPLEMENTATION (2-4 hours)

#### TASK 3.1: Fix OAuth Authentication Issue
**Condition**: Only if GET locations fails
**Files**: R/ebay_api.R, .Renviron

**Action**: Re-authenticate with correct scopes

**Steps**:
1. Verify OAuth scopes in .Renviron:
```r
EBAY_SCOPES=https://api.ebay.com/oauth/api_scope/sell.inventory,https://api.ebay.com/oauth/api_scope/sell.inventory.readonly
```

2. Check RuName configuration:
```r
# In app, disconnect eBay account
# Reconnect to trigger fresh OAuth flow
# Verify scopes in authorization URL
```

3. Test with fresh token:
```r
ebay_api <- init_ebay_api("production")
# Re-authenticate via UI
loc_result <- ebay_api$inventory$get_locations()
print(loc_result)
```

**VALIDATE**:
```r
# Should succeed:
source("check_ebay_location.R")
# Should list locations or show "No locations found" (not an error)
```

**IF_FAIL**:
- Check eBay Developer Console: https://developer.ebay.com/my/keys
- Verify production app has "Inventory" API checked
- Contact eBay support if scopes look correct but still fail

**ROLLBACK**: N/A (re-authentication is non-destructive)

---

#### TASK 3.2: Complete Account Setup
**Condition**: If account verification needed
**Files**: None (external eBay process)

**Action**: Complete seller registration and verification

**Manual Steps**:
1. Go to eBay Seller Hub: https://www.ebay.com/sh/ovw
2. Complete all onboarding steps:
   - [ ] Add payment method
   - [ ] Verify bank account
   - [ ] Confirm business address
   - [ ] Set seller preferences

3. Wait for verification (can take 1-5 business days)

4. Apply for production API access:
   - https://developer.ebay.com/my/keys
   - Request production access for Inventory API
   - May require application review

**VALIDATE** (after verification complete):
```r
# Should now succeed:
source("diagnose_location.R")
# TEST 1 should pass, TEST 2 should succeed
```

**IF_FAIL**:
- Contact eBay Developer Support: https://developer.ebay.com/support
- Provide account details and error logs
- Reference error ID 2004

**WORKAROUND** (while waiting for approval):
```r
# Option A: Continue using sandbox for testing
# Option B: Implement Trading API fallback (see TASK 3.5)
```

**TIMELINE**: 1-5 days for eBay verification

---

#### TASK 3.3: Fix API Request Format
**Condition**: If API request has format issues
**Files**: R/ebay_api.R:420-502, R/ebay_integration.R:108-144

**Action**: Adjust location payload based on eBay documentation

**Investigation Steps**:
1. Review eBay API docs for Romania-specific requirements
2. Check if phone number is required:
```r
# Search docs for "phone" + "required" + "RO"
# If required, ensure .Renviron has EBAY_LOCATION_PHONE
```

3. Test with enhanced payload:

**READ** R/ebay_integration.R:121-136 (location_data construction)

**FIND_ISSUES**:
- [ ] Missing required fields for RO?
- [ ] Field format incorrect (e.g., postal code format)?
- [ ] Character encoding issues (Romanian characters)?
- [ ] Extra whitespace in address fields?

**TRY_VARIATIONS**:

**Variation 1: Add operating hours (sometimes required)**
```r
# R/ebay_integration.R, after line 128
location_data <- list(
  location = list(
    address = address
  ),
  name = "Primary Location",
  locationTypes = list("WAREHOUSE"),
  operatingHours = list(
    list(
      dayOfWeekEnum = "MONDAY",
      intervals = list(
        list(open = "09:00:00", close = "17:00:00")
      )
    )
  )
)
```

**Variation 2: Try different location type**
```r
# Change from WAREHOUSE to STORE
locationTypes = list("STORE")  # Instead of "WAREHOUSE"
```

**Variation 3: Ensure no special characters**
```r
# Sanitize address fields
address <- list(
  addressLine1 = iconv(location_address_line1, to = "ASCII//TRANSLIT"),
  city = iconv(location_city, to = "ASCII//TRANSLIT"),
  postalCode = gsub("[^0-9]", "", location_postal),  # Only digits
  country = location_country
)
```

**Variation 4: Try minimal request to isolate issue**
```r
# Temporarily simplify to absolute minimum (R/ebay_integration.R:123-128)
location_data <- list(
  location = list(
    address = list(
      city = location_city,
      country = location_country
    )
  )
)
# If this works, add fields back one by one to find problematic field
```

**VALIDATE**:
```r
devtools::load_all()
# Launch app, try creating eBay listing
# Check console for "✅ Location ready" message
```

**IF_FAIL** on specific field:
- Examine eBay error parameters: `param$name` and `param$value`
- Adjust that field's format
- Retry

**ROLLBACK**:
```bash
git checkout R/ebay_integration.R R/ebay_api.R
```

**PERFORMANCE**: No impact (same number of API calls)

---

#### TASK 3.4: Use Existing Location
**Condition**: If suitable location already exists
**Files**: R/ebay_integration.R:66-152

**Action**: Detect and reuse existing locations instead of creating new ones

**Implementation**:

**STEP 1**: Add location detection before creation

**EDIT** R/ebay_integration.R:66, **INSERT BEFORE** location creation:

```r
# Step 2: Check for existing inventory locations
cat("\n2. Checking inventory location...\n")

# First, try to get existing locations
existing_locations_result <- ebay_api$inventory$get_locations()

# If we already have a location, use it
if (existing_locations_result$success &&
    !is.null(existing_locations_result$locations) &&
    length(existing_locations_result$locations) > 0) {

  # Use first available location
  first_location <- existing_locations_result$locations[[1]]
  location_key <- first_location$merchantLocationKey

  cat("   ✅ Using existing location:", location_key, "\n")
  cat("      Address:", first_location$location$address$addressLine1 %||% "N/A", "\n")
  cat("      City:", first_location$location$address$city %||% "N/A", "\n")
  cat("      Country:", first_location$location$address$country %||% "N/A", "\n")

  # Skip location creation, jump to inventory item creation

} else {
  # No existing locations, create one
  cat("   No existing locations found, creating new location...\n")

  # [KEEP EXISTING LOCATION CREATION CODE HERE - lines 70-152]
}
```

**VALIDATE**:
```r
# Run check_ebay_location.R first to see existing locations
source("check_ebay_location.R")

# Then test listing creation
devtools::load_all()
# Launch app, create listing
# Should see "Using existing location: XXX" message
```

**IF_FAIL**:
- Ensure existing location has status "ENABLED"
- Check if location is associated with inventory items
- May need to explicitly enable disabled locations via eBay API

**ROLLBACK**:
```bash
git diff R/ebay_integration.R  # Review changes
git checkout R/ebay_integration.R  # Undo if needed
```

**ADVANTAGE**: Avoids error 2004 entirely by not creating locations

---

#### TASK 3.5: Implement Trading API Fallback (Advanced)
**Condition**: If Inventory API remains blocked
**Files**: R/ebay_api.R (new class), R/ebay_integration.R
**Complexity**: HIGH (4-6 hours)
**Risk**: MEDIUM (different API paradigm)

**Action**: Implement alternative listing creation via older Trading API

**Background**:
- Trading API is older but more widely available
- Doesn't require Inventory Location setup
- Uses different authentication (sometimes easier to get approved)
- Different data structure (XML-based vs JSON)

**Implementation Outline**:

**STEP 1**: Create TradingAPI class (R/ebay_api.R, after EbayMediaAPI)

```r
EbayTradingAPI <- R6::R6Class("EbayTradingAPI",
  private = list(
    oauth = NULL,
    config = NULL
  ),

  public = list(
    initialize = function(oauth, config) {
      private$oauth <- oauth
      private$config <- config
    },

    # Add item using Trading API
    add_item = function(item_data) {
      # Build XML request (Trading API uses XML, not JSON)
      # Call AddItem or AddFixedPriceItem endpoint
      # Parse XML response
    }
  )
)
```

**STEP 2**: Update init_ebay_api() to include Trading API

**STEP 3**: Add fallback logic in ebay_integration.R

```r
# In create_ebay_listing_from_card(), after location creation fails:
if (!location_result$success) {
  cat("   ⚠️ Inventory API location creation failed\n")
  cat("   Attempting fallback to Trading API...\n")

  trading_result <- ebay_api$trading$add_item(...)
  if (trading_result$success) {
    return(trading_result)
  }
}
```

**VALIDATE**:
- Trading API listing appears on eBay
- All data (title, price, image) correct
- Database tracking works

**IF_FAIL**:
- Trading API may also be restricted
- Check eBay Developer Console for Trading API access

**ROLLBACK**:
- Comment out fallback logic
- Keep Inventory API as primary

**RECOMMENDATION**: Only implement if other solutions fail after 1 week

---

### PHASE 4: TESTING & VALIDATION (1 hour)

#### TASK 4.1: End-to-End Listing Creation Test
**Action**: Test complete flow after implementing solution

**Test Cases**:

**Test 1: Fresh Location Creation**
```r
# Delete all existing locations first (via check_ebay_location.R)
devtools::load_all()
run_app()

# In app:
# 1. Authenticate with eBay (production)
# 2. Process a postcard with AI extraction
# 3. Click "Send to eBay"
# 4. Monitor console output

# Expected output:
# ✅ Location ready: location_XXXXX (RO 011321)
# ✅ Inventory item created
# ✅ Offer created
# ✅ Offer published
# ✅ Database record created
```

**VALIDATE**:
- [ ] No error 2004 appears
- [ ] Location creation succeeds (HTTP 200/201/204)
- [ ] Full listing created on eBay
- [ ] Listing URL is accessible
- [ ] Image appears correctly

**IF_FAIL**: Check specific failure step and revisit corresponding task

---

**Test 2: Existing Location Reuse**
```r
# Run Test 1 first to create a location
# Then run again without deleting location

# Expected output:
# ✅ Using existing location: location_XXXXX
# [No location creation API call]
# ✅ Inventory item created
# ... (rest of flow)
```

**VALIDATE**:
- [ ] Location not created again
- [ ] Existing location used successfully
- [ ] Listing created with same location

---

**Test 3: Error Handling**
```r
# Test with invalid configuration
Sys.setenv(EBAY_LOCATION_CITY = "")  # Remove required field

devtools::load_all()
run_app()

# Try to create listing

# Expected output:
# ❌ Missing required location fields in .Renviron: EBAY_LOCATION_CITY
```

**VALIDATE**:
- [ ] Clear error message shown
- [ ] No cryptic API errors
- [ ] User knows how to fix the issue

---

**Test 4: Multi-Account Scenario**
```r
# If using multi-account feature
# Switch to different eBay account
# Try creating listing

# Location should be created with correct account's address
```

**VALIDATE**:
- [ ] Location tied to correct account
- [ ] No cross-account location conflicts

---

#### TASK 4.2: Performance & Reliability Testing
**Action**: Verify solution is robust

**Checks**:
1. **Idempotency**: Creating listing twice with same data doesn't cause errors
2. **Retry Logic**: If location creation fails transiently, does it retry?
3. **Token Refresh**: If token expires during listing creation, does it refresh?
4. **Rate Limits**: Multiple listings in quick succession handled gracefully?

**VALIDATE**:
```r
# Create 3 listings in a row
# All should succeed without manual intervention
```

**IF_FAIL**:
- Add retry logic for transient errors
- Implement exponential backoff
- Add token refresh checks

---

### PHASE 5: DOCUMENTATION & CLEANUP (30 min)

#### TASK 5.1: Update Documentation
**Files**: PRPs/PRP_EBAY_LOCATION_CREATION_FIX.md, .serena/memories/

**Action**: Document the solution and learnings

**CREATE** .serena/memories/ebay_location_fix_YYYYMMDD.md:

```markdown
# eBay Location Creation Fix - [Date]

## Root Cause
[What was actually causing error 2004]

## Solution Implemented
[Which task from TASK PRP was used]

## Files Modified
- R/ebay_api.R (lines X-Y): [changes]
- R/ebay_integration.R (lines X-Y): [changes]
- .Renviron: [new variables]

## Testing Results
- [Test 1 result]
- [Test 2 result]
- [etc.]

## Lessons Learned
- [Gotcha 1]
- [Gotcha 2]

## Future Enhancements
- [Optional improvement 1]
- [Optional improvement 2]
```

**UPDATE** PRPs/PRP_EBAY_LOCATION_CREATION_FIX.md:

Add at end:
```markdown
## RESOLUTION - [Date]

✅ **FIXED**

**Root Cause**: [brief description]

**Solution**: [brief description]

**See**: .serena/memories/ebay_location_fix_YYYYMMDD.md
```

**VALIDATE**:
- [ ] Memory file created with comprehensive details
- [ ] PRP marked as resolved
- [ ] Future developers can understand the fix

---

#### TASK 5.2: Clean Up Diagnostic Scripts
**Files**: diagnose_location.R, check_ebay_location.R, diagnostic_results.txt

**Action**: Archive diagnostic files

**Steps**:
```bash
# Keep scripts (they may be useful again)
# But move results to archive

mkdir -p TASK_PRP/ebay_location_fix_archive
mv diagnostic_results.txt TASK_PRP/ebay_location_fix_archive/
mv account_status.md TASK_PRP/ebay_location_fix_archive/
mv root_cause_analysis.md TASK_PRP/ebay_location_fix_archive/

# Add note to scripts
echo "# ARCHIVED - Issue resolved on [DATE]" >> diagnose_location.R
echo "# See: .serena/memories/ebay_location_fix_YYYYMMDD.md" >> diagnose_location.R
```

**VALIDATE**:
- [ ] Repository clean (no stale diagnostic output)
- [ ] Scripts preserved for future use
- [ ] Archive contains complete diagnostic history

---

#### TASK 5.3: Update User-Facing Docs
**Files**: docs/guides/PRODUCTION_TESTING_GUIDE.md (if exists)

**Action**: Add location setup to production checklist

**ADD** section if guide exists:

```markdown
### eBay Inventory Location Setup

Before creating your first eBay listing in production:

1. Ensure .Renviron has location configuration:
   ```bash
   EBAY_LOCATION_COUNTRY=RO
   EBAY_LOCATION_CITY=Bucharest
   EBAY_LOCATION_ADDRESS_LINE1=Turda 1
   EBAY_LOCATION_POSTAL=011321
   EBAY_LOCATION_PHONE=+40123456789  # Optional but recommended
   ```

2. Address must EXACTLY match your eBay seller registration
3. First listing creation will automatically create the location
4. Subsequent listings will reuse the same location

**Troubleshooting**:
- Error 2004: Verify seller registration is complete
- Location conflicts: Run `source("check_ebay_location.R")` to manage locations
```

**VALIDATE**:
- [ ] User documentation updated
- [ ] Setup instructions clear
- [ ] Troubleshooting guide helpful

---

## Success Criteria

**Must Have** (all required):
- [ ] Location creation succeeds with HTTP 200/201/204 (not 400)
- [ ] Error 2004 no longer appears
- [ ] Full eBay listing created end-to-end
- [ ] Solution works for any eBay account (not hardcoded)
- [ ] Clear error messages guide users when setup incomplete

**Nice to Have**:
- [ ] Works in both sandbox and production
- [ ] Existing location detection and reuse
- [ ] Multi-account support verified
- [ ] Diagnostic scripts available for future issues

**Performance Targets**:
- [ ] Location creation: < 2 seconds
- [ ] Total listing creation: < 10 seconds
- [ ] No unnecessary API calls (reuse locations)

---

## Risk Assessment

### High Risk Areas

**1. Account Verification Delays**
- **Risk**: eBay verification takes 1-5 days
- **Mitigation**: User can continue development in sandbox
- **Contingency**: Trading API fallback (TASK 3.5)

**2. Romania-Specific Requirements**
- **Risk**: Undocumented field requirements for RO
- **Mitigation**: Test with multiple variations (TASK 3.3)
- **Contingency**: Contact eBay Developer Support

**3. Location Key Conflicts**
- **Risk**: Existing locations interfere with new ones
- **Mitigation**: GET locations first, reuse if suitable (TASK 3.4)
- **Contingency**: DELETE conflicting locations via check script

### Rollback Strategy

**If solution makes things worse**:
```bash
# 1. Revert code changes
git diff  # Review what changed
git checkout R/ebay_api.R R/ebay_integration.R

# 2. Restore original .Renviron
cp .Renviron.backup .Renviron  # If you made a backup

# 3. Clear any test locations
source("check_ebay_location.R")
# Delete test locations created during debugging

# 4. Return to original error state
# At least we're back to a known state
```

**Safe to Rollback**: All changes are in application code, no eBay account modifications

---

## Debug Strategies

### When Tests Fail

**Symptom**: Still getting error 2004 after implementing fix

**Debug Steps**:
1. **Enable maximum verbosity**:
```r
# In R/ebay_api.R:create_location(), add more logging
cat("   DEBUG - Full request:\n")
cat("      Headers:\n")
cat("         Authorization: Bearer [TOKEN_LENGTH:", nchar(private$oauth$get_access_token()), "]\n")
cat("         Content-Type: application/json\n")
cat("      Body (formatted):\n")
print(jsonlite::toJSON(location_data, auto_unbox = TRUE, pretty = TRUE))
```

2. **Capture raw response**:
```r
# After req_perform(), before error handling
raw_response <- resp_body_string(response)
cat("   DEBUG - Raw response body:\n", raw_response, "\n")
writeLines(raw_response, "ebay_response.txt")  # Save for analysis
```

3. **Compare with working request**:
   - If sandbox works, capture sandbox request/response
   - Diff the two to find differences
   - Focus on field values, not just structure

4. **Test with Postman/curl**:
```bash
# Export request as curl command from httr2
# Test outside of R to isolate application-specific issues
curl -X PUT "https://api.ebay.com/sell/inventory/v1/location/test_location" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"location":{"address":{"city":"Bucharest","country":"RO"}}}'
```

5. **Check eBay Developer Forums**:
   - Search for "error 2004 inventory location Romania"
   - Look for similar issues from other developers
   - Post question with sanitized request/response

---

**Symptom**: GET locations works but PUT location fails

**Likely Cause**: Write permissions issue

**Fix**:
- Check OAuth scopes include `sell.inventory` (not just `sell.inventory.readonly`)
- Re-authenticate with correct scopes
- Verify app has write permissions in Developer Console

---

**Symptom**: Works in sandbox but fails in production with different error

**Likely Cause**: Production validation stricter

**Fix**:
- Compare sandbox vs production address validation rules
- Ensure address is in eBay's postal database
- Try alternative address format (abbreviations, no abbreviations, etc.)

---

## Timeline Estimate

**Optimistic** (account already approved): 2 hours
- 1 hour diagnostics
- 30 min fix implementation
- 30 min testing

**Realistic** (needs minor API fix): 4 hours
- 2 hours diagnostics
- 1 hour fix implementation
- 1 hour testing & docs

**Pessimistic** (needs eBay approval): 1-5 days
- 2 hours diagnostics identifying account issue
- 1-5 days waiting for eBay verification
- 1 hour testing after approval

**Worst Case** (requires Trading API fallback): 8-10 hours
- 3 hours exhausting Inventory API options
- 5 hours implementing Trading API
- 2 hours testing both paths

---

## Next Actions

**START HERE**:
1. Run `source("diagnose_location.R")` immediately
2. Save all console output to diagnostic_results.txt
3. Follow diagnostic results to identify root cause (TASK 2.1)
4. Jump to appropriate implementation task (TASK 3.1-3.5)

**User Decision Points**:
- If account verification needed → User must wait for eBay (1-5 days)
- If existing location suitable → User chooses to delete or reuse
- If Trading API needed → User approves scope expansion (more complex)

**Completion**:
- Update this TASK PRP with actual solution used
- Create memory file with detailed findings
- Mark PRP_EBAY_LOCATION_CREATION_FIX.md as resolved

---

## References

- **eBay Inventory API Docs**: https://developer.ebay.com/api-docs/sell/inventory/overview.html
- **Error Codes Reference**: https://developer.ebay.com/api-docs/sell/inventory/error-codes.html
- **Developer Support**: https://developer.ebay.com/support
- **Seller Hub**: https://www.ebay.com/sh/ovw
- **Trading API Docs**: https://developer.ebay.com/Devzone/XML/docs/Reference/eBay/index.html (fallback option)

---

**Generated by**: Claude Code
**Task Type**: Diagnostic and Fix
**Complexity**: Medium to High (depends on root cause)
**Dependencies**: eBay account status, API access approval
**Breaking Changes**: None (backward compatible)
