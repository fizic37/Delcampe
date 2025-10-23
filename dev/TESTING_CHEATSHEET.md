# Testing Cheat Sheet

## 🚀 Quick Commands

### Run Critical Tests (Use This Daily!)
```r
source("dev/run_critical_tests.R")
```
**Result:** ~170 tests, all should pass ✅
**Time:** 10-20 seconds

---

### Run Discovery Tests (When Exploring)
```r
source("dev/run_discovery_tests.R")
```
**Result:** ~140 tests, failures OK ⚠️
**Time:** 30-60 seconds

---

### Run Everything
```r
source("dev/run_tests.R")
```
**Result:** All tests
**Time:** 1-2 minutes

---

## 📚 Which Script When?

| Situation | Command |
|-----------|---------|
| **Before committing** | `run_critical_tests.R` |
| **During development** | `run_critical_tests.R` |
| **Exploring code** | `run_discovery_tests.R` |
| **Before release** | `run_tests.R` |
| **Learning testing** | `run_discovery_tests.R` |

---

## 🎯 Test Categories

### ✅ Critical (Always Pass)
- `test-ebay_helpers.R` - eBay business logic
- `test-utils_helpers.R` - Utility functions
- `test-mod_delcampe_export.R` - Delcampe export module
- `test-mod_tracking_viewer.R` - Tracking viewer module

### 🔍 Discovery (Learning)
- `test-ai_api_helpers.R` - AI integration
- `test-tracking_database.R` - Database functions
- `test-mod_login.R` - Login module template
- `test-mod_settings_llm.R` - LLM settings template

---

## 📊 Understanding Output

```
[ FAIL 0 | WARN 0 | SKIP 5 | PASS 50 ]
```

- **FAIL 0** = No failures (good!)
- **WARN 0** = No warnings
- **SKIP 5** = Intentionally skipped
- **PASS 50** = Tests passed ✅

---

## 🛠️ Common Tasks

### Load Package First
```r
devtools::load_all()
```
**Always do this before running tests manually!**

### Run One Test File
```r
devtools::load_all()
testthat::test_file("tests/testthat/test-ebay_helpers.R")
```

### Skip a Failing Test
```r
test_that("my test", {
  skip("TODO: Fix function signature")
  # test code
})
```

### Check Coverage
```r
devtools::load_all()
coverage <- covr::package_coverage()
covr::report(coverage)
```

---

## 📖 Documentation Files

| File | Purpose |
|------|---------|
| `TESTING_STRATEGY.md` | Critical vs Discovery strategy |
| `TESTING_QUICKSTART.md` | Understanding basics |
| `TEST_PRIORITIZATION.md` | Which tests to keep/skip |
| `TESTING_GUIDE.md` | Complete reference |
| `QUICK_WIN_TESTS.md` | Get started fast |

---

## ⚡ Emergency Reference

**Tests won't run?**
```r
devtools::load_all()  # Load package first!
```

**Too many failures?**
```r
source("dev/run_critical_tests.R")  # Run only stable tests
```

**Want to learn?**
```r
source("dev/run_discovery_tests.R")  # Explore with discovery
```

**Need help?**
Read: `dev/TESTING_QUICKSTART.md`

---

## 🎯 Daily Workflow

```
Morning:
  ↓
Load package
  ↓
Run critical tests ✅
  ↓
All pass? → Start coding
  ↓
Make changes
  ↓
Run critical tests again
  ↓
All pass? → Commit ✅
```

---

## 💡 Remember

1. **Load package first**: `devtools::load_all()`
2. **Critical before commit**: Always pass
3. **Discovery when learning**: Failures teach
4. **Skip when needed**: Better than failing
5. **One at a time**: Fix gradually

---

**That's it!** Bookmark this page for quick reference. 🚀
