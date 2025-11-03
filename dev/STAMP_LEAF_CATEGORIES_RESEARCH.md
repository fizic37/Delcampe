# eBay Stamp Leaf Categories - Research Notes

**Date:** 2025-11-02
**Problem:** Category 260 is NOT a leaf category (Error 87)
**Need:** Find correct leaf category ID for stamps

---

## Known Facts

1. **Category 260 = Stamps** (Parent category, NOT leaf)
2. **Error 87:** "The category selected is not a leaf category"
3. **Postcards use 262042** (Topographical Postcards - this IS a leaf category)

---

## Common eBay Stamp Leaf Categories (Typical Structure)

Based on standard eBay category hierarchies, stamps are typically organized as:

```
260 - Stamps [PARENT - Cannot list here]
├── United States
│   ├── Plate Blocks
│   ├── Collections & Lots
│   ├── 19th Century (Pre-1900)
│   ├── 1901-1940
│   ├── 1941-1980
│   ├── 1981-Now
│   └── Other subcategories...
├── Topical
├── Worldwide
└── Other regions...
```

---

## Potential Solutions

### Option 1: Use "United States" Stamps Category (Most Common)

**Most likely leaf categories for US stamps:**
- **~47149** or similar - US Stamps general category
- Sub-categories by era (1901-1940, 1941-1980, 1981-Now)

### Option 2: Use a "Worldwide" or General Stamps Category

For international stamps or when country is unknown.

### Option 3: Dynamic Category Selection

Implement logic:
```r
determine_stamp_leaf_category <- function(ai_data) {
  country <- ai_data$country
  year <- as.numeric(ai_data$year)

  if (is.null(country) || is.na(country)) {
    return(DEFAULT_STAMP_LEAF_CATEGORY)
  }

  if (country == "United States" || country == "USA") {
    # Use US stamps category
    # Could further subdivide by year if needed
    return(US_STAMPS_LEAF_CATEGORY)
  }

  # For other countries
  return(WORLDWIDE_STAMPS_LEAF_CATEGORY)
}
```

---

## Immediate Workaround

**While we research the exact category IDs, here's what we can do:**

### Quick Fix: Test with Known Good Category

Since we KNOW that **262042 works** (Topographical Postcards is a leaf category), we can:

1. **Temporarily** test if the aspect fix works by using 262042
2. This will at least verify our aspect extraction fix is correct
3. Then swap in the correct stamp leaf category once we find it

**Test Code:**
```r
# TEMPORARY TEST - Use postcard category to verify aspects work
category_id <- 262042  # Postcards (we know this is a leaf)

# With stamp aspects (our fix)
aspects <- extract_stamp_aspects(ai_data, condition_display)

# This will tell us if eBay accepts stamp aspects in a leaf category
# If it works, we just need the right stamp leaf category
```

### Finding the Exact Category ID

**Method 1: Browse eBay UI**
1. Go to https://www.ebay.com/
2. Browse to Collectibles > Stamps
3. Click through to United States > (specific era)
4. Check URL for category ID parameter

**Method 2: Inspect Existing Listing**
1. Find any active US stamp listing on eBay
2. View page source
3. Search for "categoryId" or "category_id"
4. Extract the ID

**Method 3: Use Taxonomy API (Different approach)**
The Taxonomy API might work with application token:
```r
# GET /commerce/taxonomy/v1/category_tree/0/get_categories
# Starting at category 260
```

---

## Recommended Immediate Action

**Step 1: Quick Test**

Update `R/ebay_integration.R` temporarily:

```r
# TEMPORARY: Use a known leaf category to test aspect fix
if (is_stamp) {
  # TODO: Find correct stamp leaf category
  # For now, test with postcard category to verify aspects work
  category_id <- 262042  # TEMPORARY - will change to stamp leaf category
  cat("   ⚠️ TEMPORARY: Using postcard category for testing\n")
  cat("   TODO: Update to correct stamp leaf category\n")
} else {
  category_id <- 262042  # Postcards
}
```

**Step 2: Manual Research**

Browse eBay website:
- Go to Stamps section
- Navigate to United States stamps
- Find a specific subcategory (like "1941-1980")
- Note the category ID from URL or page source

**Step 3: Update with Correct Category**

Once found:
```r
# Actual fix
STAMP_LEAF_CATEGORY_US <- 47149  # Example - replace with actual
STAMP_LEAF_CATEGORY_WORLDWIDE <- XXXXX  # To be determined

if (is_stamp) {
  if (ai_data$country == "United States") {
    category_id <- STAMP_LEAF_CATEGORY_US
  } else {
    category_id <- STAMP_LEAF_CATEGORY_WORLDWIDE
  }
}
```

---

## Alternative: Ask eBay Directly

Since the Trading API won't give us categories without a user token, we could:

1. **Check eBay Seller Hub** - If you have an active eBay seller account, the category selection tool will show all valid leaf categories

2. **Use Category Browse on eBay.com** - Navigate the categories and extract IDs from URLs

3. **Check Developer Forums** - Other developers may have documented common stamp category IDs

---

## Expected Category Structure

Based on typical eBay organization, likely structure:

```
260 - Stamps [NOT LEAF]
  ├── 260001 - United States [MAYBE NOT LEAF]
  │     ├── XXXXX - Plate Blocks [LEAF?]
  │     ├── XXXXX - Collections & Lots [LEAF?]
  │     ├── XXXXX - 19th Century [LEAF?]
  │     ├── XXXXX - 1901-1940 [LEAF?]
  │     ├── XXXXX - 1941-1980 [LEAF?]
  │     └── XXXXX - 1981-Now [LEAF?]
  ├── XXXXX - Topical [LEAF or PARENT?]
  └── XXXXX - Worldwide [LEAF or PARENT?]
```

---

## Next Steps

1. [ ] Browse eBay.com manually to find US stamps leaf category
2. [ ] Extract category ID from URL or page source
3. [ ] Update code with correct category ID
4. [ ] Test listing with correct category
5. [ ] Verify listing appears in Stamps section (not Postcards)

---

## Status

**Blocked:** Need valid user OAuth token for GetCategories API call, OR need to manually browse eBay website

**Workaround:** Use eBay website UI to find category IDs manually

**Timeline:** Should be able to find correct category ID within 10-15 minutes of manual browsing

---

**Last Updated:** 2025-11-02
**Status:** In Progress - Manual Research Needed
