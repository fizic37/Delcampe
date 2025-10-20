# TASK: AI Extraction for Combined Images

## Context

The deduplication feature is now working perfectly. When a user uploads images, processes them, and creates combined face+verso images, we want to run AI extraction on these combined images to generate metadata (title, description, condition, price).

## Current State

### What Works
- ✅ Individual face and verso images can be processed and cropped
- ✅ Combined images are created (both individual pairs and lot images)
- ✅ AI extraction exists and works for individual images
- ✅ Database has `card_processing` table with AI fields ready

### Combined Image Types
After processing, we have:
1. **Individual combined images** - Face+verso pairs (e.g., `combined_row0_col0.jpg`, `combined_row1_col0.jpg`)
2. **Lot image** - All pairs stacked vertically (e.g., `lot_column_1.jpg`)

Both are stored in: `shiny_combined_images_*/combined_images/`

## Requirements

### 1. Determine Which Images to Extract AI From

**Decision needed:** Should we extract AI from:
- **Option A:** Individual combined images (each face+verso pair) - More granular, one AI extraction per card
- **Option B:** Lot image (all pairs together) - Single extraction for the entire lot
- **Option C:** Both - Extract from individuals AND lot, store differently

**Recommendation:** Option A (individual combined images) because:
- Each postal card pair should have its own metadata
- More practical for eBay listings (one card = one listing)
- Can aggregate to lot level if needed later

### 2. When to Trigger AI Extraction

**Trigger point:** When combined images are created (in `combined_image_output_display` render)

Current flow:
```r
# In app_server.R when images_processed becomes TRUE
combined_output <- renderUI({
  # Creates combined images display
  # Combined images are ready at this point
  # → TRIGGER AI EXTRACTION HERE
})
```

### 3. Integration with card_processing Table

When AI extraction completes for a card:
```r
save_card_processing(
  card_id = card_id,  # Already exists from upload
  crop_paths = existing_crops,  # Already saved
  h_boundaries = existing_h,
  v_boundaries = existing_v,
  grid_rows = existing_rows,
  grid_cols = existing_cols,
  extraction_dir = existing_dir,
  ai_data = list(  # NEW - Update this
    title = "Vintage Postcard - Paris Eiffel Tower",
    description = "Beautiful vintage postcard...",
    condition = "Good",
    price = 15.99,
    model = "claude-3-5-sonnet-20241022"
  )
)
```

This **updates** the existing card_processing row (UPSERT pattern).

### 4. UI Flow

**Current:**
```
Upload → Extract → Combine → [Display combined images]
```

**After Implementation:**
```
Upload → Extract → Combine → [Display combined images] → AI Extract → [Show AI results]
```

**UI Placement:**
- AI extraction results should appear in the existing "AI Extraction Results" accordion
- One accordion item per individual combined image
- Show: Title, Description, Condition, Price

## Implementation Steps

### Step 1: Identify Combined Image Paths

In `app_server.R`, after combined images are created:
```r
# Get paths to individual combined images
combined_dir <- rv$combined_output_dir  # This should exist
combined_files <- list.files(
  combined_dir, 
  pattern = "^combined_row.*\\.jpg$",
  full.names = TRUE
)
```

### Step 2: Match Combined Images to card_ids

Each combined image corresponds to a face+verso pair at a specific row:
```r
# Row 0 → face card_id from row 0
# Need to track which crop belongs to which card_id
# This mapping needs to be stored when extraction happens
```

**Problem:** We currently don't track which crop row maps to which card_id. We need to add this.

### Step 3: Call AI Extraction

For each combined image:
```r
# Reuse existing AI extraction module
ai_result <- extract_with_llm(
  image_path = combined_image_path,
  api_key = api_key,
  model = selected_model,
  prompt = ai_prompt
)

# Update card_processing
save_card_processing(
  card_id = card_id_for_this_row,
  ... existing data ...,
  ai_data = ai_result
)
```

### Step 4: Display Results

Update the AI results accordion to show results for each card.

## Technical Challenges

### Challenge 1: Mapping Crops to card_ids

**Current:** We have face card_id and verso card_id at the module level, but we don't track which crop row corresponds to which pair.

**Solution:** Store crop-to-card mapping during extraction:
```r
# In extraction observer, store:
rv$crop_to_card_mapping <- data.frame(
  row = 0:2,
  face_card_id = rep(rv$face_card_id, 3),
  verso_card_id = rep(rv$verso_card_id, 3)
)
```

### Challenge 2: Running AI for Multiple Images

**Current:** AI extraction runs on a single image.

**Solution:** Loop through combined images and run AI extraction sequentially or in parallel.

### Challenge 3: Storing Results

**Current:** card_processing has fields for ONE set of AI data per card.

**Question:** For a pair of face+verso:
- Do we store AI data against the **face** card_id?
- Or create a **new combined card** entry?

**Recommendation:** Store against face card_id (the "primary" card in the pair).

## Files to Modify

### 1. `R/app_server.R`
Add AI extraction trigger after combined images are created.

### 2. `R/mod_postal_card_processor.R`
Store crop-to-card mapping during extraction.

### 3. `R/tracking_database.R`
No changes needed - functions already support ai_data parameter.

### 4. Potentially new file: `R/utils_ai_combined.R`
Helper functions for AI extraction on combined images.

## Success Criteria

✅ Combined images automatically trigger AI extraction  
✅ Each individual combined image gets its own AI metadata  
✅ Results are stored in `card_processing` table  
✅ Results are displayed in AI Extraction accordion  
✅ User can see: title, description, condition, price for each card  
✅ Works with the existing deduplication feature  

## Questions to Answer

1. **Which combined images?** Individual pairs or lot image? → **Recommendation: Individual pairs**
2. **How to map crops to cards?** Need data structure → **Add mapping in extraction observer**
3. **Where to store AI data?** Face card, verso card, or new combined card? → **Recommendation: Face card**
4. **When to trigger?** After combine completes → **In combined_output render**
5. **Batch or sequential?** Run AI for all images at once or one by one? → **Sequential with progress indicator**

## Next Steps

1. Decide on the questions above
2. Add crop-to-card mapping data structure
3. Implement AI extraction trigger after combine
4. Test with real images
5. Update UI to display per-card AI results

---

**Ready to implement?** Start with Step 1: Add the crop-to-card mapping structure during extraction.
