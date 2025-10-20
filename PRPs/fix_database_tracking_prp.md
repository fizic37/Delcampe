# Product Requirements Prompt (PRP): Fix Database Tracking Issues

**Date:** October 14, 2025  
**Version:** 1.0  
**Type:** Bug Fix / Improvement  
**Priority:** HIGH  

## Executive Summary

This PRP addresses critical database tracking issues in the Delcampe postal card processor application. The system currently has a 3-layer database architecture for tracking uploads, processing, and AI extraction, but two key issues prevent proper functionality:

1. **Verso upload tracking not working properly** - The verso (back) side uploads are not being tracked correctly in the database
2. **AI extraction data not updating UI fields** - When duplicate images are detected, the AI extraction data exists in the database but doesn't populate the UI form fields

## Problem Statement

### Issue 1: Verso Upload Tracking
- **Current State:** Verso images are uploaded but not properly tracked in the `postal_cards` and `card_processing` tables
- **Expected State:** Verso uploads should create/update database records just like face uploads
- **Impact:** Users lose processing history for verso images, deduplication doesn't work for verso

### Issue 2: AI Extraction UI Update
- **Current State:** When a duplicate combined image is detected with existing AI data, the extraction UI loads but fields remain empty
- **Expected State:** If AI data exists for a combined image, the extraction UI should auto-populate with saved data
- **Impact:** Users must re-extract AI data even when it already exists, wasting API calls and time

## Technical Context

### Current Architecture

The system uses a 3-layer database architecture:

```
Layer 1: postal_cards (master table)
  - Unique by file_hash + image_type
  - Tracks all unique images ever uploaded
  
Layer 2: card_processing (processing results)
  - One-to-one with postal_cards
  - Stores crop boundaries, grid config, AI extraction data
  - Uses UPSERT pattern for updates
  
Layer 3: session_activity (audit log)
  - Tracks every action in every session
  - Links sessions to cards and processing
```

### Key Files

1. **R/tracking_database.R** - Database functions and schema
2. **R/mod_postal_card_processor.R** - Face/verso upload and processing UI/server
3. **R/mod_ai_extraction.R** - AI extraction module
4. **R/mod_delcampe_ui.R** - Main UI coordinator module

### Current Flow

1. User uploads face image → `get_or_create_card()` → stores in DB
2. User uploads verso image → `get_or_create_card()` → stores in DB
3. User adjusts crops and extracts → `save_card_processing()` → stores boundaries
4. User combines images → creates combined image
5. User extracts AI data → saves to `card_processing` table
6. On re-upload → `find_card_processing()` → shows modal if duplicate

## Requirements

### Functional Requirements

#### FR1: Fix Verso Upload Tracking
- Verso uploads MUST call `get_or_create_card()` with correct parameters
- Verso uploads MUST track in `session_activity` table
- Verso processing MUST save to `card_processing` table
- Duplicate verso detection MUST work like face detection

#### FR2: Fix AI Extraction UI Population
- When combined image has existing AI data, fields MUST auto-populate
- Title, description, condition, and price fields MUST show saved values
- User MUST be able to edit pre-populated values
- System MUST indicate when using previously extracted data

### Technical Requirements

#### TR1: Database Consistency
- All database operations MUST handle NULL values properly (use NA_* types)
- JSON fields MUST be properly serialized/deserialized
- Foreign key relationships MUST be maintained

#### TR2: Module Communication
- Modules MUST properly pass card_id between components
- Reactive values MUST trigger UI updates when data loads
- Session tokens MUST be used consistently for tracking

### Non-Functional Requirements

#### NFR1: User Experience
- Loading existing data MUST be faster than re-extraction
- User MUST receive clear notifications about data reuse
- System MUST NOT lose user data during updates

#### NFR2: Performance
- Database queries MUST use indexes efficiently
- Duplicate checking MUST complete within 100ms
- UI updates MUST be reactive and immediate

## Implementation Plan

### Phase 1: Fix Verso Upload Tracking

#### Step 1.1: Analyze Verso Module Instance
**File:** `R/mod_delcampe_ui.R`
- Locate verso module server call
- Verify card_type parameter is "verso"
- Check that database tracking callbacks are connected

#### Step 1.2: Fix Verso Upload Observer
**File:** `R/mod_postal_card_processor.R` (verso instance)
- Ensure image upload observer calls `get_or_create_card()`
- Verify `image_type = "verso"` is passed correctly
- Add debug logging to trace execution

#### Step 1.3: Fix Verso Extraction Tracking
**File:** `R/mod_postal_card_processor.R` (lines ~800-850)
- Ensure extraction calls `save_card_processing()`
- Verify card_id is available in reactive values
- Track extraction in `session_activity`

### Phase 2: Fix AI Extraction UI Population

#### Step 2.1: Trace Data Flow
**File:** `R/mod_ai_extraction.R`
- Identify where existing_card_data is loaded
- Trace how data flows to UI outputs
- Find reactive trigger for UI updates

#### Step 2.2: Implement UI Population
**File:** `R/mod_ai_extraction.R` (UI rendering section)
- Add observer for `rv$existing_card_data`
- Update form fields when data exists:
  ```r
  observeEvent(rv$existing_card_data, {
    if (!is.null(rv$existing_card_data)) {
      updateTextInput(session, "title", 
                     value = rv$existing_card_data$ai_title %||% "")
      updateTextAreaInput(session, "description", 
                         value = rv$existing_card_data$ai_description %||% "")
      updateSelectInput(session, "condition", 
                       selected = rv$existing_card_data$ai_condition %||% "")
      updateNumericInput(session, "price", 
                        value = rv$existing_card_data$ai_price %||% NA)
    }
  })
  ```

#### Step 2.3: Fix Combined Image Hash Calculation
**File:** `R/mod_delcampe_ui.R` (combine handler)
- Calculate hash of combined image
- Call `get_or_create_card()` for type "combined"
- Pass card_id to AI extraction module

### Phase 3: Testing & Validation

#### Test Case 1: Verso Upload Tracking
1. Upload new verso image
2. Check database for new `postal_cards` entry with type "verso"
3. Extract crops
4. Check `card_processing` has boundaries saved
5. Re-upload same verso
6. Verify modal appears with "Use Existing" option

#### Test Case 2: AI Extraction Population
1. Upload face and verso, combine
2. Extract AI data, save
3. Start new session
4. Upload same face and verso, combine
5. Navigate to AI extraction
6. Verify fields are pre-populated with saved data

## Code Snippets

### Fix 1: Verso Upload Tracking
```r
# In mod_postal_card_processor.R (verso instance)
observeEvent(input$image_upload, {
  # ... existing code ...
  
  # FIX: Ensure verso tracking
  image_hash <- calculate_image_hash(upload_path)
  rv$current_image_hash <- image_hash
  
  # Get or create card with correct type
  card_id <- get_or_create_card(
    file_hash = image_hash,
    image_type = "verso",  # CRITICAL: Must be "verso" not card_type variable
    original_filename = file_info$name,
    file_size = file.info(upload_path)$size,
    dimensions = NULL
  )
  
  rv$current_card_id <- card_id
  
  # Track activity
  track_session_activity(
    session_id = session$token,
    card_id = card_id,
    action = "uploaded",
    details = list(type = "verso")
  )
  
  message("✅ Verso tracked - Card ID: ", card_id)
})
```

### Fix 2: AI Extraction UI Population
```r
# In mod_ai_extraction.R
observe({
  req(rv$existing_card_data)
  
  # Update all form fields with existing data
  isolate({
    # Title field
    if (!is.null(rv$existing_card_data$ai_title)) {
      updateTextInput(session_inner, "title_input", 
                     value = rv$existing_card_data$ai_title)
    }
    
    # Description field  
    if (!is.null(rv$existing_card_data$ai_description)) {
      updateTextAreaInput(session_inner, "description_input", 
                         value = rv$existing_card_data$ai_description)
    }
    
    # Condition field
    if (!is.null(rv$existing_card_data$ai_condition)) {
      updateSelectInput(session_inner, "condition_input", 
                       selected = rv$existing_card_data$ai_condition)
    }
    
    # Price field
    if (!is.null(rv$existing_card_data$ai_price)) {
      updateNumericInput(session_inner, "price_input", 
                        value = rv$existing_card_data$ai_price)
    }
  })
  
  showNotification(
    "📝 Loaded existing AI extraction data",
    type = "message",
    duration = 5,
    session = notification_session
  )
})
```

## Success Criteria

### Acceptance Criteria
1. ✅ Verso uploads create database records with type="verso"
2. ✅ Verso crops are saved to `card_processing` table
3. ✅ Duplicate verso images trigger reuse modal
4. ✅ Combined images with existing AI data auto-populate form fields
5. ✅ Users can edit pre-populated AI data and save updates
6. ✅ All database operations handle NULL values correctly

### Performance Criteria
- Database queries complete in < 100ms
- UI updates occur within 200ms of data load
- No memory leaks or orphaned database records

### Quality Criteria
- No regression in existing functionality
- All error cases handled gracefully
- Comprehensive logging for debugging

## Risk Mitigation

### Risk 1: Database Migration
- **Risk:** Existing data might be incompatible
- **Mitigation:** Use UPSERT pattern, don't modify schema

### Risk 2: Module Communication
- **Risk:** Reactive dependencies might break
- **Mitigation:** Use isolate() to prevent cascading updates

### Risk 3: Race Conditions
- **Risk:** Async operations might conflict
- **Mitigation:** Use database transactions where possible

## Testing Checklist

### Pre-Implementation
- [ ] Backup current database
- [ ] Document current behavior with screenshots
- [ ] Create test images (face and verso pairs)

### Post-Implementation
- [ ] Verso upload creates DB record
- [ ] Verso extraction saves boundaries
- [ ] Verso duplicate detection works
- [ ] AI data auto-populates for combined duplicates
- [ ] Fields are editable after population
- [ ] Updates save correctly to database
- [ ] No regression in face processing
- [ ] No regression in combine functionality

## Rollback Plan

If issues occur:
1. Restore backed up database
2. Revert code changes via git
3. Clear browser cache
4. Restart R session

## Documentation Updates

After successful implementation:
1. Update `.serena/memories/` with fix details
2. Add test cases to `tests/` directory
3. Update user guide if UI behavior changes
4. Document any new reactive dependencies

## Appendix A: Database Schema Reference

```sql
-- Relevant tables for this fix
CREATE TABLE postal_cards (
  card_id INTEGER PRIMARY KEY,
  file_hash TEXT UNIQUE NOT NULL,
  image_type TEXT NOT NULL,  -- 'face', 'verso', or 'combined'
  -- ... other fields
);

CREATE TABLE card_processing (
  processing_id INTEGER PRIMARY KEY,
  card_id INTEGER UNIQUE NOT NULL,
  crop_paths TEXT,           -- JSON array of paths
  h_boundaries TEXT,          -- JSON array of boundaries
  v_boundaries TEXT,          -- JSON array of boundaries
  ai_title TEXT,              -- AI extracted title
  ai_description TEXT,        -- AI extracted description
  ai_condition TEXT,          -- AI extracted condition
  ai_price REAL,              -- AI extracted price
  ai_model TEXT,              -- Model used for extraction
  -- ... other fields
);
```

## Appendix B: Module Communication Flow

```
mod_delcampe_ui (orchestrator)
  ├── mod_postal_card_processor (face)
  │     └── tracks: get_or_create_card() → save_card_processing()
  ├── mod_postal_card_processor (verso)
  │     └── tracks: get_or_create_card() → save_card_processing()
  ├── combine_handler
  │     └── creates combined image → get_or_create_card(type="combined")
  └── mod_ai_extraction
        └── reads: find_card_processing() → populate UI
        └── writes: save_card_processing() with AI data
```

## Appendix C: Debugging Commands

```r
# Check verso tracking
DBI::dbGetQuery(con, "SELECT * FROM postal_cards WHERE image_type = 'verso'")

# Check AI data
DBI::dbGetQuery(con, "
  SELECT card_id, ai_title, ai_description, ai_condition, ai_price 
  FROM card_processing 
  WHERE ai_title IS NOT NULL
")

# Check session activity
DBI::dbGetQuery(con, "
  SELECT * FROM session_activity 
  WHERE action IN ('uploaded', 'ai_extracted')
  ORDER BY timestamp DESC LIMIT 20
")
```

---

**END OF PRP**

This PRP provides comprehensive context for fixing the database tracking issues. Use Serena's semantic search and code modification tools to implement these fixes systematically.