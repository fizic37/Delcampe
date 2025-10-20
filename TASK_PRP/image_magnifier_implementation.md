# TASK PRP: Image Magnifier Implementation

**Source PRP**: `PRPs/PRP_IMAGE_MAGNIFIER_COMBINED.md`
**Created**: 2025-10-20
**Complexity**: Medium (Simple code, high risk)
**Estimated Time**: 2 hours

---

## Executive Summary

Implement hover-activated magnifying glass on combined images in the Delcampe Export module to enable detailed image inspection without workflow disruption. This is a **pure UI enhancement** with **zero database changes** and **minimal code changes** (5 lines in R, plus 2 new static files).

**Critical Success Factor**: Must not break existing AI extraction or eBay submission workflows.

---

## Context & Background

### Purpose
Users need to inspect fine details in combined postcard images before creating eBay listings, but currently must open external viewers which disrupts their workflow.

### Technical Context

```yaml
Current Implementation:
  - Module: R/mod_delcampe_export.R (1027 lines)
  - Image Display: Lines 154-157 (basic <img> tag)
  - Location: Inside bslib::accordion panels
  - Rendering: Dynamic via renderUI
  - Namespace: Module uses ns() for IDs

Prepared Assets:
  - reference/image_magnifier.js (146 lines) - Production ready
  - reference/magnifier_styles.css (61 lines) - Complete CSS
  - reference/magnifier_r_examples.R (407 lines) - Integration patterns
  - reference/MAGNIFYING_GLASS_IMPLEMENTATION.md - Full guide

Key Constraints:
  - DO NOT break AI pre-population (fixed in .serena/memories/ai_ui_population_timing_fix_20251014.md)
  - DO NOT interfere with accordion open/close
  - DO NOT block form field updates
  - PRESERVE module namespace (ns()) handling
```

### Dependencies

**Required Files**:
- ✅ `reference/image_magnifier.js` - Exists, tested
- ✅ `reference/magnifier_styles.css` - Exists, tested
- ✅ `R/mod_delcampe_export.R` - Current implementation

**Memory Files to Review**:
- `.serena/memories/ai_ui_population_timing_fix_20251014.md` - Critical timing bug fix
- `.serena/memories/accordion_success_20251010.md` - Accordion implementation patterns
- `CLAUDE.md` - Development standards (lines 142-151: Module namespace rules)

**No External Packages Required**: Uses existing JavaScript capability in Shiny

---

## Risk Analysis

### Critical Risks (Must Monitor)

#### RISK 1: JavaScript Namespace Conflicts (HIGH PRIORITY)
**Problem**: Custom JavaScript in Shiny modules can fail with namespaced IDs
**Symptom**: Magnifier doesn't initialize or targets wrong image
**Test**: Open multiple accordion panels, verify each image has unique magnifier
**Mitigation**: Use `ns()` wrapper for all image IDs, `onload` initialization
**Rollback Trigger**: Console errors mentioning "Image with ID ... not found"

#### RISK 2: AI Pre-Population Breaks (CRITICAL - ZERO TOLERANCE)
**Problem**: JavaScript interference with `updateTextAreaInput()` calls
**Symptom**: Form fields don't populate after AI extraction
**Test**: Run full AI extraction test suite (Tests 3.3, 3.4 below)
**Mitigation**: Magnifier uses `pointer-events: none`, no form element touching
**Rollback Trigger**: ANY failure in AI extraction workflow - immediate rollback required

#### RISK 3: Accordion Rendering Race Condition (MEDIUM)
**Problem**: Magnifier initializes before image fully loaded
**Symptom**: Lens doesn't appear or shows incorrect dimensions
**Test**: Slow 3G network simulation in Chrome DevTools
**Mitigation**: Use `onload` attribute (not DOMContentLoaded)
**Rollback Trigger**: Magnifier fails to appear on >30% of accordion opens

#### RISK 4: Event Handler Conflicts (MEDIUM)
**Problem**: Mouse events conflict with accordion clicks
**Symptom**: Accordion won't open/close, buttons don't respond
**Test**: Click all interactive elements while hovering over image
**Mitigation**: Magnifier listens only on `<img>`, lens has no pointer events
**Rollback Trigger**: Any accordion or button click failure

---

## Implementation Tasks

### PHASE 1: Asset Deployment (10 min)

#### TASK 1.1: Copy JavaScript File
```yaml
ACTION: Copy reference/image_magnifier.js → inst/app/www/image_magnifier.js

COMMAND:
  cp reference/image_magnifier.js inst/app/www/image_magnifier.js

VALIDATE:
  - file.exists("inst/app/www/image_magnifier.js") == TRUE
  - File size ~146 lines, ~4.5KB
  - Contains "function initImageMagnifier"
  - Contains "window.initImageMagnifier = initImageMagnifier"

IF_FAIL:
  - Check source file exists: ls -la reference/image_magnifier.js
  - Verify target directory exists: ls -la inst/app/www/
  - Check file permissions: ls -la inst/app/www/image_magnifier.js

ROLLBACK: rm inst/app/www/image_magnifier.js
```

#### TASK 1.2: Append CSS Styles
```yaml
ACTION: Append reference/magnifier_styles.css → inst/app/www/styles.css

COMMAND:
  cat reference/magnifier_styles.css >> inst/app/www/styles.css

VALIDATE:
  - grep -q "\.magnifier-lens" inst/app/www/styles.css
  - grep -q "pointer-events: none" inst/app/www/styles.css
  - grep -q "\.magnifiable-image-container" inst/app/www/styles.css
  - tail -20 inst/app/www/styles.css shows magnifier styles

IF_FAIL:
  - Check source file: cat reference/magnifier_styles.css
  - Check target file writable: test -w inst/app/www/styles.css
  - Verify no duplicate append: grep -c "magnifier-lens" inst/app/www/styles.css

ROLLBACK:
  git checkout inst/app/www/styles.css
```

**Checkpoint 1**: Verify both files deployed
```r
# R Console
file.exists("inst/app/www/image_magnifier.js")  # Should be TRUE
readLines("inst/app/www/styles.css", n = -1) |>
  grep(pattern = "magnifier-lens", value = TRUE) |>
  length() > 0  # Should be TRUE
```

---

### PHASE 2: Module Integration (20 min)

#### TASK 2.1: Add JavaScript Reference to Module UI
```yaml
ACTION: Modify R/mod_delcampe_export.R (Lines 11-18)

LOCATION: In mod_delcampe_export_ui function, after line 13

CHANGE:
  FIND:
    mod_delcampe_export_ui <- function(id) {
      ns <- NS(id)

      tagList(
        # Accordion will be dynamically generated
        uiOutput(ns("accordion_container"))
      )
    }

  REPLACE_WITH:
    mod_delcampe_export_ui <- function(id) {
      ns <- NS(id)

      tagList(
        # Add image magnifier JavaScript
        tags$head(
          tags$script(src = "www/image_magnifier.js")
        ),

        # Accordion will be dynamically generated
        uiOutput(ns("accordion_container"))
      )
    }

VALIDATE:
  - R -e "source('R/mod_delcampe_export.R')" # Should parse without errors
  - grep -A 2 "tags\$head" R/mod_delcampe_export.R | grep "image_magnifier.js"

IF_FAIL:
  - Check syntax: Check matching parentheses and commas
  - Verify quote consistency: Should be "www/image_magnifier.js"
  - Test in isolation: tags$head(tags$script(src = "www/image_magnifier.js"))

ROLLBACK: git checkout R/mod_delcampe_export.R
```

#### TASK 2.2: Add ID and Magnifier to Image Tag
```yaml
ACTION: Modify R/mod_delcampe_export.R (Lines 154-157)

LOCATION: In create_form_content function, image tag within column(6, ...)

CHANGE:
  FIND:
    tags$img(
      src = path,
      style = "width: 100%; max-height: 300px; object-fit: contain; border-radius: 8px; border: 1px solid #dee2e6;"
    )

  REPLACE_WITH:
    tags$img(
      id = ns(paste0("combined_img_", idx)),
      src = path,
      class = "magnifiable-image",
      style = "width: 100%; max-height: 300px; object-fit: contain; border-radius: 8px; border: 1px solid #dee2e6;",
      onload = sprintf(
        "if (typeof initImageMagnifier === 'function') {
          initImageMagnifier('%s', 2.5, 200);
        } else {
          console.error('Image magnifier script not loaded');
        }",
        ns(paste0("combined_img_", idx))
      )
    )

CRITICAL_NOTES:
  - id = ns(...) is MANDATORY for module namespace handling
  - onload ensures image fully loaded before magnifier init
  - typeof check prevents error if JS file fails to load
  - 2.5 = zoom level (250% magnification)
  - 200 = lens diameter in pixels
  - sprintf() properly escapes quotes in JavaScript

VALIDATE:
  - R -e "source('R/mod_delcampe_export.R')" # Should parse without errors
  - grep "onload.*initImageMagnifier" R/mod_delcampe_export.R
  - grep 'id = ns(paste0("combined_img_' R/mod_delcampe_export.R

IF_FAIL:
  - Check sprintf syntax: Count opening/closing quotes
  - Verify ns() usage: Should wrap paste0("combined_img_", idx)
  - Test sprintf separately:
      sprintf("initImageMagnifier('%s', 2.5, 200);", "test_id")

ROLLBACK: git checkout R/mod_delcampe_export.R
```

**Checkpoint 2**: Syntax validation
```bash
# Terminal
R -e "source('R/mod_delcampe_export.R')"
# Expected: No errors, just function definitions loaded

# Check line count
wc -l R/mod_delcampe_export.R
# Expected: ~1036 lines (was 1027, +9 lines added)
```

---

### PHASE 3: Validation Testing (45 min)

#### TEST 3.1: Basic Magnifier Functionality
```yaml
TEST: Magnifier appears and tracks mouse

STEPS:
  1. golem::run_dev()
  2. Navigate to "eBay Export" tab
  3. Ensure combined images exist (process cards first if needed)
  4. Click to open first accordion panel
  5. Hover mouse over combined image

EXPECTED:
  - ✅ Circular magnifying lens appears within 100ms
  - ✅ Lens follows cursor smoothly (no lag)
  - ✅ Magnified view shows 2.5x zoom (can read small text)
  - ✅ Lens has white border, circular shape
  - ✅ Lens disappears when mouse leaves image
  - ✅ Cursor changes to crosshair over image

IF_FAIL:
  - Open browser DevTools (F12) → Console tab
  - Look for errors:
      "Image with ID ... not found" → ns() namespace issue
      "initImageMagnifier is not a function" → JS file not loaded
      No errors but no lens → CSS not loaded
  - Check Network tab: Verify image_magnifier.js loaded (200 OK)
  - Inspect image element: Right-click image → Inspect
      Verify id="mod_delcampe_export-combined_img_1" (or similar namespaced ID)

ROLLBACK_TRIGGER: Lens doesn't appear after 3 attempts
```

#### TEST 3.2: Multiple Images (Namespace Test)
```yaml
TEST: Each image has independent magnifier

STEPS:
  1. App running from TEST 3.1
  2. Open first accordion panel → hover over image → verify magnifier works
  3. Close first panel, open second panel → hover → verify magnifier works
  4. Open third panel (if exists) → hover → verify magnifier works
  5. Open browser console (F12) throughout test

EXPECTED:
  - ✅ Each image has unique namespaced ID (combined_img_1, combined_img_2, etc.)
  - ✅ Each image gets its own magnifier instance
  - ✅ No ID conflicts in console
  - ✅ No duplicate lenses appearing
  - ✅ Previous magnifiers properly cleaned up when accordion closes

IF_FAIL:
  - Console errors about duplicate IDs → ns() not applied correctly
  - Multiple lenses on one image → init called multiple times
  - Lens stuck after closing accordion → destroy() not working

ROLLBACK_TRIGGER: Namespace conflicts causing console errors
```

#### TEST 3.3: AI Extraction (Non-Regression - CRITICAL)
```yaml
TEST: AI extraction still works with magnifier active

PRIORITY: ⚠️ CRITICAL - Any failure requires immediate rollback

STEPS:
  1. App running, accordion panel open
  2. Hover over image briefly (activate magnifier)
  3. Click "Extract with AI" button
  4. Wait for extraction to complete (~5-10 seconds)
  5. Observe form fields

EXPECTED:
  - ✅ "Starting AI extraction..." notification appears
  - ✅ Status shows "Extracting with Claude..." (blue banner)
  - ✅ Form fields populate after extraction:
      - Title field fills with AI-generated title
      - Description field fills with AI description
      - Price field updates to AI-recommended price
      - Condition dropdown updates to AI condition
  - ✅ Green success banner shows: "✅ Extraction complete! Price: $X.XX"
  - ✅ Magnifier still works after extraction
  - ✅ No JavaScript errors in console

IF_FAIL:
  🚨 IMMEDIATE ROLLBACK REQUIRED 🚨

  1. Stop app immediately
  2. Execute rollback:
      git checkout R/mod_delcampe_export.R
      rm inst/app/www/image_magnifier.js
      git checkout inst/app/www/styles.css
  3. Restart app and verify AI extraction works without magnifier
  4. Document failure in TASK_PRP/magnifier_failure_log.md:
      - Which fields didn't populate
      - Console error messages
      - Network tab activity during extraction
  5. DO NOT proceed with magnifier until issue resolved

DEBUG_STEPS (only after rollback):
  - Check if magnifier JS has stopPropagation() calls (shouldn't)
  - Verify lens CSS has pointer-events: none
  - Check if magnifier modifies DOM of form elements (shouldn't)
  - Review timing of later::later() call (line 568: delay = 0.1)

ROLLBACK_TRIGGER: Any form field fails to populate after AI extraction
```

#### TEST 3.4: AI Pre-Population (Duplicate Image - CRITICAL)
```yaml
TEST: Pre-population works for duplicate combined images

PRIORITY: ⚠️ CRITICAL - Tests recently fixed timing bug

BACKGROUND:
  - This tests the fix from .serena/memories/ai_ui_population_timing_fix_20251014.md
  - Previously, fields didn't populate due to timing race condition
  - Fix uses later::later(delay = 0.15) at line 326

STEPS:
  1. Process same combined image twice (creates duplicate with existing AI data)
  2. Navigate to eBay Export tab
  3. Click to open accordion panel for duplicate image
  4. Observe form fields (should auto-populate)
  5. Check browser console

EXPECTED:
  - ✅ Green banner appears: "Previous AI extraction loaded (Model: claude-...)"
  - ✅ All form fields populate within 200ms:
      - Title pre-filled
      - Description pre-filled
      - Price pre-filled
      - Condition pre-filled
  - ✅ Button shows "Re-extract with AI" (not "Extract with AI")
  - ✅ Magnifier works normally on pre-populated image
  - ✅ Console shows: "✓ Title populated", "✓ Description populated", etc.
  - ✅ No errors in console

IF_FAIL:
  🚨 CRITICAL BUG - IMMEDIATE ROLLBACK 🚨

  This breaks a recently fixed bug. Rollback immediately:

  1. Stop app
  2. Execute full rollback:
      git checkout R/mod_delcampe_export.R
      rm inst/app/www/image_magnifier.js
      git checkout inst/app/www/styles.css
  3. Test pre-population works without magnifier
  4. Document issue with these details:
      - Console output around line "Delayed update triggered"
      - Whether updateTextAreaInput calls execute
      - Timing measurements (use console.time if needed)
  5. Investigate magnifier JavaScript for timing interference

ROLLBACK_TRIGGER: Fields don't populate OR populate slower than 500ms
```

#### TEST 3.5: Accordion Interactions
```yaml
TEST: Accordion open/close still works normally

STEPS:
  1. App running with magnifier active
  2. Open accordion panel → hover over image (magnifier active)
  3. While hovering, click accordion title to close panel
  4. Open different accordion panel
  5. Repeat 5 times with different panels

EXPECTED:
  - ✅ Accordion panels open/close smoothly (no lag)
  - ✅ Auto-collapse works (only one panel open at a time)
  - ✅ No stuck magnifier lenses after closing panels
  - ✅ New panel's image gets its own magnifier
  - ✅ Clicking accordion title works even during hover
  - ✅ Status badges update correctly

IF_FAIL:
  - Accordion won't close → Check if lens blocks clicks (pointer-events)
  - Stuck lens after close → destroy() method not working
  - Can't click accordion while hovering → z-index conflict

ROLLBACK_TRIGGER: Accordion becomes unresponsive or sluggish
```

#### TEST 3.6: Send to eBay (Complete Workflow)
```yaml
TEST: Full workflow from magnifier to eBay listing

STEPS:
  1. Open accordion panel
  2. Hover over image to inspect with magnifier
  3. Click "Extract with AI" (if not pre-populated)
  4. Review extracted data
  5. Edit any fields if needed
  6. Click "Send to eBay"
  7. Wait for completion

EXPECTED:
  - ✅ Magnifier doesn't interfere with field editing
  - ✅ "Sending to eBay..." notification appears
  - ✅ Status badge changes to "Sending..."
  - ✅ eBay listing created successfully
  - ✅ Success notification: "✅ Listed on eBay! [View Listing]"
  - ✅ Status badge changes to "Sent" (green)
  - ✅ No errors in console
  - ✅ Image appears correctly in eBay listing

IF_FAIL:
  - Listing creation fails → Check if magnifier modified form data
  - Image upload fails → Check if magnifier blocks file access
  - Console errors during send → Check for JavaScript conflicts

ROLLBACK_TRIGGER: Listing creation success rate drops below 95%
```

#### TEST 3.7: Browser Console Check
```yaml
TEST: No JavaScript errors throughout all tests

STEPS:
  1. Open browser DevTools (F12) → Console tab
  2. Clear console (trash icon)
  3. Perform all tests 3.1-3.6 again
  4. Monitor console output continuously

EXPECTED:
  - ✅ No red error messages
  - ℹ️ Expected messages (OK):
      "Image magnifier initialized for: mod_delcampe_export-combined_img_X"
      R/Shiny connection messages
      AI extraction logs
  - ⚠️ Warning messages (review but OK if known):
      Favicon 404 (known issue, harmless)
      Browser extension messages

FORBIDDEN (immediate rollback):
  - ❌ "Uncaught TypeError" related to magnifier
  - ❌ "Image with ID ... not found"
  - ❌ "Cannot read property ... of undefined" in magnifier code
  - ❌ "ResizeObserver loop limit exceeded" (may indicate memory leak)

IF_FAIL:
  - Screenshot all console errors
  - Copy full error stack traces
  - Check Network tab for failed resource loads
  - Execute rollback if errors persist after app restart

ROLLBACK_TRIGGER: Any console errors referencing "magnifier" or "lens"
```

#### TEST 3.8: Performance Test
```yaml
TEST: No performance degradation

STEPS:
  1. Open 5-10 accordion panels in sequence (open, hover, close, repeat)
  2. Rapidly hover over images (move mouse quickly across image)
  3. Open browser DevTools → Performance tab
  4. Click "Record" → perform hovering actions → click "Stop"
  5. Analyze performance profile

EXPECTED:
  - ✅ Magnifier appears with <100ms delay
  - ✅ Mouse tracking smooth (60 FPS target, 30 FPS acceptable)
  - ✅ No frame drops during hover
  - ✅ Memory usage stable (check DevTools → Memory)
  - ✅ No excessive repaints (check Rendering → Paint Flashing)

METRICS:
  | Metric | Target | Acceptable | Failure |
  |--------|--------|------------|---------|
  | Lens appearance | <50ms | <100ms | >200ms |
  | Tracking FPS | 60 FPS | 30 FPS | <30 FPS |
  | Memory per magnifier | <1MB | <5MB | >10MB |
  | CPU during hover | <10% | <25% | >50% |

IF_FAIL:
  - Performance issues → Check mousemove event throttling
  - Memory leaks → Check destroy() called on accordion close
  - High CPU → Review background-position calculation frequency

ROLLBACK_TRIGGER: Noticeable lag or UI freezing during magnifier use
```

**Checkpoint 3**: Core functionality validated
```yaml
GATE: All critical tests must pass before proceeding

REQUIRED_PASSES:
  - ✅ TEST 3.1: Basic magnifier works
  - ✅ TEST 3.2: Multiple images work
  - ✅ TEST 3.3: AI extraction works (CRITICAL)
  - ✅ TEST 3.4: AI pre-population works (CRITICAL)
  - ✅ TEST 3.5: Accordion works
  - ✅ TEST 3.6: Send to eBay works
  - ✅ TEST 3.7: No console errors
  - ✅ TEST 3.8: Performance acceptable

IF_ANY_FAIL: DO NOT PROCEED. Execute rollback and debug separately.
```

---

### PHASE 4: Edge Cases & Polish (30 min)

#### TEST 4.1: Small Images
```yaml
TEST: Magnifier works on images smaller than lens

STEPS:
  1. Process postcard with small image output (<500x500px)
  2. Open accordion panel for small image
  3. Hover over image

EXPECTED:
  - ✅ Magnifier still appears
  - ✅ Shows zoomed detail (even if image is smaller than lens)
  - ✅ Lens constrained to image bounds

IF_FAIL: Document but non-critical (small images are rare)
```

#### TEST 4.2: Very Large Images
```yaml
TEST: Performance on large images

STEPS:
  1. Process postcard with large combined image (>5000x5000px)
  2. Open accordion panel
  3. Hover and move mouse rapidly

EXPECTED:
  - ✅ Magnifier initializes (may take extra ~100ms)
  - ✅ Tracking remains smooth (30+ FPS)
  - ✅ No browser memory warnings

IF_FAIL: Consider reducing max-height in CSS or adding loading indicator
```

#### TEST 4.3: Network Delay Simulation
```yaml
TEST: Magnifier handles slow image loading

STEPS:
  1. Chrome DevTools → Network → Throttling → Slow 3G
  2. Open accordion panel (image loads slowly)
  3. Observe magnifier initialization

EXPECTED:
  - ✅ onload fires only after image fully loaded
  - ✅ Magnifier doesn't appear until image ready
  - ✅ No broken lens or incorrect dimensions

IF_FAIL: onload timing is correct, likely CSS issue
```

#### TEST 4.4: Rapid Accordion Switching
```yaml
TEST: No orphaned lenses

STEPS:
  1. Quickly open panel 1 → panel 2 → panel 3 → panel 1 (rapid clicks)
  2. Hover over images after each switch
  3. Check for multiple lens elements in DOM

EXPECTED:
  - ✅ Only one lens per image
  - ✅ No lens elements orphaned in DOM
  - ✅ No console errors about duplicate initialization

IF_FAIL: Add data-magnifier-initialized attribute check in JS
```

**Checkpoint 4**: Edge cases handled
```yaml
GATE: Edge case failures are non-critical but should be documented

RECOMMENDED_PASSES:
  - ✅ Small images (nice to have)
  - ✅ Large images (should pass)
  - ✅ Network delay (should pass)
  - ✅ Rapid switching (should pass)

IF_FAIL: Document in known issues, proceed unless performance unacceptable
```

---

### PHASE 5: Final Validation & Documentation (15 min)

#### TASK 5.1: Cross-Browser Test
```yaml
TEST: Magnifier works in major browsers

BROWSERS:
  - Chrome (latest) - Primary development browser
  - Firefox (latest) - Secondary
  - Edge (latest) - Secondary

EXPECTED: Magnifier works identically in all browsers

IF_FAIL: Document browser-specific issues, prioritize Chrome/Edge
```

#### TASK 5.2: Create Memory File
```yaml
ACTION: Document implementation in .serena/memories/

FILE: .serena/memories/image_magnifier_implementation_YYYYMMDD.md

CONTENT:
  # Image Magnifier Implementation - [DATE]

  ## Summary
  Successfully implemented hover-activated magnifying glass on combined images
  in the Delcampe Export module (R/mod_delcampe_export.R).

  ## Changes
  - inst/app/www/image_magnifier.js (new, 146 lines)
  - inst/app/www/styles.css (append 61 lines magnifier CSS)
  - R/mod_delcampe_export.R (modified, +9 lines)
      - Line 12-15: Added JavaScript reference in module UI
      - Line 154-162: Added id, class, onload to image tag

  ## Configuration
  - Zoom level: 2.5x (250% magnification)
  - Lens size: 200px diameter
  - Initialization: onload attribute (ensures image loaded)
  - Namespace: Properly uses ns() for module IDs

  ## Testing Results
  - ✅ Basic magnifier functionality: PASS
  - ✅ Multiple images (namespace): PASS
  - ✅ AI extraction workflow: PASS (critical)
  - ✅ AI pre-population: PASS (critical)
  - ✅ Accordion interactions: PASS
  - ✅ Send to eBay workflow: PASS
  - ✅ Browser console: No errors
  - ✅ Performance: Acceptable (<100ms, 30+ FPS)

  ## Known Issues
  - None currently

  ## Future Enhancements (Out of Scope)
  - User-configurable zoom level
  - Keyboard shortcuts
  - Click-to-lock zoom position

  ## Rollback Instructions
  If issues arise:
  1. git checkout R/mod_delcampe_export.R
  2. rm inst/app/www/image_magnifier.js
  3. git checkout inst/app/www/styles.css
  4. Restart app
```

#### TASK 5.3: Update INDEX Memory
```yaml
ACTION: Add entry to .serena/memories/INDEX.md

APPEND:
  - `image_magnifier_implementation_YYYYMMDD.md` - Hover-activated magnifying
    glass on combined images in eBay Export module. Pure UI enhancement, no
    database changes. Files: inst/app/www/image_magnifier.js (new),
    inst/app/www/styles.css (modified), R/mod_delcampe_export.R (modified).
```

---

## Rollback Plan

### Immediate Rollback (<2 minutes)
```bash
# Stop Shiny app (Ctrl+C in R console)

# Execute rollback
git checkout R/mod_delcampe_export.R
rm inst/app/www/image_magnifier.js
git checkout inst/app/www/styles.css

# Restart app
# R Console: golem::run_dev()
```

### Verification After Rollback
```yaml
VERIFY:
  1. App starts without errors
  2. eBay Export tab loads
  3. Accordion panels open/close
  4. AI extraction works
  5. Send to eBay works
  6. No magnifier appears (expected)

IF_VERIFICATION_FAILS:
  - Check git status for uncommitted changes
  - Review recent commits: git log --oneline -5
  - Consider full revert: git reset --hard HEAD~1
```

---

## Success Criteria

### Technical Success (All Required)
- [ ] Magnifier works on all combined images in eBay Export
- [ ] Initialization time <100ms
- [ ] Smooth tracking (30+ FPS minimum)
- [ ] No JavaScript errors in console
- [ ] No CSS conflicts with existing UI
- [ ] No performance degradation
- [ ] All existing features work (non-regression)

### Critical Non-Regression (Zero Tolerance)
- [ ] AI extraction populates fields correctly
- [ ] AI pre-population works for duplicates (within 200ms)
- [ ] Accordion panels open/close normally
- [ ] Send to eBay creates listings successfully
- [ ] Status badges update correctly
- [ ] No console errors related to magnifier

### User Experience
- [ ] Can inspect image details clearly
- [ ] Intuitive hover interaction
- [ ] No workflow disruption
- [ ] Zoom level appropriate (2.5x readable)
- [ ] Professional appearance (white border, smooth)

### Code Quality
- [ ] <200 lines of new code total (JS + CSS + R)
- [ ] No code duplication
- [ ] Clear comments in JavaScript
- [ ] Follows existing patterns
- [ ] Easy to disable (rollback in <2 minutes)

---

## Common Issues & Solutions

### Issue: Magnifier Not Appearing

**Symptoms**: Hover over image, no lens appears

**Debug Steps**:
1. Open browser DevTools (F12) → Console
2. Look for specific errors:
   - "Image with ID ... not found" → Namespace issue
   - "initImageMagnifier is not a function" → JS not loaded

**Solutions**:
```yaml
IF "Image with ID ... not found":
  - Check image element in DOM (right-click → Inspect)
  - Verify ID format: "mod_delcampe_export-combined_img_1"
  - Ensure ns() wraps paste0("combined_img_", idx)

IF "initImageMagnifier is not a function":
  - Open Network tab, refresh page
  - Look for image_magnifier.js request (should be 200 OK)
  - Verify file exists: ls inst/app/www/image_magnifier.js
  - Check file path in tags$script: "www/image_magnifier.js"

IF No errors but no lens:
  - Check Elements tab → head → script tags
  - Verify image_magnifier.js is loaded
  - Check Elements tab → Styles
  - Search for ".magnifier-lens" class (should exist)
  - If missing, CSS didn't load: check styles.css
```

### Issue: Magnifier Position Offset

**Symptoms**: Lens appears offset from cursor

**Debug Steps**:
1. Right-click image → Inspect
2. Check parent container CSS
3. Look for transforms or positioning

**Solutions**:
```yaml
COMMON_CAUSES:
  - Parent container lacks position: relative
  - CSS transform affecting positioning
  - Incorrect z-index layering

FIXES:
  - Ensure parent div has position: relative
  - Check for CSS transforms in parent chain
  - Verify lens z-index: 2000 (higher than other elements)
```

### Issue: AI Extraction Breaks

**Symptoms**: Button clicks but fields don't populate

**THIS IS CRITICAL - IMMEDIATE ROLLBACK REQUIRED**

**Debug Steps**:
1. Stop app immediately
2. Execute rollback (see Rollback Plan above)
3. Test AI extraction without magnifier
4. Document the failure

**Investigation** (only after rollback):
```yaml
CHECK:
  1. Does magnifier JavaScript have stopPropagation()?
     - Search image_magnifier.js for "stopPropagation"
     - Should be NONE found

  2. Does lens element block form fields?
     - Check CSS: lens should have "pointer-events: none"
     - Verify lens z-index doesn't cover form

  3. Timing interference with later::later()?
     - Check R/mod_delcampe_export.R line 568
     - Delay should be 0.1 (100ms)
     - Magnifier shouldn't affect timing

  4. DOM modification?
     - Magnifier should only add/remove lens element
     - Should NOT touch form input elements
     - Check image_magnifier.js lines 98-105 (destroy method)
```

### Issue: Accordion Won't Close

**Symptoms**: Click accordion title, nothing happens

**Debug Steps**:
1. Inspect lens element in DOM
2. Check computed CSS: pointer-events
3. Try clicking while not hovering

**Solutions**:
```yaml
IF clicking_fails_during_hover:
  - Lens blocks clicks → Check CSS pointer-events: none
  - Fix: Add to styles.css:
      .magnifier-lens {
        pointer-events: none !important;
      }

IF lens_stuck_after_close:
  - destroy() not working → Check JavaScript
  - Verify lens removed from DOM
  - Add explicit cleanup in accordion close observer
```

### Issue: Multiple Lenses on One Image

**Symptoms**: 2+ lenses appear when hovering

**Debug Steps**:
1. Open Elements tab
2. Search for class "magnifier-lens"
3. Count how many lens elements exist

**Solutions**:
```yaml
CAUSE: initImageMagnifier() called multiple times

FIX_OPTIONS:
  1. Add initialization guard in JavaScript:
     if (img.dataset.magnifierInitialized === 'true') return;
     img.dataset.magnifierInitialized = 'true';

  2. Call destroy() before re-initialization:
     if (img._magnifier) img._magnifier.destroy();

  3. Use unique lens ID to prevent duplicates:
     lens.id = `magnifier-lens-${imageId}`;
```

### Issue: Memory Leak (Performance Degradation)

**Symptoms**: App slows down after many open/close operations

**Debug Steps**:
1. Chrome DevTools → Performance
2. Record while opening/closing panels 10 times
3. Check Memory tab for increasing usage

**Solutions**:
```yaml
INVESTIGATE:
  - Are event listeners cleaned up?
  - Is destroy() method called?
  - Are lens elements removed from DOM?

FIX:
  1. Ensure destroy() removes all event listeners:
     img.removeEventListener('mousemove', moveMagnifier)
     img.removeEventListener('mouseenter', ...)
     img.removeEventListener('mouseleave', ...)

  2. Call destroy on accordion panel close:
     observeEvent(input$export_accordion, {
       # When panel closes, cleanup magnifier
     })

  3. Use weak references if possible
```

---

## Files Modified Summary

### inst/app/www/image_magnifier.js
- **Action**: CREATE (new file)
- **Lines**: 146
- **Source**: Copy from reference/image_magnifier.js
- **Purpose**: Magnifying glass JavaScript logic
- **Key Functions**:
  - `initImageMagnifier(imageId, zoomLevel, lensSize)`
  - `destroy()` method for cleanup
  - Auto-initialization via data attributes
  - Shiny custom message handlers

### inst/app/www/styles.css
- **Action**: MODIFY (append)
- **Lines Added**: 61 (from ~100 lines to ~161 lines)
- **Source**: Append from reference/magnifier_styles.css
- **Purpose**: Magnifier lens styling
- **Key Classes**:
  - `.magnifier-lens` - Circular lens with border
  - `.magnifiable-image-container` - Container with crosshair cursor
  - Optional theme variants (mint, coral)

### R/mod_delcampe_export.R
- **Action**: MODIFY (minimal changes)
- **Lines Modified**: 9 (5 new, 4 modified)
- **Original Size**: 1027 lines
- **New Size**: ~1036 lines
- **Changes**:
  - **Lines 12-15**: Added `tags$head()` with JavaScript reference
  - **Lines 154-162**: Modified `tags$img()` to add:
    - `id = ns(paste0("combined_img_", idx))`
    - `class = "magnifiable-image"`
    - `onload = sprintf(...)` with magnifier initialization

**Note**: Module remains over 400-line limit (1036 lines) - consider splitting in future (separate task)

---

## Next Steps After Implementation

1. **Monitor Production**: Watch for any user reports of issues
2. **Gather Feedback**: Ask users if zoom level (2.5x) is appropriate
3. **Consider Enhancements**:
   - User-configurable zoom via slider
   - Keyboard shortcuts (Z to toggle)
   - Magnifier on thumbnail images in accordion titles
4. **Module Splitting**: R/mod_delcampe_export.R is 1036 lines (over 400 limit)
   - Consider splitting into:
     - `mod_delcampe_export_ui.R` - UI only
     - `mod_delcampe_export_server.R` - Server logic
     - `mod_delcampe_export_helpers.R` - Helper functions

---

## References

### Documentation
- `reference/MAGNIFYING_GLASS_IMPLEMENTATION.md` - Complete implementation guide
- `reference/magnifier_r_examples.R` - 10 integration pattern examples
- `.serena/memories/ai_ui_population_timing_fix_20251014.md` - Critical timing bug fix
- `.serena/memories/accordion_success_20251010.md` - Accordion implementation
- `CLAUDE.md` - Lines 142-151: Module namespace rules

### Code Files
- `reference/image_magnifier.js` - Production-ready JavaScript (146 lines)
- `reference/magnifier_styles.css` - Complete CSS styles (61 lines)
- `R/mod_delcampe_export.R` - Target module (1027 lines currently)

### Testing Resources
- Chrome DevTools: F12 → Console, Network, Performance tabs
- Network throttling: Chrome DevTools → Network → Slow 3G
- Performance profiling: Chrome DevTools → Performance → Record

---

## Appendix: Technical Specifications

### Magnifier Configuration

```yaml
Zoom Level: 2.5
  - Meaning: 250% magnification
  - Reasoning: Balance between detail and usability
  - Range: 1.5 - 5 (configurable in JavaScript)
  - Adjustment: Change second parameter in initImageMagnifier()

Lens Size: 200px
  - Meaning: Circular lens diameter
  - Reasoning: Large enough to see context, small enough not to obscure
  - Range: 100 - 300px (configurable in JavaScript)
  - Adjustment: Change third parameter in initImageMagnifier()

Initialization: onload attribute
  - Why: Ensures image fully loaded before magnifier
  - Alternative: DOMContentLoaded (less reliable with dynamic content)
  - Critical for: Correct dimension calculations

Namespace Handling: ns() wrapper
  - Why: Shiny modules require namespaced IDs
  - Format: "mod_delcampe_export-combined_img_1"
  - Without: "combined_img_1" (would fail in module context)
```

### CSS Specifications

```css
/* Lens positioning */
.magnifier-lens {
  position: absolute;      /* Required for cursor tracking */
  z-index: 2000;          /* Above all other elements */
  pointer-events: none;   /* CRITICAL: Don't block clicks */
}

/* Cursor indication */
.magnifiable-image-container {
  cursor: crosshair;      /* Indicates magnifiable */
}
```

### JavaScript Architecture

```javascript
// Core function
initImageMagnifier(imageId, zoomLevel, lensSize)
  ├─ Validates image element exists
  ├─ Creates lens element
  ├─ Attaches event listeners (mouseenter, mouseleave, mousemove)
  ├─ Returns object with methods:
  │   ├─ destroy() - Cleanup
  │   ├─ setZoom(newZoom) - Dynamic zoom
  │   └─ setLensSize(newSize) - Dynamic size
  └─ Handles touch events for mobile (bonus)

// Shiny integration
Shiny.addCustomMessageHandler('initMagnifier', ...)
  - Server can trigger magnifier programmatically
  - Currently unused (using onload instead)
```

---

**END OF TASK PRP**

**Total Estimated Time**: 2 hours (10 + 20 + 45 + 30 + 15 minutes)
**Risk Level**: Medium-High (simple code, but critical non-regression requirements)
**Complexity**: Medium (straightforward implementation, but requires careful testing)

**CRITICAL REMINDER**: If ANY existing functionality breaks during testing, IMMEDIATELY execute the rollback plan. Do not attempt to "fix forward" - rollback first, debug separately, then re-implement.
