# PRP: eBay Stamp Category Validation & Subcategory Implementation

**Status:** Draft
**Priority:** High
**Created:** 2025-11-02
**Owner:** System

---

## Problem Statement

Stamps are currently being listed in eBay under category 260 (Stamps - top level), but may be appearing under the wrong subcategory or getting misclassified as postal cards. The system needs to:

1. Verify stamps are being listed in the correct eBay category/subcategory
2. Determine if category 260 is sufficient or if we need specific subcategories
3. Investigate why stamps might appear as "postal cards" in eBay's system
4. Implement proper category validation and subcategory selection

---

## Current State Analysis

### Current Implementation

**Category Assignment (R/ebay_stamp_helpers.R:121):**
```r
PrimaryCategory = list(CategoryID = "260"),  # STAMPS CATEGORY
```

**Category Selection Logic (R/ebay_integration.R:124-126):**
```r
# Determine category: 260 for stamps, 262042 for postcards
category_id <- if (is_stamp) 260 else 262042
cat("   Category:", if (is_stamp) "Stamps (260)" else "Topographical Postcards (262042)", "\n")
```

### Known Facts from eBay API Documentation

1. **Category 260 = Stamps** (Top-level category)
2. **Category 262042 = Topographical Postcards** (Leaf category under Postcards)
3. **eBay requires leaf categories** for most listings
4. **GetCategories API** can retrieve subcategory hierarchy (deprecated March 2026)
5. **Taxonomy API** is the modern replacement for category browsing

### Category Structure

**Postcards:**
- Uses specific leaf category: 262042 (Topographical Postcards)
- Working correctly with no issues

**Stamps:**
- Currently using: 260 (Stamps - TOP LEVEL)
- May have subcategories like:
  - United States stamps
  - Worldwide stamps
  - Topical stamps
  - Different country/region categories

### Potential Issues

1. **Leaf Category Requirement**: Category 260 is likely a parent category, not a leaf
2. **Missing Subcategory**: Stamps should use specific subcategories (e.g., US stamps, Europe stamps)
3. **Category Validation**: eBay may reject or misclassify listings using non-leaf categories
4. **Display Issues**: Stamps might appear in wrong section or as "uncategorized"

---

## Research Tasks

### Phase 1: Category Hierarchy Investigation

#### Task 1.1: Retrieve Stamp Category Hierarchy
**Goal:** Get complete subcategory structure for category 260

**Approach:**
```r
# Use eBay Trading API GetCategories call
# Request parameters:
# - CategoryParent: 260
# - DetailLevel: ReturnAll
# - ViewAllNodes: true
# - LevelLimit: 5
```

**Expected Data:**
- List of all subcategories under category 260
- CategoryID for each subcategory
- CategoryName for each subcategory
- LeafCategory status (true/false)
- CategoryLevel (hierarchy depth)
- CategoryParentID relationships

**Deliverable:** Document complete category tree for stamps

#### Task 1.2: Identify Appropriate Subcategories
**Goal:** Determine which subcategories are valid for stamp listings

**Questions to Answer:**
1. Which categories are leaf categories (can accept listings)?
2. What are the main geographic divisions? (US, Europe, Asia, etc.)
3. Are there topical/thematic subcategories?
4. What category should US stamps use?
5. What category should international stamps use?

**Deliverable:** Mapping table of stamp types → leaf category IDs

#### Task 1.3: Compare with Postcard Implementation
**Goal:** Understand why postcards work correctly

**Analysis:**
- Postcards use leaf category 262042 (Topographical Postcards)
- How was this category ID determined?
- Is there documentation or testing history?
- What item specifics are required for this category?

**Deliverable:** Comparison document: Stamps vs Postcards category usage

### Phase 2: Category Validation Testing

#### Task 2.1: Test Current Category Assignment
**Goal:** Verify if category 260 is causing issues

**Test Cases:**
1. Create test listing with category 260 (current implementation)
2. Check eBay response for warnings/errors
3. Verify listing appears in correct section on eBay
4. Check if eBay auto-reassigns to different category

**Deliverable:** Test results showing current behavior

#### Task 2.2: Test Leaf Subcategories
**Goal:** Identify which subcategories accept stamp listings

**Test Cases:**
For each potential leaf subcategory:
1. Create test listing with subcategory ID
2. Verify listing succeeds
3. Check item specifics requirements
4. Verify listing displays correctly

**Deliverable:** List of validated leaf categories for stamps

#### Task 2.3: Item Specifics Requirements
**Goal:** Determine required/recommended item specifics per category

**API Call:** GetCategorySpecifics for each leaf category

**Expected Data:**
- Required item specifics (must provide)
- Recommended item specifics (improve visibility)
- Allowed values for each specific

**Deliverable:** Item specifics mapping per category

---

## Implementation Requirements

### Requirement 1: Dynamic Category Selection

**User Story:**
As a stamp seller, I want my stamps to be listed in the correct eBay subcategory so they appear in the right search results and attract the right buyers.

**Acceptance Criteria:**
1. System determines appropriate subcategory based on stamp data
2. US stamps use US-specific subcategory
3. International stamps use appropriate regional subcategory
4. Category selection is validated before listing creation

**Technical Implementation:**
```r
# New function: determine_stamp_category()
determine_stamp_category <- function(ai_data) {
  country <- ai_data$country

  # Map country to appropriate leaf category
  if (is.null(country) || is.na(country)) {
    return(DEFAULT_STAMP_CATEGORY)  # TBD from research
  }

  if (country == "United States" || country == "USA") {
    return(CATEGORY_US_STAMPS)  # TBD: specific leaf category
  }

  # Add other country/region mappings
  # Based on category hierarchy research

  return(CATEGORY_WORLDWIDE_STAMPS)  # TBD: default international
}
```

### Requirement 2: Category Validation

**User Story:**
As a developer, I want to validate category IDs before making API calls to avoid listing failures.

**Acceptance Criteria:**
1. System checks if category ID is valid leaf category
2. System retrieves item specifics for selected category
3. Validation happens before API call to eBay
4. Clear error messages if category is invalid

**Technical Implementation:**
```r
# New function: validate_stamp_category()
validate_stamp_category <- function(category_id, api) {
  # Check if category exists and is leaf category
  # Use GetCategoryInfo or cached category data

  if (!is_leaf_category(category_id)) {
    stop("Category ", category_id, " is not a leaf category")
  }

  # Check if category is under Stamps (260) hierarchy
  if (!is_stamp_category(category_id)) {
    stop("Category ", category_id, " is not a stamps category")
  }

  return(TRUE)
}
```

### Requirement 3: Item Specifics Compliance

**User Story:**
As a stamp seller, I want my listings to include all required item specifics so eBay accepts them without errors.

**Acceptance Criteria:**
1. System retrieves required item specifics for selected category
2. AI extraction provides necessary data for item specifics
3. Missing required specifics trigger warnings
4. System uses appropriate defaults when data unavailable

**Technical Implementation:**
```r
# Update: extract_stamp_aspects()
# Must align with category-specific requirements

extract_stamp_aspects <- function(ai_data, category_id) {
  # Get required/recommended specifics for this category
  required_specifics <- get_category_specifics(category_id)

  aspects <- list()

  # Build aspects based on category requirements
  # Ensure all required specifics are present

  return(aspects)
}
```

### Requirement 4: Category Hierarchy Cache

**User Story:**
As a system, I want to cache category hierarchy data to avoid repeated API calls.

**Acceptance Criteria:**
1. Category data is fetched once and cached
2. Cache is refreshed quarterly (per eBay guidelines)
3. Cache includes leaf status, parent IDs, item specifics
4. Fallback to API call if cache is stale

**Technical Implementation:**
```r
# New module: R/ebay_category_helpers.R

# Cache category hierarchy
STAMP_CATEGORY_CACHE <- NULL

init_stamp_category_cache <- function(api) {
  # Fetch category hierarchy for stamps
  # Store in package data or SQLite
  # Return structured list
}

get_leaf_categories_for_stamps <- function() {
  # Return cached list of valid leaf categories
}

refresh_category_cache <- function(api) {
  # Re-fetch from eBay
  # Update cache
}
```

---

## API Integration

### GetCategories Call

**Purpose:** Retrieve stamp category hierarchy

**Request:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<GetCategoriesRequest xmlns="urn:ebay:apis:eBLBaseComponents">
  <RequesterCredentials>
    <eBayAuthToken>TOKEN</eBayAuthToken>
  </RequesterCredentials>
  <CategoryParent>260</CategoryParent>
  <DetailLevel>ReturnAll</DetailLevel>
  <ViewAllNodes>true</ViewAllNodes>
  <LevelLimit>5</LevelLimit>
</GetCategoriesRequest>
```

**Response Parsing:**
```r
parse_category_hierarchy <- function(xml_response) {
  categories <- list()

  # Extract CategoryArray
  # Parse each Category node
  # Build hierarchy structure

  return(categories)
}
```

### GetCategorySpecifics Call

**Purpose:** Get required/recommended item specifics

**Request:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<GetCategorySpecificsRequest xmlns="urn:ebay:apis:eBLBaseComponents">
  <RequesterCredentials>
    <eBayAuthToken>TOKEN</eBayAuthToken>
  </RequesterCredentials>
  <CategoryID>LEAF_CATEGORY_ID</CategoryID>
</GetCategorySpecificsRequest>
```

**Response Parsing:**
```r
parse_category_specifics <- function(xml_response) {
  specifics <- list(
    required = list(),
    recommended = list()
  )

  # Extract NameValueList elements
  # Identify required vs recommended
  # Extract allowed values

  return(specifics)
}
```

---

## Testing Strategy

### Unit Tests

**File:** `tests/testthat/test-ebay_category_helpers.R`

```r
test_that("determine_stamp_category returns US category for US stamps", {
  ai_data <- list(country = "United States")
  category <- determine_stamp_category(ai_data)
  expect_equal(category, CATEGORY_US_STAMPS)
})

test_that("determine_stamp_category returns default for unknown country", {
  ai_data <- list(country = NA)
  category <- determine_stamp_category(ai_data)
  expect_equal(category, DEFAULT_STAMP_CATEGORY)
})

test_that("validate_stamp_category rejects non-leaf categories", {
  expect_error(
    validate_stamp_category(260, mock_api()),  # 260 is parent
    "not a leaf category"
  )
})
```

### Integration Tests

**File:** `tests/testthat/test-ebay_stamp_integration.R`

```r
test_that("stamp listing uses correct category", {
  # Create mock stamp data
  # Build item data
  # Verify category_id is leaf category
  # Verify category is under stamps hierarchy
})

test_that("stamp aspects match category requirements", {
  # Get category specifics
  # Build stamp aspects
  # Verify all required specifics present
})
```

### Manual Verification

**Checklist:**
- [ ] Create test listing in eBay sandbox with category 260
- [ ] Verify if eBay accepts or rejects
- [ ] Check where listing appears in category hierarchy
- [ ] Create test listing with specific leaf subcategory
- [ ] Verify listing displays correctly
- [ ] Search for listing and verify findability

---

## Documentation Updates

### Code Documentation

**New Files:**
- `R/ebay_category_helpers.R` - Category hierarchy and validation
- `man/determine_stamp_category.Rd` - Auto-generated
- `man/validate_stamp_category.Rd` - Auto-generated

**Updated Files:**
- `R/ebay_stamp_helpers.R` - Update to use dynamic categories
- `R/ebay_integration.R` - Update category selection logic
- `man/build_stamp_item_data.Rd` - Update with new parameters

### User Documentation

**New Memory:**
`.serena/memories/ebay_stamp_category_research_YYYYMMDD.md`

**Content:**
- Complete category hierarchy for stamps
- Mapping of countries to subcategories
- Item specifics requirements per category
- Testing results and validation

**Update Memory:**
`.serena/memories/INDEX.md`

Add entry for stamp category research

---

## Success Criteria

### Definition of Done

1. **Research Complete:**
   - [ ] Complete stamp category hierarchy documented
   - [ ] Leaf categories identified and validated
   - [ ] Item specifics requirements documented
   - [ ] Mapping table: stamp types → categories created

2. **Implementation Complete:**
   - [ ] `determine_stamp_category()` function working
   - [ ] Category validation implemented
   - [ ] Item specifics aligned with category requirements
   - [ ] Category cache system functional

3. **Testing Complete:**
   - [ ] Unit tests passing (>95% coverage)
   - [ ] Integration tests passing
   - [ ] Manual eBay sandbox testing successful
   - [ ] Stamps appear in correct eBay categories

4. **Documentation Complete:**
   - [ ] Code documentation updated
   - [ ] Serena memory created
   - [ ] PRP marked as complete
   - [ ] Findings documented for future reference

### Validation

**Test Stamps:**
1. US stamp from 1950s → Should use US stamps subcategory
2. European stamp → Should use appropriate regional subcategory
3. Worldwide lot → Should use worldwide/mixed subcategory

**Expected Results:**
- Listings succeed without category errors
- Stamps appear in correct category on eBay
- Item specifics validation passes
- Search results show stamps in relevant categories

---

## Risk Assessment

### High Risk
- **eBay API Changes:** GetCategories deprecated in March 2026
  - **Mitigation:** Plan migration to Taxonomy API
  - **Timeline:** Complete before Q1 2026

### Medium Risk
- **Category Requirements Vary:** Different subcategories have different item specifics
  - **Mitigation:** Implement flexible aspect extraction
  - **Validation:** Test multiple subcategories

### Low Risk
- **Cache Staleness:** Categories change quarterly
  - **Mitigation:** Implement quarterly refresh
  - **Monitoring:** Log category validation failures

---

## Future Enhancements

### Phase 2 Improvements
1. **AI-Assisted Category Selection:**
   - Use image analysis to suggest subcategory
   - Identify stamp theme/topic for topical categories

2. **User Category Override:**
   - Allow manual category selection in UI
   - Provide category browser/picker

3. **Multi-Category Support:**
   - List in both primary and secondary categories
   - Store category suggestions for future listings

### Migration to Taxonomy API
**Timeline:** Before March 2026

**Changes Required:**
- Replace GetCategories with Taxonomy API calls
- Update category data structure
- Implement new validation logic
- Test with new API endpoints

---

## References

### eBay API Documentation
- [GetCategories API Reference](https://developer.ebay.com/devzone/xml/docs/Reference/ebay/GetCategories.html)
- [GetCategorySpecifics API Reference](https://developer.ebay.com/devzone/xml/docs/reference/ebay/GetCategorySpecifics.html)
- [Category IDs Overview](https://developer.ebay.com/api-docs/user-guides/static/trading-user-guide/category-id-overview.html)
- [Taxonomy API Overview](https://developer.ebay.com/api-docs/commerce/taxonomy/overview.html)

### Project Files
- `R/ebay_stamp_helpers.R` - Current stamp category implementation
- `R/ebay_integration.R` - Category selection logic
- `R/ebay_helpers.R` - Postcard category implementation (reference)
- `dev/check_stamp_listing.R` - Diagnostic script
- `dev/find_stamp_listing.R` - Investigation script

### External Resources
- [I Sold What - eBay Category Browser](https://www.isoldwhat.com/)
- [eBay Standard Envelope - Stamp Category](https://www.ebay.com/help/selling/shipping-items/setting-shipping-options/ebay-standard-envelope)

---

## Appendix A: Category Investigation Script

**File:** `dev/investigate_stamp_categories.R`

```r
# eBay Stamp Category Investigation
# Purpose: Retrieve and analyze stamp category hierarchy

library(Delcampe)
library(xml2)
library(httr)

# Initialize eBay API
api <- EbayTradingAPI$new(
  sandbox = TRUE,
  app_id = Sys.getenv("EBAY_APP_ID"),
  dev_id = Sys.getenv("EBAY_DEV_ID"),
  cert_id = Sys.getenv("EBAY_CERT_ID"),
  token = Sys.getenv("EBAY_TOKEN")
)

# Fetch stamp category hierarchy
get_stamp_categories <- function(api) {
  request <- '<?xml version="1.0" encoding="utf-8"?>
  <GetCategoriesRequest xmlns="urn:ebay:apis:eBLBaseComponents">
    <RequesterCredentials>
      <eBayAuthToken>%s</eBayAuthToken>
    </RequesterCredentials>
    <CategoryParent>260</CategoryParent>
    <DetailLevel>ReturnAll</DetailLevel>
    <ViewAllNodes>true</ViewAllNodes>
    <LevelLimit>5</LevelLimit>
  </GetCategoriesRequest>'

  request <- sprintf(request, api$get_token())
  response <- api$make_request("GetCategories", request)

  return(response)
}

# Parse and display category tree
parse_category_tree <- function(xml_response) {
  categories <- xml_find_all(xml_response, "//Category")

  cat("=== STAMP CATEGORY HIERARCHY ===\n\n")

  for (cat in categories) {
    cat_id <- xml_text(xml_find_first(cat, ".//CategoryID"))
    cat_name <- xml_text(xml_find_first(cat, ".//CategoryName"))
    cat_level <- xml_text(xml_find_first(cat, ".//CategoryLevel"))
    is_leaf <- xml_text(xml_find_first(cat, ".//LeafCategory"))

    indent <- strrep("  ", as.integer(cat_level) - 1)
    leaf_marker <- if (is_leaf == "true") " [LEAF]" else ""

    cat(sprintf("%s%s (%s)%s\n", indent, cat_name, cat_id, leaf_marker))
  }
}

# Run investigation
cat("Fetching stamp categories from eBay...\n")
response <- get_stamp_categories(api)
parse_category_tree(response)

# Save results
saveRDS(response, "dev/stamp_category_hierarchy.rds")
cat("\n✅ Results saved to dev/stamp_category_hierarchy.rds\n")
```

---

## Appendix B: Expected Category Structure

**Preliminary Structure (to be validated):**

```
260 - Stamps
├── 260001 - United States
│   ├── 260001001 - 19th Century [LEAF]
│   ├── 260001002 - 1901-1940 [LEAF]
│   ├── 260001003 - 1941-1980 [LEAF]
│   └── 260001004 - 1981-Now [LEAF]
├── 260002 - Great Britain
│   └── ... [LEAF subcategories]
├── 260003 - Canada
│   └── ... [LEAF subcategories]
├── 260004 - Europe
│   └── ... [LEAF subcategories by country]
└── 260005 - Worldwide
    └── ... [LEAF subcategories by region]
```

**Note:** Actual structure to be determined by API research.

---

**PRP Version:** 1.0
**Last Updated:** 2025-11-02
**Next Review:** After Phase 1 Research Complete
