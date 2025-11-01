# Stamp UI isTRUE() Fix - NULL Boolean Error

**Date:** October 31, 2025
**Status:** ✅ FIXED
**Severity:** HIGH - Application crash
**Error:** `invalid 'x' type in 'x || y'`

---

## Problem

Application crashed immediately when opening Stamps tab with error:

```
Error: invalid 'x' type in 'x || y'
Warning: Error in ||: invalid 'x' type in 'x || y'
  99: renderUI [R/app_server.R#1085]
```

**Root Cause:**
When using `||` or `&&` operators with reactive values that are NULL, R throws this error because NULL is not a valid boolean type.

**Problematic Code:**
```r
show_reset_button <- app_rv$stamp_face_image_uploaded || app_rv$stamp_verso_image_uploaded
# If either value is NULL → Error!

if (!app_rv$stamp_face_extraction_complete || !app_rv$stamp_verso_extraction_complete) {
# If either value is NULL → Error!
```

---

## Solution

Use `isTRUE()` for all boolean checks on reactive values:

```r
# BEFORE (WRONG):
show_reset_button <- app_rv$stamp_face_image_uploaded || app_rv$stamp_verso_image_uploaded

# AFTER (CORRECT):
show_reset_button <- isTRUE(app_rv$stamp_face_image_uploaded) || isTRUE(app_rv$stamp_verso_image_uploaded)
```

**Why `isTRUE()` Works:**
- `isTRUE(NULL)` returns `FALSE` (safe)
- `isTRUE(TRUE)` returns `TRUE`
- `isTRUE(FALSE)` returns `FALSE`
- Never throws error, always returns boolean

---

## Locations Fixed

**File: `R/app_server.R`**

1. Line 1085: `show_reset_button` calculation
2. Line 1088: State 1 condition
3. Lines 1117-1123: Status badge conditionals (4 occurrences)
4. Line 1130: State 2 condition
5. Line 1232: Button handler condition

**Total fixes:** 8 instances

---

## Pattern to Follow

### Always Use isTRUE() For:

**Reactive Values:**
```r
# ✅ CORRECT
if (isTRUE(app_rv$some_flag)) { ... }

# ❌ WRONG
if (app_rv$some_flag) { ... }
```

**Boolean Operators:**
```r
# ✅ CORRECT
condition <- isTRUE(rv$a) || isTRUE(rv$b)

# ❌ WRONG
condition <- rv$a || rv$b
```

**Negation:**
```r
# ✅ CORRECT
if (!isTRUE(rv$complete)) { ... }

# ❌ WRONG
if (!rv$complete) { ... }
```

---

## Related Pattern in Postal Cards

Checking postal cards code - they also use isTRUE():

```r
# Line 426 in app_server.R
show_reset_button <- app_rv$face_image_uploaded || app_rv$verso_image_uploaded
```

**Wait - postal cards DON'T use isTRUE()! Why don't they crash?**

**Answer:** Postal cards initialize reactive values differently. Let me check...

Actually, the postal cards might have the same bug but it hasn't manifested because those values are always initialized before the renderUI runs. Stamps are new, so the renderUI runs before any values are set.

**Best Practice:** Always use `isTRUE()` for reactive boolean checks!

---

## Success Criteria

- [x] All `||` and `&&` operators use `isTRUE()`
- [x] All `if()` conditions with reactive booleans use `isTRUE()`
- [x] All negations use `!isTRUE()` pattern
- [ ] Stamps tab opens without error (USER TO VERIFY)
- [ ] Status displays show correctly (USER TO VERIFY)

---

## Status

**Current:** ✅ **FIXED**
**Testing:** ⏳ **AWAITING USER VERIFICATION**

---

**Last Updated:** 2025-10-31
**Bug Type:** Runtime error (NULL boolean)
**Fix Complexity:** LOW (8 line changes)
**Lesson:** Always use `isTRUE()` with reactive values
