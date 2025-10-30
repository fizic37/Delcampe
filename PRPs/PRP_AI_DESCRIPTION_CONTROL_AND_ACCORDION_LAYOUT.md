# PRP: AI Description Control and Accordion Layout Improvements

**Status**: Ready for Implementation
**Priority**: Medium
**Created**: 2025-10-30
**Estimated Effort**: 3-4 hours

## Context

The AI extraction feature currently always generates and populates the description field. However, users may prefer to use a standard description template instead of AI-generated content. Additionally, the accordion layout needs optimization:

- AI description is always fetched (no user control)
- No option for standard template-based description
- Accordion layout doesn't use full page width
- Combined images order isn't prioritized

## Problem Statement

Users need:
1. **Control over AI description**: Option to fetch AI description or use standard template
2. **Template-based description**: Pre-formatted shipping info when AI is disabled
3. **Better layout**: Full-width accordions for optimal space usage
4. **Logical ordering**: Lot cards combined images should appear first

## Success Criteria

- [ ] Checkbox added to control AI description fetching (default: unchecked)
- [ ] When unchecked: Description uses title + standard template
- [ ] When checked: AI fetches and populates description (current behavior)
- [ ] Accordions use full page width (column width 12)
- [ ] Lot cards combined images appear first in accordion order
- [ ] Standard template includes shipping rates and terms

## Technical Requirements

### 1. AI Description Control Checkbox

**Current State**:
- AI extraction always fetches description
- No user control over description generation
- Description field always populated by AI

**Required Changes**:

**R/mod_delcampe_export.R** - Add checkbox in AI controls section (around line 173):

```r
# In the AI Assistant section, after the model selector
column(
  6,
  div(
    style = "padding: 16px; background: #f1f3f5; border-radius: 6px; border-left: 4px solid #4c6ef5; height: 100%;",
    h5(icon("robot"), " AI Assistant", style = "margin-top: 0;"),

    selectInput(
      ns(paste0("ai_model_", idx)),
      "Model",
      choices = c("Claude" = "claude", "GPT-4" = "gpt4"),
      selected = "claude",
      width = "100%"
    ),

    # NEW: Checkbox for description control
    checkboxInput(
      ns(paste0("fetch_ai_description_", idx)),
      "Fetch AI description",
      value = FALSE  # Default: unchecked (don't fetch)
    ),

    uiOutput(ns(paste0("ai_button_", idx)))
  )
)
```

### 2. Conditional Description Logic

**Required Changes**:

**R/mod_delcampe_export.R** - Update AI extraction handler (around line 847):

```r
observeEvent(input[[paste0("extract_ai_", i)]], ignoreNULL = TRUE, ignoreInit = TRUE, {

  # Get checkbox state
  fetch_description <- input[[paste0("fetch_ai_description_", i)]] %||% FALSE

  cat("🎯 Extract AI button clicked for image", i, "\n")
  cat("   Fetch description:", fetch_description, "\n")

  # ... existing path and model selection code ...

  later::later(function() {
    tryCatch({

      # ... existing AI API call code ...

      if (result$success) {
        parsed <- parse_enhanced_ai_response(result$data)

        # Always update title
        shiny::updateTextAreaInput(
          session,
          paste0("item_title_", i),
          value = parsed$title
        )

        # CONDITIONAL: Update description based on checkbox
        if (fetch_description) {
          # AI-generated description
          shiny::updateTextAreaInput(
            session,
            paste0("item_description_", i),
            value = parsed$description
          )
          cat("   ✅ Using AI-generated description\n")
        } else {
          # Template-based description
          template_description <- build_template_description(parsed$title)
          shiny::updateTextAreaInput(
            session,
            paste0("item_description_", i),
            value = template_description
          )
          cat("   ✅ Using template description\n")
        }

        # Update other fields (price, condition, etc.)
        # ... existing code ...

      }

    }, error = function(e) {
      # ... existing error handling ...
    })
  }, delay = 0.1)
})
```

### 3. Template Description Builder

**Required Changes**:

**R/mod_delcampe_export.R** - Add helper function (around line 130, before module server):

```r
#' Build template description from title and standard text
#' @param title Character string with extracted title
#' @return Character string with formatted description
build_template_description <- function(title) {

  # Standard shipping and terms text
  standard_text <- paste(
    "THIS ITEM IS SOLD AS IT IS PLEASE LOOK CAREFULLY AT THE PHOTOS!!!",
    "All items are part of my private collection.",
    "Your satisfaction is guaranteed, full refund if the item is not as described.",
    "",
    "AT THE MOMENT ROMANIAN POST DOES NOT SEND ITEMS IN UKRAINE, BELARUS AND RUSSIAN FEDERATION",
    "SO I WILL NOT BE ABLE TO COMPLETE ORDERS FROM THIS COUNTRIES UNLESS YOU HAVE A SECOND SHIPPING ADDRESS IN OTHER COUNTRY.",
    "",
    "",
    "Shipping rates worldwide (economy, not registered):",
    "",
    " 50 - 100g     - 4$",
    "100 - 500g    - 7$",
    "500 - 1000g  - 10$",
    "",
    "For registered shipping there is an extra 2$ to be added.",
    "If you want registered shipping, please let me know after the auction is finished.",
    "I am not responsible for any items lost or stolen in shipments that are not registered.",
    sep = "\n"
  )

  # Concatenate title + standard text
  description <- paste(title, standard_text, sep = "\n\n")

  return(description)
}
```

**Alternative Implementation** (if standard text should be a constant):

```r
# Define at module level (outside server function)
STANDARD_DESCRIPTION_TEMPLATE <- "THIS ITEM IS SOLD AS IT IS PLEASE LOOK CAREFULLY AT THE PHOTOS!!! - All items are part of my private collection. Your satisfaction is guaranteed, full refund if the item is not as described.

AT THE MOMENT ROMANIAN POST DOES NOT SEND ITEMS IN UKRAINE, BELARUS AND RUSSIAN FEDERATION SO I WILL NOT BE ABLE TO COMPLETE ORDERS FROM THIS COUNTRIES UNLESS YOU HAVE A SECOND SHIPPING ADDRESS IN OTHER COUNTRY.


Shipping rates worldwide (economy, not registered):


 50 - 100g     - 4$
100 - 500g    - 7$
500 - 1000g  - 10$

For registered shipping there is an extra 2$ to be added. If you want registered shipping, please let me know after the auction is finished. I am not responsible for any items lost or stolen in shipments that are not registered."

#' Build template description
build_template_description <- function(title) {
  paste(title, STANDARD_DESCRIPTION_TEMPLATE, sep = "\n\n")
}
```

### 4. Accordion Full Width Layout

**Current State**:
- Accordions may not use full page width
- Combined images might be in constrained columns

**Required Changes**:

**R/mod_delcampe_export.R** - Update accordion container (search for accordion creation):

```r
# Ensure accordion container uses full width
div(
  class = "container-fluid",  # Use fluid container for full width
  style = "padding: 0; margin: 0;",

  # Create accordion with full-width items
  bslib::accordion(
    id = ns("export_accordion"),
    open = NULL,
    multiple = TRUE,

    # Create accordion panels from image paths
    # Each panel should use col-12 for full width
    lapply(seq_along(rv$image_paths), function(idx) {
      create_accordion_panel(idx, rv$image_paths[idx])
    })
  )
)
```

**Update individual accordion panels to use col-12**:

```r
create_accordion_panel <- function(idx, image_path) {
  bslib::accordion_panel(
    title = get_panel_title(idx, image_path),
    value = as.character(idx),

    # Use full-width container
    div(
      class = "row",
      column(
        12,  # Full width
        create_form_content(idx, image_path)
      )
    )
  )
}
```

### 5. Lot Cards First Ordering

**Current State**:
- Combined images may appear in arbitrary order
- Lot cards might not be prioritized

**Required Changes**:

**R/mod_delcampe_export.R** - Add image sorting function:

```r
#' Sort images so lot cards combined images appear first
#' @param image_paths Character vector of image paths
#' @return Sorted character vector
sort_images_lot_first <- function(image_paths) {

  # Identify lot card images (containing "lot" in path)
  is_lot <- grepl("lot.*combined", image_paths, ignore.case = TRUE)

  # Separate lot and non-lot images
  lot_images <- image_paths[is_lot]
  other_images <- image_paths[!is_lot]

  # Concatenate: lot images first, then others
  sorted_paths <- c(lot_images, other_images)

  cat("📋 Image ordering:\n")
  cat("   Lot images:", length(lot_images), "\n")
  cat("   Other images:", length(other_images), "\n")

  return(sorted_paths)
}
```

**Apply sorting when setting image paths**:

```r
# When setting rv$image_paths (find where this happens)
rv$image_paths <- sort_images_lot_first(combined_image_paths)
```

**Alternative: Sort by filename pattern**:

```r
sort_images_lot_first <- function(image_paths) {

  # Define priority order
  priority_order <- data.frame(
    path = image_paths,
    order = sapply(image_paths, function(path) {
      if (grepl("lot.*card.*combined", path, ignore.case = TRUE)) return(1)  # Lot cards first
      if (grepl("combined", path, ignore.case = TRUE)) return(2)              # Other combined
      return(3)                                                                # Everything else
    }),
    stringsAsFactors = FALSE
  )

  # Sort by priority order
  priority_order <- priority_order[order(priority_order$order), ]

  return(priority_order$path)
}
```

## Implementation Steps

### Phase 1: Checkbox and Template Description (1.5 hours)

1. Add `fetch_ai_description_` checkbox to AI controls section
2. Create `build_template_description()` helper function
3. Update AI extraction handler to check checkbox state
4. Implement conditional description logic
5. Test with checkbox checked and unchecked

**Verification**:
- Checkbox appears in UI
- Default state is unchecked
- Checking enables AI description
- Unchecking uses template description

### Phase 2: Full Width Accordion Layout (0.5 hours)

1. Update accordion container to use `container-fluid`
2. Ensure all accordion panels use `column(12, ...)`
3. Remove any width constraints on accordion items
4. Test responsive behavior

**Verification**:
- Accordions span full page width
- No horizontal scrolling needed
- Layout looks clean on various screen sizes

### Phase 3: Lot Cards First Ordering (1 hour)

1. Create `sort_images_lot_first()` helper function
2. Identify where `rv$image_paths` is set
3. Apply sorting before setting paths
4. Add logging to verify order
5. Test with multiple image types

**Verification**:
- Lot card combined images appear first
- Other combined images follow
- Individual images appear last
- Order is consistent across sessions

### Phase 4: Testing and Polish (1 hour)

1. Test complete workflow with real data
2. Verify template formatting looks good
3. Test checkbox state persistence (if needed)
4. Test with different image combinations
5. Run critical tests: `source("dev/run_critical_tests.R")`

## Testing Checklist

### AI Description Control
- [ ] Checkbox appears in AI controls section
- [ ] Default state is unchecked
- [ ] Checkbox can be toggled before extraction
- [ ] When unchecked: Description = Title + Template
- [ ] When checked: Description = AI-generated content
- [ ] Template text formatting is correct
- [ ] Title extraction works regardless of checkbox state

### Layout
- [ ] Accordions use full page width (no side margins)
- [ ] All form fields are properly aligned
- [ ] No horizontal scrolling required
- [ ] Layout is responsive on mobile/tablet
- [ ] Images display correctly at full width

### Ordering
- [ ] Lot card combined images appear first
- [ ] Other combined images follow
- [ ] Individual images appear last
- [ ] Order is consistent across page refreshes
- [ ] Logging shows correct sort order

### Integration
- [ ] AI extraction still works as expected
- [ ] Form submission includes correct description
- [ ] eBay listing creation uses correct description
- [ ] No console errors
- [ ] No breaking changes to existing functionality

## Files to Modify

1. **R/mod_delcampe_export.R**
   - Add `build_template_description()` helper (around line 130)
   - Add `sort_images_lot_first()` helper (around line 140)
   - Add checkbox in AI controls UI (around line 173)
   - Update AI extraction handler with conditional logic (around line 847)
   - Apply image sorting where `rv$image_paths` is set
   - Update accordion container for full width
   - Ensure panels use `column(12, ...)`

2. **tests/testthat/test-mod_delcampe_export.R** (create if needed)
   - Test `build_template_description()` output format
   - Test `sort_images_lot_first()` ordering logic
   - Test checkbox state affects description
   - Test full-width layout rendering

## Standard Description Template

```
{TITLE}

THIS ITEM IS SOLD AS IT IS PLEASE LOOK CAREFULLY AT THE PHOTOS!!! - All items are part of my private collection. Your satisfaction is guaranteed, full refund if the item is not as described.

AT THE MOMENT ROMANIAN POST DOES NOT SEND ITEMS IN UKRAINE, BELARUS AND RUSSIAN FEDERATION SO I WILL NOT BE ABLE TO COMPLETE ORDERS FROM THIS COUNTRIES UNLESS YOU HAVE A SECOND SHIPPING ADDRESS IN OTHER COUNTRY.


Shipping rates worldwide (economy, not registered):


 50 - 100g     - 4$
100 - 500g    - 7$
500 - 1000g  - 10$

For registered shipping there is an extra 2$ to be added. If you want registered shipping, please let me know after the auction is finished. I am not responsible for any items lost or stolen in shipments that are not registered.
```

## Edge Cases & Considerations

### Empty Title
**Issue**: If AI fails to extract title, template will start with empty line
**Solution**: Use fallback title "Vintage Postcard" if title is empty

```r
build_template_description <- function(title) {
  # Use fallback if title is empty
  if (is.null(title) || trimws(title) == "") {
    title <- "Vintage Postcard"
  }

  paste(title, STANDARD_DESCRIPTION_TEMPLATE, sep = "\n\n")
}
```

### Checkbox State Persistence
**Issue**: Should checkbox state persist between extractions?
**Solution**: Default to unchecked for each new image (conservative approach)
**Alternative**: Use reactive value to persist state across images in session

### Multiple Languages
**Issue**: Template is in English, may need localization
**Solution**: Phase 2 enhancement - add language selector
**Current**: Keep English template (international eBay standard)

### Template Customization
**Issue**: Users may want to customize template
**Solution**: Phase 2 enhancement - add settings UI for template editing
**Current**: Use hard-coded template (covers most use cases)

### Image Order Ambiguity
**Issue**: Multiple "lot" images - which comes first?
**Solution**: Sort alphabetically within priority groups

```r
sort_images_lot_first <- function(image_paths) {
  priority_order <- data.frame(
    path = image_paths,
    priority = sapply(image_paths, function(path) {
      if (grepl("lot.*card.*combined", path, ignore.case = TRUE)) return(1)
      if (grepl("combined", path, ignore.case = TRUE)) return(2)
      return(3)
    }),
    stringsAsFactors = FALSE
  )

  # Sort by priority first, then alphabetically within priority
  priority_order <- priority_order[order(priority_order$priority, priority_order$path), ]
  return(priority_order$path)
}
```

## Success Metrics

- ✅ Users can control AI description generation
- ✅ Template description is properly formatted with shipping info
- ✅ Default behavior (unchecked) uses template
- ✅ AI description works when explicitly enabled
- ✅ Accordions use full page width for better space utilization
- ✅ Lot cards combined images consistently appear first
- ✅ No regression in existing functionality
- ✅ Critical tests pass

## Dependencies

- Existing: bslib (accordion), shiny (UI components)
- No new packages required
- Backward compatible with existing module

## Risk Assessment

**Low Risk**:
- Changes are additive (don't break existing functionality)
- Checkbox provides explicit user control
- Template is static (predictable behavior)
- Layout changes are CSS/structure only
- Image sorting is deterministic

**Medium Risk**:
- Template text needs to match user's exact formatting preferences
- Order detection logic depends on filename patterns
- Full-width layout may affect mobile rendering

**Testing Priority**: Medium - Test checkbox states thoroughly, verify template formatting

## Future Enhancements

### Phase 2: Template Customization
- Add settings UI for editing description template
- Support multiple templates (eBay, Delcampe, etc.)
- Allow template variables: {TITLE}, {PRICE}, {CONDITION}

### Phase 3: Multi-Language Templates
- Add language selector to settings
- Support multiple template languages
- Auto-detect language from postcard content

### Phase 4: Smart Template Selection
- Auto-select template based on listing platform
- Different templates for different postcard types
- AI-generated template customization

### Phase 5: Advanced Ordering
- User-configurable image order
- Drag-and-drop reordering UI
- Save ordering preferences

## Rollback Plan

If issues arise:

1. **Checkbox issues**: Remove checkbox, revert to always fetching AI description
   ```bash
   git checkout HEAD~1 -- R/mod_delcampe_export.R
   ```

2. **Template formatting issues**: Adjust `STANDARD_DESCRIPTION_TEMPLATE` constant

3. **Layout issues**: Remove `container-fluid`, revert to default Bootstrap columns

4. **Ordering issues**: Remove `sort_images_lot_first()` call, use original order

No database changes required - all changes are UI/logic only.

## Acceptance Criteria

Implementation is complete when:

1. ✅ Checkbox added to AI controls for description fetching
2. ✅ Default checkbox state is unchecked
3. ✅ When unchecked: Description = Title + Standard Template
4. ✅ When checked: Description = AI-generated content
5. ✅ Standard template includes all required shipping text
6. ✅ Accordions use full page width (col-12)
7. ✅ Lot cards combined images appear first
8. ✅ Other combined images follow lot cards
9. ✅ Image ordering is consistent
10. ✅ No console errors or warnings
11. ✅ Critical tests pass: `source("dev/run_critical_tests.R")`
12. ✅ Manual testing with 5+ images confirms correct behavior
13. ✅ Documentation updated in `.serena/memories/`

---

## Implementation Notes

- **Conservative defaults**: Checkbox unchecked by default (use template)
- **User control**: Explicit opt-in for AI description
- **Template consistency**: Hard-coded template ensures consistent formatting
- **Layout optimization**: Full-width accordions improve space usage
- **Logical ordering**: Lot cards first improves user workflow
- **No breaking changes**: Existing extraction logic preserved
- **Backward compatible**: Works with existing database and UI code

## Related Documentation

- `.serena/memories/ai_extraction_integration_complete_20251010.md` - AI extraction implementation
- `.serena/memories/accordion_ai_integration_verified_20251010.md` - Accordion integration
- `CLAUDE.md` - Module design principles and constraints
