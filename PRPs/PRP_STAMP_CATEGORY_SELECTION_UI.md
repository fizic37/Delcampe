# PRP: Stamp Category Selection UI & Validation

**Status:** Draft
**Priority:** Critical
**Created:** 2025-11-02
**Dependencies:** STAMP_CATEGORY_FIX_COMPLETE.md, Official eBay Category CSV

---

## Executive Summary

Implement a two-level category selection UI for stamp listings with:
1. **Region dropdown** (United States, Europe, Asia, etc.)
2. **Country/Subcategory dropdown** (dynamically populated based on region)
3. **AI extraction** of country from stamp images
4. **Validation** to prevent eBay listing without valid leaf category
5. **Smart defaults** based on AI-extracted data

---

## Problem Statement

### Current Issues

1. **Hardcoded Category:** All stamps use category 675 (US 19th Century Used)
2. **No User Control:** Cannot select appropriate category for international stamps
3. **No AI Extraction:** AI doesn't extract country/region from stamps
4. **No Validation:** Can send stamps to eBay with wrong category
5. **Error Prone:** User might not know which eBay category to use

### Impact

- International stamps (Europe, Asia, etc.) listed in wrong category
- Poor discoverability on eBay (stamps in wrong region)
- Potential eBay policy violations
- Reduced sales (buyers search by region)

---

## Research Findings

### eBay Category Structure

**Source:** https://ir.ebaystatic.com/pictures/aw/pics/pdf/us/file_exchange/CategoryIDs-US.csv

**Total Stamp Categories:** 438

**Hierarchy:**
```
Stamps (260) [NOT A LEAF]
├── United States [NOT A LEAF - has 48 subcategories]
│   ├── 19th Century: Used (675) [LEAF ✓]
│   ├── 19th Century: Unused (676) [LEAF ✓]
│   ├── 1901-40: Unused (3461) [LEAF ✓]
│   ├── 1941-Now: Unused (679) [LEAF ✓]
│   ├── 1901-Now: Used (678) [LEAF ✓]
│   ├── Postage (47149) [LEAF ✓]
│   ├── Sheets (265) [LEAF ✓]
│   ├── Collections, Lots (683) [LEAF ✓]
│   └── ... (40 more subcategories)
├── Canada [NOT A LEAF - has 11 subcategories]
│   ├── Mint (3480) [LEAF ✓]
│   ├── Used (3481) [LEAF ✓]
│   ├── Collections, Lots (3486) [LEAF ✓]
│   └── ... (8 more)
├── Great Britain [NOT A LEAF - has 17 subcategories]
├── Europe [NOT A LEAF - has 50+ country subcategories]
│   ├── France (12559) [LEAF ✓]
│   ├── Germany (12560) [LEAF ✓]
│   ├── Italy (12563) [LEAF ✓]
│   ├── Romania (12569) [LEAF ✓]
│   └── ... (46 more countries)
├── Asia [NOT A LEAF - has 30+ country subcategories]
│   ├── China (12574) [LEAF ✓]
│   ├── Japan (12577) [LEAF ✓]
│   └── ... (28 more countries)
├── Africa [NOT A LEAF - has 50+ country subcategories]
├── Latin America [NOT A LEAF - has 30+ country subcategories]
├── Middle East [NOT A LEAF - has 15 country subcategories]
├── Australia & Oceania [NOT A LEAF - has subcategories]
├── British Colonies & Territories [NOT A LEAF]
├── Caribbean [NOT A LEAF]
├── Topical [MIGHT BE LEAF - needs verification]
├── Worldwide [HAS subcategories]
└── Other Stamps (170137) [LEAF ✓]
```

### Key Findings

1. **Regions are NOT leaf categories** - You MUST select a country/subcategory
2. **Only exception:** "Other Stamps" (170137) is a leaf category at region level
3. **United States** has era-specific categories (19th century, 1901-40, 1941-Now)
4. **Most regions** are organized by country (Europe > France, Asia > Japan, etc.)
5. **Total leaf categories:** Approximately 400+ valid listing categories

---

## Requirements

### Functional Requirements

#### FR1: Two-Level Category Selection UI

**User Story:**
As a stamp seller, I want to select the appropriate region and country for my stamp so it appears in the correct eBay category.

**Acceptance Criteria:**
1. ✅ Region dropdown shows all major regions:
   - United States
   - Canada
   - Great Britain
   - Europe
   - Asia
   - Africa
   - Latin America
   - Middle East
   - Australia & Oceania
   - British Colonies & Territories
   - Caribbean
   - Topical
   - Worldwide
   - Other Stamps
2. ✅ Country/Subcategory dropdown populates based on selected region
3. ✅ For United States: Show era options (19th Century, 1901-40, 1941-Now, etc.)
4. ✅ For other regions: Show country list (France, Germany, Romania, etc.)
5. ✅ UI clearly indicates which field is required
6. ✅ Dropdowns use user-friendly labels (not category IDs)

#### FR2: AI Country Extraction

**User Story:**
As a stamp seller, I want the AI to automatically detect the country of origin from my stamp image so I don't have to manually select it.

**Acceptance Criteria:**
1. ✅ AI prompt includes instruction to extract country/region
2. ✅ AI extraction returns structured country field
3. ✅ Country field is mapped to eBay category
4. ✅ UI pre-selects region and country based on AI extraction
5. ✅ User can override AI selection if incorrect

**AI Prompt Enhancement:**
```
You are an expert philatelist analyzing stamp images.

CRITICAL: Extract the COUNTRY OF ORIGIN for the stamp.
This determines the eBay listing category.

COUNTRY: The nation that issued the stamp (e.g., "United States", "France", "Romania", "Japan")
- Look for text on stamp indicating country
- Common indicators: "USA", "US", "France", "Deutschland" (Germany), "România", "日本" (Japan)
- If stamp shows multiple countries (commemorative), use primary issuing country
- Be specific: "United States" not just "US", "Great Britain" not just "UK"

Extract the following fields:
- TITLE: ...
- DESCRIPTION: ...
- COUNTRY: [REQUIRED] Issuing country (e.g., "United States", "France", "Germany")
- YEAR: Year of issue if visible
- GRADE: Condition (MNH, MH, Used, Unused)
- DENOMINATION: Face value (e.g., "5c", "10 pfennig", "1 franc")
- ...
```

#### FR3: Category Validation

**User Story:**
As the system, I must prevent stamp listings from being sent to eBay without a valid leaf category selected.

**Acceptance Criteria:**
1. ✅ "Send to eBay" button is DISABLED until valid category selected
2. ✅ Visual indicator shows validation status:
   - ⚠️ Yellow warning: "Category required"
   - ✅ Green checkmark: "Category valid"
3. ✅ Validation checks:
   - Region selected
   - Country/Subcategory selected
   - Selected category is a LEAF category (not parent)
4. ✅ Clear error message if validation fails
5. ✅ Validation runs on:
   - Initial AI extraction
   - User selection change
   - Before eBay submission

**Validation Logic:**
```r
validate_stamp_category <- function(region, country_subcategory) {
  if (is.null(region) || region == "") {
    return(list(valid = FALSE, error = "Please select a region"))
  }

  if (is.null(country_subcategory) || country_subcategory == "") {
    return(list(valid = FALSE, error = "Please select a country or subcategory"))
  }

  # Check if category exists in our mapping
  category_id <- get_category_id(region, country_subcategory)

  if (is.null(category_id)) {
    return(list(valid = FALSE, error = "Invalid category selection"))
  }

  # All our mapped categories are leaf categories
  return(list(valid = TRUE, category_id = category_id))
}
```

#### FR4: Smart Defaults

**User Story:**
As a stamp seller, I want the system to intelligently pre-select categories based on AI extraction so I minimize manual work.

**Acceptance Criteria:**
1. ✅ If AI extracts "United States" → Pre-select region "United States"
2. ✅ If AI extracts year → Pre-select appropriate era subcategory
   - Year < 1900 → "19th Century: Used"
   - Year 1901-1940 → "1901-40: Unused" or "1901-Now: Used" (based on grade)
   - Year ≥ 1941 → "1941-Now: Unused" or "1901-Now: Used" (based on grade)
3. ✅ If AI extracts European country → Pre-select "Europe" region, then country
4. ✅ If AI cannot determine country → Default to "Other Stamps" (170137)
5. ✅ User can always override defaults

---

## Design Specifications

### UI Layout

**Location:** Stamp Export Module (`R/mod_stamp_export.R`)

**Placement:** Below AI-extracted fields (title, description, price)

**Design:**
```
┌─────────────────────────────────────────────┐
│ [AI Extracted Fields]                       │
│ Title: [.........................]          │
│ Description: [.........................]    │
│ Price: [$5.00]                              │
│                                             │
│ ━━━━ eBay Category Selection ━━━━           │
│                                             │
│ Region: *                                   │
│ ┌─────────────────────────────────────┐    │
│ │ United States              ▼        │    │
│ └─────────────────────────────────────┘    │
│                                             │
│ Country/Era: *                              │
│ ┌─────────────────────────────────────┐    │
│ │ 19th Century: Used         ▼        │    │
│ └─────────────────────────────────────┘    │
│                                             │
│ ✅ Category valid (675)                     │
│                                             │
│ [Send to eBay]  [Cancel]                    │
└─────────────────────────────────────────────┘
```

**States:**
- **Empty:** Both dropdowns empty, warning shown, button disabled
- **Region Only:** Region selected, country dropdown populated, warning shown, button disabled
- **Valid:** Both selected, green checkmark, button enabled
- **Invalid:** Invalid combination, error shown, button disabled

### Category Mapping Data Structure

**File:** `R/ebay_stamp_categories.R` (NEW)

```r
#' eBay Stamp Category Mappings
#' Source: Official eBay CategoryIDs-US.csv
#' Downloaded: 2025-11-02

# Region-level categories (for dropdown)
STAMP_REGIONS <- list(
  list(label = "United States", value = "US", has_subcategories = TRUE),
  list(label = "Canada", value = "CA", has_subcategories = TRUE),
  list(label = "Great Britain", value = "GB", has_subcategories = TRUE),
  list(label = "Europe", value = "EU", has_subcategories = TRUE),
  list(label = "Asia", value = "AS", has_subcategories = TRUE),
  list(label = "Africa", value = "AF", has_subcategories = TRUE),
  list(label = "Latin America", value = "LA", has_subcategories = TRUE),
  list(label = "Middle East", value = "ME", has_subcategories = TRUE),
  list(label = "Australia & Oceania", value = "AU", has_subcategories = TRUE),
  list(label = "British Colonies & Territories", value = "BC", has_subcategories = TRUE),
  list(label = "Caribbean", value = "CB", has_subcategories = TRUE),
  list(label = "Topical", value = "TP", has_subcategories = TRUE),
  list(label = "Worldwide", value = "WW", has_subcategories = TRUE),
  list(label = "Other Stamps", value = "OTHER", has_subcategories = FALSE, category_id = 170137)
)

# Country/Subcategory mappings
STAMP_CATEGORIES <- list(
  US = list(
    "19th Century: Used" = 675,
    "19th Century: Unused" = 676,
    "1901-40: Unused" = 3461,
    "1901-Now: Used" = 678,
    "1941-Now: Unused" = 679,
    "Postage" = 47149,
    "Sheets" = 265,
    "Collections, Lots" = 683,
    "Plate Blocks/Multiples" = 682,
    "Confederate States" = 3463,
    "Possessions" = 688,
    "Other United States Stamps" = 262
  ),
  CA = list(
    "Mint" = 3480,
    "Used" = 3481,
    "Collections, Lots" = 3486,
    "Blocks/Multiples" = 3479,
    "Covers" = 3482,
    "FDCs" = 47151,
    "Provinces" = 3485,
    "NFLD (pre-1949)" = 7168,
    "Other Canadian Stamps" = 3477
  ),
  GB = list(
    "Elizabeth II" = 65152,
    "George VI" = 3508,
    "Edward VIII" = 3507,
    "George V" = 3509,
    "Edward VII" = 3510,
    "Victoria" = 23739,
    "Commemorative" = 65137,
    "Collections, Lots" = 65154,
    "Other British Stamps" = 179326
  ),
  EU = list(
    "France" = 12559,
    "Germany" = 12560,
    "Italy" = 12563,
    "Spain" = 12571,
    "Romania" = 12569,
    "Poland" = 12568,
    "Greece" = 12561,
    "Netherlands" = 12566,
    "Belgium" = 12556,
    "Austria" = 7171,
    "Switzerland" = 12572,
    "Portugal" = 66798,
    "Sweden" = 66800,
    "Norway" = 66796,
    "Denmark" = 66793,
    "Finland" = 66794,
    "Ireland" = 66795,
    "Hungary" = 12562,
    "Czech Republic" = 66792,
    "Slovakia" = 127399,
    "Slovenia" = 127400,
    "Croatia" = 171172,
    "Serbia" = 171174,
    "Bulgaria" = 12557,
    "Russia" = 12570,
    "Ukraine" = 171175
    # ... (25 more European countries from CSV)
  ),
  AS = list(
    "China" = 12574,
    "Japan" = 12577,
    "India" = 12576,
    "Thailand" = 12581,
    "Vietnam" = 12583,
    "Indonesia" = 123787,
    "Philippines" = 12579,
    "South Korea" = 12580,
    "Taiwan" = 66807,
    "Hong Kong" = 12575,
    "Singapore" = 66806,
    "Malaysia" = 12578
    # ... (18 more Asian countries)
  ),
  AF = list(
    "Egypt" = 12555,
    "South Africa" = 12554,
    "Algeria" = 127414,
    "Morocco" = 66784,
    "Tunisia" = 66788
    # ... (45 more African countries)
  ),
  # ... (Additional regions: LA, ME, AU, BC, CB, TP, WW)
)
```

### Helper Functions

**File:** `R/ebay_stamp_categories.R`

```r
#' Get subcategories for a region
#' @param region_code Region code (e.g., "US", "EU", "AS")
#' @return Named list of subcategories with category IDs
#' @export
get_stamp_subcategories <- function(region_code) {
  if (region_code == "OTHER") {
    return(list("Other Stamps" = 170137))
  }

  STAMP_CATEGORIES[[region_code]]
}

#' Get category ID from region and subcategory
#' @param region_code Region code
#' @param subcategory_label User-facing subcategory label
#' @return Numeric category ID
#' @export
get_stamp_category_id <- function(region_code, subcategory_label) {
  if (region_code == "OTHER") {
    return(170137)
  }

  subcats <- STAMP_CATEGORIES[[region_code]]
  if (is.null(subcats)) return(NULL)

  subcats[[subcategory_label]]
}

#' Map AI-extracted country to region and country selection
#' @param country Country name from AI extraction
#' @return List with region_code, country_label, and category_id
#' @export
map_country_to_category <- function(country) {
  if (is.null(country) || is.na(country) || country == "") {
    return(list(
      region_code = "OTHER",
      country_label = "Other Stamps",
      category_id = 170137
    ))
  }

  country_upper <- toupper(trimws(country))

  # IMPORTANT: This function must return BOTH the region AND the specific country
  # so we can pre-select BOTH dropdowns in the UI

  # United States - Special handling for eras
  if (grepl("UNITED STATES|USA|US$|AMERICA", country_upper)) {
    return(list(
      region_code = "US",
      country_label = NULL,  # Will be determined by year/grade in get_default_subcategory()
      needs_year = TRUE  # Signal that we need year to determine subcategory
    ))
  }

  # Canada
  if (grepl("CANADA", country_upper)) {
    return(list(
      region_code = "CA",
      country_label = NULL,  # Will be determined by grade (Mint vs Used)
      needs_grade = TRUE
    ))
  }

  # Great Britain
  if (grepl("GREAT BRITAIN|UK|UNITED KINGDOM|ENGLAND|SCOTLAND|WALES", country_upper)) {
    return(list(
      region_code = "GB",
      country_label = NULL,  # Will be determined by monarch/era
      needs_year = TRUE
    ))
  }

  # European countries - Map to exact country name in our category list
  eu_mapping <- list(
    "FRANCE" = "France",
    "GERMANY" = "Germany",
    "DEUTSCHLAND" = "Germany",
    "ITALY" = "Italy",
    "ITALIA" = "Italy",
    "SPAIN" = "Spain",
    "ESPAÑA" = "Spain",
    "ROMANIA" = "Romania",
    "ROMÂNIA" = "Romania",
    "POLAND" = "Poland",
    "POLSKA" = "Poland",
    "GREECE" = "Greece",
    "NETHERLANDS" = "Netherlands",
    "HOLLAND" = "Netherlands",
    "BELGIUM" = "Belgium",
    "BELGIË" = "Belgium",
    "AUSTRIA" = "Austria",
    "ÖSTERREICH" = "Austria",
    "SWITZERLAND" = "Switzerland",
    "SCHWEIZ" = "Switzerland",
    "PORTUGAL" = "Portugal",
    "SWEDEN" = "Sweden",
    "SVERIGE" = "Sweden",
    "NORWAY" = "Norway",
    "NORGE" = "Norway",
    "DENMARK" = "Denmark",
    "DANMARK" = "Denmark",
    "FINLAND" = "Finland",
    "SUOMI" = "Finland",
    "IRELAND" = "Ireland",
    "HUNGARY" = "Hungary",
    "MAGYARORSZÁG" = "Hungary",
    "CZECH" = "Czech Republic",
    "SLOVAKIA" = "Slovakia",
    "SLOVENIA" = "Slovenia",
    "CROATIA" = "Croatia",
    "SERBIA" = "Serbia",
    "BULGARIA" = "Bulgaria",
    "RUSSIA" = "Russia",
    "USSR" = "Russia",
    "UKRAINE" = "Ukraine"
  )

  for (pattern in names(eu_mapping)) {
    if (grepl(pattern, country_upper)) {
      country_name <- eu_mapping[[pattern]]
      return(list(
        region_code = "EU",
        country_label = country_name,
        category_id = STAMP_CATEGORIES$EU[[country_name]]
      ))
    }
  }

  # Asian countries
  asia_mapping <- list(
    "CHINA" = "China",
    "中国" = "China",
    "JAPAN" = "Japan",
    "日本" = "Japan",
    "NIPPON" = "Japan",
    "INDIA" = "India",
    "THAILAND" = "Thailand",
    "VIETNAM" = "Vietnam",
    "INDONESIA" = "Indonesia",
    "PHILIPPINES" = "Philippines",
    "KOREA" = "South Korea",
    "TAIWAN" = "Taiwan",
    "HONG KONG" = "Hong Kong",
    "SINGAPORE" = "Singapore",
    "MALAYSIA" = "Malaysia"
  )

  for (pattern in names(asia_mapping)) {
    if (grepl(pattern, country_upper)) {
      country_name <- asia_mapping[[pattern]]
      return(list(
        region_code = "AS",
        country_label = country_name,
        category_id = STAMP_CATEGORIES$AS[[country_name]]
      ))
    }
  }

  # African countries
  africa_mapping <- list(
    "EGYPT" = "Egypt",
    "SOUTH AFRICA" = "South Africa",
    "ALGERIA" = "Algeria",
    "MOROCCO" = "Morocco",
    "TUNISIA" = "Tunisia",
    "KENYA" = "Kenya",
    "NIGERIA" = "Nigeria",
    "ETHIOPIA" = "Ethiopia",
    "GHANA" = "Ghana"
  )

  for (pattern in names(africa_mapping)) {
    if (grepl(pattern, country_upper)) {
      country_name <- africa_mapping[[pattern]]
      return(list(
        region_code = "AF",
        country_label = country_name,
        category_id = STAMP_CATEGORIES$AF[[country_name]]
      ))
    }
  }

  # Latin American countries
  latin_mapping <- list(
    "MEXICO" = "Mexico",
    "BRAZIL" = "Brazil",
    "BRASIL" = "Brazil",
    "ARGENTINA" = "Argentina",
    "CHILE" = "Chile",
    "PERU" = "Peru",
    "COLOMBIA" = "Colombia",
    "VENEZUELA" = "Venezuela",
    "CUBA" = "Cuba",
    "ECUADOR" = "Ecuador"
  )

  for (pattern in names(latin_mapping)) {
    if (grepl(pattern, country_upper)) {
      country_name <- latin_mapping[[pattern]]
      return(list(
        region_code = "LA",
        country_label = country_name,
        category_id = STAMP_CATEGORIES$LA[[country_name]]
      ))
    }
  }

  # Middle Eastern countries
  middle_east_mapping <- list(
    "ISRAEL" = "Israel",
    "SAUDI" = "Saudi Arabia",
    "IRAN" = "Iran",
    "IRAQ" = "Iraq",
    "TURKEY" = "Turkey",
    "UAE" = "United Arab Emirates",
    "JORDAN" = "Jordan",
    "LEBANON" = "Lebanon",
    "KUWAIT" = "Kuwait",
    "QATAR" = "Qatar",
    "OMAN" = "Oman",
    "BAHRAIN" = "Bahrain",
    "YEMEN" = "Yemen"
  )

  for (pattern in names(middle_east_mapping)) {
    if (grepl(pattern, country_upper)) {
      country_name <- middle_east_mapping[[pattern]]
      return(list(
        region_code = "ME",
        country_label = country_name,
        category_id = STAMP_CATEGORIES$ME[[country_name]]
      ))
    }
  }

  # Australia & Oceania
  oceania_mapping <- list(
    "AUSTRALIA" = "Australia",
    "NEW ZEALAND" = "New Zealand",
    "FIJI" = "Fiji",
    "SAMOA" = "Samoa"
  )

  for (pattern in names(oceania_mapping)) {
    if (grepl(pattern, country_upper)) {
      country_name <- oceania_mapping[[pattern]]
      return(list(
        region_code = "AU",
        country_label = country_name,
        category_id = STAMP_CATEGORIES$AU[[country_name]]
      ))
    }
  }

  # Default to "Other Stamps"
  return(list(
    region_code = "OTHER",
    country_label = "Other Stamps",
    category_id = 170137
  ))
}

#' Get smart default subcategory based on AI data
#' @param region_code Region code
#' @param ai_data AI extraction data (year, grade, etc.)
#' @return Default subcategory label
#' @export
get_default_subcategory <- function(region_code, ai_data) {
  if (region_code == "US") {
    year <- as.numeric(ai_data$year)
    grade <- tolower(ai_data$grade %||% "used")

    if (!is.na(year) && year < 1900) {
      return(if (grepl("unused|mnh|mint", grade)) "19th Century: Unused" else "19th Century: Used")
    }

    if (!is.na(year) && year >= 1901 && year <= 1940) {
      return(if (grepl("unused|mnh|mint", grade)) "1901-40: Unused" else "1901-Now: Used")
    }

    if (!is.na(year) && year >= 1941) {
      return(if (grepl("unused|mnh|mint", grade)) "1941-Now: Unused" else "1901-Now: Used")
    }

    # Default for US
    return("Postage")
  }

  if (region_code == "CA") {
    grade <- tolower(ai_data$grade %||% "used")
    return(if (grepl("unused|mnh|mint", grade)) "Mint" else "Used")
  }

  # For other regions, return first subcategory
  subcats <- get_stamp_subcategories(region_code)
  if (length(subcats) > 0) {
    return(names(subcats)[1])
  }

  return(NULL)
}
```

---

## Implementation Tasks

### Phase 1: Category Data & Backend (4-6 hours)

#### Task 1.1: Process eBay Category CSV
- [x] Download official CSV
- [ ] Run `dev/process_stamp_categories.R`
- [ ] Extract all 438 stamp categories
- [ ] Identify leaf categories
- [ ] Create region/country mapping structure

#### Task 1.2: Create Category Mapping Module
- [ ] Create `R/ebay_stamp_categories.R`
- [ ] Define `STAMP_REGIONS` list
- [ ] Define `STAMP_CATEGORIES` list (all 438 categories)
- [ ] Implement `get_stamp_subcategories()`
- [ ] Implement `get_stamp_category_id()`
- [ ] Implement `map_country_to_region()`
- [ ] Implement `get_default_subcategory()`
- [ ] Add roxygen2 documentation

#### Task 1.3: Update AI Extraction
- [ ] Update `R/stamp_ai_helpers.R` prompt
- [ ] Add explicit COUNTRY extraction instruction
- [ ] Emphasize importance of country for category selection
- [ ] Update parsing to extract country field
- [ ] Test AI extraction with sample stamps

### Phase 2: UI Implementation (6-8 hours)

#### Task 2.1: Add Category Selection UI
- [ ] Update `R/mod_stamp_export.R`
- [ ] Add region selectInput dropdown
- [ ] Add country/subcategory selectInput dropdown
- [ ] Position below AI-extracted fields
- [ ] Style with consistent theme (purple for stamps)

#### Task 2.2: Implement Dynamic Dropdown Population
- [ ] Create observer for region selection
- [ ] Populate country dropdown based on selected region
- [ ] Clear country selection when region changes
- [ ] Handle "Other Stamps" special case (no country dropdown)

#### Task 2.3: Add Validation UI
- [ ] Add validation status indicator (⚠️ or ✅)
- [ ] Show validation message
- [ ] Disable "Send to eBay" button when invalid
- [ ] Enable button when valid category selected
- [ ] Add tooltip explaining requirements

#### Task 2.4: Implement Smart Defaults
- [ ] Observer to detect AI extraction completion
- [ ] Map AI country → region code
- [ ] Pre-select region dropdown
- [ ] Trigger country dropdown population
- [ ] Pre-select default subcategory
- [ ] Allow user override

### Phase 3: Validation & Integration (3-4 hours)

#### Task 3.1: Implement Category Validation
- [ ] Create `validate_stamp_category()` function
- [ ] Check region selected
- [ ] Check subcategory selected
- [ ] Verify category ID exists
- [ ] Return validation result

#### Task 3.2: Update eBay Integration
- [ ] Modify `R/ebay_integration.R`
- [ ] Remove hardcoded category 675
- [ ] Use selected category from UI
- [ ] Add validation before API call
- [ ] Reject submission if invalid category

#### Task 3.3: Update Database Schema
- [ ] Add `ebay_region` column to stamp listings
- [ ] Add `ebay_category_label` column (user-friendly name)
- [ ] Store category ID, region, and label together
- [ ] Migration script for existing listings

### Phase 4: Testing (3-4 hours)

#### Task 4.1: Unit Tests
- [ ] Test `map_country_to_region()` with various countries
- [ ] Test `get_default_subcategory()` for US stamps (various years)
- [ ] Test `get_stamp_category_id()` returns correct IDs
- [ ] Test validation logic

#### Task 4.2: Integration Tests
- [ ] Test AI extraction → region/country pre-selection flow
- [ ] Test manual region/country selection
- [ ] Test validation prevents invalid submissions
- [ ] Test eBay listing creation with selected category

#### Task 4.3: Manual Testing
- [ ] Test US stamp from 1880s → 19th Century
- [ ] Test US stamp from 1920s → 1901-40
- [ ] Test US stamp from 1960s → 1941-Now
- [ ] Test European stamp (France) → Europe > France
- [ ] Test Asian stamp (Japan) → Asia > Japan
- [ ] Test unknown country → Other Stamps

---

## Success Criteria

### Definition of Done

1. **UI Complete:**
   - [ ] Two-level dropdown visible in stamp export UI
   - [ ] Dropdowns populate correctly
   - [ ] Validation indicator shows status
   - [ ] Smart defaults work based on AI extraction

2. **Validation Working:**
   - [ ] Cannot send to eBay without valid category
   - [ ] Clear error messages for invalid states
   - [ ] Green checkmark for valid selection

3. **AI Integration:**
   - [ ] AI extracts country field
   - [ ] Country maps to correct region
   - [ ] UI pre-selects region and subcategory
   - [ ] User can override AI selection

4. **eBay Integration:**
   - [ ] Selected category used in API call
   - [ ] Stamps appear in correct eBay category
   - [ ] No more Error 87 (non-leaf category)
   - [ ] International stamps in correct regions

5. **Testing:**
   - [ ] All unit tests pass
   - [ ] Manual testing confirms correct categories
   - [ ] Stamps from various countries list correctly

---

## Edge Cases & Error Handling

### Edge Case 1: AI Cannot Determine Country
**Scenario:** Stamp image too blurry, text unreadable
**Handling:** Default to "Other Stamps" (170137), user must manually select

### Edge Case 2: Country Not in eBay Categories
**Scenario:** Obscure country not listed in CSV
**Handling:** Map to parent region (e.g., small African country → Africa > first available)

### Edge Case 3: Multiple Countries on Stamp
**Scenario:** Commemorative stamp showing multiple flags
**Handling:** AI extracts primary issuing country, user can override

### Edge Case 4: User Changes Region After AI Pre-selection
**Scenario:** AI selected "Europe > France", user changes to "Asia"
**Handling:** Clear country dropdown, show Asian countries, no default selected

### Edge Case 5: "Other Stamps" Selected
**Scenario:** User selects "Other Stamps" region
**Handling:** Hide country dropdown (not needed), use category 170137 directly

---

## Future Enhancements

### Phase 5: Advanced Features (Optional)

1. **Category Search:**
   - Add search box to filter countries
   - Autocomplete for large region lists (Europe has 50+ countries)

2. **Recent Categories:**
   - Remember user's last 5 category selections
   - Quick-select from recent categories

3. **Bulk Category Assignment:**
   - Select category once, apply to multiple stamps
   - Useful for stamp lots from same country

4. **Category Recommendations:**
   - Analyze similar stamps user has listed
   - Suggest most frequently used categories

5. **Visual Category Browser:**
   - Tree view of category hierarchy
   - Click to expand/collapse regions

---

## Documentation

### User Documentation

**Help Text for UI:**
```
eBay Category Selection

Region: Select the geographic region of your stamp.
  • United States - for US stamps
  • Europe - for European countries
  • Asia - for Asian countries
  • etc.

Country/Era: Select the specific country or category.
  • For US stamps: Choose by era (19th Century, 1901-40, etc.)
  • For other regions: Choose the country
  • For unknown: Select "Other Stamps"

Both fields are required to list on eBay.
```

### Developer Documentation

**In code comments:**
```r
# eBay Category Selection System
#
# eBay requires LEAF categories for listings. Stamp categories are organized:
# Region (NOT leaf) > Country/Subcategory (LEAF)
#
# All regions except "Other Stamps" require a subcategory selection.
# Category 260 (Stamps parent) is NOT a valid listing category.
#
# Category data source: eBay's official CategoryIDs-US.csv
# Last updated: 2025-11-02 (refresh quarterly)
```

---

## Rollout Plan

### Development Environment Testing
1. Implement Phase 1-3
2. Test with 10+ sample stamps
3. Verify eBay sandbox accepts categories

### Staging/Beta Testing
1. Deploy to test environment
2. Test with real user (you)
3. Create 5-10 actual eBay listings
4. Verify listings appear in correct categories

### Production Rollout
1. Deploy to production
2. Update existing hardcoded category 675 listings (optional migration)
3. Monitor for eBay errors
4. Collect user feedback

---

## Risk Assessment

### High Risk
**Issue:** User selects wrong category despite validation
**Mitigation:** Clear labels, tooltip help text, validation before submission

**Issue:** eBay changes category structure
**Mitigation:** Quarterly refresh of CSV, fallback to "Other Stamps"

### Medium Risk
**Issue:** AI country extraction accuracy
**Mitigation:** User can always override, defaults to "Other Stamps" if uncertain

### Low Risk
**Issue:** UI clutter with two dropdowns
**Mitigation:** Clean design, only show country dropdown when needed

---

## References

- **eBay Category CSV:** https://ir.ebaystatic.com/pictures/aw/pics/pdf/us/file_exchange/CategoryIDs-US.csv
- **Related PRPs:**
  - `PRP_EBAY_STAMP_CATEGORY_VALIDATION.md` - Original investigation
  - `STAMP_CATEGORY_FIX_COMPLETE.md` - Current temporary fix
- **Code Files:**
  - `dev/stamp_categories_only.csv` - Extracted stamp categories
  - `dev/process_stamp_categories.R` - Processing script
  - `R/ebay_stamp_categories.R` - Category mapping module (to be created)
  - `R/mod_stamp_export.R` - UI implementation location

---

**Status:** Ready for Implementation
**Estimated Total Time:** 16-22 hours
**Priority:** Critical - Blocks proper international stamp listing

---

## Appendix: Sample Category Mappings

### United States Categories
```
675 - 19th Century: Used
676 - 19th Century: Unused
3461 - 1901-40: Unused
678 - 1901-Now: Used
679 - 1941-Now: Unused
47149 - Postage (general)
265 - Sheets
683 - Collections, Lots
```

### Europe Categories (Sample)
```
12559 - France
12560 - Germany
12563 - Italy
12571 - Spain
12569 - Romania
12568 - Poland
12561 - Greece
```

### Asia Categories (Sample)
```
12574 - China
12577 - Japan
12576 - India
12581 - Thailand
12583 - Vietnam
```

Total: 438 stamp categories available
