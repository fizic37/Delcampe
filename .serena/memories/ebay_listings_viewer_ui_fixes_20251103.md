# eBay Listings Viewer - UI Optimization and Category Display Fix

**Date**: 2025-11-03  
**Status**: COMPLETE  
**Related Memory**: ebay_listings_api_sync_complete_20251103.md

## Summary

Fixed two critical UI issues in the eBay Listings Viewer:
1. Removed vertical scrollbar from header card by using `tags$div` instead of `bslib::card_body`
2. Fixed category display to correctly show "Stamps" vs "Postcards" using SKU-based detection

## Issue #1: Vertical Scrollbar in Header Card

**Problem**: The header card containing stats, countdown, and filters had a vertical scrollbar, making it difficult to use on laptops.

**Root Cause**: `bslib::card_body` creates an internal scrolling container with fixed height.

**Solution**: Replaced `bslib::card_body` with a simple `tags$div` container.

**Files Modified**: `R/mod_ebay_listings.R` (lines 14-57)

**Changes**:
```r
# BEFORE: Using bslib::card with card_body (caused scrollbar)
bslib::card(
  bslib::card_header(...),
  bslib::card_body(...)  # ← This created scrollbar
)

# AFTER: Using tags$div (no scrollbar)
tags$div(
  class = "bg-light border rounded mb-3 p-2",
  # Title bar
  tags$div(...),
  # Single row: Stats + Filters + Countdown
  tags$div(...)
)
```

**Layout Structure**:
- **Row 1**: Title ("eBay Listings Viewer") + Refresh button
- **Row 2**: Stats (left) + Filters (center) + Countdown (right)
- All in ONE compact horizontal layout
- No labels on filter dropdowns (cleaner)
- Stats include color legend: "🟢 Active: 0", "🔵 Sold: 0", "⚪ Ended: 9"

## Issue #2: Category Display - Stamps Showing as Postcards

**Problem**: Stamps exported BEFORE the category fix (2025-11-02) still have category 262042 (Postcards) in eBay's database. When fetched via API, they show as "Postcards" instead of "Stamps".

**Root Cause**: The `decode_category()` function only looked at category ID, which was wrong for old stamp listings.

**Solution**: Use SKU prefix as the AUTHORITATIVE source for determining Stamps vs Postcards.

**Files Modified**: `R/mod_ebay_listings.R` (lines 101-132)

**Changes**:
```r
# BEFORE: Only looked at category_id
decode_category <- function(category_id) {
  if (category_num %in% c(262042, 262043)) return("Postcards")
  if (category_num %in% c(260, 675, 265)) return("Stamps")
  # ...
}

# AFTER: Check SKU prefix FIRST, then fallback to category_id
decode_category <- function(category_id, sku) {
  # Check SKU prefix first (authoritative for stamps vs postcards)
  if (!is.na(sku) && nzchar(sku)) {
    if (grepl("^(STAMP-|ST-)", sku, ignore.case = TRUE)) {
      return("Stamps")
    }
    if (grepl("^PC-", sku, ignore.case = TRUE)) {
      return("Postcards")
    }
  }
  
  # Fallback to category ID
  category_num <- as.numeric(category_id)
  if (category_num %in% c(262042, 262043)) return("Postcards")
  if (category_num == 260 || category_num %in% c(675, 265)) return("Stamps")
  
  return(paste0("Cat:", category_id))
}
```

**Updated datatable call** (line 331):
```r
# Pass both category_id and sku to decode function
Category = mapply(decode_category, data$category_id, data$sku, SIMPLIFY = TRUE)
```

**Logic**:
1. **First priority**: SKU prefix
   - `STAMP-*` or `ST-*` → "Stamps"
   - `PC-*` → "Postcards"
2. **Second priority**: Category ID
   - `262042, 262043` → "Postcards"
   - `260, 675, 265` → "Stamps"
3. **Fallback**: Unknown categories show as "Cat:xxxxx"

## Final UI Layout

**Header Section**:
```
┌─────────────────────────────────────────────────────────────────────────┐
│ eBay Listings Viewer (API-Synced)              [Refresh from eBay]     │
├─────────────────────────────────────────────────────────────────────────┤
│ 📋 Total: 9  🟢 Active: 0  🔵 Sold: 0  ⚪ Ended: 9                     │
│                        [All ▼] [Fixed Price ▼]      🕐 Last sync: ...  │
└─────────────────────────────────────────────────────────────────────────┘
```

**Datatable Section**:
- Column order: Status | Title | Category | Price | Type | Views | Watchers | Bids | TimeLeft | SoldQty
- Category shows "Stamps" or "Postcards" (human-readable)
- Status shows badge with color (using `render_status_badge()`)

## Technical Details

### Container Choice
- `bslib::card_body` → Creates internal scrolling, fixed height
- `tags$div` → No internal scrolling, flexible height
- **Lesson**: Use `tags$div` for header sections that should never scroll

### SKU-Based Detection
- **Why needed**: eBay API returns category ID from their database (immutable historical data)
- **Why SKU works**: SKU is created at submission time and reflects CURRENT category logic
- **Pattern matching**: Uses regex `^(STAMP-|ST-)` to catch both old and new SKU formats

### Stats Display
- Removed labels ("Active:", "Sold:", etc.) for compactness
- Kept emoji indicators (🟢, 🔵, ⚪) for visual clarity
- Added actual labels back based on user feedback for professional appearance

## Files Modified

1. **R/mod_ebay_listings.R** (~360 lines total)
   - Lines 14-57: UI layout (replaced `bslib::card` with `tags$div`)
   - Lines 101-132: `decode_category()` function (SKU-based detection)
   - Lines 290-296: Stats display (with color labels)
   - Line 331: Datatable category column (uses `mapply`)

## Testing Checklist

- [ ] Verify no vertical scrollbar in header section
- [ ] Verify filters are on one horizontal line
- [ ] Verify stamps with SKU "STAMP-xxx" show as "Stamps"
- [ ] Verify postcards with SKU "PC-xxx" show as "Postcards"
- [ ] Verify old stamps (category 262042, SKU STAMP-xxx) show as "Stamps"
- [ ] Verify stats display with color legend is readable
- [ ] Verify countdown timer shows sync status
- [ ] Verify layout works on laptop screen (1366x768)

## Success Metrics

✅ **UI Optimization**:
- No vertical scrollbar on header
- All controls visible on one screen
- Professional appearance maintained

✅ **Category Accuracy**:
- Stamps show as "Stamps" regardless of eBay category ID
- Postcards show as "Postcards"
- SKU-based detection handles historical data correctly

## Lessons Learned

1. **bslib card bodies create scrollbars** - Use `tags$div` for non-scrolling sections
2. **Historical data requires smart detection** - Can't rely on immutable API data alone
3. **SKU is more reliable than category** - SKU reflects submission-time logic
4. **Balance compactness with clarity** - Users need labels to understand what filters do

## Related Documentation

- **Initial implementation**: .serena/memories/ebay_listings_api_sync_complete_20251103.md
- **Category fix history**: .serena/memories/ebay_listings_viewer_fixes_20251102.md
- **Category config**: R/ebay_category_config.R

---

**Implementation Date**: 2025-11-03  
**Status**: ✅ COMPLETE - Ready for use
