# Testing Guide: Conditional AI Prompts

**Date**: 2025-11-01
**Feature**: Conditional AI prompt selection based on "Fetch AI description" checkbox

---

## What Was Implemented

The "Fetch AI description" checkbox now controls **what the AI extracts**, not just what gets displayed:

- **Checkbox UNCHECKED**: Minimal prompt (title + price only) - saves ~60% tokens
- **Checkbox CHECKED**: Full prompt (title + description + metadata)

---

## Database Cleanup Scripts

Before testing, you may want to delete existing records to ensure deduplication doesn't interfere:

### Delete ALL Stamp Records
```r
source("dev/cleanup_all_stamps.R")
# Type 'YES' when prompted to confirm
```

### Delete ALL Postal Card Records
```r
source("dev/cleanup_all_postal_cards.R")
# Type 'YES' when prompted to confirm
```

### Delete Specific Stamp IDs
```r
source("dev/cleanup_stamps_by_id.R")
# Deletes only stamp IDs 1, 2, 3
```

---

## Testing Workflow

### 1. Prepare Test Environment

**Option A**: Clean slate (recommended for first test)
```r
# Delete all stamp records
source("dev/cleanup_all_stamps.R")  # Type YES to confirm

# OR delete all postal card records
source("dev/cleanup_all_postal_cards.R")  # Type YES to confirm
```

**Option B**: Keep existing data (test deduplication behavior)

---

### 2. Test Stamps - Minimal Prompt (Checkbox UNCHECKED)

1. **Start the app**: `golem::run_dev()`
2. **Navigate to**: Stamps tab
3. **Upload a stamp image** (face or combined)
4. **UNCHECK** the "Fetch AI description" checkbox
5. **Click** "Extract with AI"

**Expected Console Output**:
```
🎯 Extract AI button clicked for image 1
   Fetch AI description: FALSE
   Using MINIMAL prompt (title/price/grade only - saves tokens)
   Prompt built, calling API...
```

**Expected UI Result**:
- ✅ Title field populated
- ✅ Price field populated
- ✅ Grade/Condition field populated
- ✅ Description field = Title + Standard Template
- ❌ Country, Year, Denomination, etc. fields EMPTY or NA

**Expected Behavior**:
- Faster response (~2-3 seconds vs ~5-7 seconds)
- Console shows "Using MINIMAL prompt"
- Template description used (not AI-generated)

---

### 3. Test Stamps - Full Prompt (Checkbox CHECKED)

1. **Upload another stamp image** (or use same one)
2. **CHECK** the "Fetch AI description" checkbox
3. **Click** "Extract with AI"

**Expected Console Output**:
```
🎯 Extract AI button clicked for image 2
   Fetch AI description: TRUE
   Using FULL prompt (description requested)
   Prompt built, calling API...
```

**Expected UI Result**:
- ✅ Title field populated
- ✅ Price field populated
- ✅ Grade/Condition field populated
- ✅ Description field = AI-GENERATED description
- ✅ Country, Year, Denomination, Scott Number, etc. fields POPULATED

**Expected Behavior**:
- Normal response time (~5-7 seconds)
- Console shows "Using FULL prompt"
- AI-generated description used
- All metadata fields populated

---

### 4. Test Postal Cards - Minimal Prompt (Checkbox UNCHECKED)

1. **Navigate to**: Delcampe Export tab
2. **Upload a postal card image** (face, verso, combined, or lot)
3. **UNCHECK** the "Fetch AI description" checkbox
4. **Click** "Extract with AI"

**Expected Console Output**:
```
🎯 Extract AI button clicked for image 1
   Fetch AI description: FALSE
   Using MINIMAL prompt (title/price only - saves tokens)
   Prompt built, calling API...
```

**Expected UI Result**:
- ✅ Title field populated
- ✅ Price field populated
- ✅ Description field = Title + Standard Template
- ❌ Year, Era, City, Country, Region, Theme Keywords fields EMPTY or NA

---

### 5. Test Postal Cards - Full Prompt (Checkbox CHECKED)

1. **Upload another postal card** (or use same one)
2. **CHECK** the "Fetch AI description" checkbox
3. **Click** "Extract with AI"

**Expected Console Output**:
```
🎯 Extract AI button clicked for image 2
   Fetch AI description: TRUE
   Using FULL prompt (description requested)
   Prompt built, calling API...
```

**Expected UI Result**:
- ✅ Title field populated
- ✅ Price field populated
- ✅ Description field = AI-GENERATED description
- ✅ Year, Era, City, Country, Region, Theme Keywords fields POPULATED (when visible in image)

---

## Verification Checklist

### Stamps
- [ ] Minimal prompt: Console shows "Using MINIMAL prompt"
- [ ] Minimal prompt: Title, price, grade populated
- [ ] Minimal prompt: Description = template (not AI)
- [ ] Minimal prompt: Metadata fields empty/NA
- [ ] Minimal prompt: Noticeably faster response
- [ ] Full prompt: Console shows "Using FULL prompt"
- [ ] Full prompt: All fields populated including AI description
- [ ] Full prompt: Metadata fields populated
- [ ] Full prompt: Normal response time
- [ ] Save to database works for both cases
- [ ] Reload image: Deduplication works

### Postal Cards
- [ ] Minimal prompt: Console shows "Using MINIMAL prompt"
- [ ] Minimal prompt: Title, price populated
- [ ] Minimal prompt: Description = template (not AI)
- [ ] Minimal prompt: Metadata fields empty/NA
- [ ] Minimal prompt: Noticeably faster response
- [ ] Full prompt: Console shows "Using FULL prompt"
- [ ] Full prompt: All fields populated including AI description
- [ ] Full prompt: Metadata fields populated
- [ ] Full prompt: Normal response time
- [ ] Save to database works for both cases
- [ ] Reload image: Deduplication works

---

## What to Look For

### ✅ Success Indicators

1. **Console Logging**: Clear indication of which prompt is being used
2. **Speed Difference**: Minimal prompt noticeably faster
3. **UI Behavior**: Description field shows template vs AI content correctly
4. **No Errors**: No console errors or warnings
5. **Database**: Both minimal and full extractions save successfully
6. **Deduplication**: Reloading same image populates from database

### ❌ Potential Issues

1. **Console doesn't show prompt type**: Check if fetch_description variable is being read correctly
2. **Both prompts same speed**: AI might be getting full prompt regardless of checkbox
3. **Template description not showing**: Check build_template_description() function
4. **Metadata fields populated with minimal prompt**: Parser might not be handling missing fields correctly
5. **Database save fails with minimal data**: Schema might not allow NULL for optional fields

---

## Token Savings Verification

You can verify token savings by checking the prompt length in console:

**Postal Cards**:
- Full prompt: ~2682 characters
- Minimal prompt: ~1091 characters
- **Expected reduction**: ~59%

**Stamps**:
- Full prompt: ~10 fields requested
- Minimal prompt: ~3 fields requested
- **Expected reduction**: ~70%

---

## Troubleshooting

### Issue: Console doesn't show which prompt is being used

**Check**: Lines in console around "Extract AI button clicked"

**Fix**: Verify the fetch_description variable is being read:
```r
fetch_description <- input[[paste0("fetch_ai_description_", i)]] %||% FALSE
cat("   Fetch AI description:", fetch_description, "\n")
```

### Issue: Description is empty instead of template

**Check**: build_template_description() function exists and works

**Fix**: Look in R/utils_helpers.R or search for the function

### Issue: Metadata fields show NA even with full prompt

**Check**: AI might not have detected those fields in the image

**Expected**: Some metadata fields may be NA if not visible in image (this is normal)

---

## Files Modified (Reference)

- `R/ai_api_helpers.R` - Added `build_postal_card_prompt_minimal()`
- `R/mod_delcampe_export.R` - Added conditional prompt selection
- `R/mod_stamp_export.R` - Added console logging

---

## Documentation

- **PRP**: PRPs/PRP_CONDITIONAL_AI_PROMPTS_DESCRIPTION_CHECKBOX.md
- **Memory**: .serena/memories/conditional_ai_prompts_implementation_20251101.md
- **This Guide**: dev/TESTING_CONDITIONAL_PROMPTS.md

---

## Next Steps After Testing

If everything works:
1. Test with real postal cards and stamps
2. Verify token usage in Claude/OpenAI dashboards
3. Confirm cost savings
4. Update user documentation

If issues found:
1. Check console for error messages
2. Review parser logic for missing field handling
3. Verify checkbox state is being read correctly
4. Check database schema allows NULL for optional fields
