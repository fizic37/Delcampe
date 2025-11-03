# Stamp Category Selection UI - Implementation Complete

**Date:** 2025-11-03
**Status:** ✅ Complete (Code changes)
**Testing Status:** ⏳ Pending manual validation

## Summary

Replaced hardcoded category 675 with two-level cascading dropdown UI for stamp eBay listings. Users can now select region (United States, Europe, Asia, etc.) and country/subcategory for accurate eBay category placement.

## Changes Made

### 1. R/ebay_integration.R
**Lines Modified:** 26-133 (function signature and category logic)

**Changes:**
- Added `category_id = NULL` parameter to `create_ebay_listing_from_card()` function signature
- Removed hardcoded `category_id <- 675` 
- Added validation: `if (is.null(category_id) || is.na(category_id)) { stop("category_id is required for stamp listings") }`
- Updated console output to show: `"Category: {category_id} (from user selection)"`
- Updated roxygen documentation to include `@param category_id` with description

**Code Change:**
```r
# BEFORE
if (is_stamp) {
  category_id <- 675  # Hardcoded US Stamps 19th Century
}

# AFTER
if (is_stamp) {
  if (is.null(category_id) || is.na(category_id)) {
    stop("category_id is required for stamp listings")
  }
  cat("   Category:", category_id, "(from user selection)\n")
}
```

### 2. R/mod_stamp_export.R
**Lines Modified:** 2204 (function call)

**Changes:**
- Added `is_stamp = TRUE` parameter to `create_ebay_listing_from_card()` call
- Category extraction logic (lines 2118-2136) was already present and working correctly:
  - Gets `ebay_region` and `ebay_country_id` from UI inputs
  - Handles "Other Stamps" special case (region_id instead of country_id)
  - Validates category is not null/NA before proceeding
  - Passes `category_id` to eBay API function

**Note:** The UI logic for cascading dropdowns, validation, and AI auto-selection was already implemented. Only needed to add the `is_stamp = TRUE` flag.

### 3. R/ebay_database_extension.R
**Line Modified:** 27

**Changes:**
- Changed `category_id TEXT DEFAULT '914'` to `category_id TEXT DEFAULT NULL`
- Category 914 doesn't exist in eBay stamps, NULL is more appropriate default

### 4. tests/testthat/test-stamp_helpers.R
**Lines Added:** 123-154 (new tests)

**Changes:**
- Added test: `map_country_to_category recognizes European countries`
  - Tests Romania (with both Latin and native spelling)
  - Tests France
  - Validates region_code, country_label, and category_id
- Added test: `map_country_to_category handles US stamps (ambiguous)`
  - Verifies US stamps return NULL for country_label (requires manual selection)
- Added test: `map_country_to_category handles unknown countries`
  - Verifies unknown countries return all NULL values

## UI Features (Already Implemented)

The UI was **90% complete** before this task. Existing features include:

1. **Two-level cascading dropdown** (lines 441-468, 1134-1213)
   - Region dropdown: United States, Europe, Asia, Africa, Americas, Oceania, Other Stamps
   - Country dropdown: Dynamically populated via `renderUI` based on region selection
   
2. **AI auto-selection** (lines 1488-1506)
   - Extracts country from stamp image
   - Calls `map_country_to_category()` to determine region and category
   - Auto-selects region dropdown
   - Auto-selects country dropdown (with 0.2s delay for renderUI)
   - Handles ambiguous cases (like US) by only selecting region

3. **Three-state validation indicator** (lines 1216-1269)
   - ⚠️ Yellow warning: "Please select region and country/subcategory"
   - ✅ Green success: "Valid category: {category_id}"
   - ❌ Red error: "Invalid category selection"

4. **Form validation** (lines 1985-2027)
   - Prevents submission without valid category
   - Shows error notification if category missing
   - Extracts final category_id before calling eBay API

## Testing Results

### Unit Tests
- ✅ 3 new test cases added to `test-stamp_helpers.R`
- ⏳ Tests require package environment to run (deferred to user)

### Critical Tests
- ⏳ Deferred to user environment (WSL R lacks required packages)
- Expected result: All existing tests should pass (no regressions)

### Integration Tests (Manual - Pending)
The following tests should be performed by the user:

1. **Romania stamp test:**
   - Upload Romania stamp image
   - Verify AI auto-selects: Region = "Europe", Country = "Romania"
   - Verify validation shows green with category 47169
   - Submit to eBay sandbox
   - Verify no Error 87

2. **US stamp test:**
   - Upload US stamp from 1880s
   - Verify AI auto-selects: Region = "United States"
   - Verify Country dropdown shows era options (not auto-selected)
   - Manually select "19th Century: Used"
   - Verify validation shows green with category 675
   - Submit to eBay sandbox

3. **Unknown country test:**
   - Upload stamp from obscure country
   - Verify both dropdowns empty (no auto-selection)
   - Verify validation shows yellow warning
   - Manually select "Other Stamps" region
   - Verify validation shows green with category 170137

## Key Files Modified

| File | Purpose | Lines Changed |
|------|---------|---------------|
| `R/ebay_integration.R` | eBay API integration | 26-133 (signature + category logic) |
| `R/mod_stamp_export.R` | Stamp export UI module | 2204 (added is_stamp parameter) |
| `R/ebay_database_extension.R` | Database schema | 27 (default value fix) |
| `tests/testthat/test-stamp_helpers.R` | Unit tests | 123-154 (new category tests) |

## Key Files (Unchanged but Important)

| File | Purpose | Key Lines |
|------|---------|-----------|
| `R/ebay_stamp_categories.R` | Category data + mapping | 28-593 (STAMP_CATEGORIES), 632-1044 (map_country_to_category) |
| `R/mod_stamp_export.R` | UI implementation | 441-468 (UI), 1134-1213 (cascading), 1216-1269 (validation), 1488-1506 (AI auto-select) |

## Critical Implementation Details

### 1. Category ID Extraction Logic
```r
# Get region and country from UI
ebay_region <- input[[paste0("ebay_region_", i)]]
ebay_country_id <- input[[paste0("ebay_country_", i)]]

# Handle "Other Stamps" special case (leaf at region level)
if (ebay_region == "OT") {
  category_id <- STAMP_CATEGORIES[[ebay_region]]$region_id
} else {
  category_id <- as.numeric(ebay_country_id)
}

# Validate before proceeding
if (is.null(category_id) || is.na(category_id)) {
  showNotification("Invalid category selection", type = "error")
  return()
}
```

### 2. Cascading Dropdown Pattern
**Key Insight:** No `observeEvent` needed! `renderUI` automatically re-renders when input changes.

```r
output[[paste0("ebay_country_ui_", i)]] <- renderUI({
  region <- input[[paste0("ebay_region_", i)]]
  
  if (is.null(region) || region == "") {
    return(selectInput(..., choices = c("Select region first..." = "")))
  }
  
  # Get country choices from STAMP_CATEGORIES
  region_data <- STAMP_CATEGORIES[[region]]
  country_choices <- c("Select country..." = "", region_data$countries)
  
  selectInput(..., choices = country_choices)
})
```

### 3. AI Auto-Selection Timing
**CRITICAL:** 0.2s delay needed between region and country updates:

```r
# Update region first
updateSelectInput(session, paste0("ebay_region_", i), 
                 selected = category_mapping$region_code)

# Wait for renderUI to create country dropdown
Sys.sleep(0.2)

# Then update country
updateSelectInput(session, paste0("ebay_country_", i),
                 selected = as.character(category_mapping$category_id))
```

**Why?** `renderUI` is asynchronous. Without delay, country dropdown doesn't exist yet.

## Future Enhancements

- Category search/autocomplete for large region lists
- Recent categories quick-select
- Bulk category assignment for stamp lots
- Category validation against eBay API (check if still valid leaf)

## Gotchas & Constraints

### 1. Module Namespace Issues
**RULE:** In Shiny modules, ALWAYS use native Shiny/bslib components, NOT custom JavaScript.
- ❌ Custom jQuery onclick handlers (fail due to namespace)
- ❌ shinyjs functions (don't reliably handle namespaces)
- ✅ `renderUI` + `selectInput` (handles namespacing automatically)

### 2. showNotification() Type Values
**CRITICAL:** Only three valid type values:
- `type = "message"` (blue/info)
- `type = "warning"` (yellow)
- `type = "error"` (red)

**NEVER use:**
- ❌ `type = "default"` (causes error)
- ❌ `type = "success"` (causes error)

### 3. Category Leaf Requirements
- eBay requires LEAF categories (Error 87 if not leaf)
- Category 260 (Stamps) is NOT a leaf
- All 438 categories in STAMP_CATEGORIES are verified leaf categories
- Exception: Category 170137 ("Other Stamps") is a leaf at region level

## Rollback Plan

If issues arise, rollback in reverse order:

1. **Restore database default:**
   ```sql
   category_id TEXT DEFAULT '914',
   ```

2. **Remove is_stamp parameter from mod_stamp_export.R:**
   ```r
   # Remove line 2204
   is_stamp = TRUE,
   ```

3. **Remove category_id parameter from function signature:**
   ```r
   # R/ebay_integration.R line 26
   # Remove: category_id = NULL,
   ```

4. **Restore hardcoded category:**
   ```r
   if (is_stamp) {
     category_id <- 675
   }
   ```

5. **Remove unit tests:**
   ```r
   # Delete lines 123-154 in test-stamp_helpers.R
   ```

## User Action Items

The following tasks require the user to complete:

1. **Run critical tests:**
   ```bash
   Rscript -e 'source("dev/run_critical_tests.R")'
   ```
   Expected: All tests pass (currently ~170 tests)

2. **Manual integration tests:**
   - Start app: `golem::run_dev()`
   - Test Romania stamp (auto-selection)
   - Test US stamp (manual selection)
   - Test unknown country (fallback to "Other Stamps")

3. **End-to-end eBay submission:**
   - Submit 3 stamps to eBay sandbox
   - Verify no Error 87
   - Check listings appear in correct categories on eBay

4. **Production deployment:**
   - If all tests pass, deploy to production
   - Monitor first few stamp listings for issues

## Success Criteria

- [x] Hardcoded category 675 removed
- [x] Function signature updated with `category_id` parameter
- [x] UI passes selected category to eBay API
- [x] Database default value fixed
- [x] Unit tests added (need validation)
- [ ] Critical tests pass (170/170) - **User to verify**
- [ ] Integration tests pass - **User to verify**
- [ ] Manual E2E test confirms eBay listings in correct categories - **User to verify**
- [ ] No Error 87 from eBay API - **User to verify**
- [x] Documentation updated

## Notes

This task was significantly easier than expected because the UI implementation was already 90% complete. The cascading dropdowns, validation indicator, AI auto-selection, and form validation were all working. Only needed to:

1. Remove hardcoded category from eBay integration
2. Pass category_id parameter through the call chain
3. Add is_stamp flag
4. Fix database default
5. Add unit tests

The heavy lifting (UI logic, STAMP_CATEGORIES data structure, map_country_to_category mapping) was done in previous work.
