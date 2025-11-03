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
#' @param progress_callback Optional callback function(message, value) to report progress.
#'   Called at key stages with message (string) and value (0.0 to 1.0).
#' @param listing_type Listing type: "auction" or "fixed_price" (default: "fixed_price")
#' @param listing_duration Listing duration: "Days_3", "Days_5", "Days_7", "Days_10", or "GTC" (default: "GTC")
#' @param buy_it_now_price Buy It Now price for auctions (optional)
#' @param reserve_price Reserve price for auctions (optional)
#' @param is_stamp Boolean indicating if this is a stamp or postcard (default: FALSE)
#' @param category_id Numeric eBay category ID (required for stamps, optional for postcards)
#' @param sku_prefix SKU prefix to use: "PC" for postcards, "STAMP" for stamps (default: "PC")
#'
#' @export
create_ebay_listing_from_card <- function(card_id, ai_data, ebay_api, session_id,
                                          image_url = NULL, ebay_user_id = NULL, ebay_username = NULL,
                                          progress_callback = NULL, listing_type = "fixed_price",
                                          listing_duration = "GTC", buy_it_now_price = NULL,
                                          reserve_price = NULL, schedule_time_utc = NULL,
                                          is_stamp = FALSE, category_id = NULL, sku_prefix = "PC") {

  cat("\n=== CREATING EBAY LISTING (Trading API) ===\n")
  cat("   Card ID:", card_id, "\n")
  cat("   Session:", session_id, "\n")
  cat("   eBay User:", ebay_username %||% "None", "\n")
  cat("   Listing Type:", listing_type, "\n")
  if (listing_type == "auction") {
    cat("   Duration:", listing_duration, "\n")
    if (!is.null(buy_it_now_price)) cat("   Buy It Now:", buy_it_now_price, "\n")
    if (!is.null(reserve_price)) cat("   Reserve:", reserve_price, "\n")
  }

  # Step 1: Validate required fields
  cat("\n1. Validating required fields...\n")
  if (!is.null(progress_callback)) progress_callback("Validating data...", 0.1)

  validation <- validate_required_fields(ai_data, image_url)
  if (!validation$valid) {
    cat("   \u274c Validation failed:", validation$message, "\n")
    return(list(success = FALSE, error = validation$message))
  }
  cat("   \u2705 All required fields present\n")

  # Step 2: Upload image (try Imgur first, fallback to eBay)
  if (is.null(image_url)) {
    image_url <- "https://via.placeholder.com/500x350.png?text=Postcard"
    cat("   Using placeholder image\n")
  } else if (file.exists(image_url)) {
    cat("\n2. Uploading image...\n")
    cat("   Local path:", image_url, "\n")
    if (!is.null(progress_callback)) progress_callback("Uploading image...", 0.3)

    # Try imgbb first (fast, reliable, simple API)
    imgbb_result <- upload_to_imgbb(image_url)

    if (imgbb_result$success) {
      image_url <- imgbb_result$url
      cat("   \u2705 Image uploaded to imgbb:", image_url, "\n")
    } else {
      # Fallback to eBay Picture Services
      cat("   \u26a0\ufe0f imgbb failed, trying eBay Picture Services...\n")
      upload_result <- ebay_api$trading$upload_image(image_url)

      if (!upload_result$success) {
        cat("   \u274c Both uploads failed\n")
        cat("   \u26a0\ufe0f Using placeholder\n")
        image_url <- "https://via.placeholder.com/500x350.png?text=Upload+Failed"
      } else {
        image_url <- upload_result$image_url
        cat("   \u2705 Image uploaded to EPS:", image_url, "\n")
      }
    }
  }

  # Step 3: Get account registration country
  cat("\n3. Detecting account country...\n")
  if (!is.null(progress_callback)) progress_callback("Detecting account location...", 0.5)

  reg_result <- ebay_api$inventory$get_registration_address()

  country <- "RO"  # Default Romania
  location_text <- "Bucharest, Romania"

  if (reg_result$success && !is.null(reg_result$country)) {
    country <- reg_result$country
    location_text <- reg_result$city %||% country
    cat("   \u2705 Account registered in:", country, "\n")
  } else {
    cat("   \u26a0\ufe0f Could not detect country, using default: RO\n")
  }

  # Validate schedule time if provided
  if (!is.null(schedule_time_utc)) {
    validation <- validate_schedule_time(schedule_time_utc)
    if (!validation$valid) {
      cat("   \u274c Schedule time validation failed:", validation$error, "\n")
      return(list(
        success = FALSE,
        error = validation$error
      ))
    }
  }

  # Step 4: Build Trading API item data
  cat("\n4. Building Trading API request...\n")
  if (!is.null(progress_callback)) progress_callback("Preparing listing data...", 0.7)

  # Generate SKU with correct prefix
  sku <- generate_sku(card_id, prefix = sku_prefix)
  cat("   SKU:", sku, "\n")

  # Determine category: stamps need user-selected category, postcards use 262042
  if (is_stamp) {
    # Category ID passed from UI (user-selected via dropdown)
    # Validation already done in mod_stamp_export.R
    # category_id parameter MUST be provided for stamps
    if (is.null(category_id) || is.na(category_id)) {
      stop("category_id is required for stamp listings")
    }
    cat("   Category:", category_id, "(from user selection)\n")
  } else {
    category_id <- 262042  # Topographical Postcards - LEAF category
    cat("   Category: Topographical Postcards (262042)\n")
  }

  item_data <- build_trading_item_data(
    card_id = card_id,
    ai_data = ai_data,
    image_url = image_url,
    country = country,
    location = location_text,
    category_id = category_id,
    is_stamp = is_stamp
  )

  # Add scheduling if requested
  if (!is.null(schedule_time_utc)) {
    item_data$schedule_time <- format_ebay_schedule_time(schedule_time_utc)
    cat("   Scheduled for:", format_display_time(schedule_time_utc), "\n")
  }

  # Add auction-specific fields if listing_type is auction
  if (listing_type == "auction") {
    item_data$listing_type <- "auction"
    item_data$listing_duration <- listing_duration
    item_data$start_price <- ai_data$price  # Starting bid
    item_data$buy_it_now_price <- buy_it_now_price
    item_data$reserve_price <- reserve_price

    cat("   Title:", item_data$title, "\n")
    cat("   Country:", item_data$country, "\n")
    cat("   Starting Bid:", item_data$start_price, "USD\n")
    cat("   Duration:", item_data$listing_duration, "\n")
  } else {
    item_data$listing_type <- "fixed_price"
    item_data$listing_duration <- "GTC"

    cat("   Title:", item_data$title, "\n")
    cat("   Country:", item_data$country, "\n")
    cat("   Price:", item_data$price, "USD\n")
  }

  # Step 5: Create listing via Trading API (route based on listing type)
  cat("\n5. Creating listing via Trading API...\n")
  if (!is.null(progress_callback)) progress_callback("Creating eBay listing...", 0.8)

  if (listing_type == "auction") {
    result <- ebay_api$trading$add_auction_item(item_data)
  } else {
    result <- ebay_api$trading$add_fixed_price_item(item_data)
  }

  if (!result$success) {
    cat("   \u274c Trading API failed:", result$error, "\n")
    return(list(success = FALSE, error = result$error))
  }

  cat("   \u2705 Listing created!\n")
  cat("   Item ID:", result$item_id, "\n")

  # Step 6: Save to database
  cat("\n6. Saving to database...\n")
  if (!is.null(progress_callback)) progress_callback("Saving to database...", 0.95)

  save_success <- save_ebay_listing(
    card_id = card_id,
    session_id = session_id,
    ebay_item_id = result$item_id,
    ebay_offer_id = NA,  # Trading API doesn't use offers
    sku = sku,
    status = "listed",
    title = item_data$title,
    description = ai_data$description,
    price = ai_data$price,
    condition = ai_data$condition,
    aspects = item_data$aspects,
    environment = ebay_api$config$environment,
    ebay_user_id = ebay_user_id,
    ebay_username = ebay_username,
    api_type = "trading",  # Trading API
    listing_type = listing_type,  # Auction or fixed_price
    listing_duration = listing_duration,  # Duration
    buy_it_now_price = buy_it_now_price,  # Buy It Now (optional)
    reserve_price = reserve_price,  # Reserve (optional)
    schedule_time = schedule_time_utc,  # Scheduled start time (optional)
    is_scheduled = !is.null(schedule_time_utc),  # Boolean flag
    actual_start_time = if (!is.null(result$start_time)) {  # eBay's returned StartTime
      as.POSIXct(result$start_time, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
    } else NULL
  )

  if (!save_success) {
    cat("   \u26a0\ufe0f Database save failed (non-fatal)\n")
  } else {
    cat("   \u2705 Database record created\n")
  }

  # Build listing URL
  listing_url <- if (ebay_api$config$environment == "sandbox") {
    paste0("https://sandbox.ebay.com/itm/", result$item_id)
  } else {
    paste0("https://www.ebay.com/itm/", result$item_id)
  }

  cat("\n=== LISTING CREATED SUCCESSFULLY ===\n")
  cat("   URL:", listing_url, "\n\n")

  if (!is.null(progress_callback)) progress_callback("Complete!", 1.0)

  return(list(
    success = TRUE,
    item_id = result$item_id,
    sku = sku,
    listing_url = listing_url,
    api_type = "trading"
  ))
}

# ==== OLD INVENTORY API CODE - ARCHIVED ====
# See backup: C:/Users/mariu/Documents/R_Projects/Delcampe_BACKUP/ebay_integration_INVENTORY_API_20251028.R
# Inventory API 3-step process (inventory item -> offer -> publish) cannot work for cross-border sellers
# Error 25002: No Item.Country field available in Inventory API
