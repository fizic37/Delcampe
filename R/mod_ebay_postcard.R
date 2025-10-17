# eBay Postcard Listing Module
# This module handles creating postcard listings on eBay

#' eBay Postcard Listing UI Module
#' @export
mod_ebay_postcard_ui <- function(id) {
  ns <- NS(id)
  
  tagList(
    div(
      class = "ebay-postcard-container",
      h3("Create eBay Postcard Listing"),
      
      fluidRow(
        # Left column - Basic Information
        column(
          width = 6,
          wellPanel(
            h4("Basic Information"),
            textInput(
              ns("sku"),
              "SKU (Stock Keeping Unit)",
              placeholder = "e.g., PC-001"
            ),
            textInput(
              ns("title"),
              "Title",
              placeholder = "e.g., Vintage Paris Eiffel Tower Postcard 1950s"
            ),
            textAreaInput(
              ns("description"),
              "Description",
              rows = 5,
              placeholder = "Describe your postcard in detail..."
            ),
            numericInput(
              ns("price"),
              "Price (USD)",
              value = 9.99,
              min = 0.01,
              step = 0.01
            ),
            numericInput(
              ns("quantity"),
              "Quantity",
              value = 1,
              min = 1,
              step = 1
            )
          )
        ),
        
        # Right column - Postcard Details
        column(
          width = 6,
          wellPanel(
            h4("Postcard Details"),
            selectInput(
              ns("condition"),
              "Condition",
              choices = list(
                "New" = "NEW",
                "Like New" = "LIKE_NEW",
                "Used - Excellent" = "USED_EXCELLENT",
                "Used - Very Good" = "USED_VERY_GOOD",
                "Used - Good" = "USED_GOOD",
                "Used - Acceptable" = "USED_ACCEPTABLE"
              ),
              selected = "USED_EXCELLENT"
            ),
            
            # Postcard specific attributes
            selectInput(
              ns("era"),
              "Era",
              choices = list(
                "Pre-1900" = "Pre-1900",
                "1900-1919" = "1900-1919",
                "1920-1939" = "1920-1939",
                "1940-1959" = "1940-1959",
                "1960-1979" = "1960-1979",
                "1980-Present" = "1980-Present",
                "Unknown" = "Unknown"
              ),
              selected = "Unknown"
            ),
            
            selectInput(
              ns("theme"),
              "Theme",
              choices = list(
                "Travel" = "Travel",
                "Cities & Towns" = "Cities & Towns",
                "Famous Places" = "Famous Places",
                "Greetings" = "Greetings",
                "Holiday" = "Holiday",
                "Art" = "Art",
                "Military" = "Military",
                "Transportation" = "Transportation",
                "Animals" = "Animals",
                "Nature" = "Nature",
                "Other" = "Other"
              ),
              selected = "Travel"
            ),
            
            textInput(
              ns("country"),
              "Country/Region of Manufacture",
              placeholder = "e.g., France, USA, Unknown"
            ),
            
            checkboxInput(
              ns("is_original"),
              "Original (not reprint)",
              value = TRUE
            ),
            
            checkboxInput(
              ns("is_posted"),
              "Has been posted/Used",
              value = FALSE
            )
          ),
          
          # Image upload section
          wellPanel(
            h4("Images"),
            fileInput(
              ns("images"),
              "Upload Images",
              multiple = TRUE,
              accept = c("image/png", "image/jpeg", "image/jpg")
            ),
            tags$small("Upload up to 12 images. First image will be the main image."),
            uiOutput(ns("image_preview"))
          )
        )
      ),
      
      # Listing Policies
      wellPanel(
        h4("Listing Policies"),
        p("Leave blank to use default policies or enter your policy IDs from eBay Seller Hub:"),
        fluidRow(
          column(
            4,
            textInput(
              ns("fulfillment_policy"),
              "Fulfillment Policy ID",
              value = Sys.getenv("EBAY_FULFILLMENT_POLICY_ID", "")
            )
          ),
          column(
            4,
            textInput(
              ns("payment_policy"),
              "Payment Policy ID",
              value = Sys.getenv("EBAY_PAYMENT_POLICY_ID", "")
            )
          ),
          column(
            4,
            textInput(
              ns("return_policy"),
              "Return Policy ID",
              value = Sys.getenv("EBAY_RETURN_POLICY_ID", "")
            )
          )
        )
      ),
      
      # Action buttons
      div(
        class = "listing-actions",
        actionButton(
          ns("preview_listing"),
          "Preview",
          icon = icon("eye"),
          class = "btn-info btn-lg"
        ),
        actionButton(
          ns("save_draft"),
          "Save Draft",
          icon = icon("save"),
          class = "btn-secondary btn-lg"
        ),
        actionButton(
          ns("create_listing"),
          "Create Listing",
          icon = icon("upload"),
          class = "btn-success btn-lg"
        )
      ),
      
      # Status output
      br(),
      uiOutput(ns("listing_status"))
    )
  )
}

#' eBay Postcard Listing Server Module
#' @export
mod_ebay_postcard_server <- function(id, ebay_api) {
  moduleServer(id, function(input, output, session) {
    
    # Store uploaded images
    uploaded_images <- reactiveVal(list())
    
    # Handle image upload and preview
    observeEvent(input$images, {
      req(input$images)
      
      # Process uploaded images
      image_list <- list()
      for (i in 1:nrow(input$images)) {
        # Read and encode image
        img_data <- base64enc::base64encode(input$images$datapath[i])
        
        image_list[[i]] <- list(
          name = input$images$name[i],
          path = input$images$datapath[i],
          data = img_data,
          size = input$images$size[i]
        )
      }
      
      uploaded_images(image_list)
      
      # Display image previews
      output$image_preview <- renderUI({
        if (length(image_list) > 0) {
          tags$div(
            class = "image-preview-container",
            style = "display: flex; flex-wrap: wrap; gap: 10px;",
            lapply(1:length(image_list), function(i) {
              tags$div(
                class = "image-preview",
                style = "text-align: center;",
                tags$img(
                  src = paste0("data:image/jpeg;base64,", image_list[[i]]$data),
                  style = "max-width: 100px; max-height: 100px; border: 1px solid #ddd; padding: 2px;",
                  title = image_list[[i]]$name
                ),
                tags$br(),
                tags$small(image_list[[i]]$name)
              )
            })
          )
        }
      })
    })
    
    # Preview listing
    observeEvent(input$preview_listing, {
      showModal(
        modalDialog(
          title = "Listing Preview",
          size = "l",
          div(
            h4(input$title %||% "No title"),
            hr(),
            p(strong("Price:"), sprintf("$%.2f", input$price)),
            p(strong("Quantity:"), input$quantity),
            p(strong("Condition:"), input$condition),
            p(strong("SKU:"), input$sku %||% "Not set"),
            hr(),
            h5("Description:"),
            p(input$description %||% "No description"),
            hr(),
            h5("Attributes:"),
            tags$ul(
              tags$li(paste("Era:", input$era)),
              tags$li(paste("Theme:", input$theme)),
              tags$li(paste("Original:", ifelse(input$is_original, "Yes", "No"))),
              tags$li(paste("Posted/Used:", ifelse(input$is_posted, "Yes", "No"))),
              tags$li(paste("Country:", input$country %||% "Unknown"))
            ),
            if (length(uploaded_images()) > 0) {
              div(
                h5("Images:"),
                paste(length(uploaded_images()), "image(s) uploaded")
              )
            }
          ),
          footer = modalButton("Close")
        )
      )
    })
    
    # Save draft
    observeEvent(input$save_draft, {
      # Create draft data
      draft_data <- list(
        sku = input$sku,
        title = input$title,
        description = input$description,
        price = input$price,
        quantity = input$quantity,
        condition = input$condition,
        era = input$era,
        theme = input$theme,
        country = input$country,
        is_original = input$is_original,
        is_posted = input$is_posted,
        images = uploaded_images(),
        timestamp = Sys.time()
      )
      
      # Ensure data directory exists
      if (!dir.exists("data/drafts")) {
        dir.create("data/drafts", recursive = TRUE)
      }
      
      # Save draft
      filename <- paste0(
        "draft_",
        gsub("[^A-Za-z0-9]", "_", input$sku %||% "no_sku"),
        "_",
        format(Sys.time(), "%Y%m%d_%H%M%S"),
        ".rds"
      )
      
      saveRDS(draft_data, file = file.path("data", "drafts", filename))
      
      showNotification(
        "Draft saved successfully!",
        type = "success"
      )
    })
    
    # Create listing on eBay
    observeEvent(input$create_listing, {
      # Validate required fields
      if (is.null(input$sku) || input$sku == "") {
        showNotification("SKU is required", type = "error")
        return()
      }
      
      if (is.null(input$title) || input$title == "") {
        showNotification("Title is required", type = "error")
        return()
      }
      
      if (input$price <= 0) {
        showNotification("Price must be greater than 0", type = "error")
        return()
      }
      
      # Check eBay connection
      api <- ebay_api()
      if (is.null(api) || !api$oauth$is_authenticated()) {
        showNotification(
          "Please connect to eBay API first",
          type = "error"
        )
        return()
      }
      
      # Show progress
      withProgress(message = "Creating eBay listing...", value = 0, {
        
        incProgress(0.2, detail = "Preparing listing data...")
        
        # Prepare aspects (postcard-specific attributes)
        aspects <- list(
          "Type" = list("Postcard"),
          "Era" = list(input$era),
          "Theme" = list(input$theme),
          "Original/Licensed Reprint" = list(
            ifelse(input$is_original, "Original", "Licensed Reprint")
          ),
          "Posted/Unposted" = list(
            ifelse(input$is_posted, "Posted", "Unposted")
          )
        )
        
        if (!is.null(input$country) && input$country != "") {
          aspects[["Country/Region of Manufacture"]] <- list(input$country)
        }
        
        incProgress(0.4, detail = "Uploading images...")
        
        # TODO: Upload images to eBay Picture Services
        # For now, using empty list
        image_urls <- list()
        
        incProgress(0.6, detail = "Creating listing...")
        
        # Prepare listing policies
        listing_policies <- list()
        if (!is.null(input$fulfillment_policy) && input$fulfillment_policy != "") {
          listing_policies$fulfillmentPolicyId <- input$fulfillment_policy
        }
        if (!is.null(input$payment_policy) && input$payment_policy != "") {
          listing_policies$paymentPolicyId <- input$payment_policy
        }
        if (!is.null(input$return_policy) && input$return_policy != "") {
          listing_policies$returnPolicyId <- input$return_policy
        }
        
        # Create listing
        result <- api$inventory$create_postcard_listing(
          sku = input$sku,
          title = input$title,
          description = input$description %||% "",
          price = input$price,
          quantity = input$quantity,
          image_urls = image_urls,
          condition = input$condition,
          aspects = aspects,
          listing_policies = listing_policies
        )
        
        incProgress(1, detail = "Complete!")
        
        # Show result
        if (result$success) {
          output$listing_status <- renderUI({
            div(
              class = "alert alert-success",
              h4("Listing Created Successfully!"),
              p(paste("Offer ID:", result$offer_id)),
              if (!is.null(result$listing_id)) {
                tagList(
                  p(paste("Listing ID:", result$listing_id)),
                  a(
                    href = paste0(
                      ifelse(api$config$environment == "sandbox",
                             "https://sandbox.ebay.com/itm/",
                             "https://www.ebay.com/itm/"),
                      result$listing_id
                    ),
                    target = "_blank",
                    class = "btn btn-primary",
                    "View Listing on eBay"
                  )
                )
              }
            )
          })
          
          showNotification(
            "Listing created successfully!",
            type = "success",
            duration = 10
          )
          
        } else {
          output$listing_status <- renderUI({
            div(
              class = "alert alert-danger",
              h4("Error Creating Listing"),
              p(result$error)
            )
          })
          
          showNotification(
            paste("Error:", result$error),
            type = "error",
            duration = NULL
          )
        }
      })
    })
    
  })
}
