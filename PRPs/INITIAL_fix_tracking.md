# INITIAL: Fix Database Tracking Issues in Delcampe

## FEATURE:
Fix two critical database tracking issues in the Delcampe postal card processor application:

1. **Verso upload tracking is broken** - When users upload verso (back) images, the database tracking doesn't work properly. The system should track verso uploads in the `postal_cards` and `card_processing` tables just like it does for face uploads, enabling deduplication and processing history.

2. **AI extraction data doesn't populate UI fields** - When users process a duplicate combined image that already has AI-extracted data in the database, the extraction UI loads empty instead of showing the previously extracted title, description, condition, and price. The system should auto-populate these fields from the database when available.

## CONTEXT:
The application uses a 3-layer database architecture:
- **postal_cards**: Master table tracking unique images by hash
- **card_processing**: Stores processing results including crop boundaries and AI data
- **session_activity**: Audit log of all actions

The system already successfully implements deduplication for face images and shows a modal when duplicates are detected. The same functionality needs to work for verso images, and the AI extraction module needs to properly retrieve and display existing data.

## EXAMPLES:
Key files that demonstrate current patterns:
- `R/tracking_database.R` - Database functions using the 3-layer architecture
- `R/mod_postal_card_processor.R` - Module handling face/verso upload and processing
- `R/mod_ai_extraction.R` - AI extraction module that should populate fields
- `.serena/memories/DEDUPLICATION_FINAL_STATUS_20251013.md` - Documents working deduplication for face images

## TECHNICAL CONSTRAINTS:
- Must use existing 3-layer database architecture (don't modify schema)
- Must follow Golem framework patterns
- Must use existing `get_or_create_card()` and `save_card_processing()` functions
- Must maintain backward compatibility with existing data
- Use R with Shiny modules, reticulate for Python integration
- SQLite database with proper NULL handling (use NA_* types in R)

## CURRENT BEHAVIOR:
1. Face upload → Creates card in DB → Deduplication works → Modal appears for duplicates ✅
2. Verso upload → May not create proper DB entry → Deduplication fails ❌
3. Combined image with AI data → Data exists in DB → UI fields remain empty ❌

## EXPECTED BEHAVIOR:
1. Verso upload → Creates card with type="verso" → Deduplication works → Modal appears
2. Combined image with existing AI data → Fields auto-populate with saved values → User can edit

## DEBUGGING HINTS:
- Verso module might not be passing `image_type = "verso"` correctly to database functions
- AI extraction module loads `rv$existing_card_data` but might not trigger UI updates
- Check reactive dependencies and observers for field updates
- Module communication through parent session might be dropping card_id
- Be consistent about feeding images location

## OTHER CONSIDERATIONS:
- The system uses `calculate_image_hash()` for MD5 hashing to detect duplicates
- JSON fields in database need proper serialization/deserialization
- Module namespacing in Shiny can cause issues with UI updates
- Previous successful implementation for face images can serve as reference
- User should see notifications when existing data is loaded
- Performance is important - duplicate checks should be fast (<100ms)

## SUCCESS CRITERIA:
- Verso uploads create entries in `postal_cards` table with correct image_type
- Duplicate verso images trigger the reuse modal
- AI extraction fields populate automatically when data exists
- Users can edit and save updates to pre-populated data
- No regression in existing face/combine functionality
