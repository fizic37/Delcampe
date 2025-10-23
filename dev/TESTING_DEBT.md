# Testing Debt: Modules Requiring Test Coverage

**Date:** 2025-10-23
**Status:** Partial Coverage - Infrastructure Complete, Some Modules Tested

---

## Summary

This document tracks modules that need comprehensive test coverage. The testing infrastructure is complete and production-ready, with helper functions, fixtures, and test runners all implemented. Critical business logic is well-tested, but several modules still need dedicated test files.

### Current Coverage Statistics

**Fully Tested:**
- ✅ `R/ebay_helpers.R` - 30 tests (critical suite)
- ✅ `R/utils_helpers.R` - 30 tests (critical suite)
- ✅ `R/ai_api_helpers.R` - 40+ tests (discovery suite, recently fixed)
- ✅ `R/tracking_database.R` - 42 tests (discovery suite)
- ✅ `R/mod_delcampe_export.R` - 60+ tests (comprehensive module tests)
- ✅ `R/mod_tracking_viewer.R` - 50+ tests (comprehensive module tests)

**Template Tests (Basic Coverage):**
- ⚠️ `R/mod_login.R` - Template only (~10 tests)
- ⚠️ `R/mod_settings_llm.R` - Template only (~8 tests)

**No Test Coverage:**
- ❌ 9 modules (listed below)

**Total:** 6 fully tested, 2 with templates, 9 without tests

---

## Modules Requiring Test Coverage

### Priority 1: Critical Business Logic Modules

These modules handle core workflow and should be tested soon.

#### 1. `mod_postal_card_processor.R`

**Why Critical:** Main workflow coordinator, processes cards from upload to eBay

**Complexity:** HIGH (likely 300-500 lines)

**Estimated Tests Needed:** 60-80 tests

**What to Test:**
- Image upload handling
- Crop generation (face/verso)
- Combined image creation
- Integration with AI extraction
- Integration with eBay export
- Session management
- User feedback and notifications

**Dependencies:**
- tracking_database.R (✅ tested)
- ai_api_helpers.R (✅ tested)
- Image processing functions
- File system operations

**Test File:** `tests/testthat/test-mod_postal_card_processor.R`

**Notes:** This is the central module - high priority for comprehensive testing

---

#### 2. `mod_ai_extraction.R`

**Why Critical:** Handles AI extraction workflow and UI

**Complexity:** MEDIUM-HIGH

**Estimated Tests Needed:** 40-60 tests

**What to Test:**
- AI model selection
- Extraction triggers and workflows
- Result parsing and display
- Integration with mod_delcampe_export
- Error handling for API failures
- Status tracking during extraction

**Dependencies:**
- ai_api_helpers.R (✅ tested)
- tracking_database.R (✅ tested)

**Test File:** `tests/testthat/test-mod_ai_extraction.R`

**Priority:** HIGH - AI is a core feature

---

#### 3. `mod_ebay_postcard.R`

**Why Critical:** Creates eBay listings (core business function)

**Complexity:** HIGH

**Estimated Tests Needed:** 50-70 tests

**What to Test:**
- eBay listing creation
- Image upload to eBay
- Item specifics mapping
- Category selection
- Price and condition handling
- Shipping configuration
- Business policy application
- Error handling for eBay API failures

**Dependencies:**
- ebay_helpers.R (✅ tested)
- tracking_database.R (✅ tested)
- eBay API integration

**Test File:** `tests/testthat/test-mod_ebay_postcard.R`

**Priority:** HIGH - Direct revenue impact

---

### Priority 2: Authentication & Configuration Modules

These modules handle user management and settings.

#### 4. `mod_ebay_auth.R`

**Why Important:** eBay OAuth, multi-account management

**Complexity:** MEDIUM-HIGH

**Estimated Tests Needed:** 40-50 tests

**What to Test:**
- OAuth flow initiation
- Token storage and retrieval
- Token refresh
- Multi-account switching
- Account credentials validation
- Sandbox vs production mode

**Dependencies:**
- Database (user settings)
- OAuth library integration

**Test File:** `tests/testthat/test-mod_ebay_auth.R`

**Priority:** MEDIUM - Important for eBay integration

---

#### 5. `mod_settings_server.R`

**Why Important:** Handles all settings logic

**Complexity:** MEDIUM

**Estimated Tests Needed:** 30-40 tests

**What to Test:**
- Settings loading and saving
- AI API key management
- eBay configuration
- User preferences
- Validation of settings

**Dependencies:**
- Database
- Settings persistence

**Test File:** `tests/testthat/test-mod_settings_server.R`

**Priority:** MEDIUM

---

#### 6. `mod_settings_password.R`

**Why Important:** Password management, security-critical

**Complexity:** LOW-MEDIUM

**Estimated Tests Needed:** 20-30 tests

**What to Test:**
- Password hashing (SHA-256)
- Password change workflow
- Validation rules
- Master user protection
- Error messages

**Dependencies:**
- tracking_database.R (✅ tested)

**Test File:** `tests/testthat/test-mod_settings_password.R`

**Priority:** MEDIUM - Security-sensitive

---

### Priority 3: UI Modules

These are primarily UI composition modules with less complex logic.

#### 7. `mod_delcampe_ui.R`

**Why Less Critical:** Mainly UI composition

**Complexity:** LOW-MEDIUM

**Estimated Tests Needed:** 20-30 tests

**What to Test:**
- UI element generation
- Layout structure
- Namespace handling
- Component integration

**Test File:** `tests/testthat/test-mod_delcampe_ui.R`

**Priority:** LOW - UI composition, less logic

---

#### 8. `mod_settings_ui.R`

**Why Less Critical:** UI only, logic in mod_settings_server.R

**Complexity:** LOW

**Estimated Tests Needed:** 15-25 tests

**What to Test:**
- Settings form structure
- Input element creation
- Default values
- Validation UI

**Test File:** `tests/testthat/test-mod_settings_ui.R`

**Priority:** LOW

---

#### 9. `mod_settings_ui_simple.R`

**Why Less Critical:** Simplified UI variant

**Complexity:** LOW

**Estimated Tests Needed:** 10-20 tests

**What to Test:**
- Simplified form structure
- Required elements present
- Namespace handling

**Test File:** `tests/testthat/test-mod_settings_ui_simple.R`

**Priority:** LOW

---

## Modules with Template Tests (Need Completion)

### `mod_login.R`

**Current Status:** Template with ~10 basic tests

**What's Missing:**
- Comprehensive authentication flow tests
- Session management tests
- Error handling tests
- Master user privilege tests

**Estimated Additional Tests Needed:** 30-40 tests

**Test File:** `tests/testthat/test-mod_login.R` (exists, needs expansion)

**Priority:** MEDIUM - Authentication is important

---

### `mod_settings_llm.R`

**Current Status:** Template with ~8 basic tests

**What's Missing:**
- LLM model selection tests
- API key validation tests
- Settings persistence tests
- Integration with AI extraction

**Estimated Additional Tests Needed:** 20-30 tests

**Test File:** `tests/testthat/test-mod_settings_llm.R` (exists, needs expansion)

**Priority:** MEDIUM

---

## Integration Tests Needed

Beyond individual module tests, we need integration tests that verify multi-module workflows:

### Integration Test Suite 1: End-to-End Card Processing

**What to Test:**
1. Login → Upload Images → Crop Generation → Combined Image → AI Extraction → eBay Export

**Estimated Tests:** 10-15 tests

**Test File:** `tests/testthat/test-integration-card-processing.R`

**Priority:** HIGH - Verifies core workflow

---

### Integration Test Suite 2: Multi-Module Communication

**What to Test:**
- Data flow between modules
- Reactive parameter passing
- Return value handling
- Event triggering across modules

**Estimated Tests:** 15-20 tests

**Test File:** `tests/testthat/test-integration-module-communication.R`

**Priority:** MEDIUM

---

### Integration Test Suite 3: Database Consistency

**What to Test:**
- Transaction integrity
- Data consistency across tables
- Cascade operations
- Deduplication logic

**Estimated Tests:** 10-15 tests

**Test File:** `tests/testthat/test-integration-database.R`

**Priority:** MEDIUM

---

## Test Writing Guidelines

When adding tests for the above modules:

1. **Follow Patterns:** Use `dev/TESTING_PATTERNS.md` as reference
2. **Start with Templates:** Copy from `test-mod_delcampe_export.R` or `test-mod_tracking_viewer.R`
3. **Test Edge Cases:** NULL, empty, invalid inputs
4. **Use Helpers:** Leverage `helper-setup.R`, `helper-mocks.R`, `helper-fixtures.R`
5. **Skip Integration:** Use `skip()` for tests requiring full stack
6. **Group Tests:** Organize with `# ==== SECTION NAME ====` headers
7. **Be Descriptive:** Clear test names explain what's being tested

---

## Recommended Testing Schedule

### Week 1: High Priority Business Logic
- ✅ Complete mod_postal_card_processor tests (60-80 tests)
- ✅ Complete mod_ai_extraction tests (40-60 tests)
- ✅ Complete mod_ebay_postcard tests (50-70 tests)

**Total:** ~150-210 tests

---

### Week 2: Authentication & Configuration
- Complete mod_ebay_auth tests (40-50 tests)
- Complete mod_settings_server tests (30-40 tests)
- Complete mod_settings_password tests (20-30 tests)
- Expand mod_login tests (+30-40 tests)
- Expand mod_settings_llm tests (+20-30 tests)

**Total:** ~140-190 tests

---

### Week 3: UI Modules & Integration
- Complete mod_delcampe_ui tests (20-30 tests)
- Complete mod_settings_ui tests (15-25 tests)
- Complete mod_settings_ui_simple tests (10-20 tests)
- Add integration test suite 1 (10-15 tests)
- Add integration test suite 2 (15-20 tests)

**Total:** ~70-110 tests

---

## Progress Tracking

| Module | Priority | Status | Est. Tests | Actual Tests | Date Completed |
|--------|----------|--------|------------|--------------|----------------|
| ebay_helpers.R | Critical | ✅ Complete | 30 | 30 | 2025-10-23 |
| utils_helpers.R | Critical | ✅ Complete | 30 | 30 | 2025-10-23 |
| ai_api_helpers.R | Critical | ✅ Complete | 40 | 40+ | 2025-10-23 |
| tracking_database.R | Critical | ✅ Complete | 42 | 42 | 2025-10-23 |
| mod_delcampe_export.R | High | ✅ Complete | 60 | 60+ | 2025-10-23 |
| mod_tracking_viewer.R | Medium | ✅ Complete | 50 | 50+ | 2025-10-23 |
| mod_postal_card_processor.R | High | ❌ Needed | 60-80 | 0 | - |
| mod_ai_extraction.R | High | ❌ Needed | 40-60 | 0 | - |
| mod_ebay_postcard.R | High | ❌ Needed | 50-70 | 0 | - |
| mod_ebay_auth.R | Medium | ❌ Needed | 40-50 | 0 | - |
| mod_settings_server.R | Medium | ❌ Needed | 30-40 | 0 | - |
| mod_settings_password.R | Medium | ❌ Needed | 20-30 | 0 | - |
| mod_delcampe_ui.R | Low | ❌ Needed | 20-30 | 0 | - |
| mod_settings_ui.R | Low | ❌ Needed | 15-25 | 0 | - |
| mod_settings_ui_simple.R | Low | ❌ Needed | 10-20 | 0 | - |
| mod_login.R | Medium | ⚠️ Template | 40-50 | ~10 | - |
| mod_settings_llm.R | Medium | ⚠️ Template | 28-38 | ~8 | - |

**Current Total Tests:** ~252 tests
**Target Total Tests:** ~700-900 tests
**Coverage:** ~28-36%

---

## Adding Tests Incrementally

You don't need to complete all testing at once! The infrastructure supports incremental test addition:

### As You Develop New Features:
1. Write tests alongside new code
2. Add tests to appropriate suite (critical vs discovery)
3. Run `source("dev/run_critical_tests.R")` before committing

### As You Fix Bugs:
1. Write a failing test that reproduces the bug
2. Fix the bug
3. Verify test passes
4. Add test to critical suite if it's important

### During Refactoring:
1. Write tests for current behavior first
2. Refactor code
3. Verify tests still pass
4. Tests ensure you didn't break anything

---

## Notes

- **Testing infrastructure is production-ready** - All helpers, fixtures, and runners are complete
- **Templates exist** - Copy patterns from existing test files
- **Skip complex integration** - Use `skip()` for tests requiring full stack
- **Start with critical modules** - Test high-value, high-risk code first
- **Tests are living documentation** - They show how modules are intended to be used

---

**Remember:** It's better to have excellent tests for critical modules than mediocre tests for everything. Focus on quality over quantity, and add tests incrementally as the codebase evolves.
