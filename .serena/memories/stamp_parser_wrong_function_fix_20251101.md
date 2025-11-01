# Stamp Parser Wrong Function Fix - CRITICAL BUG

**Date:** November 1, 2025
**Status:** ✅ FIXED
**Severity:** CRITICAL - AI extraction completely broken for stamps
**Module:** `R/mod_stamp_export.R`

---

## Problem

When users extracted AI data for stamp lots, **price and condition fields remained empty** even after successful AI extraction. Database showed `ai_price: NULL` and `ai_condition: NULL` despite AI providing these values.

**User Report:**
> "I am seeing a wrong price update (AI extracted) inside a stamp lot"

---

## Root Cause: **WRONG PARSER FUNCTION**

### The Bug

**Line 1114** in `R/mod_stamp_export.R` was calling the **POSTAL CARD parser** instead of the stamp-specific parser:

```r
# ❌ WRONG - Line 1114
parsed <- parse_enhanced_ai_response(result$content)  # Postal card parser!
```

### Why This Failed

**Mismatch Chain:**

1. **Stamp Prompt** (`build_stamp_prompt()`) tells AI to output:
   - `RECOMMENDED_PRICE: $XX`
   - `GRADE: Used/Mint/etc.`
   - Plus: `DENOMINATION`, `SCOTT_NUMBER`, `PERFORATION`, `WATERMARK`

2. **AI Response** contains:
   ```
   TITLE: INDIA - 1880s QUARTER ANNA QUEEN VICTORIA...
   DESCRIPTION: Vintage Queen Victoria era stamp...
   RECOMMENDED_PRICE: 12
   GRADE: Used
   COUNTRY: India
   YEAR: 1880
   DENOMINATION: Quarter Anna
   ...
   ```

3. **Postal Card Parser** (`parse_enhanced_ai_response()`) looks for:
   - `PRICE:` (not `RECOMMENDED_PRICE:`) ❌
   - `CONDITION:` (not `GRADE:`) ❌
   - `ERA:`, `CITY:`, `REGION:`, `THEME_KEYWORDS:` (stamp fields don't have these) ❌

4. **Result:** Parser can't find `PRICE:` or `CONDITION:`, returns:
   - `parsed$price = NA`
   - `parsed$condition = NA`
   - Stamp-specific fields ignored entirely!

5. **Database Save:**
   ```r
   ai_data <- list(
     price = parsed$price,  # NA!
     condition = parsed$condition  # NA!
   )
   ```
   Result: `ai_price: NULL`, `ai_condition: NULL` in database

6. **UI Update:**
   ```r
   updateNumericInput(..., value = parsed$price)  # NA → field stays empty
   updateSelectInput(..., selected = parsed$condition)  # NA → no selection
   ```

### Evidence from Console

User's console output showed:
```
AI Fields:
   - ai_title: 'INDIA - 1880s QUARTER ANNA QUEEN VICTORI...'
   - ai_description: 416 chars
   - ai_price: NULL    ⚠️⚠️⚠️
   - ai_condition: NULL ⚠️⚠️⚠️
   - ai_model: claude-sonnet-4-5-20250929
```

Despite AI extraction succeeding (title and description populated), price and condition were NULL in database!

---

## The Fix

### Changed Parser Function Call

**File:** `R/mod_stamp_export.R`

**Line 1114:**
```r
# BEFORE (WRONG):
parsed <- parse_enhanced_ai_response(result$content)

# AFTER (CORRECT):
parsed <- parse_stamp_response(result$content)
```

### Updated Field Mappings

**UI Update (Lines 1149-1152):**
```r
# BEFORE:
updateNumericInput(session, paste0("starting_price_", i), value = parsed$price)
updateSelectInput(session, paste0("condition_", i), selected = parsed$condition)

# AFTER:
updateNumericInput(session, paste0("starting_price_", i), value = parsed$recommended_price)
updateSelectInput(session, paste0("condition_", i), selected = parsed$grade)
```

**Draft Save (Lines 1195-1196):**
```r
# BEFORE:
rv$image_drafts[[draft_key]] <- list(
  price = parsed$price,
  condition = parsed$condition,
  ...
)

# AFTER:
rv$image_drafts[[draft_key]] <- list(
  price = parsed$recommended_price,
  condition = parsed$grade,
  ...
)
```

**Database Save (Lines 1255-1256):**
```r
# BEFORE:
ai_data <- list(
  condition = parsed$condition,
  price = parsed$price,
  year = parsed$year,
  era = parsed$era,  # ❌ Stamps don't have era!
  city = parsed$city,  # ❌ Stamps don't have city!
  region = parsed$region,  # ❌ Stamps don't have region!
  theme_keywords = parsed$theme_keywords  # ❌ Stamps don't have theme_keywords!
)

# AFTER:
ai_data <- list(
  condition = parsed$grade,  # ✅ Stamp field
  price = parsed$recommended_price,  # ✅ Stamp field
  year = parsed$year,  # ✅ Common field
  country = parsed$country,  # ✅ Common field
  denomination = parsed$denomination,  # ✅ Stamp-specific
  scott_number = parsed$scott_number,  # ✅ Stamp-specific
  perforation = parsed$perforation,  # ✅ Stamp-specific
  watermark = parsed$watermark  # ✅ Stamp-specific
)
```

### Updated Console Logging

**Lines 1119-1126:**
```r
# BEFORE (postal card fields):
cat("      Price: €", parsed$price, "\n")
cat("      Condition: used (default - seller can adjust)\n")
cat("      Year:", parsed$year, "\n")
cat("      Era:", parsed$era, "\n")
cat("      City:", parsed$city, "\n")
cat("      Region:", parsed$region, "\n")
cat("      Theme Keywords:", parsed$theme_keywords, "\n")

# AFTER (stamp fields):
cat("      Recommended Price: $", parsed$recommended_price, "\n")
cat("      Grade:", parsed$grade, "\n")
cat("      Year:", parsed$year, "\n")
cat("      Country:", parsed$country, "\n")
cat("      Denomination:", parsed$denomination, "\n")
cat("      Scott Number:", parsed$scott_number, "\n")
cat("      Perforation:", parsed$perforation, "\n")
cat("      Watermark:", parsed$watermark, "\n")
```

---

## Parser Comparison

### Postal Card Parser (`parse_enhanced_ai_response`)

**Location:** `R/ai_api_helpers.R`

**Expected Fields:**
```
TITLE: ...
DESCRIPTION: ...
PRICE: XX (in EUR)
CONDITION: used/excellent/etc.
YEAR: XXXX
ERA: Belle Époque/Interwar/etc.
CITY: Paris
COUNTRY: France
REGION: Île-de-France
THEME_KEYWORDS: architecture, vintage, ...
```

**Returns:**
```r
list(
  title = "...",
  description = "...",
  price = 15.0,
  condition = "used",
  year = "1920",
  era = "Interwar",
  city = "Paris",
  country = "France",
  region = "Île-de-France",
  theme_keywords = "architecture, vintage"
)
```

### Stamp Parser (`parse_stamp_response`)

**Location:** `R/stamp_ai_helpers.R`

**Expected Fields:**
```
TITLE: ...
DESCRIPTION: ...
RECOMMENDED_PRICE: XX (in USD)
GRADE: Used/Mint/MNH/etc.
COUNTRY: USA
YEAR: 1963
DENOMINATION: 5c
SCOTT_NUMBER: 1234
PERFORATION: 11x10.5
WATERMARK: Double-lined USPS
```

**Returns:**
```r
list(
  title = "...",
  description = "...",
  recommended_price = 12.0,  # NOT "price"!
  grade = "Used",  # NOT "condition"!
  country = "USA",
  year = 1963,
  denomination = "5c",
  scott_number = "1234",
  perforation = "11x10.5",
  watermark = "Double-lined USPS"
)
```

**Critical Differences:**
- Price field: `price` (postal) vs. `recommended_price` (stamp)
- Condition field: `condition` (postal) vs. `grade` (stamp)
- Currency: EUR (postal) vs. USD (stamp)
- Postal-only: `era`, `city`, `region`, `theme_keywords`
- Stamp-only: `denomination`, `scott_number`, `perforation`, `watermark`

---

## How This Bug Happened

### Copy-Paste Inheritance

When creating `R/mod_stamp_export.R`:

1. **Copied** `R/mod_delcampe_export.R` → `R/mod_stamp_export.R`
2. **Find-replaced:**
   - `delcampe_export` → `stamp_export`
   - `postal_card` → `stamp`
   - `card_id` → `stamp_id`
3. **Created** `R/stamp_ai_helpers.R` with stamp-specific `parse_stamp_response()`
4. **But forgot** to update Line 1114 to use the new parser!

The code still called `parse_enhanced_ai_response()` from `R/ai_api_helpers.R` (postal card parser).

### Why It Went Unnoticed Initially

**Title and description worked!** Both parsers extract these fields the same way:
```r
extract_field(response_text, "TITLE")
extract_field(response_text, "DESCRIPTION")
```

So during initial testing:
- ✅ Title populated
- ✅ Description populated
- ❌ Price stayed empty (thought it was AI not providing value)
- ❌ Condition stayed empty (thought it was optional field)

**No error thrown!** `NA` values are valid in R, so:
- `updateNumericInput(..., value = NA)` → silently fails to update
- `updateSelectInput(..., selected = NA)` → silently fails to select
- Database save with `NULL` → accepted

---

## Impact

### Before Fix
- ❌ Price: Always NULL in database, empty in UI
- ❌ Condition: Always NULL in database, empty in UI
- ❌ Stamp-specific fields: Ignored (denomination, Scott number, perforation, watermark)
- ❌ Deduplication: Pre-loaded NULL values, no benefit
- ❌ User experience: Manual entry required for all pricing
- ❌ API waste: Re-extraction didn't help

### After Fix
- ✅ Price: Extracted from AI, saved to database, displayed in UI
- ✅ Condition/Grade: Extracted, saved, displayed
- ✅ Stamp-specific fields: Captured and saved
- ✅ Deduplication: Reloads complete AI data
- ✅ User experience: One-click AI extraction
- ✅ API efficiency: Deduplication works fully

---

## Testing

### Manual Test Protocol

**Setup:**
1. **Clear existing data** (important!):
   ```sql
   DELETE FROM stamp_processing WHERE stamp_id = 3;
   ```
   This ensures fresh AI extraction, not deduplication with old NULL values

2. Navigate to Stamps tab
3. Upload stamp face image → Use Existing
4. Upload stamp verso image → Use Existing
5. Wait for combined lot image

**Test: Fresh AI Extraction**
```
1. Open lot accordion panel
2. Click "Extract with AI" (NOT "Re-extract" - that means old data exists)
3. Wait for extraction
4. Check console output:
   ✅ "Recommended Price: $XX" (not "Price: €XX")
   ✅ "Grade: Used" (not "Condition: used")
   ✅ "Denomination: Quarter Anna"
   ✅ "Scott Number: ..." (if available)
5. Check UI:
   ✅ Price field: Shows numeric value (e.g., 12)
   ✅ Condition dropdown: Shows "Used" or similar
6. Check database:
   SELECT ai_price, ai_condition FROM stamp_processing WHERE stamp_id = 3;
   ✅ ai_price: 12 (not NULL!)
   ✅ ai_condition: 'Used' (not NULL!)
```

**Test: Deduplication**
```
1. Close app, reopen
2. Upload same images → Use Existing
3. Open lot accordion (should auto-populate)
4. Verify:
   ✅ Price field: Pre-filled with 12
   ✅ Condition: Pre-selected as "Used"
   ✅ Console: "DEDUPLICATION SUCCESS - Reusing AI data"
   ✅ Console: "ai_price: 12" (not NULL!)
```

### Database Verification

```sql
-- Check stamp processing records
SELECT
  sp.stamp_id,
  sp.ai_title,
  sp.ai_price,  -- Should be numeric, not NULL
  sp.ai_condition,  -- Should be 'Used'/'Mint'/etc., not NULL
  sp.ai_denomination,  -- Stamp-specific field
  sp.ai_scott_number,  -- Stamp-specific field
  sp.ai_model,
  sp.processed_timestamp
FROM stamp_processing sp
JOIN stamps s ON s.stamp_id = sp.stamp_id
WHERE s.image_type = 'lot'
ORDER BY sp.processed_timestamp DESC
LIMIT 5;
```

**Expected Results:**
```
stamp_id | ai_title                         | ai_price | ai_condition | ai_denomination | ai_scott_number | ai_model
---------|----------------------------------|----------|--------------|-----------------|-----------------|---------------------------
3        | INDIA - 1880s QUARTER ANNA...   | 12       | Used         | Quarter Anna    | (varies)        | claude-sonnet-4-5-20250929
```

---

## Files Modified

### R/mod_stamp_export.R

**Changes:**
- Line 1114: Parser function call
- Lines 1119-1126: Console logging (field names)
- Lines 1149-1152: UI update field mapping
- Lines 1195-1196: Draft save field mapping
- Lines 1252-1264: AI data save field mapping and stamp-specific fields
- Lines 1266-1277: Database save logging (field names)

**Total changes:** 7 locations
**Backward compatible:** No (but stamps never worked before, so no regression)
**Breaking changes:** None (feature was broken)

---

## Related Issues

### Issue 2: Description Logic - WORKING AS DESIGNED

User also reported description logic concern, but investigation showed:
- ✅ Checkbox exists and functions correctly
- ✅ Checked → AI description
- ✅ Unchecked → Template description
- ✅ Logic identical to postal cards

**No fix needed for Issue 2.**

---

## Lessons Learned

### For Copy-Paste Module Creation

1. **Create Comprehensive Checklist:**
   - ✅ UI element IDs
   - ✅ Database function names
   - ✅ **Parser function calls** ⚠️ (missed this!)
   - ✅ Field name mappings
   - ✅ Console log messages

2. **Search for Entity-Specific Function Calls:**
   ```bash
   # After copying mod_delcampe_export.R → mod_stamp_export.R
   grep -n "parse_enhanced" R/mod_stamp_export.R
   # Should return ZERO results! If found, need to replace with parse_stamp_response
   ```

3. **Integration Test Immediately:**
   - Don't just test title/description
   - Test ALL fields: price, condition, metadata
   - Verify database save, not just UI display

4. **Compare Prompts and Parsers:**
   - Ensure prompt output format matches parser expectations
   - Document field name differences (price vs recommended_price)

---

## Prevention Strategy

### Automated Check

**Add to test suite:**
```r
test_that("Stamp export uses correct parser", {
  # Read mod_stamp_export.R
  code <- readLines("R/mod_stamp_export.R")

  # Search for wrong parser usage
  wrong_parser_lines <- grep("parse_enhanced_ai_response", code)

  # Should be ZERO occurrences
  expect_equal(
    length(wrong_parser_lines),
    0,
    info = "mod_stamp_export.R should use parse_stamp_response, not parse_enhanced_ai_response"
  )

  # Search for correct parser usage
  correct_parser_lines <- grep("parse_stamp_response", code)

  # Should be at least ONE occurrence
  expect_true(
    length(correct_parser_lines) >= 1,
    info = "mod_stamp_export.R should call parse_stamp_response"
  )
})
```

### Code Review Checklist

**For parallel features (stamps, coins, art, etc.):**

- [ ] Custom prompt builder function created (`build_X_prompt`)
- [ ] Custom parser function created (`parse_X_response`)
- [ ] Export module calls correct parser (NOT postal card parser!)
- [ ] Field names match between prompt output and parser expectations
- [ ] UI updates use correct field names from parser
- [ ] Draft save uses correct field names
- [ ] Database save uses correct field names
- [ ] Console logs reference correct entity and field names
- [ ] Integration test verifies all fields populate

---

## Success Criteria

- [x] Correct parser function called (`parse_stamp_response`)
- [x] Price field mapping corrected (`recommended_price`)
- [x] Condition field mapping corrected (`grade`)
- [x] Stamp-specific fields added to save (`denomination`, `scott_number`, etc.)
- [x] Console logging updated with stamp field names
- [ ] Manual test confirms price populates (USER TO VERIFY)
- [ ] Manual test confirms condition populates (USER TO VERIFY)
- [ ] Database query shows non-NULL values (USER TO VERIFY)
- [ ] Deduplication reloads correct values (USER TO VERIFY)

---

## Related Memories

- `.serena/memories/stamp_ai_deduplication_fix_20251031.md` - Fixed database function calls
  - That fix corrected `find_card_processing` → `find_stamp_processing`
  - This fix corrects parser function call
  - Both were copy-paste issues from postal card module

- `PRPs/PRP_STAMP_AI_ISSUES_INVESTIGATION.md` - Original investigation PRP
  - Led to discovery of this parser mismatch

---

## Status

**Current:** ✅ **FIXED**
**Testing:** ⏳ **AWAITING USER VERIFICATION**
**Severity:** **CRITICAL** → **RESOLVED**

**Next Steps:**
1. User clears old stamp_processing record (stamp_id = 3)
2. User performs fresh AI extraction
3. User verifies price and condition populate
4. User confirms database has non-NULL values
5. User tests deduplication with new data
6. If successful → Mark as VERIFIED FIXED

---

**Last Updated:** 2025-11-01
**Bug Type:** Copy-paste inheritance, wrong function call
**Fix Complexity:** MEDIUM (7 locations, multiple field mappings)
**Testing Priority:** HIGH (critical feature)
**User Impact:** HIGH (feature was completely broken for pricing)
