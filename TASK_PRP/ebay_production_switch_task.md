# TASK PRP: Switch eBay Integration to Production Mode

## Overview

Switch the eBay integration from sandbox testing to live production environment. This involves updating credentials, configuring business policies, changing location from US to Romania, and enabling real eBay listing creation.

## Context

### Documentation
```yaml
docs:
  - url: https://developer.ebay.com/api-docs/sell/inventory/overview.html
    focus: Inventory API endpoints (location, item, offer, publish)
  - url: https://developer.ebay.com/api-docs/static/oauth-tokens.html
    focus: Production OAuth setup and RuName generation
  - url: https://www.ebay.com/sh/buspolicy
    focus: Creating and managing business policies

patterns:
  - file: R/ebay_integration.R:15-246
    copy: Existing listing creation flow (proven in sandbox)
  - file: R/ebay_api.R:9-59
    copy: Environment-aware configuration pattern
  - file: .serena/memories/ebay_oauth_integration_complete_20251017.md
    context: Sandbox implementation complete and tested

gotchas:
  - issue: "Sandbox uses api.*.ebay.com for tokens, NOT auth.*.ebay.com"
    fix: "Already fixed in code, don't change token endpoint URLs"
  - issue: "Business policies REQUIRED in production, optional in sandbox"
    fix: "Must configure policies before first production listing"
  - issue: "RuName is NOT a URL - it's a special eBay-generated identifier"
    fix: "Get from developer.ebay.com/my/keys, don't make up a URL"
  - issue: "Location must match seller's registered eBay account country"
    fix: "Verify seller account is registered for Romania before switching"
```

## Prerequisites

**User Actions Required BEFORE Code Changes:**

1. **Verify eBay Account Registration:**
   - Confirm seller account is registered for selling from Romania
   - Check seller hub for country settings
   - Verify address on file matches location we'll set in code

2. **Create Production OAuth RuName:**
   - Go to: https://developer.ebay.com/my/keys
   - Switch to "Production Keys" tab
   - Click "User Tokens" → "Add eBay Redirect URL"
   - Fill form:
     - Display Title: "Delcampe Production OAuth"
     - Privacy Policy URL: (provide if required)
     - Select: **OAuth** (not Auth'n'Auth)
   - Save and copy generated RuName (format: `USERNAME-APPNAME-SUFFIX`)

3. **Create Business Policies:**
   - Go to: https://www.ebay.com/sh/buspolicy
   - Create **Payment Policy**:
     - Name: "Delcampe Standard Payment"
     - Payment methods: PayPal, credit cards (as desired)
     - Copy Policy ID after saving
   - Create **Return Policy**:
     - Name: "Delcampe Returns"
     - Return period: 14/30/60 days (seller's choice)
     - Who pays shipping: Buyer/Seller (seller's choice)
     - Copy Policy ID after saving
   - Create **Fulfillment Policy**:
     - Name: "Delcampe Shipping"
     - Handling time: 1-3 business days
     - Domestic/international shipping rates
     - Item location: Romania
     - Copy Policy ID after saving

4. **Backup Current Configuration:**
   - Copy `.Renviron` to backup location
   - Document current sandbox state
   - Note any test listings in sandbox

---

## Task Sequence

### PHASE 1: Configuration Updates (No Code Changes)

#### TASK 1.1: Backup Current State
**File:** `.Renviron`
```bash
# Backup command
cp .Renviron C:/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/.Renviron.sandbox.$(date +%Y%m%d_%H%M%S)
```

**Action:**
- Create timestamped backup of `.Renviron`
- Document current sandbox test results
- Note any pending sandbox tests

**Validate:**
```bash
# Check backup exists
ls -la C:/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/.Renviron.sandbox.*
```

**If_Fail:** Manually copy file to backup location

**Rollback:** N/A (this IS the rollback preparation)

---

#### TASK 1.2: Update .Renviron with Production Settings
**File:** `.Renviron`

**Current State (lines 14-31):**
```env
EBAY_PROD_CLIENT_ID=your_production_app_id_here
EBAY_PROD_CLIENT_SECRET=your_production_cert_id_here
EBAY_PROD_DEV_ID=your_production_dev_id_here
EBAY_REDIRECT_URI=TITA_MARIUS-TITAMARI-Delcam-dcgnbxvbl
EBAY_ENVIRONMENT=sandbox
```

**Action:**
Replace with actual production values:
```env
# Production Credentials (from developer.ebay.com)
EBAY_PROD_CLIENT_ID=<actual_production_app_id>
EBAY_PROD_CLIENT_SECRET=<actual_production_cert_id>
EBAY_PROD_DEV_ID=<actual_production_dev_id>

# Production OAuth RuName (NEW - from User Tokens section)
EBAY_PROD_REDIRECT_URI=<production_runame_from_developer_portal>

# Business Policy IDs (from ebay.com/sh/buspolicy)
EBAY_FULFILLMENT_POLICY_ID=<fulfillment_policy_id>
EBAY_PAYMENT_POLICY_ID=<payment_policy_id>
EBAY_RETURN_POLICY_ID=<return_policy_id>

# Switch to production
EBAY_ENVIRONMENT=production
```

**Validate:**
```r
# In R console after restart
Sys.getenv("EBAY_ENVIRONMENT")  # Should return "production"
Sys.getenv("EBAY_PROD_CLIENT_ID")  # Should NOT be "your_production_app_id_here"
Sys.getenv("EBAY_FULFILLMENT_POLICY_ID")  # Should be numeric ID
```

**If_Fail:**
- Check for typos in variable names
- Verify no trailing spaces in values
- Ensure no quote marks around values
- Restart R session to reload .Renviron

**Rollback:**
```bash
cp C:/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/.Renviron.sandbox.* .Renviron
```

---

### PHASE 2: Code Updates

#### TASK 2.1: Update Location from US to Romania
**File:** `R/ebay_integration.R`
**Lines:** 50-52

**Current Code:**
```r
address = list(
  country = "US",
  postalCode = "10001"
)
```

**Action:**
Replace with:
```r
address = list(
  country = "RO",
  postalCode = "010101"  # Bucharest postal code, update if different
)
```

**Implementation Strategy:**
- Use `serena:find_symbol` to locate exact code
- Use `serena:replace_symbol_body` if replacing entire function
- OR use Edit tool for targeted line replacement

**Validate:**
```r
# Read the file and check
source("R/ebay_integration.R")
# Manually verify lines 50-52 show "RO" instead of "US"
```

**If_Fail:**
- Edit not applied → use Edit tool with exact old_string match
- Verify indentation matches (2 spaces, not tabs)

**Rollback:**
```bash
git checkout R/ebay_integration.R
```

---

#### TASK 2.2: Optional - Make Location Configurable
**File:** `R/ebay_integration.R`
**Lines:** 45-60 (create_location call)

**Action:**
Add environment variable support for location:
```r
# At top of create_ebay_listing_from_card function
location_country <- Sys.getenv("EBAY_LOCATION_COUNTRY", "RO")
location_postal <- Sys.getenv("EBAY_LOCATION_POSTAL_CODE", "010101")
location_city <- Sys.getenv("EBAY_LOCATION_CITY", "Bucharest")

# Then in create_location call
location_data = list(
  location = list(
    address = list(
      country = location_country,
      postalCode = location_postal,
      city = location_city
    )
  ),
  name = "Primary Location",
  locationTypes = list("WAREHOUSE")
)
```

**Validate:**
```r
# Test with different values
Sys.setenv(EBAY_LOCATION_COUNTRY = "RO")
Sys.setenv(EBAY_LOCATION_POSTAL_CODE = "020101")
# Run test listing creation (with high price)
# Check location in created listing
```

**If_Fail:**
- Skip this enhancement
- Use hardcoded values (Task 2.1 is sufficient)

**Rollback:**
```bash
git checkout R/ebay_integration.R
```

---

### PHASE 3: Production Authorization

#### TASK 3.1: Restart Shiny App
**Action:**
- Stop current Shiny app session
- Restart R session to reload `.Renviron`
- Launch Shiny app: `golem::run_dev()`

**Validate:**
```r
# In app's server console
cat("Environment:", Sys.getenv("EBAY_ENVIRONMENT"), "\n")
cat("Prod Client:", substr(Sys.getenv("EBAY_PROD_CLIENT_ID"), 1, 10), "...\n")
```

**If_Fail:**
- Check `.Renviron` syntax (no spaces around `=`)
- Verify file saved before restart
- Use `readRenviron(".Renviron")` to force reload

**Rollback:** Restore sandbox .Renviron and restart

---

#### TASK 3.2: Authorize with Production eBay Account
**Action:**
1. Navigate to eBay integration section in app
2. Click "Connect to eBay" button
3. Browser opens eBay login page
4. **CRITICAL:** Sign in with PRODUCTION seller account (not sandbox test user)
5. Click "Agree" to authorize app
6. Copy authorization code from URL
7. Paste code into app's input field
8. Click "Get Token"

**Validate:**
- Success message: "Connected to eBay API (production environment)"
- Token saved to: `inst/app/data/ebay_tokens.rds`
- Token length: ~2500+ characters (valid access token)

**If_Fail:**
Common errors:
- **500 "temporarily_unavailable":** Check token endpoint (should use `api.*.ebay.com`)
- **400 "invalid_request":** Wrong RuName or RuName not OAuth-enabled
- **invalid_grant:** Authorization code expired (max 5 min), restart from step 1

**Debug Strategy:**
```r
# Check what config is loaded
ebay_api <- init_ebay_api()
print(ebay_api$config$environment)  # Should be "production"
print(ebay_api$config$get_base_url())  # Should be "https://api.ebay.com"
```

**Rollback:** Switch EBAY_ENVIRONMENT back to sandbox, restart, re-authorize sandbox

---

### PHASE 4: Production Testing

#### TASK 4.1: Create High-Price Test Listing
**Action:**
1. Select low-value postcard or test item
2. Fill in listing details (or use AI extraction)
3. **CRITICAL:** Set price to $999.99 (prevents accidental sale)
4. Click "Create eBay Listing"
5. Wait for all steps to complete:
   - ✅ Inventory location created/verified
   - ✅ Inventory item created (HTTP 204)
   - ✅ Offer created (HTTP 201)
   - ✅ **Offer published** (HTTP 200) ← KEY TEST
   - ✅ Listing ID returned

**Validate:**
```r
# Check console output for success messages
# Expected: "LISTING CREATED SUCCESSFULLY"
# Expected: listing URL like "https://www.ebay.com/itm/123456789"
```

**If_Fail:**
Error scenarios:
- **25002 "No business policy":** Check policy IDs in .Renviron
- **25002 "Invalid location":** Verify account registered for Romania
- **401 "Unauthorized":** Token expired, re-authorize
- **403 "Forbidden":** Account not approved for selling, check eBay seller hub

**Debug Strategy:**
1. Check `.Renviron` has all three policy IDs
2. Verify policies exist in eBay Seller Hub
3. Check seller account status (suspended? limits reached?)
4. Review app console for detailed error messages

**Rollback:** Delete test listing immediately if created

---

#### TASK 4.2: Verify Listing on eBay.com
**Action:**
1. Open listing URL from step 4.1
2. Verify listing displays correctly:
   - Title matches submitted title
   - Description matches
   - Price shows $999.99
   - Shipping policy details appear (from fulfillment policy)
   - Return policy details appear (from return policy)
   - Payment methods appear (from payment policy)
   - Location shows "Romania" or specific city
   - Images display correctly
   - Category is "Postcards" (914)

**Validate:**
- Listing is LIVE on eBay.com (not sandbox)
- All policy details populated automatically
- No missing required fields
- Listing appears in your seller hub

**If_Fail:**
- Missing policies: Policies not properly linked, check IDs
- Wrong location: Code not updated or seller account location mismatch
- Missing images: Check image URL accessibility from eBay servers
- Wrong category: Hardcoded to 914, verify this is correct

**Rollback:** End listing immediately (next task)

---

#### TASK 4.3: End Test Listing
**Action:**
1. Go to eBay Seller Hub → Active Listings
2. Find test listing (price $999.99)
3. Click "End listing"
4. Reason: "Made an error in the listing"
5. Confirm deletion

**Validate:**
- Listing no longer appears on eBay.com
- Listing shows as "Ended" in seller hub
- No eBay fees charged (check seller account)

**If_Fail:**
- Listing can't be ended → Contact eBay support
- Fees charged → Normal for ended listing, may be credited

**Rollback:** N/A (cleanup step)

---

### PHASE 5: Deployment

#### TASK 5.1: Create First Real Listing
**Action:**
1. Select actual postcard for sale
2. Use AI extraction to populate fields
3. **CRITICAL:** Set REALISTIC price (market value)
4. Review all fields for accuracy
5. Click "Create eBay Listing"
6. Verify success
7. Check listing appears correctly on eBay.com
8. Monitor for first 24 hours:
   - Check views in seller hub
   - Ensure no buyer questions about errors
   - Verify shipping calculator works for buyers

**Validate:**
- Listing created successfully
- Price is realistic (not $999)
- All details accurate
- Listing searchable on eBay
- No error notifications from eBay

**If_Fail:**
- Listing errors → Fix and re-list
- Policy issues → Update policies in seller hub
- Pricing errors → Revise listing in seller hub

**Rollback:** End listing and fix issues before continuing

---

#### TASK 5.2: Bulk Listing Deployment
**Action:**
1. Create 5-10 more listings over 24-48 hours
2. Monitor each for issues
3. Check eBay seller limits (new accounts have listing limits)
4. Verify database tracking works correctly
5. Review first sales (if any) for fulfillment workflow

**Validate:**
- All listings created without errors
- Database tracks all listings correctly
- No account warnings from eBay
- Policies apply correctly to all listings
- Can manage all listings from seller hub

**If_Fail:**
- Listing limits reached → Wait for eBay to increase limits
- Repeated errors → Pause and debug
- Database issues → Check database extension code

**Rollback:** Stop creating new listings, debug issues

---

### PHASE 6: Post-Deployment

#### TASK 6.1: Update Documentation
**File:** `EBAY_INTEGRATION_STATUS.md` or similar

**Action:**
Add production status section:
```markdown
## Production Status (Updated: YYYY-MM-DD)

### Environment: PRODUCTION

**OAuth:** ✅ Configured with production RuName
**Credentials:** ✅ Production keys active
**Business Policies:** ✅ All three policies configured
- Fulfillment Policy ID: [ID]
- Payment Policy ID: [ID]
- Return Policy ID: [ID]

**Location:** ✅ Romania (postal code: [code])
**Test Results:** ✅ Test listing successful (deleted)
**Production Listings:** [count] active listings

### Known Issues
- [Document any issues encountered]

### Lessons Learned
- [Document any gotchas or tips]
```

**Validate:**
- Documentation accurately reflects current state
- Future developers can understand setup

**If_Fail:** N/A (documentation only)

**Rollback:** N/A

---

#### TASK 6.2: Create Memory File
**File:** `.serena/memories/ebay_production_switch_complete_[date].md`

**Action:**
Document complete production switch:
```markdown
# eBay Production Switch Complete - [Date]

## Summary
Successfully switched from sandbox to production eBay environment.

## Configuration Changes
- Environment: sandbox → production
- Location: US → Romania
- Business policies: Configured all three required policies
- OAuth: Production RuName configured

## Files Modified
- `.Renviron` - Lines 14-31 (production credentials and policies)
- `R/ebay_integration.R` - Lines 50-52 (location update)

## Test Results
- Test listing: SUCCESS
- Production listing: SUCCESS
- Total listings created: [count]

## Gotchas Discovered
[Document any issues encountered and solutions]

## Next Steps
[Optional enhancements or monitoring tasks]
```

**Validate:**
- Memory file created in `.serena/memories/`
- Indexed in `.serena/memories/INDEX.md`

**If_Fail:** N/A (documentation only)

**Rollback:** N/A

---

## Optional Enhancements (Post-Production)

### ENHANCEMENT 1: Fetch Policies from eBay API
**Goal:** Allow seller to select policies from UI instead of editing .Renviron

**Files to Create/Modify:**
- `R/ebay_policies.R` - New file with policy fetching functions
- `R/mod_ebay_settings.R` - New Shiny module for settings UI

**API Endpoints:**
```
GET /sell/account/v1/fulfillment_policy
GET /sell/account/v1/payment_policy
GET /sell/account/v1/return_policy
```

**Implementation Steps:**
1. Create policy fetching functions in `ebay_policies.R`
2. Create settings module with dropdown selectors
3. Store selected policies in app config or database
4. Update `create_ebay_listing_from_card` to use selected policies

**Validate:**
- Can fetch policies from eBay
- UI displays policy names and IDs
- Selected policies apply to new listings

**Priority:** LOW (nice-to-have, not critical)

---

### ENHANCEMENT 2: Multi-Location Support
**Goal:** Support sellers with inventory in multiple locations

**Implementation:**
- Store multiple locations in database
- Allow location selection per listing
- Track which location each item uses

**Priority:** LOW

---

## Error Handling Reference

### Production-Specific Errors

**Error 25002 - "No business policy":**
- **Cause:** Policy ID invalid or policy doesn't exist
- **Fix:** Verify policy IDs in eBay Seller Hub match .Renviron

**Error 25002 - "Invalid location":**
- **Cause:** Location country doesn't match seller account
- **Fix:** Verify seller registered for selling from Romania

**Error 401 - "Unauthorized":**
- **Cause:** Access token expired (typically 2 hours)
- **Fix:** Re-authorize app, implement token refresh

**Error 403 - "Forbidden":**
- **Cause:** Account suspended or selling limits reached
- **Fix:** Check eBay seller hub for account status

**Error 9001 - "Selling limit reached":**
- **Cause:** New sellers have monthly listing limits
- **Fix:** Request limit increase from eBay or wait for monthly reset

---

## Success Criteria

✅ **Production switch successful when:**
1. Can authorize with production eBay account
2. All three business policies configured and recognized
3. Can create inventory items in production
4. Can create offers with policies attached
5. **Can publish offers successfully** (KEY TEST)
6. Listings appear on eBay.com (not sandbox)
7. Listings show correct location (Romania)
8. Listings show correct policies (shipping/payment/return)
9. No errors in full listing creation flow
10. Database tracks production listings correctly

---

## Rollback Strategy

### Emergency Rollback (Critical Failure)

**Steps:**
1. Stop creating new listings immediately
2. Restore sandbox .Renviron:
   ```bash
   cp C:/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/.Renviron.sandbox.* .Renviron
   ```
3. Restore code changes:
   ```bash
   git checkout R/ebay_integration.R
   ```
4. Restart Shiny app
5. Re-authorize with sandbox credentials
6. Verify sandbox still works
7. Debug production issues before retry

**When to Rollback:**
- Unable to authorize production account
- Repeated API failures (>3 consecutive)
- eBay account suspended/restricted
- Critical data corruption in database
- Cannot end test listings

### Partial Rollback (Specific Issues)

**Issue: Wrong location in listings**
- End all active listings with wrong location
- Fix code (Task 2.1)
- Redeploy

**Issue: Policy problems**
- Continue with listings if functional
- Fix policies in eBay Seller Hub (live update)
- New listings use updated policies

**Issue: Price errors**
- Revise prices in eBay Seller Hub (no need for code change)

---

## Timeline Estimate

**Pre-Implementation (User):**
- eBay account verification: 5 minutes
- Create production RuName: 10 minutes
- Create business policies: 30 minutes
- **Total:** 45 minutes

**Implementation (Developer):**
- Phase 1 (Config backup & update): 15 minutes
- Phase 2 (Code changes): 15 minutes
- Phase 3 (Authorization): 10 minutes
- Phase 4 (Testing): 30 minutes
- Phase 5 (Deployment): 2-24 hours (monitoring)
- Phase 6 (Documentation): 20 minutes
- **Total:** ~1.5 hours active + 24 hours monitoring

**Total Time:** ~2 hours active work + monitoring period

---

## Quality Checklist

- [x] All changes identified
- [x] Dependencies mapped (OAuth → policies → code → testing)
- [x] Each task has validation steps
- [x] Rollback steps included for each phase
- [x] Debug strategies provided for common errors
- [x] Performance impact: None (production may be faster than sandbox)
- [x] Security checked: Production credentials in .Renviron (gitignored)
- [x] Edge cases: Account limits, policy errors, location mismatches

---

## Related Files

**Modified:**
- `.Renviron` - Production credentials and policy IDs
- `R/ebay_integration.R` - Location update (lines 50-52)

**Referenced:**
- `R/ebay_api.R` - OAuth and API client (no changes needed)
- `R/ebay_helpers.R` - Utility functions (no changes needed)
- `R/ebay_database_extension.R` - Database tracking (no changes needed)
- `R/mod_ebay_auth.R` - Auth UI module (no changes needed)

**Documentation:**
- `PRPs/PRP_EBAY_PRODUCTION_SWITCH.md` - Source requirements
- `.serena/memories/ebay_oauth_integration_complete_20251017.md` - Sandbox status
- `EBAY_INTEGRATION_STATUS.md` - Status tracking (to be updated)

---

## Notes

**Key Insight:** The switch from sandbox to production is primarily a configuration change. The code is already production-ready from sandbox testing. The critical elements are:

1. **Business Policies:** Configured ONCE in eBay Seller Hub
2. **OAuth RuName:** Different for production vs sandbox
3. **Location:** Must match seller's registered country
4. **Credentials:** Separate keys for prod vs sandbox

**Policy Benefits:**
- ✅ Configure shipping/payment/returns ONCE
- ✅ All future listings use those settings automatically
- ✅ Update policies anytime in Seller Hub
- ✅ Changes apply to all new listings
- ✅ No re-entering details per listing

**Sandbox vs Production:**
| Aspect | Sandbox | Production |
|--------|---------|------------|
| Listings appear | Nowhere | eBay.com |
| Business policies | Optional | REQUIRED |
| Publish step | Fails | Works |
| Cost | Free | eBay fees |
| Testing | Safe | Real money |
