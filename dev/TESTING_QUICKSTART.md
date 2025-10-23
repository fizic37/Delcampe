# Testing Quick Start Guide

## Understanding R Package Testing

When you run tests for an R package, you need to **load the package first** so the test functions can find your package functions. This is different from regular R scripts!

## What Just Happened?

You saw two types of errors:

### 1. NAMESPACE Export Errors
```
Error: undefined exports: Calculate, MD5, an, deduplication, hash, of
```

**Cause**: Malformed roxygen comment that put `@export` on the wrong line
**Fixed**: ✅ Cleaned up R/tracking_database.R and NAMESPACE

### 2. "could not find function" Errors
```
Error: could not find function "get_llm_config"
```

**Cause**: Tests ran before package was loaded
**Fixed**: ✅ Updated dev/run_tests.R to load package first

---

## How to Run Tests Now

### Option 1: Use the Updated Runner (Easiest)

```r
source("dev/run_tests.R")
```

This now:
1. Loads the Delcampe package with `devtools::load_all()`
2. Runs all tests
3. Generates coverage report

### Option 2: Manual Step-by-Step

```r
# Step 1: Load the package
devtools::load_all()

# Step 2: Run tests
testthat::test_dir("tests/testthat")

# Step 3: Check coverage (optional)
coverage <- covr::package_coverage()
covr::report(coverage)
```

### Option 3: Run Specific Test File

```r
# Load package first!
devtools::load_all()

# Run one test file
testthat::test_file("tests/testthat/test-tracking_database.R")
```

---

## The R Package Testing Workflow

```
┌─────────────────────────────────────────────────┐
│  1. Write Code in R/                            │
│     - Add functions to R/*.R files              │
│     - Document with #' roxygen comments         │
│     - Use #' @export for public functions       │
└─────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│  2. Write Tests in tests/testthat/              │
│     - Create test-*.R files                     │
│     - Use test_that("description", { ... })     │
│     - Use expect_* functions for assertions     │
└─────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│  3. Load Package                                │
│     - Run: devtools::load_all()                 │
│     - This makes your functions available       │
│     - Like library(Delcampe) but for development│
└─────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│  4. Run Tests                                   │
│     - Run: devtools::test()                     │
│     - Or: testthat::test_dir("tests/testthat")  │
│     - Tests can now find your functions!        │
└─────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│  5. Fix Failures & Iterate                      │
│     - Read error messages                       │
│     - Fix code or tests                         │
│     - Re-run: devtools::load_all() then test    │
└─────────────────────────────────────────────────┘
```

---

## Common Issues & Solutions

### Issue: "could not find function"

**Symptom**: Tests can't find your functions
```r
Error: could not find function "my_function"
```

**Solution**: Load the package first!
```r
devtools::load_all()  # Always do this first
testthat::test_dir("tests/testthat")
```

---

### Issue: NAMESPACE Export Errors

**Symptom**: Package won't load
```
Error: undefined exports: Calculate, MD5, hash
```

**Cause**: Malformed roxygen comment

**Wrong**:
```r
#' @export Calculate an MD5 hash
my_function <- function() {}
```

**Right**:
```r
#' Calculate an MD5 hash
#' @export
my_function <- function() {}
```

**Fix**:
1. Find and fix the malformed comment
2. Regenerate NAMESPACE: `roxygen2::roxygenize()` (if packages installed)
3. Or manually edit NAMESPACE to remove bad exports

---

### Issue: Tests Pass Locally But Fail in CI

**Cause**: Missing dependencies or environment differences

**Check**:
1. All packages in DESCRIPTION Imports/Suggests
2. Python dependencies if using reticulate
3. System dependencies (image libraries, etc.)

---

## Understanding Test Output

```
[ FAIL 2 | WARN 1 | SKIP 5 | PASS 35 ]
```

- **FAIL**: Tests that failed - FIX THESE
- **WARN**: Warnings - investigate but not critical
- **SKIP**: Tests marked with `skip()` - intentionally skipped
- **PASS**: Tests that passed - good!

---

## Tips for Success

1. **Always load first**: Make `devtools::load_all()` your habit
2. **Run tests often**: After every change, run relevant tests
3. **Read error messages carefully**: They usually tell you exactly what's wrong
4. **Start small**: Run one test file at a time when debugging
5. **Use helper functions**: Our helper-*.R files make testing much easier

---

## Next Steps

Now that tests can run, you should:

1. **Run tests again** with the fixed setup:
   ```r
   source("dev/run_tests.R")
   ```

2. **Review failures**: Some tests may still fail because:
   - Functions might have different behavior than expected
   - Some tests need database setup
   - Some tests are templates with `skip()`

3. **Fix real failures**: Update tests or code as needed

4. **Understand skip() tests**: These are templates - they show patterns but don't run yet

---

## Questions?

- See full testing patterns in `tests/README.md`
- See detailed guide in `dev/TESTING_GUIDE.md`
- Check test templates in `test-mod_login.R` and `test-mod_settings_llm.R`
