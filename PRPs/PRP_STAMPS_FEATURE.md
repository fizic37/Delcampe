# PRP: Stamps Feature for Delcampe Postal Processor

## Executive Summary

This PRP defines the implementation of a comprehensive Stamps processing feature for the Delcampe Postal Card Processor application. The feature will use the **exact same logic** as Postal Cards including face/verso image uploading, gridlines, tracking, and AI extraction, but will deploy to eBay category 260 (Stamps) with stamp-specific metadata and prompts.

**Key Points:**
- **Reuse 100% of postal card logic**: Face/verso upload, grid detection, extraction, tracking
- **Only differences**:
  1. eBay category 260 (Stamps) instead of 262042 (Postcards)
  2. AI prompts adapted for stamps (perforation, watermark, denomination, Scott number)
  3. Database tables named `stamps`, `stamp_processing`, `ebay_stamp_listings`
  4. UI labels say "Stamp" instead of "Postal Card"

---

## Problem Statement

Currently, the application only handles postal cards. Users who collect and sell stamps require the same processing capabilities with:

1. **Face/Verso Upload**: Same dual-sided processing as postal cards
2. **Grid Detection**: Reuse exact gridline system
3. **Extraction**: Generate individual stamp images and lots
4. **AI Metadata**: Extract stamp-specific information (country, denomination, year, grade, perforation)
5. **Tracking**: Integrate with existing 3-layer database architecture
6. **eBay Deployment**: List stamps in eBay category 260 with stamp-specific attributes

---

## Solution Design

### Architecture Overview

**Copy postal card architecture 1:1, rename entities:**

```
Stamps Menu (New)
    ├── Face Upload (exact copy of postal card face)
    ├── Verso Upload (exact copy of postal card verso)
    ├── Grid Detection & Cross-Sync (exact same logic)
    ├── Extract Individual Stamps / Lots (exact same extraction)
    ├── AI Metadata Extraction (NEW stamps prompt)
    ├── Combined Image Display (exact same)
    ├── Tracking Integration (NEW stamps tables)
    └── eBay Deployment (category 260 with stamp aspects)

Backend Modules
    ├── mod_stamp_face_processor.R (copy of mod_postal_card_processor.R)
    ├── mod_stamp_verso_processor.R (copy of mod_postal_card_processor.R)
    ├── mod_stamp_export.R (copy of mod_delcampe_export.R)
    ├── stamp_ai_helpers.R (NEW - stamp prompts only)
    ├── ebay_stamp_helpers.R (NEW - category 260 mapping)
    └── tracking_database.R (EXTEND - add stamps tables)
```

---

## Implementation Plan

### Phase 1: Database Schema Extension

**File:** `R/tracking_database.R`

**New Tables (exact copies of postal card tables with renamed entities):**

```r
# Table 1: Stamps (exact copy of postal_cards table)
CREATE TABLE IF NOT EXISTS stamps (
  stamp_id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_hash TEXT UNIQUE NOT NULL,
  image_type TEXT NOT NULL CHECK(image_type IN ('face', 'verso', 'combined')),
  original_filename TEXT,
  file_size INTEGER,
  dimensions TEXT,
  upload_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_accessed DATETIME DEFAULT CURRENT_TIMESTAMP
)

# Table 2: Stamp Processing (exact copy of card_processing with stamp fields)
CREATE TABLE IF NOT EXISTS stamp_processing (
  processing_id INTEGER PRIMARY KEY AUTOINCREMENT,
  stamp_id INTEGER NOT NULL,
  crop_paths TEXT,
  h_boundaries TEXT,
  v_boundaries TEXT,
  grid_rows INTEGER,
  grid_cols INTEGER,
  extraction_dir TEXT,
  ai_title TEXT,
  ai_description TEXT,
  ai_condition TEXT,
  ai_price REAL,
  ai_model TEXT,
  ai_country TEXT,
  ai_year INTEGER,
  ai_denomination TEXT,
  ai_scott_number TEXT,
  ai_perforation TEXT,
  ai_watermark TEXT,
  ai_grade TEXT,
  processed_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (stamp_id) REFERENCES stamps(stamp_id)
)

# Table 3: eBay Stamp Listings (exact copy of ebay_listings)
CREATE TABLE IF NOT EXISTS ebay_stamp_listings (
  listing_id INTEGER PRIMARY KEY AUTOINCREMENT,
  stamp_id INTEGER NOT NULL,
  session_id TEXT NOT NULL,
  ebay_item_id TEXT,
  ebay_offer_id TEXT,
  sku TEXT UNIQUE NOT NULL,
  status TEXT DEFAULT 'draft',
  environment TEXT DEFAULT 'sandbox',
  title TEXT,
  description TEXT,
  price REAL,
  quantity INTEGER DEFAULT 1,
  condition TEXT,
  category_id TEXT DEFAULT '260',
  listing_url TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  listed_at DATETIME,
  last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
  error_message TEXT,
  FOREIGN KEY (stamp_id) REFERENCES stamps(stamp_id),
  FOREIGN KEY (session_id) REFERENCES sessions(session_id)
)
```

**Helper Functions (exact copies with renamed entities):**

```r
# Get or create stamp (exact copy of get_or_create_card)
get_or_create_stamp <- function(file_hash, image_type, original_filename, file_size, dimensions) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  # Check for existing stamp
  existing <- DBI::dbGetQuery(con,
    "SELECT stamp_id FROM stamps WHERE file_hash = ? AND image_type = ?",
    params = list(file_hash, image_type))

  if (nrow(existing) > 0) {
    # Update last_accessed
    DBI::dbExecute(con,
      "UPDATE stamps SET last_accessed = CURRENT_TIMESTAMP WHERE stamp_id = ?",
      params = list(existing$stamp_id[1]))
    return(existing$stamp_id[1])
  }

  # Create new stamp
  DBI::dbExecute(con,
    "INSERT INTO stamps (file_hash, image_type, original_filename, file_size, dimensions)
     VALUES (?, ?, ?, ?, ?)",
    params = list(file_hash, image_type, original_filename, file_size, dimensions))

  new_stamp <- DBI::dbGetQuery(con,
    "SELECT stamp_id FROM stamps WHERE file_hash = ? AND image_type = ?",
    params = list(file_hash, image_type))

  return(new_stamp$stamp_id[1])
}

# Save stamp processing (exact copy of save_card_processing)
save_stamp_processing <- function(stamp_id, crop_paths, h_boundaries, v_boundaries,
                                  grid_rows, grid_cols, extraction_dir, ai_data) {
  # Exact same logic as save_card_processing, just use stamp_processing table
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  crop_paths_json <- if (!is.null(crop_paths)) jsonlite::toJSON(crop_paths) else NULL
  h_boundaries_json <- if (!is.null(h_boundaries)) jsonlite::toJSON(h_boundaries) else NULL
  v_boundaries_json <- if (!is.null(v_boundaries)) jsonlite::toJSON(v_boundaries) else NULL

  # Check if processing exists
  existing <- DBI::dbGetQuery(con,
    "SELECT processing_id FROM stamp_processing WHERE stamp_id = ?",
    params = list(stamp_id))

  if (nrow(existing) > 0) {
    # Update existing (same COALESCE logic as postal cards)
    DBI::dbExecute(con,
      "UPDATE stamp_processing SET
       crop_paths = COALESCE(?, crop_paths),
       h_boundaries = COALESCE(?, h_boundaries),
       v_boundaries = COALESCE(?, v_boundaries),
       grid_rows = COALESCE(?, grid_rows),
       grid_cols = COALESCE(?, grid_cols),
       extraction_dir = COALESCE(?, extraction_dir),
       ai_title = COALESCE(?, ai_title),
       ai_description = COALESCE(?, ai_description),
       ai_condition = COALESCE(?, ai_condition),
       ai_price = COALESCE(?, ai_price),
       ai_model = COALESCE(?, ai_model),
       ai_country = COALESCE(?, ai_country),
       ai_year = COALESCE(?, ai_year),
       ai_denomination = COALESCE(?, ai_denomination),
       ai_scott_number = COALESCE(?, ai_scott_number),
       ai_perforation = COALESCE(?, ai_perforation),
       ai_watermark = COALESCE(?, ai_watermark),
       ai_grade = COALESCE(?, ai_grade),
       processed_timestamp = CURRENT_TIMESTAMP
       WHERE stamp_id = ?",
      params = list(
        crop_paths_json, h_boundaries_json, v_boundaries_json,
        grid_rows, grid_cols, extraction_dir,
        ai_data$title, ai_data$description, ai_data$condition,
        ai_data$price, ai_data$model,
        ai_data$country, ai_data$year, ai_data$denomination,
        ai_data$scott_number, ai_data$perforation, ai_data$watermark,
        ai_data$grade, stamp_id
      ))
  } else {
    # Insert new
    DBI::dbExecute(con,
      "INSERT INTO stamp_processing (
       stamp_id, crop_paths, h_boundaries, v_boundaries,
       grid_rows, grid_cols, extraction_dir,
       ai_title, ai_description, ai_condition, ai_price, ai_model,
       ai_country, ai_year, ai_denomination, ai_scott_number,
       ai_perforation, ai_watermark, ai_grade
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      params = list(
        stamp_id, crop_paths_json, h_boundaries_json, v_boundaries_json,
        grid_rows, grid_cols, extraction_dir,
        ai_data$title, ai_data$description, ai_data$condition,
        ai_data$price, ai_data$model,
        ai_data$country, ai_data$year, ai_data$denomination,
        ai_data$scott_number, ai_data$perforation, ai_data$watermark,
        ai_data$grade
      ))
  }
}

# Find stamp processing (exact copy of find_card_processing)
find_stamp_processing <- function(file_hash, image_type) {
  # Exact same logic as find_card_processing
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  result <- DBI::dbGetQuery(con,
    "SELECT s.stamp_id, s.file_hash, s.image_type, s.last_accessed,
            sp.crop_paths, sp.h_boundaries, sp.v_boundaries,
            sp.grid_rows, sp.grid_cols, sp.ai_title, sp.ai_description,
            sp.ai_model, sp.processed_timestamp as last_processed
     FROM stamps s
     LEFT JOIN stamp_processing sp ON s.stamp_id = sp.stamp_id
     WHERE s.file_hash = ? AND s.image_type = ?",
    params = list(file_hash, image_type))

  if (nrow(result) == 0) {
    return(NULL)
  }

  # Parse JSON fields
  row <- result[1, ]
  if (!is.na(row$crop_paths) && !is.null(row$crop_paths)) {
    row$crop_paths <- jsonlite::fromJSON(row$crop_paths)
  }
  if (!is.na(row$h_boundaries) && !is.null(row$h_boundaries)) {
    row$h_boundaries <- jsonlite::fromJSON(row$h_boundaries)
  }
  if (!is.na(row$v_boundaries) && !is.null(row$v_boundaries)) {
    row$v_boundaries <- jsonlite::fromJSON(row$v_boundaries)
  }

  return(row)
}
```

---

### Phase 2: Stamp Processor Modules (Exact Copies)

**File 1:** `R/mod_stamp_face_processor.R`
- **Action**: Copy `mod_postal_card_processor.R` entirely
- **Changes**:
  - Replace all `card` with `stamp`
  - Replace all `postcard` with `stamp`
  - Set `card_type = "face"` → `stamp_type = "face"`
  - Call `get_or_create_stamp()` instead of `get_or_create_card()`
  - Call `save_stamp_processing()` instead of `save_card_processing()`
  - Call `find_stamp_processing()` instead of `find_card_processing()`

**File 2:** `R/mod_stamp_verso_processor.R`
- **Action**: Copy `mod_postal_card_processor.R` entirely
- **Changes**: Same as Face but with `stamp_type = "verso"`

**Implementation Note:**
These are literally copy-paste files with find-replace:
- `postal_card` → `stamp`
- `card_id` → `stamp_id`
- `get_or_create_card` → `get_or_create_stamp`
- UI labels: "Upload Face image" → "Upload Stamp Face image"

---

### Phase 3: AI Stamp Extraction Prompts

**File:** `R/stamp_ai_helpers.R` (NEW)

**Stamp-Specific Prompt Builder:**

```r
#' Build Stamp Analysis Prompt
#'
#' @param extraction_type "individual" or "lot"
#' @param stamp_count Number of stamps (for lot type)
#' @return Formatted prompt string
#' @export
build_stamp_prompt <- function(extraction_type = "individual", stamp_count = 1) {

  # CRITICAL: ASCII-only instruction at the top
  ascii_instruction <- "IMPORTANT: Use ONLY ASCII characters in your output. Replace all diacritics:
- Romanian: ă→a, â→a, î→i, ș→s, ț→t
- European: é→e, è→e, ü→u, ö→o, ñ→n, ç→c
- Examples: București → Bucuresti, café → cafe

"

  base_prompt <- "You are an expert philatelist and stamp appraiser. Analyze this stamp image carefully and provide:\n\n"

  if (extraction_type == "lot") {
    prompt <- paste0(ascii_instruction, base_prompt,
      "IMPORTANT: This is a lot of ", stamp_count, " stamps.\n",
      "The image shows BOTH SIDES of each stamp:\n",
      "- TOP ROW: Front/face sides (", stamp_count, " images)\n",
      "- BOTTOM ROW: Back/verso sides (", stamp_count, " images)\n",
      "- TOTAL STAMPS: ", stamp_count, " (not ", stamp_count * 2, "!)\n\n",

      "REQUIRED FIELDS:\n\n",
      "1. TITLE: eBay-optimized title (MAXIMUM 80 characters)\n",
      "   - ALL UPPERCASE format\n",
      "   - Use dashes (-) to separate sections\n",
      "   - ASCII only (e.g., Osterreich not Österreich)\n",
      "   - Element order: COUNTRY - YEAR DENOMINATION TOPIC/TYPE FEATURES\n",
      "   - Front-load important search terms (country, year, Scott number)\n",
      "   - Include special features: PERFIN, OVERPRINT, CANCELLATION, MNH, MINT\n",
      "   - No articles (a, an, the) or filler words\n",
      "   - Examples:\n",
      "     * 'USA - 1963 5c WASHINGTON COIL PERFIN LOT OF 3'\n",
      "     * 'ROMANIA - 1920s FERDINAND OVERPRINT MINT HINGED SET 5'\n",
      "     * 'GERMANY - 1940 THIRD REICH PROPAGANDA USED LOT 8'\n\n",

      "2. DESCRIPTION: Detailed description (150-300 characters, ASCII only)\n",
      "   - Country of origin\n",
      "   - Approximate year or era\n",
      "   - Denomination and currency (if visible)\n",
      "   - Topic or theme (e.g., royalty, transportation, flora)\n",
      "   - Notable features (perforations, watermarks, overprints)\n",
      "   - DO NOT assess condition - seller will determine that\n\n",

      "3. RECOMMENDED_PRICE: Suggest eBay sale price in US Dollars (USD)\n",
      "   - Price for ALL ", stamp_count, " stamps combined\n",
      "   - Typical range per stamp: $0.50 - $5.00 (common), $5+ (scarce)\n",
      "   - Format: numeric value only (e.g., 12.00 for 4 stamps at $3 each)\n\n",

      "EBAY METADATA (extract from most prominent/clear stamp):\n",
      "IMPORTANT: These fields improve eBay search ranking - extract when visible!\n\n",

      "4. COUNTRY: Country of origin (e.g., United States, Romania, Germany)\n",
      "   - Use English country name\n",
      "   - If not visible, omit this field\n\n",

      "5. YEAR: Year of issue (e.g., 1957)\n",
      "   - Look carefully at printed year on stamp\n",
      "   - If multiple years visible, use earliest\n",
      "   - If not visible, omit this field\n\n",

      "6. DENOMINATION: Face value (e.g., 5c, 10 bani, 2 francs)\n",
      "   - Include currency symbol or abbreviation\n",
      "   - If multiple denominations, list primary one\n\n",

      "7. SCOTT_NUMBER: Scott catalog number (if identifiable)\n",
      "   - Format: Country abbreviation + number (e.g., US-1234, RO-567)\n",
      "   - Only include if you are confident\n",
      "   - If uncertain, omit this field\n\n",

      "8. PERFORATION: Perforation type (e.g., Perf 12, Imperf, Rouletted)\n",
      "   - Only if clearly visible and identifiable\n\n",

      "9. WATERMARK: Watermark description (if visible)\n",
      "   - Only if clearly visible (rare in photo analysis)\n\n",

      "10. GRADE: Condition grade\n",
      "   - Mint Never Hinged (MNH): Perfect, no hinge marks\n",
      "   - Mint Hinged (MH): Perfect but has hinge remnant\n",
      "   - Used: Postally used with cancellation\n",
      "   - Unused: Not used but may have faults\n\n",

      "FORMAT YOUR RESPONSE EXACTLY AS:\n",
      "TITLE: [your title]\n",
      "DESCRIPTION: [your description]\n",
      "RECOMMENDED_PRICE: [numeric value]\n",
      "COUNTRY: [country name]\n",
      "YEAR: [year]\n",
      "DENOMINATION: [value]\n",
      "SCOTT_NUMBER: [catalog number]\n",
      "PERFORATION: [type]\n",
      "WATERMARK: [description]\n",
      "GRADE: [condition]"
    )
  } else {
    # Individual stamp prompt (similar structure, singular references)
    prompt <- paste0(ascii_instruction, base_prompt,
      "1. A concise TITLE (max 80 characters) suitable for an online auction listing\n",
      "2. A detailed DESCRIPTION (150-300 characters) including:\n",
      "   - Country of origin\n",
      "   - Year of issue (if visible)\n",
      "   - Denomination and currency\n",
      "   - Subject depicted (portrait, scene, symbol)\n",
      "   - Perforations, watermarks, overprints\n",
      "   - Scott catalog number (if identifiable)\n",
      "   - Historical or collecting significance\n\n",

      "3. RECOMMENDED_PRICE: Suggested retail price in USD\n",
      "4. COUNTRY: Country of origin\n",
      "5. YEAR: Year of issue\n",
      "6. DENOMINATION: Face value with currency\n",
      "7. SCOTT_NUMBER: Scott catalog number\n",
      "8. PERFORATION: Perforation type\n",
      "9. WATERMARK: Watermark description\n",
      "10. GRADE: Condition grade (MNH/MH/Used/Unused)\n\n",

      "Format your response EXACTLY as:\n",
      "TITLE: [your title]\n",
      "DESCRIPTION: [your description]\n",
      "RECOMMENDED_PRICE: [numeric value]\n",
      "COUNTRY: [country name]\n",
      "YEAR: [year]\n",
      "DENOMINATION: [value]\n",
      "SCOTT_NUMBER: [catalog number]\n",
      "PERFORATION: [type]\n",
      "WATERMARK: [description]\n",
      "GRADE: [condition]"
    )
  }

  return(prompt)
}

#' Parse Stamp AI Response
#'
#' @param response_text Raw AI response text
#' @return List with extracted stamp metadata
#' @export
parse_stamp_response <- function(response_text) {

  # Helper to extract field
  extract_field <- function(text, field_name) {
    pattern <- paste0(field_name, ":\\s*(.+?)(?=\\n[A-Z_]+:|$)")
    match <- regmatches(text, regexec(pattern, text, perl = TRUE))
    if (length(match[[1]]) > 1) {
      return(trimws(match[[1]][2]))
    }
    return(NA_character_)
  }

  # Extract all fields (same as postal cards plus stamp-specific)
  result <- list(
    title = extract_field(response_text, "TITLE"),
    description = extract_field(response_text, "DESCRIPTION"),
    recommended_price = as.numeric(extract_field(response_text, "RECOMMENDED_PRICE")),
    country = extract_field(response_text, "COUNTRY"),
    year = as.integer(extract_field(response_text, "YEAR")),
    denomination = extract_field(response_text, "DENOMINATION"),
    scott_number = extract_field(response_text, "SCOTT_NUMBER"),
    perforation = extract_field(response_text, "PERFORATION"),
    watermark = extract_field(response_text, "WATERMARK"),
    grade = extract_field(response_text, "GRADE")
  )

  return(result)
}
```

**Integration:**
Extend `mod_ai_extraction_server` to detect if `image_type = "stamp"` and call `build_stamp_prompt()` instead of `build_postal_card_prompt()`.

---

### Phase 4: eBay Stamps Integration

**File:** `R/ebay_stamp_helpers.R` (NEW)

```r
#' Map Stamp Grade to eBay Condition
#'
#' @param grade Grade from AI extraction (MNH, MH, Used, Unused)
#' @return eBay condition code
#' @export
map_stamp_grade_to_ebay <- function(grade) {
  if (is.null(grade) || is.na(grade)) {
    return("UNSPECIFIED")
  }

  grade_upper <- toupper(trimws(grade))

  # Exact matches
  if (grade_upper == "MNH" || grepl("NEVER.*HINGED", grade_upper)) {
    return("USED")  # Use "USED" to avoid Error 25019 per existing postal card logic
  } else if (grade_upper == "MH" || grepl("MINT.*HINGED", grade_upper)) {
    return("USED")
  } else if (grepl("USED", grade_upper)) {
    return("USED")
  } else if (grepl("UNUSED", grade_upper)) {
    return("USED")
  } else {
    return("UNSPECIFIED")
  }
}

#' Extract Stamp Aspects for eBay
#'
#' @param ai_data AI extraction data
#' @param condition_code eBay condition code
#' @return List of eBay aspects
#' @export
extract_stamp_aspects <- function(ai_data, condition_code = NULL) {

  aspects <- list()

  # Type (required for stamps)
  if (!is.null(ai_data$stamp_count) && ai_data$stamp_count > 1) {
    aspects[["Type"]] <- list("Lot")
  } else {
    aspects[["Type"]] <- list("Individual Stamp")
  }

  # Country
  if (!is.null(ai_data$country) && !is.na(ai_data$country)) {
    aspects[["Country/Region of Manufacture"]] <- list(ai_data$country)
  }

  # Year
  if (!is.null(ai_data$year) && !is.na(ai_data$year)) {
    aspects[["Year of Issue"]] <- list(as.character(ai_data$year))
  }

  # Grade (critical for stamps)
  if (!is.null(ai_data$grade) && !is.na(ai_data$grade)) {
    aspects[["Grade"]] <- list(ai_data$grade)
  }

  # Certification (default to uncertified)
  aspects[["Certification"]] <- list("Uncertified")

  # Denomination
  if (!is.null(ai_data$denomination) && !is.na(ai_data$denomination)) {
    aspects[["Denomination"]] <- list(ai_data$denomination)
  }

  # Scott Number (if available)
  if (!is.null(ai_data$scott_number) && !is.na(ai_data$scott_number)) {
    aspects[["Catalog Number"]] <- list(ai_data$scott_number)
  }

  # Perforation (if available)
  if (!is.null(ai_data$perforation) && !is.na(ai_data$perforation)) {
    aspects[["Perforation"]] <- list(ai_data$perforation)
  }

  return(aspects)
}

#' Build eBay Stamp Item Data (using Trading API)
#'
#' @param ai_data AI extraction results
#' @param image_urls List of uploaded image URLs
#' @param price_usd Price in USD
#' @param quantity Number of items
#' @return List formatted for eBay Trading API
#' @export
build_stamp_item_data <- function(ai_data, image_urls, price_usd, quantity = 1) {

  # Determine condition (use same logic as postal cards to avoid Error 25019)
  condition_code <- if (!is.null(ai_data$grade)) {
    map_stamp_grade_to_ebay(ai_data$grade)
  } else {
    "USED"  # Safe default
  }

  # Extract aspects
  aspects <- extract_stamp_aspects(ai_data, condition_code)

  # Build item data (exact same structure as postal cards)
  item_data <- list(
    Title = ai_data$title,
    Description = ai_data$description,
    PrimaryCategory = list(CategoryID = "260"),  # STAMPS CATEGORY
    StartPrice = price_usd,
    Quantity = quantity,
    Country = "US",
    Currency = "USD",
    ConditionID = "3000",  # 3000 = Used (safest for stamps per postal card pattern)
    ItemSpecifics = list(
      NameValueList = lapply(names(aspects), function(name) {
        list(Name = name, Value = aspects[[name]])
      })
    ),
    PictureDetails = list(
      PictureURL = image_urls
    ),
    ListingDuration = "Days_7",
    ListingType = "FixedPriceItem",
    PaymentMethods = "PayPal",
    PayPalEmailAddress = Sys.getenv("EBAY_PAYPAL_EMAIL", ""),
    PostalCode = Sys.getenv("EBAY_POSTAL_CODE", ""),
    ShippingDetails = list(
      ShippingType = "Flat",
      ShippingServiceOptions = list(
        list(
          ShippingService = "USPSFirstClass",
          ShippingServiceCost = 1.50  # Stamps are lightweight
        )
      )
    ),
    ReturnPolicy = list(
      ReturnsAcceptedOption = "ReturnsAccepted",
      RefundOption = "MoneyBack",
      ReturnsWithinOption = "Days_30",
      ShippingCostPaidByOption = "Buyer"
    )
  )

  return(item_data)
}
```

---

### Phase 5: Stamp Export Module

**File:** `R/mod_stamp_export.R`
- **Action**: Copy `mod_delcampe_export.R` entirely
- **Changes**:
  - Replace `card` with `stamp`
  - Replace `postcard` with `stamp`
  - Call `build_stamp_item_data()` instead of `build_trading_item_data()`
  - Call `extract_stamp_aspects()` for aspect mapping
  - Use category ID `"260"` instead of `"262042"`

**eBay Send Logic (adapted from postal cards):**

```r
observeEvent(input$send_to_ebay_btn, {
  req(combined_image_path())

  # Get AI data
  ai_data <- rv$last_ai_result

  if (is.null(ai_data) || !ai_data$success) {
    showNotification("Please run AI extraction first", type = "warning")
    return()
  }

  # Check eBay authentication
  if (!ebay_api()$is_authenticated()) {
    showNotification("Please authenticate with eBay first", type = "error")
    return()
  }

  withProgress(message = "Creating eBay listing...", {

    incProgress(0.2, detail = "Uploading images...")

    # Upload images (reuse exact postal card logic)
    upload_result <- upload_images_to_ebay(
      image_paths = c(combined_image_path()),
      ebay_api = ebay_api()
    )

    if (!upload_result$success) {
      showNotification(paste("Image upload failed:", upload_result$error),
                      type = "error")
      return()
    }

    incProgress(0.5, detail = "Building listing data...")

    # Build stamp item data (NEW FUNCTION - category 260)
    item_data <- build_stamp_item_data(
      ai_data = ai_data,
      image_urls = upload_result$urls,
      price_usd = input$price_override %||% ai_data$recommended_price %||% 5.00,
      quantity = 1
    )

    incProgress(0.7, detail = "Creating listing...")

    # Create listing via Trading API (exact same call as postal cards)
    result <- create_ebay_listing_trading(
      item_data = item_data,
      ebay_api = ebay_api()
    )

    if (result$success) {
      # Save to database
      save_ebay_stamp_listing(
        stamp_id = current_stamp_id(),
        session_id = session$token,
        ebay_item_id = result$item_id,
        sku = generate_sku(current_stamp_id(), prefix = "STAMP"),
        title = ai_data$title,
        price = ai_data$recommended_price,
        status = "listed",
        listing_url = result$listing_url
      )

      showNotification("Stamp listing created successfully!", type = "message")

      # Display result (exact same UI as postal cards)
      output$ebay_result <- renderUI({
        div(
          class = "alert alert-success",
          h4("eBay Listing Created!"),
          p(paste("Item ID:", result$item_id)),
          a(href = result$listing_url, target = "_blank",
            class = "btn btn-primary", "View on eBay")
        )
      })

    } else {
      showNotification(paste("Error:", result$error), type = "error")
    }
  })
})
```

---

### Phase 6: UI Integration

**File:** `R/app_ui.R`

Add new "Stamps" tab (exact copy of Postal Cards structure):

```r
bslib::nav_panel(
  title = "Stamps",
  icon = icon("stamp"),
  value = "stamps",

  # Face and Verso processors (exact same layout as postal cards)
  fluidRow(
    column(
      width = 6,
      bslib::card(
        header = bslib::card_header("Stamp Face"),
        mod_stamp_face_processor_ui("stamp_face")
      )
    ),
    column(
      width = 6,
      bslib::card(
        header = bslib::card_header("Stamp Verso"),
        mod_stamp_verso_processor_ui("stamp_verso")
      )
    )
  ),

  # Combined image and export (exact same layout)
  fluidRow(
    column(
      width = 12,
      mod_stamp_export_ui("stamp_export")
    )
  )
)
```

**File:** `R/app_server.R`

```r
# Stamp Face processor
stamp_face_result <- mod_stamp_face_processor_server(
  "stamp_face",
  stamp_type = "face",
  on_grid_update = function(rows, cols) {
    message("Stamp face grid: ", rows, "x", cols)
  },
  on_extraction_complete = function(count, dir, used_existing) {
    message("Stamp face extraction: ", count, " stamps")
    # Trigger auto-combine if both face and verso are done
    check_auto_combine_stamps()
  }
)

# Stamp Verso processor
stamp_verso_result <- mod_stamp_verso_processor_server(
  "stamp_verso",
  stamp_type = "verso",
  on_grid_update = function(rows, cols) {
    message("Stamp verso grid: ", rows, "x", cols)
  },
  on_extraction_complete = function(count, dir, used_existing) {
    message("Stamp verso extraction: ", count, " stamps")
    # Trigger auto-combine if both face and verso are done
    check_auto_combine_stamps()
  }
)

# Stamp export module
mod_stamp_export_server(
  "stamp_export",
  face_images = stamp_face_result$get_extracted_paths,
  verso_images = stamp_verso_result$get_extracted_paths,
  stamp_id = reactive(stamp_face_result$current_stamp_id),
  ebay_api = ebay_api
)

# Auto-combine function (exact copy of postal card logic)
check_auto_combine_stamps <- function() {
  if (stamp_face_result$is_extraction_complete() &&
      stamp_verso_result$is_extraction_complete()) {
    # Trigger combine logic (exact same as postal cards)
    combined_image_path <- combine_face_verso_stamps(
      face_paths = stamp_face_result$get_extracted_paths(),
      verso_paths = stamp_verso_result$get_extracted_paths()
    )
  }
}
```

---

## Testing Strategy

### Unit Tests

**File:** `tests/testthat/test-stamp_helpers.R`

```r
test_that("Stamp grade mapping works correctly", {
  expect_equal(map_stamp_grade_to_ebay("MNH"), "USED")  # Per postal card pattern
  expect_equal(map_stamp_grade_to_ebay("Mint Hinged"), "USED")
  expect_equal(map_stamp_grade_to_ebay("Used"), "USED")
  expect_equal(map_stamp_grade_to_ebay("Unknown"), "UNSPECIFIED")
})

test_that("Stamp aspects extraction includes stamp-specific fields", {
  ai_data <- list(
    country = "United States",
    year = 1963,
    denomination = "5c",
    grade = "MNH",
    scott_number = "US-1234",
    stamp_count = 1
  )

  aspects <- extract_stamp_aspects(ai_data, "USED")

  expect_true("Type" %in% names(aspects))
  expect_true("Country/Region of Manufacture" %in% names(aspects))
  expect_true("Year of Issue" %in% names(aspects))
  expect_true("Grade" %in% names(aspects))
  expect_true("Catalog Number" %in% names(aspects))
  expect_equal(aspects$Type[[1]], "Individual Stamp")
})

test_that("Stamp prompt includes philatelic fields", {
  prompt <- build_stamp_prompt("individual", 1)

  expect_true(grepl("DENOMINATION", prompt))
  expect_true(grepl("SCOTT_NUMBER", prompt))
  expect_true(grepl("PERFORATION", prompt))
  expect_true(grepl("GRADE", prompt))
  expect_true(grepl("WATERMARK", prompt))
})

test_that("Stamp item data uses category 260", {
  ai_data <- list(
    title = "USA - 1963 5c WASHINGTON",
    description = "1963 George Washington stamp",
    recommended_price = 3.50,
    country = "United States",
    year = 1963,
    grade = "MNH"
  )

  item_data <- build_stamp_item_data(ai_data, list("http://example.com/img.jpg"), 3.50, 1)

  expect_equal(item_data$PrimaryCategory$CategoryID, "260")
  expect_equal(item_data$StartPrice, 3.50)
})
```

### Integration Tests

**File:** `tests/testthat/test-stamp_workflow.R`

```r
test_that("Complete stamp processing workflow (face + verso)", {
  # Clear test data
  clear_test_stamp_data()

  # Face upload
  face_result <- upload_stamp_image("test_images/test_stamp_face.jpg", type = "face")
  expect_true(face_result$success)
  expect_true(!is.null(face_result$stamp_id))

  # Verso upload (should cross-sync grid from face)
  verso_result <- upload_stamp_image("test_images/test_stamp_verso.jpg", type = "verso")
  expect_true(verso_result$success)
  expect_equal(verso_result$grid_source, "cross_sync")

  # Extract stamps
  face_extraction <- extract_stamps(face_result$stamp_id, 2, 3)
  verso_extraction <- extract_stamps(verso_result$stamp_id, 2, 3)

  expect_equal(length(face_extraction$crop_paths), 6)
  expect_equal(length(verso_extraction$crop_paths), 6)

  # Combine face/verso
  combined <- combine_face_verso_stamps(
    face_extraction$crop_paths,
    verso_extraction$crop_paths
  )

  expect_equal(nrow(combined), 6)  # 6 stamps total

  # AI extraction
  ai_result <- perform_stamp_ai_extraction(
    image_path = combined$combined_path[1],
    extraction_type = "lot",
    stamp_count = 6
  )

  expect_true(ai_result$success)
  expect_true(!is.null(ai_result$country))
  expect_true(!is.null(ai_result$denomination))
})
```

---

## eBay Category 260 - Stamps

**Primary Category:** 260 (Stamps)

**Key Subcategories:**
- 261: United States
- 885: Europe
- 886: Asia
- 64524: Topical
- 181420: Worldwide

**Required Aspects:**
- Type: Individual Stamp | Set | Lot | Collection
- Certification: Certified | Uncertified

**Recommended Aspects:**
- Country/Region of Manufacture
- Year of Issue
- Grade: Mint Never Hinged | Mint Hinged | Used | Unused
- Denomination
- Catalog Number (Scott, Michel, Stanley Gibbons)
- Perforation
- Topic (for thematic stamps)
- Color

**Critical Note:**
Follow exact same condition mapping as postal cards (use "USED" to avoid Error 25019 for cross-border listings).

---

## Success Criteria

1. ✅ User can upload stamp face images (exact same logic as postal cards)
2. ✅ User can upload stamp verso images (exact same logic as postal cards)
3. ✅ Grid detection works for stamps (reusing postal card Python integration)
4. ✅ Cross-sync works for stamp face/verso (exact same logic)
5. ✅ User can adjust gridlines (exact same draggable UI)
6. ✅ Extract individual stamps and lots (exact same extraction logic)
7. ✅ AI extraction produces stamp-specific metadata (NEW prompts)
8. ✅ Stamps tracked in database with deduplication (exact same 3-layer architecture)
9. ✅ "Send to eBay" creates listing in category 260 (NEW category mapping)
10. ✅ eBay listing includes stamp-specific aspects (NEW aspect extraction)
11. ✅ All critical tests pass

---

## Implementation Summary

**What's Copied 1:1 from Postal Cards:**
- Face/verso upload modules
- Grid detection (Python integration)
- Draggable gridlines UI
- Cross-sync logic
- Image extraction
- Duplicate detection with modals
- Tracking database architecture (3 tables)
- Auto-combine logic
- Session tracking

**What's New/Different:**
1. **AI Prompts**: `build_stamp_prompt()` with perforation, watermark, denomination, Scott number
2. **eBay Category**: 260 (Stamps) instead of 262042 (Postcards)
3. **eBay Aspects**: `extract_stamp_aspects()` with stamp-specific fields
4. **Database Tables**: Named `stamps`, `stamp_processing`, `ebay_stamp_listings`
5. **UI Labels**: "Stamp" instead of "Postal Card"

**Files to Create:**
- `R/mod_stamp_face_processor.R` (copy of `mod_postal_card_processor.R`)
- `R/mod_stamp_verso_processor.R` (copy of `mod_postal_card_processor.R`)
- `R/mod_stamp_export.R` (copy of `mod_delcampe_export.R`)
- `R/stamp_ai_helpers.R` (NEW - stamp prompts)
- `R/ebay_stamp_helpers.R` (NEW - category 260 mapping)
- `tests/testthat/test-stamp_helpers.R` (NEW)
- `tests/testthat/test-stamp_workflow.R` (NEW)

**Estimated Timeline:** 1-2 weeks (mostly copy-paste + eBay category adaptation)

---

## Next Steps

1. ✅ Review and approve PRP
2. ⏳ Extend database schema with stamp tables
3. ⏳ Copy postal card modules to stamp modules (find-replace entities)
4. ⏳ Implement stamp-specific AI prompts
5. ⏳ Implement eBay category 260 helpers
6. ⏳ Test face/verso workflow with stamp images
7. ⏳ Test AI extraction with real stamps
8. ⏳ Test eBay listing creation in sandbox (category 260)
9. ⏳ Production deployment

---

**Document Version:** 2.0
**Date:** 2025-10-30
**Author:** Claude Code
**Status:** Ready for Implementation
**Key Change:** Includes face/verso upload (exact same logic as postal cards), only eBay category and AI prompts differ
