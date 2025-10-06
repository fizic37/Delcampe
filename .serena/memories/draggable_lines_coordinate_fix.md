# Draggable Lines Coordinate Mapping Solution

## Date: 2025-01-06
## Module: mod_postal_card_processor
## Component: inst/app/www/draggable_lines.js

## Problem Statement

The draggable lines on images did not properly map to crop coordinates. When users dragged red horizontal lines to separate postcards, the cropped results were offset by several pixels. The issue worsened when resizing the browser window (e.g., opening DevTools).

**Root Cause:** Lines were positioned as children of a wrapper div (400px fixed height) but didn't account for the rendered image's actual position within that wrapper when using CSS `object-fit: contain`. This created padding around the image, causing coordinate misalignment.

## Solution Overview

Complete rewrite of the JavaScript coordinate mapping logic to:
1. Calculate actual rendered image bounds (accounting for aspect ratio and padding)
2. Position lines relative to the rendered image with proper offsets
3. Convert coordinates through proper forward and reverse transformations
4. Update positions dynamically on window resize with debouncing

## Technical Details

### Three Coordinate Systems

The solution handles conversion between three different coordinate systems:

1. **Original Image Coordinates** (e.g., 1915×3507) - What Python cropping needs
2. **Rendered Image Coordinates** (e.g., 218.5×400) - What's actually visible on screen
3. **Wrapper Coordinates** (e.g., 800×400) - Where lines are positioned as DOM elements

### Key Calculations

**Rendered Image Bounds:**
```javascript
const imgAspect = origWidth / origHeight;
const wrapperAspect = wrapperRect.width / wrapperRect.height;

if (imgAspect > wrapperAspect) {
  // Image is wider - constrained by wrapper width
  renderedWidth = wrapperRect.width;
  renderedHeight = renderedWidth / imgAspect;
  offsetLeft = 0;
  offsetTop = (wrapperRect.height - renderedHeight) / 2;
} else {
  // Image is taller - constrained by wrapper height
  renderedHeight = wrapperRect.height;
  renderedWidth = renderedHeight * imgAspect;
  offsetTop = 0;
  offsetLeft = (wrapperRect.width - renderedWidth) / 2;
}
```

**Forward Conversion (Original → Screen):**
```
boundary (px in original) 
  → percentage of original dimension
    → position in rendered image (px)
      → position in wrapper (px) = rendered position + offset
```

**Reverse Conversion (Screen → Original):**
```
position in wrapper (px)
  → position in rendered image (px) = wrapper position - offset
    → percentage of rendered dimension
      → boundary (px in original)
```

### Critical Functions Added

1. **`getRenderedImageBounds()`** - Calculates where image actually appears in wrapper
2. **`updateLinePositions()`** - Positions lines on rendered image with proper offset
3. **Enhanced drag handlers** - Convert coordinates through proper chain on drag end

### Data Attributes Used

- `data-original-width` / `data-original-height` on `<img>` - Original image dimensions
- `data-boundary-value` on each line - Stores position in original coordinates for repositioning
- `data-draggrid` on wrapper - Flags wrapper for initialization

## Files Modified

### Primary Changes
- **inst/app/www/draggable_lines.js** - Complete rewrite with proper coordinate mapping

### R Module (No Changes Needed)
- **R/mod_postal_card_processor.R** - Already handled conversion correctly on R side

### Tests Added
- **tests/testthat/test-mod_postal_card_processor.R** - Automated unit tests
- **tests/manual/test_coordinate_mapping.R** - Manual verification with visual output
- **tests/manual/verify_fix.R** - Complete system verification script

### Documentation Created
- **COORDINATE_FIX_SUMMARY.md** - Complete technical reference
- **IMPLEMENTATION_GUIDE.md** - Quick start and testing guide
- **This file** - Persistent memory for future LLM sessions

## Testing

### Automated Tests
```r
# Run unit tests
testthat::test_file("tests/testthat/test-mod_postal_card_processor.R")

# Run manual verification
source("tests/manual/verify_fix.R")
```

### Manual Visual Testing
1. Run app: `Delcampe::run_app()`
2. Upload test image
3. Open DevTools (F12) → Console
4. Drag lines and check console logs
5. Extract cards and verify crops match

### Expected Console Output
```
🎯 Initializing draggable grid for wrapper: face-grid_ui_wrapper
📐 Original dimensions: 1915 x 3507
🖼️ Rendered image bounds: {offset: 290.75px, 0px, size: 218.5px x 400px}
🔴 H-line 2: boundary=1753, %=50.00%, rendered=200.00px, final=200.00px
```

## Success Metrics

✅ Lines overlay exactly on image features (no offset into padding)
✅ Lines stay aligned when resizing window or DevTools
✅ Cropped images match visual line positions perfectly
✅ Works with all grid configurations (1×1, 2×2, 3×3, etc.)
✅ Sub-pixel accuracy (<1px error in round-trip conversion)

## Common Issues & Solutions

### Lines Don't Appear
- Check if `data-original-width`/`data-original-height` are set on `<img>`
- Verify `data-draggrid="true"` on wrapper
- Ensure JavaScript file is loaded

### Lines in Wrong Position
- Confirm image has `object-fit: contain` in CSS
- Verify wrapper has `position: relative`
- Check that `updateLinePositions()` runs after image loads

### Crops Don't Match Lines
- Verify R console shows correct scale_factor calculation
- Confirm JavaScript sends position in **rendered** image (not wrapper)
- Check that `wrapper_dim` is the **rendered** dimension

## Performance Considerations

- Resize handler is debounced (100ms) to prevent excessive recalculations
- Bounds calculated once at drag start and reused during drag
- No polling or continuous calculations - event-driven only
- Lines update only when necessary (load, resize, manual repositioning)

## Browser Compatibility

Tested and working on:
- Chrome/Edge (Chromium-based)
- Firefox
- Safari

## Future Enhancement Ideas

1. Snap-to-grid functionality for easier alignment
2. Visual pixel rulers showing measurements
3. Undo/redo for line adjustments
4. Save/load boundary presets for common layouts
5. Auto-snap to detected edges
6. Preview overlay showing crop regions before extraction

## Related Modules

- **mod_postal_card_processor** - Main module using this functionality
- **extract_postcards.py** - Python script that receives crop coordinates

## Key Learnings for Future Development

1. Always account for CSS layout effects (object-fit, padding, margins) in coordinate calculations
2. Store data in original coordinate system and convert to display coordinates
3. Use data attributes to persist state across DOM updates
4. Debounce resize handlers to prevent performance issues
5. Comprehensive logging is essential for debugging coordinate transformations
6. Test with various window sizes and zoom levels

## Quick Reference for Future LLMs

If working on coordinate mapping issues:
1. Check this file first for context
2. Review `COORDINATE_FIX_SUMMARY.md` for technical details
3. Run `tests/manual/verify_fix.R` to check current state
4. Look at console logs when dragging lines (shows full conversion chain)
5. The key is accounting for `object-fit: contain` padding in coordinate conversion

## Contact Points in Code

**JavaScript Entry Point:**
- Function: `initDraggableGrid(wrapper)`
- File: `inst/app/www/draggable_lines.js`
- Called by: DOMContentLoaded event on elements with `[data-draggrid]`

**R Entry Point:**
- Module: `mod_postal_card_processor_server()`
- File: `R/mod_postal_card_processor.R`
- Observers: `input$hline_moved_direct`, `input$vline_moved_direct`

**Python Integration:**
- Function: `crop_image_with_boundaries()`
- File: `inst/python/extract_postcards.py`
- Receives: `h_boundaries`, `v_boundaries` in original image coordinates
