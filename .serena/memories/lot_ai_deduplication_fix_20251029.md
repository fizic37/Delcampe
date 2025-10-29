# Lot AI Deduplication Fix - COMPLETE

**Date:** October 29, 2025
**Status:** ✅ VERIFIED WORKING
**File Changed:** `R/app_server.R` (2 locations)

## Problem

Lot card AI deduplication did NOT work. When re-uploading the same lot images:
- AI extraction would run again (wasting API calls)  
- Form fields would not pre-populate
- No deduplication modal appeared

**Individual combined cards worked fine** - only lots were broken.

## Root Cause

**Lot images were NEVER tracked in the database!**

When lots are created (e.g., 2x2 grid), Python returns:
- `lot_paths`: Array of lot compilation images (lot_face.png, lot_verso.png)
- `combined_paths`: Array of individual card images (card1.png, card2.png, card3.png, card4.png)

The original code:
- ✅ Looped through `combined_paths` and stored each as `image_type = "combined"`
- ❌ Completely ignored `lot_paths` - they were NEVER stored in database!

Later, when exporting lots:
- Lot export module queries: `find_card_processing(hash, "lot")`
- Database has no records with `image_type = "lot"`
- Query returns NULL → No deduplication!

## Solution

Added NEW loop to track lot images with `image_type = "lot"`.

### Changes Made

**File:** `R/app_server.R`

**Location 1:** Lines ~453-505 (auto-combine path)  
**Location 2:** Lines ~782-834 (manual-combine path)

Added identical code block after combined images tracking:

```r
# Track lot images in database (if they exist)
tryCatch({
  lot_card_ids <- list()
  for (i in seq_along(abs_lot_paths)) {
    lot_path <- abs_lot_paths[i]

    # Calculate hash for lot image
    lot_hash <- calculate_image_hash(lot_path)

    if (!is.null(lot_hash)) {
      # Create card entry for lot image
      card_id <- get_or_create_card(
        file_hash = lot_hash,
        image_type = "lot",  # ← KEY: Use "lot" not "combined"
        original_filename = basename(lot_path),
        file_size = file.info(lot_path)$size
      )

      lot_card_ids[[i]] <- card_id

      # Save processing details for lot
      save_card_processing(
        card_id = card_id,
        crop_paths = NULL,
        h_boundaries = NULL,
        v_boundaries = NULL,
        grid_rows = as.integer(num_rows),
        grid_cols = as.integer(num_cols),
        extraction_dir = as.character(combined_output_dir),
        ai_data = NULL
      )

      # Track session activity
      track_session_activity(
        session_id = session$token,
        card_id = card_id,
        action = "lot_created",
        details = list(
          lot_index = i,
          lot_path = lot_path,
          grid = paste0(num_rows, "x", num_cols)
        )
      )
    }
  }

  # Store lot card IDs for AI extraction
  app_rv$lot_card_ids <- lot_card_ids

  message("✅ Lot images tracked in database: ", length(lot_card_ids), " lot images")
}, error = function(e) {
  message("⚠️ Failed to track lot images: ", e$message)
})
```

## How It Works Now

### When Creating Lots (2x2 grid)

**Before:**
```
✅ Combined images tracked: 4 cards (image_type='combined')
❌ Lot images: NOT tracked at all
```

**After:**
```
✅ Combined images tracked: 4 cards (image_type='combined')
✅ Lot images tracked: 2 lot images (image_type='lot')
```

### Database State

After uploading 2x2 grid, database now contains:

| card_id | file_hash | image_type | original_filename |
|---------|-----------|------------|-------------------|
| 101 | abc123... | combined | card1_face_verso.png |
| 102 | def456... | combined | card2_face_verso.png |
| 103 | ghi789... | combined | card3_face_verso.png |
| 104 | jkl012... | combined | card4_face_verso.png |
| 105 | mno345... | **lot** | lot_face.png |
| 106 | pqr678... | **lot** | lot_verso.png |

### When Re-uploading Same Lot

**Lot export module:**
1. Calculates hash of lot image
2. Queries: `find_card_processing(hash, "lot")`
3. ✅ Finds card_id 105 or 106
4. ✅ Retrieves existing AI data
5. ✅ Pre-populates form fields
6. ✅ Shows "Re-extract with AI" button
7. ✅ No redundant API call!

## Related Fixes

This fix complements commit 043d7bb which changed queries in `mod_delcampe_export.R` from hardcoded `"combined"` to using the `image_type` parameter.

**Commit 043d7bb ensured:**  
Queries use correct image_type parameter

**This fix ensures:**  
Lot images are actually STORED with correct image_type

**Both fixes were needed for full deduplication support!**

## Impact

✅ **Eliminates redundant API calls** for re-uploaded lots  
✅ **Instant form pre-population** for known lots  
✅ **Consistent UX** between individual and lot cards  
✅ **Cost savings** - Lot AI extraction can cost $0.05-0.15 per lot

## Testing

✅ Tested and confirmed working by user

## Files Modified

1. `R/app_server.R` - Added lot tracking at 2 locations (lines ~453-505 and ~782-834)

## Lines Added

~106 new lines total (~53 lines × 2 locations)

---

**Status:** DEPLOYED AND VERIFIED ✅  
**Tested:** YES - User confirmed working  
**Confidence:** HIGH - Root cause identified and fixed correctly
