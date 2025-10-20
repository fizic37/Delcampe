# TASK PRP: eBay Sandbox Integration - "Send to eBay" Feature

**Based on:** PRPs/PRP_EBAY_SANDBOX_INTEGRATION.md
**Created:** 2025-10-15
**Status:** Ready for Implementation

---

## Context

```yaml
existing_infrastructure:
  - R/ebay_api.R: Complete R6 classes (EbayAPIConfig, EbayOAuth, EbayInventoryAPI)
  - R/mod_ebay_auth.R: OAuth flow module (UI + Server)
  - R/mod_ebay_postcard.R: Standalone listing module (not integrated)
  - R/ebay_database_extension.R: Database functions for tracking
  - R/mod_delcampe_export.R: Export module with AI extraction (LINE 27-963)
  - R/app_server.R: Main server initialization (LINE 6-808)
  - R/app_ui.R: Main UI with Settings tab (LINE 7-137)
  - R/tracking_database.R: Three-layer architecture with AI fields

integration_points:
  export_module: mod_delcampe_export.R:434-509 (AI extraction handlers)
  database: card_processing table has ai_title, ai_description, ai_price, ai_condition
  settings_ui: app_ui.R:103-119 (Settings navset_card_tab)
  app_init: app_server.R:6-808 (module initialization)

patterns:
  - file: R/mod_delcampe_export.R:434-509
    copy: AI extraction with notification patterns

  - file: R/app_server.R:243-244
    copy: Module initialization pattern (Settings module)

  - file: R/tracking_database.R:454-516
    copy: Database query pattern (find_card_processing)

gotchas:
  - "Custom JavaScript FAILS in modules - use bslib components only"
  - "AI data already in database - retrieve via find_card_processing()"
  - "Export module uses accordion - button goes inside panel"
  - "Must check OAuth authentication before allowing send"
  - "Database has TWO tables: ebay_posts (legacy) and ebay_listings (use this)"
  - "Condition values: used/excellent/good/fair/poor → need eBay mapping"
  - "SKU must be unique - generate from card_id + timestamp"
```

---

## Task Breakdown

### TASK 1: Create Helper Functions (R/ebay_helpers.R)

**File:** `R/ebay_helpers.R` (NEW FILE)

```r
# CREATE: Helper functions for eBay integration
# LOCATION: R/ebay_helpers.R

#' Map Delcampe condition to eBay condition codes
#' @param delcampe_condition Condition from Delcampe ("used", "excellent", etc.)
#' @return eBay condition code
#' @export
map_condition_to_ebay <- function(delcampe_condition) {
  # IMPLEMENT: Mapping logic
  # used -> USED_EXCELLENT
  # excellent -> USED_EXCELLENT
  # good -> USED_VERY_GOOD
  # fair -> USED_GOOD
  # poor -> USED_ACCEPTABLE
}

#' Generate unique SKU for postcard listing
#' @param card_id Card ID from database
#' @param session_id Session identifier
#' @return Unique SKU string
#' @export
generate_sku <- function(card_id, session_id = NULL) {
  # IMPLEMENT: SKU generation
  # Format: PC-{card_id}-{timestamp}
  # Example: PC-12345-20251015143022
}

#' Extract postcard aspects from AI data
#' @param ai_data List with AI extraction results
#' @return List of eBay aspects (key-value pairs)
#' @export
extract_postcard_aspects <- function(ai_data) {
  # IMPLEMENT: Extract aspects
  # Return: list(
  #   "Type" = list("Postcard"),
  #   "Condition" = list(ai_data$condition),
  #   ...
  # )
}
```

**VALIDATION:**
```r
# Test condition mapping
testthat::test_that("Condition mapping works", {
  expect_equal(map_condition_to_ebay("used"), "USED_EXCELLENT")
  expect_equal(map_condition_to_ebay("excellent"), "USED_EXCELLENT")
  expect_equal(map_condition_to_ebay("good"), "USED_VERY_GOOD")
})

# Test SKU generation
sku1 <- generate_sku(12345)
sku2 <- generate_sku(12345)
expect_true(sku1 != sku2) # Must be unique
expect_match(sku1, "^PC-12345-\\d{14}$")
```

**IF_FAIL:** Check function exports in NAMESPACE, verify R CMD check passes

**ROLLBACK:** Delete R/ebay_helpers.R, revert NAMESPACE

---

### TASK 2: Extend Database Functions (R/ebay_database_extension.R)

**File:** `R/ebay_database_extension.R` (EXISTS - MODIFY)

**OPERATION 1: Add table initialization to main init**
```r
# FIND: initialize_ebay_tables function (LINE 6-53)
# MODIFY: Ensure ebay_listings table is created (already exists - verify)
# NO CHANGES NEEDED if table already defined
```

**OPERATION 2: Add SKU uniqueness check**
```r
# ADD AFTER: get_ebay_listing_for_card function (LINE 117-143)

#' Check if SKU already exists
#' @param sku SKU to check
#' @return TRUE if exists, FALSE otherwise
#' @export
check_sku_exists <- function(sku) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con))

    result <- DBI::dbGetQuery(con, "
      SELECT COUNT(*) as count FROM ebay_listings WHERE sku = ?
    ", list(sku))

    return(result$count[1] > 0)
  }, error = function(e) {
    message("Error checking SKU: ", e$message)
    return(FALSE)
  })
}
```

**VALIDATION:**
```r
# Test SKU check
sku <- "PC-TEST-12345"
expect_false(check_sku_exists(sku))
save_ebay_listing(card_id = 1, session_id = "test", sku = sku, status = "draft")
expect_true(check_sku_exists(sku))
```

**IF_FAIL:** Check database connection, verify ebay_listings table exists

**ROLLBACK:** Remove check_sku_exists function

---

### TASK 3: Add eBay Button to Export Module (R/mod_delcampe_export.R)

**File:** `R/mod_delcampe_export.R:229-256`

**FIND:** The section in create_form_content where action buttons are created (around LINE 229-256)

**CURRENT CODE:**
```r
# Action button - Send to eBay
fluidRow(
  column(
    12,
    div(
      style = "margin-top: 16px;",
      actionButton(
        ns(paste0("send_to_ebay_", idx)),
        "Send to eBay",
        icon = icon("upload"),
        class = "btn-success",
        style = "width: 100%;"
      )
    )
  )
)
```

**MODIFY TO:**
```r
# Action buttons - Export options
fluidRow(
  column(
    12,
    div(
      style = "margin-top: 16px; display: flex; gap: 10px;",
      actionButton(
        ns(paste0("export_delcampe_", idx)),
        "Export to Delcampe",
        icon = icon("file-export"),
        class = "btn-primary",
        style = "flex: 1;"
      ),
      actionButton(
        ns(paste0("send_to_ebay_", idx)),
        "Send to eBay",
        icon = icon("upload"),
        class = "btn-success",
        style = "flex: 1;"
      )
    )
  )
)
```

**VALIDATION:** Visually inspect accordion panel - should show two buttons side by side

**IF_FAIL:** Check that ns() namespace is applied correctly

**ROLLBACK:** Revert to single button layout

---

### TASK 4: Add eBay API Parameter to Export Module (R/mod_delcampe_export.R)

**File:** `R/mod_delcampe_export.R:27`

**FIND:** mod_delcampe_export_server function signature (LINE 27)

**CURRENT:**
```r
mod_delcampe_export_server <- function(id, image_paths = reactive(NULL), image_file_paths = reactive(NULL), image_type = "combined") {
```

**MODIFY TO:**
```r
mod_delcampe_export_server <- function(id, image_paths = reactive(NULL), image_file_paths = reactive(NULL), image_type = "combined", ebay_api = reactive(NULL)) {
```

**VALIDATION:** R CMD check - no missing parameter errors

**IF_FAIL:** Check function signature matches module calls

**ROLLBACK:** Remove ebay_api parameter

---

### TASK 5: Implement eBay Send Handler (R/mod_delcampe_export.R)

**File:** `R/mod_delcampe_export.R`

**LOCATION:** Add AFTER the AI extraction handlers (after LINE 963, before return statement)

**ADD:**
```r
# eBay Send Handlers - Create observers for each image's Send to eBay button
observe({
  req(image_paths())
  paths <- image_paths()

  lapply(seq_along(paths), function(i) {
    observeEvent(input[[paste0("send_to_ebay_", i)]], ignoreNULL = TRUE, ignoreInit = TRUE, {

      cat("\n🎯 Send to eBay button clicked for image", i, "\n")

      # STEP 1: Check eBay authentication
      api <- ebay_api()
      if (is.null(api) || !api$oauth$is_authenticated()) {
        showModal(modalDialog(
          title = "eBay Connection Required",
          div(
            icon("exclamation-triangle", style = "color: #f0ad4e; font-size: 48px;"),
            h4("Please connect to eBay first", style = "margin-top: 20px;"),
            p("Go to Settings > eBay Connection to authenticate with eBay API.")
          ),
          footer = tagList(
            modalButton("Cancel"),
            actionButton(session$ns("go_to_settings"), "Go to Settings", class = "btn-primary")
          )
        ))
        return()
      }

      cat("   ✅ eBay authenticated\n")

      # STEP 2: Get AI data from database
      current_path <- paths[i]
      file_paths <- image_file_paths()
      actual_path <- if (!is.null(file_paths) && i <= length(file_paths)) {
        file_paths[i]
      } else {
        convert_web_path_to_file_path(current_path)
      }

      if (is.null(actual_path) || !file.exists(actual_path)) {
        showNotification("Could not locate image file", type = "error")
        return()
      }

      # Calculate hash to find card_id
      image_hash <- calculate_image_hash(actual_path)
      if (is.null(image_hash)) {
        showNotification("Could not calculate image hash", type = "error")
        return()
      }

      # Find card processing with AI data
      card_data <- find_card_processing(image_hash, "combined")

      if (is.null(card_data)) {
        showNotification("No card data found. Please run AI extraction first.", type = "warning")
        return()
      }

      cat("   📦 Card data found (card_id:", card_data$card_id, ")\n")

      # Check if AI data exists
      if (is.null(card_data$ai_title) || is.na(card_data$ai_title) || nchar(card_data$ai_title) == 0) {
        showNotification("No AI extraction data found. Please extract with AI first.", type = "warning")
        return()
      }

      cat("   ✅ AI data exists:\n")
      cat("      Title:", substr(card_data$ai_title, 1, 50), "\n")
      cat("      Price:", card_data$ai_price, "\n")
      cat("      Condition:", card_data$ai_condition, "\n")

      # STEP 3: Generate unique SKU
      sku <- generate_sku(card_data$card_id, session$token)

      # Check if SKU exists (should never happen, but safety check)
      retry_count <- 0
      while (check_sku_exists(sku) && retry_count < 3) {
        Sys.sleep(0.1) # Wait 100ms
        sku <- generate_sku(card_data$card_id, session$token)
        retry_count <- retry_count + 1
      }

      if (check_sku_exists(sku)) {
        showNotification("Could not generate unique SKU. Please try again.", type = "error")
        return()
      }

      cat("   🏷️ Generated SKU:", sku, "\n")

      # STEP 4: Map condition to eBay format
      ebay_condition <- map_condition_to_ebay(card_data$ai_condition)
      cat("   📋 eBay condition:", ebay_condition, "\n")

      # STEP 5: Extract aspects
      aspects <- extract_postcard_aspects(list(
        title = card_data$ai_title,
        condition = card_data$ai_condition
      ))

      # STEP 6: Show progress and create listing
      notification_id <- showNotification(
        "Creating eBay listing...",
        duration = NULL,
        closeButton = FALSE,
        type = "message"
      )

      withProgress(message = "Sending to eBay...", value = 0, {

        incProgress(0.3, detail = "Creating inventory item...")

        tryCatch({
          # Create listing using eBay API
          result <- api$inventory$create_postcard_listing(
            sku = sku,
            title = card_data$ai_title,
            description = card_data$ai_description %||% "",
            price = card_data$ai_price,
            quantity = 1,
            image_urls = list(), # TODO: Upload images to eBay Picture Services
            condition = ebay_condition,
            aspects = aspects,
            location_key = "default_location",
            listing_policies = list() # TODO: Add from env vars if configured
          )

          incProgress(0.7, detail = "Saving to database...")

          if (result$success) {
            # Save to database
            save_ebay_listing(
              card_id = card_data$card_id,
              session_id = session$token,
              ebay_item_id = result$listing_id,
              ebay_offer_id = result$offer_id,
              sku = sku,
              status = "listed",
              environment = api$config$environment,
              title = card_data$ai_title,
              description = card_data$ai_description,
              price = card_data$ai_price,
              condition = ebay_condition,
              aspects = jsonlite::toJSON(aspects, auto_unbox = TRUE)
            )

            incProgress(1, detail = "Complete!")

            # Close notification
            removeNotification(notification_id)

            # Show success
            showNotification(
              paste0("✅ Listed on eBay! (SKU: ", sku, ")"),
              type = "success",
              duration = 10
            )

            # Update UI status
            output[[paste0("ai_status_", i)]] <- renderUI({
              div(
                style = "padding: 12px; background: #d4edda; border-left: 4px solid #28a745; margin-top: 10px;",
                icon("check-circle", style = "color: #155724;"),
                sprintf(" Listed on eBay (SKU: %s)", sku),
                br(),
                tags$small(sprintf("Offer ID: %s", result$offer_id))
              )
            })

            cat("   ✅ Listing complete!\n")
            cat("      SKU:", sku, "\n")
            cat("      Offer ID:", result$offer_id, "\n")
            cat("      Listing ID:", result$listing_id, "\n\n")

          } else {
            # Handle error
            removeNotification(notification_id)

            showNotification(
              paste("eBay Error:", result$error),
              type = "error",
              duration = NULL
            )

            # Save failed listing to database
            save_ebay_listing(
              card_id = card_data$card_id,
              session_id = session$token,
              sku = sku,
              status = "failed",
              environment = api$config$environment,
              title = card_data$ai_title,
              description = card_data$ai_description,
              price = card_data$ai_price,
              condition = ebay_condition
            )

            # Update error in database
            update_ebay_listing_status(sku, "failed", result$error)

            cat("   ❌ Listing failed:", result$error, "\n\n")
          }

        }, error = function(e) {
          removeNotification(notification_id)

          showNotification(
            paste("Unexpected error:", e$message),
            type = "error",
            duration = NULL
          )

          cat("   💥 Unexpected error:", e$message, "\n\n")
        })
      })
    })
  })
})
```

**VALIDATION:**
1. Click "Send to eBay" without authentication → Should show modal
2. Click "Send to eBay" with authentication → Should create listing
3. Check database: `SELECT * FROM ebay_listings` → Should have new record
4. Check eBay sandbox → Should see listing

**IF_FAIL:**
- Check eBay API credentials in .Renviron
- Check OAuth token is valid (not expired)
- Check console for detailed error messages
- Verify database connection works

**ROLLBACK:** Remove observer block

---

### TASK 6: Add eBay Settings Panel to UI (R/app_ui.R)

**File:** `R/app_ui.R:103-119`

**FIND:** Settings navset_card_tab (LINE 103-119)

**CURRENT:**
```r
bslib::navset_card_tab(
  bslib::nav_panel(
    title = "General",
    mod_settings_ui("settings")
  ),
  bslib::nav_panel(
    title = "Tracking",
    mod_tracking_viewer_ui("tracking_viewer_1")
  )
)
```

**MODIFY TO:**
```r
bslib::navset_card_tab(
  bslib::nav_panel(
    title = "General",
    mod_settings_ui("settings")
  ),
  bslib::nav_panel(
    title = "eBay Connection",
    icon = icon("link"),
    mod_ebay_auth_ui("ebay_auth")
  ),
  bslib::nav_panel(
    title = "Tracking",
    mod_tracking_viewer_ui("tracking_viewer_1")
  )
)
```

**VALIDATION:** Open app → Settings tab → Should see "eBay Connection" panel

**IF_FAIL:** Check mod_ebay_auth_ui is exported, verify NAMESPACE

**ROLLBACK:** Remove eBay Connection panel

---

### TASK 7: Initialize eBay API in App Server (R/app_server.R)

**File:** `R/app_server.R:243-244`

**FIND:** Settings module initialization (around LINE 243)

**CURRENT:**
```r
# Settings server - FIXED: Changed role to "admin" to show LLM Models tab
mod_settings_server("settings", reactive(list(email = "admin@delcampe.com", role = "admin")))
```

**ADD AFTER:**
```r
# eBay authentication server
ebay_api <- mod_ebay_auth_server("ebay_auth")
```

**VALIDATION:** Check console on app start → Should see eBay API initialization messages

**IF_FAIL:** Check mod_ebay_auth_server exists, verify module is loaded

**ROLLBACK:** Remove ebay_api initialization

---

### TASK 8: Pass eBay API to Export Modules (R/app_server.R)

**File:** `R/app_server.R:785-795`

**FIND:** Export module initialization (around LINE 785-795)

**CURRENT:**
```r
# Export modules - must be initialized outside reactive context
mod_delcampe_export_server(
  "lot_export",
  image_paths = reactive(app_rv$lot_paths),
  image_type = "lot"
)

mod_delcampe_export_server(
  "combined_export",
  image_paths = reactive(app_rv$combined_paths),
  image_file_paths = reactive(app_rv$combined_file_paths),
  image_type = "combined"
)
```

**MODIFY TO:**
```r
# Export modules - must be initialized outside reactive context
mod_delcampe_export_server(
  "lot_export",
  image_paths = reactive(app_rv$lot_paths),
  image_type = "lot",
  ebay_api = ebay_api
)

mod_delcampe_export_server(
  "combined_export",
  image_paths = reactive(app_rv$combined_paths),
  image_file_paths = reactive(app_rv$combined_file_paths),
  image_type = "combined",
  ebay_api = ebay_api
)
```

**VALIDATION:** No errors on app start, eBay buttons work

**IF_FAIL:** Check ebay_api reactive exists, verify parameter passing

**ROLLBACK:** Remove ebay_api parameters

---

### TASK 9: Initialize eBay Database Table on Startup (R/app_server.R)

**File:** `R/app_server.R:9-27`

**FIND:** Database initialization block (LINE 9-27)

**ADD AFTER:** The initialize_tracking_db call (around LINE 11)

```r
# Initialize eBay tables
tryCatch({
  initialize_ebay_tables("inst/app/data/tracking.sqlite")
  cat("✅ eBay tables initialized\n")
}, error = function(e) {
  cat("⚠️ Failed to initialize eBay tables:", e$message, "\n")
})
```

**VALIDATION:** Check database → ebay_listings table should exist

**IF_FAIL:** Check initialize_ebay_tables function, verify database path

**ROLLBACK:** Remove eBay table initialization

---

## Final Integration Testing

### Manual Test Plan

**Test 1: OAuth Flow**
1. Start app
2. Go to Settings > eBay Connection
3. Click "Connect to eBay"
4. Browser opens with eBay sandbox login
5. Complete authorization
6. Copy code from URL
7. Paste in app, click "Submit Code"
8. **EXPECT:** Green success message "Connected to eBay"

**Test 2: Send to eBay (Happy Path)**
1. Upload face/verso images
2. Extract both sides
3. Combine images (auto or manual)
4. Open accordion for combined image #1
5. Click "Extract with AI"
6. Wait for AI extraction to complete
7. Click "Send to eBay"
8. **EXPECT:**
   - Progress notification "Creating eBay listing..."
   - Success notification with SKU
   - Green status badge "Listed on eBay"
   - Database record created

**Test 3: Send Without AI Data**
1. Upload and combine images
2. Skip AI extraction
3. Click "Send to eBay"
4. **EXPECT:** Warning "Please run AI extraction first"

**Test 4: Send Without Authentication**
1. Don't connect to eBay
2. Try to send listing
3. **EXPECT:** Modal "eBay Connection Required"

**Test 5: Database Verification**
```bash
sqlite3 inst/app/data/tracking.sqlite "SELECT * FROM ebay_listings;"
```
**EXPECT:** Listing record with status='listed', ebay_item_id, ebay_offer_id

**Test 6: eBay Sandbox Verification**
1. Log into eBay Sandbox Seller Hub
2. Check "Active Listings"
3. **EXPECT:** Postcard listing with correct title, price, condition

---

## Rollback Strategy

If integration fails catastrophically:

```r
# 1. Restore original files from backup
cp C:/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/mod_delcampe_export.R.backup R/mod_delcampe_export.R
cp C:/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/app_server.R.backup R/app_server.R
cp C:/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/app_ui.R.backup R/app_ui.R

# 2. Remove new helper file
rm R/ebay_helpers.R

# 3. Revert NAMESPACE
git checkout NAMESPACE

# 4. Restart R session
# 5. Test that app works without eBay integration
```

---

## Success Criteria Checklist

- [ ] **OAuth Flow:** Can connect to eBay sandbox successfully
- [ ] **UI Integration:** "Send to eBay" button appears in export accordion
- [ ] **Authentication Check:** Button disabled/modal shown when not authenticated
- [ ] **AI Data Retrieval:** Successfully retrieves AI data from database
- [ ] **SKU Generation:** Generates unique SKUs with no collisions
- [ ] **Condition Mapping:** Correctly maps Delcampe → eBay conditions
- [ ] **Listing Creation:** Creates listing in eBay sandbox
- [ ] **Database Tracking:** Saves listing info to ebay_listings table
- [ ] **Error Handling:** Shows meaningful errors for failures
- [ ] **Status Display:** Updates UI to show "Listed on eBay" status

---

## Performance Notes

- OAuth token refresh happens automatically (via EbayOAuth class)
- Database queries are lightweight (indexed on card_id)
- eBay API calls are async-compatible (httr2)
- No blocking operations in UI thread

---

## Security Notes

- ✅ Credentials stored in .Renviron (not in code)
- ✅ OAuth tokens stored in data/ebay_tokens.rds (gitignored)
- ✅ Token refresh handled automatically
- ✅ No API keys logged to console
- ⚠️ TODO: Add rate limiting for eBay API calls
- ⚠️ TODO: Encrypt token storage file

---

## Future Enhancements

1. **Image Upload to eBay:** Currently uses empty image_urls - implement eBay Picture Services upload
2. **Bulk Listing:** Add "Send All to eBay" button to export multiple at once
3. **Listing Management:** Add UI to view/edit/end existing eBay listings
4. **Production Mode:** Add environment switcher (sandbox ↔ production)
5. **Policy Configuration:** UI for setting fulfillment/payment/return policies
6. **Price Adjustment:** Allow user to override AI-suggested price before listing
7. **Category Selection:** Auto-detect postcard category or allow manual selection

---

## Documentation Updates Needed

After successful implementation:

1. Update `docs/guides/getting-started.md` - Add eBay setup section
2. Create `docs/EBAY_SETUP_GUIDE.md` - Detailed eBay credential setup
3. Update `.serena/memories/INDEX.md` - Add eBay integration memory
4. Create `.serena/memories/ebay_integration_complete_YYYYMMDD.md` - Implementation details
5. Update `CLAUDE.md` - Add eBay integration to constraints section if needed

---

**End of Task PRP**
