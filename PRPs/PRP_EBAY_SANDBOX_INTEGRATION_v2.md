# PRP: eBay Sandbox Integration for Postcard Listings

name: "eBay Sandbox Integration v2 - Send Postcards to eBay with Full API Documentation"
description: |
  Integrate eBay sandbox API to enable users to send postcards to eBay marketplace
  with a "Send to eBay" button after AI extraction completes. Includes comprehensive
  API documentation and field requirements.

---

## Goal

**Feature Goal**: Enable users to list postcards on eBay sandbox directly from the Delcampe app after AI extraction

**Deliverable**: Functional "Send to eBay" button that creates listings using AI-extracted data in eBay sandbox environment

**Success Definition**: User can authenticate with eBay, click "Send to eBay", and see their postcard listed in eBay sandbox with AI-extracted title, description, and price

## User Persona

**Target User**: Postcard seller/collector using Delcampe app

**Use Case**: After processing postcards and extracting details via AI, user wants to list them on eBay marketplace

**User Journey**: 
1. User processes face/verso images
2. AI extracts title, description, condition, price
3. User sees "Send to eBay" button in export section
4. User clicks button → listing created on eBay sandbox
5. User receives confirmation with eBay listing ID
6. User can view listing at `https://sandbox.ebay.com/itm/{listingId}`

**Pain Points Addressed**: Manual re-entry of postcard details on eBay, time-consuming listing process

## Why

- Streamlines postcard selling workflow from processing to marketplace listing
- Leverages existing AI extraction to populate eBay fields automatically
- Reduces manual data entry and potential errors
- Enables multi-channel selling (Delcampe + eBay)

## What

Users will see a "Send to eBay" button after postcard processing that:
- Uses AI-extracted data (title, description, price, condition)
- Creates listing in eBay sandbox environment
- Shows success/error status
- Tracks listing in database
- Provides direct link to view listing on sandbox.ebay.com

### Success Criteria

- [ ] eBay OAuth authentication works in Settings tab
- [ ] "Send to eBay" button appears in export section after processing
- [ ] AI-extracted data correctly populates eBay listing fields
- [ ] All required fields are populated (title, description, image, price, condition)
- [ ] Postcard aspects are correctly mapped (Era, Theme, Original/Reprint)
- [ ] Listing successfully creates in eBay sandbox (category 914)
- [ ] Database tracks eBay listing status and IDs
- [ ] User receives clear success/error feedback with listing URL

## All Needed Context

### Documentation & References

```yaml
- docfile: PRPs/ai_docs/ebay_api_documentation.md
  why: Complete eBay API documentation with required fields, sandbox URLs, postcard aspects
  section: All sections critical - Required Fields, API Call Flow, Postcard Requirements
  critical: Category 914 for postcards, condition mapping, aspect requirements

- url: https://developer.ebay.com/api-docs/sell/inventory/overview.html
  why: Official Inventory API documentation
  critical: Understanding create/update flow for inventory items and offers

- url: https://developer.ebay.com/api-docs/sell/static/inventory/publishing-offers.html  
  why: Complete list of required fields for publishing
  critical: Must have all required fields before publishOffer call

- url: https://sandbox.ebay.com
  why: Sandbox web interface to view test listings
  critical: Verify listings after creation

- file: R/mod_delcampe_export.R
  why: Existing export module where eBay button will be integrated
  pattern: Current export UI structure with accordion panels
  gotcha: Uses bslib::accordion with dynamic panel generation

- file: R/tracking_database.R
  why: Database schema with existing ebay_posts table
  pattern: Three-layer architecture (postal_cards → card_processing → session_activity)
  gotcha: Already has ebay_posts table but needs ebay_listings for full tracking

- file: R/mod_ai_extraction.R
  why: Shows how AI extraction data is stored and retrieved
  pattern: save_ai_extraction_to_db and get_ai_extraction_for_card functions
  gotcha: Data stored in card_processing table with ai_* fields

- file: R/app_ui.R
  why: Main UI structure to add eBay settings panel
  pattern: Settings tab uses bslib::navset_card_tab
  gotcha: Settings already has General and Tracking panels

- file: R/app_server.R
  why: Main server where modules are initialized
  pattern: Module initialization and reactive data passing
  gotcha: Need to pass ebay_api reactive to export module

- file: R/ebay_api.R
  why: Already created eBay API integration
  pattern: R6 classes for API config, OAuth, and inventory
  gotcha: Uses httr2 for HTTP requests, handles token refresh

- file: .Renviron
  why: Stores eBay credentials securely
  pattern: Environment variables for API keys
  gotcha: Must restart R after updating

- file: inst/golem-config.yml
  why: Golem configuration with eBay settings
  pattern: Nested YAML structure for environments
  gotcha: Different settings for dev/production
```

### Current Codebase Structure

```bash
R/
├── app_ui.R                      # Main UI with Settings tab
├── app_server.R                   # Main server initialization
├── mod_delcampe_export.R         # Export module (needs eBay button)
├── mod_postal_card_processor.R   # Processing module
├── mod_ai_extraction.R           # AI extraction module
├── tracking_database.R           # Database with ebay_posts table
├── ebay_api.R                    # eBay API integration (created)
├── mod_ebay_auth.R               # eBay auth module (created)
├── mod_ebay_postcard.R           # eBay postcard module (created)
└── ebay_database_extension.R     # eBay database functions (created)
```

### Desired Structure with New Files

```bash
R/
├── app_ui.R                      # MODIFY: Add eBay panel to Settings
├── app_server.R                   # MODIFY: Initialize eBay API
├── mod_delcampe_export.R         # MODIFY: Add "Send to eBay" button
├── ebay_helpers.R                # CREATE: Helper functions (condition mapping, SKU generation)
└── ebay_integration.R            # CREATE: Main integration logic

PRPs/ai_docs/
└── ebay_api_documentation.md     # CREATED: Complete API documentation
```

### Known Gotchas

```r
# CRITICAL: httr2 requires |> pipe operator (R 4.1+)
# CRITICAL: OAuth tokens expire after 2 hours - must handle refresh
# CRITICAL: Sandbox has different URL than production
# CRITICAL: Must initialize database tables before use
# CRITICAL: shinyjs must be initialized in app_ui
# CRITICAL: Category 914 is for postcards
# CRITICAL: Price must be string with 2 decimal places ("9.99")
# CRITICAL: At least one image URL required
# CRITICAL: Business policies must exist in eBay account
```

## Implementation Blueprint

### Data Models and Structure

```r
# Database extension (already exists in ebay_posts, enhance with ebay_listings)
CREATE TABLE IF NOT EXISTS ebay_listings (
  listing_id INTEGER PRIMARY KEY,
  card_id INTEGER,
  session_id TEXT,
  ebay_item_id TEXT,
  ebay_offer_id TEXT,
  sku TEXT UNIQUE,
  status TEXT DEFAULT 'draft',
  environment TEXT DEFAULT 'sandbox',
  title TEXT,
  description TEXT,
  price REAL,
  condition TEXT,
  aspects TEXT,  # JSON with Era, Theme, etc.
  created_at DATETIME,
  listed_at DATETIME,
  error_message TEXT
)

# Required eBay API structures (from documentation)
InventoryItem: {
  sku: "PC-001",
  product: {
    title: "max 80 chars",
    description: "max 4000 chars, HTML allowed",
    imageUrls: ["required array"],
    aspects: {
      "Type": ["Postcard"],
      "Era": ["1940-1959"],
      "Theme": ["Travel"],
      "Original/Licensed Reprint": ["Original"],
      "Posted/Unposted": ["Unposted"]
    }
  },
  condition: "USED_EXCELLENT",
  availability: {
    shipToLocationAvailability: {
      quantity: 1
    }
  }
}

Offer: {
  sku: "PC-001",
  marketplaceId: "EBAY_US",
  format: "FIXED_PRICE",
  categoryId: "914",  # Postcards category
  pricingSummary: {
    price: {
      currency: "USD",
      value: "9.99"  # String with 2 decimals
    }
  },
  listingPolicies: {
    fulfillmentPolicyId: "required",
    paymentPolicyId: "required",
    returnPolicyId: "required"
  }
}
```

### Implementation Tasks

```yaml
Task 1: EXTEND R/tracking_database.R
  - ADD: initialize_ebay_listings_table() function
  - IMPLEMENT: save_ebay_listing(), get_ebay_listing_for_card()
  - FOLLOW pattern: Existing card_processing functions
  - PLACEMENT: After existing ebay_posts functions
  - VALIDATE: Table has all required fields from API docs

Task 2: CREATE R/ebay_helpers.R
  - IMPLEMENT: map_condition_to_ebay() - map AI conditions to eBay codes
  - IMPLEMENT: generate_sku() - create unique SKU from card_id
  - IMPLEMENT: extract_postcard_aspects() - map AI data to eBay aspects
  - IMPLEMENT: validate_required_fields() - check all required fields present
  - FOLLOW pattern: R/utils_helpers.R structure
  - CRITICAL: Must handle all eBay condition codes and aspect values

Task 3: MODIFY R/mod_delcampe_export.R
  - ADD: "Send to eBay" button next to existing export button
  - IMPLEMENT: observeEvent(input$send_to_ebay)
  - CHECK: Authentication status before allowing send
  - RETRIEVE: AI data from card_processing table
  - VALIDATE: All required fields present
  - FOLLOW pattern: Existing export_delcampe button handler

Task 4: MODIFY R/app_ui.R
  - ADD: eBay Connection panel to Settings navset_card_tab
  - INSERT: bslib::nav_panel("eBay Connection", mod_ebay_auth_ui("ebay_auth"))
  - PLACEMENT: After Tracking panel in Settings
  - ENSURE: OAuth flow UI is user-friendly

Task 5: MODIFY R/app_server.R
  - INITIALIZE: ebay_api <- mod_ebay_auth_server("ebay_auth")
  - PASS: ebay_api to mod_delcampe_export_server as parameter
  - ENSURE: Reactive chain properly connected
  - PLACEMENT: After module initialization section

Task 6: CREATE R/ebay_integration.R
  - IMPLEMENT: create_ebay_listing_from_card() main function
  - FLOW: Create location → Create inventory → Create offer → Publish
  - ERROR HANDLING: Comprehensive try-catch with specific error messages
  - RETURN: Success with listing URL or error with message
  - CRITICAL: Follow exact API call sequence from documentation
```

### Implementation Patterns

```r
# Pattern: Complete eBay listing creation flow
create_ebay_listing_from_card <- function(card_id, ai_data, ebay_api, session_id) {
  
  # Step 1: Validate required fields
  validation <- validate_required_fields(ai_data)
  if (!validation$valid) {
    return(list(success = FALSE, error = validation$message))
  }
  
  # Step 2: Create/verify location (one-time)
  if (!location_exists(ebay_api, "default_location")) {
    location_result <- ebay_api$inventory$create_location(
      merchant_location_key = "default_location",
      location_data = list(
        location = list(
          address = list(
            country = "US",
            postalCode = "10001"
          )
        ),
        locationTypes = list("WAREHOUSE")
      )
    )
  }
  
  # Step 3: Create inventory item with all required fields
  sku <- generate_sku(card_id)
  inventory_data <- list(
    product = list(
      title = substr(ai_data$title, 1, 80),  # Max 80 chars
      description = ai_data$description,
      imageUrls = list("https://placeholder.com/image.jpg"),  # TODO: Real image
      aspects = extract_postcard_aspects(ai_data)
    ),
    condition = map_condition_to_ebay(ai_data$condition),
    availability = list(
      shipToLocationAvailability = list(
        quantity = 1
      )
    )
  )
  
  inventory_result <- ebay_api$inventory$create_inventory_item(sku, inventory_data)
  
  # Step 4: Create offer with required policies
  offer_data <- list(
    sku = sku,
    marketplaceId = "EBAY_US",
    format = "FIXED_PRICE",
    categoryId = "914",  # Postcards
    pricingSummary = list(
      price = list(
        currency = "USD",
        value = format_ebay_price(ai_data$price)
      )
    ),
    listingPolicies = list(
      fulfillmentPolicyId = Sys.getenv("EBAY_FULFILLMENT_POLICY_ID"),
      paymentPolicyId = Sys.getenv("EBAY_PAYMENT_POLICY_ID"),
      returnPolicyId = Sys.getenv("EBAY_RETURN_POLICY_ID")
    ),
    merchantLocationKey = "default_location"
  )
  
  offer_result <- ebay_api$inventory$create_offer(offer_data)
  
  # Step 5: Publish offer
  if (offer_result$success) {
    publish_result <- ebay_api$inventory$publish_offer(offer_result$offer_id)
    
    # Step 6: Save to database
    save_ebay_listing(
      card_id = card_id,
      session_id = session_id,
      ebay_item_id = publish_result$listing_id,
      ebay_offer_id = offer_result$offer_id,
      sku = sku,
      status = "listed",
      title = inventory_data$product$title,
      description = inventory_data$product$description,
      price = ai_data$price,
      condition = inventory_data$condition,
      aspects = inventory_data$product$aspects
    )
    
    return(list(
      success = TRUE,
      listing_id = publish_result$listing_id,
      listing_url = paste0("https://sandbox.ebay.com/itm/", publish_result$listing_id)
    ))
  }
  
  return(list(success = FALSE, error = offer_result$error))
}
```

### Integration Points

```yaml
DATABASE:
  - migration: Run initialize_ebay_listings_table() on startup
  - index: CREATE INDEX idx_ebay_listings_card ON ebay_listings(card_id)

CONFIG:
  - add to: .Renviron
  - pattern: |
    EBAY_SANDBOX_CLIENT_ID=your_app_id
    EBAY_SANDBOX_CLIENT_SECRET=your_cert_id
    EBAY_FULFILLMENT_POLICY_ID=your_policy_id
    EBAY_PAYMENT_POLICY_ID=your_policy_id
    EBAY_RETURN_POLICY_ID=your_policy_id

UI:
  - add to: R/app_ui.R Settings tab
  - pattern: bslib::nav_panel("eBay Connection", ...)

SANDBOX:
  - test users: Create TESTUSER_seller and TESTUSER_buyer
  - view listings: https://sandbox.ebay.com/sch/i.html?_nkw=postcard
```

## Validation Loop

### Level 1: Syntax & Style

```bash
# Check R syntax
R CMD check .

# Run lintr for style
Rscript -e "lintr::lint_package()"

# Expected: No errors or warnings
```

### Level 2: Unit Tests

```bash
# Test database functions
Rscript -e "testthat::test_file('tests/testthat/test-ebay-database.R')"

# Test helper functions
Rscript -e "testthat::test_file('tests/testthat/test-ebay-helpers.R')"

# Test field validation
Rscript -e "
  source('R/ebay_helpers.R')
  # Test required fields validation
  test_data <- list(title='Test', price=9.99)
  validation <- validate_required_fields(test_data)
  print(validation)
"

# Expected: All tests pass
```

### Level 3: Integration Testing

```bash
# Start Shiny app
Rscript -e "shiny::runApp()"

# Manual validation steps:
# 1. Go to Settings > eBay Connection
# 2. Click "Connect to eBay"
# 3. Complete OAuth flow
# 4. Process a postcard image
# 5. Click "Send to eBay" button
# 6. Verify listing created in sandbox

# Check database
sqlite3 inst/app/data/tracking.sqlite "SELECT * FROM ebay_listings;"

# Expected: New listing record with status='listed'
```

### Level 4: eBay Sandbox Validation

```bash
# Verify OAuth token
Rscript -e "
  source('R/ebay_api.R')
  api <- init_ebay_api('sandbox')
  print(api$oauth$is_authenticated())
"

# Test complete listing flow
Rscript -e "
  source('R/ebay_integration.R')
  test_ai_data <- list(
    title = 'Vintage Paris Postcard 1950s',
    description = 'Beautiful vintage postcard of Eiffel Tower',
    price = 9.99,
    condition = 'Excellent'
  )
  result <- create_ebay_listing_from_card(
    card_id = 1,
    ai_data = test_ai_data,
    ebay_api = init_ebay_api('sandbox'),
    session_id = 'test_session'
  )
  print(result)
  # Should return: list(success=TRUE, listing_id='...', listing_url='https://sandbox.ebay.com/itm/...')
"

# Verify listing on sandbox
# Open browser to: https://sandbox.ebay.com
# Search for your postcard title
# Or go directly to: https://sandbox.ebay.com/itm/{listing_id}

# Expected: Postcard visible with correct title, price, description, aspects
```

## Final Validation Checklist

### Technical Validation

- [ ] R CMD check passes without errors
- [ ] All helper functions work correctly
- [ ] Database tables created successfully
- [ ] OAuth flow completes successfully
- [ ] Token refresh works automatically
- [ ] All required eBay fields populated

### Feature Validation

- [ ] "Send to eBay" button appears after processing
- [ ] Button disabled when not authenticated
- [ ] AI data populates eBay fields correctly
- [ ] Title limited to 80 characters
- [ ] Price formatted as string with 2 decimals
- [ ] Postcard aspects correctly mapped (Era, Theme, etc.)
- [ ] Category 914 used for postcards
- [ ] Listing creates in sandbox environment
- [ ] Listing URL returned and clickable
- [ ] Success/error messages display properly
- [ ] Database record created with all fields

### eBay API Compliance

- [ ] All required fields from API documentation present
- [ ] Condition codes match eBay's allowed values
- [ ] Aspects follow postcard category requirements
- [ ] Business policy IDs are valid
- [ ] Image URLs are accessible
- [ ] OAuth scope is correct (sell.inventory)

### Code Quality

- [ ] Follows existing R/Shiny patterns
- [ ] Proper error handling throughout
- [ ] Database transactions are atomic
- [ ] No hardcoded credentials
- [ ] Logging for debugging
- [ ] Field validation before API calls

## Anti-Patterns to Avoid

- ❌ Don't store credentials in code - use .Renviron
- ❌ Don't skip OAuth token refresh - tokens expire after 2 hours
- ❌ Don't ignore sandbox limitations - some features unavailable
- ❌ Don't bypass error handling - user needs feedback
- ❌ Don't create duplicate database records - check existing first
- ❌ Don't assume AI data is complete - provide defaults
- ❌ Don't exceed field limits - title 80 chars, description 4000 chars
- ❌ Don't use wrong category - must be 914 for postcards
- ❌ Don't format price incorrectly - must be string "9.99" not numeric
- ❌ Don't skip required fields - will fail at publish step
