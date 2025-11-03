# Delcampe Project - Memory Index

## Active Memories (Curated List)

### Project Overview
- **project_purpose_and_overview** - High-level project goals and architecture
- **tech_stack_and_architecture** - R/Shiny framework, Python integration, database design
- **code_style_and_conventions** - Coding standards and best practices
- **critical_constraints_preservation** - MUST NOT MODIFY rules (R-Python integration, auth, file paths)

### Current Implementation Status
- **current_status_20251009** - Overall project state snapshot
- **existing_module_analysis** - Catalog of implemented modules

### Testing Infrastructure (IMPORTANT)
- **testing_infrastructure_complete_20251023** - Complete testing guide
  - Two-suite strategy: critical (must pass) and discovery (learning)
  - Run `source("dev/run_critical_tests.R")` before every commit
  - Currently ~170 critical tests, ~100 discovery tests
  - Use helper functions: `with_test_db()`, `with_mocked_ai()`

### AI Integration
- **ai_extraction_complete_20251009** - AI-powered data extraction system
- **genai_integration_fix_20251007** - Claude/GPT-4o integration
- **llm_settings_fix_complete_20251009** - LLM configuration UI

### eBay Integration

#### Multi-Account & OAuth
- **ebay_multi_account_phase2_complete_20251018** - Account manager implementation
- **ebay_oauth_integration_complete_20251017** - OAuth 2.0 flow
- **ebay_oauth_scope_fix_trading_api_20251029** - Scope requirements for Trading API

#### Trading API & Auctions  
- **ebay_trading_api_complete_20251028** - Trading API implementation
- **ebay_auction_support_complete_20251029** - Auction listing support
- **ebay_scheduled_listing_backend_complete_20251101** - Scheduled listing backend
- **ebay_scheduled_listing_ui_complete_20251102** - Scheduled listing UI

#### eBay Listings Viewer & Sync
- **ebay_listings_viewer_fixes_20251102** - LATEST: Category bugs, sync fixes, API errors
  - Fixed: Stamps going to wrong category (262042 → 260)
  - Fixed: SKU prefix (PC- → STAMP-)
  - Fixed: Sync now inserts new listings from eBay
  - Fixed: XML parsing NULL/NA safety
  - UNRESOLVED: eBay API GetSellerList call failing
  - Files: ebay_helpers.R, ebay_integration.R, mod_stamp_export.R, ebay_sync_helpers.R

#### Image Upload & Other
- **ebay_image_upload_complete_20251020** - eBay Picture Services integration
- **imgbb_integration_and_oauth_fixes_20251029** - Imgbb fallback
- **image_upload_race_condition_fix_FINAL_20251029** - Race condition fix

### Stamps Feature
- **stamp_ai_extraction_complete_fix_20251101** - Three critical bugs fixed
- **stamp_ui_differentiation_purple_theme_20251031** - Purple theme for stamps tab

### UI/UX Improvements
- **accordion_success_20251010** - bslib accordion implementation
- **panel_layout_implementation_20251010** - Panel-based layout
- **form_layout_optimization_full_width_20251030** - Form layout optimization

### Database & Tracking
- **three_layer_architecture_complete_20251013** - Database schema design
- **tracking_datatable_complete_20251016** - DataTable viewer
- **deduplication_bug_fixed_20251013** - Deduplication logic fix

### Workflow Automation
- **task_09_auto_combine_complete_20251014** - Auto-combine workflow

### Bug Fixes & Resolutions
- **shownotification_type_error_fix** - Shiny notification types (message/warning/error only)
- **draggable_lines_coordinate_fix** - JavaScript coordinate system fix
- **null_dimensions_bug_fix_20251013** - Dimension handling

### Development Guides
- **suggested_commands** - Common development commands
- **task_completion_procedures** - How to complete and document tasks

## Memory Organization

### By Feature Area

**Core Infrastructure**
- project_purpose_and_overview
- tech_stack_and_architecture  
- code_style_and_conventions
- critical_constraints_preservation
- testing_infrastructure_complete_20251023

**AI/LLM**
- ai_extraction_complete_20251009
- genai_integration_fix_20251007
- llm_settings_fix_complete_20251009

**eBay Integration**
- ebay_oauth_integration_complete_20251017
- ebay_multi_account_phase2_complete_20251018
- ebay_trading_api_complete_20251028
- ebay_auction_support_complete_20251029
- ebay_scheduled_listing_backend_complete_20251101
- ebay_scheduled_listing_ui_complete_20251102
- ebay_listings_viewer_fixes_20251102 ← LATEST
- ebay_image_upload_complete_20251020
- imgbb_integration_and_oauth_fixes_20251029

**Stamps Feature**
- stamp_ai_extraction_complete_fix_20251101
- stamp_ui_differentiation_purple_theme_20251031

**Database**
- three_layer_architecture_complete_20251013
- tracking_datatable_complete_20251016

**UI Components**
- accordion_success_20251010
- panel_layout_implementation_20251010
- form_layout_optimization_full_width_20251030

## Recent Updates (Last 7 Days)

1. **2025-11-02**: ebay_listings_viewer_fixes_20251102
   - Fixed stamp category bug (262042 → 260)
   - Fixed SKU prefix (PC- → STAMP-)  
   - Enhanced sync to insert new eBay listings
   - Added XML parsing safety checks
   - eBay API sync still failing - needs debugging

2. **2025-11-01**: ebay_scheduled_listing_backend_complete_20251101
   - Scheduled listing backend with timezone handling

3. **2025-11-01**: stamp_ai_extraction_complete_fix_20251101
   - Fixed three critical stamp extraction bugs

4. **2025-10-31**: stamp_ui_differentiation_purple_theme_20251031
   - Purple theme for stamps tab

## How to Use This Index

1. **Starting new work?** Check "Current Implementation Status" and relevant feature area
2. **Fixing bugs?** Look in "Bug Fixes & Resolutions" and feature-specific memories
3. **Adding features?** Review architecture, constraints, and similar feature implementations
4. **Before committing?** Check "Testing Infrastructure" and run critical tests

## Archive (Historical/Superseded)

These memories contain outdated information but kept for reference:
- session_failed_analysis_20251011
- llm_settings_incomplete_20251007
- DEDUPLICATION_FINAL_STATUS_20251013
- SESSION_SUMMARY_DEDUPLICATION_20251013

## Notes

- Memories prefixed with dates show implementation completion
- "complete" suffix indicates feature is fully implemented
- "fix" suffix indicates bug resolution
- Always check LATEST tag for most recent work in each area
