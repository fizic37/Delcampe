# PRP: Image Magnifier for Combined Image Output

name: "Image Magnifier - Interactive Zoom for Combined Images"
description: |
  Add hover-to-magnify functionality on combined images in the eBay export form
  to allow users to inspect details without breaking the existing workflow.
  Critical: Must preserve all existing functionality and avoid conflicts.

---

## Goal

**Feature Goal**: Enable detailed inspection of combined images without leaving the export form

**Deliverable**: Hover-activated magnifying glass on combined images in the Delcampe Export accordion panels

**Success Definition**: Users can hover over combined images to see magnified details, with no disruption to existing AI extraction, form filling, or eBay submission workflows

## User Persona

**Target User**: You - inspecting postcard details before eBay listing

**Use Case**: Quality checking combined images during export preparation

**User Journey**:
1. User processes postcards and generates combined images
2. User navigates to eBay Export tab
3. User opens accordion panel for a combined image
4. User hovers mouse over image → magnifying lens appears
5. User moves mouse to inspect different areas → lens follows cursor
6. User moves mouse away → lens disappears
7. User continues with AI extraction and form filling
8. User sends to eBay (no workflow disruption)

**Pain Points Addressed**:
- ✅ "Can't see fine details in the combined image"
- ✅ "Need to verify text is readable before listing"
- ✅ "Want to check image quality without opening external viewer"
- ✅ "Need quick zoom without workflow interruption"

## Why

- **User Need**: Combined images contain 2-4 crops - need to verify each is clear
- **Quality Control**: Catch quality issues before eBay submission
- **Efficiency**: No need to open external image viewers
- **Non-Disruptive**: Hover interaction doesn't interfere with form
- **Professional**: Better UX for a production workflow

## What

### Magnifying Lens Feature
On-hover magnifying glass for combined images showing:
- **2-3x zoom** of image area under cursor
- **Circular lens** (150-200px diameter)
- **Smooth tracking** of mouse movement
- **Auto-hide** when mouse leaves image
- **Touch support** for mobile/tablet devices

### Integration Points
Add magnifier to:
- ✅ **Primary location**: Combined image preview in accordion panel (R/mod_delcampe_export.R, lines 154-157)
- ⚠️ **Avoid**: Thumbnail images in accordion title (too small, would clutter)
- ⚠️ **Avoid**: AI extraction section (not relevant there)

### Success Criteria

**UI/UX**:
- [ ] Magnifier appears smoothly on hover (no lag)
- [ ] Lens follows cursor accurately
- [ ] Magnifier disappears when mouse leaves image
- [ ] No visual conflicts with accordion or form elements
- [ ] Works on all combined images in all accordion panels
- [ ] Zoom level provides clear detail (2-3x recommended)

**Functionality**:
- [ ] Works with dynamically rendered images (renderUI)
- [ ] No interference with accordion open/close
- [ ] No interference with AI extraction button
- [ ] No interference with form field updates
- [ ] No interference with "Send to eBay" workflow

**Critical Non-Regression**:
- [ ] Accordion panels open/close normally
- [ ] AI extraction still works (button clicks, form population)
- [ ] Form fields update correctly from AI data
- [ ] Send to eBay button functions normally
- [ ] Status badges update correctly
- [ ] No JavaScript errors in console
- [ ] No impact on module namespace (ns())

**Performance**:
- [ ] No noticeable performance degradation
- [ ] Smooth magnification even on large images (5000x5000px)
- [ ] Works with images up to 10MB

## Risk Analysis & Mitigation

### Critical Risks

**RISK 1: JavaScript Namespace Conflicts** (HIGH)
- **Problem**: Custom JavaScript in Shiny modules can fail with namespace issues
- **Impact**: Magnifier won't initialize, or will target wrong images
- **Mitigation**:
  - Use `onload` attribute with properly namespaced IDs
  - Test with multiple images open simultaneously
  - Ensure `ns()` is used for all image IDs
  - Fallback: Use data attributes for auto-initialization

**RISK 2: Accordion Rendering Race Condition** (MEDIUM)
- **Problem**: Magnifier initialization before image fully loaded
- **Impact**: Magnifier doesn't work or shows incorrect dimensions
- **Mitigation**:
  - Use `onload` event for initialization (not DOMContentLoaded)
  - Add image load verification in JS
  - Test with slow network conditions

**RISK 3: Breaking AI Pre-Population** (HIGH)
- **Problem**: JavaScript interference with `updateTextAreaInput()` calls
- **Impact**: Existing AI data won't populate form fields (recently fixed bug)
- **Mitigation**:
  - Magnifier JS should NOT touch form elements
  - Use `pointer-events: none` on lens to avoid click hijacking
  - No event listeners on parent containers
  - Test AI pre-population with magnifier active

**RISK 4: Event Handler Conflicts** (MEDIUM)
- **Problem**: Magnifier mouse events conflict with accordion/button clicks
- **Impact**: Accordion won't open/close, buttons won't click
- **Mitigation**:
  - Magnifier only listens on `<img>` element itself
  - No `stopPropagation()` on events
  - Lens element has higher z-index but no pointer events
  - Test all clickable elements in accordion

**RISK 5: Memory Leaks** (LOW)
- **Problem**: Event listeners not cleaned up when accordion closes
- **Impact**: Performance degradation over time
- **Mitigation**:
  - Use destroy() method in magnifier object
  - Clean up on accordion panel close (if needed)
  - Test with repeated open/close cycles

### Risk Matrix

| Risk | Likelihood | Impact | Priority | Mitigation Strategy |
|------|-----------|--------|----------|---------------------|
| Namespace conflicts | High | High | 🔴 Critical | Proper ns() usage, onload init |
| AI population breaks | Medium | High | 🔴 Critical | No form element touching, test thoroughly |
| Rendering race | Medium | Medium | 🟡 Important | onload event timing |
| Event conflicts | Low | High | 🟡 Important | Isolated event listeners |
| Memory leaks | Low | Low | 🟢 Monitor | Cleanup methods |

## All Needed Context

### Documentation & References

```yaml
- file: reference/MAGNIFYING_GLASS_IMPLEMENTATION.md
  why: Complete implementation guide already prepared
  pattern: JavaScript + CSS + R integration examples
  critical: Contains tested approaches and configuration options
  gotcha: Guide was created for test but not yet integrated

- file: reference/image_magnifier.js
  why: Production-ready JavaScript implementation
  pattern: Self-contained magnifier with destroy method
  critical: |
    - Handles touch and mouse events
    - Auto-initialization via data attributes
    - Programmatic API available
    - Shiny custom message handlers
  gotcha: Must ensure proper namespace handling in Shiny module context

- file: reference/magnifier_r_examples.R
  why: Multiple R integration approaches
  pattern: Examples 1-10 cover different scenarios
  critical: Example 2 (onload) is most reliable for modules
  gotcha: Example 9 shows complete module - use as template

- file: R/mod_delcampe_export.R
  why: Target file for integration
  pattern: Dynamic accordion with renderUI
  critical: |
    - Lines 144-177: create_form_content() renders image
    - Line 154-157: Current <img> tag - ADD magnifier here
    - Lines 440-514: Accordion open observer - PRESERVE this!
    - Lines 559-960: AI extraction logic - DO NOT BREAK!
  gotcha: |
    - Module uses complex reactive state (rv$image_drafts, existing_ai_data)
    - AI pre-population timing critical (later::later with 150ms delay)
    - Multiple images use namespaced IDs (paste0("combined_img_", i))

- file: CLAUDE.md
  why: Core development principles
  critical: |
    - bslib over custom JavaScript (lines 142-151)
    - Module namespace rules
    - < 400 lines per file limit (mod_delcampe_export.R is 1165 lines!)
  gotcha: This is a rare case where simple JavaScript is appropriate

- file: inst/app/www/
  why: Static asset location for JavaScript and CSS
  pattern: Where JS/CSS files must be placed
  critical: |
    - Create: inst/app/www/image_magnifier.js
    - Modify: inst/app/www/styles.css (append magnifier styles)

- package: bslib
  docs: https://rstudio.github.io/bslib/
  why: Understanding accordion behavior
  critical: accordion_panel renders dynamically
  gotcha: JavaScript init must happen after DOM render

- reference: .serena/memories/ai_ui_population_timing_fix_20251014.md
  why: Recently fixed timing bug with AI form population
  critical: DO NOT BREAK the later::later(delay=0.15) pattern
  gotcha: Any JavaScript that interferes with form elements will break this
```

### Current Code Structure

**R/mod_delcampe_export.R - Image Rendering** (lines 144-177):
```r
create_form_content <- function(idx, path) {
  div(
    style = "padding: 20px;",

    fluidRow(
      # Left: Image preview (width 6)
      column(
        6,
        div(
          style = "text-align: center;",
          tags$img(
            src = path,
            style = "width: 100%; max-height: 300px; object-fit: contain;
                     border-radius: 8px; border: 1px solid #dee2e6;"
          )
        )
      ),
      # Right: AI controls...
    )
    # ... rest of form
  )
}
```

**Target Integration Point**:
- The `tags$img()` element at lines 154-157
- Need to add: `id = ns(paste0("combined_img_", idx))`
- Need to add: `onload` initialization call

### Architecture Changes

**Minimal Impact Design**:
```
inst/app/www/
  ├── image_magnifier.js      [NEW - 150 lines]
  └── styles.css              [MODIFY - append 30 lines]

R/
  └── mod_delcampe_export.R   [MODIFY - 5 lines changed]
      ├── Line 12: Add tags$script for JS
      ├── Line 154-157: Add id and onload to <img>

app_ui.R                      [NO CHANGE]
app_server.R                  [NO CHANGE]
```

**No Database Changes**: Pure UI enhancement
**No Module Splitting**: Changes contained to existing module
**No New Dependencies**: Uses existing JavaScript capability

## How - Implementation Strategy

### Phase 1: Add JavaScript & CSS Assets (20 min)

**Step 1.1**: Create JavaScript file
```bash
# Copy prepared implementation
cp reference/image_magnifier.js inst/app/www/image_magnifier.js
```

**Verification**:
```r
file.exists("inst/app/www/image_magnifier.js")  # Should be TRUE
```

**Step 1.2**: Add CSS styles
```bash
# Append magnifier CSS to existing styles.css
cat reference/magnifier_styles.css >> inst/app/www/styles.css
```

Or manually add to `inst/app/www/styles.css`:
```css
/* Magnifier Lens Styles */
.magnifier-lens {
  position: absolute;
  border: 3px solid #4c6ef5;
  border-radius: 50%;
  cursor: none;
  box-shadow: 0 0 20px rgba(0, 0, 0, 0.5);
  z-index: 9999;
  pointer-events: none;  /* Critical: don't block clicks */
}

.magnifiable-image {
  cursor: crosshair;
}
```

**Verification**:
```bash
tail -20 inst/app/www/styles.css  # Should show magnifier styles
```

### Phase 2: Integrate into Module UI (30 min)

**Step 2.1**: Add JavaScript reference to module UI

**File**: `R/mod_delcampe_export.R`
**Location**: After line 11 (in `mod_delcampe_export_ui` function)

**BEFORE**:
```r
mod_delcampe_export_ui <- function(id) {
  ns <- NS(id)
  tagList(
    # Dynamic accordion with auto-collapse
```

**AFTER**:
```r
mod_delcampe_export_ui <- function(id) {
  ns <- NS(id)
  tagList(
    # Add image magnifier JavaScript
    tags$head(
      tags$script(src = "www/image_magnifier.js")
    ),

    # Dynamic accordion with auto-collapse
```

**Step 2.2**: Add ID and onload to combined image

**File**: `R/mod_delcampe_export.R`
**Location**: Lines 154-157 (in `create_form_content` function)

**BEFORE**:
```r
          tags$img(
            src = path,
            style = "width: 100%; max-height: 300px; object-fit: contain; border-radius: 8px; border: 1px solid #dee2e6;"
          )
```

**AFTER**:
```r
          tags$img(
            id = ns(paste0("combined_img_", idx)),
            src = path,
            class = "magnifiable-image",
            style = "width: 100%; max-height: 300px; object-fit: contain; border-radius: 8px; border: 1px solid #dee2e6;",
            onload = sprintf(
              "if (typeof initImageMagnifier === 'function') {
                initImageMagnifier('%s', 2.5, 200);
              } else {
                console.error('Image magnifier not loaded');
              }",
              ns(paste0("combined_img_", idx))
            )
          )
```

**Key Points**:
- ✅ `id = ns(...)` ensures proper namespace
- ✅ `onload` guarantees image is loaded before init
- ✅ `typeof` check prevents errors if JS not loaded
- ✅ `2.5` zoom level = 250% magnification
- ✅ `200` lens size = 200px diameter

**Verification**:
```r
# Source the file to check for syntax errors
source("R/mod_delcampe_export.R")
# No errors = syntax is correct
```

### Phase 3: Testing & Validation (45 min)

**Test 3.1**: Basic Magnifier Functionality
```r
# Run app
golem::run_dev()

# Navigate to eBay Export tab
# Open an accordion panel with combined image
# Expected results:
#   ✅ Magnifying lens appears on hover
#   ✅ Lens follows mouse smoothly
#   ✅ Magnified view shows 2.5x zoom
#   ✅ Lens disappears when mouse leaves
```

**Test 3.2**: Multiple Images (Namespace Test)
```r
# Open multiple accordion panels
# Hover over each image
# Expected results:
#   ✅ Each image has independent magnifier
#   ✅ No ID conflicts
#   ✅ No console errors
```

**Test 3.3**: AI Extraction (Non-Regression - CRITICAL)
```r
# Open accordion panel
# Click "Extract with AI" button
# Wait for completion
# Expected results:
#   ✅ Form fields populate correctly
#   ✅ Title, description, price, condition all filled
#   ✅ Green success banner appears
#   ✅ No errors in console
#   ✅ Magnifier still works after AI extraction
```

**Test 3.4**: AI Pre-Population (Duplicate Image - CRITICAL)
```r
# Process same combined image twice (duplicate)
# Open accordion for duplicate image
# Expected results:
#   ✅ Form fields auto-populate with existing AI data
#   ✅ "Previous AI extraction loaded" message shows
#   ✅ Fields populate within 200ms
#   ✅ Magnifier works normally
```

**Test 3.5**: Accordion Interactions
```r
# Open accordion panel
# Hover over image (magnifier active)
# Click on accordion to close
# Open different accordion panel
# Expected results:
#   ✅ Accordion opens/closes normally
#   ✅ No stuck magnifier lenses
#   ✅ New image gets its own magnifier
```

**Test 3.6**: Send to eBay (Complete Workflow)
```r
# Open accordion panel
# Use magnifier to inspect image
# Click "Extract with AI"
# Review extracted data
# Click "Send to eBay"
# Expected results:
#   ✅ eBay listing created successfully
#   ✅ No errors related to magnifier
#   ✅ Status badge updates to "Sent"
```

**Test 3.7**: Browser Console Check
```r
# Open browser DevTools (F12)
# Navigate to Console tab
# Perform all above tests
# Expected results:
#   ✅ No JavaScript errors
#   ✅ Only expected log messages
#   ⚠️ If errors appear: investigate before proceeding
```

**Test 3.8**: Performance Test
```r
# Open 5-10 accordion panels rapidly
# Hover over images rapidly
# Close and reopen panels
# Expected results:
#   ✅ No lag or freezing
#   ✅ Smooth magnification
#   ✅ Memory usage stable
```

### Phase 4: Edge Cases & Polish (15 min)

**Test 4.1**: Small Images
```r
# Process images smaller than lens size
# Expected: Magnifier still works, shows zoomed detail
```

**Test 4.2**: Very Large Images
```r
# Process images > 5000x5000 pixels
# Expected: Magnifier performance remains smooth
```

**Test 4.3**: Network Delay Simulation
```r
# Chrome DevTools → Network → Slow 3G
# Open accordion panel
# Expected: onload fires only when image fully loaded
```

**Test 4.4**: Rapid Accordion Switching
```r
# Quickly open/close different panels
# Expected: No orphaned magnifier lenses, no errors
```

## Validation Gates

### Gate 1: Assets Deployed
```bash
VALIDATE: ls -l inst/app/www/image_magnifier.js
EXPECT: File exists, ~150 lines
FIX: Copy from reference/ directory

VALIDATE: grep "magnifier-lens" inst/app/www/styles.css
EXPECT: CSS rules present
FIX: Append styles from reference/magnifier_styles.css
```

### Gate 2: Syntax Check
```bash
VALIDATE: R -e "source('R/mod_delcampe_export.R')"
EXPECT: No syntax errors
FIX: Check quotes, parentheses, sprintf formatting
```

### Gate 3: App Loads
```bash
VALIDATE: Run golem::run_dev()
EXPECT: App starts, no errors in R console
FIX: Check for package dependencies, file paths
```

### Gate 4: Magnifier Works
```bash
VALIDATE: Open accordion → hover over image
EXPECT: Magnifying lens appears and tracks mouse
FIX: Check browser console, verify JS loaded, check ns() usage
```

### Gate 5: Non-Regression - AI Extraction
```bash
VALIDATE: Click "Extract with AI" → form populates
EXPECT: All fields filled correctly, no errors
FIX: If broken - remove magnifier, debug separately
```

### Gate 6: Non-Regression - Send to eBay
```bash
VALIDATE: Click "Send to eBay" → listing created
EXPECT: Success notification, listing URL
FIX: If broken - check image paths, API connection
```

## Test Plan

### Critical Path Testing

**Test Suite 1: Magnifier Basic Functionality**
- [ ] Lens appears on mouse enter
- [ ] Lens tracks mouse movement smoothly
- [ ] Lens disappears on mouse leave
- [ ] Zoom level is appropriate (can read details)
- [ ] Lens size is appropriate (not too big/small)
- [ ] Circular shape and border visible

**Test Suite 2: Module Integration**
- [ ] Works with first image in accordion
- [ ] Works with all images (test 3+ images)
- [ ] Each image has unique ID (no conflicts)
- [ ] Magnifier initializes after image load
- [ ] No errors in browser console

**Test Suite 3: Non-Regression - AI Workflows**
- [ ] AI extraction button still works
- [ ] Form fields populate correctly after extraction
- [ ] Pre-population works for duplicate images
- [ ] "Re-extract" button works on duplicates
- [ ] Status messages display correctly
- [ ] Draft saving still works

**Test Suite 4: Non-Regression - Accordion**
- [ ] Accordion panels open/close normally
- [ ] Auto-collapse works (one panel at a time)
- [ ] Panel titles display correctly
- [ ] Status badges update correctly
- [ ] Thumbnail images display correctly

**Test Suite 5: Non-Regression - eBay Submission**
- [ ] "Send to eBay" button works
- [ ] Image upload succeeds
- [ ] Listing creation succeeds
- [ ] Status changes to "Sent"
- [ ] Success notification appears

**Test Suite 6: Edge Cases**
- [ ] Small images (< 500x500)
- [ ] Large images (> 5000x5000)
- [ ] Slow network (delayed image load)
- [ ] Rapid accordion switching
- [ ] Multiple rapid hovers

**Test Suite 7: Browser Compatibility**
- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Edge (latest)
- [ ] Mobile/Touch (if applicable)

### Performance Benchmarks

| Metric | Target | Acceptable | Failure |
|--------|--------|------------|---------|
| Lens appearance delay | < 50ms | < 100ms | > 200ms |
| Mouse tracking smoothness | 60 FPS | 30 FPS | < 30 FPS |
| Image load to init | < 100ms | < 200ms | > 500ms |
| Memory per magnifier | < 1MB | < 5MB | > 10MB |

## Files Modified

### inst/app/www/image_magnifier.js
**Action**: CREATE new file
**Lines**: ~150
**Source**: Copy from `reference/image_magnifier.js`
**Purpose**: Magnifying glass logic with Shiny integration

### inst/app/www/styles.css
**Action**: MODIFY - append styles
**Lines Added**: ~30
**Source**: Append from `reference/magnifier_styles.css`
**Purpose**: Magnifier lens styling

### R/mod_delcampe_export.R
**Action**: MODIFY - minimal changes
**Lines Modified**: 5
**Changes**:
1. Line ~12: Add `tags$head(tags$script(...))` for JS
2. Line ~154-157: Add `id`, `class`, `onload` to `<img>` tag

**Current size**: 1165 lines (over limit!)
**Post-change size**: 1170 lines (still over, but only +5)
**Note**: Consider splitting module in future (separate task)

## Common Issues & Solutions

### Issue: Magnifier not appearing
**Symptoms**: Hover over image, no lens appears
**Debug Steps**:
1. Open browser DevTools (F12) → Console
2. Check for error: "Image with ID ... not found"
3. Check for error: "initImageMagnifier is not a function"

**Solutions**:
- If ID not found: Check `ns()` usage in image ID
- If function not found: Check JS file loaded (Network tab)
- If no errors but no lens: Check CSS loaded (Elements tab)

### Issue: Magnifier appears in wrong location
**Symptoms**: Lens offset from cursor
**Debug Steps**:
1. Inspect image element (right-click → Inspect)
2. Check for `position: relative` on parent containers
3. Check for CSS transforms that affect positioning

**Solutions**:
- Ensure parent container has proper positioning
- Check z-index conflicts with other elements
- Verify image dimensions calculated correctly

### Issue: AI extraction stops working
**Symptoms**: Button clicks but form doesn't populate
**Debug Steps**:
1. Check console for errors during extraction
2. Check if `updateTextAreaInput()` calls still execute
3. Check if `later::later()` timing still works

**Solutions**:
- **ROLLBACK magnifier changes immediately**
- This is a critical regression - fix before proceeding
- Check if magnifier events are calling `stopPropagation()`
- Ensure lens has `pointer-events: none`

### Issue: Accordion won't open/close
**Symptoms**: Click on accordion title, nothing happens
**Debug Steps**:
1. Check console for JavaScript errors
2. Check if lens element is blocking clicks
3. Check z-index of magnifier elements

**Solutions**:
- Ensure lens has `pointer-events: none` in CSS
- Check lens is removed when image not visible
- Verify no event listeners on accordion container

### Issue: Multiple lenses on same image
**Symptoms**: 2+ magnifier lenses appear on hover
**Debug Steps**:
1. Check if `initImageMagnifier()` called multiple times
2. Check for duplicate image IDs
3. Check if accordion re-renders trigger re-init

**Solutions**:
- Add check in JS to prevent double initialization
- Use `data-magnifier-initialized` attribute to track
- Call `destroy()` method before re-initializing

### Issue: Memory leak (performance degrades)
**Symptoms**: App slows down after many opens/closes
**Debug Steps**:
1. Chrome DevTools → Performance → Record
2. Perform repeated open/close operations
3. Check for increasing memory usage

**Solutions**:
- Implement cleanup on accordion close
- Call `destroy()` method on magnifier objects
- Remove event listeners properly

## Success Metrics

### Technical Success
- [ ] Magnifier works on all combined images
- [ ] < 100ms initialization time
- [ ] Smooth tracking (no lag)
- [ ] No JavaScript errors
- [ ] No CSS conflicts
- [ ] No performance degradation
- [ ] All existing features work (non-regression)

### User Success
- [ ] Can inspect image details clearly
- [ ] No learning curve (intuitive hover)
- [ ] No workflow disruption
- [ ] Zoom level appropriate for detail inspection
- [ ] Professional appearance

### Code Quality
- [ ] < 200 lines of new code (JS + CSS + R combined)
- [ ] No code duplication
- [ ] Clear comments in JavaScript
- [ ] Follows existing patterns
- [ ] Easy to disable if needed (remove 5 lines)

## Rollback Plan

If magnifier causes issues:

**Immediate Rollback** (< 2 min):
```r
# 1. Remove JS reference from mod_delcampe_export.R (line ~12)
# 2. Remove id, class, onload from <img> tag (lines ~154-157)
# 3. Restart app
```

**Complete Removal** (< 5 min):
```bash
# Delete JavaScript file
rm inst/app/www/image_magnifier.js

# Revert CSS changes
git checkout inst/app/www/styles.css

# Revert R changes
git checkout R/mod_delcampe_export.R

# Restart app
```

**Recovery Steps**:
1. Verify all tests pass without magnifier
2. Review error logs to identify conflict
3. Fix issue in isolated environment
4. Re-test before re-deploying

## Future Enhancements (Out of Scope)

These are intentionally excluded from initial implementation:

- [ ] User-configurable zoom level (slider)
- [ ] Keyboard shortcuts (Z to toggle)
- [ ] Click-to-lock zoom position
- [ ] Magnifier on thumbnail images
- [ ] Magnifier on cropped images
- [ ] Rectangle zoom instead of circular
- [ ] Zoom in/out with scroll wheel
- [ ] Save magnified view as image

**Rationale**: Keep initial implementation simple and proven. Add features based on user feedback.

---

## Implementation Checklist

- [ ] Phase 1: Copy JavaScript and CSS assets
- [ ] Phase 2: Integrate into module (5 line changes)
- [ ] Phase 3: Run all 8 test suites
- [ ] Phase 4: Edge case testing
- [ ] Phase 5: Non-regression validation
- [ ] Phase 6: Performance benchmarks
- [ ] Phase 7: Browser compatibility check
- [ ] Phase 8: Document any issues found
- [ ] Phase 9: Final validation

**Total Estimated Time**: 2 hours
**Difficulty**: Medium (high risk, but simple code)
**Dependencies**: None (pure UI enhancement)
**Risk Level**: Medium-High (must not break existing features)

---

**CRITICAL REMINDER**: This feature is purely visual enhancement. If ANY existing functionality breaks during testing, IMMEDIATELY rollback and debug separately. Do not proceed with a broken magnifier that disrupts the core workflow.
