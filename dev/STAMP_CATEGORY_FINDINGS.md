# eBay Stamp Category Investigation - Initial Findings

**Date:** 2025-11-02
**Status:** Preliminary Research
**Action Required:** Run `dev/investigate_stamp_categories.R` in development environment

---

## Problem Summary

Stamps are currently being listed under **category 260** (Stamps - top level), but this may be causing issues because:

1. **Category 260 is likely a PARENT category, not a LEAF category**
2. **eBay requires LEAF categories** for most listings
3. Postcards correctly use category **262042** (Topographical Postcards - a leaf category)

---

## Current Implementation

### Stamps
```r
# R/ebay_stamp_helpers.R:121
PrimaryCategory = list(CategoryID = "260"),  # STAMPS CATEGORY
```

### Postcards (Working Correctly)
```r
# Postcards use leaf category 262042
category_id <- if (is_stamp) 260 else 262042
```

---

## Key Research Findings

### From eBay API Documentation

1. **Category Structure:**
   - Category 260 = Stamps (Main category)
   - Has multiple subcategories by:
     - Geographic region (United States, Europe, Asia, etc.)
     - Time period (19th Century, 1901-1940, 1941-1980, 1981-Now)
     - Topic/theme (Topical stamps)

2. **Leaf Category Requirement:**
   - Per eBay docs: "You can only add item listings in leaf categories"
   - GetCategories API returns `LeafCategory` field (true/false)
   - Non-leaf categories will be rejected or auto-reassigned

3. **Expected Subcategory Structure:**
   ```
   260 - Stamps [PARENT]
   ├── United States [Possibly PARENT]
   │   ├── 19th Century [LEAF]
   │   ├── 1901-1940 [LEAF]
   │   ├── 1941-1980 [LEAF]
   │   └── 1981-Now [LEAF]
   ├── Great Britain [Possibly PARENT with subcategories]
   ├── Canada [Possibly PARENT with subcategories]
   ├── Europe [Possibly PARENT with subcategories]
   └── Worldwide [Possibly PARENT or LEAF]
   ```

### From eBay Community Forums

- Stamp sellers report confusion about subcategories
- Standard Envelope shipping available for stamps category
- Different subcategories may have different item specifics requirements

---

## Investigation Steps

### Step 1: Run Investigation Script

The script `dev/investigate_stamp_categories.R` will:

1. Connect to eBay Trading API (production)
2. Call `GetCategories` for category 260
3. Retrieve complete subcategory hierarchy
4. Identify all LEAF categories
5. Save results to:
   - `dev/stamp_category_hierarchy.rds` (data)
   - `dev/stamp_category_hierarchy.txt` (readable)

**To run:**
```r
# In R console or RStudio:
source("dev/investigate_stamp_categories.R")
```

**Requirements:**
- eBay OAuth credentials set in environment
- Active eBay user token
- httr2, xml2, R6 packages installed

### Step 2: Analyze Results

After running the script, review:

1. **Is category 260 itself a leaf?**
   - If YES: Current code is correct
   - If NO: MUST update to use subcategory

2. **What are the leaf categories for:**
   - United States stamps?
   - European stamps?
   - Worldwide/International stamps?

3. **What item specifics are required for each category?**
   - Use GetCategorySpecifics API call
   - Compare with current `extract_stamp_aspects()` function

### Step 3: Update Code

Based on results, implement:

```r
# New function in R/ebay_stamp_helpers.R
determine_stamp_category <- function(ai_data) {
  country <- ai_data$country

  # Map country to appropriate leaf category
  if (is.null(country) || is.na(country)) {
    return(DEFAULT_STAMP_LEAF_CATEGORY)  # From investigation results
  }

  if (country == "United States" || country == "USA") {
    # Use appropriate US stamps leaf category
    # Possibly based on year: 19th century, 1901-1940, etc.
    return(get_us_stamp_category(ai_data$year))
  }

  # Add mappings for other countries/regions
  # Based on investigation results

  return(WORLDWIDE_STAMP_LEAF_CATEGORY)  # Default
}
```

---

## Comparison: Stamps vs Postcards

### Postcards (Working)
- **Category:** 262042 (Topographical Postcards)
- **Type:** LEAF category (confirmed working)
- **Parent:** Under Postcards > Postcards > Topographical Postcards
- **Item Specifics:** Type, Era, Country, etc.

### Stamps (Needs Investigation)
- **Category:** 260 (Stamps)
- **Type:** Unknown - likely PARENT (needs confirmation)
- **Subcategories:** Unknown structure (investigation needed)
- **Item Specifics:** Type, Grade, Country, Year, Certification, etc.

---

## Likely Issues

### Why Stamps Might Show as "Postal Cards"

1. **Auto-Reassignment:**
   - If 260 is not a leaf category
   - eBay may automatically reassign to a similar category
   - Could explain stamps appearing under postcards

2. **Category Validation Failure:**
   - Non-leaf category in API call
   - eBay rejects and picks closest valid category
   - Postcards category might be selected as "closest match"

3. **Missing Category Hierarchy:**
   - If proper subcategory not specified
   - eBay's system makes best guess
   - Results in incorrect categorization

---

## Expected GetCategories Response

The API call will return XML like:

```xml
<GetCategoriesResponse>
  <Ack>Success</Ack>
  <CategoryArray>
    <Category>
      <CategoryID>260</CategoryID>
      <CategoryName>Stamps</CategoryName>
      <CategoryLevel>1</CategoryLevel>
      <LeafCategory>false</LeafCategory>  <!-- KEY: Is this true or false? -->
      <CategoryParentID>0</CategoryParentID>
    </Category>
    <Category>
      <CategoryID>260001</CategoryID>  <!-- Example subcategory -->
      <CategoryName>United States</CategoryName>
      <CategoryLevel>2</CategoryLevel>
      <LeafCategory>false</LeafCategory>  <!-- Or true? -->
      <CategoryParentID>260</CategoryParentID>
    </Category>
    <!-- More subcategories... -->
  </CategoryArray>
</GetCategoriesResponse>
```

---

## Next Actions

### Immediate (Before Implementation)

1. **[ ] Run investigation script in development environment**
   - Requires actual eBay credentials
   - Takes 10-30 seconds to complete
   - Saves results to dev/ folder

2. **[ ] Review results to identify:**
   - Is 260 a leaf category?
   - What are the correct leaf categories?
   - US stamps leaf category ID
   - International stamps leaf category ID

3. **[ ] Test with sample data:**
   - Create test listing with category 260
   - Verify if eBay accepts or rejects
   - Check where listing actually appears

### Implementation

1. **[ ] Update `R/ebay_stamp_helpers.R`:**
   - Replace hardcoded "260" with dynamic category selection
   - Implement `determine_stamp_category()` function
   - Use correct leaf categories

2. **[ ] Add category validation:**
   - Check if category is leaf before API call
   - Provide clear error if invalid category

3. **[ ] Update item specifics:**
   - Align with category-specific requirements
   - Get category specifics from eBay

4. **[ ] Add tests:**
   - Test category selection for US stamps
   - Test category selection for international stamps
   - Test validation logic

### Verification

1. **[ ] Test in eBay sandbox:**
   - Create stamp listing with new category
   - Verify it appears in correct section
   - Check for any warnings/errors

2. **[ ] Compare with postcards:**
   - Ensure stamps follow same pattern
   - Verify both use leaf categories correctly

---

## API Calls Needed

### 1. GetCategories (Current Investigation)
```xml
<GetCategoriesRequest xmlns="urn:ebay:apis:eBLBaseComponents">
  <CategoryParent>260</CategoryParent>
  <DetailLevel>ReturnAll</DetailLevel>
  <ViewAllNodes>true</ViewAllNodes>
  <LevelLimit>5</LevelLimit>
</GetCategoriesRequest>
```

### 2. GetCategorySpecifics (After Finding Leaf Categories)
```xml
<GetCategorySpecificsRequest xmlns="urn:ebay:apis:eBLBaseComponents">
  <CategoryID>[LEAF_CATEGORY_ID]</CategoryID>
</GetCategorySpecificsRequest>
```

### 3. GetCategoryFeatures (Optional - for category metadata)
```xml
<GetCategoryFeaturesRequest xmlns="urn:ebay:apis:eBLBaseComponents">
  <CategoryID>[LEAF_CATEGORY_ID]</CategoryID>
  <DetailLevel>ReturnAll</DetailLevel>
</GetCategoryFeaturesRequest>
```

---

## Risk Assessment

### High Confidence Issues
1. ✅ Category 260 is the correct top-level stamps category
2. ✅ Postcards correctly use leaf category 262042
3. ✅ eBay requires leaf categories for listings

### Needs Verification
1. ❓ Is category 260 itself a leaf? (Likely NO)
2. ❓ What are the actual leaf category IDs for stamps?
3. ❓ Do different stamp subcategories have different requirements?

### Blocked Until Investigation
1. ⏸️ Cannot implement dynamic category selection
2. ⏸️ Cannot validate categories properly
3. ⏸️ Cannot ensure correct item specifics

---

## References

- **PRP:** `PRPs/PRP_EBAY_STAMP_CATEGORY_VALIDATION.md`
- **Investigation Script:** `dev/investigate_stamp_categories.R`
- **Current Implementation:** `R/ebay_stamp_helpers.R:121`
- **Working Reference:** `R/ebay_helpers.R` (postcards)

---

## Timeline

- **2025-11-02:** Research and investigation script created
- **Next:** Run script in dev environment → Expected completion: Same day
- **Then:** Implement fixes → Expected: 1-2 days
- **Final:** Test and verify → Expected: 1 day

---

**Status:** ⏸️ **Blocked - Awaiting investigation script results**

**Run this command to proceed:**
```r
source("dev/investigate_stamp_categories.R")
```

After running, review:
- `dev/stamp_category_hierarchy.txt` (human-readable)
- `dev/stamp_category_hierarchy.rds` (data for processing)
