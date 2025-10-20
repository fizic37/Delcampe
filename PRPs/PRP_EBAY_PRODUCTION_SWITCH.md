# PRP: Switch eBay Integration to Production Mode

## Overview

Enable production eBay listing creation for the Delcampe app. This involves switching from sandbox testing to live eBay marketplace, configuring business policies, and using the seller's pre-configured eBay account settings.

## Current State

**Sandbox Implementation (Complete):**
- ✅ OAuth authentication working
- ✅ API integration functional (inventory items, offers)
- ✅ Code tested and production-ready
- ⚠️ Publishing fails in sandbox (known limitation)

**Location:** Currently hardcoded to US (line 51 in `R/ebay_integration.R`)
**Environment:** Sandbox (`EBAY_ENVIRONMENT=sandbox`)
**Credentials:** Sandbox credentials in `.Renviron`

## Goals

1. Switch from sandbox to production eBay environment
2. Configure production OAuth with proper RuName
3. Set up eBay business policies (fetch from user's existing policies)
4. Update location to Romania
5. Enable real listing creation on eBay.com
6. Ensure all seller details are fetched from eBay account

## Business Policy Integration

### What Are Business Policies?

eBay business policies are pre-configured templates that sellers create once in their eBay Seller Hub:

1. **Payment Policy**: Accepted payment methods (PayPal, credit cards, etc.)
2. **Return Policy**: Return period, who pays shipping, refund method
3. **Shipping/Fulfillment Policy**: Shipping methods, costs, handling time, locations

### How They Work in Production

**YES - All seller details are fetched automatically from existing eBay policies!**

When you configure business policies:
1. Seller creates policies ONCE in eBay Seller Hub (https://www.ebay.com/sh/buspolicy)
2. Each policy gets a unique Policy ID
3. App stores these Policy IDs in `.Renviron`
4. When creating a listing, app just references the Policy IDs
5. **eBay automatically applies all the details from those policies** (shipping costs, return terms, payment methods, etc.)

**Seller does NOT need to re-enter details in the app!**

### What Gets Fetched Automatically

When you reference a business policy by ID, eBay automatically includes:

**From Fulfillment Policy:**
- Shipping service (USPS, FedEx, etc.)
- Shipping cost
- Handling time (1 day, 2 days, etc.)
- Free shipping options
- International shipping rules
- Package dimensions/weight handling

**From Payment Policy:**
- Accepted payment methods
- PayPal email
- Immediate payment requirements
- Payment instructions

**From Return Policy:**
- Return acceptance (yes/no)
- Return period (14, 30, 60 days)
- Who pays return shipping
- Refund method
- Restocking fees

### Seller Setup (One-Time)

The seller creates these policies ONCE in their eBay account:

1. Go to https://www.ebay.com/sh/buspolicy
2. Create "Payment Policy" - select payment methods, set terms
3. Create "Return Policy" - set return period, conditions
4. Create "Fulfillment Policy" - set shipping methods, costs, locations
5. Copy the Policy IDs

Then in `.Renviron`:
```
EBAY_FULFILLMENT_POLICY_ID=123456789
EBAY_PAYMENT_POLICY_ID=987654321
EBAY_RETURN_POLICY_ID=456789123
```

**That's it!** All future listings automatically use those policies.

## Tasks

### 1. Production OAuth Setup

**Create Production RuName:**
- [ ] Go to https://developer.ebay.com/my/keys
- [ ] Switch to Production environment
- [ ] Navigate to "User Tokens" section
- [ ] Click "Add eBay Redirect URL"
- [ ] Fill out form:
  - Display Title: "Delcampe Production OAuth"
  - Privacy Policy URL: (your actual privacy policy URL or placeholder)
  - Auth Accepted URL: (eBay default is fine for production)
  - Auth Declined URL: (eBay default is fine for production)
  - **Select: OAuth (NOT Auth'n'Auth)**
- [ ] Save and copy the generated RuName

**Update `.Renviron`:**
```env
# Switch to production
EBAY_ENVIRONMENT=production

# Production OAuth RuName
EBAY_PROD_REDIRECT_URI=<your_production_runame_here>
```

### 2. Business Policy Configuration

**Seller Actions (One-Time Setup):**

1. **Create Payment Policy:**
   - [ ] Go to https://www.ebay.com/sh/buspolicy
   - [ ] Click "Create policy" under Payment
   - [ ] Name: "Delcampe Standard Payment"
   - [ ] Select accepted payment methods (PayPal, credit cards)
   - [ ] Set payment terms
   - [ ] Save and copy Policy ID

2. **Create Return Policy:**
   - [ ] Click "Create policy" under Returns
   - [ ] Name: "Delcampe Returns"
   - [ ] Set return acceptance: Yes/No
   - [ ] Return period: 14, 30, or 60 days
   - [ ] Who pays return shipping: Buyer/Seller
   - [ ] Refund method
   - [ ] Save and copy Policy ID

3. **Create Fulfillment Policy:**
   - [ ] Click "Create policy" under Shipping
   - [ ] Name: "Delcampe Shipping"
   - [ ] Handling time: 1-3 business days
   - [ ] Domestic shipping:
     - Service: Choose shipping method (e.g., "Economy Shipping from outside US")
     - Cost: Set shipping price
   - [ ] International shipping: Enable/disable, set rates
   - [ ] Item location: Romania
   - [ ] Save and copy Policy ID

**Update `.Renviron`:**
```env
EBAY_FULFILLMENT_POLICY_ID=<fulfillment_policy_id>
EBAY_PAYMENT_POLICY_ID=<payment_policy_id>
EBAY_RETURN_POLICY_ID=<return_policy_id>
```

**Important:** These policies can be managed and updated anytime in eBay Seller Hub. Changes to policies automatically apply to future listings using those Policy IDs.

### 3. Update Location to Romania

**File:** `R/ebay_integration.R`
**Lines:** 50-52

**Current (Sandbox):**
```r
address = list(
  country = "US",
  postalCode = "10001"
)
```

**Change to:**
```r
address = list(
  country = "RO",
  postalCode = "010101"  # Or actual postal code
)
```

**Optional Enhancement:**
Consider making this configurable via `.Renviron`:
```env
EBAY_LOCATION_COUNTRY=RO
EBAY_LOCATION_POSTAL_CODE=010101
EBAY_LOCATION_CITY=Bucharest
```

### 4. Production Authorization

**Steps:**
1. [ ] Update all production settings in `.Renviron`
2. [ ] Restart the Shiny app (to load new environment variables)
3. [ ] Navigate to eBay integration section in app
4. [ ] Click "Connect to eBay"
5. [ ] **Sign in with production eBay seller account** (NOT sandbox test user)
6. [ ] Authorize the app
7. [ ] Copy authorization code from redirect URL
8. [ ] Paste code into app
9. [ ] Verify "Connected to eBay API (production environment)" message

### 5. Test Production Listing

**Create Test Listing:**
1. [ ] Select a low-value postcard or test item
2. [ ] Fill in details (or use AI extraction)
3. [ ] Set high price ($999) to prevent accidental sales during testing
4. [ ] Click "Create eBay Listing"
5. [ ] Verify all steps complete:
   - ✅ Inventory location created
   - ✅ Inventory item created
   - ✅ Offer created
   - ✅ **Offer published** (should work in production!)
   - ✅ Listing ID returned
6. [ ] Check listing appears on eBay.com
7. [ ] Verify listing has correct:
   - Title and description
   - Price
   - Shipping policy (from your fulfillment policy)
   - Return policy (from your return policy)
   - Payment methods (from your payment policy)
   - Location shows Romania
8. [ ] End/delete test listing

**If successful:**
- [ ] Set realistic prices
- [ ] Create real listings
- [ ] Monitor first few listings to ensure everything works

### 6. Optional Enhancements

**Fetch Available Policies from eBay:**

Instead of manually copying Policy IDs, implement an API call to fetch available policies:

**File:** `R/ebay_api.R` or new `R/ebay_policies.R`

```r
# Fetch seller's business policies
fetch_seller_policies = function() {
  # GET /sell/account/v1/fulfillment_policy
  # GET /sell/account/v1/payment_policy
  # GET /sell/account/v1/return_policy
  # Return list of available policies with IDs and names
}
```

**Benefits:**
- Seller can select from dropdown in UI
- No need to manually copy Policy IDs
- Policies can be changed without editing .Renviron

**UI Enhancement:**
Add settings page where seller can:
1. Click "Fetch My Policies"
2. Select preferred policies from dropdowns
3. Save selections to database
4. Use selected policies for all listings

**Implementation:**
- Add `mod_ebay_settings.R` Shiny module
- Fetch policies via eBay Account API
- Store selections in `inst/app/data/app_config.rds` or database
- Update listing creation to use selected policies

### 7. Error Handling

**Add Production-Specific Error Messages:**

**File:** `R/ebay_integration.R`

```r
# In create_ebay_listing_from_card function
if (ebay_api$config$environment == "production") {
  # Validate business policies are configured
  if (fulfillment_policy == "" || payment_policy == "" || return_policy == "") {
    error_msg <- paste(
      "Business policies required for production.",
      "Please set up policies at https://www.ebay.com/sh/buspolicy",
      "and add Policy IDs to .Renviron"
    )
    return(list(success = FALSE, error = error_msg))
  }

  # Additional production validations
  # - Verify location is valid
  # - Check listing price is reasonable
  # - Ensure required fields are present
}
```

### 8. Database Updates

**Track Environment in Database:**

**File:** `R/ebay_database_extension.R`

Currently saves `environment` field. Verify it's being used:

```r
# In save_ebay_listing function
environment = ebay_api$config$environment  # "production" or "sandbox"
```

**Add Policy Tracking:**

Consider adding fields to track which policies were used:
```r
fulfillment_policy_id = fulfillment_policy,
payment_policy_id = payment_policy,
return_policy_id = return_policy
```

This helps troubleshoot if listings have issues.

## Configuration Summary

**Complete `.Renviron` for Production:**

```env
# ===== PRODUCTION EBAY CONFIGURATION =====

# Environment
EBAY_ENVIRONMENT=production

# Production Credentials
EBAY_PROD_CLIENT_ID=your_production_app_id_here
EBAY_PROD_CLIENT_SECRET=your_production_cert_id_here
EBAY_PROD_DEV_ID=your_production_dev_id_here

# Production OAuth RuName
EBAY_PROD_REDIRECT_URI=your_production_runame_here

# Business Policy IDs (from https://www.ebay.com/sh/buspolicy)
EBAY_FULFILLMENT_POLICY_ID=123456789
EBAY_PAYMENT_POLICY_ID=987654321
EBAY_RETURN_POLICY_ID=456789123

# Location (Optional - can use hardcoded values)
EBAY_LOCATION_COUNTRY=RO
EBAY_LOCATION_POSTAL_CODE=010101
EBAY_LOCATION_CITY=Bucharest
```

## Prerequisites

**CRITICAL - Must Complete First:**
- [ ] **Multi-Account Support Implementation** (See: `PRP_EBAY_MULTI_ACCOUNT_SANDBOX.md`)
  - Required for tracking which eBay user creates each listing
  - Enables switching between test and production accounts
  - Must be tested in sandbox before production switch

**Why Multi-Account First:**
- Production listings will include eBay username from day one
- Can test production credentials alongside sandbox
- No need to retrofit user tracking later
- Better architecture for multi-storefront sellers

## Implementation Checklist

**Pre-Implementation:**
- [ ] ✅ Multi-account support implemented and tested in sandbox
- [ ] Review current sandbox implementation
- [ ] Document current behavior
- [ ] Backup current `.Renviron`

**Production Setup:**
- [ ] Create production business policies in eBay Seller Hub
- [ ] Create production OAuth RuName
- [ ] Update `.Renviron` with production settings
- [ ] Update location to Romania in code

**Testing:**
- [ ] Restart app with production settings
- [ ] Authorize with production eBay account
- [ ] Create test listing (high price)
- [ ] Verify listing appears on eBay.com
- [ ] Verify all policy details are correct
- [ ] Delete test listing

**Deployment:**
- [ ] Set realistic prices
- [ ] Create real listings
- [ ] Monitor first 5-10 listings
- [ ] Document any issues

**Post-Deployment:**
- [ ] Update documentation
- [ ] Add production usage instructions
- [ ] Consider implementing policy fetching UI

## Key Differences: Sandbox vs Production

| Feature | Sandbox | Production |
|---------|---------|------------|
| Listings appear on | Nowhere (test only) | eBay.com (live!) |
| Business policies | Optional/broken | **Required** |
| Location | Any country works | Must be valid seller location |
| OAuth RuName | Sandbox RuName | Production RuName |
| Credentials | Sandbox keys | Production keys |
| User authorization | Sandbox test user | Real eBay seller account |
| Publish offer | Fails (expected) | Works |
| Cost per listing | Free | eBay insertion fees apply |

## Success Criteria

✅ **Integration Successful When:**
1. Can authorize with production eBay account
2. Can create inventory items
3. Can create offers with business policies
4. **Can publish offers successfully** (this is the key test!)
5. Listings appear on eBay.com
6. Listings show correct shipping/payment/return policies
7. Location shows Romania
8. No errors in listing creation flow

## Rollback Plan

**If Production Issues Occur:**

1. Switch back to sandbox:
   ```env
   EBAY_ENVIRONMENT=sandbox
   ```

2. Restart app

3. Debug issue in sandbox

4. Fix and re-test

5. Switch back to production

## Notes

**Business Policy Benefits:**
- ✅ Seller configures shipping/payment/returns ONCE
- ✅ All listings automatically use those settings
- ✅ Policies can be updated anytime in eBay Seller Hub
- ✅ Changes apply to future listings immediately
- ✅ No need to re-enter details in app for each listing
- ✅ Consistent experience for buyers across all listings

**Policy Management:**
- Policies are managed entirely in eBay Seller Hub
- App only needs to reference Policy IDs
- Seller can have multiple policies and choose which to use
- Policies can be country-specific for international selling

**Location Settings:**
- Must match seller's registered eBay account country
- Used for calculating shipping and import charges
- Shows to buyers in listing details
- Important for international shipping calculations

## Timeline

**Estimated Time:**
- Policy creation: 30 minutes (one-time)
- RuName setup: 10 minutes
- Code updates: 15 minutes
- Testing: 30 minutes
- **Total: ~1.5 hours**

## Support Resources

- eBay Business Policies: https://www.ebay.com/sh/buspolicy
- eBay Developer Portal: https://developer.ebay.com
- API Documentation: https://developer.ebay.com/api-docs/sell/inventory/overview.html
- Seller Hub: https://www.ebay.com/sh/ovw

## Related Files

- `R/ebay_api.R` - OAuth and API client
- `R/ebay_integration.R` - Listing creation logic (location on line 50-52)
- `R/ebay_helpers.R` - Utility functions
- `.Renviron` - Configuration
- `EBAY_INTEGRATION_STATUS.md` - Current status documentation

---

**Summary:** This PRP switches the eBay integration from sandbox testing to live production. Business policies are configured ONCE by the seller in eBay Seller Hub, and all seller details (shipping, payment, returns) are automatically fetched from those policies. The app only needs to reference the Policy IDs. No re-entering of details required!
