# PRP: Conditional AI Prompts Based on Description Checkbox

**Status**: Ready for Implementation
**Priority**: Medium
**Created**: 2025-11-01
**Estimated Effort**: 2-3 hours
**Related PRPs**: PRP_AI_DESCRIPTION_CONTROL_AND_ACCORDION_LAYOUT.md

---

## Context

Currently, the AI extraction feature for both postal cards and stamps has a "Fetch AI description" checkbox that only controls **what gets displayed in the UI**, not **what the AI is asked to extract**. This is inefficient and contradicts user expectations.

### Current Behavior (Inefficient)

**When checkbox is UNCHECKED:**
- ❌ AI is still asked to extract: TITLE + DESCRIPTION + all metadata
- ❌ Full prompt sent to API (wastes tokens and costs money)
- ✅ UI displays: Title + Template description (AI description discarded)

**When checkbox is CHECKED:**
- ✅ AI is asked to extract: TITLE + DESCRIPTION + all metadata
- ✅ Full prompt sent to API
- ✅ UI displays: Title + AI description

### Desired Behavior (Efficient)

**When checkbox is UNCHECKED:**
- ✅ AI is asked to extract: TITLE + PRICE + GRADE/CONDITION only
- ✅ Minimal prompt sent to API (saves ~50% tokens)
- ✅ Faster AI response (less to generate)
- ✅ UI displays: Title + Template description

**When checkbox is CHECKED:**
- ✅ AI is asked to extract: TITLE + DESCRIPTION + all metadata
- ✅ Full prompt sent to API
- ✅ UI displays: Title + AI description

---

## Problem Statement

The checkbox should control **what the AI extracts**, not just **what the UI displays**:

1. **Token Waste**: When unchecked, we send full prompts but discard the description
2. **Cost Inefficiency**: Paying for AI-generated content we don't use
3. **Slower Response**: AI generates unnecessary content
4. **User Confusion**: Checkbox label says "Fetch AI description" but AI always fetches it
5. **Inconsistent Behavior**: Different logic needed for stamps vs postal cards

---

## Success Criteria

### For Both Postal Cards and Stamps

- [ ] When checkbox **UNCHECKED**: Send minimal prompt (title + price + condition only)
- [ ] When checkbox **CHECKED**: Send full prompt (title + description + all metadata)
- [ ] Minimal prompt is ~50% shorter than full prompt
- [ ] Description field correctly populated in both cases
- [ ] No regression in existing extraction accuracy
- [ ] Console logs show which prompt type was used
- [ ] Token usage reduced when checkbox unchecked

### For Postal Cards Specifically

- [ ] Full prompt requests: TITLE, DESCRIPTION, PRICE, CONDITION, YEAR, ERA, CITY, FEATURES
- [ ] Minimal prompt requests: TITLE, PRICE, CONDITION only
- [ ] Template description = Title + STANDARD_DESCRIPTION_TEMPLATE

### For Stamps Specifically

- [ ] Full prompt requests: TITLE, DESCRIPTION, RECOMMENDED_PRICE, GRADE, COUNTRY, YEAR, DENOMINATION, SCOTT_NUMBER, PERFORATION, WATERMARK
- [ ] Minimal prompt requests: TITLE, RECOMMENDED_PRICE, GRADE only
- [ ] Template description = Title + STANDARD_DESCRIPTION_TEMPLATE
- [ ] `build_stamp_prompt_title_only()` function already exists ✅

---

## Technical Requirements

### 1. Postal Cards - Create Minimal Prompt Function

**Current State:**
- Postal cards use a prompt from Python integration (likely `extract_postal_card_info`)
- No minimal prompt option exists

**Required Changes:**

**File: `R/mod_ai_extraction.R` or appropriate helper file**

Create a new function `build_postal_card_prompt_minimal()`:

```r
#' Build minimal postal card prompt (title + price + condition only)
#'
#' @param extraction_type Character: "individual" or "lot"
#' @param card_count Integer: Number of cards in lot (if lot type)
#' @return Character: Minimal AI prompt
build_postal_card_prompt_minimal <- function(extraction_type = "individual", card_count = 1) {

  # ASCII-only instruction
  ascii_instruction <- "IMPORTANT: Use ONLY ASCII characters in your output. Replace all diacritics:
- Romanian: ă→a, â→a, î→i, ș→s, ț→t
- European: é→e, è→e, ü→u, ö→o, ñ→n, ç→c
- Examples: București → Bucuresti, café → cafe\n\n"

  base_prompt <- "You are an expert postal history analyst. Analyze this postcard image and provide TITLE, PRICE, and CONDITION only.\n\n"

  if (extraction_type == "lot") {
    prompt <- paste0(ascii_instruction, base_prompt,
      "IMPORTANT: This is a lot of ", card_count, " postcards.\n",
      "Provide pricing for the entire lot combined.\n\n",

      "REQUIRED FIELDS (extract these only):\n\n",
      "1. TITLE: eBay-optimized title (MAXIMUM 80 characters)\n",
      "   - ALL UPPERCASE format\n",
      "   - Format: LOCATION - YEAR TOPIC/FEATURES\n",
      "   - Example: 'ROMANIA - 1930s BUCURESTI STREET VIEW LOT OF 4'\n\n",

      "2. PRICE: eBay sale price in USD for entire lot\n",
      "   - Typical range per card: $1-5 (common), $5-15 (uncommon), $15+ (rare)\n",
      "   - Format: numeric value only (e.g., 16.00 for 4 cards at $4 each)\n\n",

      "3. CONDITION: Overall condition assessment\n",
      "   - Options: Excellent, Good, Fair, Poor\n",
      "   - Base on most common condition in lot\n\n",

      "Format your response EXACTLY as:\n",
      "TITLE: [your title]\n",
      "PRICE: [numeric value]\n",
      "CONDITION: [condition]"
    )
  } else {
    prompt <- paste0(ascii_instruction, base_prompt,
      "Analyze this individual postcard.\n\n",

      "REQUIRED FIELDS (extract these only):\n\n",
      "1. TITLE: eBay-optimized title (MAXIMUM 80 characters)\n\n",
      "2. PRICE: eBay sale price in USD\n\n",
      "3. CONDITION: Condition assessment (Excellent/Good/Fair/Poor)\n\n",

      "Format your response EXACTLY as:\n",
      "TITLE: [your title]\n",
      "PRICE: [numeric value]\n",
      "CONDITION: [condition]"
    )
  }

  return(prompt)
}
```

---

### 2. Postal Cards - Update Extraction Handler

**File: `R/mod_delcampe_export.R`**

**Current code (around line 1065-1078):**
```r
# AI extraction observer
observeEvent(input[[paste0("extract_ai_", i)]], {

  # Get checkbox state
  fetch_description <- input[[paste0("fetch_ai_description_", i)]] %||% FALSE

  cat("🎯 Extract AI button clicked for image", i, "\n")
  cat("   Fetch AI description:", fetch_description, "\n")

  # ... existing code ...

  # Call AI API with prompt
  result <- call_ai_api(
    image_path = current_path,
    prompt = build_enhanced_prompt(extraction_type, card_count)  # ❌ Always full prompt
  )

  # ... rest of code ...
})
```

**Required change:**
```r
# AI extraction observer
observeEvent(input[[paste0("extract_ai_", i)]], {

  # Get checkbox state
  fetch_description <- input[[paste0("fetch_ai_description_", i)]] %||% FALSE

  cat("🎯 Extract AI button clicked for image", i, "\n")
  cat("   Fetch AI description:", fetch_description, "\n")

  # ... existing code to determine extraction_type and card_count ...

  # CONDITIONAL PROMPT SELECTION
  prompt <- if (fetch_description) {
    # Full prompt with description request
    cat("   Using FULL prompt (description requested)\n")
    build_enhanced_prompt(
      extraction_type = extraction_type,
      card_count = card_count
    )
  } else {
    # Minimal prompt (title + price + condition only)
    cat("   Using MINIMAL prompt (title/price/condition only)\n")
    build_postal_card_prompt_minimal(
      extraction_type = extraction_type,
      card_count = card_count
    )
  }

  # Call AI API with selected prompt
  result <- call_ai_api(
    image_path = current_path,
    prompt = prompt  # ✅ Conditional prompt
  )

  # ... rest of code ...
})
```

---

### 3. Stamps - Already Partially Implemented

**Current State:**
- ✅ `build_stamp_prompt()` - Full prompt (already exists)
- ✅ `build_stamp_prompt_title_only()` - Minimal prompt (already exists in R/stamp_ai_helpers.R)
- ✅ Conditional prompt selection implemented in R/mod_stamp_export.R lines 1065-1078

**Verification Needed:**

Check that the implementation is complete:

```r
# This should already exist in R/mod_stamp_export.R
prompt <- if (fetch_description) {
  # Full prompt with description request
  build_stamp_prompt(
    extraction_type = if(image_type == "lot") "lot" else "individual",
    stamp_count = 1
  )
} else {
  # Title-only prompt (skip description to save tokens)
  build_stamp_prompt_title_only(
    extraction_type = if(image_type == "lot") "lot" else "individual",
    stamp_count = 1
  )
}
```

**If missing:** Add the same conditional logic as postal cards (see section 2 above)

---

### 4. Parser Compatibility

Both parsers must handle responses from both full and minimal prompts gracefully.

**For Postal Cards:**

**Parser:** `parse_enhanced_ai_response()` or equivalent

**Required behavior:**
- ✅ When full prompt: Extract all fields (title, description, price, condition, year, era, city)
- ✅ When minimal prompt: Extract available fields only (title, price, condition)
- ✅ Missing fields should return `NA` (not cause errors)

**Example response from minimal prompt:**
```
TITLE: ROMANIA - 1930s BUCURESTI STREET VIEW LOT OF 4
PRICE: 16.00
CONDITION: Good
```

**Parser should handle:**
```r
parsed <- parse_enhanced_ai_response(result$content)
# Expected result:
# parsed$title = "ROMANIA - 1930s BUCURESTI STREET VIEW LOT OF 4"
# parsed$price = 16.00
# parsed$condition = "Good"
# parsed$description = NA  # ← Not in response, should be NA
# parsed$year = NA
# parsed$era = NA
# parsed$city = NA
```

**For Stamps:**

**Parser:** `parse_stamp_response()` (R/stamp_ai_helpers.R)

**Required behavior:**
- ✅ Already handles minimal responses (verified in memory: stamp_ai_extraction_complete_fix_20251101)
- ✅ Regex pattern extracts available fields only
- ✅ Missing fields return `NA_character_`

---

### 5. UI Update Logic

Both modules must handle conditional description population correctly.

**For Postal Cards (R/mod_delcampe_export.R):**

```r
# After AI response received and parsed
if (result$success) {
  parsed <- parse_enhanced_ai_response(result$content)

  # Always update title
  shiny::updateTextAreaInput(session, paste0("item_title_", i), value = parsed$title)

  # CONDITIONAL: Update description based on checkbox
  if (fetch_description) {
    # AI-generated description (from full prompt)
    shiny::updateTextAreaInput(
      session,
      paste0("item_description_", i),
      value = parsed$description
    )
    cat("      Description updated with AI content (length:", nchar(parsed$description), ")\n")
  } else {
    # Template-based description (minimal prompt didn't request description)
    template_description <- build_template_description(parsed$title)
    shiny::updateTextAreaInput(
      session,
      paste0("item_description_", i),
      value = template_description
    )
    cat("      Description updated with template (length:", nchar(template_description), ")\n")
  }

  # Update price and condition
  shiny::updateNumericInput(session, paste0("item_price_", i), value = parsed$price)
  shiny::updateSelectInput(session, paste0("item_condition_", i), selected = parsed$condition)

  # Update other fields if they exist (from full prompt)
  if (!is.na(parsed$year)) {
    shiny::updateTextInput(session, paste0("item_year_", i), value = parsed$year)
  }
  if (!is.na(parsed$era)) {
    shiny::updateTextInput(session, paste0("item_era_", i), value = parsed$era)
  }
  if (!is.na(parsed$city)) {
    shiny::updateTextInput(session, paste0("item_city_", i), value = parsed$city)
  }
}
```

**For Stamps (R/mod_stamp_export.R):**

Same logic as postal cards, but using stamp-specific fields:

```r
# After AI response received and parsed
if (result$success) {
  parsed <- parse_stamp_response(result$content)

  # Always update title
  shiny::updateTextAreaInput(session, paste0("item_title_", i), value = parsed$title)

  # CONDITIONAL: Update description based on checkbox
  if (fetch_description) {
    # AI-generated description
    shiny::updateTextAreaInput(
      session,
      paste0("item_description_", i),
      value = parsed$description
    )
  } else {
    # Template-based description
    template_description <- build_template_description(parsed$title)
    shiny::updateTextAreaInput(
      session,
      paste0("item_description_", i),
      value = template_description
    )
  }

  # Update price and grade (always returned from both prompts)
  shiny::updateNumericInput(session, paste0("item_price_", i), value = parsed$recommended_price)
  shiny::updateSelectInput(session, paste0("item_grade_", i), selected = parsed$grade)

  # Update metadata fields if they exist (only from full prompt)
  if (!is.na(parsed$country)) {
    shiny::updateTextInput(session, paste0("item_country_", i), value = parsed$country)
  }
  if (!is.na(parsed$year)) {
    shiny::updateTextInput(session, paste0("item_year_", i), value = parsed$year)
  }
  # ... other metadata fields ...
}
```

---

### 6. Database Save Consistency

**Critical:** When saving to database, handle missing metadata fields gracefully.

**For Postal Cards:**

```r
# When saving AI data to database
ai_data <- list(
  condition = parsed$condition,      # ✅ Always present
  price = parsed$price,              # ✅ Always present
  title = parsed$title,              # ✅ Always present
  description = if (fetch_description) parsed$description else template_description,  # ✅ Conditional
  year = parsed$year %||% NA,        # ⚠️ May be NA from minimal prompt
  era = parsed$era %||% NA,          # ⚠️ May be NA from minimal prompt
  city = parsed$city %||% NA         # ⚠️ May be NA from minimal prompt
)

save_card_processing(
  file_hash = hash,
  image_type = type,
  ai_data = ai_data,
  # ...
)
```

**For Stamps:**

```r
# When saving AI data to database
ai_data <- list(
  condition = parsed$grade,                  # ✅ Always present
  price = parsed$recommended_price,          # ✅ Always present
  title = parsed$title,                      # ✅ Always present
  description = if (fetch_description) parsed$description else template_description,  # ✅ Conditional
  country = parsed$country %||% NA,          # ⚠️ May be NA from minimal prompt
  year = parsed$year %||% NA,                # ⚠️ May be NA from minimal prompt
  denomination = parsed$denomination %||% NA,  # ⚠️ May be NA from minimal prompt
  scott_number = parsed$scott_number %||% NA,  # ⚠️ May be NA from minimal prompt
  perforation = parsed$perforation %||% NA,    # ⚠️ May be NA from minimal prompt
  watermark = parsed$watermark %||% NA         # ⚠️ May be NA from minimal prompt
)
```

---

## Implementation Steps

### Phase 1: Postal Cards Minimal Prompt (1 hour)

**Step 1.1:** Create `build_postal_card_prompt_minimal()` function
- [ ] Add function to appropriate helper file (R/mod_ai_extraction.R or new R/postal_card_ai_helpers.R)
- [ ] Test prompt generation for both individual and lot types
- [ ] Verify ASCII-only instruction is included
- [ ] Compare prompt length vs full prompt (~50% reduction expected)

**Step 1.2:** Locate full prompt builder
- [ ] Find where `build_enhanced_prompt()` or equivalent is defined
- [ ] Verify it's the correct function for postal cards
- [ ] Document the function location for clarity

**Step 1.3:** Update extraction handler in R/mod_delcampe_export.R
- [ ] Find AI extraction observer (search for `extract_ai_`)
- [ ] Add conditional prompt selection logic
- [ ] Add console logging for prompt type
- [ ] Test with checkbox checked and unchecked

**Verification:**
- [ ] Console shows "Using FULL prompt" when checkbox checked
- [ ] Console shows "Using MINIMAL prompt" when checkbox unchecked
- [ ] Minimal prompt is ~50% shorter than full prompt
- [ ] No errors when sending either prompt type

---

### Phase 2: Parser Compatibility (30 minutes)

**Step 2.1:** Test postal card parser with minimal response
- [ ] Create test minimal AI response: `TITLE: ...\nPRICE: ...\nCONDITION: ...`
- [ ] Pass to `parse_enhanced_ai_response()`
- [ ] Verify it returns: title, price, condition (not NA)
- [ ] Verify it returns: description, year, era, city (as NA)
- [ ] Fix parser if it fails on missing fields

**Step 2.2:** Test stamp parser with minimal response (should already work)
- [ ] Create test minimal AI response: `TITLE: ...\nRECOMMENDED_PRICE: ...\nGRADE: ...`
- [ ] Pass to `parse_stamp_response()`
- [ ] Verify correct extraction (based on memory, this should already work)

**Verification:**
- [ ] Both parsers handle minimal responses without errors
- [ ] Missing fields return `NA`, not cause crashes
- [ ] All required fields extracted correctly

---

### Phase 3: Stamps Conditional Logic (30 minutes)

**Step 3.1:** Verify stamp implementation exists
- [ ] Check R/mod_stamp_export.R lines 1065-1078 for conditional prompt logic
- [ ] If missing, implement same pattern as postal cards

**Step 3.2:** Test stamp extraction with both prompt types
- [ ] Test with checkbox unchecked → minimal prompt
- [ ] Test with checkbox checked → full prompt
- [ ] Verify console logs show correct prompt type
- [ ] Verify UI populates correctly in both cases

**Verification:**
- [ ] Stamp module uses correct prompt based on checkbox
- [ ] Console logs prompt selection
- [ ] No regression in extraction accuracy

---

### Phase 4: UI and Database Integration (1 hour)

**Step 4.1:** Update postal card UI population logic
- [ ] Find where parsed data updates UI fields
- [ ] Add conditional checks for metadata fields (year, era, city)
- [ ] Only update fields if value is not NA
- [ ] Test UI updates with both prompt types

**Step 4.2:** Update stamp UI population logic (may already exist)
- [ ] Verify conditional metadata updates exist
- [ ] Test UI updates with both prompt types

**Step 4.3:** Verify database save handles NA values
- [ ] Check `save_card_processing()` accepts NA for metadata fields
- [ ] Check `save_stamp_processing()` accepts NA for metadata fields
- [ ] Verify database schema allows NULL values
- [ ] Test saving data from both minimal and full prompts

**Verification:**
- [ ] UI correctly populated with minimal prompt (title, price, condition, template description)
- [ ] UI correctly populated with full prompt (all fields including AI description)
- [ ] Database saves succeed with both prompt types
- [ ] Deduplication works correctly (loads previously saved metadata)

---

### Phase 5: Testing and Validation (30 minutes)

**Step 5.1:** Manual testing workflow
- [ ] Upload postal card lot
- [ ] Extract with checkbox UNCHECKED → verify minimal prompt used
- [ ] Verify title, price, condition populated
- [ ] Verify description = title + template
- [ ] Save to database
- [ ] Re-open image → verify deduplication loads saved data

**Step 5.2:** Repeat for checkbox CHECKED
- [ ] Extract with checkbox CHECKED → verify full prompt used
- [ ] Verify all fields populated including AI description
- [ ] Verify metadata fields (year, era, city) populated

**Step 5.3:** Repeat for stamps
- [ ] Test both checkbox states
- [ ] Verify stamp-specific fields

**Step 5.4:** Run critical tests
- [ ] `source("dev/run_critical_tests.R")`
- [ ] All tests must pass

**Verification:**
- [ ] No console errors
- [ ] Both prompt types work correctly
- [ ] UI updates correctly in all cases
- [ ] Database saves and retrieves correctly
- [ ] Critical tests pass

---

## Files to Modify

### New Files (if needed)

**Option A:** Create new helper file
- `R/postal_card_ai_helpers.R` - Contains `build_postal_card_prompt_minimal()`

**Option B:** Add to existing file
- `R/mod_ai_extraction.R` - Add `build_postal_card_prompt_minimal()` function

### Files to Modify

1. **R/mod_delcampe_export.R**
   - Lines ~1065-1078: Add conditional prompt selection
   - Lines ~1120-1160: Update UI population logic with NA checks
   - Lines ~1250-1270: Verify database save handles NA values

2. **R/mod_stamp_export.R**
   - Lines ~1065-1078: Verify/add conditional prompt selection (may already exist)
   - Lines ~1149-1180: Verify UI population logic handles NA values
   - Lines ~1255-1275: Verify database save handles NA values

3. **R/stamp_ai_helpers.R**
   - No changes needed (functions already exist)

4. **R/[postal_card_helpers].R** (wherever postal card prompts are defined)
   - Add `build_postal_card_prompt_minimal()` function

### Test Files

Create or update:
- `tests/testthat/test-postal_card_ai_helpers.R`
  - Test `build_postal_card_prompt_minimal()` generates correct prompt
  - Test prompt is ~50% shorter than full prompt
  - Test both individual and lot types

- `tests/testthat/test-stamp_ai_helpers.R`
  - Verify `build_stamp_prompt_title_only()` still works
  - Test both individual and lot types

---

## Prompt Comparison

### Postal Cards

**Full Prompt (with description):**
```
REQUIRED FIELDS:

1. TITLE: eBay-optimized title (MAXIMUM 80 characters)
2. DESCRIPTION: Detailed description (150-300 characters)
3. PRICE: eBay sale price in USD
4. CONDITION: Overall condition (Excellent/Good/Fair/Poor)
5. YEAR: Year or decade (e.g., 1920s, 1955)
6. ERA: Historical era (e.g., WWI, Interwar, Communist)
7. CITY: City or location depicted
8. FEATURES: Notable features (people, buildings, events)

Format your response EXACTLY as:
TITLE: [your title]
DESCRIPTION: [your description]
PRICE: [numeric value]
CONDITION: [condition]
YEAR: [year]
ERA: [era]
CITY: [city]
FEATURES: [features]
```

**Minimal Prompt (without description):**
```
REQUIRED FIELDS (extract these only):

1. TITLE: eBay-optimized title (MAXIMUM 80 characters)
2. PRICE: eBay sale price in USD
3. CONDITION: Overall condition (Excellent/Good/Fair/Poor)

Format your response EXACTLY as:
TITLE: [your title]
PRICE: [numeric value]
CONDITION: [condition]
```

**Token Reduction:** ~60% (8 fields → 3 fields)

---

### Stamps

**Full Prompt (with description):**
```
REQUIRED FIELDS:

1. TITLE: eBay-optimized title (MAXIMUM 80 characters)
2. DESCRIPTION: Detailed description (150-300 characters)
3. RECOMMENDED_PRICE: eBay sale price in USD
4. COUNTRY: Country of origin
5. YEAR: Year of issue
6. DENOMINATION: Face value
7. SCOTT_NUMBER: Scott catalog number
8. PERFORATION: Perforation type
9. WATERMARK: Watermark description
10. GRADE: Condition grade (MNH/MH/Used/Unused)

Format your response EXACTLY as:
TITLE: [your title]
DESCRIPTION: [your description]
RECOMMENDED_PRICE: [numeric value]
COUNTRY: [country]
YEAR: [year]
DENOMINATION: [value]
SCOTT_NUMBER: [catalog number]
PERFORATION: [type]
WATERMARK: [description]
GRADE: [condition]
```

**Minimal Prompt (already implemented in `build_stamp_prompt_title_only()`):**
```
REQUIRED FIELDS (extract these only):

1. TITLE: eBay-optimized title (MAXIMUM 80 characters)
2. RECOMMENDED_PRICE: eBay sale price in USD
3. GRADE: Condition grade (MNH/MH/Used/Unused)

Format your response EXACTLY as:
TITLE: [your title]
RECOMMENDED_PRICE: [numeric value]
GRADE: [condition]
```

**Token Reduction:** ~70% (10 fields → 3 fields)

---

## Expected Behavior After Implementation

### User Workflow 1: Fast Extraction (Checkbox Unchecked)

**User Action:** Unchecks "Fetch AI description" → Clicks "Extract with AI"

**System Behavior:**
1. ✅ Console: "Using MINIMAL prompt (title/price/condition only)"
2. ✅ Sends ~200 token prompt instead of ~500 token prompt
3. ✅ AI responds in ~2-3 seconds instead of ~5-7 seconds
4. ✅ UI populates: Title, Price, Condition
5. ✅ Description = Title + Standard Template
6. ✅ Metadata fields remain empty (or show NA)
7. ✅ User can manually edit any field
8. ✅ Saves to database: title, price, condition, template description

**Token Savings:** ~60-70% per extraction
**Cost Savings:** ~60-70% per extraction
**Time Savings:** ~50% faster response

---

### User Workflow 2: Full Extraction (Checkbox Checked)

**User Action:** Checks "Fetch AI description" → Clicks "Extract with AI"

**System Behavior:**
1. ✅ Console: "Using FULL prompt (description requested)"
2. ✅ Sends full ~500 token prompt
3. ✅ AI responds in ~5-7 seconds with complete analysis
4. ✅ UI populates: Title, Description (AI), Price, Condition, Year, Era, City, etc.
5. ✅ All metadata fields populated
6. ✅ User can manually edit any field
7. ✅ Saves to database: all fields including AI description and metadata

**Behavior:** Same as current implementation (no regression)

---

## Edge Cases & Error Handling

### Edge Case 1: Parser Receives Unexpected Format

**Scenario:** AI returns partial response or different format

**Handling:**
```r
# Parser should handle gracefully
parsed <- parse_enhanced_ai_response(result$content)

# Check critical fields
if (is.na(parsed$title)) {
  showNotification("AI extraction failed: Title missing", type = "error")
  return()
}

if (is.na(parsed$price)) {
  showNotification("AI extraction failed: Price missing", type = "warning")
  # Continue with title only
}
```

---

### Edge Case 2: Checkbox State Changes After Extraction

**Scenario:** User extracts with checkbox unchecked, then checks it and extracts again

**Handling:**
- ✅ Each extraction is independent
- ✅ Second extraction will use full prompt
- ✅ UI will update with new data (including AI description)
- ✅ Database will save most recent extraction

---

### Edge Case 3: Deduplication with Different Prompt Types

**Scenario:** Image extracted with full prompt, then uploaded again and extracted with minimal prompt

**Handling:**
```r
# When loading from database
if (!is.null(existing$ai_description) && existing$ai_description != "") {
  # Previous extraction had AI description
  # Current extraction uses template
  # Template overrides AI description (user's choice via checkbox)
}

# Database fields that weren't requested in minimal prompt stay NULL
# This is acceptable - user chose to not extract metadata
```

---

### Edge Case 4: Database Query Returns Incomplete Data

**Scenario:** Database has title and price but no condition (from old extraction)

**Handling:**
```r
# UI update should handle missing values
if (!is.na(parsed$condition)) {
  shiny::updateSelectInput(session, paste0("item_condition_", i), selected = parsed$condition)
} else {
  # Leave as default or show placeholder
}
```

---

## Testing Checklist

### Postal Cards

**Minimal Prompt Testing:**
- [ ] Upload individual postal card
- [ ] Uncheck "Fetch AI description"
- [ ] Click "Extract with AI"
- [ ] Console shows "Using MINIMAL prompt"
- [ ] Title field populated
- [ ] Price field populated
- [ ] Condition field populated
- [ ] Description field = title + template
- [ ] Year/Era/City fields empty or NA
- [ ] Save to database succeeds
- [ ] Reload image → deduplication works

**Full Prompt Testing:**
- [ ] Upload individual postal card
- [ ] Check "Fetch AI description"
- [ ] Click "Extract with AI"
- [ ] Console shows "Using FULL prompt"
- [ ] All fields populated (title, AI description, price, condition, year, era, city)
- [ ] Save to database succeeds
- [ ] Reload image → deduplication works

**Lot Testing:**
- [ ] Repeat minimal and full tests with lot of cards
- [ ] Verify prompt mentions card_count correctly
- [ ] Verify pricing reflects lot size

---

### Stamps

**Minimal Prompt Testing:**
- [ ] Upload individual stamp
- [ ] Uncheck "Fetch AI description"
- [ ] Click "Extract with AI"
- [ ] Console shows "Using MINIMAL prompt" (or equivalent)
- [ ] Title field populated
- [ ] Price field populated
- [ ] Grade field populated
- [ ] Description field = title + template
- [ ] Country/Year/Denomination/etc. fields empty or NA
- [ ] Save to database succeeds

**Full Prompt Testing:**
- [ ] Upload individual stamp
- [ ] Check "Fetch AI description"
- [ ] Click "Extract with AI"
- [ ] All fields populated including metadata
- [ ] Save to database succeeds

**Lot Testing:**
- [ ] Repeat minimal and full tests with stamp lot
- [ ] Verify correct prompt and pricing

---

### Integration Testing

- [ ] Run `source("dev/run_critical_tests.R")` - all tests pass
- [ ] No console errors or warnings
- [ ] No regression in existing functionality
- [ ] Both modules work independently
- [ ] Database schema unchanged (only data differences)
- [ ] Deduplication works with both prompt types

---

## Performance Metrics

### Before Implementation

**Per Extraction (Checkbox Unchecked):**
- Prompt tokens: ~500
- Response tokens: ~200
- Total tokens: ~700
- Cost: ~$0.01 (varies by model)
- Time: ~5-7 seconds
- **BUT:** Description discarded, metadata unused

### After Implementation

**Per Extraction (Checkbox Unchecked):**
- Prompt tokens: ~200 (60% reduction)
- Response tokens: ~80 (60% reduction)
- Total tokens: ~280 (60% reduction)
- Cost: ~$0.004 (60% savings)
- Time: ~2-3 seconds (50% faster)
- **AND:** Only requested data extracted

**Per Extraction (Checkbox Checked):**
- Same as before (no regression)

### Projected Annual Savings

**Assumptions:**
- 1000 extractions per month
- 50% use minimal prompt (checkbox unchecked)
- 50% use full prompt (checkbox checked)

**Monthly Savings:**
- Token reduction: ~210,000 tokens (500 extractions × 420 tokens saved)
- Cost savings: ~$3-5 per month
- Time savings: ~25 minutes per month (500 extractions × 3 seconds saved)

**Annual Savings:**
- Token reduction: ~2.5 million tokens
- Cost savings: ~$36-60 per year
- Time savings: ~5 hours per year

**User Experience:**
- Faster extraction when description not needed
- Clearer intent (checkbox controls what AI does)
- No wasted API calls

---

## Validation Gates

### Gate 1: Prompt Function Creation
- [ ] `build_postal_card_prompt_minimal()` function exists
- [ ] Function generates valid prompt for individual cards
- [ ] Function generates valid prompt for card lots
- [ ] Prompt is ~50% shorter than full prompt
- [ ] Prompt includes ASCII-only instruction

### Gate 2: Parser Compatibility
- [ ] Postal card parser handles minimal responses without errors
- [ ] Stamp parser handles minimal responses without errors (already verified)
- [ ] Missing fields return NA (not crash)
- [ ] Required fields extracted correctly

### Gate 3: Conditional Logic
- [ ] Postal card module uses correct prompt based on checkbox
- [ ] Stamp module uses correct prompt based on checkbox
- [ ] Console logs show prompt type selection

### Gate 4: UI Integration
- [ ] UI updates correctly with minimal prompt data
- [ ] UI updates correctly with full prompt data
- [ ] Template description populated when checkbox unchecked
- [ ] AI description populated when checkbox checked

### Gate 5: Database Integration
- [ ] Database save succeeds with minimal prompt data (some fields NA)
- [ ] Database save succeeds with full prompt data (all fields)
- [ ] Deduplication loads saved data correctly
- [ ] No database schema changes required

### Gate 6: Testing
- [ ] Manual testing complete for postal cards (both prompt types)
- [ ] Manual testing complete for stamps (both prompt types)
- [ ] Critical tests pass: `source("dev/run_critical_tests.R")`
- [ ] No console errors or warnings
- [ ] No regression in extraction accuracy

### Gate 7: Documentation
- [ ] Memory file created: `.serena/memories/conditional_ai_prompts_implementation_YYYYMMDD.md`
- [ ] Console logs clearly indicate prompt type
- [ ] Code comments explain conditional logic

---

## Acceptance Criteria

Implementation is complete when:

1. ✅ Postal card minimal prompt function created and tested
2. ✅ Postal card module uses conditional prompt selection
3. ✅ Stamp module uses conditional prompt selection (verify existing or implement)
4. ✅ Both parsers handle minimal responses gracefully
5. ✅ UI updates correctly for both prompt types
6. ✅ Database saves succeed for both prompt types
7. ✅ Deduplication works with both prompt types
8. ✅ Console logs show prompt type selection
9. ✅ Token usage reduced ~60% when checkbox unchecked
10. ✅ No regression in extraction accuracy
11. ✅ No console errors or warnings
12. ✅ Critical tests pass
13. ✅ Manual testing confirms both workflows work correctly
14. ✅ Documentation updated in `.serena/memories/`

---

## Related Documentation

- `.serena/memories/ai_description_control_and_layout_improvements_20251030.md` - Original checkbox implementation
- `.serena/memories/stamp_ai_extraction_complete_fix_20251101.md` - Stamp prompt implementation
- `PRPs/PRP_AI_DESCRIPTION_CONTROL_AND_ACCORDION_LAYOUT.md` - Original PRP for checkbox feature
- `R/stamp_ai_helpers.R` - Contains `build_stamp_prompt_title_only()` (reference implementation)
- `CLAUDE.md` - Module design principles

---

## Risk Assessment

**Low Risk:**
- Additive changes (doesn't break existing functionality)
- Conditional logic is clear and explicit
- Stamp implementation already exists as reference
- Parser changes minimal (should already handle missing fields)

**Medium Risk:**
- Postal card prompt builder location unknown (need to find it first)
- Parser compatibility needs verification
- Database save must handle NA values correctly

**Mitigation:**
- Implement postal cards first (more work), verify stamps (likely done)
- Test parsers thoroughly with minimal responses
- Add NA checks in all UI update and database save code
- Comprehensive console logging for debugging

---

## Success Metrics

After implementation:

- ✅ Users can choose between fast extraction (minimal) and detailed extraction (full)
- ✅ Checkbox label accurately reflects behavior ("Fetch AI description" controls prompt)
- ✅ Token usage reduced ~60% when description not needed
- ✅ API costs reduced ~60% when description not needed
- ✅ Extraction speed improved ~50% when description not needed
- ✅ No regression in full extraction accuracy
- ✅ User workflow clear and predictable
- ✅ Code maintainable and well-documented

---

## Implementation Notes

- **Start with postal cards** - More work needed (new prompt function)
- **Verify stamps** - May already be implemented (check R/mod_stamp_export.R:1065-1078)
- **Test parsers early** - Critical for both prompt types
- **Add logging everywhere** - Makes debugging much easier
- **Handle NA gracefully** - Missing fields are expected, not errors
- **Document prompt selection** - Console logs should clearly show which prompt was used
- **Preserve database compatibility** - NULL values should be acceptable for optional metadata

---

## Git Commit Message Template

```
feat: Implement conditional AI prompts based on description checkbox

POSTAL CARDS:
- Add build_postal_card_prompt_minimal() for title/price/condition only
- Update mod_delcampe_export.R with conditional prompt selection
- Verify parser handles minimal responses (missing metadata fields)
- Add NA checks in UI update and database save logic

STAMPS:
- Verify build_stamp_prompt_title_only() conditional logic exists
- Add/verify conditional prompt selection in mod_stamp_export.R
- Verify parser handles minimal responses

BENEFITS:
- ~60% token reduction when checkbox unchecked
- ~60% cost savings when description not needed
- ~50% faster extraction when using minimal prompt
- Clearer user intent (checkbox controls what AI extracts)

TECHNICAL:
- Minimal prompt: TITLE + PRICE + CONDITION/GRADE only
- Full prompt: All fields including description and metadata
- Parsers handle missing fields gracefully (return NA)
- Database saves succeed with partial data (NA for optional fields)
- Deduplication works with both prompt types

TESTING:
- Manual testing for both postal cards and stamps
- Both checkbox states tested (checked and unchecked)
- Individual and lot types tested
- Critical tests pass

Closes #PRP_CONDITIONAL_AI_PROMPTS_DESCRIPTION_CHECKBOX
Related: #PRP_AI_DESCRIPTION_CONTROL_AND_ACCORDION_LAYOUT
```

---

**Status:** Ready for Implementation
**Priority:** Medium (improves efficiency, reduces costs, better UX)
**Estimated ROI:** High (token/cost savings accumulate over time)
**Risk Level:** Low-Medium (mostly additive, needs thorough testing)
