# Serena Memories Index

This directory contains persistent context and solutions for the Delcampe project. Future LLM assistants should read these files to understand previous work and avoid re-solving problems.

## Quick Navigation

### Project Overview
- **project_purpose_and_overview.md** - What this app does and why
- **tech_stack_and_architecture.md** - Technologies, structure, and constraints

### Development Guidelines
- **code_style_and_conventions.md** - Coding standards
- **task_completion_procedures.md** - How to complete tasks properly
- **suggested_commands.md** - Useful commands and workflows

### Solutions & Fixes
- **draggable_lines_coordinate_fix.md** - ⭐ Coordinate mapping solution (2025-01-06)
  - Problem: Draggable lines offset from crop boundaries
  - Solution: JavaScript rewrite with proper coordinate systems
  - Status: ✅ COMPLETE AND TESTED
- **shownotification_type_error_fix.md** - ⭐ Process Combined Images fix (2025-10-06)
  - Problem: 'arg' should be one of "default", "message", "warning", "error"
  - Solution: Fixed notification types + implemented Python function call
  - Status: ✅ COMPLETE AND TESTED
- **genai_integration_fix_20251007.md** - ⭐ GenAI image analysis fix (2025-10-07)
  - Problem: GenAI errors + no model selection in UI
  - Solution: Connected real API calls + added model selector dropdown
  - Status: ✅ COMPLETE - READY FOR TESTING
- **llm_settings_fix_complete_20251009.md** - ⭐ LLM Settings UI visibility fix (2025-10-09)
  - Problem: LLM Models tab not visible in Settings menu
  - Solution: Changed user role from "user" to "admin" in app_server.R
  - Status: ✅ COMPLETE AND TESTED
- **llm_modal_fix_20251009.md** - ⭐ LLM Modal dialog fix (2025-10-09)
  - Problem: Modal showing "no model configured" and default model not pre-selected
  - Solution: Created missing get_llm_config() function in ai_api_helpers.R
  - Status: ✅ COMPLETE AND TESTED

### Analysis & Progress
- **existing_module_analysis.md** - Module structure analysis
- **decomposition_progress_summary.md** - Refactoring progress
- **critical_constraints_preservation.md** - Things that must not change

## File Relationships

```
project_purpose_and_overview.md
    ↓
tech_stack_and_architecture.md
    ↓
    ├──→ draggable_lines_coordinate_fix.md (specific solution)
    └──→ code_style_and_conventions.md (how to write code)
```

## When to Read What

### Starting a new task?
1. Read `project_purpose_and_overview.md` - Understand the goal
2. Read `tech_stack_and_architecture.md` - Know the constraints
3. Read `code_style_and_conventions.md` - Follow standards

### Fixing a bug?
1. Check `draggable_lines_coordinate_fix.md` - Is it related to coordinates?
2. Check `critical_constraints_preservation.md` - What can't be changed?
3. Read related module analysis in `existing_module_analysis.md`

### Adding a feature?
1. Read `tech_stack_and_architecture.md` - Understand architecture
2. Read `decomposition_progress_summary.md` - Know current state
3. Follow `task_completion_procedures.md` - Do it right

### Debugging coordinate issues?
1. **READ FIRST**: `draggable_lines_coordinate_fix.md` 
2. Run tests: `tests/manual/verify_fix.R`
3. Check console logs as described in the fix document

## Critical Files (Don't Miss These!)

### 🔴 Must Read Before Any Changes
- **critical_constraints_preservation.md** - Violations will break the app
- **tech_stack_and_architecture.md** - Core architecture decisions

### 🟡 Read Before Module Changes
- **draggable_lines_coordinate_fix.md** - If touching mod_postal_card_processor
- **existing_module_analysis.md** - Module structure details

### 🟢 Reference as Needed
- **code_style_and_conventions.md** - For coding questions
- **suggested_commands.md** - For workflow questions

## Solution Registry

Track of all major solutions implemented:

| Date | Problem | Solution File | Status | Tests |
|------|---------|---------------|--------|-------|
| 2025-01-06 | Draggable lines coordinate mapping | draggable_lines_coordinate_fix.md | ✅ Complete | tests/testthat/test-mod_postal_card_processor.R |
| 2025-10-06 | showNotification type error | shownotification_type_error_fix.md | ✅ Complete | Manual testing |
| 2025-10-07 | "Start Over" button not functional | start_over_button_implementation.md | ✅ Complete | Manual testing |
| 2025-10-07 | GenAI image analysis error + missing model selection | genai_integration_fix_20251007.md | ✅ Complete | Manual testing |
| 2025-10-07 | LLM Settings UI not visible | llm_settings_incomplete_20251007.md | ⚠️ INCOMPLETE | Documented problem |
| 2025-10-09 | LLM Settings UI visibility fix | llm_settings_fix_complete_20251009.md | ✅ Complete | Manual testing |
| 2025-10-09 | LLM Modal dialog fix (no model configured) | llm_modal_fix_20251009.md | ✅ Complete | Manual testing |
| 2025-10-09 | AI Extraction Feature - Complete Implementation | ai_extraction_complete_20251009.md | ✅ Complete | Manual testing |
| 2025-10-09 | Six Enhancement Tasks (4 of 6 complete) | six_enhancements_complete_20251009.md | ⚠️ Partial (4/6) | Manual testing |
| 2025-10-09 | AI Notification Enhancement - Better Progress Feedback | ai_notification_enhancement_20251009.md | ✅ IMPLEMENTED | Ready to test |
| 2025-10-09 | AI Notification Implementation Complete | ai_notification_implementation_20251009.md | ✅ Complete | User testing needed |
| 2025-10-09 | AI Notification Granular Messages Update | ai_notification_granular_20251009.md | ✅ Enhanced | 14 status messages |
| 2025-10-10 | API Keys Storage + UI Layout Fix | api_keys_and_ui_fix_complete_20251010.md | ✅ Complete | Production ready |
| 2025-10-10 | Right Panel Layout - Non-blocking UI | panel_layout_implementation_20251010.md | ✅ Implemented | Ready for testing |

## Adding New Solutions

When implementing a major fix or feature:

1. **Create a memory file** in this directory:
   ```
   <descriptive_name>_<date>.md
   ```

2. **Include these sections**:
   - Problem Statement
   - Root Cause Analysis
   - Solution Overview
   - Technical Details
   - Files Modified
   - Testing Instructions
   - Success Metrics
   - Related Components
   - Key Learnings

3. **Update this index**:
   - Add to Solution Registry table
   - Update Quick Navigation if major
   - Update "When to Read What" if relevant

4. **Reference in other files**:
   - Update `tech_stack_and_architecture.md`
   - Add constraints to `critical_constraints_preservation.md` if needed
   - Update module analysis if relevant

5. **Create tests**:
   - Add automated tests in `tests/testthat/`
   - Add manual verification in `tests/manual/`
   - Document test procedures in solution file

## Search Tips for Future LLMs

### Finding Coordinate Mapping Info
Search for: "coordinate", "draggable", "object-fit", "bounds", "offset"
→ Points to: `draggable_lines_coordinate_fix.md`

### Finding Python Integration Info
Search for: "reticulate", "python", "extract_postcards"
→ Points to: `tech_stack_and_architecture.md`, `critical_constraints_preservation.md`

### Finding Module Structure Info
Search for: "module", "golem", "server", "ui"
→ Points to: `existing_module_analysis.md`, `tech_stack_and_architecture.md`

### Finding Coding Standards
Search for: "style", "convention", "naming"
→ Points to: `code_style_and_conventions.md`

## Maintenance Guidelines

### Monthly Review
- [ ] Check if any solutions are outdated
- [ ] Update status of ongoing work
- [ ] Archive completed decomposition notes
- [ ] Verify all tests still pass

### When Refactoring
- [ ] Update affected solution files
- [ ] Update module analysis
- [ ] Add migration notes if breaking changes
- [ ] Update tests to match new structure

### When Adding Dependencies
- [ ] Document in `tech_stack_and_architecture.md`
- [ ] Note any version constraints
- [ ] Update `DESCRIPTION` file
- [ ] Test compatibility with existing code

## Version History

| Version | Date | Changes | Author Context |
|---------|------|---------|----------------|
| 1.0 | 2025-01-06 | Initial memories structure created | Claude (Anthropic) |
| 1.1 | 2025-01-06 | Added draggable_lines_coordinate_fix.md | Claude (Anthropic) |
| 1.2 | 2025-01-06 | Reorganized tests to Golem structure | Claude (Anthropic) |

## Notes for Future LLMs

### Communication Style
The user prefers:
- Clear, technical explanations
- Visual diagrams when helpful
- Complete, tested solutions
- Comprehensive documentation
- R and Python expertise

### Project Preferences
- Golem framework for R Shiny structure
- Test-driven approach with testthat
- Persistent documentation in .serena/memories/
- Manual verification scripts alongside automated tests
- Console logging for debugging

### Known Working Patterns
1. **JavaScript-R Integration**: Use Shiny.setInputValue with priority: 'event'
2. **Coordinate Conversion**: Always account for CSS layout (object-fit, padding)
3. **Python Integration**: Never modify reticulate setup, use existing functions
4. **Testing**: Both automated (testthat) and manual (verification scripts)
5. **Documentation**: Technical details in memories/, quick guides in root

## Related Documentation Outside This Directory

- **Root level**:
  - `COORDINATE_FIX_SUMMARY.md` - Complete technical reference
  - `IMPLEMENTATION_GUIDE.md` - Quick start for testing
  - `README.md` - Project overview (if exists)

- **Tests**:
  - `tests/README.md` - Test structure and usage
  - `tests/testthat/test-mod_postal_card_processor.R` - Automated tests
  - `tests/manual/verify_fix.R` - System verification

- **Dev**:
  - `dev/01_start.R` - Project initialization
  - `dev/02_dev.R` - Development workflow
  - `dev/run_dev.R` - Run development version

## Emergency Contacts (Code Patterns)

### If Coordinates Are Wrong
```javascript
// Check in browser console:
img = document.querySelector('[id$="preview_image"]');
console.log('Original:', img.getAttribute('data-original-width'), 'x', img.getAttribute('data-original-height'));
console.log('Rendered:', img.getBoundingClientRect());
```

### If Python Integration Fails
```r
# Check in R console:
exists("detect_grid_layout", envir = .GlobalEnv)
exists(".postal_card_python_loaded", envir = .GlobalEnv)
reticulate::py_config()
```

### If Tests Fail
```r
# Run verification:
source("tests/manual/verify_fix.R")

# Run specific test:
testthat::test_file("tests/testthat/test-mod_postal_card_processor.R")

# Check test output:
devtools::test()
```

## Glossary

- **Boundary**: Crop line position in original image coordinates
- **Rendered Image**: Actual displayed size of image with object-fit:contain
- **Wrapper**: Container div with fixed dimensions
- **Offset**: Padding between wrapper edge and rendered image
- **Golem**: R package framework for production Shiny apps
- **Module**: Shiny module (namespace-scoped UI/server pair)
- **reticulate**: R package for R-Python interoperability

## End of Index

Last updated: 2025-01-06
Maintained by: LLM assistants and human developers
Purpose: Ensure knowledge persistence across sessions
