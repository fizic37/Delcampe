# Quick Test: AI Field Pre-Population Fix

**Purpose:** Verify that duplicate combined images auto-populate AI extraction fields

**Time Required:** ~5 minutes

**Status:** ⏳ Awaiting User Testing

---

## Prerequisites

- App installed and working
- AI API key configured (Claude or GPT-4)
- Face and verso images ready for upload

---

## Test Procedure

### Part 1: Create AI Data (First Upload)

1. **Start app:**
   ```r
   devtools::load_all()
   run_app()
   ```

2. **Upload face image:**
   - Click "Upload Face Image"
   - Select test image
   - Wait for extraction to complete
   - Note the image for later reuse

3. **Upload verso image:**
   - Click "Upload Verso Image"
   - Select test image
   - Wait for extraction to complete
   - Note the image for later reuse

4. **Combine images:**
   - Click "Process Combined Images"
   - Wait for combined images to appear in right panel

5. **Extract AI data:**
   - Click first combined image to expand accordion
   - Click "Extract with AI"
   - Wait for extraction to complete (~5-10 seconds)
   - **VERIFY:** Fields populated (title, description, price, condition)
   - **OPTIONAL:** Change title to "TEST PREPOPULATED" for easy verification

6. **Close app** (important for testing reload)

### Part 2: Test Pre-Population (Duplicate Upload)

7. **Restart app:**
   ```r
   devtools::load_all()
   run_app()
   ```

8. **Upload SAME face image:**
   - Upload the exact same file from step 2
   - Modal should appear: "Duplicate Image Detected"
   - Click "Use Existing"
   - Crops should appear instantly

9. **Upload SAME verso image:**
   - Upload the exact same file from step 3
   - Modal should appear: "Duplicate Image Detected"
   - Click "Use Existing"
   - Crops should appear instantly

10. **Combine images again:**
    - Click "Process Combined Images"
    - Combined images appear in right panel

11. **🎯 CRITICAL TEST:**
    - Click first combined image to expand accordion
    - **Watch carefully:**
      - Fields should populate within 150-200ms
      - You may see a brief moment before fields fill
      - This is the intentional delay (150ms)

---

## Expected Results

### ✅ SUCCESS Indicators

1. **Title field populated:**
   - Shows "TEST PREPOPULATED" (if you changed it)
   - OR shows original AI-extracted title

2. **Description field populated:**
   - Shows the previously extracted description text

3. **Price field populated:**
   - Shows the AI-recommended price (e.g., 2.50)

4. **Condition field populated:**
   - Shows the selected condition (e.g., "Used")

5. **Green success banner:**
   - Appears above AI controls
   - Text: "Previous AI extraction loaded (Model: ...)"

6. **Console logs show:**
   ```
   === AI PRE-POPULATION OBSERVER TRIGGERED ===
   ✨ Found existing AI data for image 1
   💾 Draft saved with existing data
   🔄 Delayed update triggered for image 1
   ✓ Title populated
   ✓ Description populated
   ✓ Price populated
   ✓ Condition populated
   ✅ Field updates complete
   ```

### ❌ FAILURE Indicators

1. **Fields remain empty** despite console showing "✓ Title populated"
2. **No green success banner** appears
3. **Errors in R console** related to update functions
4. **Delay is too long** (>500ms) causing noticeable lag

---

## Troubleshooting

### Issue: Fields Still Empty

**Check console logs:**
```
# Should see:
✨ Found existing AI data for image 1
🔄 Delayed update triggered for image 1
✓ Title populated

# If you see errors instead:
❌ Error populating fields: <error message>
```

**Possible causes:**
1. Accordion not rendering - check if panel opens properly
2. Input IDs mismatch - check namespace issues
3. Database empty - verify data saved in Part 1

**Debug command:**
```r
library(DBI)
con <- dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
dbGetQuery(con, "SELECT * FROM card_processing WHERE image_type = 'combined' LIMIT 5")
dbDisconnect(con)
```

### Issue: Delay Too Long

If fields take >500ms to populate:
- System may be slow
- Consider reducing delay in code
- Current: 150ms (line 435 in mod_delcampe_export.R)

### Issue: Wrong Data Appears

**Verify hash calculation:**
```r
# Should use actual file path, not web URL
# Check console for:
"Using image_file_paths mapping"
"Actual path: C:/Users/.../Temp/..."
```

---

## Quick Verification Checklist

- [ ] Part 1 completed (AI data created)
- [ ] Part 2 completed (duplicate upload)
- [ ] Title field auto-populated
- [ ] Description field auto-populated
- [ ] Price field auto-populated
- [ ] Condition field auto-populated
- [ ] Green success banner appeared
- [ ] Console shows "✅ Field updates complete"
- [ ] No errors in R console
- [ ] Timing feels natural (~200ms)

---

## Report Results

**If all checks pass:**
- Comment on original issue/PRP: "✅ VERIFIED - Fields populate correctly"
- Ready for production use

**If any check fails:**
- Copy console log errors
- Note which specific check failed
- Report for further debugging

---

## Additional Tests (Optional)

### Test 3: Editability
- Modify pre-populated title
- Click "Extract with AI" again
- Verify new extraction updates fields

### Test 4: Multiple Combined Images
- Create 2+ combined images
- Test pre-population on each
- All should work independently

### Test 5: Different Sessions
- Close and reopen app multiple times
- Data should persist across sessions

---

## Performance Benchmark

**Acceptable Performance:**
- Database query: <10ms
- Hash calculation: <20ms
- Field population delay: 150ms (intentional)
- Total time: <200ms from accordion open to populated

**User Perception:**
- Should feel "instant" or "very fast"
- Delay should be imperceptible

---

## Success Criteria

✅ **Fix is working** if:
1. All fields populate automatically
2. Timing is acceptable (<300ms)
3. No errors in console
4. Data matches database records
5. User experience is smooth

❌ **Fix needs adjustment** if:
1. Fields remain empty
2. Delay is too long (>500ms)
3. Errors appear in console
4. Only some fields populate

---

**Created:** 2025-10-14
**Related:**
- Memory: `.serena/memories/ai_ui_population_timing_fix_20251014.md`
- PRP: `PRPs/fix_ai_extraction_ui_task.md`
- Code: `R/mod_delcampe_export.R` lines 390-459
