# Testing Infrastructure Guide - INDEX

**Date**: 2025-11-03
**Purpose**: Navigation guide for testing infrastructure documentation
**Total Memory Files Created**: 4

---

## QUICK START (5 MINUTES)

**I just want to write tests!** → Go to **ready_examples** document

**I need to understand patterns** → Go to **comprehensive_patterns** document

**I need assertion patterns** → Go to **assertion_reference** document

---

## DOCUMENT OVERVIEW

### 1. authentication_testing_comprehensive_patterns_20251103.md
**Purpose**: Complete reference for all testing infrastructure
**Size**: ~600 lines of content + patterns
**Read Time**: 20-30 minutes
**Best For**: Understanding the full testing system

**Contains:**
- Complete table of contents
- All helper functions (database, mocks, fixtures)
- Exact database testing pattern (with_test_db) - COPY-PASTE READY
- Exact module testing pattern (testServer) - COPY-PASTE READY
- Mock patterns for external dependencies - COPY-PASTE READY
- Test structure and organization
- Critical vs discovery tests explanation
- Assertion patterns commonly used
- Complete example test files
- Test data setup patterns
- Running tests commands

**Key Sections:**
- Section 2: Database testing pattern (most important!)
- Section 3: Module testing pattern
- Section 4: Mock patterns
- Section 10: Complete copy-paste commands

**When to read:** First, to understand the infrastructure

---

### 2. authentication_testing_assertion_reference_20251103.md
**Purpose**: Complete assertion types with examples
**Size**: ~400 lines of content + examples
**Read Time**: 15-20 minutes
**Best For**: Looking up assertion patterns

**Contains:**
- Assertion quick reference by type
- Assertion patterns by test type (auth, database, Shiny)
- Complete auth test examples:
  - User creation assertions
  - Login assertions
  - Password validation assertions
  - Session management assertions
  - Master user assertions
  - Database assertions
- Shiny module assertions
- Error handling assertions
- Assertion troubleshooting guide
- Common issues and fixes

**Key Sections:**
- "ASSERTION QUICK REFERENCE" - One-liner examples
- "Assertion Patterns by Test Type" - Complete examples
- "Authentication System Tests" - Auth-specific patterns
- "Assertion Troubleshooting" - Common errors

**When to read:** While writing tests, for lookup

---

### 3. authentication_testing_ready_examples_20251103.md
**Purpose**: Complete test file template ready to copy-paste
**Size**: ~500 lines (actual test code)
**Read Time**: 10-15 minutes for skimming, 30+ to read completely
**Best For**: Copy-paste ready test file

**Contains:**
- Complete test file template (450+ lines)
- Ready-to-use test functions (40+):
  - Database initialization tests
  - User creation tests (variations)
  - Authentication tests (variations)
  - Session management tests
  - Password validation tests
  - Master user tests
  - Error handling tests
  - Integration tests (complete user lifecycle)
- Quick-start checklist
- Adaptation guide for customization

**Key Sections:**
- "COMPLETE TEST FILE TEMPLATE" - Copy entire file
- Each test function is a standalone example
- "IMPLEMENTATION CHECKLIST" - Step-by-step
- "ADAPTING EXAMPLES" - How to customize

**When to read:** Before creating test-auth_system.R

---

### 4. authentication_testing_complete_summary_20251103.md
**Purpose**: Overview and navigation guide
**Size**: ~300 lines
**Read Time**: 10-15 minutes
**Best For**: Understanding the big picture

**Contains:**
- Summary of all deliverables
- Infrastructure components reviewed
- Actionable patterns (4 main ones)
- Helper functions available
- Assertion patterns summary
- Critical vs discovery classification
- Implementation checklist
- Testing workflow
- Key statistics
- Quick links to all documents

**Key Sections:**
- "ACTIONABLE PATTERNS" - 4 main copy-paste patterns
- "HELPER FUNCTIONS AVAILABLE" - All available helpers
- "IMPLEMENTATION CHECKLIST" - What to do
- "TESTING WORKFLOW" - How to work
- "QUICK LINKS" - Where to go next

**When to read:** First, for orientation; later as reference

---

## READING ORDER RECOMMENDATIONS

### For Complete Understanding (45-60 min)
1. Read this index (5 min)
2. Read complete_summary (10 min)
3. Read comprehensive_patterns (20 min) - Focus on sections 2-5
4. Read assertion_reference (15 min) - Focus on auth sections
5. Skim ready_examples (10 min) - See the structure

### For Practical Usage (15-20 min)
1. Read complete_summary quickly (5 min)
2. Read comprehensive_patterns sections 2-4 (10 min)
3. Jump to ready_examples and start copying (5 min)

### For Quick Lookup (5 min)
1. Go directly to assertion_reference for assertion patterns
2. Go directly to comprehensive_patterns section 2 for database pattern
3. Go directly to ready_examples for template functions

---

## WHAT YOU'LL LEARN

### Helper Functions (Where to find them)
| Helper Type | Location | Document |
|-------------|----------|----------|
| Database | helper-setup.R | comprehensive_patterns §1 |
| Mocking | helper-mocks.R | comprehensive_patterns §1 |
| Fixtures | helper-fixtures.R | comprehensive_patterns §1 |

### Patterns (Ready to copy)
| Pattern | First Appear | Document |
|---------|--------------|----------|
| Database testing | comprehensive_patterns §2 | All docs |
| Module testing | comprehensive_patterns §3 | All docs |
| Mocking APIs | comprehensive_patterns §4 | comprehensive_patterns |
| Error handling | assertion_reference | All docs |

### Examples (Ready to use)
| Example | Location | Document |
|---------|----------|----------|
| Complete test file | Section 1 | ready_examples |
| User creation tests | Multiple | ready_examples + assertion_reference |
| Auth tests | Multiple | ready_examples + assertion_reference |
| Integration test | Complete | ready_examples |

---

## THE 4 MOST IMPORTANT PATTERNS

### Pattern 1: Database Testing (Most Important!)
**Location**: comprehensive_patterns §2, assertion_reference §4

```r
with_test_db({
  # Your test here
})
```

**Why important**: Every auth test uses this!

### Pattern 2: Module Testing
**Location**: comprehensive_patterns §3, ready_examples

```r
testServer(mod_name_server, {
  session$setInputs(...)
  expect_true(...)
})
```

### Pattern 3: Mocking External APIs
**Location**: comprehensive_patterns §4

```r
with_mocked_ai({
  # Test code
}, provider = "claude", success = TRUE)
```

### Pattern 4: Error Handling
**Location**: assertion_reference, comprehensive_patterns §7

```r
expect_error(my_function(NULL), "pattern")
```

---

## QUICK REFERENCE TABLE

| Question | Answer | Document | Section |
|----------|--------|----------|---------|
| How do I test database functions? | Use with_test_db() | comprehensive_patterns | §2 |
| How do I test Shiny modules? | Use testServer() | comprehensive_patterns | §3 |
| How do I mock API calls? | Use with_mocked_ai() | comprehensive_patterns | §4 |
| What assertions exist? | See quick reference | assertion_reference | Top |
| How do I write auth tests? | Use ready examples | ready_examples | All |
| Where are helpers? | In tests/testthat/ | comprehensive_patterns | §1 |
| What's critical vs discovery? | See classification | complete_summary | Classification |
| What should I do first? | Create test file | ready_examples | Checklist |
| How do I run tests? | See commands | comprehensive_patterns | §10 |

---

## COMMON TASKS - WHERE TO FIND HELP

### "I need to write a test for user creation"
1. Go to: ready_examples, search "create_user"
2. Copy the test function
3. Adapt to your auth system
4. Run and verify

### "I need to assert something about a user record"
1. Go to: assertion_reference
2. Search "user" or "database"
3. Find matching pattern
4. Copy the assertion

### "I don't understand how with_test_db works"
1. Go to: comprehensive_patterns §2
2. Read "Pattern: with_test_db() - COPY THIS"
3. See Key Points section
4. View Real Example from Codebase

### "I'm stuck on a test that's failing"
1. Go to: assertion_reference, "Assertion Troubleshooting"
2. Search your error message
3. See the problem and fix

### "I want to test module logic"
1. Go to: comprehensive_patterns §3
2. Read "Pattern: testServer() - COPY THIS"
3. See Module Server Tests section
4. Adapt to your module

### "I need to understand the test structure"
1. Go to: comprehensive_patterns §5
2. Read "Test Structure and Organization"
3. See File Organization
4. See Test Organization Within File

---

## BEFORE YOU START

### Prerequisites
- [ ] Understand basic R testing with testthat
- [ ] Know your auth system's functions
- [ ] Familiar with with R reactive programming (for module tests)
- [ ] Have read complete_summary for overview

### Setup Required
- [ ] Package loads with devtools::load_all()
- [ ] tests/testthat/ directory exists
- [ ] Helper files present (already done)

### Files You'll Create
- [ ] tests/testthat/test-auth_system.R (from ready_examples)

### Files You'll Modify
- [ ] dev/run_critical_tests.R (add test-auth_system.R when stable)

---

## MEMORY FILE LOCATION

All files are saved in project memory:
```r
# Read any document with:
mcp__serena__read_memory("authentication_testing_<name>_20251103.md")
```

Available documents:
1. `authentication_testing_comprehensive_patterns_20251103.md`
2. `authentication_testing_assertion_reference_20251103.md`
3. `authentication_testing_ready_examples_20251103.md`
4. `authentication_testing_complete_summary_20251103.md`
5. `testing_infrastructure_guide_index_20251103.md` (this file)

---

## TIPS FOR SUCCESS

### Tip 1: Start with ready_examples
Don't start from scratch. Use the template and adapt it.

### Tip 2: Use with_test_db() for everything
Every database test should use with_test_db(). It handles cleanup automatically.

### Tip 3: One focus per test
Each test should test one thing. Use clear test names.

### Tip 4: Run frequently
Test after every change: `testthat::test_file("...")`

### Tip 5: Use skip() when needed
If a test isn't ready, skip() it rather than deleting it.

### Tip 6: Copy-paste is fine!
The patterns are designed to be copied and slightly adapted.

### Tip 7: Check assertion_reference for lookups
Instead of guessing, always check what assertions are available.

### Tip 8: Verify with_test_db() setup
Before writing assertions, ensure setup created the data correctly.

---

## TROUBLESHOOTING GUIDE

### "Package not loaded"
**Fix**: Run `devtools::load_all()` first

### "Test can't find database helper"
**Fix**: Ensure helper-setup.R exists in tests/testthat/

### "with_test_db not working"
**Fix**: Make sure db is referenced correctly in test code

### "Assertion not recognized"
**Fix**: Check assertion_reference for correct syntax

### "Module test failing"
**Fix**: Add `session$flushReact()` after `session$setInputs()`

### "Too many assertions failing"
**Fix**: Run critical tests only: `source("dev/run_critical_tests.R")`

### "Can't understand a pattern"
**Fix**: Check assertion_reference for that pattern's examples

---

## NEXT STEPS

### Immediate (Today)
1. [ ] Read complete_summary (10 min)
2. [ ] Skim comprehensive_patterns §2-4 (10 min)
3. [ ] Open ready_examples document (5 min)

### Short Term (This session)
1. [ ] Create tests/testthat/test-auth_system.R
2. [ ] Copy template from ready_examples
3. [ ] Adapt for your auth functions
4. [ ] Run tests and verify

### Medium Term (Next session)
1. [ ] Add passing tests to dev/run_critical_tests.R
2. [ ] Run full critical test suite
3. [ ] Write any additional edge case tests

### Long Term (Ongoing)
1. [ ] Use patterns for all new auth tests
2. [ ] Run critical tests before commits
3. [ ] Gradually add discovery tests for exploration

---

**Last Updated**: 2025-11-03
**Status**: Complete and ready to use ✅
**All patterns documented**: ✅
**All examples provided**: ✅

---

## FINAL CHECKLIST

- [ ] Read this index
- [ ] Understood which document to read first
- [ ] Located all 4 memory files
- [ ] Ready to create test-auth_system.R
- [ ] Know where to look up patterns
- [ ] Know where to find examples
- [ ] Understand critical vs discovery
- [ ] Ready to start testing!

**You are now ready to write comprehensive auth system tests!** 🚀
