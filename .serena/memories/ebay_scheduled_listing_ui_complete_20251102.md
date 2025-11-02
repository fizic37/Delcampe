# eBay Scheduled Listing UI Implementation - Complete

**Date**: 2025-11-02  
**Status**: ✅ Complete and Working  
**Related**: `ebay_scheduled_listing_backend_complete_20251101.md`

## Summary

Successfully implemented the frontend UI for eBay scheduled listings in both the Postcard and Stamp export modules. Users can now schedule listings to start at a specific time (default: next 10 AM Pacific) or list immediately.

## Implementation Details

### Files Modified

1. **`R/mod_delcampe_export.R`** (Postcard Module)
   - Added schedule UI controls (lines 430-497)
   - Added default schedule observer (lines 1544-1580)
   - Added schedule display renderUI (lines 1582-1627)
   - Added schedule reading logic in send_to_ebay observer (lines 1627-1665)
   - Updated modal call with schedule parameter (line 1717)
   - Updated modal function to display schedule (lines 568-670)
   - Updated confirm observer with schedule logic (lines 1818-1899)

2. **`R/mod_stamp_export.R`** (Stamp Module)
   - Applied identical changes as postcard module
   - All 7 tasks implemented with same logic
   - Category label: "Stamps" (vs "Postcards")

### UI Components Added

#### Schedule Controls
```r
# "List Immediately" checkbox (default: unchecked = scheduled)
checkboxInput(ns(paste0("list_immediately_", idx)), ...)

# Date picker (Pacific timezone)
dateInput(ns(paste0("schedule_date_", idx)), ...)

# Hour/Minute selectors
selectInput(ns(paste0("schedule_hour_", idx)), ...)
selectInput(ns(paste0("schedule_minute_", idx)), ...)

# Dynamic display showing Pacific + Romania times
uiOutput(ns(paste0("schedule_display_", idx)))
```

#### Default Behavior
- Listings default to **scheduled** (not immediate)
- Auto-sets to next 10 AM Pacific when accordion opens
- Uses `calculate_next_10am_pacific()` from backend

#### Schedule Display
- Shows **dual timezones**: Pacific and Romania
- Updates reactively when user changes time
- Displays warnings:
  - "⚠️ Listing will NOT be visible until scheduled time"
  - "💵 eBay charges $0.10 scheduling fee"

### Backend Integration

#### Schedule Data Flow
1. **UI Input** → Pacific time (date + hour + minute)
2. **Conversion** → UTC via `as.POSIXct(format(pacific_time, tz = "UTC"), tz = "UTC")`
3. **Validation** → `validate_schedule_time(schedule_time_utc)` (1 hour min, 3 weeks max)
4. **Database** → `schedule_time_utc` passed to `create_ebay_listing_from_card()`
5. **eBay API** → Formatted via `format_ebay_schedule_time()` as ISO 8601

#### Parameters Passed
```r
create_ebay_listing_from_card(
  card_id = ...,
  # ... other params ...
  schedule_time_utc = schedule_time_utc,  # NULL for immediate
  progress_callback = ...
)
```

### Bug Fixes Applied

#### Bug #1: Observer Trigger
**Issue**: `req(ai_extractions[[i]])` referenced non-existent variable  
**Fix**: Changed to `req(image_paths()); req(length(image_paths()) >= i)`  
**Files**: Both modules (delcampe line 1547, stamp line 1562)

#### Bug #2: Parameter Name
**Issue**: Stamp module used `stamp_id` instead of `card_id`  
**Error**: `unused argument (stamp_id = ...)`  
**Fix**: Changed to `card_id` (line 1904 in stamp module)

## User Experience

### Default Flow
1. User uploads images
2. Opens accordion panel for an image
3. **Schedule UI auto-fills** with next 10 AM Pacific
4. Schedule display shows: "🇺🇸 Pacific: Sat Nov 02, 10:00 AM PST" / "🇷🇴 Romania: Sat Nov 02, 19:00 EET"
5. User clicks "Send to eBay"
6. **Confirmation modal** shows schedule details
7. Listing created with `ScheduleTime` in XML

### Immediate Listing Flow
1. User checks "List Immediately (skip scheduling)"
2. Schedule controls hide
3. Modal shows: "Start Time: Immediately after creation"
4. Listing created without `ScheduleTime` (backward compatible)

## Testing Results

✅ **Syntax Validation**: Both modules parse successfully  
✅ **Manual Testing**: Feature working in production  
✅ **Backward Compatibility**: Immediate listings still work  
✅ **Both Modules**: Identical functionality for postcards and stamps

## Key Design Decisions

### 1. Default to Scheduled (Not Immediate)
- **Rationale**: Primary use case is scheduling for next 10 AM Pacific
- **UX**: Checkbox is unchecked by default = scheduled
- **Override**: Easy to check "List Immediately" if needed

### 2. Dual Timezone Display
- **Pacific**: eBay's primary timezone
- **Romania**: User's local timezone
- **Format**: Human-readable with day/date/time

### 3. Conditional UI
- Uses Shiny's `conditionalPanel` with JavaScript condition
- Schedule controls only visible when NOT listing immediately
- Clean, uncluttered interface

### 4. Reactive Updates
- `renderUI()` for dynamic schedule display
- Automatically recalculates when user changes date/hour/minute
- No page reload needed

## Helper Functions Used

From `R/ebay_time_helpers.R`:
- `calculate_next_10am_pacific()` - Returns next 10 AM Pacific in UTC
- `validate_schedule_time()` - Enforces eBay's 1-hour min, 3-week max
- `format_display_time()` - Formats for modal display (Pacific + Romania)
- `format_ebay_schedule_time()` - ISO 8601 for API (used in backend)

## Database Schema

Columns used (from `ebay_listings` table):
- `schedule_time` (TEXT) - ISO 8601 format
- `is_scheduled` (INTEGER) - 0 or 1
- `actual_start_time` (TEXT) - When eBay actually started the listing

## Code Patterns

### Observer Pattern
```r
observe({
  req(image_paths())
  req(length(image_paths()) >= i)
  
  next_10am <- calculate_next_10am_pacific()
  pacific_time <- as.POSIXct(format(next_10am, tz = "America/Los_Angeles"), 
                              tz = "America/Los_Angeles")
  
  updateDateInput(session, paste0("schedule_date_", i), value = as.Date(pacific_time))
  updateSelectInput(session, paste0("schedule_hour_", i), selected = ...)
  updateSelectInput(session, paste0("schedule_minute_", i), selected = ...)
})
```

### RenderUI Pattern
```r
output[[paste0("schedule_display_", i)]] <- renderUI({
  req(input[[paste0("schedule_date_", i)]])
  req(input[[paste0("schedule_hour_", i)]])
  req(input[[paste0("schedule_minute_", i)]])
  
  # Build Pacific time from inputs
  pacific_str <- sprintf("%s %s:%s:00", date, hour, minute)
  pacific_time <- as.POSIXct(pacific_str, tz = "America/Los_Angeles", ...)
  
  # Convert to UTC and Romania
  utc_time <- as.POSIXct(format(pacific_time, tz = "UTC"), tz = "UTC")
  romania_time <- as.POSIXct(format(utc_time, tz = "Europe/Bucharest"), ...)
  
  # Render display
  div(...)
})
```

### Schedule Reading Pattern
```r
list_immediately <- input[[paste0("list_immediately_", i)]]
schedule_time_utc <- NULL

if (!isTRUE(list_immediately)) {
  # Build Pacific time from inputs
  pacific_str <- sprintf("%s %s:%s:00", schedule_date, schedule_hour, schedule_minute)
  pacific_time <- as.POSIXct(pacific_str, tz = "America/Los_Angeles", ...)
  schedule_time_utc <- as.POSIXct(format(pacific_time, tz = "UTC"), tz = "UTC")
  
  # Validate
  validation <- validate_schedule_time(schedule_time_utc)
  if (!validation$valid) {
    showNotification(validation$error, type = "error")
    return()
  }
}
```

## Edge Cases Handled

1. **DST Transitions**: R's timezone library handles automatically
2. **Past Times**: Validation blocks via `validate_schedule_time()`
3. **eBay Limits**: Max 3 weeks enforced in `dateInput` max parameter
4. **Invalid Times**: Min 1 hour enforced in validation
5. **NULL Schedule**: Immediate listings pass `schedule_time_utc = NULL`

## Performance

- **Minimal Overhead**: Logic only runs when schedule checkbox unchecked
- **No Extra API Calls**: Schedule time included in existing request
- **Reactive Updates**: Efficient renderUI updates
- **No Page Reload**: All updates client-side

## Related Files

- Backend: `R/ebay_time_helpers.R`
- Database: `R/ebay_database_extension.R`
- API: `R/ebay_trading_api.R`
- Integration: `R/ebay_integration.R`
- Tests: `tests/testthat/test-ebay_time_helpers.R`
- Memory: `.serena/memories/ebay_scheduled_listing_backend_complete_20251101.md`

## Future Enhancements

- [ ] Add "Schedule for tomorrow 10 AM" quick button
- [ ] Save user's preferred schedule time
- [ ] Bulk scheduling for multiple images
- [ ] Calendar view for scheduled listings

## Success Criteria

✅ User can schedule listings for next 10 AM Pacific (default)  
✅ User can customize schedule date/time  
✅ User can bypass scheduling with "List Immediately"  
✅ Schedule displays in both Pacific and Romania time  
✅ Validation prevents invalid schedules  
✅ Database correctly records schedule metadata  
✅ eBay receives ScheduleTime in API request  
✅ No regressions in immediate listing functionality  
✅ Code follows existing patterns and conventions  
✅ Both postcard and stamp modules work identically
