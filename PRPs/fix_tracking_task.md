# Fix Database Tracking Issues

## Problem Description

Two critical database tracking issues prevent proper functionality in the Delcampe postal card processor:

1. **Verso upload tracking fails** - Verso (back) images don't create proper database records in the 3-layer architecture (postal_cards, card_processing, session_activity tables), breaking deduplication.

2. **AI extraction fields stay empty** - When processing duplicate combined images with existing AI data, the extraction UI doesn't populate saved title, description, condition, and price fields.

## Affected Components

- `R/mod_postal_card_processor.R` - Verso instance not calling `get_or_create_card()` with correct parameters
- `R/mod_ai_extraction.R` - Loads `rv$existing_card_data` but doesn't update UI input fields  
- `R/tracking_database.R` - Database functions work correctly, issue is in module integration
- `R/mod_delcampe_ui.R` - Orchestrates modules, may not pass card_id properly

## Current vs Expected

**Current:**
- Face uploads → DB tracking works → Deduplication works ✅
- Verso uploads → DB tracking fails → No deduplication ❌  
- Combined image with AI data → Data in DB → Fields empty ❌

**Expected:**
- Verso uploads → Creates card with type="verso" → Deduplication modal appears
- Combined image with AI data → Fields auto-populate → User can edit/save

## Key Context

- System uses 3-layer database architecture (see `.serena/memories/DEDUPLICATION_FINAL_STATUS_20251013.md`)
- Face upload deduplication already works perfectly - use as reference pattern
- Database functions (`get_or_create_card`, `save_card_processing`) are correct
- Issue is in module integration and UI update triggers

## Technical Details

- MD5 hash via `calculate_image_hash()` for deduplication
- JSON fields need proper serialization (`jsonlite::toJSON/fromJSON`)
- NULL values must use NA_* types for SQL parameters (NA_character_, NA_integer_, NA_real_)
- Module namespacing can affect UI updates - use `session_inner` for module updates

## Acceptance Criteria

1. Verso uploads create `postal_cards` entries with `image_type = "verso"`
2. Verso processing saves boundaries to `card_processing` table
3. Duplicate verso triggers reuse modal (like face does)
4. AI extraction fields populate when `existing_card_data` exists
5. Populated fields are editable and save updates correctly
6. No regression in face/combine functionality