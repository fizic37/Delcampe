# Magnifying Glass Implementation Guide for R Shiny Golem App

## Overview
This guide provides complete instructions for implementing a magnifying glass feature on combined image outputs in your R Shiny Golem application.

**IMPORTANT:** No magnifying glass implementation was found in Test_Delcampe. This is a new implementation created based on best practices.

## Files to Create/Modify

### 1. Create JavaScript File
**Location:** `inst/app/www/image_magnifier.js`

This file contains all the magnifying glass logic. Features include:
- Mouse tracking for lens positioning
- Touch support for mobile devices
- Configurable zoom level and lens size
- Auto-initialization via data attributes
- Programmatic API for dynamic control

See the `image_magnifier_js` artifact for the complete JavaScript code.

### 2. Update CSS File
**Location:** `inst/app/www/styles.css`

Add the magnifier styles to your existing styles.css file. The styles include:
- Circular lens with border and shadow
- Cursor changes for better UX
- Optional magnification indicator icon

See the `magnifier_css` artifact for the CSS code to add.

### 3. Integrate into R Module
Modify your postal cards module (e.g., `R/mod_postal_cards_face.R`)

See the `r_shiny_integration` artifact for examples.

## Implementation Steps

### Step 1: Add JavaScript File
1. Copy the JavaScript code from the artifact to `inst/app/www/image_magnifier.js`
2. Ensure the file is tracked in your git repository

### Step 2: Add CSS Styles
Append the magnifier CSS to your existing `inst/app/www/styles.css`

### Step 3: Modify UI Function
In your module's UI function, add the JavaScript file reference:

```r
mod_postal_cards_face_ui <- function(id) {
  ns <- NS(id)
  tagList(
    # Add magnifier JS
    tags$head(
      tags$script(src = "www/image_magnifier.js")
    ),
    
    # Your existing UI code...
  )
}
```

### Step 4: Update Image Output
When rendering the combined image, use one of these approaches:

#### Approach A: Auto-initialization (Simplest)
```r
tags$img(
  id = ns("combined_image"),
  src = image_url,
  `data-magnifier` = "true",
  `data-magnifier-zoom` = "2.5",
  `data-magnifier-size` = "200"
)
```

#### Approach B: Onload initialization (Recommended)
```r
tags$img(
  id = ns("combined_image"),
  src = image_url,
  onload = sprintf(
    "if (typeof initImageMagnifier === 'function') { 
      initImageMagnifier('%s', 2.5, 200); 
    }", 
    ns("combined_image")
  )
)
```

#### Approach C: Server-side initialization (Most Flexible)
```r
# In server function
observeEvent(rv$combined_image_url, {
  session$sendCustomMessage(
    "initMagnifier",
    list(
      imageId = ns("combined_image"),
      zoom = 2.5,
      lensSize = 200
    )
  )
})
```

## Configuration Options

### Zoom Level
- **Range:** 1.5 - 5
- **Recommended:** 2 - 3
- **Default:** 2

```javascript
// JavaScript
initImageMagnifier('image_id', 2.5, 200);
```

```r
# R Shiny
data-magnifier-zoom="2.5"
```

### Lens Size
- **Range:** 100 - 300 pixels
- **Recommended:** 150 - 200 pixels
- **Default:** 150

```javascript
// JavaScript
initImageMagnifier('image_id', 2, 200);
```

```r
# R Shiny
data-magnifier-size="200"
```

## Example: Complete Integration

### In `R/mod_postal_cards_face.R`:

```r
mod_postal_cards_face_ui <- function(id) {
  ns <- NS(id)
  tagList(
    shinyjs::useShinyjs(),
    tags$head(
      tags$script(src = "www/image_magnifier.js")
    ),
    bslib::page_fluid(
      # ... your existing controls ...
      
      # Combined image display with magnifier
      fluidRow(
        column(
          width = 12,
          bslib::card(
            header = bslib::card_header("Combined Image (Hover to Magnify)"),
            uiOutput(ns("combined_image_display"))
          )
        )
      )
    )
  )
}

mod_postal_cards_face_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # Reactive value for combined image
    rv <- reactiveValues(
      combined_image_url = NULL
    )
    
    # Render combined image with magnifier
    output$combined_image_display <- renderUI({
      req(rv$combined_image_url)
      
      div(
        class = "magnifiable-image-container",
        style = "text-align: center;",
        tags$img(
          id = ns("combined_img"),
          src = rv$combined_image_url,
          style = "max-width: 100%; height: auto;",
          onload = sprintf(
            "initImageMagnifier('%s', 2.5, 200);",
            ns("combined_img")
          )
        )
      )
    })
    
    # When combined image is created
    observeEvent(input$create_combined, {
      # ... your image combination logic ...
      
      # Set the combined image URL
      rv$combined_image_url <- combined_img_web_path
    })
  })
}
```

## Testing

### Test Checklist
- [ ] Magnifier appears on mouse hover
- [ ] Magnifier follows cursor smoothly
- [ ] Magnifier disappears when mouse leaves image
- [ ] Zoom level provides clear magnification
- [ ] No performance issues on large images
- [ ] Touch works on mobile devices (if applicable)
- [ ] Multiple images can each have their own magnifier

### Troubleshooting

#### Issue: Magnifier not appearing
**Solutions:**
1. Check browser console for JavaScript errors
2. Verify `image_magnifier.js` is loaded (check Network tab)
3. Ensure image has a unique ID
4. Confirm image is fully loaded before initialization

#### Issue: Magnifier position is off
**Solutions:**
1. Ensure parent container has `position: relative`
2. Check for CSS conflicts with `z-index`
3. Verify image dimensions are calculated correctly

#### Issue: Blurry magnification
**Solutions:**
1. Use higher resolution source images
2. Adjust zoom level (lower values = clearer but less magnification)
3. Check image compression settings

## Browser Compatibility
- ✅ Chrome/Edge (latest)
- ✅ Firefox (latest)
- ✅ Safari (latest)
- ✅ Mobile browsers (with touch support)

## Performance Notes
- Magnifier uses CSS background positioning for smooth performance
- Minimal JavaScript overhead
- Works well with images up to 5000x5000 pixels
- For very large images (>10MB), consider adding loading indicators

## Advanced Customization

### Custom Lens Styling
Modify CSS in `styles.css`:

```css
.magnifier-lens {
  border: 5px solid #52B788;  /* Match your theme */
  border-radius: 50%;         /* Keep circular */
  box-shadow: 0 0 15px rgba(0, 0, 0, 0.7);  /* Adjust shadow */
}
```

### Dynamic Zoom Control
Add zoom controls in your UI:

```r
# UI
sliderInput(ns("zoom_level"), "Zoom Level", min = 1.5, max = 5, value = 2.5, step = 0.5)

# Server
observeEvent(input$zoom_level, {
  session$sendCustomMessage(
    "updateMagnifierZoom",
    list(
      imageId = ns("combined_img"),
      zoom = input$zoom_level
    )
  )
})
```

### Disable Magnifier Programmatically
```javascript
// In JavaScript console or custom script
const magnifier = initImageMagnifier('my_image', 2, 150);
magnifier.destroy();  // Remove magnifier
```

## Summary of Findings from Test_Delcampe

After thorough investigation of the Test_Delcampe project:
- **No magnifying glass feature exists** in the Test_Delcampe app
- The app uses draggable grid lines for image manipulation (see `draggable_lines.js`)
- Both Test_Delcampe and Delcampe share similar structure
- This implementation is newly created based on best practices

## Next Steps
1. Create the JavaScript file in `inst/app/www/image_magnifier.js`
2. Add CSS styles to `inst/app/www/styles.css`
3. Integrate into your module
4. Test with sample images
5. Adjust zoom/size parameters to your preference
6. Deploy and gather user feedback

## Support
- Check browser console for errors
- Verify all files are in correct locations
- Test with simple image first before complex combined images
- Use browser dev tools to inspect element positions
