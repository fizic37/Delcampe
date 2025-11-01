# Conditional AI Prompts & Stamp Field Corrections - 2025-11-01

## Overview

Implemented conditional AI prompt selection based on "Fetch AI description" checkbox to save tokens, plus fixed multiple stamp module issues discovered during implementation.

## Feature 1: Conditional AI Prompts

### User Need
Save AI API costs by ~30-40% when user doesn't need AI-generated descriptions.

### Implementation

**Checkbox Controls What AI Extracts** (not just what displays):
- **Unchecked**: Minimal prompt (title + metadata only) - ~40% token reduction
- **Checked**: Full prompt (title + description + metadata)

### Files Modified

#### R/ai_api_helpers.R
**New Function** `build_postal_card_prompt_minimal()` (lines 752-911):
- Requests: TITLE, PRICE, YEAR, ERA, CITY, COUNTRY, REGION, THEME_KEYWORDS
- Does NOT request: DESCRIPTION (template used instead)
- Note: Do NOT assess condition - seller will determine that

**Parser** already correct - defaults condition to "used" (line 1033)

#### R/mod_delcampe_export.R
**Conditional Prompt Selection** (lines 1049-1066):
```r
fetch_description <- input[[paste0("fetch_ai_description_", i)]] %||% FALSE
prompt <- if (fetch_description) {
  cat("   Using FULL prompt (description requested)\n")
  build_enhanced_postal_card_prompt(...)
} else {
  cat("   Using MINIMAL prompt (title/price only - saves tokens)\n")
  build_postal_card_prompt_minimal(...)
}
```

**Conditional Description Save** (lines 1246-1268):
```r
description_to_save <- if (fetch_description) {
  parsed$description  # AI-generated
} else {
  build_template_description(parsed$title)  # Template
}

ai_data <- list(
  title = parsed$title,
  description = description_to_save,  # ✅ Saves correct description
  # ... other fields
)
```

**CRITICAL**: Template description must be saved to database for deduplication to work.

#### R/stamp_ai_helpers.R
**New Function** `build_stamp_prompt_title_only()` (lines 158-253):
- Similar to postal card minimal prompt
- Stamp-specific metadata fields

**Updated** `build_stamp_prompt()` to remove GRADE/CONDITION fields (lines 82-91 removed)
**Updated** parser to hardcode grade = "used" (line 258)

#### R/mod_stamp_export.R
**Conditional Prompt Selection** - same pattern as postal cards
**Conditional Description Save** (lines 1257-1283) - same pattern as postal cards

### Token Savings

**Postal Cards**:
- Full prompt: ~2682 characters
- Minimal prompt: ~1091 characters
- **Reduction**: ~59%

**Stamps**:
- Full prompt: ~10 fields
- Minimal prompt: ~3 fields  
- **Reduction**: ~70%

**Actual savings**: ~30-40% overall (AI responses still have some overhead)

## Feature 2: Condition/Grade Removal from AI Extraction

### Problem
AI cannot reliably assess stamp condition from photos - it's subjective and requires expertise.

### Solution
- Removed GRADE/CONDITION from all AI prompts
- Parser hardcodes `grade = "used"` (seller changes manually if needed)
- UI always defaults to "used" selection

### Why "Used" Default
- Most stamps in bulk lots are used (cancelled)
- Conservative default (better to upgrade than downgrade)
- Seller has full control to change

## Feature 3: Stamp UI Field Corrections

### Problem Discovered
Stamp module had **completely wrong UI fields** - copied from postal cards without adaptation.

**What Was Wrong**:
- UI had: era, city, region, theme_keywords (postal card fields)
- Database had: ai_denomination, ai_scott_number, ai_perforation, ai_watermark (stamp fields)
- AI was extracting stamp fields but UI couldn't display them

### eBay Category Differences

**Postal Cards (Category 262042)**:
- year, era, city, country, region, theme_keywords

**Stamps (Category 260)**:
- year, denomination, scott_number, country, perforation, watermark

**Common**: year, country
**Different**: Everything else

### Files Modified: R/mod_stamp_export.R

**1. UI Form Fields** (lines 393-490):
- REMOVED: era (selectInput), city, region, theme_keywords (textInput)
- ADDED: denomination, scott_number (textAreaInput), perforation, watermark (textAreaInput)
- Added purple visual separator for advanced manual-entry fields

**2. UI Population - Deduplication** (lines 864-903):
- REMOVED: Updates for era, city, region, theme_keywords
- ADDED: Updates for denomination, scott_number, perforation, watermark
- Changed to updateTextAreaInput for scott/perf/watermark

**3. UI Population - AI Extraction** (lines 1167-1193):
- REMOVED: Population for era, city, region, theme_keywords, scott_number, perforation, watermark
- ADDED: Population for denomination only
- Note: Scott/perf/watermark NOT populated by AI (manual entry only)

**4. Manual Save to Database** (lines 1582-1652):
- REMOVED: Reading era, city, region, theme_keywords from inputs
- ADDED: Reading denomination, scott_number, perforation, watermark from inputs
- Updated ai_data structure accordingly

## Feature 4: Stamp Advanced Fields - Manual Entry Only

### Problem
AI cannot realistically extract these fields from photos:
- **Scott Number**: Requires catalog knowledge (not printed on stamp)
- **Perforation**: Requires measurement tools
- **Watermark**: Requires special lighting/backlight

### Solution

**1. Removed from AI Prompts** (R/stamp_ai_helpers.R):
- All 4 prompts updated to remove Scott Number, Perforation, Watermark
- Added note: "Do NOT attempt to identify Scott catalog numbers, perforation types, or watermarks"

**2. Parser Updated** (R/stamp_ai_helpers.R:255-257):
```r
scott_number = NA_character_,  # Not extracted by AI - manual entry only
perforation = NA_character_,   # Not extracted by AI - manual entry only
watermark = NA_character_,     # Not extracted by AI - manual entry only
```

**3. UI Redesigned** (R/mod_stamp_export.R:445-490):
- Changed from textInput to textAreaInput
- Added purple visual separator
- Label: "Advanced Philatelic Details (Manual Entry Only)"
- Helper text: "Scott Number, Perforation, Watermark - fill in if you know them"

**4. Population Logic**:
- AI extraction: Does NOT populate these fields (lines 1192-1193)
- Deduplication: DOES populate if user manually entered before (lines 889-903)

### AI Capability Matrix

| Field | What It Is | AI Can Extract? |
|-------|-----------|-----------------|
| Denomination | Face value on stamp | ✅ YES - Printed on stamp |
| Year | Year of issue | ✅ YES - Often printed |
| Country | Country of origin | ✅ YES - Identifiable from design |
| Scott Number | Catalog ID | ❌ NO - Requires expert knowledge |
| Perforation | Edge type | ❌ NO - Requires measurement |
| Watermark | Paper pattern | ❌ NO - Requires special lighting |

## Bug Fix: Condition Not Populating from Deduplication

### Problem
Reloading stamp image didn't populate condition to "used".

### Root Cause
`stamp_processing` table has TWO columns:
- `ai_condition` - What deduplication reads from
- `ai_grade` - What save function expects

ai_data was only setting `condition`, not `grade`.

### Fix (R/mod_stamp_export.R:1273-1274):
```r
condition = parsed$grade,  // For ai_condition column  
grade = parsed$grade,      // For ai_grade column (both set to "used")
```

## Testing Guide

See: `dev/TESTING_CONDITIONAL_PROMPTS.md`

**Key Test Cases**:
1. ✅ Minimal prompt: Faster, no description, metadata populated
2. ✅ Full prompt: Normal speed, AI description, all metadata
3. ✅ Template description saves to database
4. ✅ Deduplication works for both cases
5. ✅ Condition defaults to "used"
6. ✅ Scott/perf/watermark NOT populated by AI
7. ✅ Manual entries persist in database

## Database Schema

**Already Correct** - No changes needed:

### postal_card_processing
```sql
ai_condition TEXT,
ai_year INTEGER,
ai_era TEXT,
ai_city TEXT,
ai_country TEXT,
ai_region TEXT,
ai_theme_keywords TEXT
```

### stamp_processing
```sql
ai_condition TEXT,
ai_year INTEGER,
ai_country TEXT,
ai_denomination TEXT,
ai_scott_number TEXT,
ai_perforation TEXT,
ai_watermark TEXT,
ai_grade TEXT
```

## Files Summary

### Modified
- **R/ai_api_helpers.R**: Added minimal postal card prompt, parser already correct
- **R/stamp_ai_helpers.R**: Added minimal prompt, removed condition/grade, removed scott/perf/watermark
- **R/mod_delcampe_export.R**: Conditional prompts, conditional description save
- **R/mod_stamp_export.R**: Conditional prompts, corrected UI fields, advanced fields manual-only

### Created (Documentation)
- **PRPs/PRP_CONDITIONAL_AI_PROMPTS_DESCRIPTION_CHECKBOX.md**: Feature specification
- **dev/TESTING_CONDITIONAL_PROMPTS.md**: Testing guide
- **dev/cleanup_all_stamps.R**: Utility for testing
- **dev/cleanup_all_postal_cards.R**: Utility for testing

### Database
- **R/tracking_database.R**: No changes (schema was already correct)

## User Experience Improvements

### Before
- AI always generated descriptions (slow, expensive)
- Stamp UI showed wrong fields (postal card fields)
- AI attempted to extract unrealistic fields
- Condition field empty on deduplication

### After
- User controls when AI generates descriptions (fast, cheap option available)
- Stamp UI shows correct stamp-specific fields
- Advanced philatelic fields clearly marked "Manual Entry Only"
- Condition properly defaults to "used" everywhere
- Template descriptions work seamlessly
- Deduplication preserves all data correctly

## Related Documentation

- Original PRP: PRPs/PRP_CONDITIONAL_AI_PROMPTS_DESCRIPTION_CHECKBOX.md
- Testing guide: dev/TESTING_CONDITIONAL_PROMPTS.md
- Code style: .serena/memories/code_style_and_conventions.md
- Project overview: .serena/memories/project_purpose_and_overview.md
