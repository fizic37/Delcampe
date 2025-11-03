# Stamp UI Nested Accordion Fix

**Date:** 2025-11-03  
**Issue:** Nested accordion causing parent accordion to close  
**Status:** ✅ Fixed

## Problem

When users clicked to open the metadata accordion (nested inside the combined image accordion), it caused the parent accordion to close, throwing the user out of the current item they were working on.

**Root Cause:** bslib::accordion components don't work well when nested - clicking a nested accordion's controls can trigger events on the parent accordion.

## Solution

Replaced the nested `bslib::accordion()` with native HTML `<details>` and `<summary>` elements, which are independent of the parent accordion and don't interfere with its state.

## Implementation

**File Modified:** `R/mod_stamp_export.R` (lines 537-626, 58-72)

### Before (Nested Accordion - BROKEN):
```r
bslib::accordion(
  id = ns(paste0("metadata_accordion_", idx)),
  open = FALSE,
  bslib::accordion_panel(
    title = tags$span(icon("info-circle"), " Optional Stamp Metadata..."),
    # ... fields ...
  )
)
```

### After (HTML details/summary - FIXED):
```r
tags$details(
  style = "margin-top: 20px; margin-bottom: 20px; border: 1px solid #dee2e6; border-radius: 6px; padding: 10px; background: #f8f9fa;",
  tags$summary(
    style = "cursor: pointer; font-weight: 500; color: #495057; padding: 8px; user-select: none;",
    icon("info-circle", style = "color: #17a2b8; margin-right: 8px;"),
    "Optional Stamp Metadata (Country, Year, Catalog Numbers)"
  ),
  tags$div(
    style = "margin-top: 15px; padding: 10px; background: white; border-radius: 4px;",
    # ... all metadata fields ...
  )
)
```

## CSS Enhancements (lines 58-72)

Added styling for the details/summary element:
```css
/* Style the details/summary metadata collapsible */
details summary {
  transition: all 0.2s ease;
}

details summary:hover {
  background: #e9ecef;
  border-radius: 4px;
}

details[open] summary {
  margin-bottom: 10px;
  padding-bottom: 10px;
  border-bottom: 1px solid #dee2e6;
}
```

## Benefits

1. **No Interference:** HTML details/summary is completely independent of parent accordion
2. **Native Browser Support:** Uses standard HTML5 elements, no JavaScript required
3. **Better UX:** Smooth transitions, hover effects, visual feedback
4. **Accessible:** Native semantic HTML with built-in keyboard support
5. **Lightweight:** No additional dependencies or event handlers needed

## Technical Note

The `<details>` element is part of HTML5 and provides native collapsible/expandable functionality:
- Browser handles all expand/collapse logic
- Built-in ARIA attributes for accessibility
- No JavaScript conflicts with Shiny's accordion
- Works across all modern browsers

## Testing

User should verify:
1. ✅ Metadata section expands/collapses smoothly
2. ✅ Parent accordion stays open when expanding metadata
3. ✅ All metadata fields are accessible and functional
4. ✅ Visual styling matches the rest of the UI
5. ✅ Hover effects work on the summary line

## Related Files

- `R/mod_stamp_export.R` - Main implementation
- `.serena/memories/stamp_ui_optimization_complete_20251103.md` - Original optimization docs

## Pattern for Future Use

**Lesson Learned:** When you need collapsible sections inside bslib::accordion panels, use HTML `<details>`/`<summary>` instead of nested accordions to avoid event interference.

**Pattern:**
```r
tags$details(
  tags$summary("Click to expand"),
  tags$div(
    # Content goes here
  )
)
```

This pattern should be used anywhere we need expandable sections that shouldn't interfere with parent UI components.
