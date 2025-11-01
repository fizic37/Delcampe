# PRP: Fix AI Extraction Deduplication for Lot Cards

**Status**: Ready for Implementation
**Priority**: High
**Created**: 2025-10-29
**Estimated Effort**: 2-3 hours

---

## Problem Statement

### Current Behavior
AI extraction deduplication works correctly for individual combined cards but **fails for lot cards**. When a lot card has already been processed with AI extraction, the system re-runs the AI extraction instead of reusing the existing data.

### Root Cause Analysis

The issue occurs due to a **mismatch between how lot images are stored vs. how they're queried**:

1. **Storage Phase** (`app_server.R` lines 685-690):
   - Both individual combined images AND lot images are created in the database with `image_type = "combined"`
   - No distinction is made between these two different image types

2. **Export Module Initialization** (`app_server.R` lines 777-780):
   - Lot export module is correctly configured with `image_type = "lot"`
   - Combined export module uses default `image_type = "combined"`

3. **Deduplication Query** (`mod_delcampe_export.R` line 515):
   - When checking for existing AI data, the system calls: `find_card_processing(image_hash, image_type)`
   - For lots: searches with `image_type = "lot"`
   - For combined: searches with `image_type = "combined"`

4. **Database Query** (`tracking_database.R` lines 580-615):
   - `find_card_processing()` queries: `WHERE c.file_hash = ? AND c.image_type = ?`
   - For lot images stored as "combined" but queried as "lot": **NO MATCH FOUND**
   - Result: System thinks it's a new image and re-runs AI extraction

### Evidence in Code

**Bug Location 1**: `app_server.R` lines 685-690 (auto-combine path)
```r
card_id <- get_or_create_card(
  file_hash = combined_hash,
  image_type = "combined",  # ← BUG: Should be "lot" for lot images!
  original_filename = basename(combined_path),
  file_size = file.info(combined_path)$size
)
```

**Bug Location 2**: `app_server.R` line 411 (manual combine path)
```r
card_id <- get_or_create_card(
  file_hash = combined_hash,
  image_type = "combined",  # ← BUG: Same issue in manual path!
  original_filename = basename(combined_path),
  file_size = file.info(combined_path)$size
)
```

**Correct Usage**: `app_server.R` line 780
```r
mod_delcampe_export_server(
  "lot_export",
  image_paths = reactive(app_rv$lot_paths),
  image_type = "lot",  # ✅ Correctly specified
```

---

## Success Criteria

- [ ] Lot images are stored in database with `image_type = "lot"`
- [ ] Individual combined images are stored with `image_type = "combined"`
- [ ] Deduplication works for lots: AI data is reused when re-uploading same lot image
- [ ] Deduplication still works for combined cards (no regression)
- [ ] Database migration handles existing "combined" records appropriately
- [ ] Console logging clearly shows when AI data is reused vs. extracted fresh

---

## Technical Requirements

### 1. Distinguish Lot vs Combined During Image Creation

**Problem**: When creating combined images, we need to know whether they're individual pairs or lot compilations.

**Solution**: Use the presence of lot images to determine type.

**Required Changes**:

#### File: `R/app_server.R`

**Location 1: Auto-combine path (lines 402-430)**

```r
# Current code (lines 673-717):
# Track combined images in database
tryCatch({
  # For each combined image, create a card entry
  combined_card_ids <- list()
  for (i in seq_along(abs_combined_paths)) {
    combined_path <- abs_combined_paths[i]

    # Calculate hash for combined image
    combined_hash <- calculate_image_hash(combined_path)

    if (!is.null(combined_hash)) {
      # Create card entry for combined image
      card_id <- get_or_create_card(
        file_hash = combined_hash,
        image_type = "combined",  # ← BUG HERE
        original_filename = basename(combined_path),
        file_size = file.info(combined_path)$size
      )

      # ... rest of code
    }
  }
  # ...
```

**CHANGE TO**:

```r
# Track combined images in database
tryCatch({
  # For each combined image, create a card entry
  combined_card_ids <- list()

  # Determine if we're creating lot images or individual combined images
  # Lot images exist when Python creates lot_paths in addition to combined_paths
  has_lot_images <- !is.null(py_results$lot_paths) && length(py_results$lot_paths) > 0

  for (i in seq_along(abs_combined_paths)) {
    combined_path <- abs_combined_paths[i]

    # Calculate hash for combined image
    combined_hash <- calculate_image_hash(combined_path)

    if (!is.null(combined_hash)) {
      # Create card entry for combined image
      # Use "lot" type if this is a lot compilation, otherwise "combined"
      card_id <- get_or_create_card(
        file_hash = combined_hash,
        image_type = if (has_lot_images) "lot" else "combined",  # ✅ FIXED
        original_filename = basename(combined_path),
        file_size = file.info(combined_path)$size
      )

      # ... rest of code stays the same
    }
  }
  # ...
```

**Repeat same fix for manual combine path** (around line 411):

```r
# Determine if we're creating lot images
has_lot_images <- !is.null(py_results$lot_paths) && length(py_results$lot_paths) > 0

for (i in seq_along(abs_combined_paths)) {
  combined_path <- abs_combined_paths[i]
  combined_hash <- calculate_image_hash(combined_path)

  if (!is.null(combined_hash)) {
    card_id <- get_or_create_card(
      file_hash = combined_hash,
      image_type = if (has_lot_images) "lot" else "combined",  # ✅ FIXED
      original_filename = basename(combined_path),
      file_size = file.info(combined_path)$size
    )
    # ... rest stays same
  }
}
```

### 2. Verify Deduplication Logic

**No changes needed** - deduplication logic is already correct in:
- `mod_ai_extraction.R` line 43: `find_card_processing(current_hash, "combined")`
- `mod_delcampe_export.R` line 515: `find_card_processing(image_hash, image_type)`

The module correctly passes the `image_type` parameter received from the server.

### 3. Database Schema

**No changes needed** - `postal_cards.image_type` is already a TEXT column that accepts any value.

Existing records with `image_type = "combined"` will remain unchanged and continue to work for individual combined cards.

### 4. Enhanced Logging for Debugging

**Location**: `mod_delcampe_export.R` line 514

```r
# Current code:
cat("      Querying database for existing AI data (image_type='", image_type, "')...\n", sep = "")
existing <- find_card_processing(image_hash, image_type)
```

**CHANGE TO** (add more diagnostic info):

```r
cat("      Querying database for existing AI data (image_type='", image_type, "')...\n", sep = "")
cat("      Hash (first 12 chars):", substr(image_hash, 1, 12), "...\n")
existing <- find_card_processing(image_hash, image_type)

if (!is.null(existing)) {
  cat("      ✅ DEDUPLICATION SUCCESS - Reusing AI data from card_id:", existing$card_id, "\n")
  cat("         - Last processed:", existing$last_processed, "\n")
  cat("         - AI model used:", existing$ai_model %||% "Unknown", "\n")
} else {
  cat("      ℹ️  No existing AI data found - will extract fresh\n")
}
```

---

## Implementation Steps

### Phase 1: Core Fix (1 hour)

1. **Identify lot vs combined logic**:
   - Add `has_lot_images` flag based on `py_results$lot_paths` existence
   - Use ternary operator: `if (has_lot_images) "lot" else "combined"`

2. **Apply fix in two locations**:
   - Auto-combine path (lines 673-717 in `app_server.R`)
   - Manual combine path (lines 402-430 in `app_server.R`)

3. **Verify no syntax errors**:
   - Run `source("R/app_server.R")` to check for parsing errors

### Phase 2: Testing (1 hour)

1. **Test individual combined cards (regression test)**:
   - Upload face + verso images
   - Auto-combine or manually combine
   - Extract AI data for one card
   - Re-upload same images
   - Verify: AI data is reused (console shows "DEDUPLICATION SUCCESS")

2. **Test lot cards (primary fix)**:
   - Upload face + verso images with 2x2 grid
   - Auto-combine or manually combine (creates lot images)
   - Extract AI data for one lot
   - Re-upload same images with same grid
   - Verify: AI data is reused (console shows "DEDUPLICATION SUCCESS")

3. **Test mixed scenario**:
   - Upload same images, extract AI for both individual AND lot
   - Verify: Both maintain separate AI data (different image_types)

### Phase 3: Enhanced Logging (30 minutes)

1. **Add diagnostic logging to `mod_delcampe_export.R`**:
   - Log hash prefix for verification
   - Log deduplication success/failure clearly
   - Log card_id and last_processed timestamp when found

2. **Test logging**:
   - Verify console output is clear and helpful
   - Ensure emojis render correctly in Windows console

---

## Testing Checklist

### Deduplication for Individual Combined Cards (Regression)
- [ ] Upload face/verso, combine, extract AI for combined card
- [ ] Re-upload same images, auto-combine
- [ ] Console shows: "Querying database for existing AI data (image_type='combined')"
- [ ] Console shows: "✅ DEDUPLICATION SUCCESS - Reusing AI data"
- [ ] UI pre-populates title/description/price/condition
- [ ] Button shows "Re-extract with AI" (not "Extract with AI")

### Deduplication for Lot Cards (Primary Fix)
- [ ] Upload face/verso with multi-card grid (e.g., 2x2)
- [ ] Auto-combine or manual combine (creates lot images)
- [ ] Extract AI for one lot card
- [ ] Re-upload same images with same grid
- [ ] Console shows: "Querying database for existing AI data (image_type='lot')"
- [ ] Console shows: "✅ DEDUPLICATION SUCCESS - Reusing AI data"
- [ ] Lot export UI pre-populates AI data
- [ ] Button shows "Re-extract with AI"

### Database Integrity
- [ ] Check database: `SELECT DISTINCT image_type FROM postal_cards;`
- [ ] Should show: "face", "verso", "combined", "lot"
- [ ] Old "combined" records (individual cards) still work correctly

### Edge Cases
- [ ] Upload same images: extract for BOTH individual combined AND lot
- [ ] Verify: Both maintain separate AI data (different card_ids)
- [ ] Verify: Re-uploading reuses correct AI data based on context (lot vs individual)

---

## Files to Modify

1. **R/app_server.R**
   - Line ~411: Fix `image_type` for manual combine path
   - Line ~687: Fix `image_type` for auto-combine path
   - Add `has_lot_images` flag detection in both locations

2. **R/mod_delcampe_export.R** (optional enhancement)
   - Line ~514: Add enhanced diagnostic logging
   - Show hash prefix, deduplication result, card_id, timestamp

---

## Success Metrics

- ✅ Zero false negatives: Existing lot AI data is always found
- ✅ Zero false positives: Individual combined cards don't match lot cards
- ✅ Clear logging: User can see when AI data is reused vs. extracted fresh
- ✅ Performance: No redundant AI API calls for duplicate lot images
- ✅ Database integrity: Proper separation between "lot" and "combined" types

---

## Risk Assessment

**Low Risk**:
- Change is minimal: only affects `image_type` value assignment
- No database schema changes required
- Existing "combined" records continue to work (backward compatible)
- Deduplication logic already handles arbitrary `image_type` values
- Easy to test: upload same images twice and check console

**Testing Priority**: High - Must verify both lot and individual combined deduplication

---

## Context & Background

### How Deduplication Works

1. **Hash Calculation**: When image is uploaded/created, calculate SHA-256 hash
2. **Database Lookup**: Query `postal_cards` table with `file_hash + image_type`
3. **Match Found**: If `card_processing` has AI data for that card_id, reuse it
4. **No Match**: Extract fresh AI data, save to database

### Why image_type Matters

The database query uses **both** `file_hash` AND `image_type`:

```sql
SELECT * FROM postal_cards c
LEFT JOIN card_processing p ON c.card_id = p.card_id
WHERE c.file_hash = ? AND c.image_type = ?
```

This means:
- Same image hash with `image_type = "combined"` → One card_id
- Same image hash with `image_type = "lot"` → Different card_id

This is **intentional design** because:
- Individual combined card (face+verso pair) has different AI extraction than lot compilation
- Lot compilation might describe "Set of 4 postcards" while individual describes specific postcard
- User might want different titles/prices for individual vs. lot sales

### Python Image Generation

The Python function `combine_face_verso_images()` in `inst/python/extract_postcards.py` returns:
- `combined_paths`: List of individual face+verso pairs
- `lot_paths`: List of vertical stack compilations (for lot sales)

**Current behavior**:
- If grid is 1x1: Only `combined_paths` (one pair)
- If grid is NxM: Both `combined_paths` (N*M pairs) AND `lot_paths` (M columns)

The presence of `lot_paths` indicates we're creating lot images, not just individual pairs.

---

## Future Enhancements (Not in Scope)

- Add database migration to identify and re-classify existing lot images
- Add UI indicator showing "AI data reused" timestamp
- Track AI extraction cost savings from deduplication
- Add admin page showing deduplication statistics

---

## Related Files & Documentation

### Memories to Read Before Starting
- `.serena/memories/DEDUPLICATION_FINAL_STATUS_20251013.md` - Deduplication implementation details
- `.serena/memories/ai_extraction_complete_20251009.md` - AI extraction feature documentation
- `.serena/memories/tech_stack_and_architecture.md` - Architecture constraints

### Key Functions
- `get_or_create_card()` - Creates/retrieves card from database
- `find_card_processing()` - Checks for existing AI data
- `save_card_processing()` - Saves AI extraction results
- `calculate_image_hash()` - Generates SHA-256 hash for deduplication

### Database Tables
- `postal_cards` - Master table (hash, image_type, metadata)
- `card_processing` - UPSERT table (AI data, crops, grid info)
- `session_activity` - Audit trail

---

**Remember**: This is a simple fix - just changing `"combined"` to conditionally use `"lot"` when appropriate. The hard part was diagnosing the issue! 🎯
