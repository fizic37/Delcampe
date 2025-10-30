# PRP: eBay Auction Listing Support

**Priority**: CRITICAL
**Status**: Ready for Implementation
**Created**: 2025-10-29
**Estimated Effort**: 4-6 hours
**Related Memories**:
- `.serena/memories/ebay_trading_api_complete_20251028.md`
- `.serena/memories/ebay_trading_api_implementation_complete_20251028.md`

---

## Problem Statement

The current eBay integration only supports **Fixed Price (Buy It Now)** listings. Users need the ability to create **Auction** listings, which is the preferred format for vintage postcard sales on eBay. Auction listings allow competitive bidding and can achieve higher final sale prices than fixed-price listings.

**Current Limitation**: All listings use `AddFixedPriceItem` API call with `ListingDuration=GTC` (Good 'Til Cancelled).

**User Impact**: HIGH - Users cannot create auction listings, limiting their selling strategy and potentially reducing revenue.

---

## Requirements

### Functional Requirements

#### FR1: Listing Type Selection
- **MUST** add a select input allowing user to choose between "Auction" and "Buy It Now"
- **MUST** default to "Auction" (preferred format for vintage postcards)
- **MUST** be placed above the price field in the UI
- **MUST** persist selection across page refreshes using reactive state

#### FR2: Conditional UI Elements
- When **Auction** is selected:
  - Price field label **MUST** change to "Starting Bid"
  - **MUST** show auction duration dropdown (3, 5, 7, or 10 days)
  - **SHOULD** optionally show "Buy It Now Price" field (must be 30%+ higher than starting bid)
  - **SHOULD** optionally show "Reserve Price" field (minimum acceptable price)

- When **Buy It Now** is selected:
  - Price field label **MUST** remain "Price"
  - Duration **MUST** be fixed at "GTC" (Good 'Til Cancelled)
  - Buy It Now and Reserve fields **MUST** be hidden

#### FR3: API Integration
- **MUST** create new method `add_auction_item()` in `EbayTradingAPI` R6 class
- **MUST** use `AddItem` API call with `ListingType=Chinese` for auctions
- **MUST** continue using `AddFixedPriceItem` for Buy It Now listings
- **MUST** validate auction-specific fields before submission
- **MUST** handle Buy It Now price validation (30%+ higher than starting bid)

#### FR4: Database Schema
- **MUST** add `listing_type` column to `ebay_listings` table (values: "auction", "fixed_price")
- **MUST** add `listing_duration` column to store duration (e.g., "Days_7", "GTC")
- **MUST** add `buy_it_now_price` column (nullable REAL)
- **MUST** add `reserve_price` column (nullable REAL)
- **MUST** provide automatic migration for existing databases

#### FR5: Validation
- Starting bid **MUST** be greater than $0.99 (eBay minimum)
- Buy It Now price **MUST** be at least 30% higher than starting bid (if specified)
- Reserve price **MUST** be greater than or equal to starting bid (if specified)
- Auction duration **MUST** be one of: Days_3, Days_5, Days_7, Days_10

### Non-Functional Requirements

#### NFR1: User Experience
- UI changes **MUST** be intuitive and self-explanatory
- Field labels **MUST** update immediately when listing type changes
- Invalid combinations **MUST** show clear error messages
- Progress feedback **MUST** be shown during listing creation

#### NFR2: Code Quality
- **MUST** follow Golem module conventions
- **MUST** include comprehensive unit tests (critical test suite)
- **MUST** maintain existing code style and patterns
- **MUST** backup original files before modification

#### NFR3: Backwards Compatibility
- Existing fixed-price listings **MUST** continue to work
- Database migration **MUST** be automatic and safe
- Existing code calling `add_fixed_price_item()` **MUST** still work

---

## Technical Research

### eBay Trading API - Auction vs Fixed Price

| Feature | Auction (Chinese) | Fixed Price |
|---------|------------------|-------------|
| **API Call** | `AddItem` | `AddFixedPriceItem` |
| **ListingType** | `Chinese` | `FixedPriceItem` |
| **Price Field** | `<StartPrice>` | `<StartPrice>` |
| **Duration** | `Days_3`, `Days_5`, `Days_7`, `Days_10` | `GTC` (Good 'Til Cancelled) |
| **Buy It Now** | Optional `<BuyItNowPrice>` | N/A (is Buy It Now) |
| **Reserve Price** | Optional `<ReservePrice>` | N/A |
| **Quantity** | Must be `1` | Can be multiple |

### XML Request Structure for Auction

```xml
<?xml version="1.0" encoding="utf-8"?>
<AddItemRequest xmlns="urn:ebay:apis:eBLBaseComponents">
  <RequesterCredentials>
    <eBayAuthToken>{token}</eBayAuthToken>
  </RequesterCredentials>
  <Item>
    <Country>RO</Country>
    <Location>Bucharest, Romania</Location>
    <Title>Vintage Bucharest Postcard 1920s</Title>
    <Description><![CDATA[...HTML description...]]></Description>
    <PrimaryCategory>
      <CategoryID>262042</CategoryID>
    </PrimaryCategory>

    <!-- AUCTION-SPECIFIC FIELDS -->
    <ListingType>Chinese</ListingType>
    <StartPrice currencyID="USD">4.99</StartPrice>
    <ListingDuration>Days_7</ListingDuration>

    <!-- OPTIONAL: Buy It Now (must be 30%+ higher) -->
    <BuyItNowPrice currencyID="USD">9.99</BuyItNowPrice>

    <!-- OPTIONAL: Reserve Price (minimum to sell) -->
    <ReservePrice currencyID="USD">6.50</ReservePrice>

    <ConditionID>3000</ConditionID>
    <Quantity>1</Quantity>
    <PictureDetails>
      <PictureURL>https://i.imgur.com/...</PictureURL>
    </PictureDetails>
    <ItemSpecifics>
      <NameValueList>
        <Name>Type</Name>
        <Value>Postcard</Value>
      </NameValueList>
    </ItemSpecifics>

    <!-- Business Policies (reuse existing implementation) -->
    <SellerProfiles>
      <SellerPaymentProfile>
        <PaymentProfileID>{payment_profile_id}</PaymentProfileID>
      </SellerPaymentProfile>
      <SellerReturnProfile>
        <ReturnProfileID>{return_profile_id}</ReturnProfileID>
      </SellerReturnProfile>
      <SellerShippingProfile>
        <ShippingProfileID>{shipping_profile_id}</ShippingProfileID>
      </SellerShippingProfile>
    </SellerProfiles>
  </Item>
</AddItemRequest>
```

### Key Differences from Current Implementation

1. **API Call**: Use `AddItem` instead of `AddFixedPriceItem`
2. **ListingType**: Must specify `<ListingType>Chinese</ListingType>`
3. **Duration**: Use `Days_X` instead of `GTC`
4. **Price Semantics**: `StartPrice` means "starting bid" not "fixed price"
5. **Quantity**: Must be `1` for auctions (enforced by eBay)

---

## Implementation Plan

### Phase 1: Database Extension (30 minutes)

**File**: `R/ebay_database_extension.R`

1. Add columns to `ebay_listings` table:
   ```r
   listing_type TEXT DEFAULT 'fixed_price'
   listing_duration TEXT DEFAULT 'GTC'
   buy_it_now_price REAL
   reserve_price REAL
   ```

2. Create migration function `migrate_add_auction_fields()`

3. Call migration in `initialize_ebay_tables()`

4. Update `save_ebay_listing()` to accept new parameters

5. Add indexes for performance:
   ```sql
   CREATE INDEX idx_ebay_listings_listing_type ON ebay_listings(listing_type);
   ```

**Testing**:
- Test migration on empty database
- Test migration on database with existing records
- Verify default values applied correctly

### Phase 2: Trading API Enhancement (2 hours)

**File**: `R/ebay_trading_api.R`

1. **Add `add_auction_item()` method** (lines 114-200):
   ```r
   add_auction_item = function(item_data) {
     # item_data must include:
     # - start_price (starting bid)
     # - listing_duration (Days_3, Days_5, Days_7, Days_10)
     # - buy_it_now_price (optional, must be 30%+ higher)
     # - reserve_price (optional, >= start_price)

     # Validate auction-specific requirements
     private$validate_auction_data(item_data)

     # Build XML with ListingType=Chinese
     xml_body <- private$build_auction_xml(item_data)

     # Make request to AddItem (not AddFixedPriceItem)
     response <- private$make_request(xml_body, "AddItem")

     # Parse response (same structure as fixed price)
     return(private$parse_response(httr2::resp_body_string(response)))
   }
   ```

2. **Add private helper `build_auction_xml()`** (lines 300-400):
   - Similar to `build_add_item_xml()` but:
   - Include `<ListingType>Chinese</ListingType>`
   - Use `<StartPrice>` for starting bid
   - Include `<ListingDuration>Days_X</ListingDuration>`
   - Conditionally add `<BuyItNowPrice>` if specified
   - Conditionally add `<ReservePrice>` if specified
   - Force `<Quantity>1</Quantity>` (required for auctions)

3. **Add private helper `validate_auction_data()`** (lines 401-450):
   ```r
   validate_auction_data = function(item_data) {
     # Validate starting price >= $0.99
     if (is.null(item_data$start_price) || item_data$start_price < 0.99) {
       stop("Starting bid must be at least $0.99")
     }

     # Validate Buy It Now price (if specified)
     if (!is.null(item_data$buy_it_now_price)) {
       if (item_data$buy_it_now_price < item_data$start_price * 1.3) {
         stop("Buy It Now price must be at least 30% higher than starting bid")
       }
     }

     # Validate Reserve price (if specified)
     if (!is.null(item_data$reserve_price)) {
       if (item_data$reserve_price < item_data$start_price) {
         stop("Reserve price must be >= starting bid")
       }
     }

     # Validate duration
     valid_durations <- c("Days_3", "Days_5", "Days_7", "Days_10")
     if (!item_data$listing_duration %in% valid_durations) {
       stop("Invalid auction duration. Must be Days_3, Days_5, Days_7, or Days_10")
     }
   }
   ```

4. **Update `make_request()` to handle both API calls** (if needed)

**Testing**:
- Test XML generation for auction with all fields
- Test XML generation for auction with optional fields omitted
- Test validation for invalid Buy It Now price (< 30% higher)
- Test validation for invalid Reserve price (< starting bid)
- Test validation for invalid duration
- Test validation for starting price < $0.99

### Phase 3: Integration Layer Update (1 hour)

**File**: `R/ebay_integration.R`

1. **Update `create_ebay_listing_from_card()`**:
   - Add parameters: `listing_type`, `listing_duration`, `buy_it_now_price`, `reserve_price`
   - Detect listing type and call appropriate method:
     ```r
     if (listing_type == "auction") {
       result <- ebay_api$trading$add_auction_item(item_data)
     } else {
       result <- ebay_api$trading$add_fixed_price_item(item_data)
     }
     ```

2. **Update database save call**:
   ```r
   save_ebay_listing(
     session_id = session_id,
     card_id = card_id,
     item_id = result$item_id,
     listing_url = listing_url,
     api_type = "trading",
     listing_type = listing_type,
     listing_duration = listing_duration,
     buy_it_now_price = buy_it_now_price,
     reserve_price = reserve_price
   )
   ```

**Testing**:
- Test creating auction listing
- Test creating fixed-price listing
- Test database records have correct values

### Phase 4: UI Updates (2 hours)

**File**: `R/mod_delcampe_export.R`

1. **Add listing type selector** (after line 260, before price field):
   ```r
   # Listing Type Selection
   selectInput(
     ns(paste0("listing_type_", idx)),
     "Listing Type",
     choices = c("Auction" = "auction", "Buy It Now" = "fixed_price"),
     selected = "auction",
     width = "100%"
   ),
   ```

2. **Add conditional duration selector** (shown only for auctions):
   ```r
   # Auction Duration (conditional)
   conditionalPanel(
     condition = sprintf("input['%s'] == 'auction'", ns(paste0("listing_type_", idx))),
     selectInput(
       ns(paste0("auction_duration_", idx)),
       "Auction Duration",
       choices = c(
         "3 Days" = "Days_3",
         "5 Days" = "Days_5",
         "7 Days" = "Days_7",
         "10 Days" = "Days_10"
       ),
       selected = "Days_7",
       width = "100%"
     )
   ),
   ```

3. **Add optional Buy It Now field** (shown only for auctions):
   ```r
   # Buy It Now Price (optional, auction only)
   conditionalPanel(
     condition = sprintf("input['%s'] == 'auction'", ns(paste0("listing_type_", idx))),
     textInput(
       ns(paste0("buy_it_now_", idx)),
       "Buy It Now Price (Optional - must be 30%+ higher)",
       value = "",
       placeholder = "e.g., 9.99",
       width = "100%"
     )
   ),
   ```

4. **Add optional Reserve Price field** (shown only for auctions):
   ```r
   # Reserve Price (optional, auction only)
   conditionalPanel(
     condition = sprintf("input['%s'] == 'auction'", ns(paste0("listing_type_", idx))),
     textInput(
       ns(paste0("reserve_price_", idx)),
       "Reserve Price (Optional - minimum to sell)",
       value = "",
       placeholder = "e.g., 6.50",
       width = "100%"
     )
   ),
   ```

5. **Update dynamic price label** with observeEvent:
   ```r
   observeEvent(input[[paste0("listing_type_", i)]], {
     listing_type <- input[[paste0("listing_type_", i)]]

     # Update label based on listing type
     updateTextInput(
       session,
       paste0("price_", i),
       label = if (listing_type == "auction") "Starting Bid" else "Price"
     )
   })
   ```

6. **Update confirmation modal** to show listing type:
   ```r
   show_ebay_confirmation_modal = function(idx, title, price, condition, listing_type, duration) {
     type_label <- if (listing_type == "auction") {
       paste0("Auction (", duration, ")")
     } else {
       "Buy It Now"
     }

     showModal(modalDialog(
       title = "Confirm eBay Listing",
       tagList(
         p(strong("Title:"), title),
         p(strong("Type:"), type_label),
         p(strong(if (listing_type == "auction") "Starting Bid:" else "Price:"), price),
         p(strong("Condition:"), condition),
         # ... rest of modal
       ),
       footer = tagList(
         modalButton("Cancel"),
         actionButton(ns(paste0("confirm_send_to_ebay_", idx)), "Confirm & Send", class = "btn-success")
       )
     ))
   }
   ```

7. **Update Send to eBay observer** (lines 1198-1231):
   - Read `listing_type` input
   - Read conditional inputs (duration, buy_it_now, reserve)
   - Pass to confirmation modal

8. **Update Confirm Send observer** (lines 1233-1318):
   - Read all inputs (listing_type, duration, buy_it_now, reserve)
   - Validate inputs client-side
   - Pass to `create_ebay_listing_from_card()`

**Testing**:
- Test UI shows/hides fields correctly when toggling listing type
- Test price label changes from "Price" to "Starting Bid"
- Test confirmation modal displays correct information
- Test validation messages for invalid inputs

### Phase 5: Helper Functions (30 minutes)

**File**: `R/ebay_helpers.R`

1. **Add `parse_auction_inputs()`**:
   ```r
   #' Parse and validate auction-specific inputs from UI
   #' @param buy_it_now_str Character string from textInput
   #' @param reserve_str Character string from textInput
   #' @param start_price Numeric starting bid
   #' @return List with buy_it_now_price and reserve_price (NULL if empty)
   parse_auction_inputs <- function(buy_it_now_str, reserve_str, start_price) {
     # Parse Buy It Now
     bin <- NULL
     if (!is.null(buy_it_now_str) && nchar(trimws(buy_it_now_str)) > 0) {
       bin <- as.numeric(trimws(buy_it_now_str))
       if (is.na(bin) || bin < start_price * 1.3) {
         stop("Buy It Now price must be at least 30% higher than starting bid")
       }
     }

     # Parse Reserve
     reserve <- NULL
     if (!is.null(reserve_str) && nchar(trimws(reserve_str)) > 0) {
       reserve <- as.numeric(trimws(reserve_str))
       if (is.na(reserve) || reserve < start_price) {
         stop("Reserve price must be greater than or equal to starting bid")
       }
     }

     list(
       buy_it_now_price = bin,
       reserve_price = reserve
     )
   }
   ```

**Testing**:
- Test parsing valid Buy It Now price
- Test parsing empty Buy It Now (returns NULL)
- Test parsing invalid Buy It Now (< 30% higher)
- Test parsing valid Reserve price
- Test parsing empty Reserve (returns NULL)
- Test parsing invalid Reserve (< starting bid)

### Phase 6: Testing (1 hour)

**File**: `tests/testthat/test-ebay_trading_api_auction.R` (NEW)

1. **Test XML generation for auctions**:
   - Test basic auction XML structure
   - Test auction with Buy It Now
   - Test auction with Reserve
   - Test auction with both optional fields

2. **Test validation**:
   - Test validation rejects starting bid < $0.99
   - Test validation rejects Buy It Now < 30% higher
   - Test validation rejects Reserve < starting bid
   - Test validation rejects invalid duration

3. **Test database operations**:
   - Test saving auction listing to database
   - Test querying auction listings
   - Test migration on existing database

**File**: `tests/testthat/test-ebay_helpers_auction.R` (NEW)

1. **Test `parse_auction_inputs()`**:
   - Test valid inputs
   - Test empty inputs (NULL)
   - Test invalid inputs (errors)

**Add to Critical Test Suite**:
- Update `dev/run_critical_tests.R` to include auction tests
- All tests must pass before committing

---

## Database Schema Changes

```sql
-- Migration: Add auction support fields to ebay_listings table

ALTER TABLE ebay_listings
ADD COLUMN listing_type TEXT DEFAULT 'fixed_price';

ALTER TABLE ebay_listings
ADD COLUMN listing_duration TEXT DEFAULT 'GTC';

ALTER TABLE ebay_listings
ADD COLUMN buy_it_now_price REAL;

ALTER TABLE ebay_listings
ADD COLUMN reserve_price REAL;

-- Indexes for performance
CREATE INDEX idx_ebay_listings_listing_type
ON ebay_listings(listing_type);

-- Update existing records (backward compatibility)
UPDATE ebay_listings
SET listing_type = 'fixed_price',
    listing_duration = 'GTC'
WHERE listing_type IS NULL;
```

---

## UI Mockup

### Before (Fixed Price Only)

```
┌─────────────────────────────────┐
│ eBay Export                     │
├─────────────────────────────────┤
│ Title: Vintage Bucharest...     │
│ Price: 6.50                     │
│ Condition: Used                 │
│ [Send to eBay]                  │
└─────────────────────────────────┘
```

### After (With Auction Support)

```
┌─────────────────────────────────┐
│ eBay Export                     │
├─────────────────────────────────┤
│ Listing Type: [Auction ▼]      │
│                                 │
│ Title: Vintage Bucharest...     │
│ Starting Bid: 4.99              │
│                                 │
│ Auction Duration: [7 Days ▼]   │
│                                 │
│ Buy It Now Price (Optional):    │
│ 9.99                            │
│                                 │
│ Reserve Price (Optional):       │
│ 6.50                            │
│                                 │
│ Condition: Used                 │
│ [Send to eBay]                  │
└─────────────────────────────────┘
```

When toggled to "Buy It Now":

```
┌─────────────────────────────────┐
│ eBay Export                     │
├─────────────────────────────────┤
│ Listing Type: [Buy It Now ▼]   │
│                                 │
│ Title: Vintage Bucharest...     │
│ Price: 6.50                     │
│                                 │
│ Condition: Used                 │
│ [Send to eBay]                  │
└─────────────────────────────────┘
```

---

## Success Criteria

### Definition of Done

- [ ] Database schema updated with auction fields
- [ ] Migration function created and tested
- [ ] `EbayTradingAPI$add_auction_item()` method implemented
- [ ] XML generation for auctions working correctly
- [ ] Validation for auction fields implemented
- [ ] UI shows listing type selector (defaults to Auction)
- [ ] UI conditionally shows auction-specific fields
- [ ] Price label changes dynamically based on listing type
- [ ] Confirmation modal displays listing type and details
- [ ] Integration layer calls correct API method based on type
- [ ] Database saves listing type and auction-specific fields
- [ ] Comprehensive unit tests written and passing (critical suite)
- [ ] End-to-end test: Create auction listing in sandbox
- [ ] End-to-end test: Create fixed-price listing still works
- [ ] Documentation updated (this PRP serves as docs)
- [ ] Backups created before modifying files

### Verification Steps

1. **Unit Tests Pass**:
   ```r
   # Run auction-specific tests
   testthat::test_file("tests/testthat/test-ebay_trading_api_auction.R")
   testthat::test_file("tests/testthat/test-ebay_helpers_auction.R")

   # Run critical test suite
   source("dev/run_critical_tests.R")
   # Expected: All tests pass (100%)
   ```

2. **Manual Sandbox Test - Auction**:
   - Launch app in sandbox mode
   - Process a postcard with AI extraction
   - Select "Auction" listing type
   - Set starting bid: $4.99
   - Set duration: 7 days
   - Set Buy It Now: $9.99 (optional)
   - Click "Send to eBay"
   - Verify listing created successfully
   - Check eBay sandbox: Listing shows as auction format

3. **Manual Sandbox Test - Fixed Price**:
   - Select "Buy It Now" listing type
   - Set price: $6.50
   - Click "Send to eBay"
   - Verify listing created successfully
   - Check eBay sandbox: Listing shows as Buy It Now format

4. **Database Verification**:
   ```r
   # Check auction listing record
   DBI::dbGetQuery(con, "
     SELECT listing_type, listing_duration, buy_it_now_price, reserve_price
     FROM ebay_listings
     WHERE item_id = '{auction_item_id}'
   ")
   # Expected: listing_type='auction', listing_duration='Days_7', etc.

   # Check fixed-price listing record
   DBI::dbGetQuery(con, "
     SELECT listing_type, listing_duration
     FROM ebay_listings
     WHERE item_id = '{fixed_price_item_id}'
   ")
   # Expected: listing_type='fixed_price', listing_duration='GTC'
   ```

---

## Dependencies

### R Packages
- `xml2` (already installed) - XML generation
- `httr2` (already installed) - HTTP requests
- `R6` (already installed) - OOP for API client
- `DBI` (already installed) - Database operations

### External APIs
- eBay Trading API - `AddItem` call (for auctions)
- eBay Trading API - `AddFixedPriceItem` call (for fixed-price, existing)

### Authentication
- Reuses existing OAuth2 tokens (no changes needed)
- Same scopes work for both `AddItem` and `AddFixedPriceItem`

---

## Risks and Mitigations

### Risk 1: eBay API Validation Errors
**Likelihood**: Medium
**Impact**: High
**Mitigation**:
- Implement client-side validation matching eBay's rules
- Use `VerifyAddItem` API call for validation before actual listing
- Test thoroughly in sandbox environment
- Provide clear error messages to user

### Risk 2: Backwards Compatibility
**Likelihood**: Low
**Impact**: High
**Mitigation**:
- Keep `add_fixed_price_item()` method unchanged
- Database defaults ensure existing records remain valid
- Test with existing data before deploying

### Risk 3: UI Complexity
**Likelihood**: Medium
**Impact**: Low
**Mitigation**:
- Use `conditionalPanel` to show/hide fields automatically
- Provide helpful placeholder text and labels
- Show validation errors immediately (not just on submit)

### Risk 4: Duration Confusion
**Likelihood**: Medium
**Impact**: Low
**Mitigation**:
- Use friendly labels ("7 Days") instead of API values ("Days_7")
- Default to most common duration (7 days)
- Show explanation text: "Auction will end in X days"

---

## Future Enhancements (Out of Scope)

### Nice-to-Have Features
1. **Best Offer Support**: Allow buyers to make offers on fixed-price listings
2. **Scheduled Listings**: Start auction at specific date/time
3. **Multiple Quantities**: For fixed-price listings (postcards usually single quantity)
4. **Listing Templates**: Save and reuse common auction settings
5. **Smart Pricing**: Suggest starting bid based on AI-extracted condition and era
6. **Bulk Auction Creation**: Create multiple auctions at once

### Monitoring and Analytics
1. Track auction vs fixed-price success rates
2. Monitor average final sale price by listing type
3. Track conversion rates (views → bids/purchases)
4. Analyze optimal starting bid vs final price correlation

---

## References

### eBay API Documentation
- [AddItem API Reference](https://developer.ebay.com/devzone/xml/docs/reference/ebay/additem.html)
- [AddFixedPriceItem API Reference](https://developer.ebay.com/devzone/xml/docs/reference/ebay/AddFixedPriceItem.html)
- [ItemType Schema](https://developer.ebay.com/devzone/xml/docs/reference/ebay/types/ItemType.html)
- [ListingTypeCodeType Values](https://developer.ebay.com/devzone/xml/docs/reference/ebay/types/ListingTypeCodeType.html)

### Project Documentation
- `CLAUDE.md` - Core principles and constraints
- `.serena/memories/ebay_trading_api_complete_20251028.md` - Current Trading API implementation
- `.serena/memories/testing_infrastructure_complete_20251023.md` - Testing strategy

### Related PRPs
- ~~`PRP_EBAY_TRADING_API_IMPLEMENTATION.md`~~ (COMPLETED - Oct 28, 2025)
- `PRP_EBAY_UX_IMPROVEMENTS.md` (PLANNED - Can be combined with this)

---

## Notes for Implementation

### Code Style Reminders
1. **Follow Golem conventions** - Use established patterns
2. **Backup before modifying** - Save to `Delcampe_BACKUP/` folder
3. **Test-driven development** - Write tests alongside code
4. **Run critical tests** - Must pass before committing
5. **showNotification types** - Only use "message", "warning", "error" (NOT "success")

### Development Workflow
```r
# 1. Start with database migration
source("dev/migrate_add_auction_fields.R")

# 2. Implement Trading API method
# Edit R/ebay_trading_api.R

# 3. Write tests
# Create tests/testthat/test-ebay_trading_api_auction.R

# 4. Run tests frequently during development
testthat::test_file("tests/testthat/test-ebay_trading_api_auction.R")

# 5. Update integration layer
# Edit R/ebay_integration.R

# 6. Update UI
# Edit R/mod_delcampe_export.R

# 7. Test end-to-end in sandbox
devtools::load_all()
golem::run_dev()

# 8. Run critical tests before committing
source("dev/run_critical_tests.R")

# 9. Commit with clear message
# git add -A
# git commit -m "feat: Add eBay auction listing support"
```

### Testing Priority
1. **CRITICAL** - XML generation for auctions
2. **CRITICAL** - Validation logic (30% rule, minimums, durations)
3. **CRITICAL** - Database migration and save operations
4. **HIGH** - UI conditional rendering
5. **MEDIUM** - Helper function parsing
6. **LOW** - Edge cases and error messages

---

## Questions for Clarification

Before starting implementation, confirm:

1. ✅ **Default to Auction** - Is "Auction" the correct default, or should it be "Buy It Now"?
   - **Answer**: User specified "defaults to auction" - Confirmed ✅

2. ⚠️ **Buy It Now on Auctions** - Should Buy It Now field be shown by default or behind "Advanced Options"?
   - **Recommendation**: Show by default with clear label explaining 30% rule

3. ⚠️ **Reserve Price** - Should Reserve field be shown by default or behind "Advanced Options"?
   - **Recommendation**: Show behind "Advanced Options" accordion (less commonly used)

4. ⚠️ **Default Duration** - What should be the default auction duration?
   - **Recommendation**: 7 Days (most common for vintage items)

5. ⚠️ **Price Field Behavior** - When switching from Auction to Buy It Now, should the price value be preserved?
   - **Recommendation**: Yes, preserve value (user may be switching to compare options)

---

## Completion Checklist

When implementation is complete, create a Serena memory:
`.serena/memories/ebay_auction_support_complete_YYYYMMDD.md`

Include:
- ✅ What works (auction creation, fixed-price still works)
- ✅ Database schema changes
- ✅ API methods created
- ✅ UI changes and conditional rendering
- ✅ Test coverage (X tests passing)
- ✅ Sandbox verification (item IDs)
- ⚠️ Known limitations (if any)
- 📋 Future enhancements (from this PRP)

---

**End of PRP**

**Next Step**: Review with user, address clarification questions, then begin Phase 1 (Database Extension).
