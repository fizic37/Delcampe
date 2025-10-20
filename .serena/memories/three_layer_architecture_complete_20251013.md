# 3-Layer Architecture - IMPLEMENTATION COMPLETE

**Date:** October 13, 2025  
**Status:** ✅ **FULLY IMPLEMENTED**

## Architecture Overview

Replaced single-table approach with proper 3-layer architecture:

### Layer 1: `postal_cards` (Master Table)
- **Purpose:** One entry per unique physical image
- **Key:** file_hash (UNIQUE constraint)
- **Contains:** hash, filename, type, dimensions, upload count
- **Behavior:** Created once, updated count on re-upload

### Layer 2: `card_processing` (Processing Results)
- **Purpose:** Store crops, boundaries, AI data
- **Key:** card_id (UNIQUE - one row per card)
- **Behavior:** UPSERT pattern - updates on reprocess
- **Contains:** 
  - crop_paths (JSON array)
  - h_boundaries, v_boundaries (JSON arrays)
  - grid_rows, grid_cols
  - extraction_dir
  - ai_title, ai_description, ai_condition, ai_price, ai_model

### Layer 3: `session_activity` (Activity Log)
- **Purpose:** Track what happened when
- **Links:** session_id → card_id
- **Actions:** uploaded, processed, reused
- **Contains:** timestamp, details (JSON)

## Implementation Details

### New Functions (tracking_database.R)

**`get_or_create_card(file_hash, image_type, ...)`**
- Checks if card exists by hash + type
- If exists: Updates times_uploaded, returns existing card_id
- If new: Inserts new card, returns new card_id
- **Result:** No duplicate cards, just increment counter

**`save_card_processing(card_id, crop_paths, boundaries, ...)`**
- Checks if processing exists for card_id
- If exists: **UPDATE** (overwrites old crops/boundaries)
- If new: INSERT
- **Result:** Always one processing row per card

**`find_card_processing(file_hash, image_type)`**
- Joins postal_cards + card_processing
- Returns NULL if not processed yet
- Returns full card + processing data if processed
- **Result:** Finds previously processed cards

**`track_session_activity(session_id, card_id, action, details)`**
- Logs every action in session_activity table
- Actions: 'uploaded', 'processed', 'reused'
- **Result:** Complete audit trail

### Integration Changes (mod_postal_card_processor.R)

**1. Upload Tracking (~line 217)**
```r
# OLD: INSERT into images table every time
# NEW: Get or create card
card_id <- get_or_create_card(...)
rv$current_card_id <- card_id
track_session_activity(..., action = "uploaded")
```

**2. Duplicate Check (~line 426)**
```r
# OLD: find_existing_processing(hash, type)
# NEW: find_card_processing(hash, type)
existing <- find_card_processing(rv$current_image_hash, card_type)
```

**3. Field Names in Modal (~line 442)**
```r
# OLD: existing$processed_at, existing$cropped_paths
# NEW: existing$last_processed, existing$crop_paths
```

**4. Extraction Tracking (~line 809)**
```r
# OLD: INSERT into processing_log with JSON
# NEW: UPSERT into card_processing
save_card_processing(
  card_id = rv$current_card_id,
  crop_paths = abs_paths,
  h_boundaries = rv$h_boundaries,
  v_boundaries = rv$v_boundaries,
  grid_rows = rv$current_grid_rows,
  grid_cols = rv$current_grid_cols,
  extraction_dir = py_out_dir,
  ai_data = NULL
)
track_session_activity(..., action = "processed")
```

**5. "Use Existing" Handler (~line 530)**
```r
# OLD: existing$cropped_paths, existing$grid_config$rows
# NEW: existing$crop_paths, existing$grid_rows
copy_result <- copy_existing_crops(existing$crop_paths, ...)
rv$current_grid_rows <- existing$grid_rows
rv$current_grid_cols <- existing$grid_cols

# OLD: mark_processing_reused(..., image_id, source_image_id)
# NEW: track_session_activity(..., action = "reused")
```

## Benefits

✅ **True Deduplication**
- Same image hash = same card_id forever
- No duplicate entries for same physical image

✅ **Persistent Processing**
- Crops saved permanently with card
- Can reuse even after app restart

✅ **UPSERT Pattern**
- Reprocess → updates existing row
- No accumulation of old processing data

✅ **Session Tracking**
- Full audit trail of who did what when
- Can analyze user behavior

✅ **AI Ready**
- ai_title, ai_description, ai_condition, ai_price fields ready
- Just pass ai_data to save_card_processing()

✅ **Scalable**
- Works for single user (current)
- Ready for multi-user (future)

## Testing Checklist

### First Upload
```
✅ Card ID: 1
Card tracked: card_id = 1
```

### Process
```
Processing saved for card_id: 1
📂 Saved 3 crop paths
```

### Re-upload Same Image
```
Existing card found: card_id = 1  ← SAME ID!
🔍 Checking for duplicates
📋 Duplicate check result: FOUND
✅ Duplicate with valid crops found - showing modal
```

### Database Check
```r
source("debug_database.R")
```

**Expected Results:**
- `postal_cards`: 1 entry per unique hash, times_uploaded = 2
- `card_processing`: 1 entry per card (UPSERTed if reprocessed)
- `session_activity`: Multiple entries (uploaded, processed, reused)
- `images`: Still has old entries (legacy, ignore)

## Console Output

### Upload Same Image Twice

**First time:**
```
🔐 Image hash calculated: abc123...
✅ Card ID: 1
Card tracked: card_id = 1
🔍 Checking for duplicates
📋 Duplicate check result: NONE
```

**Second time:**
```
🔐 Image hash calculated: abc123...
Existing card found: card_id = 1
✅ Card ID: 1
🔍 Checking for duplicates
📋 Duplicate check result: FOUND
✅ Duplicate with valid crops found - showing modal
```

**→ Modal appears!** 🎉

### Reprocess Same Image

User clicks "Process Anyway", adjusts boundaries, extracts:
```
Processing saved for card_id: 1  ← SAME card_id
📂 Saved 3 crop paths
```

**Database:** `card_processing` row for card_id=1 is **UPDATED**, not duplicated

## Migration Note

Old `images` and `processing_log` tables still exist for backward compatibility. New code uses new tables. Both can coexist.

To clean up old data (optional):
```sql
DELETE FROM images;
DELETE FROM processing_log;
VACUUM;
```

## Status

**Implementation:** COMPLETE ✅  
**Testing:** READY FOR USER ✅  
**Expected:** Deduplication should work perfectly now! 🚀