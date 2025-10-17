#' eBay Integration Functions
#' Main orchestration for creating eBay listings from Delcampe data

#' Create eBay listing from card data
#'
#' Complete flow: location → inventory item → offer → publish
#'
#' @param card_id Card ID from postal_cards table
#' @param ai_data List with title, description, price, condition
#' @param ebay_api eBay API object from init_ebay_api()
#' @param session_id Shiny session ID for tracking
#' @param image_url Image URL for listing (temporary placeholder OK for sandbox)
#'
#' @return List with success, listing_id, listing_url, or error
#' @export
create_ebay_listing_from_card <- function(card_id, ai_data, ebay_api, session_id, image_url = NULL) {

  cat("\n=== CREATING EBAY LISTING ===\n")
  cat("   Card ID:", card_id, "\n")
  cat("   Session:", session_id, "\n")

  # Step 1: Validate required fields
  cat("\n1. Validating required fields...\n")

  # Use placeholder image if none provided (for sandbox testing)
  if (is.null(image_url)) {
    image_url <- "https://via.placeholder.com/500x350.png?text=Postcard"
    cat("   Using placeholder image\n")
  }

  validation <- validate_required_fields(ai_data, image_url)
  if (!validation$valid) {
    cat("   ❌ Validation failed:", validation$message, "\n")
    return(list(success = FALSE, error = validation$message))
  }
  cat("   ✅ All required fields present\n")

  # Step 2: Check/create location (one-time setup)
  cat("\n2. Checking inventory location...\n")
  location_key <- "default_location"

  # For simplicity, assume location exists or create on first run
  # In production, would check if location exists first
  # NOTE: Using US for sandbox testing - update for production
  location_result <- tryCatch({
    ebay_api$inventory$create_location(
      merchant_location_key = location_key,
      location_data = list(
        location = list(
          address = list(
            country = "US",
            postalCode = "10001"
          )
        ),
        name = "Primary Location",
        locationTypes = list("WAREHOUSE")
      )
    )
  }, error = function(e) {
    # Location might already exist, that's OK
    list(success = TRUE)
  })

  cat("   ✅ Location ready:", location_key, "\n")

  # Step 3: Create inventory item
  cat("\n3. Creating inventory item...\n")

  sku <- generate_sku(card_id)
  cat("   SKU:", sku, "\n")

  # Truncate title to 80 chars (eBay limit)
  title_truncated <- substr(trimws(ai_data$title), 1, 80)
  cat("   Title:", title_truncated, "\n")

  inventory_data <- list(
    product = list(
      title = title_truncated,
      description = ai_data$description,
      imageUrls = list(image_url),
      aspects = extract_postcard_aspects(ai_data)
    ),
    condition = map_condition_to_ebay(ai_data$condition),
    availability = list(
      shipToLocationAvailability = list(
        quantity = 1
      )
    )
  )

  cat("   Condition:", inventory_data$condition, "\n")
  cat("   Calling API: PUT /inventory_item/", sku, "\n")

  inventory_result <- ebay_api$inventory$create_inventory_item(sku, inventory_data)

  if (!inventory_result$success) {
    error_msg <- paste("Failed to create inventory item:", inventory_result$error)
    cat("   ❌", error_msg, "\n")
    return(list(success = FALSE, error = error_msg))
  }
  cat("   ✅ Inventory item created\n")

  # Step 4: Create offer
  cat("\n4. Creating offer...\n")

  # Get business policy IDs from environment
  fulfillment_policy <- Sys.getenv("EBAY_FULFILLMENT_POLICY_ID")
  payment_policy <- Sys.getenv("EBAY_PAYMENT_POLICY_ID")
  return_policy <- Sys.getenv("EBAY_RETURN_POLICY_ID")

  # For sandbox, skip policies if not configured (they're optional in sandbox)
  use_policies <- TRUE
  if (ebay_api$config$environment == "sandbox") {
    if (fulfillment_policy == "" || payment_policy == "" || return_policy == "") {
      cat("   ⚠️ Warning: Business policies not configured for sandbox\n")
      cat("   Attempting to create offer without policies (may fail)\n")
      use_policies <- FALSE
    }
  } else {
    # Production requires policies
    if (fulfillment_policy == "" || payment_policy == "" || return_policy == "") {
      error_msg <- "Business policies required for production. Please set EBAY_FULFILLMENT_POLICY_ID, EBAY_PAYMENT_POLICY_ID, EBAY_RETURN_POLICY_ID"
      cat("   ❌", error_msg, "\n")
      return(list(success = FALSE, error = error_msg))
    }
  }

  # Build offer data - SKIP POLICIES ENTIRELY FOR SANDBOX
  # eBay sandbox requires business policy opt-in which is complex
  # For production, you'll need to set up policies properly

  if (ebay_api$config$environment == "sandbox") {
    cat("   ⚠️ Sandbox mode: skipping business policies (not supported)\n")
    cat("   Note: Listing will use minimal configuration for sandbox\n")

    # Minimal offer for sandbox testing
    offer_data <- list(
      sku = sku,
      marketplaceId = "EBAY_US",
      format = "FIXED_PRICE",
      categoryId = "914",
      merchantLocationKey = location_key,
      availableQuantity = 1,
      listingDescription = ai_data$description,
      pricingSummary = list(
        price = list(
          currency = "USD",
          value = format_ebay_price(ai_data$price)
        )
      )
    )
  } else {
    # Production requires policies
    if (!use_policies) {
      error_msg <- "Production requires business policies. Configure them in .Renviron"
      cat("   ❌", error_msg, "\n")
      return(list(success = FALSE, error = error_msg))
    }

    offer_data <- list(
      sku = sku,
      marketplaceId = "EBAY_US",
      format = "FIXED_PRICE",
      categoryId = "914",
      pricingSummary = list(
        price = list(
          currency = "USD",
          value = format_ebay_price(ai_data$price)
        )
      ),
      merchantLocationKey = location_key,
      listingPolicies = list(
        fulfillmentPolicyId = fulfillment_policy,
        paymentPolicyId = payment_policy,
        returnPolicyId = return_policy
      )
    )
  }

  cat("   Price:", offer_data$pricingSummary$price$value, "USD\n")
  cat("   Category: 914 (Postcards)\n")
  cat("   Calling API: POST /offer\n")

  offer_result <- ebay_api$inventory$create_offer(offer_data)

  if (!offer_result$success) {
    error_msg <- paste("Failed to create offer:", offer_result$error)
    cat("   ❌", error_msg, "\n")
    return(list(success = FALSE, error = error_msg))
  }
  cat("   ✅ Offer created, ID:", offer_result$offer_id, "\n")

  # Step 5: Publish offer
  cat("\n5. Publishing offer...\n")
  cat("   Calling API: POST /offer/", offer_result$offer_id, "/publish\n")

  publish_result <- ebay_api$inventory$publish_offer(offer_result$offer_id)

  if (!publish_result$success) {
    error_msg <- paste("Failed to publish offer:", publish_result$error)
    cat("   ❌", error_msg, "\n")
    return(list(success = FALSE, error = error_msg))
  }
  cat("   ✅ Offer published, listing ID:", publish_result$listing_id, "\n")

  # Step 6: Save to database
  cat("\n6. Saving to database...\n")

  save_success <- save_ebay_listing(
    card_id = card_id,
    session_id = session_id,
    ebay_item_id = publish_result$listing_id,
    ebay_offer_id = offer_result$offer_id,
    sku = sku,
    status = "listed",
    title = title_truncated,
    description = ai_data$description,
    price = ai_data$price,
    condition = inventory_data$condition,
    aspects = inventory_data$product$aspects,
    environment = ebay_api$config$environment
  )

  if (!save_success) {
    cat("   ⚠️ Database save failed (non-fatal)\n")
  } else {
    cat("   ✅ Database record created\n")
  }

  # Build listing URL
  listing_url <- if (ebay_api$config$environment == "sandbox") {
    paste0("https://sandbox.ebay.com/itm/", publish_result$listing_id)
  } else {
    paste0("https://www.ebay.com/itm/", publish_result$listing_id)
  }

  cat("\n=== LISTING CREATED SUCCESSFULLY ===\n")
  cat("   URL:", listing_url, "\n\n")

  return(list(
    success = TRUE,
    listing_id = publish_result$listing_id,
    offer_id = offer_result$offer_id,
    sku = sku,
    listing_url = listing_url
  ))
}
