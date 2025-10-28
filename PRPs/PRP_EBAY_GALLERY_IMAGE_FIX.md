# PRP: Fix eBay Gallery Picture Issue

**Status**: 🔴 Critical
**Priority**: High
**Created**: 2025-10-28
**Type**: Bug Fix / Integration Issue

---

## Problem Statement

After successfully creating eBay listings via Trading API, users receive this error:

```
There's a problem with your Gallery picture. Sometimes this problem resolves
itself within 24 hours without you doing anything. Below are the 3 different
ways you can try to fix it now:

1. Go to the Fix your Gallery picture page, and click the Create button.
2. If you want to use a different picture for your Gallery picture, revise
   your item to add a different picture.
3. If fixing your Gallery picture doesn't solve the problem, please contact
   eBay Customer Support.
```

**Critical Issue**: While the listing is created successfully, the user cannot easily view their listing due to missing gallery image. This is unacceptable for production use.

---

## Current Behavior

1. User clicks "Send to eBay" button
2. Image uploads to eBay Picture Services (EPS) successfully
3. Listing is created via Trading API's AddFixedPriceItem successfully
4. Listing appears on eBay with Item ID
5. **BUT**: Gallery thumbnail fails to generate immediately
6. User sees error about Gallery picture
7. User cannot easily navigate to view their listing

### Why This Happens

eBay's image processing has two stages:
1. **EPS Upload**: Image is uploaded to `https://i.ebayimg.com/00/s/.../` ✅ Works
2. **Gallery Generation**: eBay's backend generates thumbnails for search/category pages ❌ Sometimes lags

The lag in step 2 is on eBay's side, but we can work around it.

---

## Investigation Findings

### Current Implementation

File: `R/ebay_trading_api.R`, Method: `upload_image()`

```r
upload_image = function(local_path) {
  # Read image as base64
  image_data <- base64enc::base64encode(local_path)

  # Call UploadSiteHostedPictures
  xml_body <- sprintf('<?xml version="1.0" encoding="utf-8"?>
    <UploadSiteHostedPicturesRequest xmlns="urn:ebay:apis:eBLBaseComponents">
      <RequesterCredentials>
        <eBayAuthToken>%s</eBayAuthToken>
      </RequesterCredentials>
      <PictureData>%s</PictureData>
    </UploadSiteHostedPicturesRequest>',
    private$token, image_data
  )

  # Parse response
  image_url <- xml2::xml_text(xml2::xml_find_first(xml_response, ".//d1:FullURL"))
  return(list(success = TRUE, image_url = image_url))
}
```

**Issue**: We're only using `FullURL` from EPS response. eBay recommends using **both** `FullURL` and `PictureSetMember` for reliable gallery display.

### eBay API Documentation

From [UploadSiteHostedPictures API](https://developer.ebay.com/Devzone/XML/docs/Reference/eBay/UploadSiteHostedPictures.html):

> **PictureSetMember**: Contains size-specific URLs for the uploaded picture.
> While FullURL provides the original image, using PictureSetMember URLs ensures
> proper gallery display across all eBay surfaces.

Response structure:
```xml
<UploadSiteHostedPicturesResponse>
  <FullURL>https://i.ebayimg.com/00/s/...</FullURL>
  <PictureSetMember>
    <MemberURL>https://i.ebayimg.com/images/g/.../s-l1600.jpg</MemberURL>
    <PictureSize>Supersize</PictureSize>
  </PictureSetMember>
  <PictureSetMember>
    <MemberURL>https://i.ebayimg.com/images/g/.../s-l500.jpg</MemberURL>
    <PictureSize>Large</PictureSize>
  </PictureSetMember>
  <PictureSetMember>
    <MemberURL>https://i.ebayimg.com/images/g/.../s-l225.jpg</MemberURL>
    <PictureSize>Medium</PictureSize>
  </PictureSetMember>
</UploadSiteHostedPicturesResponse>
```

### Alternative: PictureName Field

Another approach is to use `<PictureName>` in UploadSiteHostedPictures request:

```xml
<UploadSiteHostedPicturesRequest>
  <PictureName>postcard_{card_id}_{timestamp}.jpg</PictureName>
  <PictureData>...</PictureData>
</UploadSiteHostedPicturesRequest>
```

This helps eBay's backend cache and process images more reliably.

---

## Proposed Solution

### Option A: Use PictureSetMember URLs (Recommended)

**Rationale**: eBay-optimized URLs are pre-processed and have better gallery compatibility.

#### Implementation

File: `R/ebay_trading_api.R`

```r
upload_image = function(local_path) {
  # ... existing base64 encoding ...

  # Parse ALL PictureSetMember URLs
  picture_set <- xml2::xml_find_all(xml_response, ".//d1:PictureSetMember")

  urls <- list()
  for (member in picture_set) {
    size <- xml2::xml_text(xml2::xml_find_first(member, ".//d1:PictureSize"))
    url <- xml2::xml_text(xml2::xml_find_first(member, ".//d1:MemberURL"))
    urls[[size]] <- url
  }

  # Prefer in order: Supersize > Large > Medium > FullURL
  image_url <- urls$Supersize %||% urls$Large %||% urls$Medium %||% full_url

  return(list(
    success = TRUE,
    image_url = image_url,
    all_urls = urls  # For debugging
  ))
}
```

#### Modified AddFixedPriceItem

Currently we send:
```xml
<PictureDetails>
  <PictureURL>https://i.ebayimg.com/00/s/...</PictureURL>
</PictureDetails>
```

**Change to**: Use the Supersize/Large URL from PictureSetMember instead of FullURL.

**Expected Result**: Gallery thumbnails generate immediately because eBay's image processing has already created the size variants.

---

### Option B: Add PictureName Field

File: `R/ebay_trading_api.R`, Method: `upload_image()`

```r
upload_image = function(local_path, card_id = NULL) {
  image_data <- base64enc::base64encode(local_path)

  # Generate unique picture name
  picture_name <- if (!is.null(card_id)) {
    sprintf("postcard_%s_%s.jpg", card_id, format(Sys.time(), "%Y%m%d%H%M%S"))
  } else {
    sprintf("postcard_%s.jpg", format(Sys.time(), "%Y%m%d%H%M%S"))
  }

  xml_body <- sprintf('<?xml version="1.0" encoding="utf-8"?>
    <UploadSiteHostedPicturesRequest xmlns="urn:ebay:apis:eBLBaseComponents">
      <RequesterCredentials>
        <eBayAuthToken>%s</eBayAuthToken>
      </RequesterCredentials>
      <PictureName>%s</PictureName>
      <PictureData>%s</PictureData>
    </UploadSiteHostedPicturesRequest>',
    private$token, picture_name, image_data
  )

  # ... rest of existing code ...
}
```

**Expected Result**: Named images help eBay's backend cache and process images faster.

---

### Option C: Retry Logic with eBay's ReviseItem API

If gallery image fails initially, automatically retry with `ReviseItem` after 5 seconds.

```r
create_ebay_listing_from_card = function(...) {
  # ... existing listing creation ...

  # Check if gallery picture warning exists
  if (result$success && grepl("Gallery picture", result$warnings)) {
    cat("⚠️ Gallery picture warning detected, retrying in 5 seconds...\n")
    Sys.sleep(5)

    # Re-upload image
    upload_result <- ebay_api$trading$upload_image(image_url)

    # Revise item with new picture URL
    revise_result <- ebay_api$trading$revise_item(
      item_id = result$item_id,
      picture_url = upload_result$image_url
    )
  }

  return(result)
}
```

**Pros**: Automated recovery
**Cons**: Adds 5+ seconds to every listing, even successful ones

---

## Recommended Approach

**Implement Option A (PictureSetMember URLs)**

**Why**:
1. Uses eBay-optimized image URLs that are pre-processed
2. No performance impact (same API call, just parse response differently)
3. Gallery thumbnails likely already exist for these URLs
4. Follows eBay's recommended best practices

**Fallback**: If Option A doesn't fully resolve the issue, add Option B (PictureName) as it's a simple addition.

---

## Success Criteria

1. ✅ User creates eBay listing via Trading API
2. ✅ Image uploads successfully to EPS
3. ✅ **NEW**: Gallery thumbnail appears immediately (no error)
4. ✅ User can click notification URL and view listing with image
5. ✅ Console logs show which PictureSetMember URL was used

---

## Testing Plan

### Test Case 1: Standard Image Upload
1. Select combined image with 3 postcards
2. Extract AI data
3. Click "Send to eBay"
4. **Verify**: Console shows `Using PictureSetMember URL (Supersize): https://...`
5. **Verify**: No gallery picture error
6. **Verify**: Click notification URL → listing shows image

### Test Case 2: Large Image (>5MB after compression)
1. Use large combined image
2. Click "Send to eBay"
3. **Verify**: Compression to 3.7MB works
4. **Verify**: PictureSetMember URL used
5. **Verify**: Gallery image appears

### Test Case 3: Multiple Rapid Listings
1. Create 3 listings in quick succession
2. **Verify**: All 3 have gallery images
3. **Verify**: No race conditions or API errors

---

## Files to Modify

1. **`R/ebay_trading_api.R`**
   - Method: `upload_image()`
   - Add: Parse PictureSetMember URLs
   - Add: Return all URLs for debugging
   - Add: Log which URL is selected

2. **`R/ebay_integration.R`**
   - Method: `create_ebay_listing_from_card()`
   - Update: Use new image_url from upload_result
   - Add: Console logging for troubleshooting

3. **`tests/testthat/test-ebay_trading_api.R`**
   - Add: Test for PictureSetMember parsing
   - Add: Test for URL preference order
   - Add: Mock response with multiple sizes

---

## Rollback Plan

If Option A causes issues:
1. Revert to using FullURL (current behavior)
2. Implement Option B (PictureName) instead
3. If still failing, implement Option C (retry logic)

---

## Related Issues

- eBay's Gallery Picture processing lag (third-party issue)
- Base64 encoding size increase (fixed in previous session: 3.7MB compression target)
- User cannot view listings easily (notification now shows full clickable URL)

---

## References

- [eBay UploadSiteHostedPictures API](https://developer.ebay.com/Devzone/XML/docs/Reference/eBay/UploadSiteHostedPictures.html)
- [eBay Picture Services (EPS) Guide](https://developer.ebay.com/devzone/xml/docs/HowTo/Pictures/index.html)
- Memory: ebay_metadata_fields_and_condition_removal_20251028.md (notification improvements)
- Memory: ebay_trading_api_implementation_complete_20251028.md (current implementation)
