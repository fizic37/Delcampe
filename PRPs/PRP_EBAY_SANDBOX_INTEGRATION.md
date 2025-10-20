# PRP: eBay Sandbox Integration for Postcard Listings

name: "eBay Sandbox Integration v1 - Send Postcards to eBay"
description: |
  Integrate eBay sandbox API to enable users to send postcards to eBay marketplace
  with a "Send to eBay" button after AI extraction completes.

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

### Success Criteria

- [ ] eBay OAuth authentication works in Settings tab
- [ ] "Send to eBay" button appears in export section after processing
- [ ] AI-extracted data correctly populates eBay listing fields
- [ ] Listing successfully creates in eBay sandbox
- [ ] Database tracks eBay listing status and IDs
- [ ] User receives clear success/error feedback

## All Needed Context

### Documentation & References

```yaml
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
```

### Known Gotchas

```r
# CRITICAL: httr2 requires |> pipe operator (R 4.1+)
# CRITICAL: OAuth tokens expire after 2 hours - must handle refresh
# CRITICAL: Sandbox has different URL than production
# CRITICAL: Must initialize database tables before use
# CRITICAL: shinyjs must be initialized in app_ui
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
  aspects TEXT,  # JSON
  created_at DATETIME,
  listed_at DATETIME,
  error_message TEXT
)
```

### Implementation Tasks

```yaml
Task 1: EXTEND R/tracking_database.R
  - ADD: initialize_ebay_listings_table() function
  - IMPLEMENT: save_ebay_listing(), get_ebay_listing_for_card()
  - FOLLOW pattern: Existing card_processing functions
  - PLACEMENT: After existing ebay_posts functions

Task 2: CREATE R/ebay_helpers.R
  - IMPLEMENT: map_condition_to_ebay(), generate_sku(), extract_postcard_aspects()
  - FOLLOW pattern: R/utils_helpers.R structure
  - NAMING: snake_case functions
  - PLACEMENT: New file in R/

Task 3: MODIFY R/mod_delcampe_export.R
  - ADD: "Send to eBay" button next to existing export button
  - IMPLEMENT: observeEvent(input$send_to_ebay)
  - FOLLOW pattern: Existing export_delcampe button handler
  - DEPENDENCIES: Receive ebay_api reactive parameter

Task 4: MODIFY R/app_ui.R
  - ADD: eBay Connection panel to Settings navset_card_tab
  - INSERT: bslib::nav_panel("eBay Connection", mod_ebay_auth_ui("ebay_auth"))
  - PLACEMENT: After Tracking panel in Settings

Task 5: MODIFY R/app_server.R
  - INITIALIZE: ebay_api <- mod_ebay_auth_server("ebay_auth")
  - PASS: ebay_api to mod_delcampe_export_server
  - PLACEMENT: After module initialization section

Task 6: CREATE R/ebay_integration.R
  - IMPLEMENT: Main integration logic create_ebay_listing_from_card()
  - COMBINE: AI data retrieval, eBay API calls, database updates
  - ERROR HANDLING: Comprehensive try-catch with user notifications
```

### Implementation Patterns

```r
# Pattern: Adding eBay button to export module
observeEvent(input$send_to_ebay, {
  req(input$send_to_ebay)
  req(ebay_api())
  
  # Check authentication
  if (!ebay_api()$oauth$is_authenticated()) {
    showModal(modalDialog(
      title = "eBay Connection Required",
      "Please connect to eBay in Settings first.",
      footer = modalButton("OK")
    ))
    return()
  }
  
  # Get current card data
  card_id <- get_current_card_id()
  ai_data <- get_ai_extraction_for_card(card_id)
  
  # Create listing with progress
  withProgress(message = "Creating eBay listing...", {
    result <- create_ebay_listing_from_card(
      card_id = card_id,
      ai_data = ai_data,
      ebay_api = ebay_api(),
      session_id = session$token
    )
    
    if (result$success) {
      showNotification("Listing created on eBay!", type = "success")
    } else {
      showNotification(paste("Error:", result$error), type = "error")
    }
  })
})
```

### Integration Points

```yaml
DATABASE:
  - migration: Run initialize_ebay_listings_table() on startup
  - index: CREATE INDEX idx_ebay_listings_card ON ebay_listings(card_id)

CONFIG:
  - add to: .Renviron
  - pattern: EBAY_SANDBOX_CLIENT_ID=your_app_id
            EBAY_SANDBOX_CLIENT_SECRET=your_cert_id

UI:
  - add to: R/app_ui.R Settings tab
  - pattern: bslib::nav_panel("eBay Connection", ...)
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

# Test listing creation
Rscript -e "
  source('R/ebay_integration.R')
  test_listing <- create_test_postcard_listing()
  print(test_listing)
"

# Expected: Successful listing with eBay item ID
```

## Final Validation Checklist

### Technical Validation

- [ ] R CMD check passes without errors
- [ ] All helper functions work correctly
- [ ] Database tables created successfully
- [ ] OAuth flow completes successfully
- [ ] Token refresh works automatically

### Feature Validation

- [ ] "Send to eBay" button appears after processing
- [ ] Button disabled when not authenticated
- [ ] AI data populates eBay fields correctly
- [ ] Listing creates in sandbox environment
- [ ] Success/error messages display properly

### Code Quality

- [ ] Follows existing R/Shiny patterns
- [ ] Proper error handling throughout
- [ ] Database transactions are atomic
- [ ] No hardcoded credentials
- [ ] Logging for debugging

## Anti-Patterns to Avoid

- ❌ Don't store credentials in code - use .Renviron
- ❌ Don't skip OAuth token refresh - tokens expire
- ❌ Don't ignore sandbox limitations - some features unavailable
- ❌ Don't bypass error handling - user needs feedback
- ❌ Don't create duplicate database records - check existing first
- ❌ Don't assume AI data is complete - provide defaults
