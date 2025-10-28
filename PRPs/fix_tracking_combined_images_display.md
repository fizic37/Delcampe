# PRP: Display Combined Images in Tracking Viewer

**Status:** Draft for Task Create
**Priority:** Medium
**Created:** 2025-10-22
**Type:** Bug Fix / Enhancement

---

## Problem Statement

The Settings > Tracking submenu (general tracking viewer) does not display combined images to users when they view their processing history. While the tracking database stores crop dimensions (`h_boundaries`, `v_boundaries`, `grid_rows`, `grid_cols`) and crop file paths, combined images are not persistently stored and therefore cannot be displayed.

### Current Behavior

When a user:
1. Processes images (face and verso uploads)
2. Extracts crops using AI
3. Views their processing history in Settings > Tracking
4. Clicks on a session to see details in the modal

**Result:** Only face and verso images are shown; combined images are missing from the modal display.

### Root Cause

- Combined images are created temporarily during processing but are NOT stored in the database
- The `postal_cards` table only stores face/verso image types
- The tracking viewer modal (`mod_tracking_viewer.R`) only displays images with stored paths
- However, crop dimensions and crop file paths ARE stored in the `card_processing` table

---

## Proposed Solution

Recreate combined images on-demand when displaying tracking history by:

1. **Read stored crop data** from the `card_processing` table
   - `crop_paths` (JSON array of crop file paths)
   - `h_boundaries` (JSON array)
   - `v_boundaries` (JSON array)
   - `grid_rows`, `grid_cols` (integers)

2. **Identify crop directories** from the stored `crop_paths`
   - Parse paths to determine face crop directory
   - Parse paths to determine verso crop directory

3. **Call Python function** to recreate combined images
   - Use existing `combine_face_verso_images()` function from `inst/python/extract_postcards.py`
   - Function signature: `combine_face_verso_images(face_dir, verso_dir, output_dir, num_rows, num_cols)`
   - Returns: `{"lot_paths": [...], "combined_paths": [...]}`

4. **Display recreated images** in the tracking viewer modal
   - Show individual combined images (face+verso pairs)
   - Optionally show lot images (full columns)

---

## Technical Details

### Existing Python Function

```python
def combine_face_verso_images(face_dir, verso_dir, output_dir, num_rows, num_cols):
    """
    Create both lot images (by columns) and individual combined images.

    Args:
        face_dir (str): Directory containing extracted face images
        verso_dir (str): Directory containing extracted verso images
        output_dir (str): Directory where combined images will be saved
        num_rows (int): Number of rows in the grid (used as fallback)
        num_cols (int): Number of columns in the grid (used as fallback)

    Returns:
        dict: {
            "lot_paths": list of file paths of lot images,
            "combined_paths": list of file paths of individual combined images
        }
    """
```

**Location:** `inst/python/extract_postcards.py:283-505`

### Database Schema

```sql
-- card_processing table (stores crop dimensions)
CREATE TABLE IF NOT EXISTS card_processing (
  processing_id INTEGER PRIMARY KEY AUTOINCREMENT,
  card_id INTEGER UNIQUE NOT NULL,
  crop_paths TEXT,          -- JSON array of crop file paths
  h_boundaries TEXT,        -- JSON array of horizontal boundaries
  v_boundaries TEXT,        -- JSON array of vertical boundaries
  grid_rows INTEGER,        -- Number of grid rows
  grid_cols INTEGER,        -- Number of grid columns
  extraction_dir TEXT,      -- Directory where crops were saved
  ...
)
```

### Current Tracking Viewer Implementation

**Files:**
- `R/mod_tracking_viewer.R` - UI and server for tracking viewer
- `R/tracking_database.R` - Database queries (`get_session_cards()`)

**Key Functions:**
- `get_session_cards(session_id)` - Retrieves all cards for a session
- `show_session_modal()` - Displays session details in modal (lines 218-368)

---

## Implementation Plan

### Step 1: Extend Database Query

Modify `get_session_cards()` in `R/tracking_database.R` to include:
- `h_boundaries` from `card_processing`
- `v_boundaries` from `card_processing`
- `extraction_dir` from `card_processing`

**Current query at:** `R/tracking_database.R:1580-1642`

### Step 2: Create Helper Function

Add new function in `R/mod_tracking_viewer.R`:

```r
recreate_combined_images <- function(card_id, crop_paths, h_boundaries, v_boundaries,
                                     grid_rows, grid_cols, extraction_dir) {
  # 1. Parse crop_paths JSON to get face and verso directories
  # 2. Create temporary output directory for combined images
  # 3. Call Python function via reticulate
  # 4. Return paths to recreated combined images
}
```

### Step 3: Modify Modal Display Logic

Update `show_session_modal()` function (lines 218-368) to:
1. Check if card has processing data (crop_paths, boundaries)
2. If yes, call `recreate_combined_images()` to generate combined images
3. Add combined images section to modal display
4. Show both individual combined images and lot images (optional)

### Step 4: Handle Temporary Files

Implement cleanup strategy:
- Store recreated combined images in `data/temp/combined/` directory
- Clean up old temp files on app startup or periodically
- OR: Store recreated images in user-specific session temp directory

---

## Acceptance Criteria

### Must Have

✅ When user opens tracking viewer modal for a session with processed cards:
  - Combined images are visible in the modal
  - Images are recreated from stored crop dimensions
  - Images display correctly (face+verso side by side)

✅ Performance:
  - Combined image recreation happens within 3 seconds
  - Modal displays loading indicator while images are being recreated

✅ Error Handling:
  - If crop files are missing, show appropriate error message
  - If Python function fails, display fallback message
  - Don't break existing face/verso image display

### Should Have

✅ Display both:
  - Individual combined images (each card pair)
  - Lot images (full columns) - optional toggle

✅ Cache recreated images:
  - Avoid recreating same images multiple times in same session
  - Use reactive values or temp storage

### Nice to Have

- Preview/expand combined images (already exists with simple image enlargement)
- Download button for combined images
- Batch recreation of all combined images for a session

---

## Files to Modify

### Core Changes

1. **`R/tracking_database.R`**
   - Modify `get_session_cards()` to include crop processing data
   - Add helper function to extract crop directories from paths

2. **`R/mod_tracking_viewer.R`**
   - Add `recreate_combined_images()` helper function
   - Modify `show_session_modal()` to display combined images
   - Add loading indicator for image recreation

### Optional/Supporting Changes

3. **`R/utils_python.R`** (if doesn't exist, create it)
   - Wrapper functions for Python integration
   - Error handling for Python function calls

4. **`inst/app/data/temp/`**
   - Create directory structure for temporary combined images

---

## Testing Requirements

### Unit Tests

- Test `recreate_combined_images()` with valid crop data
- Test error handling when crop files are missing
- Test JSON parsing of crop_paths, boundaries

### Integration Tests

- Test full workflow: view tracking → click session → see combined images
- Test with different grid configurations (2x3, 3x2, etc.)
- Test with sessions that have only face or only verso images
- Test with sessions that have missing crop files

### User Acceptance Testing

- Process new images end-to-end
- View processing history
- Verify combined images appear correctly
- Test on multiple sessions

---

## Dependencies

### Existing Components

- ✅ Python function `combine_face_verso_images()` exists
- ✅ Database stores all necessary crop data
- ✅ Tracking viewer modal infrastructure exists
- ✅ Reticulate integration for R-Python communication

### New Requirements

- Temporary directory for storing recreated combined images
- Loading indicator component (can use existing Shiny progress indicators)

---

## Risk Assessment

### Low Risk

- Python function already exists and is tested
- Database already stores all necessary data
- No schema changes required

### Medium Risk

- Performance: Recreating images on-demand may be slow for large grids
  - **Mitigation:** Add caching, loading indicators

- File system: Temporary files need cleanup
  - **Mitigation:** Implement cleanup strategy on app startup

### Dependencies

- Reticulate must be properly configured
- Python environment must be available
- OpenCV must be installed in Python environment

---

## Success Metrics

1. **Functional:** Users can view combined images in tracking history (100% of time)
2. **Performance:** Combined images load within 3 seconds
3. **Reliability:** No errors in tracking viewer due to missing images (<1% failure rate)
4. **User Satisfaction:** Users can review their complete processing history including combined images

---

## Future Enhancements

1. **Persistent Combined Image Storage**
   - Store combined images permanently in database
   - Pros: Faster display, no recreation needed
   - Cons: Increased storage requirements

2. **Batch Recreation**
   - Recreate all combined images for a session at once
   - Background job processing

3. **Preview in Data Table**
   - Show thumbnail of combined image in main tracking table
   - Not just in modal

4. **Export Combined Images**
   - Allow users to download all combined images for a session
   - Batch export functionality

---

## Notes

- This functionality already exists in the main workflow when images are initially processed
- We're reusing the same Python function that creates combined images during processing
- The tracking viewer is accessed via Settings > Tracking (first tab in admin UI)
- Modal display logic is in `mod_tracking_viewer.R:218-368`

---

## References

- Python function: `inst/python/extract_postcards.py:283-505`
- Tracking viewer: `R/mod_tracking_viewer.R`
- Database functions: `R/tracking_database.R`
- Settings UI: `R/mod_settings_ui.R:25-30`
