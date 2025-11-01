#' Stamp AI Helpers
#'
#' @description Functions for AI-powered stamp metadata extraction
#'
#' This module provides stamp-specific prompts and parsing for AI extraction.
#' Uses the same AI provider infrastructure as postal cards but with philatelic-specific fields.
#'
#' @name stamp_ai_helpers
NULL

#' Build Stamp Analysis Prompt
#'
#' @description Creates a detailed prompt for AI analysis of stamp images
#'
#' @param extraction_type Character: "individual" or "lot"
#' @param stamp_count Integer: Number of stamps (for lot type)
#' @return Character: Formatted prompt string
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
      "IMPORTANT: This is a SINGLE stamp showing both front and back.\n\n",

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
      "     * 'USA - 1963 5c WASHINGTON COIL PERFIN'\n",
      "     * 'ROMANIA - 1920 FERDINAND OVERPRINT MINT HINGED'\n",
      "     * 'GERMANY - 1940 THIRD REICH PROPAGANDA USED'\n\n",

      "2. DESCRIPTION: Detailed description (150-300 characters, ASCII only)\n",
      "   - Country of origin\n",
      "   - Year of issue (if visible)\n",
      "   - Denomination and currency\n",
      "   - Subject depicted (portrait, scene, symbol)\n",
      "   - Perforations, watermarks, overprints\n",
      "   - Scott catalog number (if identifiable)\n",
      "   - Historical or collecting significance\n\n",

      "3. RECOMMENDED_PRICE: Suggested retail price in USD\n",
      "   - Typical range: $0.50 - $5.00 (common), $5+ (scarce)\n",
      "   - Format: numeric value only (e.g., 3.50)\n\n",

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

#' Build Stamp Prompt (Title Only - No Description)
#'
#' @description Creates a minimal prompt for title extraction only (saves tokens when description not needed)
#'
#' @param extraction_type Character: "individual" or "lot"
#' @param stamp_count Integer: Number of stamps (for lot type)
#' @return Character: Formatted prompt string
#' @export
build_stamp_prompt_title_only <- function(extraction_type = "individual", stamp_count = 1) {

  # CRITICAL: ASCII-only instruction at the top
  ascii_instruction <- "IMPORTANT: Use ONLY ASCII characters in your output. Replace all diacritics:
- Romanian: ă→a, â→a, î→i, ș→s, ț→t
- European: é→e, è→e, ü→u, ö→o, ñ→n, ç→c
- Examples: București → Bucuresti, café → cafe

"

  base_prompt <- "You are an expert philatelist and stamp appraiser. Analyze this stamp image and provide TITLE and PRICE only.\n\n"

  if (extraction_type == "lot") {
    prompt <- paste0(ascii_instruction, base_prompt,
      "IMPORTANT: This is a lot of ", stamp_count, " stamps.\n",
      "The image shows BOTH SIDES of each stamp.\n\n",

      "REQUIRED FIELDS (extract these only):\n\n",
      "1. TITLE: eBay-optimized title (MAXIMUM 80 characters)\n",
      "   - ALL UPPERCASE format\n",
      "   - Format: COUNTRY - YEAR DENOMINATION TOPIC/TYPE FEATURES\n",
      "   - Example: 'USA - 1963 5c WASHINGTON COIL PERFIN LOT OF 3'\n\n",

      "2. RECOMMENDED_PRICE: eBay sale price in USD for entire lot\n",
      "   - Format: numeric value only (e.g., 24.00)\n\n",

      "3. GRADE: Condition (Used, Mint, MNH, etc.)\n\n",

      "Format your response EXACTLY as:\n",
      "TITLE: [your title]\n",
      "RECOMMENDED_PRICE: [numeric value]\n",
      "GRADE: [condition]"
    )
  } else {
    prompt <- paste0(ascii_instruction, base_prompt,
      "Analyze this individual stamp.\n\n",

      "REQUIRED FIELDS (extract these only):\n\n",
      "1. TITLE: eBay-optimized title (MAXIMUM 80 characters)\n\n",
      "2. RECOMMENDED_PRICE: eBay sale price in USD\n\n",
      "3. GRADE: Condition\n\n",

      "Format your response EXACTLY as:\n",
      "TITLE: [your title]\n",
      "RECOMMENDED_PRICE: [numeric value]\n",
      "GRADE: [condition]"
    )
  }

  return(prompt)
}

#' Parse Stamp AI Response
#'
#' @description Extracts structured stamp metadata from AI response text
#'
#' @param response_text Character: Raw AI response text
#' @return List: Extracted stamp metadata fields
#' @export
parse_stamp_response <- function(response_text) {

  # Helper to extract field using regexpr (same as postal card parser)
  extract_field <- function(text, field_name) {
    pattern <- paste0(field_name, ":\\s*(.+?)(?=\\n|$)")
    match <- regexpr(pattern, text, perl = TRUE)
    if (match > 0) {
      start <- attr(match, "capture.start")[1]
      length <- attr(match, "capture.length")[1]
      return(trimws(substr(text, start, start + length - 1)))
    }
    return(NA_character_)
  }

  # Extract all fields
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

message("✅ Stamp AI helpers loaded!")
