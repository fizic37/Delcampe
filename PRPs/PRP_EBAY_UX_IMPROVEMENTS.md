# PRP: eBay Listing UX Improvements

**Status**: Ready for Implementation
**Priority**: High
**Created**: 2025-10-28
**Estimated Effort**: 4-6 hours

## Context

The eBay Trading API integration is working successfully, but the user experience needs improvement:
- No confirmation before creating listings
- No feedback during the 10-15 second listing process
- Condition values may not match eBay's accepted values
- AI extraction doesn't capture eBay-specific metadata (Era, City)
- eBay export UI is basic and lacks polish

## Problem Statement

Users need:
1. **Confidence**: Confirmation dialog before irreversible listing creation
2. **Feedback**: Progress messages during the long listing process
3. **Accuracy**: Condition values that match eBay's requirements exactly
4. **Completeness**: AI should extract Era, City, and other eBay-specific data
5. **Polish**: Modern, professional UI for eBay export functionality

## Success Criteria

- [ ] User must confirm before listing is created on eBay
- [ ] Progress messages show: "Uploading image...", "Creating listing...", "Saving..."
- [ ] Condition dropdown matches eBay's accepted values with "Used" as default
- [ ] AI extraction includes: Era (with year), City, Theme hints
- [ ] eBay export UI is modernized with better layout and feedback

## Technical Requirements

### 1. Condition Value Validation

**Current State**:
- AI returns: "mint", "near mint", "excellent", "very good", "good", "fair", "poor", "used"
- eBay Trading API expects ConditionID integers: 3000 (Mint), 4000 (Very Good), etc.
- Default should be "Used" (3000)

**Required Changes**:

**R/ebay_helpers.R**:
```r
#' Map condition to Trading API ConditionID
#' @export
map_condition_to_trading_id <- function(condition_str) {
  # Default to "Used" if not specified
  if (is.null(condition_str) || condition_str == "") {
    condition_str <- "used"
  }

  condition_str <- tolower(trimws(condition_str))

  condition_map <- list(
    "mint" = 3000,
    "near mint" = 3000,
    "excellent" = 3000,
    "very good" = 4000,
    "good" = 5000,
    "fair" = 6000,
    "poor" = 7000,
    "used" = 3000  # Default to Used/Mint
  )

  # Return mapped value or default to Used
  condition_map[[condition_str]] %||% 3000
}
```

**R/mod_delcampe_export.R** - Add condition dropdown with default:
```r
selectInput(
  ns("condition_override"),
  "Condition:",
  choices = c(
    "Used" = "used",
    "Mint" = "mint",
    "Near Mint" = "near mint",
    "Excellent" = "excellent",
    "Very Good" = "very good",
    "Good" = "good",
    "Fair" = "fair",
    "Poor" = "poor"
  ),
  selected = "used"  # Default to Used
)
```

### 2. Confirmation Dialog

**Required Changes**:

**R/mod_delcampe_export.R** - Add confirmation modal:
```r
# When Send to eBay is clicked
observeEvent(input$send_to_ebay, {
  # Get current data
  card_data <- get_current_card_data()

  # Show confirmation modal
  showModal(modalDialog(
    title = "Confirm eBay Listing",
    size = "m",

    div(
      style = "padding: 15px;",

      h4("You are about to create an eBay listing:"),

      tags$ul(
        tags$li(strong("Title: "), card_data$title),
        tags$li(strong("Price: "), paste0("$", card_data$price)),
        tags$li(strong("Condition: "), card_data$condition),
        tags$li(strong("Category: "), "Topographical Postcards")
      ),

      br(),

      div(
        style = "background-color: #fff3cd; border: 1px solid #ffc107; padding: 10px; border-radius: 5px;",
        icon("exclamation-triangle"),
        strong(" Warning: "),
        "This will create a live listing on eBay. ",
        "Listing fees may apply. You can end the listing later if needed."
      )
    ),

    footer = tagList(
      modalButton("Cancel"),
      actionButton(
        ns("confirm_send_to_ebay"),
        "Create Listing",
        class = "btn-primary",
        icon = icon("check")
      )
    )
  ))
})

# Handle confirmed action
observeEvent(input$confirm_send_to_ebay, {
  removeModal()
  # Proceed with actual listing creation
  create_listing_with_progress()
})
```

### 3. Progress Messages

**Required Changes**:

**R/ebay_integration.R** - Add progress callback parameter:
```r
create_ebay_listing_from_card <- function(card_id, ai_data, ebay_api, session_id,
                                          image_url = NULL, ebay_user_id = NULL,
                                          ebay_username = NULL,
                                          progress_callback = NULL) {

  if (!is.null(progress_callback)) {
    progress_callback("Validating data...", 0.1)
  }

  # Step 1: Validate
  validation <- validate_required_fields(ai_data, image_url)
  # ... existing validation code ...

  # Step 2: Upload image
  if (!is.null(progress_callback)) {
    progress_callback("Uploading image to eBay...", 0.3)
  }
  upload_result <- ebay_api$trading$upload_image(image_url)
  # ... existing upload code ...

  # Step 3: Detect country
  if (!is.null(progress_callback)) {
    progress_callback("Detecting account location...", 0.5)
  }
  # ... existing country detection ...

  # Step 4: Build request
  if (!is.null(progress_callback)) {
    progress_callback("Preparing listing data...", 0.7)
  }
  # ... existing build code ...

  # Step 5: Create listing
  if (!is.null(progress_callback)) {
    progress_callback("Creating eBay listing...", 0.8)
  }
  result <- ebay_api$trading$add_fixed_price_item(item_data)
  # ... existing creation code ...

  # Step 6: Save to database
  if (!is.null(progress_callback)) {
    progress_callback("Saving to database...", 0.95)
  }
  save_success <- save_ebay_listing(...)
  # ... existing save code ...

  if (!is.null(progress_callback)) {
    progress_callback("Complete!", 1.0)
  }

  return(result)
}
```

**R/mod_delcampe_export.R** - Show progress:
```r
create_listing_with_progress <- function() {
  # Create progress indicator
  progress <- shiny::Progress$new()
  on.exit(progress$close())

  progress$set(message = "Creating eBay listing...", value = 0)

  # Call with progress callback
  result <- create_ebay_listing_from_card(
    card_id = current_card_id,
    ai_data = ai_data,
    ebay_api = ebay_api(),
    session_id = session$token,
    image_url = image_path,
    ebay_user_id = ebay_user_id,
    ebay_username = ebay_username,
    progress_callback = function(message, value) {
      progress$set(message = message, value = value)
    }
  )

  if (result$success) {
    showNotification(
      paste0("✅ Listing created! Item ID: ", result$item_id),
      type = "message",
      duration = 10
    )
  } else {
    showNotification(
      paste0("❌ Failed: ", result$error),
      type = "error",
      duration = 10
    )
  }
}
```

### 4. AI Extraction Enhancement

**Current AI Prompt**: Located in AI extraction modules
**Required Enhancement**: Add eBay-specific fields to extraction

**R/ai_api_helpers.R** or similar - Update prompt:
```r
system_prompt <- "You are an expert at analyzing vintage postcards. Extract:

REQUIRED:
- title: Descriptive title (max 80 chars)
- description: Detailed description (condition, imagery, text visible)
- price: USD price (numeric)
- condition: One of: used, mint, near mint, excellent, very good, good, fair, poor

EBAY METADATA (NEW):
- year: Year visible on postcard or postmark (e.g., 1957)
- era: Postcard era if year present:
  - pre-1907: Undivided Back
  - 1907-1915: Divided Back
  - 1930-1945: Linen
  - 1939+: Chrome
- city: City/town name visible (e.g., Buziaș)
- country: Country name (e.g., Romania)
- region: State/region if visible (e.g., Timiș County)
- theme_keywords: Keywords for theme detection (e.g., view, town, church, landscape)

Return as JSON with all fields."
```

**Parse AI response to include new fields**:
```r
parse_ai_extraction <- function(ai_response) {
  # Parse JSON
  data <- jsonlite::fromJSON(ai_response)

  # Ensure required fields
  data$title <- data$title %||% "Vintage Postcard"
  data$description <- data$description %||% ""
  data$price <- as.numeric(data$price) %||% 5.00
  data$condition <- data$condition %||% "used"

  # NEW: Parse eBay metadata
  data$year <- data$year %||% NULL
  data$era <- data$era %||% infer_era_from_year(data$year)
  data$city <- data$city %||% NULL
  data$country <- data$country %||% NULL
  data$region <- data$region %||% NULL
  data$theme_keywords <- data$theme_keywords %||% NULL

  return(data)
}
```

**Use in aspect extraction**:
```r
extract_postcard_aspects <- function(ai_data, condition_code = NULL) {
  aspects <- list(
    "Type" = list("Postcard")
  )

  # Use AI-extracted era if available
  if (!is.null(ai_data$era)) {
    aspects[["Era"]] <- list(ai_data$era)
  } else if (!is.null(ai_data$year)) {
    # Infer from year
    aspects[["Era"]] <- list(infer_era_from_year(ai_data$year))
  } else {
    # Fall back to text parsing
    aspects[["Era"]] <- list(infer_era_from_text(ai_data))
  }

  # Use AI-extracted theme keywords
  if (!is.null(ai_data$theme_keywords)) {
    aspects[["Theme"]] <- list(infer_theme_from_keywords(ai_data$theme_keywords))
  } else {
    aspects[["Theme"]] <- list(infer_theme_from_text(ai_data))
  }

  # Add city to description if present
  if (!is.null(ai_data$city)) {
    aspects[["City"]] <- list(ai_data$city)
  }

  return(aspects)
}
```

### 5. UI Modernization

**Current State**: Basic card layout in mod_delcampe_export.R
**Required Changes**: Modern, polished UI with better feedback

**R/mod_delcampe_export.R** - UI improvements:
```r
# Modern card layout
bslib::card(
  full_screen = TRUE,
  height = "100%",

  bslib::card_header(
    class = "bg-primary text-white",
    div(
      style = "display: flex; justify-content: space-between; align-items: center;",
      div(
        icon("store", style = "font-size: 24px; margin-right: 10px;"),
        span("eBay Export", style = "font-size: 20px; font-weight: 600;")
      ),
      div(
        # Connection status indicator
        uiOutput(ns("connection_status"))
      )
    )
  ),

  bslib::card_body(
    class = "p-4",

    # Preview section
    div(
      class = "mb-4",
      h4("Preview", class = "mb-3"),
      div(
        class = "row",
        div(
          class = "col-md-4",
          div(
            class = "border rounded p-3",
            imageOutput(ns("card_preview"), height = "200px")
          )
        ),
        div(
          class = "col-md-8",
          div(
            class = "border rounded p-3",
            h5(textOutput(ns("preview_title"))),
            p(textOutput(ns("preview_description"))),
            div(
              style = "display: flex; gap: 20px; margin-top: 15px;",
              div(
                strong("Price: "),
                span(textOutput(ns("preview_price")), style = "color: #28a745; font-size: 18px;")
              ),
              div(
                strong("Condition: "),
                span(textOutput(ns("preview_condition")))
              )
            )
          )
        )
      )
    ),

    # Edit section
    div(
      class = "mb-4",
      h4("Edit Details", class = "mb-3"),

      textInput(
        ns("title_override"),
        "Title:",
        placeholder = "Auto-filled from AI extraction",
        width = "100%"
      ),

      textAreaInput(
        ns("description_override"),
        "Description:",
        rows = 4,
        placeholder = "Auto-filled from AI extraction",
        width = "100%"
      ),

      div(
        class = "row",
        div(
          class = "col-md-4",
          numericInput(
            ns("price_override"),
            "Price (USD):",
            value = NULL,
            min = 0.99,
            step = 0.50,
            width = "100%"
          )
        ),
        div(
          class = "col-md-4",
          selectInput(
            ns("condition_override"),
            "Condition:",
            choices = c(
              "Used" = "used",
              "Mint" = "mint",
              "Near Mint" = "near mint",
              "Excellent" = "excellent",
              "Very Good" = "very good",
              "Good" = "good",
              "Fair" = "fair",
              "Poor" = "poor"
            ),
            selected = "used",
            width = "100%"
          )
        ),
        div(
          class = "col-md-4",
          numericInput(
            ns("quantity_override"),
            "Quantity:",
            value = 1,
            min = 1,
            max = 10,
            width = "100%"
          )
        )
      )
    ),

    # Action section
    div(
      class = "d-flex justify-content-end gap-2",
      actionButton(
        ns("refresh_preview"),
        "Refresh Preview",
        icon = icon("refresh"),
        class = "btn-outline-secondary"
      ),
      actionButton(
        ns("send_to_ebay"),
        "Send to eBay",
        icon = icon("upload"),
        class = "btn-lg btn-success",
        style = "padding: 12px 30px; font-weight: 600;"
      )
    )
  )
)
```

## Implementation Steps

### Phase 1: Condition & Validation (1 hour)
1. Update `map_condition_to_trading_id()` with default "used"
2. Add condition dropdown to UI with "Used" selected
3. Test condition mapping with all values

### Phase 2: Confirmation Dialog (1 hour)
1. Add confirmation modal to mod_delcampe_export.R
2. Split send_to_ebay observer into confirm + execute
3. Test confirmation flow

### Phase 3: Progress Messages (1.5 hours)
1. Add progress_callback parameter to `create_ebay_listing_from_card()`
2. Add progress indicators at each step
3. Update mod_delcampe_export.R to show Progress bar
4. Test progress display

### Phase 4: AI Extraction Enhancement (1.5 hours)
1. Update AI prompt to include eBay metadata fields
2. Update parse_ai_extraction() to handle new fields
3. Update extract_postcard_aspects() to use AI metadata
4. Add helper functions: infer_era_from_year(), infer_theme_from_keywords()
5. Test extraction with sample postcards

### Phase 5: UI Modernization (1 hour)
1. Redesign mod_delcampe_export UI with bslib cards
2. Add preview section with image/title/description/price
3. Add connection status indicator
4. Improve button styling and layout
5. Test UI responsiveness

## Testing Checklist

- [ ] Condition dropdown defaults to "Used"
- [ ] All condition values map correctly to eBay ConditionIDs
- [ ] Confirmation modal appears before listing creation
- [ ] User can cancel confirmation
- [ ] Progress bar shows all 6 steps with messages
- [ ] AI extracts year, era, city, country correctly
- [ ] AI-extracted era appears in item specifics
- [ ] AI-extracted theme improves classification
- [ ] UI preview shows correct data
- [ ] UI is responsive on different screen sizes
- [ ] Complete flow: Extract → Preview → Edit → Confirm → Progress → Success

## Files to Modify

1. **R/ebay_helpers.R**
   - Update `map_condition_to_trading_id()` with default
   - Enhance `extract_postcard_aspects()` to use AI metadata
   - Add helper functions for era/theme inference

2. **R/ebay_integration.R**
   - Add `progress_callback` parameter
   - Add progress calls at each step

3. **R/mod_delcampe_export.R**
   - Redesign UI with modern layout
   - Add condition dropdown with default "Used"
   - Add confirmation modal
   - Add progress bar implementation
   - Add preview section

4. **R/ai_api_helpers.R** (or extraction module)
   - Update AI prompt with eBay metadata fields
   - Update response parser for new fields

## Success Metrics

- ✅ Zero accidental listings (confirmation required)
- ✅ User can see progress for 100% of listing operations
- ✅ Condition accuracy: 100% match with eBay accepted values
- ✅ AI extraction: Era detected in 80%+ of postcards with dates
- ✅ UI polish: Modern, professional appearance
- ✅ User satisfaction: Clear feedback at every step

## Dependencies

- Existing: bslib, shiny
- No new packages required

## Risk Assessment

**Low Risk**:
- Changes are additive (don't break existing functionality)
- Confirmation dialog prevents accidental listings
- Progress callbacks are optional (graceful degradation)
- AI prompt enhancement is backward compatible

**Testing Priority**: High - Test complete flow multiple times

## Future Enhancements

- Save draft listings before sending to eBay
- Bulk upload multiple cards at once
- Schedule listings for future dates
- Auto-calculate shipping costs
- International shipping options
