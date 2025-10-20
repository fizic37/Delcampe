# ========================================
# MAGNIFYING GLASS R SHINY INTEGRATION
# Complete examples for implementation
# ========================================

# ----------------------------------------
# Example 1: Basic Integration in Module UI
# ----------------------------------------

mod_postal_cards_face_ui <- function(id) {
  ns <- NS(id)
  tagList(
    shinyjs::useShinyjs(),
    
    # Add magnifier JavaScript
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

# ----------------------------------------
# Example 2: Server-side Rendering with Auto-initialization
# ----------------------------------------

mod_postal_cards_face_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    rv <- reactiveValues(
      combined_image_url = NULL
    )
    
    # Approach A: Using data attributes (simplest)
    output$combined_image_display <- renderUI({
      req(rv$combined_image_url)
      
      div(
        class = "magnifiable-image-container",
        style = "text-align: center;",
        tags$img(
          id = ns("combined_img"),
          src = rv$combined_image_url,
          style = "max-width: 100%; height: auto;",
          # Auto-initialize on page load
          `data-magnifier` = "true",
          `data-magnifier-zoom` = "2.5",
          `data-magnifier-size` = "200"
        )
      )
    })
  })
}

# ----------------------------------------
# Example 3: Manual Initialization with onload
# ----------------------------------------

output$combined_image_display <- renderUI({
  req(rv$combined_image_url)
  
  div(
    class = "magnifiable-image-container",
    tags$img(
      id = ns("combined_img"),
      src = rv$combined_image_url,
      style = "max-width: 100%; height: auto;",
      # Initialize after image loads (recommended)
      onload = sprintf(
        "if (typeof initImageMagnifier === 'function') { 
          initImageMagnifier('%s', 2.5, 200); 
        }", 
        ns("combined_img")
      )
    )
  )
})

# ----------------------------------------
# Example 4: Server-controlled Initialization
# ----------------------------------------

output$combined_image_display <- renderUI({
  req(rv$combined_image_url)
  
  div(
    class = "magnifiable-image-container",
    tags$img(
      id = ns("combined_img"),
      src = rv$combined_image_url,
      style = "max-width: 100%; height: auto;"
    )
  )
})

# Initialize magnifier when image URL changes
observeEvent(rv$combined_image_url, {
  req(rv$combined_image_url)
  
  session$sendCustomMessage(
    "initMagnifier",
    list(
      imageId = ns("combined_img"),
      zoom = 2.5,
      lensSize = 200
    )
  )
})

# ----------------------------------------
# Example 5: Dynamic Zoom Control
# ----------------------------------------

# UI
fluidRow(
  column(
    width = 12,
    sliderInput(
      ns("zoom_control"),
      "Magnification Level",
      min = 1.5,
      max = 5,
      value = 2.5,
      step = 0.5
    )
  )
)

# Server
observeEvent(input$zoom_control, {
  session$sendCustomMessage(
    "updateMagnifierZoom",
    list(
      imageId = ns("combined_img"),
      zoom = input$zoom_control
    )
  )
})

# ----------------------------------------
# Example 6: Multiple Images with Different Settings
# ----------------------------------------

output$face_image_display <- renderUI({
  req(rv$face_image_url)
  
  div(
    class = "magnifiable-image-container",
    tags$img(
      id = ns("face_img"),
      src = rv$face_image_url,
      onload = "initImageMagnifier('face_img', 3, 150);"  # Higher zoom
    )
  )
})

output$verso_image_display <- renderUI({
  req(rv$verso_image_url)
  
  div(
    class = "magnifiable-image-container",
    tags$img(
      id = ns("verso_img"),
      src = rv$verso_image_url,
      onload = "initImageMagnifier('verso_img', 2, 200);"  # Lower zoom, bigger lens
    )
  )
})

# ----------------------------------------
# Example 7: Conditional Magnifier Activation
# ----------------------------------------

output$combined_image_display <- renderUI({
  req(rv$combined_image_url)
  
  # Only add magnifier if user has enabled it
  magnifier_attrs <- if (input$enable_magnifier) {
    list(
      `data-magnifier` = "true",
      `data-magnifier-zoom` = input$zoom_level,
      `data-magnifier-size` = input$lens_size
    )
  } else {
    list()
  }
  
  do.call(
    tags$img,
    c(
      list(
        id = ns("combined_img"),
        src = rv$combined_image_url,
        style = "max-width: 100%; height: auto;"
      ),
      magnifier_attrs
    )
  )
})

# ----------------------------------------
# Example 8: Integration with Existing Grid Display
# ----------------------------------------

output$image_with_draggable_grid <- renderUI({
  req(rv$image_url_display, rv$image_dims_original)
  
  # Your existing grid code...
  h_lines <- lapply(seq_along(h_boundaries_px), function(i) {
    # ... existing line creation code ...
  })
  
  v_lines <- lapply(seq_along(v_boundaries_px), function(i) {
    # ... existing line creation code ...
  })
  
  tags$div(
    style = "position:relative; width:100%; height:100%; overflow:visible;",
    
    # Image with magnifier
    tags$img(
      id = ns("preview_image"),
      src = img_src_with_nonce,
      style = paste(
        "display:block; position:absolute; top:0; left:0;",
        "width:100%; height:100%; object-fit:contain;",
        "pointer-events:none; z-index:5;"
      ),
      `data-original-width` = rv$image_dims_original[1],
      `data-original-height` = rv$image_dims_original[2],
      # Add magnifier initialization
      onload = sprintf("initImageMagnifier('%s', 2, 150);", ns("preview_image"))
    ),
    
    h_lines, 
    v_lines,
    
    # Your existing grid initialization script
    tags$script(HTML(sprintf(
      "if (typeof initDraggableGrid === 'function') { 
        initDraggableGrid(document.getElementById('%s')); 
      }",
      ns("grid_ui_wrapper")
    )))
  )
})

# ----------------------------------------
# Example 9: Complete Module with Magnifier
# ----------------------------------------

#' Combined Image Module UI
mod_combined_image_ui <- function(id) {
  ns <- NS(id)
  tagList(
    tags$head(
      tags$script(src = "www/image_magnifier.js")
    ),
    
    bslib::card(
      header = bslib::card_header(
        div(
          style = "display: flex; justify-content: space-between; align-items: center;",
          span("Combined Image"),
          div(
            checkboxInput(ns("enable_magnifier"), "Enable Magnifier", value = TRUE),
            conditionalPanel(
              condition = sprintf("input['%s']", ns("enable_magnifier")),
              sliderInput(ns("zoom_level"), "Zoom", min = 1.5, max = 5, value = 2.5, step = 0.5)
            )
          )
        )
      ),
      uiOutput(ns("image_display"))
    )
  )
}

#' Combined Image Module Server
mod_combined_image_server <- function(id, image_reactive) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    output$image_display <- renderUI({
      req(image_reactive())
      
      if (input$enable_magnifier) {
        div(
          class = "magnifiable-image-container",
          tags$img(
            id = ns("combined_img"),
            src = image_reactive(),
            style = "max-width: 100%; height: auto;",
            onload = sprintf(
              "initImageMagnifier('%s', %s, 200);",
              ns("combined_img"),
              input$zoom_level
            )
          )
        )
      } else {
        tags$img(
          src = image_reactive(),
          style = "max-width: 100%; height: auto;"
        )
      }
    })
    
    # Update zoom dynamically
    observeEvent(input$zoom_level, {
      req(input$enable_magnifier, image_reactive())
      
      session$sendCustomMessage(
        "updateMagnifierZoom",
        list(
          imageId = ns("combined_img"),
          zoom = input$zoom_level
        )
      )
    })
  })
}

# ----------------------------------------
# Example 10: Error Handling
# ----------------------------------------

output$combined_image_display <- renderUI({
  req(rv$combined_image_url)
  
  tryCatch({
    div(
      class = "magnifiable-image-container",
      tags$img(
        id = ns("combined_img"),
        src = rv$combined_image_url,
        style = "max-width: 100%; height: auto;",
        onload = sprintf(
          "try { 
            if (typeof initImageMagnifier === 'function') { 
              initImageMagnifier('%s', 2.5, 200); 
            } else {
              console.error('Magnifier function not loaded');
            }
          } catch(e) { 
            console.error('Error initializing magnifier:', e); 
          }",
          ns("combined_img")
        ),
        onerror = "console.error('Failed to load image for magnification');"
      )
    )
  }, error = function(e) {
    div(
      class = "alert alert-danger",
      paste("Error displaying image:", e$message)
    )
  })
})

# ----------------------------------------
# Testing Helper Function
# ----------------------------------------

#' Test magnifier on a simple image
test_magnifier <- function() {
  ui <- fluidPage(
    tags$head(
      tags$script(src = "www/image_magnifier.js")
    ),
    titlePanel("Magnifier Test"),
    div(
      class = "magnifiable-image-container",
      tags$img(
        id = "test_img",
        src = "test_images/sample.jpg",
        style = "max-width: 500px;",
        onload = "initImageMagnifier('test_img', 2.5, 200);"
      )
    )
  )
  
  server <- function(input, output, session) {
    # No server logic needed for basic test
  }
  
  shinyApp(ui, server)
}

# Run test
# test_magnifier()
