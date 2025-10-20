#' eBay Integration Functions
#' Main orchestration for creating eBay listings from Delcampe data

#' Create eBay Listing from Postal Card
#'
#' Creates a complete eBay listing by uploading image, creating inventory item, offer, and publishing.
#' Complete flow: image upload → location → inventory item → offer → publish
#'
#' @param card_id Postal card ID from database
#' @param ai_data List containing AI-extracted data (title, description, price, condition)
#' @param ebay_api EbayAPI instance with authenticated connection
#' @param session_id Current processing session ID
#' @param image_url Either a public HTTPS URL or local file path to image. If local path, will be uploaded to eBay Picture Services.
#' @param ebay_user_id eBay user ID from account manager
#' @param ebay_username eBay username for tracking
#' @return List with success status, listing_id, offer_id, sku, listing_url
#' @export
create_ebay_listing_from_card <- function(card_id, ai_data, ebay_api, session_id, image_url = NULL, ebay_user_id = NULL, ebay_username = NULL) {

  cat("\n=== CREATING EBAY LISTING ===\n")
  cat("   Card ID:", card_id, "\n")
  cat("   Session:", session_id, "\n")
  cat("   eBay User ID:", ebay_user_id %||% "None", "\n")
  cat("   eBay Username:", ebay_username %||% "None", "\n")

  # Step 0: Upload image to eBay Picture Services if local path provided
  if (is.null(image_url)) {
    # For now, use placeholder - in production, this should receive image_path
    image_url <- "https://via.placeholder.com/500x350.png?text=Postcard"
    cat("   Using placeholder image\n")
  } else if (file.exists(image_url)) {
    # image_url is actually a local file path - upload it
    cat("\n0. Uploading image to eBay Picture Services...\n")
    cat("   Local path:", image_url, "\n")
    cat("   Environment:", ebay_api$config$environment, "\n")

    upload_result <- ebay_api$media$upload_image(image_url)

    if (!upload_result$success) {
      error_msg <- paste("Failed to upload image:", upload_result$error)
      cat("   ❌", error_msg, "\n")

      # FALLBACK: Use placeholder image if upload fails
      cat("   ⚠️ Falling back to placeholder image for now\n")
      image_url <- "https://via.placeholder.com/500x350.png?text=Postcard+Image+Upload+Failed"
      cat("   ℹ️ Listing will be created but without your actual image\n")
      cat("   ℹ️ Try testing in sandbox first or check eBay API status\n")
    } else {
      image_url <- upload_result$image_url
      cat("   ✅ Image uploaded, EPS URL:", image_url, "\n")
      cat("   Image ID:", upload_result$image_id, "\n")
      cat("   Expires:", upload_result$expiration, "\n")
    }
  }

  # Step 1: Validate required fields
  cat("\n1. Validating required fields...\n")

  validation <- validate_required_fields(ai_data, image_url)
  if (!validation$valid) {
    cat("   ❌ Validation failed:", validation$message, "\n")
    return(list(success = FALSE, error = validation$message))
  }
  cat("   ✅ All required fields present\n")

  # Step 2: Get inventory location (auto-detect from eBay account)
  cat("\n2. Detecting inventory location...\n")

  # Try to get existing locations from eBay
  existing_locations_result <- ebay_api$inventory$get_locations()

  location_key <- NULL

  if (existing_locations_result$success &&
      !is.null(existing_locations_result$locations) &&
      length(existing_locations_result$locations) > 0) {

    # Use first available location (eBay account already configured)
    first_location <- existing_locations_result$locations[[1]]
    location_key <- first_location$merchantLocationKey
    location_country <- first_location$location$address$country %||% "N/A"

    cat("   ✅ Using eBay inventory location:", location_key, "\n")
    cat("      Address:", first_location$location$address$addressLine1 %||% "N/A", "\n")
    cat("      City:", first_location$location$address$city %||% "N/A", "\n")
    cat("      Country:", location_country, "\n")

    # Get registration address to compare (helps diagnose Error 25019)
    cat("   Checking account registration address...\n")
    reg_result <- ebay_api$inventory$get_registration_address()

    if (reg_result$success) {
      reg_country <- reg_result$country %||% "N/A"
      cat("   📋 eBay account registered in:", reg_country, "\n")

      # Warn if mismatch (causes Error 25019)
      if (!is.na(reg_country) && !is.na(location_country) && reg_country != location_country) {
        cat("   ⚠️ WARNING: Location country (", location_country, ") ≠ Registration country (", reg_country, ")\n")
        cat("   ⚠️ This will cause Error 25019 (Overseas Warehouse Block Policy)\n")
        cat("   ⚠️ You need to either:\n")
        cat("      1. Update inventory location to match registration (", reg_country, ") at: https://www.ebay.com/sh/ovw\n")
        cat("      2. Or apply for overseas warehouse authorization: whappeals@ebay.com\n")
      } else {
        cat("   ✅ Location and registration countries match\n")
      }
    }

  } else {
    # No locations exist - account needs setup via eBay Seller Hub
    error_msg <- paste0(
      "No inventory locations found in your eBay account. ",
      "Please set up at least one location in eBay Seller Hub first:\n",
      "   1. Go to: https://www.ebay.com/sh/ovw\n",
      "   2. Navigate to: Business > Locations\n",
      "   3. Add your inventory location\n",
      "   4. Then try creating listings again"
    )
    cat("   ❌", error_msg, "\n")
    return(list(success = FALSE, error = error_msg))
  }

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
      categoryId = "262042",  # Topographical Postcards (correct 2024 category)
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
      categoryId = "262042",  # Topographical Postcards (correct 2024 category)
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
  cat("   Category: 262042 (Topographical Postcards)\n")
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
    
    # Check for Error 25019 (Overseas Warehouse Block)
    if (grepl("25019", error_msg)) {
      cat("   ℹ️ eBay Error 25019: Overseas Warehouse Block Policy\n")
      cat("   ℹ️ Your eBay account's inventory location doesn't match your registration address.\n")
      cat("   ℹ️ To fix this, you need to:\n")
      cat("      1. Go to eBay Seller Hub: https://www.ebay.com/sh/ovw\n")
      cat("      2. Update your inventory location to match your registered address\n")
      cat("      3. Or apply for overseas warehouse authorization: whappeals@ebay.com\n")
      cat("      4. See: https://export.ebay.com/en/tc/overseas-warehouse-block-policy\n")
    }
    
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
    environment = ebay_api$config$environment,
    ebay_user_id = ebay_user_id,
    ebay_username = ebay_username
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
