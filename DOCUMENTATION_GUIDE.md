# Documentation Guide for Future Development

## Quick Start

This project has comprehensive documentation to help both humans and AI assistants understand the codebase and previous solutions.

## For Human Developers

### Getting Started
1. **Project Overview**: Read `README.Rmd` (if exists) or check `.serena/memories/project_purpose_and_overview.md`
2. **Setup**: Follow instructions in `dev/01_start.R`
3. **Running**: Use `dev/run_dev.R` for development mode

### Testing
```r
# Run all automated tests
devtools::test()

# Verify specific fix
source("tests/manual/verify_fix.R")

# Manual testing with visual output
source("tests/manual/test_coordinate_mapping.R")
```

See `tests/README.md` for complete testing documentation.

### Documentation Structure
```
Delcampe/
├── .serena/memories/           # Persistent LLM context
│   ├── INDEX.md               # Start here for navigation
│   ├── draggable_lines_coordinate_fix.md  # Major solution (2025-01-06)
│   └── ...                    # Other context files
├── COORDINATE_FIX_SUMMARY.md  # Technical reference (root level)
├── IMPLEMENTATION_GUIDE.md    # Quick testing guide (root level)
└── tests/
    ├── README.md              # Testing documentation
    ├── testthat/              # Automated unit tests
    └── manual/                # Verification scripts
```

## For AI Assistants (LLMs)

### First Time in This Project?

**Read these files in order:**

1. **`.serena/memories/INDEX.md`** - Navigation and overview of all documentation
2. **`.serena/memories/tech_stack_and_architecture.md`** - Core architecture and constraints
3. **`.serena/memories/critical_constraints_preservation.md`** - What must NOT be changed

### Working on Specific Tasks?

**Coordinate Mapping / Draggable Lines:**
→ `.serena/memories/draggable_lines_coordinate_fix.md`

**Python Integration:**
→ `.serena/memories/tech_stack_and_architecture.md` (Python Integration section)

**Module Structure:**
→ `.serena/memories/existing_module_analysis.md`

**Coding Standards:**
→ `.serena/memories/code_style_and_conventions.md`

### Key Principles

1. **Always check `.serena/memories/` first** - Don't re-solve solved problems
2. **Update documentation when making changes** - Future LLMs need context
3. **Follow Golem structure** - Tests in proper directories, modules properly named
4. **Preserve critical constraints** - R-Python integration, data attributes, CSS properties

## Recent Major Solutions

### Draggable Lines Coordinate Mapping Fix (2025-01-06) ✅

**Problem**: Lines didn't align with crop boundaries  
**Solution**: JavaScript rewrite with proper coordinate systems  
**Files Changed**: `inst/app/www/draggable_lines.js`  
**Documentation**: 
- Technical: `COORDINATE_FIX_SUMMARY.md`
- Quick Guide: `IMPLEMENTATION_GUIDE.md`
- LLM Context: `.serena/memories/draggable_lines_coordinate_fix.md`
- Tests: `tests/testthat/test-mod_postal_card_processor.R`

**Status**: Complete and tested ✅

## Project Structure (Golem Framework)

```
Delcampe/                      # Golem package structure
├── R/                         # R source code
│   ├── app_*.R               # App configuration
│   ├── mod_*.R               # Shiny modules
│   ├── utils_*.R             # Utility functions
│   └── run_app.R             # Main entry point
├── inst/                      # Installation files
│   ├── app/www/              # Static assets (JS, CSS, images)
│   ├── python/               # Python scripts
│   └── golem-config.yml      # Golem configuration
├── tests/                     # Test suite
│   ├── testthat/             # Automated tests (run with devtools::test())
│   └── manual/               # Verification scripts (source manually)
├── dev/                       # Development scripts
├── man/                       # Auto-generated documentation
├── .serena/                   # AI assistant context (persistent)
│   └── memories/             # Knowledge base for LLMs
├── venv_proj/                # Python virtual environment
└── test_images/              # Test data
```

## Common Tasks

### Running the App
```r
# Development mode
Delcampe::run_app()

# Or use the dev script
source("dev/run_dev.R")
```

### Running Tests
```r
# All automated tests
devtools::test()

# Specific test file
testthat::test_file("tests/testthat/test-mod_postal_card_processor.R")

# Manual verification
source("tests/manual/verify_fix.R")
```

### Adding New Features

1. **Check existing solutions**: Look in `.serena/memories/`
2. **Follow Golem conventions**: 
   - Modules: `mod_<name>.R` with `_ui` and `_server` functions
   - Utils: `utils_<name>.R` for helper functions
3. **Add tests**: 
   - Automated: `tests/testthat/test-<module>.R`
   - Manual: `tests/manual/verify_<feature>.R`
4. **Document**: 
   - Technical: `.serena/memories/<solution>_<date>.md`
   - User-facing: Root level markdown if needed

### Debugging Coordinate Issues

If lines don't align with crops:

1. **Check console logs** (F12 in browser):
   ```
   Should see: 🖼️ Rendered image bounds, 🔴 H-line positions, etc.
   ```

2. **Run verification**:
   ```r
   source("tests/manual/verify_fix.R")
   ```

3. **Check data attributes**:
   ```javascript
   // In browser console:
   img = document.querySelector('[id$="preview_image"]');
   console.log(img.getAttribute('data-original-width'));
   console.log(img.getAttribute('data-original-height'));
   ```

4. **Review the solution**: `.serena/memories/draggable_lines_coordinate_fix.md`

## Critical Constraints (DO NOT VIOLATE)

❌ **Never modify** the R-Python integration (reticulate setup)  
❌ **Never remove** `data-original-width`/`data-original-height` from images  
❌ **Never change** `object-fit: contain` on images  
❌ **Never delete** `.serena/memories/` directory  
❌ **Never skip** updating documentation when solving problems  

✅ **Always** check existing solutions before implementing  
✅ **Always** add tests for new features  
✅ **Always** update `.serena/memories/` for major changes  
✅ **Always** follow Golem structure conventions  

## Key Technologies

- **R Shiny** - Web application framework
- **Golem** - Production Shiny app framework
- **reticulate** - R-Python integration (DO NOT MODIFY)
- **Python 3.12** - Image processing backend
- **OpenCV (cv2)** - Computer vision library
- **testthat** - R testing framework
- **JavaScript** - Frontend interactivity (coordinate mapping)

## Getting Help

### For Coding Questions
- Check `.serena/memories/code_style_and_conventions.md`
- Review similar modules in `R/mod_*.R`

### For Architecture Questions
- Read `.serena/memories/tech_stack_and_architecture.md`
- Check `.serena/memories/existing_module_analysis.md`

### For Debugging
- Run `source("tests/manual/verify_fix.R")`
- Check browser console (F12)
- Review relevant solution in `.serena/memories/`

### For Testing
- See `tests/README.md`
- Run `devtools::test()` for automated tests
- Use manual verification scripts in `tests/manual/`

## Maintenance

### Monthly
- [ ] Run all tests: `devtools::test()`
- [ ] Verify manual scripts still work
- [ ] Review `.serena/memories/INDEX.md` for outdated content

### After Major Changes
- [ ] Update relevant files in `.serena/memories/`
- [ ] Add or update tests
- [ ] Update this guide if structure changes
- [ ] Document any new constraints

## Version History

- **v1.0** (2025-01-06): Initial documentation structure
  - Created comprehensive `.serena/memories/` system
  - Reorganized tests to Golem structure
  - Documented draggable lines coordinate fix

## For More Information

- **Project Purpose**: `.serena/memories/project_purpose_and_overview.md`
- **Full Architecture**: `.serena/memories/tech_stack_and_architecture.md`
- **All Solutions**: `.serena/memories/INDEX.md`
- **Test Guide**: `tests/README.md`
- **Coordinate Fix**: `COORDINATE_FIX_SUMMARY.md` or `.serena/memories/draggable_lines_coordinate_fix.md`

---

**Remember**: Always check `.serena/memories/INDEX.md` first when starting any work. It contains navigation to all documentation and solutions.
