# Postal Card Grid Complete Fix - November 4, 2025

## Problems Solved

### Problem 1: False Grid Detection
Python grid detection was finding 4 rows instead of 3 for postal card images, incorrectly detecting white margins at image edges as separate rows.

### Problem 2: Image Display Cutoff
Images were cut off at the top, showing only 2 of 3 postal cards due to incorrect absolute positioning with transform translate.

### Problem 3: Grid Line Positioning Mismatch
Grid lines were positioned correctly visually but extraction used wrong coordinates because R set percentage-based positioning that conflicted with flexbox centering.

### Problem 4: Grid Lines Not Draggable
After flexbox implementation, grid lines became non-interactive due to `pointer-events:none` on wrapper div.

### Problem 5: Crop Thumbnails Not Updating
After adjusting grid lines and re-extracting, the crop thumbnails showed cached images instead of the new crops.

---

## Solutions Implemented

### Solution 1: Boundary Filtering (PHASE 1)

**Implementation:** Added filtering logic after Python grid detection in all 3 processor modules.

**Files Modified:**
- `R/mod_postal_card_processor.R` (lines 318-400)
- `R/mod_stamp_face_processor.R` (lines 345-427)
- `R/mod_stamp_verso_processor.R` (lines 345-427)

**Logic:**
```r
MIN_ROW_HEIGHT_PX <- 300      # Minimum 300px for valid row
MIN_ROW_HEIGHT_PERCENT <- 0.10  # Minimum 10% of image height

# Filter boundaries creating rows smaller than EITHER threshold
# Keep boundary if: row_height >= 300px OR row_height >= 10% of image
```

**Test Results:**
- Before: Image 1882x3507 detected as 4 rows (0, 224, 1081, 2258, 3507)
- After: Detected as 3 rows (0, 1081, 2258, 3507)
- Filtered: 224px boundary (only 6.4% of image height)

---

### Solution 2: Flexbox Centering (PHASE 3)

**Problem Detail:** Image used `position:absolute; top:50%; left:50%; transform:translate(-50%, -50%)` which caused offset issues (69.8px from top).

**Implementation:** Replaced absolute positioning with flexbox centering.

**Files Modified:**
- `R/mod_postal_card_processor.R` (lines 880-911)
- `R/mod_stamp_face_processor.R` (lines 898-912)
- `R/mod_stamp_verso_processor.R` (lines 898-912)

**Structure Change:**
```r
# BEFORE:
tags$div(
  style = "position:relative; overflow:visible;",
  tags$img(style = "position:absolute; top:50%; left:50%; transform:translate(-50%, -50%); ..."),
  h_lines, v_lines
)

# AFTER:
tags$div(
  style = "position:relative; display:flex; align-items:center; justify-content:center; overflow:hidden;",
  tags$div(
    style = "position:relative; max-width:100%; max-height:100%;",
    tags$img(style = "display:block; max-width:100%; max-height:500px; ..."),
    h_lines, v_lines  # Direct children, not in wrapper
  )
)
```

**Key Changes:**
- Outer div: Added `display:flex; align-items:center; justify-content:center`
- Image: Removed `position:absolute` and `transform`, using natural flexbox positioning
- Overflow: Changed from `visible` to `hidden` to prevent scroll bars
- Image: Simplified to `display:block` with max constraints

---

### Solution 3: JavaScript-Only Grid Line Positioning (PHASE 3 continued)

**Problem Detail:** R was setting grid lines with percentage-based CSS (`top: X%`, `left: X%`) which worked with absolute positioning but failed with flexbox centering.

**Implementation:** Removed ALL CSS positioning from R, let JavaScript handle it entirely.

**Files Modified:**
- `R/mod_postal_card_processor.R` (lines 853, 870)
- `R/mod_stamp_face_processor.R` (lines 875, 889)
- `R/mod_stamp_verso_processor.R` (lines 875, 889)

**Change:**
```r
# BEFORE:
tags$div(
  class = "draggable-line horizontal-line",
  `data-boundary-value` = boundary_pos,
  style = sprintf("top: %.4f%%;", top_percent)  # ❌ Percentage positioning
)

# AFTER:
tags$div(
  class = "draggable-line horizontal-line",
  `data-boundary-value` = boundary_pos  # ✅ JavaScript will position
)
```

**Rationale:** JavaScript already had flexbox-aware positioning logic in `draggable_lines.js` (lines 35-115). R's percentage positioning conflicted with this, causing coordinate mismatches.

---

### Solution 4: Fix Pointer Events (PHASE 4)

**Problem Detail:** Grid lines were wrapped in a div with `pointer-events:none;`, blocking ALL mouse interactions including dragging.

**Implementation:** Removed the wrapper div, made grid lines direct children.

**Files Modified:**
- `R/mod_postal_card_processor.R` (lines 908-910)
- `R/mod_stamp_face_processor.R` (lines 909-911)
- `R/mod_stamp_verso_processor.R` (lines 909-911)

**Change:**
```r
# BEFORE:
tags$div(
  style = "position:relative; ...",
  tags$img(...),
  tags$div(
    style = "position:absolute; pointer-events:none;",  # ❌ Blocks interactions
    h_lines, v_lines
  )
)

# AFTER:
tags$div(
  style = "position:relative; ...",
  tags$img(...),
  h_lines, v_lines  # ✅ Direct children, pointer events work
)
```

**Note:** Image already has `pointer-events:none`, so only grid lines are interactive.

---

### Solution 5: Crop Image Cache-Busting (PHASE 4 continued)

**Problem Detail:** Browser cached crop images by URL. After re-extraction with adjusted grid lines, same URLs showed old cached images.

**Implementation:** Added unique timestamps to crop image URLs.

**Files Modified:**
- `R/mod_postal_card_processor.R` (lines 1000-1003)
- `R/mod_stamp_face_processor.R` (lines 686-688, 1013-1015)
- `R/mod_stamp_verso_processor.R` (lines 686-688, 1013-1015)

**Change:**
```r
# BEFORE:
rv$extracted_paths_web <- paste(resource_prefix, rel_paths, sep = "/")
# Result: /session/crops/crop_row0_col0.jpg

# AFTER:
cache_buster <- format(Sys.time(), "%Y%m%d%H%M%OS")
base_urls <- paste(resource_prefix, rel_paths, sep = "/")
rv$extracted_paths_web <- paste0(base_urls, "?v=", cache_buster)
# Result: /session/crops/crop_row0_col0.jpg?v=20251104170505.123456
```

**Rationale:** Each extraction gets a unique timestamp, forcing browser to reload instead of using cached images.

---

## Technical Details

### Browser Console Logging
Enhanced logging in postal card module (lines 888-905) for debugging:
```javascript
console.log('Natural size:', img.naturalWidth, 'x', img.naturalHeight);
console.log('Rendered size:', img.offsetWidth, 'x', img.offsetHeight);
console.log('Parent size:', parent.offsetWidth, 'x', parent.offsetHeight);
console.log('Position:', {top: ..., left: ...});
```

This logging revealed the 69.8px offset issue that led to the flexbox solution.

### JavaScript Coordinate Mapping
The existing `draggable_lines.js` (lines 35-68, 167-287) already had proper flexbox-aware coordinate calculations:
- Detects if image is width-constrained or height-constrained
- Calculates rendered dimensions accounting for `object-fit:contain`
- Computes offset from wrapper edges
- Maps between wrapper pixels, rendered pixels, and original image coordinates

The fix ensured R doesn't override these calculations with conflicting percentage positioning.

---

## Testing Results

### Test Case: 3-Card Postal Image (1882x3507)
✅ **Grid Detection:** Correctly detects 3 rows (not 4)
✅ **Visual Display:** All 3 cards visible (not cut off)
✅ **Grid Lines:** Positioned correctly and aligned with card boundaries
✅ **Dragging:** Grid lines move smoothly when dragged
✅ **Extraction:** Produces 3 correct crops matching visual boundaries
✅ **Re-extraction:** After dragging grid lines, new extraction produces updated crops
✅ **Thumbnail Display:** Crop thumbnails update to show new crops (not cached)

### Measurements (from browser console):
```
Natural size: 1882 x 3507
Rendered size: 271 x 500
Wrapper size: 273 x 500
Offset: 0px from top (correct - no longer 69.8px offset)
```

---

## Related Files and Patterns

### Grid Line JavaScript
- `inst/app/www/draggable_lines.js` - Complete coordinate mapping solution
- Function: `getRenderedImageBounds()` (lines 35-68)
- Function: `updateLinePositions()` (lines 71-115)
- Function: `attachDrag()` (lines 167-287)

### Python Grid Detection
- Python function returns ALL detected boundaries
- R must filter to remove false positives (margins, artifacts)
- Current thresholds: 300px OR 10% work well for typical postal cards
- May need adjustment for stamps or unusual images

### Image Display Pattern
- Flexbox centering for responsive layout
- JavaScript handles all grid line positioning
- Cache-busting for dynamic content
- Pointer events managed at element level

---

## Lessons Learned

1. **Flexbox vs Absolute Positioning:** Flexbox is more reliable for centering variable-sized content
2. **R vs JavaScript Responsibilities:** Let JavaScript handle positioning when it has more context
3. **Browser Caching:** Always cache-bust dynamic images that change without URL changes
4. **Layered Debugging:** Enhanced logging revealed offset issues invisible in rendered output
5. **Incremental Fixes:** Each phase built on the previous, addressing root causes systematically

---

## Future Considerations

### Potential Improvements
- Make MIN_ROW_HEIGHT thresholds configurable per image type
- Add visual feedback during grid line dragging
- Consider debouncing extraction to prevent accidental double-clicks
- Add undo/redo for grid line adjustments

### Known Edge Cases
- Very small stamps (< 300px) might need lower threshold
- Images with irregular spacing might need adaptive filtering
- High DPI displays may affect rendering calculations

---

## Commit Reference
This fix should be committed as a single logical change with all 5 solutions bundled together, as they are interdependent and solve the complete workflow.
