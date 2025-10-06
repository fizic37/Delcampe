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
