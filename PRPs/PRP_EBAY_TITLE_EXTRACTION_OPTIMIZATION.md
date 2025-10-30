# PRP: eBay Title Extraction Optimization

## Problem Statement

Current AI extraction produces titles that are not optimized for eBay listings. eBay collectors search using specific patterns and keywords, and titles need to maximize searchability while adhering to eBay's 80-character limit. The current prompt generates generic descriptive titles rather than collector-optimized, keyword-rich titles.

### Current State
- Titles are generated with instruction: "A concise, descriptive title (50-80 characters, ASCII only)"
- No guidance on formatting patterns or keyword prioritization
- No emphasis on uppercase convention used by professional sellers
- No guidance on element ordering or separator usage
- Generic approach rather than collector/search-optimized

### Desired State
- Titles follow professional eBay postal history listing conventions
- ALL UPPERCASE format for consistency with market standards
- Dash-separated sections for readability
- Strategic keyword ordering for maximum search visibility
- Consistent 80-character limit enforcement

## Context Analysis

### Current Implementation
**File**: `R/ai_api_helpers.R`
**Function**: `build_enhanced_postal_card_prompt()` (lines 488-656)

The function handles three extraction types:
1. **lot** - Multiple postcards
2. **combined** - Single postcard (face + verso)
3. **individual** - Single image

Current title instruction appears in all three branches:
```r
"1. TITLE: A concise, descriptive title (50-80 characters, ASCII only)\\n"
```

### eBay Market Requirements

#### Search Optimization
- eBay's search algorithm prioritizes early keywords in titles
- Collectors search by: country → year → type → location → features
- Professional sellers use consistent formatting patterns
- ALL CAPS titles are industry standard for postal history

#### Character Limit
- eBay hard limit: 80 characters
- Must account for spaces and separators
- Every character counts for search ranking

## Solution Design

### New Title Extraction Instructions

Replace current generic title instructions with comprehensive eBay-optimized guidance:

```
TITLE: Generate an eBay-optimized title (MAXIMUM 80 characters)

CRITICAL REQUIREMENTS:
- ALL UPPERCASE format
- Use dashes (-) to separate key sections
- ASCII only (e.g., Buzias not Buziaș)
- Maximize searchable keywords within 80-character limit

ELEMENT PRIORITY ORDER:
1. Country/Origin (MANDATORY - start with this)
2. Year or time period (if visible on postcard/postmark)
3. Item type/category (e.g., POSTCARD, POSTAL CARD, COVER, STAMP)
4. Key identifying features (denominations, colors, notable markings)
5. Locations mentioned (cities, postal routes, regions)
6. Special features (PERFIN, OVERPRINT, CANCELLATION, SIGNATURE)

FORMAT PATTERN:
COUNTRY - YEAR TYPE FEATURE1 FEATURE2 LOCATION1 LOCATION2 SPECIAL

FORMATTING RULES:
- No articles (omit: a, an, the)
- No unnecessary words or filler
- Prioritize rarity indicators and unique identifiers
- Include visible postmarks, cancellations, or special markings
- Be specific but concise
- Each element separated by space-dash-space ( - ) or just spaces

KEYWORD OPTIMIZATION:
- Front-load most important search terms (country, year, location)
- Use collector terminology (PERFIN, RAILWAY POST, etc.)
- Include postal routes if visible
- Mention notable destinations or origins
- Reference visible revenue stamps or special markings

EXAMPLES OF OPTIMIZED TITLES:

LOT/COMBINED:
"AUSTRIA - 1912 PARCEL POST TO ROMANIA REICHENBERG PERFIN REVENUE STAMP VERSO"
"ROMANIA - POSTAL HISTORY LOT FERDINAND ARAD FOCSANI IASI"
"FRANCE - 1920s PARIS VIEWS EIFFEL TOWER NOTRE DAME LOT OF 5"
"GERMANY - 1935 BERLIN OLYMPIC GAMES POSTMARKS HITLER ERA"

INDIVIDUAL:
"ROMANIA - 1905 BUZIAS TIMIS POSTMARK UNDIVIDED BACK THERMAL BATHS"
"AUSTRIA - 1910 WIEN VIENNA RINGSTRASSE TRAM POSTED TO PRAGUE"
"FRANCE - 1898 EXPOSITION UNIVERSELLE EIFFEL TOWER EARLY POSTCARD"
"ROMANIA - 1930 ARAD CITY HALL LINEN ERA TRANSYLVANIA"

EXTRACTION STRATEGY:
1. Examine BOTH face and verso images
2. Identify country from visible text, language, or landmarks
3. Look for dates on postmarks, stamps, or printed on card
4. Extract visible location names from image text or postmarks
5. Note special features: perfins, revenues, cancellations, signatures
6. Identify item type (postcard vs postal cover vs stamps)
7. Construct title following priority order
8. Verify character count ≤ 80
9. Convert to ALL UPPERCASE
10. Ensure ASCII-only characters
```

### Implementation Changes

#### File: `R/ai_api_helpers.R`
**Function**: `build_enhanced_postal_card_prompt()`

Update three sections:

##### 1. LOT Extraction (lines ~495-540)
Replace:
```r
"1. TITLE: A concise, descriptive title (50-80 characters, ASCII only)\\n",
"   - Include collection theme or location\\n",
"   - Include era if identifiable\\n",
"   - Example: 'Vintage Postcard Lot - Romanian Town Views, 1930s'\\n\\n",
```

With:
```r
"1. TITLE: eBay-optimized title (MAXIMUM 80 characters)\\n",
"   - ALL UPPERCASE format\\n",
"   - Use dashes (-) to separate sections\\n",
"   - ASCII only (e.g., Buzias not Buziaș)\\n",
"   - Element order: COUNTRY - YEAR TYPE LOCATION FEATURES\\n",
"   - Front-load important search terms (country, year, city)\\n",
"   - Include special features: PERFIN, OVERPRINT, CANCELLATION\\n",
"   - No articles (a, an, the) or filler words\\n",
"   - Examples:\\n",
"     * 'AUSTRIA - 1912 PARCEL POST ROMANIA REICHENBERG PERFIN REVENUE'\\n",
"     * 'ROMANIA - POSTAL HISTORY LOT FERDINAND ARAD FOCSANI IASI'\\n",
"     * 'FRANCE - 1920s PARIS VIEWS EIFFEL TOWER NOTRE DAME LOT 5'\\n\\n",
```

##### 2. COMBINED Extraction (lines ~541-610)
Replace:
```r
"1. TITLE: A concise, descriptive title (50-80 characters, ASCII only)\\n",
"   - Include location if visible (e.g., Buzias, not Buziaș)\\n",
"   - Include era if identifiable\\n",
"   - If multiple cards, find common theme or location\\n",
"   - Example: 'Vintage Postcards - Romanian Town Views, 1930s'\\n\\n",
```

With:
```r
"1. TITLE: eBay-optimized title (MAXIMUM 80 characters)\\n",
"   - ALL UPPERCASE format\\n",
"   - Use dashes (-) to separate sections\\n",
"   - ASCII only (e.g., Buzias not Buziaș)\\n",
"   - Element order: COUNTRY - YEAR TYPE LOCATION FEATURES\\n",
"   - Front-load important search terms (country, year, city)\\n",
"   - Extract from BOTH face and verso sides\\n",
"   - Include postmarks, cancellations, visible routes\\n",
"   - No articles (a, an, the) or filler words\\n",
"   - Examples:\\n",
"     * 'ROMANIA - 1905 BUZIAS TIMIS POSTMARK UNDIVIDED BACK BATHS'\\n",
"     * 'AUSTRIA - 1910 WIEN RINGSTRASSE TRAM POSTED PRAGUE'\\n",
"     * 'GERMANY - 1935 BERLIN OLYMPIC POSTMARKS HITLER ERA'\\n\\n",
```

##### 3. INDIVIDUAL Extraction (lines ~611-650)
Replace:
```r
"1. TITLE: A concise, descriptive title (50-80 characters, ASCII only)\\n",
"   - Include location if visible (e.g., Buzias, not Buziaș)\\n",
"   - Include era if identifiable\\n",
"   - Example: 'Vintage Postcard - Paris Eiffel Tower, 1920s'\\n\\n",
```

With:
```r
"1. TITLE: eBay-optimized title (MAXIMUM 80 characters)\\n",
"   - ALL UPPERCASE format\\n",
"   - Use dashes (-) to separate sections\\n",
"   - ASCII only (e.g., Buzias not Buziaș)\\n",
"   - Element order: COUNTRY - YEAR TYPE LOCATION FEATURES\\n",
"   - Front-load important search terms (country, year, city)\\n",
"   - Look for postmarks, cancellations, special markings\\n",
"   - Include visible postal routes or destinations\\n",
"   - No articles (a, an, the) or filler words\\n",
"   - Examples:\\n",
"     * 'ROMANIA - 1905 BUZIAS TIMIS POSTMARK UNDIVIDED BACK BATHS'\\n",
"     * 'FRANCE - 1898 EXPOSITION UNIVERSELLE EIFFEL TOWER EARLY'\\n",
"     * 'AUSTRIA - 1910 WIEN VIENNA RINGSTRASSE TRAM POSTED PRAGUE'\\n\\n",
```

## Testing Strategy

### Test Cases

#### Test 1: Romanian Postal History (Complex)
**Input**: Face shows Buziaș town view, verso shows 1912 postmark, perfin stamp, revenue stamp, addressed to Romania
**Expected Title**: `ROMANIA - 1912 BUZIAS TIMIS PERFIN REVENUE STAMP POSTAL HISTORY`
**Validation**:
- ✓ Starts with country
- ✓ Includes year from postmark
- ✓ All uppercase
- ✓ ASCII (Buzias not Buziaș)
- ✓ Includes special features (PERFIN, REVENUE)
- ✓ ≤ 80 characters

#### Test 2: French Tourist Postcard (Simple)
**Input**: Eiffel Tower view, 1920s era, unused
**Expected Title**: `FRANCE - 1920s PARIS EIFFEL TOWER POSTCARD UNUSED`
**Validation**:
- ✓ Starts with country
- ✓ Includes era
- ✓ All uppercase
- ✓ Location included
- ✓ ≤ 80 characters

#### Test 3: Multi-Card Lot (Thematic)
**Input**: 5 Romanian postcards from Arad, Focsani, Iasi, Ferdinand era
**Expected Title**: `ROMANIA - POSTAL HISTORY LOT FERDINAND ERA ARAD FOCSANI IASI`
**Validation**:
- ✓ Starts with country
- ✓ Identifies as lot
- ✓ All uppercase
- ✓ Multiple locations
- ✓ Era mentioned
- ✓ ≤ 80 characters

#### Test 4: Austrian Parcel Post (Special Features)
**Input**: 1912 Austrian parcel post card to Romania, Reichenberg postmark, perfin, revenue stamp on back
**Expected Title**: `AUSTRIA - 1912 PARCEL POST ROMANIA REICHENBERG PERFIN REVENUE VERSO`
**Validation**:
- ✓ Starts with country (origin)
- ✓ Includes year
- ✓ Item type (PARCEL POST)
- ✓ Destination country
- ✓ Special features prioritized
- ✓ ≤ 80 characters (77 actual)

### Manual Verification Workflow

1. **Process Test Set**: Run 20-30 diverse postcards through AI extraction
2. **Review Titles**: Check each generated title against requirements
3. **Character Count**: Verify all titles ≤ 80 characters
4. **Format Check**: Confirm ALL UPPERCASE and ASCII-only
5. **Keyword Quality**: Assess searchability and collector appeal
6. **Comparison Test**: Compare old vs new title formats side-by-side

### Success Criteria

- ✓ 100% of titles are ≤ 80 characters
- ✓ 100% of titles are ALL UPPERCASE
- ✓ 100% of titles are ASCII-only (no diacritics)
- ✓ 95%+ titles start with COUNTRY
- ✓ 90%+ titles include year/era when visible
- ✓ 95%+ titles include location when visible
- ✓ 100% titles use dash separators appropriately
- ✓ Subjective: Titles feel "professional" and "eBay-optimized"

## Implementation Steps

### Step 1: Update Prompt Function
1. Open `R/ai_api_helpers.R`
2. Locate `build_enhanced_postal_card_prompt()` function (line 488)
3. Update title instructions in all three extraction type branches
4. Maintain ASCII instruction at top of function (already present)

### Step 2: Test with Real Data
1. Start Shiny app
2. Process 3-5 test postcards through AI extraction
3. Review generated titles in UI
4. Verify formatting and character counts
5. Iterate on prompt wording if needed

### Step 3: Batch Testing
1. Run extraction on 20-30 diverse postcards
2. Export titles to spreadsheet for review
3. Calculate compliance metrics (character count, uppercase, etc.)
4. Identify any edge cases or failure patterns

### Step 4: Documentation Update
1. Update `.serena/memories/` with implementation notes
2. Document any AI model differences (Claude vs GPT-4)
3. Create before/after examples in memory

### Step 5: Critical Tests
1. Verify existing tests still pass: `source("dev/run_critical_tests.R")`
2. Consider adding title format validation tests
3. Document test results

## Edge Cases & Considerations

### Character Limit Enforcement
**Issue**: AI may generate titles >80 characters
**Solution**: Prompt emphasizes MAXIMUM 80 characters multiple times
**Fallback**: Could add post-processing truncation in `parse_enhanced_ai_response()` if needed

### Unknown Country
**Issue**: Some postcards may not have identifiable country
**Solution**: Prompt to extract from text, language, landmarks; if truly unknown, start with "POSTCARD - " or "POSTAL HISTORY - "

### Multiple Special Features
**Issue**: Too many features (PERFIN + OVERPRINT + RAILWAY + CANCELLATION) may exceed 80 chars
**Solution**: Prompt instructs to prioritize rarity indicators; AI should select most notable 2-3 features

### Mixed Languages
**Issue**: Postcards with multiple languages (e.g., Romanian city in Austrian Empire)
**Solution**: Use origin country (issuer) rather than destination; prompt emphasizes visible postmarks/text

### Lot Consistency
**Issue**: Multi-card lots may have mixed countries/eras
**Solution**: Prompt instructs to identify common theme or most prominent card; use "LOT" keyword to indicate multiple items

### ASCII Conversion Quality
**Issue**: AI must convert diacritics correctly
**Solution**: Existing ASCII instruction already handles this; examples in prompt reinforce correct conversions

## Rollback Plan

If new title format causes issues:

1. **Immediate**: Restore previous prompt from git history
2. **File**: `R/ai_api_helpers.R` function `build_enhanced_postal_card_prompt()`
3. **Command**: `git checkout HEAD~1 -- R/ai_api_helpers.R`
4. **Restart**: Restart Shiny app to load old prompt

No database changes required - titles are stored as text fields.

## Future Enhancements

### Phase 2: Title Templates by Category
- Create specialized title formats for different postcard types
- Railway posts, military mail, censored mail, perfins, etc.
- Each category gets optimized keyword patterns

### Phase 3: A/B Testing
- Track eBay listing performance (views, sales) by title format
- Iterate on prompt based on actual market data
- Build feedback loop from eBay metrics

### Phase 4: Multi-Language Support
- Add instructions for non-English postcards
- Maintain English keywords for eBay search
- Balance native language terms with searchability

## References

### eBay Best Practices
- Title character limit: 80 characters
- ALL CAPS convention for postal history sellers
- Front-load important keywords for search algorithm
- Include year, country, location for maximum search visibility

### Market Research
- Professional eBay postal history sellers use consistent patterns
- Collectors search by: country → year → location → type → features
- Dash-separated format improves readability in search results
- Special features (PERFIN, RAILWAY POST, etc.) attract specialist collectors

### Project Context
- Golem app structure: changes isolated to helper function
- ASCII-only requirement already implemented
- No UI changes needed - transparent enhancement
- Backward compatible - stored titles remain valid

---

## Acceptance Criteria

Implementation is complete when:

1. ✅ All three extraction types (lot, combined, individual) use new title instructions
2. ✅ Generated titles are ≤ 80 characters
3. ✅ Generated titles are ALL UPPERCASE
4. ✅ Generated titles use dash separators appropriately
5. ✅ Generated titles prioritize country/year/location/features correctly
6. ✅ ASCII-only characters (no diacritics)
7. ✅ Manual testing with 20+ postcards shows quality improvement
8. ✅ Critical tests pass: `source("dev/run_critical_tests.R")`
9. ✅ Documentation updated in `.serena/memories/`
10. ✅ No regression in other extraction fields (description, price, metadata)

---

## Notes for Implementation

- **Conservative approach**: Only modify title instructions, leave all other fields unchanged
- **Backward compatible**: Existing extraction logic and parsing unchanged
- **No breaking changes**: Database schema, UI, and module interfaces remain the same
- **Prompt engineering**: May require 1-2 iterations to tune AI response quality
- **Model differences**: Claude and GPT-4 may respond slightly differently; test both
- **User preference**: Consider making format optional in future (some users may prefer sentence case)
