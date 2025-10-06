# Tests Directory Structure

This directory contains tests for the Delcampe package following the Golem framework structure.

## Structure

```
tests/
├── testthat.R              # Test runner configuration
├── testthat/               # Automated unit tests (run with testthat)
│   └── test-mod_postal_card_processor.R  # Tests for coordinate mapping
├── manual/                 # Manual verification scripts
│   ├── verify_fix.R        # Complete system verification
│   ├── test_coordinate_mapping.R  # Visual coordinate conversion test
│   ├── debug_upload_issue.R  # Legacy debug script
│   └── test_drag_bug.R     # Legacy debug script
└── README.md              # This file
```

## Running Tests

### Automated Unit Tests (Recommended)

Run all tests:
```r
devtools::test()
# or
testthat::test_dir("tests/testthat")
```

Run specific test file:
```r
testthat::test_file("tests/testthat/test-mod_postal_card_processor.R")
```

### Manual Verification Scripts

**Complete system verification:**
```r
source("tests/manual/verify_fix.R")
```
This checks:
- File existence
- JavaScript implementation
- R module configuration
- Mathematical accuracy

**Visual coordinate mapping test:**
```r
source("tests/manual/test_coordinate_mapping.R")
```
This shows:
- Step-by-step coordinate conversion
- Expected vs actual values
- Testing instructions

## Test Coverage

### mod_postal_card_processor Tests

**Coordinate Conversion Math** (`test-mod_postal_card_processor.R`)
- ✅ Forward conversion (Original → Screen)
- ✅ Reverse conversion (Screen → Original)
- ✅ Round-trip accuracy (<0.1px error)
- ✅ Rendered bounds calculation
- ✅ Offset calculations for object-fit:contain
- ✅ Scale factor conversion matching JavaScript
- ✅ Boundary array validation
- ✅ Grid dimension derivation

## Test Data

Test images are located in `test_images/`:
- `test_face.jpg` - Face side of postcards (1915×3507)
- `test_verso.jpg` - Verso side of postcards

## Adding New Tests

### For Automated Tests

Create a new file in `tests/testthat/` following the naming convention:
```
test-<module_name>.R
```

Example structure:
```r
test_that("description of what you're testing", {
  # Arrange
  input <- some_value
  
  # Act
  result <- function_to_test(input)
  
  # Assert
  expect_equal(result, expected_value)
})
```

### For Manual Tests

Create a new file in `tests/manual/` with descriptive name:
```
verify_<feature>.R
```

Include:
- Clear comments explaining what it tests
- Step-by-step instructions
- Expected output examples
- Visual indicators (✅/❌) for pass/fail

## Continuous Integration

To add CI testing, create `.github/workflows/R-CMD-check.yaml`:
```yaml
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

name: R-CMD-check

jobs:
  R-CMD-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: r-lib/actions/setup-r@v2
      - uses: r-lib/actions/setup-r-dependencies@v2
      - uses: r-lib/actions/check-r-package@v2
```

## Test Philosophy

### Automated Tests Should:
- Run quickly (<1 second each)
- Be deterministic (same input = same output)
- Test one thing at a time
- Not depend on external state
- Be easy to understand

### Manual Tests Should:
- Provide visual feedback
- Include step-by-step instructions
- Show expected vs actual results
- Be runnable by non-technical users
- Document complex scenarios

## Debugging Failed Tests

If tests fail:

1. **Check the test output** - testthat provides clear error messages
2. **Run the test interactively** - Source the test file and step through
3. **Check console logs** - Especially for JavaScript-R integration
4. **Verify test data** - Ensure test images exist and are valid
5. **Check dependencies** - Make sure all packages are installed

## Related Documentation

- **`.serena/memories/draggable_lines_coordinate_fix.md`** - Technical solution details
- **`COORDINATE_FIX_SUMMARY.md`** - Complete reference documentation
- **`IMPLEMENTATION_GUIDE.md`** - Quick start guide
- **Golem Book**: https://thinkr-open.github.io/golem/

## Maintenance

When modifying the coordinate mapping logic:
1. ✅ Update tests in `test-mod_postal_card_processor.R`
2. ✅ Run `devtools::test()` to verify all tests pass
3. ✅ Update documentation in `.serena/memories/`
4. ✅ Run manual verification: `source("tests/manual/verify_fix.R")`
5. ✅ Test visually in running app

## Questions?

- For automated tests: See testthat documentation
- For Golem structure: See Golem book
- For coordinate mapping: See `.serena/memories/draggable_lines_coordinate_fix.md`
