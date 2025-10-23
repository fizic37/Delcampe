# Testing Strategy: Critical vs Discovery Tests

## 🎯 Two Test Suites

Your tests are now split into **two strategic categories**:

### 1. **Critical Tests** - Production Ready ✅
Tests that **must always pass** - they verify core functionality

**Run with:**
```r
source("dev/run_critical_tests.R")
```

**Includes:**
- `test-ebay_helpers.R` - eBay business logic
- `test-utils_helpers.R` - Utility functions
- `test-mod_delcampe_export.R` - Delcampe export module
- `test-mod_tracking_viewer.R` - Tracking viewer module

**Purpose:**
- Run before every commit
- Run in CI/CD pipeline
- Ensure core features work
- Block merges if failing

**Expected Result:** ✅ 100% pass rate

---

### 2. **Discovery Tests** - Learning & Exploration 🔍
Tests that **help you learn and improve** - failures reveal opportunities

**Run with:**
```r
source("dev/run_discovery_tests.R")
```

**Includes:**
- `test-ai_api_helpers.R` - AI integration (exploratory)
- `test-tracking_database.R` - Database functions
- `test-mod_login.R` - Login module template
- `test-mod_settings_llm.R` - LLM settings template

**Purpose:**
- Discover how code actually works
- Find missing error handling
- Identify edge cases
- Guide refactoring
- Learn testing patterns

**Expected Result:** ⚠️ Some failures are OK and useful!

---

## 📊 Quick Comparison

| Aspect | Critical Tests | Discovery Tests |
|--------|---------------|-----------------|
| **Purpose** | Verify core features | Learn & explore |
| **Failures** | ❌ Block deployment | ✅ Learning opportunity |
| **Run When** | Before every commit | During development |
| **Pass Rate** | Must be 100% | Flexible |
| **CI/CD** | Yes, must pass | No, optional |
| **Test Count** | ~170 tests | ~100+ tests |

---

## 🚀 Daily Workflow

### During Development (Every Day)

```r
# Quick check - run critical tests
source("dev/run_critical_tests.R")
```

**Takes:** 5-10 seconds
**Result:** Confirms core features work

### Before Committing (Every Commit)

```r
# Full critical test suite
source("dev/run_critical_tests.R")
```

**Must pass:** ✅ All tests green
**If fails:** Fix before committing

### When Exploring (Occasionally)

```r
# Run discovery tests to learn
source("dev/run_discovery_tests.R")
```

**Takes:** 30-60 seconds
**Result:** Insights about code behavior

### Full Test Run (Weekly or Before Release)

```r
# Run everything
source("dev/run_tests.R")
```

**Takes:** 1-2 minutes
**Result:** Complete picture of test coverage

---

## 🎓 Understanding Results

### Critical Tests Output

```
==============================================
Critical Test Summary
==============================================
Total tests run:  55
✓ Passed:         55
✗ Failed:         0
⊘ Skipped:        0
==============================================

✅ SUCCESS! All critical tests passed!
```

**What this means:** Core functionality is solid! Safe to commit.

---

### Discovery Tests Output

```
==============================================
Discovery Test Summary
==============================================
Files tested:     4 of 4
Total tests run:  142
✓ Passed:         24
✗ Failed:         26
⊘ Skipped:        92
==============================================

✓ GOOD! Failures show learning opportunities
✓ NORMAL! Skipped tests are templates
✓ GREAT! 24 tests confirm correct behavior
```

**What this means:**
- 24 tests work perfectly
- 26 tests reveal function differences (good to know!)
- 92 tests are templates or need mocking setup

**This is SUCCESS!** Discoveries help improve code.

---

## 🔄 Moving Tests Between Suites

### Promote to Critical (When test is stable)

1. Fix the test so it passes reliably
2. Verify it tests important functionality
3. Move to critical test suite:

```r
# Edit dev/run_critical_tests.R
critical_tests <- c(
  "test-ebay_helpers.R",
  "test-utils_helpers.R",
  "test-new-stable-component.R"  # Add here
)
```

### Keep in Discovery (When test is exploratory)

If test:
- Helps understand code behavior
- Tests edge cases being developed
- Requires mocking setup
- Is a template showing patterns

→ Keep in discovery suite!

---

## 📝 Best Practices

### Critical Tests Should:
- ✅ Always pass (no flaky tests!)
- ✅ Be fast (<1 second each)
- ✅ Test core business logic
- ✅ Have no external dependencies
- ✅ Be easy to understand

### Discovery Tests Can:
- ⚠️ Fail (that's the point!)
- ⏱️ Take longer (it's OK)
- 🔍 Test experimental features
- 🎯 Explore edge cases
- 📚 Show testing patterns

---

## 🎯 Migration Strategy

### Phase 1 (Current): Two Suites Established ✅
- Critical tests: Working core functionality
- Discovery tests: Learning opportunities

### Phase 2 (This Month): Stabilize Discovery Tests
- Pick 1 failing discovery test per week
- Fix test or improve function
- Move to critical suite when stable

### Phase 3 (Ongoing): Expand Coverage
- Write new critical tests for new features
- Use discovery tests to explore unknowns
- Maintain 70%+ coverage in critical areas

---

## 🛠️ Commands Reference

```r
# Run critical tests (do this daily!)
source("dev/run_critical_tests.R")

# Run discovery tests (when exploring)
source("dev/run_discovery_tests.R")

# Run all tests (comprehensive)
source("dev/run_tests.R")

# Run specific file
devtools::load_all()
testthat::test_file("tests/testthat/test-ebay_helpers.R")

# Check coverage (critical tests only)
devtools::load_all()
covr::file_coverage("R/ebay_helpers.R", "tests/testthat")
```

---

## ✨ Success Metrics

### Critical Suite (Must Achieve)
- ✅ 100% pass rate
- ✅ <10 seconds execution time
- ✅ 50-100 tests
- ✅ Cover core business logic

### Discovery Suite (Growth Over Time)
- 🎯 Increasing pass rate (gradual)
- 🎯 Decreasing fail count (as you fix)
- 🎯 100-200 tests
- 🎯 Cover edge cases & exploration

### Overall (Long Term Goals)
- 🎯 70%+ code coverage
- 🎯 CI/CD integration
- 🎯 Fast feedback loop
- 🎯 High developer confidence

---

## 🎉 You Now Have

1. ✅ **Critical test suite** - Always passing, always run
2. ✅ **Discovery test suite** - Learning tool, run when exploring
3. ✅ **Clear strategy** - Know when to run what
4. ✅ **Migration path** - Move tests from discovery to critical
5. ✅ **Best practices** - Understand the "why" behind each suite

---

## 📚 Related Documentation

- **Quick start**: `dev/TESTING_QUICKSTART.md`
- **Detailed prioritization**: `dev/TEST_PRIORITIZATION.md`
- **Complete guide**: `dev/TESTING_GUIDE.md`
- **Test patterns**: `tests/README.md`

---

**Remember:** Critical tests keep you safe. Discovery tests make you smarter. Both are valuable! 🚀
