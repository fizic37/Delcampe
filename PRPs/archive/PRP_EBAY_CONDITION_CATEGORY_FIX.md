# PRP: Fix eBay Error 25019 - Overseas Warehouse Block Policy

**Status:** Draft for Task Create
**Priority:** High (Blocks Production Listings)
**Created:** 2025-10-27
**Type:** Bug Fix / Feature Enhancement

---

## Problem Statement

eBay listings are currently failing with **Error 25019 ("Overseas Warehouse Block Policy")** when attempting to create listings from Romania. This error occurs because:

1. **All postcards are being listed with condition = "NEW"** (hardcoded in `map_condition_to_ebay()`)
2. **Category 262042 (Topographical Postcards) only accepts NEW condition**, which triggers eBay's overseas warehouse policy
3. **eBay requires additional warehouse verification** for new items shipped cross-border from countries like Romania
4. **Used/vintage postcards should NOT trigger this policy**, but current implementation cannot distinguish

### Current Behavior

**File:** `R/ebay_helpers.R:5-30`
```r
map_condition_to_ebay <- function(condition) {
  # Category 262042 (Topographical Postcards) ONLY accepts NEW condition
  condition_map <- list(
    "excellent" = "NEW",
    "very good" = "NEW",
    "good" = "NEW",
    "fair" = "NEW",
    "poor" = "NEW",
    "used" = "NEW",
    "new" = "NEW",
    "like new" = "NEW"
  )
  # Always returns "NEW" regardless of input
}
```

**Result:**
- Every postcard listing uses `condition = "NEW"`
- eBay flags listing as potential overseas warehouse violation
- Error 25019 prevents listing creation
- No way to list used/vintage postcards correctly

### Root Cause

**Two interconnected issues:**

1. **Category Restriction**: Category 262042 (Topographical Postcards) appears to only accept NEW condition based on initial testing
2. **Wrong Category?**: Postcards might belong in a different category that supports USED conditions (e.g., Collectibles > Postcards)

**Critical Constraint:**
- **Cannot omit condition_id** - eBay API defaults to NEW if condition is missing, re-triggering the same error
- **Must explicitly specify condition_id** like `"3000"` (USED) to avoid the policy block

---

## Proposed Solutions

### Option 1: Dynamic Condition Selection (Preferred)

Implement proper condition mapping by discovering valid conditions for categories dynamically.

#### Technical Approach

**Step 1: API Discovery**
Use eBay's Trading API or RESTful Metadata API to fetch valid conditions:

- **GetCategoryFeatures** (Trading API)
  - Endpoint: `https://api.ebay.com/ws/api.dll` (XML)
  - Returns: List of valid ConditionIDs for a category
  - Example: `https://developer.ebay.com/devzone/xml/docs/Reference/eBay/GetCategoryFeatures.html`

- **getItemAspectsForCategory** (Taxonomy API - RESTful, Preferred)
  - Endpoint: `GET /commerce/taxonomy/v1/category_tree/{category_tree_id}/get_item_aspects_for_category`
  - Query: `?category_id=262042`
  - Returns: JSON with valid aspects including conditions
  - Marketplace ID for US: `EBAY_US` (category_tree_id = 0)

**Step 2: Implementation Plan**
1. Create `EbayMetadataAPI` R6 class in `R/ebay_api.R`
2. Add `get_category_conditions(category_id)` method
3. Cache results to avoid repeated API calls
4. Update `map_condition_to_ebay()` to use fetched condition IDs

**Step 3: UI Enhancement**
Update Delcampe Export module to show valid condition choices:
- Add condition selector dropdown in listing UI
- Populate with AI-extracted condition by default
- Allow user to override before sending to eBay
- Map user selection to eBay condition_id

#### eBay Condition ID Reference

Standard eBay condition IDs for collectibles:
- `1000` = NEW
- `2750` = LIKE_NEW
- `3000` = USED_EXCELLENT
- `4000` = USED_VERY_GOOD
- `5000` = USED_GOOD
- `6000` = USED_ACCEPTABLE
- `7000` = FOR_PARTS_OR_NOT_WORKING

**Question to Answer:** Which of these are valid for category 262042?

---

### Option 2: Category Change (Alternative)

Switch to a category that explicitly supports used/vintage postcards.

#### Technical Approach

**Step 1: Category Discovery**
Use eBay's **GetSuggestedCategories** API to find appropriate categories:

- **GetSuggestedCategories** (Trading API)
  - Input: Sample title like "Vintage postcard Paris 1900"
  - Output: List of suggested categories with confidence scores
  - Can test with multiple representative titles

- **Expected Categories:**
  - `Collectibles > Postcards > Topographical Postcards > [Country/Region]`
  - `Collectibles > Postcards > Non-Topographical Postcards`
  - Need to verify which supports USED conditions

**Step 2: Verification**
For each suggested category:
1. Call `getItemAspectsForCategory` (from Option 1)
2. Check if condition_id `3000` (USED) is in valid aspects
3. Document which categories support used postcards

**Step 3: Implementation**
1. Update hardcoded category ID in `R/ebay_integration.R:197, 220`
2. Add dynamic category selection based on postcard type
3. Optionally: AI-based category suggestion using title/description

#### Category Discovery Test Cases

Test with these sample titles:
- "Vintage postcard Paris Eiffel Tower 1900"
- "Used postcard Romania Bucharest 1950s"
- "Antique postcard collection Europe travel"
- "Old picture postcard Germany Berlin 1920"

---

## Recommended Implementation Strategy

### Phase 1: Investigation (Essential First Step)

**Objective:** Determine if current category supports USED conditions or if category change is needed.

1. **Test Category 262042 Conditions**
   - Call Taxonomy API: `/commerce/taxonomy/v1/category_tree/0/get_item_aspects_for_category?category_id=262042`
   - Parse JSON response for condition aspect
   - Document valid condition IDs
   - **If USED conditions available:** Proceed with Option 1 only
   - **If only NEW allowed:** Must implement Option 2 as well

2. **Test Alternative Categories**
   - Call `GetSuggestedCategories` with sample postcard titles
   - For each suggested category, fetch valid conditions
   - Document which categories support USED postcards
   - Identify best category for vintage/used postcards

**Deliverable:** Decision matrix showing:
- Category ID
- Category name/path
- Valid condition IDs
- Supports USED? (Yes/No)
- Recommendation (Primary/Backup/Not Suitable)

### Phase 2: UI Enhancement (Mandatory)

**Objective:** Allow users to select condition before listing creation.

**Current Flow:**
```
AI Extraction → Condition stored in DB → Automatically mapped to "NEW" → eBay API
```

**New Flow:**
```
AI Extraction → Condition suggested in UI → User selects from valid options → eBay API
```

**Implementation:**

1. **Add UI Components** (`R/mod_delcampe_export.R`)
   - Condition selector dropdown (below title/description preview)
   - Pre-populated with AI-extracted condition
   - Label: "eBay Condition (user can override AI suggestion)"
   - Positioned before "Send to eBay" button

2. **Server Logic**
   - `input$ebay_condition` captures user selection
   - Pass selected condition to `create_ebay_listing_from_card()`
   - Map condition to appropriate condition_id

**UI Mockup Location:**
```r
# In mod_delcampe_export.R server function
# Add before the "Send to eBay" observeEvent

output$ebay_condition_selector <- renderUI({
  req(values$selected_card_id)

  # Get AI-extracted condition from database
  card_data <- get_card_data(values$selected_card_id)
  ai_condition <- card_data$ai_condition %||% "used"

  # Define available conditions (will be dynamic after Phase 1)
  condition_choices <- c(
    "Used - Excellent" = "3000",
    "Used - Very Good" = "4000",
    "Used - Good" = "5000",
    "Used - Acceptable" = "6000",
    "New" = "1000"
  )

  selectInput(
    ns("ebay_condition"),
    label = "eBay Condition:",
    choices = condition_choices,
    selected = map_ai_to_ebay_condition(ai_condition)
  )
})
```

### Phase 3: Backend Implementation

**3A: Metadata API Integration** (If Option 1 is viable)

1. **Create EbayTaxonomyAPI Class** (`R/ebay_api.R`)
   ```r
   EbayTaxonomyAPI <- R6::R6Class(
     "EbayTaxonomyAPI",
     public = list(
       initialize = function(oauth, config) { ... },

       get_category_aspects = function(category_id) {
         # GET /commerce/taxonomy/v1/category_tree/0/get_item_aspects_for_category
         # Returns: list of valid aspects including conditions
       },

       get_suggested_categories = function(query_text) {
         # POST /commerce/taxonomy/v1/category_tree/0/get_category_suggestions
         # Input: title/description text
         # Returns: suggested categories with confidence scores
       }
     ),
     private = list(
       cache_category_aspects = list() # Cache to avoid repeated calls
     )
   )
   ```

2. **Update init_ebay_api()** (`R/ebay_api.R:828-840`)
   ```r
   init_ebay_api <- function(environment = NULL) {
     # ... existing code ...
     taxonomy_api <- EbayTaxonomyAPI$new(oauth, config)

     return(list(
       config = config,
       oauth = oauth,
       inventory = inventory_api,
       media = media_api,
       taxonomy = taxonomy_api  # NEW
     ))
   }
   ```

3. **Update map_condition_to_ebay()** (`R/ebay_helpers.R`)
   ```r
   map_condition_to_ebay <- function(condition, category_id = "262042", ebay_api = NULL) {
     # If API provided, fetch valid conditions dynamically
     if (!is.null(ebay_api)) {
       valid_conditions <- ebay_api$taxonomy$get_category_aspects(category_id)$conditions
       # Map user input to valid condition_id
     } else {
       # Fallback to static mapping (for backward compatibility)
       warning("No eBay API provided, using fallback condition mapping")
     }

     # Return condition_id (e.g., "3000") not text (e.g., "USED")
   }
   ```

**3B: Category Change Implementation** (If Option 2 is needed)

1. **Make category_id configurable** (`R/ebay_integration.R`)
   ```r
   create_ebay_listing_from_card <- function(
     card_id,
     image_url = NULL,
     category_id = NULL,  # NEW parameter
     ebay_api = NULL
   ) {
     # Use provided category or default to environment variable
     if (is.null(category_id)) {
       category_id <- Sys.getenv("EBAY_DEFAULT_CATEGORY", "262042")
     }

     # Use dynamic category in offer creation
     offer_data <- list(
       # ...
       categoryId = category_id,  # Was hardcoded "262042"
       # ...
     )
   }
   ```

2. **Add category selection UI** (Optional enhancement)
   - Allow users to choose category
   - Or implement smart category suggestion based on AI data

---

## Files to Modify

### Core Changes

1. **`R/ebay_api.R`** (New API Class)
   - Add `EbayTaxonomyAPI` R6 class (~100 lines)
   - Update `init_ebay_api()` to instantiate taxonomy API
   - Location: After `EbayMediaAPI` class (line 825)

2. **`R/ebay_helpers.R`** (Condition Mapping Update)
   - Modify `map_condition_to_ebay()` function (lines 5-30)
   - Add dynamic condition fetching logic
   - Add fallback for backward compatibility
   - Return numeric condition_id instead of text

3. **`R/ebay_integration.R`** (Category & Condition)
   - Add `category_id` parameter to `create_ebay_listing_from_card()` (line 17)
   - Replace hardcoded category IDs (lines 197, 220, 237)
   - Add logic to use provided category or environment default

4. **`R/mod_delcampe_export.R`** (UI Changes)
   - Add condition selector dropdown (~30 lines)
   - Add server logic to capture user selection
   - Pass selected condition to listing creation function
   - Location: Before "Send to eBay" button observeEvent

### Supporting Changes

5. **`.Renviron`** or **Settings UI** (Configuration)
   - Add `EBAY_DEFAULT_CATEGORY` environment variable
   - Allow users to configure preferred category
   - Default: "262042" (current behavior)

6. **`R/tracking_database.R`** (Optional - Track Category)
   - Add `category_id` column to tracking database
   - Track which category was used for each listing
   - Useful for analytics and debugging

---

## Testing Requirements

### Phase 1: Investigation Tests

**Test 1: Fetch Category Conditions**
```r
# Test script: dev/test_category_conditions.R
devtools::load_all()
ebay_api <- init_ebay_api("sandbox")

# Test current category
aspects_262042 <- ebay_api$taxonomy$get_category_aspects("262042")
print(aspects_262042$conditions)

# Expected: List of valid condition IDs for category 262042
```

**Test 2: Discover Alternative Categories**
```r
# Test with sample postcard titles
test_titles <- c(
  "Vintage postcard Paris Eiffel Tower 1900",
  "Used postcard Romania Bucharest 1950s"
)

for (title in test_titles) {
  suggestions <- ebay_api$taxonomy$get_suggested_categories(title)
  cat("\nTitle:", title, "\n")
  cat("Suggested categories:\n")
  print(suggestions)

  # For each suggestion, check valid conditions
  for (cat_id in suggestions$category_ids) {
    aspects <- ebay_api$taxonomy$get_category_aspects(cat_id)
    cat("  Category", cat_id, "- Conditions:", paste(aspects$conditions, collapse = ", "), "\n")
  }
}
```

### Phase 2: UI Tests

**Test 3: Condition Selector UI**
1. Launch app: `devtools::load_all(); run_app()`
2. Navigate to Delcampe Export
3. Select a card with AI-extracted condition
4. Verify condition selector appears with correct default
5. Change condition selection
6. Verify selection is captured correctly

**Test 4: Integration with Listing Creation**
1. Select card with USED condition
2. Choose "Used - Excellent" in condition dropdown
3. Click "Send to eBay"
4. Monitor console output
5. Verify: `condition_id: 3000` (not "NEW")
6. Verify: Listing created successfully (no Error 25019)

### Phase 3: Production Tests

**Test 5: End-to-End Used Postcard Listing**
1. Process vintage postcard (1900s-1950s era)
2. AI extracts condition: "good"
3. UI shows condition selector with "Used - Good" pre-selected
4. User confirms or changes condition
5. Create eBay listing
6. Verify listing succeeds (no Error 25019)
7. Check eBay listing: condition displays as "Used - Good"

**Test 6: Category Change Test** (If Option 2 implemented)
1. Configure alternative category (from Phase 1 investigation)
2. Create listing with new category
3. Verify listing succeeds with USED condition
4. Verify category appears correctly on eBay

**Test 7: Error Handling**
1. Test with invalid condition_id
2. Test with invalid category_id
3. Test API timeout/failure scenarios
4. Verify graceful error messages to user

---

## Acceptance Criteria

### Must Have

✅ **Investigation Complete:**
  - Document valid condition IDs for category 262042
  - Identify at least one category supporting USED conditions
  - Decision matrix created for category/condition combinations

✅ **UI Enhancement:**
  - Condition selector dropdown appears in Delcampe Export
  - AI-extracted condition pre-selected by default
  - User can override condition before listing
  - Selection is properly captured in server logic

✅ **Backend Implementation:**
  - `EbayTaxonomyAPI` class functional and tested
  - `map_condition_to_ebay()` returns numeric condition_id
  - Condition selection properly passed to eBay API
  - **No more Error 25019 for used postcards**

✅ **Error Handling:**
  - Invalid conditions display clear error message
  - API failures don't break listing flow
  - User notified if condition unavailable for category

### Should Have

✅ **Category Flexibility:**
  - Category ID configurable via environment variable
  - Option to change category for specific listings
  - Smart category suggestion based on postcard type

✅ **Caching:**
  - Category aspects cached to reduce API calls
  - Cache persists across sessions
  - Cache invalidation after 24 hours

✅ **User Feedback:**
  - Loading indicator while fetching conditions
  - Clear labels for condition choices
  - Helper text explaining condition requirements

### Nice to Have

- Preview of how condition will appear on eBay
- Bulk condition update for multiple cards
- Condition validation before listing creation
- Analytics: track which conditions used most often

---

## Risk Assessment

### High Risk Items

1. **Category 262042 May Only Support NEW**
   - **Risk:** Current category might truly not support USED conditions
   - **Impact:** Would require category change (Option 2) for ALL postcards
   - **Mitigation:** Phase 1 investigation discovers this early
   - **Fallback:** Implement Option 2 (category change) as primary solution

2. **eBay API Rate Limits**
   - **Risk:** Taxonomy API calls might be rate-limited
   - **Impact:** Slow UI, failed condition lookups
   - **Mitigation:** Implement caching, minimize API calls
   - **Fallback:** Static condition mapping as last resort

3. **Condition ID Changes**
   - **Risk:** eBay might change condition ID values over time
   - **Impact:** Hardcoded IDs become invalid
   - **Mitigation:** Always fetch dynamically when possible
   - **Fallback:** Document condition IDs in code comments

### Medium Risk Items

1. **UI Complexity**
   - **Risk:** Too many options confuse users
   - **Impact:** Poor UX, incorrect selections
   - **Mitigation:** Pre-select AI condition, clear labels
   - **Fallback:** Limit to 3-4 most common conditions

2. **Backward Compatibility**
   - **Risk:** Existing code expects text conditions ("NEW"), not IDs ("1000")
   - **Impact:** Breaks existing integrations
   - **Mitigation:** Update all condition references, add fallback
   - **Fallback:** Keep old function, create new function

3. **Multi-Account Considerations**
   - **Risk:** Different accounts might have different category restrictions
   - **Impact:** Condition selector shows invalid options
   - **Mitigation:** Fetch conditions per-account when possible
   - **Fallback:** Use most permissive condition set

### Low Risk Items

- Taxonomy API is RESTful (same pattern as existing APIs)
- UI dropdown is standard Shiny component
- Cache implementation straightforward (list storage)
- Error handling follows existing patterns

---

## Dependencies

### Existing Components

✅ **Available Now:**
- eBay OAuth integration (multi-account support)
- eBay Inventory API (listing creation)
- eBay Media API (image upload)
- Shiny UI framework and modules
- AI condition extraction in database
- Tracking database for listing history

### New Requirements

**API Integration:**
- eBay Commerce Taxonomy API access (same OAuth scope)
- JSON parsing for API responses
- Caching mechanism for API results

**UI Components:**
- Condition selector dropdown (Shiny selectInput)
- Loading indicator for API calls (Shiny busy indicator)
- Optional: Category selector dropdown

**Development/Testing:**
- Test script for API investigation
- Sandbox testing environment
- Sample postcard data with various conditions

---

## Success Metrics

1. **Functional:**
   - ✅ Used postcards list successfully (0% Error 25019 for USED conditions)
   - ✅ Condition displayed correctly on eBay (100% match)
   - ✅ Users can override AI condition (UI functional)

2. **Performance:**
   - ⏱️ Condition selector loads in < 2 seconds
   - ⏱️ Cached conditions load instantly (< 100ms)
   - ⏱️ Listing creation time unchanged (< 5 seconds)

3. **Reliability:**
   - 🎯 API failure rate < 1% (with fallback to cached data)
   - 🎯 Condition validation catches 100% of invalid selections
   - 🎯 No regressions in existing listing flow

4. **User Satisfaction:**
   - 😊 Users successfully list used/vintage postcards
   - 😊 Clear understanding of condition choices
   - 😊 No confusion about overseas warehouse errors

---

## Implementation Priority & Timeline

### Sprint 1: Investigation (1-2 days)
**Priority:** CRITICAL (Blocks all decisions)

Tasks:
1. Create `EbayTaxonomyAPI` class shell
2. Implement `get_category_aspects()` method
3. Test with category 262042
4. Test with 3-5 alternative categories
5. Document findings in decision matrix

**Deliverable:** Decision document with recommended approach

### Sprint 2: UI Enhancement (2-3 days)
**Priority:** HIGH (User-facing requirement)

Tasks:
1. Design condition selector UI
2. Implement dropdown in `mod_delcampe_export.R`
3. Add server logic to capture selection
4. Integrate with AI-extracted condition
5. Test UI flow end-to-end

**Deliverable:** Functional condition selector in app

### Sprint 3: Backend Integration (3-4 days)
**Priority:** HIGH (Core functionality)

Tasks:
1. Complete `EbayTaxonomyAPI` implementation
2. Add caching mechanism
3. Update `map_condition_to_ebay()` function
4. Update `create_ebay_listing_from_card()` function
5. Add error handling and fallbacks
6. Write unit tests for new functions

**Deliverable:** Complete end-to-end integration

### Sprint 4: Testing & Refinement (2-3 days)
**Priority:** MEDIUM (Quality assurance)

Tasks:
1. Execute all test scenarios (Tests 1-7)
2. Fix any discovered issues
3. Optimize caching and performance
4. Add user documentation
5. Deploy to production

**Deliverable:** Production-ready feature

**Total Estimated Time:** 8-12 days

---

## Alternative Approaches Considered

### Option A: Always Use USED Condition (REJECTED)
**Why:** Too simplistic, doesn't handle genuinely new postcards

### Option B: Hardcode USED Condition IDs (REJECTED)
**Why:** Brittle, no validation, breaks if eBay changes IDs

### Option C: Remove Condition Entirely (REJECTED)
**Why:** eBay API defaults to NEW, re-triggering Error 25019

### Option D: External Category/Condition Database (REJECTED)
**Why:** Adds maintenance burden, can become stale

### Option E: Manual Configuration File (CONSIDERED)
**Why:** Could work as fallback, but dynamic API better

---

## Future Enhancements

1. **Smart Category Selection**
   - Use AI to suggest category based on postcard content
   - Example: "Building postcard" → Architecture category
   - Example: "Travel postcard" → Topographical category

2. **Batch Condition Updates**
   - Select multiple cards in tracking viewer
   - Update conditions in bulk before listing
   - Useful for processing large collections

3. **Condition Mapping Learning**
   - Track which AI conditions map to which eBay conditions
   - Learn user preferences over time
   - Auto-adjust mapping based on success rates

4. **Category-Specific Validation**
   - Fetch all aspects for selected category
   - Validate title length, description requirements
   - Show category-specific guidelines to user

5. **Multi-Category Listing**
   - List same postcard in multiple categories
   - Increase visibility and sales potential
   - eBay allows cross-listing in some cases

---

## Documentation Updates

### Code Documentation
- Add Roxygen documentation for `EbayTaxonomyAPI` class
- Update `map_condition_to_ebay()` function documentation
- Document condition ID reference in code comments

### User Documentation
- Update Settings/eBay guide with condition selection
- Add troubleshooting section for Error 25019
- Document category recommendations for different postcard types

### Developer Documentation
- Add Serena memory: `ebay_condition_category_fix_YYYYMMDD.md`
- Update `CLAUDE.md` if patterns change
- Document eBay API quota/limits if encountered

---

## References

### eBay API Documentation
- **Taxonomy API:** https://developer.ebay.com/api-docs/commerce/taxonomy/overview.html
- **GetCategoryFeatures:** https://developer.ebay.com/devzone/xml/docs/Reference/eBay/GetCategoryFeatures.html
- **GetSuggestedCategories:** https://developer.ebay.com/devzone/xml/docs/Reference/eBay/GetSuggestedCategories.html
- **Item Conditions:** https://developer.ebay.com/devzone/finding/callref/Enums/conditionIdList.html

### Existing Implementation
- **eBay API Integration:** `R/ebay_api.R`, `R/ebay_integration.R`
- **Condition Mapping:** `R/ebay_helpers.R:5-30`
- **Delcampe Export Module:** `R/mod_delcampe_export.R`
- **Image Upload Memory:** `.serena/memories/ebay_image_upload_complete_20251020.md`
- **Multi-Account Memory:** `.serena/memories/ebay_multi_account_phase2_complete_20251018.md`

### Related Issues
- **Error 25019:** Overseas Warehouse Block Policy
- **Category 262042:** Topographical Postcards
- **Condition Mapping:** Currently hardcoded to "NEW"

---

## Notes

- This issue is a **blocker for production listings** from Romania and similar locations
- Investigation (Phase 1) is **CRITICAL** - all implementation depends on findings
- The fix has **two parallel tracks**: condition improvement AND category flexibility
- **UI changes are mandatory** regardless of which technical approach is chosen
- **Backward compatibility** must be maintained for existing sandbox listings
- The solution should work for **both sandbox and production** environments
- Multi-account support is already in place, should work seamlessly with this fix

---

## Appendix: eBay Condition ID Quick Reference

| Condition ID | Condition Name | Typical Use Case |
|--------------|----------------|------------------|
| 1000 | NEW | Unused, mint condition postcards |
| 2750 | LIKE_NEW | Unused but not in original packaging |
| 3000 | USED_EXCELLENT | Minor wear, very good state |
| 4000 | USED_VERY_GOOD | Some visible wear, still good |
| 5000 | USED_GOOD | Noticeable wear, acceptable |
| 6000 | USED_ACCEPTABLE | Significant wear, readable |
| 7000 | FOR_PARTS_OR_NOT_WORKING | Damaged, for collectors only |

**Important:** Not all categories support all condition IDs. Phase 1 investigation will determine which are valid for postcard categories.

---

**Status:** Ready for Task Creation
**Next Step:** Execute Phase 1 investigation to determine viable approach
**Estimated Total Effort:** 8-12 days (depends on Phase 1 findings)
