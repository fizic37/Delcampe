# TASK PRP: eBay Sandbox Integration - Comprehensive Implementation

## Task Overview

**Goal**: Enable users to list postcards on eBay sandbox directly from the Delcampe app after AI extraction

**Source PRP**: `PRPs/PRP_EBAY_SANDBOX_INTEGRATION_v2.md`

**Success Criteria**:
- ✅ OAuth authentication works in Settings > eBay Connection
- ✅ "Send to eBay" button appears in export accordion panels
- ✅ AI-extracted data populates eBay listing fields
- ✅ Listing creates successfully in eBay sandbox (category 914)
- ✅ Database tracks eBay listing status
- ✅ User receives listing URL: `https://sandbox.ebay.com/itm/{listingId}`

---

## Context & Documentation

### Critical Documentation
```yaml
api_docs: PRPs/ai_docs/ebay_api_documentation.md
  sections:
    - Required Fields for Postcard Listings
    - API Call Flow (4 steps: location → inventory → offer → publish)
    - Postcard-Specific Requirements (category 914, aspects, conditions)
    - OAuth Scopes Required
    - Error Codes and Troubleshooting

official_docs: https://developer.ebay.com/api-docs/sell/inventory/overview.html
  focus: Complete inventory API flow and field requirements
```

### Existing Implementation (DO NOT RECREATE)
```yaml
completed_files:
  - R/ebay_api.R: Full API client (EbayAPIConfig, EbayOAuth, EbayInventoryAPI)
  - R/mod_ebay_auth.R: OAuth UI/server module with token management
  - R/ebay_database_extension.R: Database schema and CRUD functions
  - R/mod_ebay_postcard.R: Postcard-specific module (exists but not integrated)

working_features:
  - OAuth token generation and refresh (2-hour expiry handled)
  - Inventory item creation (PUT /inventory_item/{sku})
  - Offer creation (POST /offer)
  - Offer publishing (POST /offer/{id}/publish)
  - Location management
  - Database persistence
```

### Integration Patterns to Follow
```yaml
export_module: R/mod_delcampe_export.R
  pattern: |
    - Accordion-based UI with dynamic panels per image
    - AI extraction already integrated with database save
    - Form fields: title, description, price, condition
    - Status tracking: ready/draft/sent/pending/failed

  key_functions:
    - create_accordion_panel(idx, path): Generates panel with form
    - create_form_content(idx, path): Builds form fields
    - convert_web_path_to_file_path(): Maps URLs to file system
    - save_current_draft(): Stores form state

app_ui: R/app_ui.R:104-121
  pattern: |
    Settings tab with bslib::navset_card_tab
    Contains General and Tracking panels
    Need to add: eBay Connection panel

app_server: R/app_server.R:1-100
  pattern: |
    Module initialization at top level
    Reactive data passing between modules
    Need to add: ebay_api reactive from mod_ebay_auth_server
```

### Gotchas & Constraints
```r
# CRITICAL CONSTRAINTS FROM CLAUDE.MD
# 1. Module Design - Use bslib components, NOT custom JavaScript
#    - Custom jQuery onclick handlers FAIL in modules (namespace issues)
#    - Always prefer native Shiny/bslib components

# 2. File Management
#    - NEVER save backups in R/ directory (they get loaded)
#    - Backup location: C:/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/

# 3. R-Python Integration
#    - DO NOT MODIFY existing reticulate setup
#    - Use established patterns only

# 4. Database Architecture
#    - Three-layer: postal_cards → card_processing → session_activity
#    - AI data stored in card_processing table (ai_title, ai_description, etc.)
#    - eBay data in ebay_listings table (already defined)

# 5. eBay API Specifics (from documentation)
#    - Title: Max 80 characters
#    - Price: Must be STRING with 2 decimals ("9.99" not 9.99)
#    - Category: Must be "914" for postcards
#    - Condition: Must use eBay codes (USED_EXCELLENT, USED_GOOD, etc.)
#    - OAuth tokens: Expire after 2 hours (auto-refresh implemented)
#    - At least 1 image URL required (placeholder for now)
```

---

## Task Breakdown

### TASK 1: Create Helper Functions File
**File**: `R/ebay_helpers.R` (NEW)

**Purpose**: Provide reusable utility functions for eBay integration

**Dependencies**: None (pure R functions)

**Implementation**:
```r
#' eBay Helper Functions
#' Utilities for mapping Delcampe data to eBay API requirements

#' Map AI condition strings to eBay condition codes
#' @export
map_condition_to_ebay <- function(condition) {
  # AI extraction uses: "excellent", "good", "fair", "poor", "used"
  condition_map <- list(
    "excellent" = "USED_EXCELLENT",
    "very good" = "USED_VERY_GOOD",
    "good" = "USED_GOOD",
    "fair" = "USED_ACCEPTABLE",
    "poor" = "USED_ACCEPTABLE",
    "used" = "USED_GOOD",  # Default used condition
    "new" = "NEW",
    "like new" = "LIKE_NEW"
  )

  condition_lower <- tolower(trimws(condition))
  ebay_condition <- condition_map[[condition_lower]]

  if (is.null(ebay_condition)) {
    warning("Unknown condition '", condition, "', defaulting to USED_GOOD")
    return("USED_GOOD")
  }

  return(ebay_condition)
}

#' Generate unique SKU from card ID
#' @export
generate_sku <- function(card_id, prefix = "PC") {
  # Format: PC-{card_id}-{timestamp}
  # Example: PC-123-20250115143022
  timestamp <- format(Sys.time(), "%Y%m%d%H%M%S")
  paste0(prefix, "-", card_id, "-", timestamp)
}

#' Extract postcard aspects from AI data
#' @export
extract_postcard_aspects <- function(ai_data) {
  # Return list of eBay aspects for postcards
  # Based on PRPs/ai_docs/ebay_api_documentation.md:79-111
  aspects <- list(
    "Type" = list("Postcard")
  )

  # Try to infer Era from description/title
  # For MVP, use defaults; future enhancement: parse from AI data
  if (!is.null(ai_data$era)) {
    aspects[["Era"]] <- list(ai_data$era)
  } else {
    aspects[["Era"]] <- list("Unknown")
  }

  # Default theme
  aspects[["Theme"]] <- list("Other")

  # Default to original
  aspects[["Original/Licensed Reprint"]] <- list("Original")

  return(aspects)
}

#' Validate required fields for eBay listing
#' @export
validate_required_fields <- function(ai_data, image_url = NULL) {
  errors <- character(0)

  # Required fields per API documentation
  if (is.null(ai_data$title) || nchar(trimws(ai_data$title)) == 0) {
    errors <- c(errors, "Title is required")
  }

  if (is.null(ai_data$description) || nchar(trimws(ai_data$description)) == 0) {
    errors <- c(errors, "Description is required")
  }

  if (is.null(ai_data$price) || !is.numeric(ai_data$price) || ai_data$price <= 0) {
    errors <- c(errors, "Valid price is required")
  }

  if (is.null(ai_data$condition) || nchar(trimws(ai_data$condition)) == 0) {
    errors <- c(errors, "Condition is required")
  }

  if (is.null(image_url) || nchar(trimws(image_url)) == 0) {
    errors <- c(errors, "At least one image URL is required")
  }

  if (length(errors) > 0) {
    return(list(
      valid = FALSE,
      message = paste("Validation errors:", paste(errors, collapse = "; "))
    ))
  }

  return(list(valid = TRUE))
}

#' Format price for eBay API (must be string with 2 decimals)
#' @export
format_ebay_price <- function(price) {
  # eBay requires string like "9.99" not numeric 9.99
  sprintf("%.2f", as.numeric(price))
}
```

**Validation**:
```bash
# Test helper functions
Rscript -e "
  source('R/ebay_helpers.R')

  # Test condition mapping
  cat('Testing condition mapping:\n')
  cat('  excellent ->', map_condition_to_ebay('excellent'), '\n')
  cat('  good ->', map_condition_to_ebay('good'), '\n')
  cat('  unknown ->', map_condition_to_ebay('unknown'), '\n')

  # Test SKU generation
  cat('\nTesting SKU generation:\n')
  sku <- generate_sku(123)
  cat('  SKU:', sku, '\n')
  cat('  Length:', nchar(sku), '\n')

  # Test price formatting
  cat('\nTesting price formatting:\n')
  cat('  9.99 ->', format_ebay_price(9.99), '\n')
  cat('  10 ->', format_ebay_price(10), '\n')
  cat('  9.995 ->', format_ebay_price(9.995), '\n')

  # Test validation
  cat('\nTesting validation:\n')
  test_data <- list(title='Test', description='Desc', price=9.99, condition='good')
  result <- validate_required_fields(test_data, 'http://image.jpg')
  cat('  Valid:', result\$valid, '\n')

  invalid_data <- list(title='', description='Desc', price=0, condition='good')
  result2 <- validate_required_fields(invalid_data, NULL)
  cat('  Invalid:', result2\$valid, '\n')
  cat('  Errors:', result2\$message, '\n')
"
```

**Rollback**: Delete `R/ebay_helpers.R`

---

### TASK 2: Create Main Integration Function
**File**: `R/ebay_integration.R` (NEW)

**Purpose**: Orchestrate complete eBay listing creation flow

**Dependencies**:
- `R/ebay_api.R` (existing)
- `R/ebay_helpers.R` (Task 1)
- `R/ebay_database_extension.R` (existing)
- `R/tracking_database.R` (existing - for card_id lookup)

**Implementation**:
```r
#' eBay Integration Functions
#' Main orchestration for creating eBay listings from Delcampe data

#' Create eBay listing from card data
#'
#' Complete flow: location → inventory item → offer → publish
#'
#' @param card_id Card ID from postal_cards table
#' @param ai_data List with title, description, price, condition
#' @param ebay_api eBay API object from init_ebay_api()
#' @param session_id Shiny session ID for tracking
#' @param image_url Image URL for listing (temporary placeholder OK for sandbox)
#'
#' @return List with success, listing_id, listing_url, or error
#' @export
create_ebay_listing_from_card <- function(card_id, ai_data, ebay_api, session_id, image_url = NULL) {

  cat("\n=== CREATING EBAY LISTING ===\n")
  cat("   Card ID:", card_id, "\n")
  cat("   Session:", session_id, "\n")

  # Step 1: Validate required fields
  cat("\n1. Validating required fields...\n")

  # Use placeholder image if none provided (for sandbox testing)
  if (is.null(image_url)) {
    image_url <- "https://via.placeholder.com/500x350.png?text=Postcard"
    cat("   Using placeholder image\n")
  }

  validation <- validate_required_fields(ai_data, image_url)
  if (!validation$valid) {
    cat("   ❌ Validation failed:", validation$message, "\n")
    return(list(success = FALSE, error = validation$message))
  }
  cat("   ✅ All required fields present\n")

  # Step 2: Check/create location (one-time setup)
  cat("\n2. Checking inventory location...\n")
  location_key <- "default_location"

  # For simplicity, assume location exists or create on first run
  # In production, would check if location exists first
  location_result <- tryCatch({
    ebay_api$inventory$create_location(
      merchant_location_key = location_key,
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
  }, error = function(e) {
    # Location might already exist, that's OK
    list(success = TRUE)
  })

  cat("   ✅ Location ready:", location_key, "\n")

  # Step 3: Create inventory item
  cat("\n3. Creating inventory item...\n")

  sku <- generate_sku(card_id)
  cat("   SKU:", sku, "\n")

  # Truncate title to 80 chars (eBay limit)
  title_truncated <- substr(trimws(ai_data$title), 1, 80)
  cat("   Title:", title_truncated, "\n")

  inventory_data <- list(
    product = list(
      title = title_truncated,
      description = ai_data$description,
      imageUrls = list(image_url),
      aspects = extract_postcard_aspects(ai_data)
    ),
    condition = map_condition_to_ebay(ai_data$condition),
    availability = list(
      shipToLocationAvailability = list(
        quantity = 1
      )
    )
  )

  cat("   Condition:", inventory_data$condition, "\n")
  cat("   Calling API: PUT /inventory_item/", sku, "\n")

  inventory_result <- ebay_api$inventory$create_inventory_item(sku, inventory_data)

  if (!inventory_result$success) {
    error_msg <- paste("Failed to create inventory item:", inventory_result$error)
    cat("   ❌", error_msg, "\n")
    return(list(success = FALSE, error = error_msg))
  }
  cat("   ✅ Inventory item created\n")

  # Step 4: Create offer
  cat("\n4. Creating offer...\n")

  # Get business policy IDs from environment
  fulfillment_policy <- Sys.getenv("EBAY_FULFILLMENT_POLICY_ID")
  payment_policy <- Sys.getenv("EBAY_PAYMENT_POLICY_ID")
  return_policy <- Sys.getenv("EBAY_RETURN_POLICY_ID")

  # Check if policies are configured
  if (fulfillment_policy == "" || payment_policy == "" || return_policy == "") {
    error_msg <- "Business policies not configured in .Renviron. Please set EBAY_FULFILLMENT_POLICY_ID, EBAY_PAYMENT_POLICY_ID, EBAY_RETURN_POLICY_ID"
    cat("   ❌", error_msg, "\n")
    return(list(success = FALSE, error = error_msg))
  }

  offer_data <- list(
    sku = sku,
    marketplaceId = "EBAY_US",
    format = "FIXED_PRICE",
    categoryId = "914",  # Postcards category
    pricingSummary = list(
      price = list(
        currency = "USD",
        value = format_ebay_price(ai_data$price)
      )
    ),
    listingPolicies = list(
      fulfillmentPolicyId = fulfillment_policy,
      paymentPolicyId = payment_policy,
      returnPolicyId = return_policy
    ),
    merchantLocationKey = location_key
  )

  cat("   Price:", offer_data$pricingSummary$price$value, "USD\n")
  cat("   Category: 914 (Postcards)\n")
  cat("   Calling API: POST /offer\n")

  offer_result <- ebay_api$inventory$create_offer(offer_data)

  if (!offer_result$success) {
    error_msg <- paste("Failed to create offer:", offer_result$error)
    cat("   ❌", error_msg, "\n")
    return(list(success = FALSE, error = error_msg))
  }
  cat("   ✅ Offer created, ID:", offer_result$offer_id, "\n")

  # Step 5: Publish offer
  cat("\n5. Publishing offer...\n")
  cat("   Calling API: POST /offer/", offer_result$offer_id, "/publish\n")

  publish_result <- ebay_api$inventory$publish_offer(offer_result$offer_id)

  if (!publish_result$success) {
    error_msg <- paste("Failed to publish offer:", publish_result$error)
    cat("   ❌", error_msg, "\n")
    return(list(success = FALSE, error = error_msg))
  }
  cat("   ✅ Offer published, listing ID:", publish_result$listing_id, "\n")

  # Step 6: Save to database
  cat("\n6. Saving to database...\n")

  save_success <- save_ebay_listing(
    card_id = card_id,
    session_id = session_id,
    ebay_item_id = publish_result$listing_id,
    ebay_offer_id = offer_result$offer_id,
    sku = sku,
    status = "listed",
    title = title_truncated,
    description = ai_data$description,
    price = ai_data$price,
    condition = inventory_data$condition,
    aspects = inventory_data$product$aspects,
    environment = ebay_api$config$environment
  )

  if (!save_success) {
    cat("   ⚠️ Database save failed (non-fatal)\n")
  } else {
    cat("   ✅ Database record created\n")
  }

  # Build listing URL
  listing_url <- if (ebay_api$config$environment == "sandbox") {
    paste0("https://sandbox.ebay.com/itm/", publish_result$listing_id)
  } else {
    paste0("https://www.ebay.com/itm/", publish_result$listing_id)
  }

  cat("\n=== LISTING CREATED SUCCESSFULLY ===\n")
  cat("   URL:", listing_url, "\n\n")

  return(list(
    success = TRUE,
    listing_id = publish_result$listing_id,
    offer_id = offer_result$offer_id,
    sku = sku,
    listing_url = listing_url
  ))
}
```

**Validation**:
```bash
# Test with mock data (requires eBay credentials in .Renviron)
Rscript -e "
  source('R/ebay_api.R')
  source('R/ebay_helpers.R')
  source('R/ebay_integration.R')
  source('R/ebay_database_extension.R')

  # Initialize API
  api <- init_ebay_api('sandbox')

  # Check authentication
  if (!api\$oauth\$is_authenticated()) {
    cat('❌ Not authenticated. Run OAuth flow first.\n')
    quit(status = 1)
  }

  cat('✅ Authenticated\n')

  # Test data
  test_data <- list(
    title = 'Vintage Paris Postcard 1950s - Test Listing',
    description = 'Beautiful vintage postcard of the Eiffel Tower. This is a test listing from the Delcampe integration.',
    price = 9.99,
    condition = 'excellent'
  )

  # Create test listing
  result <- create_ebay_listing_from_card(
    card_id = 9999,  # Test card ID
    ai_data = test_data,
    ebay_api = api,
    session_id = 'test_session',
    image_url = 'https://via.placeholder.com/500x350.png?text=Test+Postcard'
  )

  if (result\$success) {
    cat('\n✅ TEST PASSED\n')
    cat('   Listing ID:', result\$listing_id, '\n')
    cat('   URL:', result\$listing_url, '\n')
    cat('\nVisit the URL to verify listing in sandbox\n')
  } else {
    cat('\n❌ TEST FAILED\n')
    cat('   Error:', result\$error, '\n')
    quit(status = 1)
  }
"
```

**Rollback**: Delete `R/ebay_integration.R`

---

### TASK 3: Initialize Database Table
**File**: `R/tracking_database.R` (MODIFY)

**Purpose**: Ensure ebay_listings table is created on app startup

**Location**: Add to existing `initialize_tracking_db()` function

**Pattern**: Follow existing table creation pattern (R/tracking_database.R:15-200)

**Implementation**:
```r
# In initialize_tracking_db() function, add after existing table creation:

# eBay Listings table
DBI::dbExecute(con, "
  CREATE TABLE IF NOT EXISTS ebay_listings (
    listing_id INTEGER PRIMARY KEY AUTOINCREMENT,
    card_id INTEGER,
    session_id TEXT NOT NULL,
    ebay_item_id TEXT,
    ebay_offer_id TEXT,
    sku TEXT UNIQUE NOT NULL,
    status TEXT DEFAULT 'draft',
    environment TEXT DEFAULT 'sandbox',
    title TEXT,
    description TEXT,
    price REAL,
    quantity INTEGER DEFAULT 1,
    condition TEXT,
    category_id TEXT DEFAULT '914',
    listing_url TEXT,
    image_urls TEXT,
    aspects TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    listed_at DATETIME,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
    error_message TEXT,
    FOREIGN KEY (card_id) REFERENCES postal_cards(card_id),
    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
  )
")

# Create indexes for ebay_listings
DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_card ON ebay_listings(card_id)")
DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_session ON ebay_listings(session_id)")
DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_status ON ebay_listings(status)")
DBI::dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ebay_listings_sku ON ebay_listings(sku)")

message("  ✅ eBay listings table initialized")
```

**Validation**:
```bash
# Check table creation
sqlite3 inst/app/data/tracking.sqlite "
  SELECT name, sql
  FROM sqlite_master
  WHERE type='table' AND name='ebay_listings';
"

# Check indexes
sqlite3 inst/app/data/tracking.sqlite "
  SELECT name
  FROM sqlite_master
  WHERE type='index' AND tbl_name='ebay_listings';
"
```

**Rollback**:
```sql
DROP TABLE IF EXISTS ebay_listings;
DROP INDEX IF EXISTS idx_ebay_listings_card;
DROP INDEX IF EXISTS idx_ebay_listings_session;
DROP INDEX IF EXISTS idx_ebay_listings_status;
DROP INDEX IF EXISTS idx_ebay_listings_sku;
```

---

### TASK 4: Add eBay Panel to Settings UI
**File**: `R/app_ui.R` (MODIFY)

**Location**: Lines 104-121 (Settings tab with navset_card_tab)

**Change Type**: ADD new nav_panel for eBay Connection

**Pattern**: Follow existing panel structure (General, Tracking)

**Implementation**:
```r
# MODIFY R/app_ui.R lines 104-121
# ADD new eBay Connection panel after Tracking panel

# Settings Tab with Tracking Integration
bslib::nav_panel(
  "Settings",
  icon = icon("cog"),

  # Settings content with integrated tracking
  bslib::navset_card_tab(
    bslib::nav_panel(
      title = "General",
      mod_settings_ui("settings")
    ),
    bslib::nav_panel(
      title = "Tracking",
      # Tracking module integrated into settings
      mod_tracking_viewer_ui("tracking_viewer_1")
    ),
    # NEW: eBay Connection panel
    bslib::nav_panel(
      title = "eBay Connection",
      icon = icon("shopping-cart"),
      mod_ebay_auth_ui("ebay_auth")
    )
  )
),
```

**Validation**:
```bash
# Start app and verify UI
Rscript -e "shiny::runApp()"

# Manual checks:
# 1. Navigate to Settings tab
# 2. Verify "eBay Connection" tab appears
# 3. Click tab - should show OAuth UI
# 4. Verify "Connect to eBay" button present
```

**Rollback**: Remove the added `bslib::nav_panel` block for eBay Connection

---

### TASK 5: Initialize eBay API in App Server
**File**: `R/app_server.R` (MODIFY)

**Location**: After line 242 (after mod_tracking_viewer_server)

**Change Type**: ADD eBay auth module initialization

**Pattern**: Follow existing module initialization pattern

**Implementation**:
```r
# MODIFY R/app_server.R
# ADD after line 242 (after mod_tracking_viewer_server call)

# eBay Authentication server - returns reactive ebay_api object
ebay_api <- mod_ebay_auth_server("ebay_auth")
```

**Validation**:
```bash
# Start app and check console for initialization
Rscript -e "shiny::runApp()"

# Look for:
# - No errors on startup
# - eBay module loads successfully
```

**Rollback**: Remove the `ebay_api <- mod_ebay_auth_server("ebay_auth")` line

---

### TASK 6: Pass eBay API to Export Module
**File**: `R/app_server.R` (MODIFY)

**Location**: Lines 797-808 (export module initialization)

**Change Type**: ADD ebay_api parameter to export modules

**Pattern**: Reactive parameter passing

**Implementation**:
```r
# MODIFY R/app_server.R lines 797-808
# CHANGE: Add ebay_api parameter to both export modules

# Export modules - must be initialized outside reactive context
mod_delcampe_export_server(
  "lot_export",
  image_paths = reactive(app_rv$lot_paths),
  image_type = "lot",
  ebay_api = ebay_api  # NEW: Pass eBay API
)

mod_delcampe_export_server(
  "combined_export",
  image_paths = reactive(app_rv$combined_paths),
  image_file_paths = reactive(app_rv$combined_file_paths),
  image_type = "combined",
  ebay_api = ebay_api  # NEW: Pass eBay API
)
```

**Validation**:
```bash
# Check for errors on startup
Rscript -e "shiny::runApp()"

# Verify export module receives ebay_api parameter
```

**Rollback**: Remove `ebay_api = ebay_api` from both export module calls

---

### TASK 7: Update Export Module Signature
**File**: `R/mod_delcampe_export.R` (MODIFY)

**Location**: Line 27 (module server function signature)

**Change Type**: ADD ebay_api parameter

**Implementation**:
```r
# MODIFY R/mod_delcampe_export.R line 27
# CHANGE function signature to accept ebay_api

mod_delcampe_export_server <- function(id, image_paths = reactive(NULL), image_file_paths = reactive(NULL), image_type = "combined", ebay_api = reactive(NULL)) {
  moduleServer(id, function(input, output, session) {
    # ... existing code ...
```

**Validation**:
```bash
# No errors on app startup
Rscript -e "shiny::runApp()"
```

**Rollback**: Remove `ebay_api = reactive(NULL)` from function signature

---

### TASK 8: Add Send to eBay Button to Form
**File**: `R/mod_delcampe_export.R` (MODIFY)

**Location**: Line 219 (inside create_form_content function, after condition selector)

**Change Type**: ADD "Send to eBay" button after the action button section

**Pattern**: Follow existing actionButton pattern with bslib styling

**Implementation**:
```r
# MODIFY R/mod_delcampe_export.R
# LOCATE: create_form_content() function
# FIND: Line ~219 where action buttons are (after condition field)
# ADD: New Send to eBay button BEFORE or AFTER existing export button

# Current code has:
# Action button - Send to eBay
fluidRow(
  column(
    12,
    div(
      style = "margin-top: 16px;",
      actionButton(
        ns(paste0("send_to_ebay_", idx)),
        "Send to eBay",
        icon = icon("upload"),
        class = "btn-success",
        style = "width: 100%;"
      )
    )
  )
)

# This already exists! Just need to add the observer.
```

**Note**: The button already exists in the form (line 205-220). We just need to add the event handler.

**Validation**: Visual check - button should appear in accordion panel

**Rollback**: N/A (button already exists)

---

### TASK 9: Implement Send to eBay Handler
**File**: `R/mod_delcampe_export.R` (MODIFY)

**Location**: After line 963 (end of AI extraction observers, before return statement)

**Change Type**: ADD new observeEvent for send_to_ebay buttons

**Pattern**: Follow existing AI extraction observer pattern (lines 600-900)

**Implementation**:
```r
# MODIFY R/mod_delcampe_export.R
# ADD after AI extraction observers (around line 963, before return statement)

# Send to eBay Handlers - Create observers for each image's Send to eBay button
observe({
  req(image_paths())
  paths <- image_paths()

  lapply(seq_along(paths), function(i) {
    observeEvent(input[[paste0("send_to_ebay_", i)]], ignoreNULL = TRUE, ignoreInit = TRUE, {

      cat("\n🎯 Send to eBay button clicked for image", i, "\n")

      # Check authentication
      api <- ebay_api()
      if (is.null(api)) {
        showNotification(
          "eBay API not initialized. Please restart the app.",
          type = "error",
          duration = 10
        )
        return()
      }

      if (!api$oauth$is_authenticated()) {
        showNotification(
          "Please connect to eBay first in Settings > eBay Connection",
          type = "warning",
          duration = 10
        )
        return()
      }

      cat("   ✅ eBay authenticated\n")

      # Get form data
      current_path <- paths[i]
      title <- input[[paste0("item_title_", i)]]
      description <- input[[paste0("item_description_", i)]]
      price <- input[[paste0("starting_price_", i)]]
      condition <- input[[paste0("condition_", i)]]

      cat("   Title:", substr(title, 1, 50), "...\n")
      cat("   Price:", price, "\n")
      cat("   Condition:", condition, "\n")

      # Validate fields
      if (is.null(title) || nchar(trimws(title)) == 0) {
        showNotification("Title is required", type = "error")
        return()
      }

      if (is.null(description) || nchar(trimws(description)) == 0) {
        showNotification("Description is required", type = "error")
        return()
      }

      if (is.null(price) || price <= 0) {
        showNotification("Valid price is required", type = "error")
        return()
      }

      # Get file path for card_id lookup
      file_paths <- image_file_paths()
      actual_path <- if (!is.null(file_paths) && i <= length(file_paths)) {
        file_paths[i]
      } else {
        convert_web_path_to_file_path(current_path)
      }

      if (is.null(actual_path) || !file.exists(actual_path)) {
        showNotification("Could not find image file", type = "error")
        return()
      }

      cat("   File path:", actual_path, "\n")

      # Get card_id from database
      image_hash <- calculate_image_hash(actual_path)
      if (is.null(image_hash)) {
        showNotification("Could not calculate image hash", type = "error")
        return()
      }

      # Look up card in postal_cards table
      tryCatch({
        con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
        on.exit(DBI::dbDisconnect(con), add = TRUE)

        card_result <- DBI::dbGetQuery(con, "
          SELECT card_id FROM postal_cards
          WHERE file_hash = ? AND image_type = ?
        ", list(image_hash, image_type))

        if (nrow(card_result) == 0) {
          showNotification("Card not found in database", type = "error")
          return()
        }

        card_id <- card_result$card_id[1]
        cat("   Card ID:", card_id, "\n")

        # Show progress notification
        notification_id <- showNotification(
          "Creating eBay listing...",
          duration = NULL,
          closeButton = FALSE,
          type = "message"
        )

        # Prepare AI data
        ai_data <- list(
          title = title,
          description = description,
          price = price,
          condition = condition
        )

        # Create listing
        result <- create_ebay_listing_from_card(
          card_id = card_id,
          ai_data = ai_data,
          ebay_api = api,
          session_id = session$token,
          image_url = NULL  # Will use placeholder
        )

        removeNotification(notification_id)

        if (result$success) {
          # Success!
          cat("   ✅ Listing created:", result$listing_id, "\n")

          showNotification(
            div(
              strong("Listing created successfully!"),
              br(),
              tags$a(
                href = result$listing_url,
                target = "_blank",
                "View on eBay Sandbox",
                style = "color: white; text-decoration: underline;"
              )
            ),
            type = "message",
            duration = 15
          )

          # Mark as sent
          isolate({
            rv$sent_images <- c(rv$sent_images, current_path)
          })

          # Update accordion panel status (trigger re-render)
          output$accordion_container <- renderUI({
            req(image_paths())
            # Re-render accordion to show updated status
            # ... existing accordion rendering code ...
          })

        } else {
          # Error
          cat("   ❌ Listing failed:", result$error, "\n")

          showNotification(
            paste("Failed to create listing:", result$error),
            type = "error",
            duration = NULL
          )

          # Mark as failed
          isolate({
            rv$failed_images <- c(rv$failed_images, current_path)
          })
        }

      }, error = function(e) {
        cat("   ❌ Error:", e$message, "\n")
        removeNotification(notification_id)
        showNotification(
          paste("Error:", e$message),
          type = "error",
          duration = NULL
        )
      })
    })
  })
})
```

**Validation**:
```bash
# Manual testing:
# 1. Start app: Rscript -e "shiny::runApp()"
# 2. Go to Settings > eBay Connection
# 3. Authenticate with eBay
# 4. Process face+verso images
# 5. Open export accordion panel
# 6. Fill in title/description/price
# 7. Click "Send to eBay"
# 8. Should see success notification with eBay URL
# 9. Click URL - should open sandbox listing
# 10. Verify listing details match form data
```

**Rollback**: Remove the entire `observe({ ... })` block for send_to_ebay handlers

---

### TASK 10: Source New Files in NAMESPACE
**File**: `R/mod_delcampe_export.R` (MODIFY - add source calls)

**Location**: Top of file (after library statements)

**Change Type**: ADD source() calls for new helper files

**Implementation**:
```r
# MODIFY R/mod_delcampe_export.R
# ADD near top of file (around line 10, before module UI function)

# Source eBay integration functions
if (file.exists("R/ebay_helpers.R")) source("R/ebay_helpers.R")
if (file.exists("R/ebay_integration.R")) source("R/ebay_integration.R")
if (file.exists("R/ebay_database_extension.R")) source("R/ebay_database_extension.R")
```

**Note**: In Golem apps, sourcing happens automatically via `golem::document_and_reload()`. This is just defensive.

**Validation**:
```bash
# Rebuild package
Rscript -e "devtools::document(); devtools::load_all()"

# Check NAMESPACE
cat NAMESPACE | grep ebay
```

**Rollback**: Remove source() calls

---

## Configuration Required

### .Renviron File
User must add these credentials to `.Renviron`:

```bash
# eBay Sandbox Credentials
EBAY_SANDBOX_CLIENT_ID=your_app_id_here
EBAY_SANDBOX_CLIENT_SECRET=your_cert_id_here

# eBay Business Policies (must create in sandbox first)
EBAY_FULFILLMENT_POLICY_ID=your_policy_id
EBAY_PAYMENT_POLICY_ID=your_policy_id
EBAY_RETURN_POLICY_ID=your_policy_id

# Environment
EBAY_ENVIRONMENT=sandbox
```

**How to get credentials**:
1. Go to https://developer.ebay.com
2. Create sandbox app
3. Get App ID (client_id) and Cert ID (client_secret)
4. Create business policies in sandbox account

**Validation**:
```bash
# Check credentials loaded
Rscript -e "
  cat('EBAY_SANDBOX_CLIENT_ID:', nchar(Sys.getenv('EBAY_SANDBOX_CLIENT_ID')), 'chars\n')
  cat('EBAY_SANDBOX_CLIENT_SECRET:', nchar(Sys.getenv('EBAY_SANDBOX_CLIENT_SECRET')), 'chars\n')
  cat('EBAY_FULFILLMENT_POLICY_ID:', Sys.getenv('EBAY_FULFILLMENT_POLICY_ID'), '\n')
"
```

---

## Testing Strategy

### Unit Tests (helpers)
```bash
Rscript -e "testthat::test_file('tests/testthat/test-ebay-helpers.R')"
```

### Integration Test (full flow)
```bash
# See TASK 2 validation section for complete test script
# Tests: auth → inventory → offer → publish → database save
```

### Manual Testing Checklist
```yaml
setup:
  - [ ] .Renviron credentials configured
  - [ ] eBay sandbox account created
  - [ ] Business policies created in sandbox
  - [ ] Database table exists

oauth_flow:
  - [ ] Settings > eBay Connection tab exists
  - [ ] "Connect to eBay" button works
  - [ ] Authorization URL opens in browser
  - [ ] Code submission works
  - [ ] "Connected" status shows

listing_creation:
  - [ ] Process face+verso images
  - [ ] Open export accordion panel
  - [ ] AI extraction populates fields (if duplicate)
  - [ ] Manual edits work
  - [ ] "Send to eBay" button enabled when authenticated
  - [ ] Click button shows progress notification
  - [ ] Success shows eBay URL
  - [ ] URL opens correct sandbox listing
  - [ ] Listing details match form data
  - [ ] Database record created

error_handling:
  - [ ] Unauthenticated click shows warning
  - [ ] Missing fields show validation error
  - [ ] API errors show user-friendly message
  - [ ] Failed listings marked as "failed" status
```

---

## Rollback Strategy

**Per-Task Rollback**: See each task's "Rollback" section

**Full Rollback** (if integration fails):
```bash
# 1. Backup current state
cp -r R/ ~/Documents/R_Projects/Delcampe_BACKUP/R_$(date +%Y%m%d_%H%M%S)/

# 2. Remove new files
rm R/ebay_helpers.R
rm R/ebay_integration.R

# 3. Revert modified files from git
git checkout R/mod_delcampe_export.R
git checkout R/app_ui.R
git checkout R/app_server.R
git checkout R/tracking_database.R

# 4. Remove database table
sqlite3 inst/app/data/tracking.sqlite "DROP TABLE IF EXISTS ebay_listings;"

# 5. Restart R session
Rscript -e "devtools::load_all()"
```

---

## Success Metrics

**Technical**:
- ✅ All R CMD checks pass
- ✅ No console errors on app startup
- ✅ OAuth flow completes successfully
- ✅ API calls return 2xx responses
- ✅ Database records created correctly

**Functional**:
- ✅ User can authenticate with one click
- ✅ Listing creation takes < 5 seconds
- ✅ Success rate > 95% for valid data
- ✅ Error messages are actionable
- ✅ Listing URL works immediately

**User Experience**:
- ✅ No technical jargon in UI
- ✅ Progress feedback at each step
- ✅ One-click listing from export form
- ✅ Link to view listing provided

---

## Known Limitations (MVP)

1. **Image URLs**: Using placeholder images for sandbox
   - **Future**: Upload actual images to cloud storage (S3/Cloudinary)

2. **Business Policies**: Must be pre-configured in sandbox
   - **Future**: API to create policies programmatically

3. **Aspects**: Using defaults (Era=Unknown, Theme=Other)
   - **Future**: Parse aspects from AI-extracted text

4. **Price Currency**: Hardcoded to USD
   - **Future**: Support EUR, GBP based on user locale

5. **Single Marketplace**: Only EBAY_US supported
   - **Future**: Multi-marketplace support (UK, DE, FR, etc.)

---

## Emergency Contacts

**If blocked**:
- eBay API errors: Check https://developer.ebay.com/api-docs/static/handling-error-messages.html
- OAuth issues: Verify redirect URI matches app configuration
- Database errors: Check `inst/app/data/tracking.sqlite` permissions
- Integration issues: Review console logs with `cat()` statements

**Support Resources**:
- eBay Developer Forums: https://community.ebay.com/t5/Developer/ct-p/developer
- API Status: https://developer.ebay.com/support/api-status
- Sandbox Issues: Often resolved by creating fresh test users
