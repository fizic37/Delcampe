# TASK PRP: eBay Image Upload Implementation

**Status**: Ready for Execution
**Priority**: High (blocks production listings with real images)
**Estimated Time**: 2-3 hours
**Created**: 2025-10-20

---

## Analysis Summary

### Problem Statement

eBay requires publicly accessible HTTPS URLs for listing images. Currently, `R/ebay_integration.R:31` uses a placeholder: `https://via.placeholder.com/500x350.png?text=Postcard`. Local image files (JPG crops stored in `inst/app/data/crops/`) cannot be used directly.

### Solution Recommendation: **eBay Commerce Media API (Option 1)**

**Why this is the best solution:**
1. ✅ **Official eBay solution** - designed specifically for this use case
2. ✅ **Minimal code changes** - integrates with existing `EbayAPIConfig` and OAuth
3. ✅ **No third-party dependencies** - no external services or costs
4. ✅ **Automatic expiration management** - eBay handles image lifecycle
5. ✅ **Direct integration** - images stored on eBay's CDN for fast loading
6. ✅ **Already authenticated** - uses existing OAuth token infrastructure

---

## Context Documentation

### API Documentation
- **URL**: https://developer.ebay.com/api-docs/commerce/media/overview.html
- **Focus**: `POST /image/create_image_from_file` endpoint
- **Authentication**: OAuth 2.0 with scope `https://api.ebay.com/oauth/api_scope/sell.inventory` (already configured)

### Code Patterns to Follow
- **File**: R/ebay_api.R (lines 437-510)
- **Copy**: HTTP request pattern with OAuth headers, error handling structure
- **Example**: `create_inventory_item()` and `create_offer()` methods show proper request construction

### Key Gotchas
1. **Issue**: Media API returns image_id in `Location` header, not JSON body
   - **Fix**: Extract from `resp$headers$location`, format: `https://apim.ebay.com/commerce/media/v1_beta/image/{image_id}`

2. **Issue**: Must call `getImage` to retrieve actual EPS URL for use in listings
   - **Fix**: Two-step process: 1) upload via `createImageFromFile`, 2) retrieve URL via `GET /image/{image_id}`

3. **Issue**: httr2's `req_body_multipart()` requires `curl::form_file()` wrapper
   - **Fix**: Use `curl::form_file(image_path, type = "image/jpeg")` for proper multipart encoding

4. **Issue**: Rate limit of 50 requests per 5 seconds for POST methods
   - **Fix**: Not a concern for single-postcard uploads; would need throttling for bulk operations

---

## Task Sequence

### SETUP: Add curl package dependency

**Context**: httr2's multipart functionality depends on curl package

```r
ACTION DESCRIPTION:1-10:
  - OPERATION: Add curl to Imports section
  - VALIDATE: devtools::document() runs without errors
  - IF_FAIL: Check if curl is already installed with `library(curl)`
  - ROLLBACK: Remove curl from DESCRIPTION if conflicts arise
```

---

### TASK 1: Create Media API client class

**Context**: Following existing pattern from `EbayInventoryAPI` class (R/ebay_api.R:437-660)

```r
ACTION R/ebay_api.R:EOF:
  - OPERATION: Insert new R6 class `EbayMediaAPI` after `EbayInventoryAPI` class
  - STRUCTURE:
    ```r
    EbayMediaAPI <- R6::R6Class("EbayMediaAPI",
      public = list(
        config = NULL,
        oauth = NULL,

        initialize = function(config, oauth) {
          self$config <- config
          self$oauth <- oauth
        },

        # Upload image file to eBay Picture Services
        upload_image = function(image_path) {
          # Step 1: Validate file exists and is image format
          # Step 2: Construct multipart upload request
          # Step 3: Extract image_id from Location header
          # Step 4: Retrieve EPS URL via getImage
          # Return: list(success = TRUE/FALSE, image_url = "...", error = "...")
        },

        # Retrieve image details from eBay (internal method)
        get_image = function(image_id) {
          # GET /commerce/media/v1_beta/image/{image_id}
          # Returns: image_url and expiration_date
        }
      )
    )
    ```
  - VALIDATE: `devtools::load_all()` loads without errors
  - IF_FAIL: Check R6 syntax, ensure no duplicate class names
  - ROLLBACK: Git restore R/ebay_api.R
```

**Implementation Details for `upload_image` method:**

1. **File validation**:
   ```r
   if (!file.exists(image_path)) {
     return(list(success = FALSE, error = paste("File not found:", image_path)))
   }

   ext <- tolower(tools::file_ext(image_path))
   if (!ext %in% c("jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp")) {
     return(list(success = FALSE, error = "Unsupported format. Use JPG, PNG, GIF, BMP, TIFF, or WEBP"))
   }
   ```

2. **Construct multipart request**:
   ```r
   base_url <- if (self$config$environment == "sandbox") {
     "https://api.sandbox.ebay.com"
   } else {
     "https://api.ebay.com"
   }

   token <- self$oauth$get_access_token()

   req <- httr2::request(paste0(base_url, "/commerce/media/v1_beta/image/create_image_from_file")) |>
     httr2::req_method("POST") |>
     httr2::req_headers(
       Authorization = paste("Bearer", token),
       "Content-Language" = "en-US"
     ) |>
     httr2::req_body_multipart(
       image = curl::form_file(image_path, type = paste0("image/", ext))
     )
   ```

3. **Perform request and extract image_id**:
   ```r
   resp <- tryCatch({
     httr2::req_perform(req)
   }, error = function(e) {
     return(list(success = FALSE, error = paste("Upload failed:", e$message)))
   })

   if (httr2::resp_status(resp) != 201) {
     return(list(success = FALSE, error = paste("Upload failed with status", httr2::resp_status(resp))))
   }

   # Extract image_id from Location header
   location <- httr2::resp_header(resp, "location")
   image_id <- gsub(".*/image/", "", location)
   ```

4. **Retrieve EPS URL**:
   ```r
   image_details <- self$get_image(image_id)
   if (!image_details$success) {
     return(image_details)
   }

   return(list(
     success = TRUE,
     image_url = image_details$image_url,
     image_id = image_id,
     expiration = image_details$expiration_date
   ))
   ```

**Implementation Details for `get_image` method:**

```r
get_image = function(image_id) {
  base_url <- if (self$config$environment == "sandbox") {
    "https://api.sandbox.ebay.com"
  } else {
    "https://api.ebay.com"
  }

  token <- self$oauth$get_access_token()

  req <- httr2::request(paste0(base_url, "/commerce/media/v1_beta/image/", image_id)) |>
    httr2::req_method("GET") |>
    httr2::req_headers(
      Authorization = paste("Bearer", token),
      "Content-Language" = "en-US"
    )

  resp <- tryCatch({
    httr2::req_perform(req)
  }, error = function(e) {
    return(list(success = FALSE, error = paste("Failed to retrieve image:", e$message)))
  })

  if (httr2::resp_status(resp) != 200) {
    return(list(success = FALSE, error = paste("Get image failed with status", httr2::resp_status(resp))))
  }

  data <- httr2::resp_body_json(resp)

  return(list(
    success = TRUE,
    image_url = data$imageUrl,
    expiration_date = data$expirationDate
  ))
}
```

---

### TASK 2: Initialize Media API in main eBay API constructor

**Context**: Media API needs to be available alongside Inventory API

```r
ACTION R/ebay_api.R:530-545:
  - OPERATION: Add `media` field initialization to `EbayAPI$initialize()`
  - LOCATE: Find where `self$inventory <- EbayInventoryAPI$new(...)` is called
  - INSERT_AFTER:
    ```r
    self$media <- EbayMediaAPI$new(self$config, self$oauth)
    ```
  - VALIDATE: Create test API instance and check `api$media` exists
  - IF_FAIL: Check field is in public list, verify class name matches
  - ROLLBACK: Remove media field initialization
```

---

### TASK 3: Update `create_ebay_listing_from_card` to upload images

**Context**: Currently uses placeholder URL (R/ebay_integration.R:31), need to upload real images

```r
ACTION R/ebay_integration.R:27-32:
  - OPERATION: Replace placeholder logic with image upload call
  - OLD_CODE:
    ```r
    # Use placeholder image if none provided (for sandbox testing)
    if (is.null(image_url)) {
      image_url <- "https://via.placeholder.com/500x350.png?text=Postcard"
      cat("   Using placeholder image\n")
    }
    ```
  - NEW_CODE:
    ```r
    # Step 0: Upload image to eBay Picture Services if local path provided
    if (is.null(image_url)) {
      # For now, use placeholder - in production, this should receive image_path
      image_url <- "https://via.placeholder.com/500x350.png?text=Postcard"
      cat("   Using placeholder image\n")
    } else if (file.exists(image_url)) {
      # image_url is actually a local file path - upload it
      cat("\n0. Uploading image to eBay Picture Services...\n")
      cat("   Local path:", image_url, "\n")

      upload_result <- ebay_api$media$upload_image(image_url)

      if (!upload_result$success) {
        error_msg <- paste("Failed to upload image:", upload_result$error)
        cat("   ❌", error_msg, "\n")
        return(list(success = FALSE, error = error_msg))
      }

      image_url <- upload_result$image_url
      cat("   ✅ Image uploaded, EPS URL:", image_url, "\n")
      cat("   Image ID:", upload_result$image_id, "\n")
      cat("   Expires:", upload_result$expiration, "\n")
    }
    ```
  - VALIDATE: Test with placeholder URL first (should still work)
  - IF_FAIL: Check if file.exists() logic is correct, verify API method signature
  - ROLLBACK: Restore placeholder-only logic
```

---

### TASK 4: Update function signature and documentation

**Context**: Need to clarify that `image_url` can now accept local file paths

```r
ACTION R/ebay_integration.R:15:
  - OPERATION: Update function documentation
  - OLD_DOC:
    ```r
    create_ebay_listing_from_card <- function(card_id, ai_data, ebay_api, session_id, image_url = NULL, ebay_user_id = NULL, ebay_username = NULL) {
    ```
  - ADD_ROXYGEN_COMMENT:
    ```r
    #' Create eBay Listing from Postal Card
    #'
    #' Creates a complete eBay listing by uploading image, creating inventory item, offer, and publishing.
    #'
    #' @param card_id Postal card ID from database
    #' @param ai_data List containing AI-extracted data (title, description, price, condition)
    #' @param ebay_api EbayAPI instance with authenticated connection
    #' @param session_id Current processing session ID
    #' @param image_url Either a public HTTPS URL or local file path to image. If local path, will be uploaded to eBay Picture Services.
    #' @param ebay_user_id eBay user ID from account manager
    #' @param ebay_username eBay username for tracking
    #' @return List with success status, listing_id, offer_id, sku, listing_url
    ```
  - VALIDATE: `devtools::document()` generates proper man page
  - IF_FAIL: Check Roxygen syntax
  - ROLLBACK: Remove documentation changes
```

---

### TASK 5: Identify where image paths are generated in the UI

**Context**: Need to find where combined images are created and pass path to listing function

```r
ACTION R/mod_delcampe_export.R:
  - OPERATION: Search for where `create_ebay_listing_from_card()` is called
  - SEARCH_FOR: "create_ebay_listing_from_card"
  - EXPECTED: Find call around line 750-1040 (based on database connection patterns)
  - EXAMINE: Check what value is currently passed for `image_url` parameter
  - DOCUMENT: Record line numbers and current implementation in memory
  - NO_CHANGES: This is exploration only
```

---

### TASK 6: Pass local image path to listing creation

**Context**: Once we find the call site, need to pass actual image file path instead of NULL

```r
ACTION R/mod_delcampe_export.R:[LINE_FROM_TASK_5]:
  - OPERATION: Update `create_ebay_listing_from_card()` call to include image path
  - CURRENT_PATTERN: `image_url = NULL` (or parameter omitted)
  - NEW_PATTERN:
    ```r
    # Determine image path from card data
    # Option A: If combined image exists in database
    image_path <- DBI::dbGetQuery(con,
      "SELECT file_path FROM postal_cards WHERE card_id = ?",
      params = list(card_id))$file_path[1]

    # Option B: If using crop files
    # image_path <- file.path("inst/app/data/crops", card_type, card_id, "crop_row0_col0.jpg")

    # Pass to listing creation
    listing_result <- create_ebay_listing_from_card(
      card_id = card_id,
      ai_data = ai_data,
      ebay_api = ebay_api(),
      session_id = session_id,
      image_url = image_path,  # Now passes local file path
      ebay_user_id = active_account$user_id,
      ebay_username = active_account$username
    )
    ```
  - VALIDATE: Check database schema for image path column
  - IF_FAIL: Use hardcoded test path first: `inst/app/data/crops/face/1/extract_1760434640/crop_row0_col0.jpg`
  - ROLLBACK: Restore `image_url = NULL`
```

---

### TASK 7: Integration testing

**Context**: Validate end-to-end flow with actual image upload

```r
ACTION TEST:
  - OPERATION: Manual test of complete flow
  - STEPS:
    1. Launch app: `devtools::load_all(); run_app()`
    2. Connect eBay account (sandbox)
    3. Select a postcard with existing crop image
    4. Trigger eBay listing creation
    5. Monitor console output for image upload messages
    6. Verify listing created with uploaded image URL
  - SUCCESS_CRITERIA:
    ✅ Console shows "0. Uploading image to eBay Picture Services..."
    ✅ Console shows "✅ Image uploaded, EPS URL: https://..."
    ✅ Console shows "✅ Inventory item created"
    ✅ Console shows "✅ Listing created successfully"
    ✅ No errors in R console
  - IF_FAIL: Check debug strategy below
  - ROLLBACK: Use git to restore all changes
```

---

## Debug Strategy

### Issue: "File not found" error during upload

**Diagnosis**:
```r
# Add this before upload call to verify path
cat("DEBUG - Checking image path:", image_url, "\n")
cat("DEBUG - File exists:", file.exists(image_url), "\n")
cat("DEBUG - Full path:", normalizePath(image_url, mustWork = FALSE), "\n")
```

**Solution**: Ensure path is absolute, not relative. If relative, prepend working directory.

---

### Issue: "Upload failed with status 400"

**Diagnosis**:
- Check response body for eBay error details
- Add to `upload_image()` method:
  ```r
  body <- httr2::resp_body_json(resp)
  return(list(success = FALSE, error = paste("eBay error:", body$errors[[1]]$message)))
  ```

**Common causes**:
- Invalid OAuth scope (need `sell.inventory`)
- File format not supported
- File size exceeds 12 MB

---

### Issue: "Location header not found"

**Diagnosis**:
```r
cat("DEBUG - Response headers:", names(resp$headers), "\n")
cat("DEBUG - Status:", httr2::resp_status(resp), "\n")
```

**Solution**: Header name might be lowercase `location` or uppercase `Location`. Try both:
```r
location <- httr2::resp_header(resp, "location") %||% httr2::resp_header(resp, "Location")
```

---

### Issue: Rate limit exceeded (HTTP 429)

**Diagnosis**: Console shows "Too Many Requests"

**Solution**: Wait 5 seconds before retrying. For bulk uploads, implement throttling:
```r
Sys.sleep(0.2)  # 200ms delay = max 5 uploads/second
```

---

## Rollback Approach

### Complete rollback (all tasks):
```bash
git checkout R/ebay_api.R
git checkout R/ebay_integration.R
git checkout R/mod_delcampe_export.R
git checkout DESCRIPTION
```

### Partial rollback (by task):
- **Task 1-2 only**: `git checkout R/ebay_api.R`
- **Task 3-4 only**: `git checkout R/ebay_integration.R`
- **Task 6 only**: `git checkout R/mod_delcampe_export.R`

---

## Risk Assessment

### High Risks
1. **OAuth scope insufficient**: If current token lacks `sell.inventory` scope, upload will fail
   - **Mitigation**: Check `.Renviron` has correct scope, may need to re-authenticate
   - **Detection**: 401 Unauthorized error during upload

2. **Image files missing/moved**: If database stores old paths, files may not exist
   - **Mitigation**: Implement file existence check before upload (already in Task 3)
   - **Detection**: "File not found" error

### Medium Risks
1. **httr2/curl package conflicts**: Package versions may be incompatible
   - **Mitigation**: Update packages with `install.packages(c("httr2", "curl"))`
   - **Detection**: Namespace errors during load

2. **Multipart encoding issues**: Different systems may encode differently
   - **Mitigation**: Follow exact pattern from httr2 documentation
   - **Detection**: eBay returns "malformed request" error

### Low Risks
1. **Image format incompatibility**: eBay rejects certain image types
   - **Mitigation**: Validate file extension against allowed list
   - **Detection**: eBay error 190203

2. **Rate limiting during testing**: Multiple rapid uploads may trigger limits
   - **Mitigation**: Add small delay between uploads in production
   - **Detection**: HTTP 429 response

---

## Performance Impact

- **Upload time**: ~1-2 seconds per image (network dependent)
- **Memory**: Minimal - httr2 streams file data
- **Database**: No additional queries beyond existing flow
- **User experience**: Add progress message "Uploading image..." to UI notification

---

## Security Considerations

- ✅ **OAuth tokens**: Already handled securely by existing infrastructure
- ✅ **File access**: Only reads from trusted app directory (`inst/app/data/crops/`)
- ✅ **Image validation**: File extension check prevents non-image uploads
- ✅ **No credentials in images**: Images are user-uploaded postcard scans (no sensitive data)

---

## Alternative Solutions (Not Recommended)

### Option 2: Third-Party Image Host (Imgur, Cloudinary)

**Why rejected**:
- ❌ Requires additional account/API key management
- ❌ Introduces external dependency and potential costs
- ❌ Images stored outside eBay ecosystem (slower loading for buyers)
- ❌ Need to handle image cleanup/expiration separately

**When to consider**: If eBay Media API proves unreliable in production

---

### Option 3: Temporary Local Web Server

**Why rejected**:
- ❌ Requires public IP or tunneling service (ngrok, etc.)
- ❌ Security risk: exposes local files to internet
- ❌ Firewall configuration challenges
- ❌ Unreliable: eBay must fetch image while server is running

**When to consider**: Never - this approach is fundamentally flawed for desktop apps

---

### Option 4: Base64 Encoding

**Why rejected**:
- ❌ eBay does NOT support base64-encoded images in Inventory API
- ❌ Only supported in legacy Trading API (XML, deprecated)

**When to consider**: Never for this project

---

## Success Criteria Checklist

- [ ] `EbayMediaAPI` class created and integrated
- [ ] `upload_image()` method uploads local files successfully
- [ ] `get_image()` method retrieves EPS URLs correctly
- [ ] Image upload integrated into `create_ebay_listing_from_card()`
- [ ] Function documentation updated
- [ ] UI passes actual image paths to listing function
- [ ] End-to-end test: Postcard listed with uploaded image
- [ ] No errors in console during normal operation
- [ ] Image URLs visible in eBay sandbox listing preview

---

## Post-Implementation Notes

After successful implementation, update the following:

1. **Memory file**: Create `.serena/memories/ebay_image_upload_complete_YYYYMMDD.md` with:
   - Implementation summary
   - API patterns used
   - Any deviations from this plan
   - Production readiness notes

2. **Documentation**: Update `docs/guides/EBAY_INTEGRATION.md` with:
   - Image upload workflow diagram
   - Troubleshooting section for upload errors
   - Rate limiting considerations

3. **Testing**: Document test procedure in `TASK_PRP/TEST_EBAY_IMAGE_UPLOAD.md`

---

## Estimated Timeline

- **Setup (Task 1-2)**: 30 minutes
- **Core implementation (Task 3-4)**: 45 minutes
- **UI integration (Task 5-6)**: 30 minutes
- **Testing and debugging (Task 7)**: 45 minutes
- **Total**: 2.5 hours (3 hours with buffer)

---

**Ready to implement?** Execute tasks sequentially, validating each before proceeding to next.
