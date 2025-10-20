# PRP: eBay Sandbox Integration for Postcard Listings

## Problem Statement
Integrate eBay sandbox API functionality into the Delcampe app to allow users to:
1. Connect to eBay sandbox environment
2. List postcards with a "Send to eBay" button
3. Use extracted data from AI processing for listing details
4. Track eBay listing status in the database

## Context Analysis

### Current State
- **App Structure**: R Shiny Golem app with modular architecture
- **Database**: SQLite with tracking tables for postcards, AI extractions, and processing
- **AI Integration**: Already extracts title, description, condition, and price from postcards
- **UI Flow**: Face/Verso processing → Combined images → Export section

### Required Integration Points
1. **UI**: Add "Send to eBay" button in export section
2. **Database**: Add ebay_listings table for tracking
3. **Authentication**: OAuth2 flow for eBay connection
4. **Data Flow**: AI extraction → eBay listing creation

## Solution Design

### Architecture
```
User Interface
    ├── Export Section (existing)
    │   ├── Delcampe Export Button (existing)
    │   └── eBay Send Button (new)
    │
    ├── Settings Tab
    │   └── eBay Connection Panel (new)
    │
    └── eBay Status Modal (new)

Backend Modules
    ├── mod_ebay_auth.R (created)
    ├── mod_ebay_postcard.R (created)
    ├── ebay_api.R (created)
    └── tracking_database.R (extend)

Data Flow
    Postcard Processing → AI Extraction → eBay Listing
```

## Implementation Plan

### Phase 1: Database Extension
Add eBay tracking table to existing SQLite database.

### Phase 2: UI Integration
Add "Send to eBay" button in the export section that appears after processing.

### Phase 3: Authentication Flow
Implement OAuth2 authentication in settings tab.

### Phase 4: Listing Creation
Use AI-extracted data to populate eBay listing fields.

### Phase 5: Testing & Validation
Test complete flow in sandbox environment.

## Detailed Tasks

### Task 1: Extend Database Schema
**File**: `R/tracking_database.R`
**Action**: Add eBay listings table

```r
# Add to initialize_tracking_db function
DBI::dbExecute(con, "
  CREATE TABLE IF NOT EXISTS ebay_listings (
    listing_id INTEGER PRIMARY KEY AUTOINCREMENT,
    card_id INTEGER NOT NULL,
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
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    listed_at DATETIME,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
    error_message TEXT,
    FOREIGN KEY (card_id) REFERENCES postal_cards(card_id),
    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
  )
")
```

### Task 2: Integrate eBay Button in Export Section
**File**: `R/mod_delcampe_export.R` (modify existing)
**Action**: Add eBay send button next to Delcampe export

```r
# In mod_delcampe_export_ui
div(
  class = "export-buttons",
  actionButton(
    ns("export_delcampe"),
    "Export to Delcampe",
    icon = icon("file-export"),
    class = "btn-primary"
  ),
  actionButton(
    ns("send_to_ebay"),
    "Send to eBay",
    icon = icon("shopping-cart"),
    class = "btn-success"
  )
)
```

### Task 3: Add eBay Settings Panel
**File**: `R/app_ui.R` (modify)
**Action**: Add eBay panel to Settings tab

```r
# In Settings navset_card_tab
bslib::nav_panel(
  title = "eBay Connection",
  mod_ebay_auth_ui("ebay_auth")
)
```

### Task 4: Server Integration
**File**: `R/app_server.R` (modify)
**Action**: Initialize eBay API and connect modules

```r
app_server <- function(input, output, session) {
  # ... existing code ...
  
  # Initialize eBay API
  ebay_api <- mod_ebay_auth_server("ebay_auth")
  
  # Pass eBay API to export module
  mod_delcampe_export_server("export_module", 
    combined_images = combined_images,
    ebay_api = ebay_api
  )
}
```

### Task 5: Create eBay Listing Handler
**File**: `R/mod_delcampe_export.R` (extend)
**Action**: Add eBay listing logic

```r
# In mod_delcampe_export_server
observeEvent(input$send_to_ebay, {
  req(combined_images())
  req(ebay_api())
  
  # Check eBay connection
  if (!ebay_api()$oauth$is_authenticated()) {
    showModal(modalDialog(
      title = "eBay Connection Required",
      "Please connect to eBay in Settings first.",
      footer = modalButton("OK")
    ))
    return()
  }
  
  # Get AI extraction data
  ai_data <- get_ai_extraction_for_image(current_image_id())
  
  # Create listing
  withProgress(message = "Creating eBay listing...", {
    result <- ebay_api()$inventory$create_postcard_listing(
      sku = paste0("PC-", format(Sys.time(), "%Y%m%d%H%M%S")),
      title = ai_data$title %||% "Vintage Postcard",
      description = ai_data$description %||% "",
      price = ai_data$price %||% 9.99,
      quantity = 1,
      condition = map_condition_to_ebay(ai_data$condition),
      aspects = list(
        "Type" = list("Postcard"),
        "Era" = list(ai_data$era %||% "Unknown"),
        "Theme" = list(ai_data$theme %||% "Travel")
      )
    )
    
    if (result$success) {
      # Save to database
      save_ebay_listing(
        card_id = current_card_id(),
        session_id = session$token,
        ebay_item_id = result$listing_id,
        ebay_offer_id = result$offer_id,
        sku = sku,
        status = "listed"
      )
      
      showNotification("Listing created on eBay!", type = "success")
    } else {
      showNotification(paste("Error:", result$error), type = "error")
    }
  })
})
```

### Task 6: Helper Functions
**File**: `R/ebay_helpers.R` (new)
**Action**: Create utility functions

```r
# Map AI conditions to eBay conditions
map_condition_to_ebay <- function(ai_condition) {
  condition_map <- list(
    "Excellent" = "USED_EXCELLENT",
    "Very Good" = "USED_VERY_GOOD",
    "Good" = "USED_GOOD",
    "Fair" = "USED_ACCEPTABLE",
    "Poor" = "USED_ACCEPTABLE",
    "New" = "NEW"
  )
  
  condition_map[[ai_condition]] %||% "USED_GOOD"
}

# Generate SKU from image data
generate_sku <- function(card_id, timestamp = Sys.time()) {
  paste0("PC-", card_id, "-", format(timestamp, "%Y%m%d"))
}

# Save eBay listing to database
save_ebay_listing <- function(card_id, session_id, ebay_item_id, 
                              ebay_offer_id, sku, status = "draft") {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))
  
  DBI::dbExecute(con, "
    INSERT INTO ebay_listings 
    (card_id, session_id, ebay_item_id, ebay_offer_id, sku, status, 
     environment, listed_at)
    VALUES (?, ?, ?, ?, ?, ?, 'sandbox', CURRENT_TIMESTAMP)
  ", params = list(card_id, session_id, ebay_item_id, 
                   ebay_offer_id, sku, status))
}
```

## Testing Plan

### 1. Unit Tests
- Test eBay API connection
- Test OAuth flow
- Test listing creation with mock data

### 2. Integration Tests
- Complete flow: Upload → Process → AI Extract → eBay List
- Error handling for missing credentials
- Sandbox environment validation

### 3. User Acceptance Tests
- Connect to eBay sandbox
- Create test listing
- Verify listing appears in sandbox account

## Configuration Requirements

### Environment Variables (.Renviron)
```
EBAY_SANDBOX_CLIENT_ID=your_sandbox_app_id
EBAY_SANDBOX_CLIENT_SECRET=your_sandbox_cert_id
EBAY_ENVIRONMENT=sandbox
EBAY_REDIRECT_URI=http://localhost:3838/callback
```

### eBay Developer Account Setup
1. Register at developer.ebay.com
2. Create application
3. Get sandbox credentials
4. Set up business policies

## Success Criteria

1. ✓ User can authenticate with eBay sandbox
2. ✓ "Send to eBay" button appears after processing
3. ✓ AI-extracted data populates listing fields
4. ✓ Listing is created in sandbox environment
5. ✓ Status is tracked in database
6. ✓ Error messages are user-friendly
7. ✓ Connection status visible in settings

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| API Rate Limits | Implement throttling and queue system |
| Token Expiry | Auto-refresh tokens before expiry |
| Missing AI Data | Provide defaults and allow manual edit |
| Network Errors | Retry logic with exponential backoff |
| Sandbox Limitations | Clear messaging about test environment |

## Timeline

- **Day 1**: Database schema and basic UI integration
- **Day 2**: Authentication flow and settings panel
- **Day 3**: Listing creation logic
- **Day 4**: Testing and error handling
- **Day 5**: Documentation and deployment

## Next Steps

1. Update .Renviron with eBay credentials
2. Run database migration to add new tables
3. Implement UI changes in export module
4. Test OAuth flow with sandbox
5. Create first test listing

## Notes

- Start with sandbox environment only
- Use existing AI extraction data
- Maintain backward compatibility
- Keep Delcampe export functionality intact
- Add progress indicators for user feedback
