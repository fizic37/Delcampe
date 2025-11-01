# PRP: Stamp AI Extraction Issues Investigation

**Date Created:** November 1, 2025
**Status:** 🔍 INVESTIGATION
**Priority:** HIGH
**Type:** Bug Fix

---

## Problem Statement

Two critical issues have been reported with stamp lot AI extraction:

### Issue 1: Wrong Price Update (AI Extracted)
- **Symptom:** When AI extraction completes for a stamp lot, the price field is being updated with an incorrect value
- **Context:** Only affecting the single stamp lot being tested
- **Expected:** AI should extract and display the correct market value price for the lot
- **Actual:** Price field shows wrong value after AI extraction

### Issue 2: AI Description Logic Mismatch
- **Symptom:** Description extraction logic differs from postal card implementation
- **Expected Behavior (Postal Cards):**
  - User checks "Fetch AI description" checkbox → AI generates full description
  - User leaves checkbox unchecked → Description is template-based (title + fixed text)
- **Actual Behavior (Stamps):** Description logic appears to not follow the same pattern
- **Impact:** Unclear if description comes from AI or template, potentially inconsistent with user expectations

---

## Context

### Current Implementation Status

**Stamp Feature:** Fully implemented with parallel architecture to postal cards
- **Module:** `R/mod_stamp_export.R` (copied from `mod_delcampe_export.R`)
- **AI Helpers:** `R/stamp_ai_helpers.R`
- **Database:** Uses `stamps` and `stamp_processing` tables
- **Recent Fix:** AI deduplication fixed (2025-10-31) via `.serena/memories/stamp_ai_deduplication_fix_20251031.md`

**Postal Card Reference Implementation:**
- **Module:** `R/mod_delcampe_export.R`
- **Checkbox Control:** Line 1122 `if (fetch_description)` conditional
- **Template Function:** `build_template_description(title)`
- **AI Description:** Full AI-generated description from prompt

### Evidence of Checkbox Implementation

**Stamp Export Module (`R/mod_stamp_export.R`):**
```r
# Line 265: UI checkbox exists
"Fetch AI description"

# Line 977: Checkbox value read
fetch_description <- input[[paste0("fetch_ai_description_", i)]] %||% FALSE

# Line 993: Debug logging
cat("   Fetch AI description:", fetch_description, "\n")

# Line 1138-1147: Conditional logic exists
if (fetch_description) {
  # AI-generated description
  shiny::updateTextAreaInput(session, paste0("item_description_", i), value = parsed$description)
  cat("      Description updated with AI content (length:", nchar(parsed$description), ")\n")
} else {
  # Template-based description
  template_description <- build_template_description(parsed$title)
  shiny::updateTextAreaInput(session, paste0("item_description_", i), value = template_description)
  cat("      Description updated with template (length:", nchar(template_description), ")\n")
}
```

**Template Function (`R/mod_stamp_export.R`):**
```r
# Line 39: Template builder exists
build_template_description <- function(title) {
  # Returns: title + fixed boilerplate text
}
```

✅ **Finding:** Description checkbox logic IS implemented for stamps, matches postal cards exactly

---

## Investigation Scope

### For Issue 1: Wrong Price Update

**Hypothesis Candidates:**

1. **AI Parsing Issue:**
   - `parse_stamp_response()` extracts wrong price from AI output
   - AI prompt produces inconsistent price format
   - Price parsing logic doesn't handle lot-based pricing correctly

2. **Database Corruption:**
   - Deduplication loading wrong price from previous extraction
   - Price stored incorrectly in `stamp_processing.ai_price`
   - Currency conversion error (eBay uses USD, not EUR)

3. **UI Update Logic:**
   - `updateNumericInput()` receiving correct value but displaying wrong
   - JavaScript/browser caching old value
   - Race condition between database pre-load and AI extraction

4. **Prompt/Model Issue:**
   - Stamp prompt asks for wrong price type (individual vs lot price)
   - AI model calculating price incorrectly
   - Prompt example confusing the model

**Investigation Steps Required:**

1. **Console Log Analysis:**
   ```
   Check for these logs during AI extraction:
   - "📄 Raw AI Response:" → Full AI JSON output
   - "✅ Parsing successful" → What parsed price shows
   - "Price updated" → What value was sent to UI
   - "💾 Draft saved" → What price is in draft data
   - "SAVING AI DATA TO DATABASE" → What price is saved
   ```

2. **Database Inspection:**
   ```sql
   SELECT
     s.stamp_id,
     s.image_type,
     sp.ai_price,
     sp.ai_title,
     sp.ai_model,
     sp.processed_timestamp
   FROM stamps s
   JOIN stamp_processing sp ON s.stamp_id = sp.stamp_id
   WHERE s.image_type = 'lot'
   ORDER BY sp.processed_timestamp DESC
   LIMIT 5;
   ```

3. **AI Response Capture:**
   - Upload same stamp lot again
   - Check "Extract with AI"
   - Copy full console output
   - Examine raw JSON from AI
   - Verify price field in JSON

4. **Comparison Test:**
   - Extract same lot with postal card module (if possible)
   - Compare extracted price values
   - Check if postal card price is correct

5. **Prompt Review:**
   - Review `build_stamp_prompt()` for lot type
   - Check if price instruction is clear
   - Compare to postal card prompt

### For Issue 2: AI Description Logic

**Current Understanding:**
- ✅ Checkbox exists in UI (Line 265)
- ✅ Checkbox value is read (Line 977)
- ✅ Conditional logic exists (Line 1138-1147)
- ✅ Template function exists (Line 39)
- ✅ Logic matches postal cards exactly

**Hypothesis:**
- **User may not be seeing checkbox in UI** (UI rendering issue)
- **Checkbox default state differs** (postal cards default checked, stamps default unchecked?)
- **User expectation mismatch** (thinks it should work differently)

**Investigation Steps Required:**

1. **UI Verification:**
   - Open stamp export accordion
   - Verify checkbox is visible
   - Check checkbox default state (checked/unchecked)
   - Test both states:
     - ✅ Checked → Should get AI description
     - ☐ Unchecked → Should get template description

2. **Console Output Analysis:**
   ```
   After extraction, check for:
   "Fetch AI description: TRUE" or "FALSE"
   "Description updated with AI content" or "Description updated with template"
   ```

3. **Template Function Test:**
   ```r
   # Test in R console
   source("R/mod_stamp_export.R")
   test_title <- "USA - 1963 5c WASHINGTON LOT OF 6"
   template_desc <- build_template_description(test_title)
   cat(template_desc)

   # Expected output: title + boilerplate
   ```

4. **Comparison:**
   - Extract one lot with checkbox ✅ checked
   - Extract another lot with checkbox ☐ unchecked
   - Compare description field contents
   - Verify AI description is detailed, template is short

---

## Success Criteria

### Issue 1: Price Fixed
- [ ] Console logs show correct price from AI response
- [ ] `parse_stamp_response()` extracts correct price
- [ ] Database stores correct price
- [ ] UI displays correct price
- [ ] Price matches user's manual assessment of lot value
- [ ] Price is in USD (eBay's currency)
- [ ] Deduplication loads same correct price

### Issue 2: Description Logic Verified
- [ ] Checkbox is visible in UI
- [ ] Checkbox default state is documented
- [ ] Checked state → AI description populated
- [ ] Unchecked state → Template description populated
- [ ] Console logs match expected behavior
- [ ] User understands how to control description type

---

## Technical Context

### Price Extraction Chain (Issue 1)

```
AI Model (Claude/GPT-4o)
  ↓ Returns JSON with "ESTIMATED PRICE: $X"
parse_stamp_response() in R/stamp_ai_helpers.R
  ↓ Extracts price with regex or JSON parsing
parsed$price (numeric value)
  ↓
updateNumericInput(session, "starting_price_X", value = parsed$price)
  ↓
UI displays in price field
  ↓ (if user saves)
save_stamp_processing(ai_data = list(price = parsed$price))
  ↓
Database: stamp_processing.ai_price = X
```

**Potential Failure Points:**
- AI returns wrong format: "€50" instead of "$50"
- Regex fails to capture: `\$(\d+\.?\d*)` doesn't match "50 USD"
- Type conversion: "50" → 50.0 fails
- Database save/load: 50.0 → stored as "50.0" → loaded as 50 (works) or fails
- UI update: Race condition overwrites with old value

### Description Logic Chain (Issue 2)

```
User clicks accordion panel
  ↓
observeEvent(input$export_accordion)
  ↓
Pre-load observer checks for existing AI data
  ↓ (if exists)
existing_ai_data() populated
  ↓
Accordion open handler fires
  ↓
User sees form with existing/empty fields
  ↓
User checks/unchecks "Fetch AI description" checkbox
  ↓
User clicks "Extract with AI" button
  ↓
fetch_description <- input$fetch_ai_description_X %||% FALSE
  ↓
AI extraction runs
  ↓
if (fetch_description) {
  updateTextAreaInput(..., value = parsed$description)  # AI description
} else {
  template_description <- build_template_description(parsed$title)
  updateTextAreaInput(..., value = template_description)  # Template
}
```

**Potential Failure Points:**
- Checkbox not rendering in UI
- Checkbox ID mismatch (namespace issue)
- `input$fetch_ai_description_X` returns NULL instead of FALSE
- `%||%` operator fails, defaults to TRUE unexpectedly
- Template function crashes, falls back to AI description
- Later timing issue (150ms delay insufficient for checkbox read)

---

## Files to Examine

### Issue 1 (Price)
- `R/stamp_ai_helpers.R` - `parse_stamp_response()`, `build_stamp_prompt()`
- `R/mod_stamp_export.R` - Lines 1149 (price update), 1256 (price save), 703 (price pre-load)
- `R/tracking_database.R` - `save_stamp_processing()`, `find_stamp_processing()`
- `R/ai_api_helpers.R` - `call_claude_api()`, `call_openai_api()`

### Issue 2 (Description)
- `R/mod_stamp_export.R` - Lines 265 (checkbox UI), 977 (checkbox read), 1138-1147 (conditional), 39 (template)
- Compare with `R/mod_delcampe_export.R` - Lines 1122-1131 (postal card reference)

---

## Testing Protocol

### Manual Test: Issue 1 (Price)

**Setup:**
1. Open app, navigate to Stamps tab
2. Have test stamp lot ready (known value)
3. Open browser console (F12) and R console side-by-side

**Test Steps:**
```
1. Upload stamp face image → extract crops
2. Upload stamp verso image → extract crops
3. Wait for combined lot image
4. Open lot accordion panel
5. Click "Extract with AI"
6. Wait for extraction to complete
7. Capture:
   - R console: Full output from "📄 Raw AI Response" to "✅ Form fields updated"
   - Browser: Any JavaScript errors
   - UI: Price field value
   - Database: Query ai_price from stamp_processing
8. Compare:
   - AI JSON "ESTIMATED PRICE: $X"
   - Parsed price in console: "Price: $X"
   - UI price field: $X
   - Database ai_price: X
9. Identify where mismatch occurs
```

**Expected Values (Hypothetical):**
- AI Response: `"ESTIMATED PRICE: $25 (lot of 6 used stamps)"`
- Parsed: `25` (numeric)
- UI: `25.00` (formatted)
- Database: `25` (numeric)

**If Wrong:**
- Document which step shows wrong value
- Check if error is consistent or random
- Test with different lot (different stamp count/value)

### Manual Test: Issue 2 (Description)

**Setup:**
1. Open app, navigate to Stamps tab
2. Have test stamp lot ready

**Test A: Checkbox Checked (AI Description)**
```
1. Upload stamp images → get lot
2. Open lot accordion panel
3. ✅ CHECK the "Fetch AI description" checkbox
4. Click "Extract with AI"
5. Wait for completion
6. Check console for: "Fetch AI description: TRUE"
7. Check console for: "Description updated with AI content"
8. Verify description field has detailed AI text (100+ chars)
```

**Test B: Checkbox Unchecked (Template Description)**
```
1. Start over (or use different lot)
2. Open lot accordion panel
3. ☐ UNCHECK the "Fetch AI description" checkbox
4. Click "Extract with AI"
5. Wait for completion
6. Check console for: "Fetch AI description: FALSE"
7. Check console for: "Description updated with template"
8. Verify description field has template text (title + boilerplate)
```

**Compare:**
- Test A description should be LONG (AI-generated details)
- Test B description should be SHORT (title + fixed text)

---

## Next Steps

### Immediate Actions

1. **User Reproduction:**
   - User runs Manual Test: Issue 1
   - User captures full console output
   - User screenshots price field
   - User provides database query results

2. **User Verification:**
   - User runs Manual Test: Issue 2
   - User confirms checkbox visibility
   - User tests both checkbox states
   - User compares description outputs

3. **AI Assistant Analysis:**
   - Review user's console output
   - Identify exact failure point in price chain
   - Determine if description logic is working correctly
   - Propose specific fix

### Potential Fixes (Hypothetical)

**If Issue 1 is AI Parsing:**
```r
# Fix parse_stamp_response() to handle edge cases
parse_stamp_response <- function(ai_response) {
  # Enhanced regex to capture various price formats
  price_pattern <- "\\$?\\s*(\\d+\\.?\\d*)\\s*(?:USD|\\$)?"
  # ... improved extraction logic
}
```

**If Issue 1 is Database:**
```sql
-- Verify data type
PRAGMA table_info(stamp_processing);
-- If ai_price is TEXT, should be REAL
-- Migration needed
```

**If Issue 1 is Prompt:**
```r
# Clarify price instruction in build_stamp_prompt()
"2. ESTIMATED PRICE: Provide lot price in USD\n",
"   - Format: ESTIMATED PRICE: $XX (explanation)\n",
"   - Use $ symbol explicitly\n",
"   - Price is for ENTIRE LOT, not per stamp\n",
```

**If Issue 2 is UI Rendering:**
```r
# Check namespace in mod_stamp_export_ui()
checkboxInput(ns("fetch_ai_description_1"), "Fetch AI description", value = FALSE)
# Ensure ns() wrapper is correct
```

**If Issue 2 is Default State:**
```r
# Document expected defaults
# Postal cards: default = FALSE (template)
# Stamps: default = FALSE (template)
# Or change to TRUE if AI description preferred by default
```

---

## Dependencies

### Related Memories
- `.serena/memories/stamp_ai_deduplication_fix_20251031.md` - Recent fix to database calls
- `.serena/memories/ai_description_control_and_layout_improvements_20251030.md` - Description control patterns
- `.serena/memories/ebay_title_extraction_optimization_20251030.md` - Title extraction logic

### Related PRPs
- `PRPs/PRP_STAMPS_FEATURE.md` - Original stamp feature implementation

### Related Code
- `R/mod_delcampe_export.R` - Reference implementation (postal cards)
- `R/ai_api_helpers.R` - AI API integration
- `R/tracking_database.R` - Database functions

---

## Risk Assessment

### Issue 1: Wrong Price
- **Severity:** HIGH - Incorrect pricing could lead to financial loss
- **User Impact:** HIGH - User cannot trust AI extraction, must verify manually
- **Workaround:** User manually edits price after extraction
- **Data Integrity:** If database stores wrong price, deduplication perpetuates error

### Issue 2: Description Logic
- **Severity:** MEDIUM - Affects description quality, not critical data
- **User Impact:** MEDIUM - User may get unexpected description format
- **Workaround:** User manually edits description
- **Data Integrity:** Template vs AI is user choice, no data corruption

---

## Communication Plan

**User Report Format:**
```
# Issue 1: Price Investigation Results

Console Output:
```
[Paste full console output here]
```

Price Field Screenshot: [attach]

Database Query:
```
[Paste query results]
```

Expected Price: $XX
Actual Price: $YY

---

# Issue 2: Description Investigation Results

Checkbox Visible: Yes/No
Checkbox Default State: Checked/Unchecked

Test A (Checked):
  Description: [paste first 200 chars]
  Console: "Fetch AI description: TRUE" (yes/no)

Test B (Unchecked):
  Description: [paste first 200 chars]
  Console: "Fetch AI description: FALSE" (yes/no)

Behavior Matches Expected: Yes/No
```

**AI Response Format:**
```
# Diagnosis

Issue 1 Root Cause: [specific finding]
Issue 2 Root Cause: [specific finding]

# Fix Proposal

[Detailed fix with code examples]

# Testing Verification

[How to verify fix works]
```

---

## Acceptance Criteria

### Issue 1: Price
- [ ] AI extracts correct lot price
- [ ] Price is in USD
- [ ] Price reflects realistic market value
- [ ] Console logs show price extraction step-by-step
- [ ] Database stores correct price
- [ ] UI displays correct price
- [ ] Deduplication reloads same correct price

### Issue 2: Description
- [ ] Checkbox is visible and functional
- [ ] Checked → AI description populated
- [ ] Unchecked → Template description populated
- [ ] Console logs confirm checkbox state
- [ ] Behavior matches postal cards
- [ ] User understands control

---

## Notes

- **Timing:** Both issues reported together, may be related or independent
- **Test Data:** Only one stamp lot being tested, need diverse test cases
- **User Workflow:** User is actively testing stamps feature, high engagement
- **Recent Context:** Deduplication just fixed, AI integration known to work for postal cards

---

**Status:** 🔍 Awaiting user reproduction and console output
**Next Owner:** User (testing) → AI Assistant (diagnosis) → User (fix verification)
