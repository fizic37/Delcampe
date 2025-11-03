# eBay Scheduled Listing - Backend Implementation Complete

**Date**: 2025-11-01
**Status**: ✅ BACKEND COMPLETE (UI Pending)
**Priority**: HIGH

## Summary

Successfully implemented the backend infrastructure for eBay scheduled listing functionality. Users can schedule listings to start at a specific future time, with smart default of next 10:00 AM Pacific Time.

**Phases 1-4 Complete (Backend)**: Time utilities, database, Trading API, integration layer
**Phases 5-6 Pending (Frontend)**: UI for postcards and stamps modules
**Phase 7 Pending**: Final testing and validation

## Files Modified

### Backend (Complete)
1. **R/ebay_time_helpers.R** (NEW) - Time zone utilities
   - `calculate_next_10am_pacific()` - Calculates next 10 AM PDT/PST
   - `format_ebay_schedule_time()` - ISO 8601 formatter for eBay API
   - `validate_schedule_time()` - Validates eBay's 1 hour min, 3 weeks max
   - `format_display_time()` - User-friendly Pacific & Romania time display
   - `get_romania_from_utc()` - Timezone conversion helper

2. **R/ebay_database_extension.R** - Database schema + migration
   - Added `schedule_time` TEXT column (ISO 8601 format)
   - Added `is_scheduled` INTEGER column (0/1 boolean flag)
   - Added `actual_start_time` TEXT column (eBay's returned StartTime)
   - Added index on `is_scheduled` for query performance
   - Updated `save_ebay_listing()` signature with 3 new parameters
   - Updated INSERT and UPDATE queries with datetime handling

3. **R/ebay_trading_api.R** - ScheduleTime XML field + response parsing
   - Updated `build_add_item_xml()` - Adds ScheduleTime to fixed-price XML
   - Updated `build_auction_xml()` - Adds ScheduleTime to auction XML
   - Updated `parse_response()` - Extracts StartTime from eBay response

4. **R/ebay_integration.R** - Schedule parameter routing
   - Added `schedule_time_utc` parameter to `create_ebay_listing_from_card()`
   - Added schedule time validation before API call
   - Formats schedule_time for eBay API (ISO 8601)
   - Passes schedule parameters to database save function
   - Converts eBay's returned StartTime to POSIXct for database

5. **tests/testthat/test-ebay_time_helpers.R** (NEW) - Comprehensive tests
   - 27 tests covering all time helper functions
   - Tests for timezone conversion, validation, formatting
   - Edge case testing for DST transitions

6. **dev/run_critical_tests.R** - Added time helper tests to critical suite

### Frontend (Pending)
7. **R/mod_delcampe_export.R** - Needs scheduling UI controls
8. **R/mod_stamp_export.R** - Needs scheduling UI controls

## Database Schema Changes

```sql
-- New columns in ebay_listings table
ALTER TABLE ebay_listings ADD COLUMN schedule_time TEXT;
ALTER TABLE ebay_listings ADD COLUMN is_scheduled INTEGER DEFAULT 0;
ALTER TABLE ebay_listings ADD COLUMN actual_start_time TEXT;

-- New index for performance
CREATE INDEX idx_ebay_listings_is_scheduled ON ebay_listings(is_scheduled);
```

## Key Implementation Decisions

### Timezone Handling
- **Always use named timezones**: "America/Los_Angeles" and "Europe/Bucharest"
- R automatically handles DST transitions (PDT/PST switch)
- Display both Pacific and Romania times for transparency
- Store times in UTC in database (as TEXT in ISO 8601 format)

### Default Behavior (User Confirmed)
- **Scheduling ON by default**: Next 10:00 AM Pacific Time
- Users must CHECK "List Immediately" to skip scheduling
- UI placement: Inline with listing fields (not separate card)
- Timezone label: Generic "Pacific Time" (not explicit PDT/PST)

### Validation Rules (eBay Requirements)
- Minimum: 1 hour in the future
- Maximum: 3 weeks (21 days) in the future
- Must be valid POSIXct object in UTC timezone

### Backward Compatibility
- All existing code works unchanged
- `schedule_time_utc = NULL` (default) creates immediate listing
- No breaking changes to existing functions

## Testing

### Unit Tests (Complete)
- **test-ebay_time_helpers.R**: 27 tests, all passing
- Tests cover:
  - Next 10 AM calculation
  - ISO 8601 formatting
  - Validation (past, too soon, too far, valid)
  - Timezone conversion (Pacific, Romania, UTC)
  - Display formatting
  - Edge cases

### Integration Tests (Pending)
- Requires UI implementation to test end-to-end
- Manual sandbox test pending (Phase 7)

## API Integration Details

### eBay Trading API
- **ScheduleTime Field**: Added to `<Item>` element (early in XML)
- **Format**: YYYY-MM-DDTHH:MM:SS.SSSZ (ISO 8601 with milliseconds)
- **Response**: eBay returns `<StartTime>` in response
- **Behavior**: Listing not visible until scheduled time

### Database Storage
- `schedule_time`: Stored as TEXT in format "%Y-%m-%d %H:%M:%S"
- `is_scheduled`: Stored as INTEGER (0/1) for quick queries
- `actual_start_time`: eBay's returned StartTime (may differ slightly from requested)

## Next Steps - UI Implementation

### PHASE 5: Postcard Module UI
File: `R/mod_delcampe_export.R`

Need to add (per TASK PRP):
1. Checkbox: "List Immediately" (unchecked by default)
2. Date input: Schedule date (default: next 10 AM date)
3. Hour select: 00-23 (default: "10")
4. Minute select: 00, 15, 30, 45 (default: "00")
5. Display: Show both Pacific and Romania times
6. Observer: Calculate and set default on card load
7. RenderUI: Dynamic schedule display with warning
8. Confirmation modal: Show schedule in confirmation
9. Send observer: Read inputs, validate, pass to modal
10. Confirm observer: Pass schedule_time_utc to integration function

### PHASE 6: Stamp Module UI
File: `R/mod_stamp_export.R`

Same changes as Phase 5, applied to stamp module.

### PHASE 7: Final Testing
1. Add comprehensive integration tests
2. Run critical test suite
3. Manual sandbox test:
   - Create scheduled listing
   - Verify not visible on eBay
   - Verify database records
   - Test immediate listing (backward compat)

## Known Limitations

- No rescheduling UI (must recreate listing to change schedule)
- No calendar view of scheduled listings
- DST transitions may need verification during March/November

## References

- **TASK PRP**: `TASK_PRP/PRPs/PRP_EBAY_SCHEDULED_LISTING_10AM_PDT.md`
- **Main PRP**: `PRPs/PRP_EBAY_SCHEDULED_LISTING_10AM_PDT.md`
- **eBay API Docs**: https://developer.ebay.com/devzone/xml/docs/reference/ebay/additem.html
- **Testing Guide**: `dev/TESTING_GUIDE.md`

## Code Patterns for Frontend Implementation

### Pattern 1: Conditional UI (Inline Placement)
```r
# Inside accordion for each card, after listing type/duration fields
checkboxInput(ns(paste0("list_immediately_", idx)), "List Immediately", value = FALSE),
conditionalPanel(
  condition = sprintf("!input['%s']", ns(paste0("list_immediately_", idx))),
  dateInput(ns(paste0("schedule_date_", idx)), "Date (Pacific)", value = Sys.Date()),
  selectInput(ns(paste0("schedule_hour_", idx)), "Hour", choices = sprintf("%02d", 0:23), selected = "10"),
  selectInput(ns(paste0("schedule_minute_", idx)), "Minute", choices = sprintf("%02d", c(0, 15, 30, 45)), selected = "00"),
  uiOutput(ns(paste0("schedule_display_", idx)))
)
```

### Pattern 2: Default Calculation Observer
```r
observe({
  req(ai_extractions[[i]])
  next_10am <- calculate_next_10am_pacific()
  pacific_time <- as.POSIXct(format(next_10am, tz = "America/Los_Angeles"), tz = "America/Los_Angeles")
  updateDateInput(session, paste0("schedule_date_", i), value = as.Date(pacific_time))
  updateSelectInput(session, paste0("schedule_hour_", i), selected = sprintf("%02d", as.integer(format(pacific_time, "%H"))))
})
```

### Pattern 3: Display RenderUI
```r
output[[paste0("schedule_display_", i)]] <- renderUI({
  req(input[[paste0("schedule_date_", i)]])
  # Build Pacific time from inputs, convert to UTC and Romania
  # Show both times with warning about scheduling fee
})
```

### Pattern 4: Validation and Pass to Integration
```r
observeEvent(input[[paste0("confirm_send_to_ebay_", i)]], {
  list_immediately <- input[[paste0("list_immediately_", i)]]
  schedule_time_utc <- NULL
  if (!list_immediately) {
    # Build from inputs, validate
    schedule_time_utc <- as.POSIXct(sprintf("%s %s:%s:00", date, hour, minute), tz = "America/Los_Angeles")
    schedule_time_utc <- as.POSIXct(format(schedule_time_utc, tz = "UTC"), tz = "UTC")
    validation <- validate_schedule_time(schedule_time_utc)
    if (!validation$valid) { showNotification(validation$error, type = "error"); return() }
  }
  result <- create_ebay_listing_from_card(..., schedule_time_utc = schedule_time_utc)
})
```

## Success Criteria

### Backend (COMPLETE ✅)
- ✅ Phase 1: Time utilities implemented and tested (27 tests passing)
- ✅ Phase 2: Database migration complete, save_ebay_listing() updated
- ✅ Phase 3: Trading API updated (build_add_item_xml, build_auction_xml, parse_response)
- ✅ Phase 4: Integration layer updated (create_ebay_listing_from_card)
- ✅ Tests added to critical suite

### Frontend (PENDING ⏳)
- ⏳ Phase 5: Postcard module UI implementation
- ⏳ Phase 6: Stamp module UI implementation
- ⏳ Phase 7: Manual sandbox testing and validation

## Estimated Remaining Work

- Phase 5 (Postcard UI): 1.5 hours
- Phase 6 (Stamp UI): 1 hour
- Phase 7 (Testing): 1 hour
- **Total remaining**: ~3.5 hours

---

**Backend Status**: ✅ COMPLETE AND TESTED
**Next Action**: Implement UI in mod_delcampe_export.R (Phase 5)
