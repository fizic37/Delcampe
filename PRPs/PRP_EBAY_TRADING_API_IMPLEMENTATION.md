# PRP: eBay Trading API Implementation for Cross-Border Listings

## Context

**CRITICAL: Read these serena memories FIRST:**
- `.serena/memories/ebay_inventory_api_limitation_20251028.md` - Why Inventory API doesn't work
- `.serena/memories/ebay_error_25019_investigation_20251027.md` - Initial investigation
- `.serena/memories/ebay_oauth_integration_complete_20251017.md` - OAuth setup

## Problem Statement

**eBay Inventory API cannot publish listings for cross-border sellers.**

- **Use Case:** Romania-based seller listing on US marketplace (EBAY_US)
- **Current Status:**
  - ✅ Inventory item creation works (HTTP 204)
  - ✅ Offer creation works (HTTP 201)
  - ❌ **Publish ALWAYS fails** with Error 25002: "No <Item.Country> exists"
- **Root Cause:** Inventory API provides NO documented way to specify Item.Country for cross-border sellers
- **Exhaustive Testing:** 16 different approaches tested over October 27-28, 2025 - ALL failed
- **Proven Solution:** User CAN create listings via eBay website (which uses Trading API)

## Requirements

### 1. Backup Inventory API Code

**CRITICAL: Inventory API code must be preserved but NOT in R/ folder (will get loaded into R environment)**

Before any modifications:
```r
# Backup existing Inventory API code
backup_folder <- "C:/Users/mariu/Documents/R_Projects/Delcampe_BACKUP"
backup_date <- format(Sys.Date(), "%Y%m%d")

# Files to backup:
# - R/ebay_integration.R (contains Inventory API logic)
# - R/ebay_api.R (if modified)
# - Any other files with Inventory API references

# Backup naming: ebay_integration_INVENTORY_API_20251028.R
```

Store in: `C:\Users\mariu\Documents\R_Projects\Delcampe_BACKUP\`

### 2. Implement Trading API Integration

Create new Trading API client to **replace** Inventory API usage:

#### File: `R/ebay_trading_api.R`
Create new R6 class `EbayTradingAPI` that:
- Uses OAuth authentication (Trading API supports it - no need for legacy auth)
- Handles XML request/response format (Trading API uses XML, not JSON)
- Implements `AddFixedPriceItem` call for creating listings
- Implements `VerifyAddFixedPriceItem` call for validation (optional but recommended)
- Supports same eBay account manager integration

#### Core Methods Required:
```r
EbayTradingAPI <- R6::R6Class("EbayTradingAPI",
  public = list(
    initialize = function(config, oauth),
    add_fixed_price_item = function(item_data),  # Main listing creation
    verify_add_item = function(item_data),       # Validation (optional)
    revise_item = function(item_id, changes),    # For future updates
    end_item = function(item_id, reason)         # For future deletions
  )
)
```

### 3. Replace Inventory API Calls

Modify `R/ebay_integration.R` to **only use Trading API**:

```r
create_ebay_listing_from_card <- function(...) {
  # REMOVED: Inventory API logic (backed up to Delcampe_BACKUP folder)
  # Inventory API cannot handle cross-border sellers (Error 25002)

  cat("   ℹ️ Creating eBay listing via Trading API...\n")

  # Use Trading API directly
  result <- create_trading_api_listing(...)

  if (result$success) {
    cat("   ✅ Listing created via Trading API\n")
    cat("   ℹ️ Item ID:", result$item_id, "\n")
  } else {
    cat("   ❌ Trading API failed:", result$error, "\n")
  }

  return(result)
}

# OLD INVENTORY API CODE - COMMENT OUT (DO NOT DELETE YET)
# # This code no longer works for cross-border sellers
# create_inventory_api_listing <- function(...) {
#   # ... old 3-step process: inventory item → offer → publish
#   # ... always fails with Error 25002 for Romania → US
# }
```

### 4. Trading API Request Structure

The Trading API `AddFixedPriceItem` XML structure must include:

```xml
<?xml version="1.0" encoding="utf-8"?>
<AddFixedPriceItemRequest xmlns="urn:ebay:apis:eBLBaseComponents">
  <RequesterCredentials>
    <eBayAuthToken><!--OAuth Token Here--></eBayAuthToken>
  </RequesterCredentials>

  <Item>
    <Title>Vintage Romanian Postcard - Title</Title>
    <Description><![CDATA[Description here]]></Description>

    <!-- CRITICAL: This is what Inventory API cannot provide -->
    <Country>RO</Country>
    <Location>Bucharest, Romania</Location>

    <PrimaryCategory>
      <CategoryID>262042</CategoryID>
    </PrimaryCategory>

    <StartPrice currencyID="USD">6.50</StartPrice>
    <ConditionID>3000</ConditionID>  <!-- Used -->
    <Quantity>1</Quantity>
    <ListingDuration>GTC</ListingDuration>  <!-- Good Till Cancelled -->

    <ShippingDetails>
      <ShippingServiceOptions>
        <ShippingService>USPSFirstClass</ShippingService>
        <ShippingServiceCost currencyID="USD">3.00</ShippingServiceCost>
        <ShippingServicePriority>1</ShippingServicePriority>
      </ShippingServiceOptions>
      <ShippingType>Flat</ShippingType>
    </ShippingDetails>

    <ReturnPolicy>
      <ReturnsAcceptedOption>ReturnsAccepted</ReturnsAcceptedOption>
      <RefundOption>MoneyBack</RefundOption>
      <ReturnsWithinOption>Days_30</ReturnsWithinOption>
      <ShippingCostPaidByOption>Buyer</ShippingCostPaidByOption>
    </ReturnPolicy>

    <PictureDetails>
      <PictureURL>https://i.ebayimg.com/images/...</PictureURL>
    </PictureDetails>

    <ItemSpecifics>
      <NameValueList>
        <Name>Type</Name>
        <Value>Postcard</Value>
      </NameValueList>
      <NameValueList>
        <Name>Condition</Name>
        <Value>Used</Value>
      </NameValueList>
    </ItemSpecifics>
  </Item>
</AddFixedPriceItemRequest>
```

### 5. XML Handling in R

Use `xml2` package for XML handling:

```r
library(xml2)

# Build XML request
build_add_item_xml <- function(item_data, token) {
  doc <- xml_new_root("AddFixedPriceItemRequest",
    xmlns = "urn:ebay:apis:eBLBaseComponents"
  )

  # Add credentials
  creds <- xml_add_child(doc, "RequesterCredentials")
  xml_add_child(creds, "eBayAuthToken", token)

  # Add item details
  item <- xml_add_child(doc, "Item")
  xml_add_child(item, "Title", item_data$title)
  xml_add_child(item, "Country", "RO")  # THE KEY FIELD!
  # ... add more fields

  return(as.character(doc))
}

# Parse XML response
parse_trading_response <- function(xml_string) {
  doc <- read_xml(xml_string)

  ack <- xml_text(xml_find_first(doc, ".//Ack"))

  if (ack %in% c("Success", "Warning")) {
    item_id <- xml_text(xml_find_first(doc, ".//ItemID"))
    return(list(success = TRUE, item_id = item_id))
  } else {
    errors <- xml_find_all(doc, ".//Errors")
    error_msgs <- xml_text(xml_find_all(errors, ".//LongMessage"))
    return(list(success = FALSE, error = paste(error_msgs, collapse = "; ")))
  }
}
```

### 6. Trading API Endpoint

**Production:** `https://api.ebay.com/ws/api.dll`
**Sandbox:** `https://api.sandbox.ebay.com/ws/api.dll`

Headers required:
```
X-EBAY-API-SITEID: 0  (0 = US)
X-EBAY-API-COMPATIBILITY-LEVEL: 1355  (or latest)
X-EBAY-API-CALL-NAME: AddFixedPriceItem
Content-Type: text/xml
```

### 7. Integration Points

#### Update `R/ebay_api.R`
Replace Inventory API with Trading API client initialization:
```r
init_ebay_api <- function(environment = NULL) {
  # REMOVED: Inventory API setup (backed up)
  # Now using Trading API only

  # Initialize Trading API
  api$trading <- EbayTradingAPI$new(
    config = config,
    oauth = oauth
  )

  return(api)
}
```

#### Update `R/ebay_integration.R`
Modify `create_ebay_listing_from_card()` to use Trading API only (see requirement #3).

#### Maintain Database Compatibility
Trading API returns `ItemID` instead of `sku/offerId`. Map appropriately:
```r
# Save to database with consistent structure
save_ebay_listing(
  sku = sku,                           # Keep for consistency
  listing_id = result$item_id,          # Trading API ItemID
  offer_id = NA,                        # Trading API doesn't use offers
  api_type = "trading",                 # Track which API was used
  ...
)
```

### 8. Error Handling

Trading API returns different error codes than Inventory API. Common errors:

| Error Code | Meaning | Action |
|------------|---------|--------|
| 21916734 | Duplicate item | Check if already listed |
| 21916635 | Invalid category | Verify category 262042 supports Trading API |
| 21916803 | Missing required field | Check XML structure |
| 21916888 | Token invalid | Refresh OAuth token |

### 9. Testing Strategy

#### Phase 1: Basic XML Generation
```r
# Test XML generation without API call
test_xml <- build_add_item_xml(test_data, "dummy_token")
# Verify XML structure matches eBay schema
```

#### Phase 2: VerifyAddItem
```r
# Use VerifyAddFixedPriceItem to validate without creating
result <- ebay_api$trading$verify_add_item(item_data)
# Check for validation errors
```

#### Phase 3: Sandbox Testing
```r
# Create actual listing in sandbox
result <- ebay_api$trading$add_fixed_price_item(item_data)
# Verify ItemID returned
```

#### Phase 4: Production Test
```r
# Create ONE test listing in production
# Verify it appears on eBay website
# Then end the listing (cleanup)
```

### 10. Database Compatibility

- **CRITICAL**: Trading API returns different data structure than Inventory API
- Database must handle both API types for historical data
- New listings use Trading API, old listings may have Inventory API data

Database schema considerations:
```r
# ebay_listings table should support:
# - api_type: "trading" or "inventory"
# - listing_id: ItemID (Trading) or listingId (Inventory)
# - offer_id: NA (Trading) or offerId (Inventory)
# - sku: Consistent format for both APIs
```

### 11. Future Enhancements (Optional)

Once basic Trading API works:
- Implement `ReviseFixedPriceItem` for updating listings
- Implement `EndFixedPriceItem` for deleting listings
- Consider using Trading API `UploadSiteHostedPictures` instead of EPS
- Add Trading API-specific business policies support

## Implementation Steps

1. **Backup Existing Code** ⚠️ FIRST STEP
   - Create backup of `R/ebay_integration.R` with Inventory API code
   - Save to: `C:\Users\mariu\Documents\R_Projects\Delcampe_BACKUP\ebay_integration_INVENTORY_API_20251028.R`
   - **DO NOT store backups in R/ folder** (will be loaded into R environment)

2. **Create `R/ebay_trading_api.R`**
   - Implement `EbayTradingAPI` R6 class
   - XML request building functions
   - XML response parsing functions
   - Error handling

3. **Add `xml2` dependency**
   - Update `DESCRIPTION`: Add `xml2` to Imports
   - Update `NAMESPACE`: Import xml2 functions

4. **Create helper functions in `R/ebay_helpers.R`**
   - `build_trading_item_xml()` - Convert card data to Trading API XML
   - `parse_trading_response()` - Parse Trading API XML response
   - `get_trading_api_endpoint()` - Get correct endpoint URL

5. **Modify `R/ebay_integration.R`**
   - **Comment out** Inventory API functions (keep for reference)
   - Replace `create_ebay_listing_from_card()` to call Trading API only
   - Create `create_trading_api_listing()` function
   - Remove Inventory API error handling

6. **Update `R/ebay_api.R`**
   - Replace Inventory API initialization with Trading API
   - Expose Trading API client via `ebay_api$trading`
   - Comment out Inventory API client setup

7. **Testing**
   - Create `tests/testthat/test-ebay_trading_api.R`
   - Test XML generation
   - Test response parsing
   - Add to critical test suite once stable

8. **Documentation**
   - Update `.serena/memories/` with Trading API integration notes
   - Document that Inventory API is no longer used
   - Add troubleshooting guide

## Success Criteria

- ✅ Trading API client successfully creates listings from Romania to US marketplace
- ✅ Listings include explicit `<Country>RO</Country>` field
- ✅ Database correctly tracks Trading API listings
- ✅ Inventory API code safely backed up outside R/ folder
- ✅ User can create postcard listings to US marketplace
- ✅ All existing tests still pass (update to use Trading API)

## Constraints

- **DO NOT** store backup files in R/ folder (will be loaded into R environment)
- **MUST** backup Inventory API code to `C:\Users\mariu\Documents\R_Projects\Delcampe_BACKUP\`
- **DO NOT** modify OAuth implementation (it works for both APIs)
- **MUST** use R's `xml2` package for XML handling (don't reinvent)
- **MUST** maintain database schema compatibility (support both api_type values)
- **SHOULD** comment out (not delete) Inventory API code in R/ files for reference
- **MUST** log api_type="trading" for each listing (for database consistency)

## Key Differences: Inventory API vs Trading API

| Aspect | Inventory API | Trading API |
|--------|---------------|-------------|
| Format | JSON | XML |
| Auth | OAuth | OAuth (or legacy) |
| Listing Flow | 3 steps: item → offer → publish | 1 step: AddItem |
| Country Field | ❌ No way to specify | ✅ Explicit `<Country>` field |
| Return Value | `offerId`, `listingId` | `ItemID` |
| Status | Modern, recommended | Legacy, but still supported |
| Our Use | ❌ **Removed** (doesn't work) | ✅ **Primary API** (only option) |

## Resources

- **Trading API Docs:** https://developer.ebay.com/Devzone/XML/docs/Reference/eBay/index.html
- **AddFixedPriceItem:** https://developer.ebay.com/Devzone/XML/docs/Reference/eBay/AddFixedPriceItem.html
- **Trading API with OAuth:** https://developer.ebay.com/devzone/xml/docs/HowTo/Tokens/MakingACall.html
- **XML Schema:** https://developer.ebay.com/webservices/latest/ebaySvc.xsd
- **R xml2 package:** https://xml2.r-lib.org/

## Notes

- Trading API is "legacy" but still fully supported by eBay
- eBay's website likely uses Trading API under the hood for cross-border listings
- Inventory API code is backed up outside R/ folder for future reference
- If eBay ever fixes Inventory API for cross-border sellers, we can reconsider
- For now, Trading API is the ONLY working solution for Romania → US listings

## Estimated Effort

- **Backup:** 15 minutes
- **Core Implementation:** 3-4 hours (simpler without hybrid logic)
- **Testing:** 2-3 hours
- **Documentation:** 1 hour
- **Total:** ~6-8 hours

## Priority

**HIGH** - Blocks Romania seller from listing postcards on US marketplace, which is a core use case.
