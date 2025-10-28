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

### Latest Session (October 28, 2025)

- ✅ **ebay_metadata_fields_and_condition_removal_20251028.md** - ⭐ METADATA FIELDS + CONDITION REMOVAL
  - Added 6 eBay metadata fields to UI and database (year, era, city, country, region, theme_keywords)
  - Database migration: Auto-creates columns in card_processing table on startup
  - Removed AI condition assessment (user knows best - defaults to "used")
  - Fixed eBay condition ID error: All postcards use ID 3000 (Used) for category 262042
  - Improved notifications: duration=NULL, full clickable URLs, user-controlled dismissal
  - AI prompt enhanced with face/verso layout instructions for combined images

- ✅ **ebay_trading_api_complete_20251028.md** - ⭐ TRADING API COMPLETE & WORKING
  - Status: Production listing created successfully (Item 406328907597)
  - Image Upload: Via EPS (eBay Picture Services) using UploadSiteHostedPictures
  - Business Policies: Auto-fetched from user account via Account API
  - Item Specifics: Intelligent Era/Theme detection from content
  - Description: HTML formatting with proper structure
  - Database: api_type column auto-migrates on app startup

- ✅ **ebay_trading_api_implementation_complete_20251028.md** - ⭐ TRADING API IMPLEMENTATION DETAILS
  - Solution: Complete Trading API implementation replacing Inventory API
  - New Files: R/ebay_trading_api.R (EbayTradingAPI R6 class), tests/testthat/test-ebay_trading_api.R
  - Modified: R/ebay_integration.R (505→141 lines), R/ebay_api.R, R/ebay_helpers.R, R/ebay_database_extension.R
  - Database: Added api_type column ("trading" vs "inventory")
  - Result: Cross-border listings now work with explicit Country field

- 🔴 **ebay_inventory_api_limitation_20251028.md** - ⚠️ CRITICAL - INVENTORY API CANNOT WORK
  - Problem: Error 25002 "No Item.Country" when publishing listings from Romania to US marketplace
  - Root Cause: Inventory API provides NO way for cross-border sellers to specify Item.Country
  - Solution: **Must use Trading API** (legacy XML) - has explicit `<Item><Country>RO</Country></Item>` field
  - Status: ✅ SOLVED - See ebay_trading_api_complete_20251028.md

### Active PRPs

- 🆕 **PRPs/PRP_EBAY_UX_IMPROVEMENTS.md** - ⭐ NEXT: UX IMPROVEMENTS FOR EBAY EXPORT
  - Condition dropdown with "Used" default
  - Confirmation dialog before listing creation
  - Progress messages during upload/creation
  - AI extraction enhancement (Era, City, Theme)
  - UI modernization with bslib cards
  - Priority: High
  - Status: Ready for Implementation

- **PRPs/PRP_EBAY_TRADING_API_IMPLEMENTATION.md** - ✅ COMPLETE (Implemented Oct 28)
  - Historical reference for Trading API implementation
  - All 8 phases completed successfully

### Previous Session (October 27, 2025)
- 🔴 **ebay_error_25019_investigation_20251027.md** - ⚠️ SUPERSEDED BY OCTOBER 28 FINDINGS
  - Original investigation into Error 25019
  - Led to discovery that Inventory API cannot handle cross-border sellers
  - See ebay_inventory_api_limitation_20251028.md for complete findings

### Previous Sessions

#### October 23, 2025 - Testing Infrastructure
- 🆕 **testing_infrastructure_complete_20251023.md** - ⭐ COMPREHENSIVE TESTING (270+ TESTS)
  - Critical suite: 170+ tests (must pass before commit)
  - Discovery suite: 100+ tests (exploratory, failures are learning)
  - Helper infrastructure: with_test_db(), with_mocked_ai()
  - CI/CD: GitHub Actions workflow

#### October 20, 2025 - Production Features
- 🆕 **simple_image_enlargement_20251020.md** - ⭐ SIMPLE CLICK-TO-ENLARGE IMAGE VIEWER
- 🆕 **production_logging_shinyapps_20251020.md** - ⭐ PRODUCTION LOGGING FOR SHINYAPPS.IO
- 🆕 **ebay_location_creation_fix_20251020.md** - ⭐ EBAY LOCATION ERROR 2004 FIX

(Previous entries preserved for historical context)

## File Relationships

```
project_purpose_and_overview.md
    ↓
tech_stack_and_architecture.md
    ↓
    ├──→ ebay_inventory_api_limitation_20251028.md (CRITICAL - Trading API needed)
    ├──→ ebay_trading_api_complete_20251028.md (✅ SOLUTION IMPLEMENTED)
    ├──→ PRPs/PRP_EBAY_UX_IMPROVEMENTS.md (🆕 NEXT STEPS)
    └──→ code_style_and_conventions.md
```

## When to Read What

### Working on eBay UX Improvements?
1. **READ FIRST**: `ebay_trading_api_complete_20251028.md` - Current working state
2. **IMPLEMENT**: `PRPs/PRP_EBAY_UX_IMPROVEMENTS.md` - Next improvements
3. Reference: `tech_stack_and_architecture.md` - Architecture constraints

### Working on eBay Listing Creation?
1. **READ FIRST**: `ebay_trading_api_complete_20251028.md` - Current implementation
2. **Historical**: `ebay_inventory_api_limitation_20251028.md` - Why Trading API is needed
3. **Testing**: `testing_infrastructure_complete_20251023.md` - How to test

### Starting a new task?
1. Read `project_purpose_and_overview.md` - Understand the goal
2. Read `tech_stack_and_architecture.md` - Know the constraints
3. Read `code_style_and_conventions.md` - Follow standards

## Critical Files (Don't Miss These!)

### 🔴 Must Read Before eBay Work
- **ebay_trading_api_complete_20251028.md** - Current working implementation
- **PRPs/PRP_EBAY_UX_IMPROVEMENTS.md** - Next improvements to implement

### 🔴 Must Read Before Any Changes
- **critical_constraints_preservation.md** - Violations will break the app
- **tech_stack_and_architecture.md** - Core architecture decisions

## Solution Registry

| Date | Problem | Solution File | Status | Tests |
|------|---------|---------------|--------|----------|
| 2025-10-28 | eBay Trading API Complete | ebay_trading_api_complete_20251028.md | ✅ WORKING | Production tested |
| 2025-10-28 | eBay Cross-Border Listing (Error 25002) | ebay_trading_api_implementation_complete_20251028.md | ✅ COMPLETE | test-ebay_trading_api.R (16+ tests) |
| 2025-10-28 | eBay Inventory API Limitation | ebay_inventory_api_limitation_20251028.md | ✅ SOLVED (use Trading API) | Documented |
| 2025-10-27 | eBay Error 25019 Investigation | ebay_error_25019_investigation_20251027.md | ⚠️ SUPERSEDED | Led to Oct 28 |
| 2025-10-23 | Testing Infrastructure | testing_infrastructure_complete_20251023.md | ✅ COMPLETE | 270+ tests |

## Emergency Contacts (Code Patterns)

### If eBay Listing Fails
```r
# ✅ SOLUTION IMPLEMENTED & WORKING (October 28, 2025)
#
# The app now uses Trading API (XML) instead of Inventory API (REST)
# Trading API properly supports cross-border listings with Country field
#
# Read: .serena/memories/ebay_trading_api_complete_20251028.md
#
# Key features:
# - Image upload via EPS (eBay Picture Services)
# - Business policies auto-fetched from user account
# - Intelligent Era/Theme detection
# - HTML description formatting
# - Database tracking with api_type="trading"
#
# Key files:
# - R/ebay_trading_api.R - EbayTradingAPI R6 class (443 lines)
# - R/ebay_integration.R - create_ebay_listing_from_card (141 lines)
# - R/ebay_helpers.R - map_condition_to_trading_id, extract_postcard_aspects
#
# Production status: ✅ Working (Item 406328907597 created)
```

### Next Steps for eBay
```r
# 🆕 IMPLEMENT NEXT (See PRPs/PRP_EBAY_UX_IMPROVEMENTS.md)
#
# 5 improvements needed:
# 1. Condition dropdown with "Used" default
# 2. Confirmation dialog before listing
# 3. Progress messages during creation
# 4. AI extraction enhancement (Era, City, Theme)
# 5. UI modernization with bslib
#
# Priority: High
# Effort: 4-6 hours
```

## Key Learnings from October 27-28, 2025

### What We Learned
1. **eBay Inventory API has a fundamental limitation** for cross-border sellers
2. Trading API is the ONLY solution for cross-border listings
3. EPS (eBay Picture Services) image upload required for Trading API
4. Business policies can be auto-fetched via Account API
5. Item specifics (Era, Theme) can be intelligently inferred from content
6. HTML descriptions work better than CDATA wrappers

### What Works (Production Tested)
- ✅ Trading API listing creation
- ✅ Image upload to EPS
- ✅ Business policies integration
- ✅ Intelligent Era/Theme detection
- ✅ HTML description formatting
- ✅ Database tracking with api_type

### What Needs Improvement (Next Steps)
- ⚠️ No confirmation before listing
- ⚠️ No progress feedback during creation
- ⚠️ Condition values need validation
- ⚠️ AI doesn't extract Era/City directly
- ⚠️ UI needs modernization

## Cleanup Done (October 28, 2025)

### Files Removed
- dev/add_sandbox_account_manually.R (obsolete)
- dev/add_sandbox_account_manual_v2.R (obsolete)
- dev/migrate_add_api_type.R (migration now in app_server.R)

### Files Archived
- PRPs/archive/PRP_EBAY_CONDITION_CATEGORY_FIX.md (completed)
- PRPs/archive/PRP_EBAY_IMAGE_UPLOAD_ANALYSIS.md (completed)
- PRPs/archive/PRP_EBAY_LOCATION_CREATION_FIX.md (completed)
- PRPs/archive/PRP_EBAY_LOCATION_FIX_AUTOMATED.md (completed)

## End of Index

Last updated: 2025-10-28
Maintained by: LLM assistants and human developers
Purpose: Ensure knowledge persistence across sessions
