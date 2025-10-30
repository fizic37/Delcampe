#' eBay Trading API Client
#'
#' R6 class for interacting with eBay Trading API (XML-based, legacy but fully supported)
#' Used for cross-border listings where Inventory API fails to support Item.Country field
#'
#' @description
#' The Trading API is required for Romania-based sellers listing on US marketplace
#' because the Inventory API provides no way to specify the country of origin.
#'
#' This client automatically fetches and uses your existing eBay business policies
#' (shipping, payment, return) from your account via SellerProfiles element.
#'
#' See memory: ebay_inventory_api_limitation_20251028.md
#'
#' @export
EbayTradingAPI <- R6::R6Class("EbayTradingAPI",
  public = list(
    #' @description Create new Trading API client
    #' @param oauth EbayOAuth instance (reuse existing)
    #' @param config EbayAPIConfig instance (reuse existing)
    initialize = function(oauth, config) {
      private$oauth <- oauth
      private$config <- config
    },

    #' @description Add fixed price listing (creates and publishes in one call)
    #' @param item_data List with: title, description, country, location, category_id, price, condition_id, quantity, images, aspects
    #' @return List with success, item_id, error
    add_fixed_price_item = function(item_data) {
      cat("\n=== Trading API: AddFixedPriceItem ===\n")
      cat("   Title:", item_data$title, "\n")
      cat("   Country:", item_data$country, "\n")

      # Build XML request
      xml_body <- private$build_add_item_xml(item_data)

      # Debug: Show token info (first/last 10 chars only for security)
      token <- private$oauth$get_access_token()
      if (!is.null(token) && nchar(token) > 20) {
        token_preview <- paste0(
          substr(token, 1, 10), "...",
          substr(token, nchar(token) - 9, nchar(token))
        )
        cat("   🔑 Token being used:", token_preview, "\n")

        # Check token expiry
        expiry <- private$oauth$get_token_expiry()
        if (!is.null(expiry)) {
          if (Sys.time() > expiry) {
            cat("   ⚠️ WARNING: Token expired at", format(expiry, "%Y-%m-%d %H:%M:%S"), "\n")
          } else {
            cat("   ✅ Token expires:", format(expiry, "%Y-%m-%d %H:%M:%S"), "\n")
          }
        }
      }

      # Debug: Save XML request to temp file
      debug_file <- tempfile(pattern = "ebay_trading_request_", fileext = ".xml")
      writeLines(xml_body, debug_file)
      cat("   📄 XML request saved to:", debug_file, "\n")

      cat("   Calling Trading API...\n")

      # Make request
      tryCatch({
        response <- private$make_request(xml_body, "AddFixedPriceItem")

        # Check HTTP status
        if (httr2::resp_is_error(response)) {
          return(list(
            success = FALSE,
            error = paste0("HTTP ", httr2::resp_status(response), ": ", httr2::resp_status_desc(response))
          ))
        }

        # Parse XML response
        xml_response <- httr2::resp_body_string(response)
        cat("   Response length:", nchar(xml_response), "characters\n")

        # Debug: Show first 500 chars of response
        if (nchar(xml_response) > 0) {
          cat("   Response preview:", substr(xml_response, 1, min(500, nchar(xml_response))), "\n")
        } else {
          cat("   ⚠️ Warning: Empty response body\n")
        }

        result <- private$parse_response(xml_response)

        if (result$success) {
          cat("   \u2705 Listing created via Trading API\n")
          cat("   Item ID:", result$item_id, "\n")
          if (!is.null(result$warnings)) {
            cat("   \u26a0\ufe0f Warnings:", paste(result$warnings, collapse = "; "), "\n")
          }
        } else {
          cat("   \u274c Trading API failed:", result$error, "\n")
        }

        return(result)

      }, error = function(e) {
        cat("   ⚠️ Exception caught:", e$message, "\n")
        cat("   Exception class:", class(e), "\n")
        if (!is.null(e$call)) {
          cat("   Exception call:", deparse(e$call), "\n")
        }
        return(list(
          success = FALSE,
          error = paste0("Exception: ", e$message)
        ))
      })
    },

    #' @description Upload image to eBay Picture Services (EPS) for Trading API
    #' @param image_path Local file path to image
    #' @return List with success, image_url, error
    upload_image = function(image_path) {
      cat("\n=== Trading API: UploadSiteHostedPictures ===\n")
      cat("   Image path:", image_path, "\n")

      if (!file.exists(image_path)) {
        return(list(success = FALSE, error = "Image file not found"))
      }

      tryCatch({
        # Read image as base64
        image_binary <- readBin(image_path, "raw", file.info(image_path)$size)
        image_base64 <- base64enc::base64encode(image_binary)

        # Build XML
        token <- private$oauth$get_access_token()
        xml_body <- paste0(
          '<?xml version="1.0" encoding="utf-8"?>',
          '<UploadSiteHostedPicturesRequest xmlns="urn:ebay:apis:eBLBaseComponents">',
          '<RequesterCredentials><eBayAuthToken>', token, '</eBayAuthToken></RequesterCredentials>',
          '<PictureData>', image_base64, '</PictureData>',
          '<PictureName>', basename(image_path), '</PictureName>',
          '</UploadSiteHostedPicturesRequest>'
        )

        cat("   Uploading to EPS...\n")

        # Make request
        response <- private$make_request(xml_body, "UploadSiteHostedPictures")

        if (httr2::resp_is_error(response)) {
          return(list(
            success = FALSE,
            error = paste0("HTTP ", httr2::resp_status(response))
          ))
        }

        # Parse response
        xml_response <- httr2::resp_body_string(response)
        doc <- xml2::read_xml(xml_response)

        ack <- xml2::xml_text(xml2::xml_find_first(doc, ".//*[local-name()='Ack']"))

        if (ack %in% c("Success", "Warning")) {
          # Parse FullURL - REQUIRED for gallery thumbnail generation per eBay docs
          full_url <- xml2::xml_text(xml2::xml_find_first(doc, ".//*[local-name()='FullURL']"))

          # Parse PictureSetMember URLs (for debugging only - NOT used for listing)
          picture_set <- xml2::xml_find_all(doc, ".//*[local-name()='PictureSetMember']")

          urls <- list()
          for (member in picture_set) {
            size <- xml2::xml_text(xml2::xml_find_first(member, ".//*[local-name()='PictureSize']"))
            url <- xml2::xml_text(xml2::xml_find_first(member, ".//*[local-name()='MemberURL']"))

            if (!is.na(size) && !is.na(url) && nchar(url) > 0) {
              urls[[size]] <- url
              cat("   Found PictureSetMember:", size, "->", substr(url, 1, 60), "...\n")
            }
          }

          # CRITICAL: Must use FullURL for gallery thumbnails to generate
          # Per eBay docs: "Using PictureSetMember URLs will result in gallery image not being generated"
          # FullURL format: ends with _1.JPG or _12.JPG
          image_url <- full_url

          cat("   ✅ Image uploaded to EPS\n")
          cat("   Using FullURL (required for gallery thumbnails)\n")
          cat("   URL:", image_url, "\n")
          if (length(urls) > 0) {
            cat("   Available sizes:", paste(names(urls), collapse=", "), "(not used)\n")
          }

          return(list(
            success = TRUE,
            image_url = image_url,
            all_urls = urls  # For debugging
          ))
        } else {
          # Extract error
          error_node <- xml2::xml_find_first(doc, ".//*[local-name()='Errors']")
          error_msg <- xml2::xml_text(xml2::xml_find_first(error_node, ".//*[local-name()='LongMessage']"))

          return(list(
            success = FALSE,
            error = error_msg
          ))
        }

      }, error = function(e) {
        return(list(
          success = FALSE,
          error = paste0("Upload exception: ", e$message)
        ))
      })
    },

    #' @description Verify listing without creating (optional validation)
    #' @param item_data Same structure as add_fixed_price_item
    #' @return List with success, errors/warnings
    verify_add_item = function(item_data) {
      cat("\n=== Trading API: VerifyAddFixedPriceItem ===\n")

      # Build XML request
      xml_body <- private$build_add_item_xml(item_data)

      cat("   Verifying item data...\n")

      # Make request
      tryCatch({
        response <- private$make_request(xml_body, "VerifyAddFixedPriceItem")

        # Check HTTP status
        if (httr2::resp_is_error(response)) {
          return(list(
            success = FALSE,
            error = paste0("HTTP ", httr2::resp_status(response))
          ))
        }

        # Parse XML response
        xml_response <- httr2::resp_body_string(response)
        result <- private$parse_response(xml_response)

        if (result$success) {
          cat("   \u2705 Verification passed\n")
        } else {
          cat("   \u274c Verification failed:", result$error, "\n")
        }

        return(result)

      }, error = function(e) {
        return(list(
          success = FALSE,
          error = paste0("Exception: ", e$message)
        ))
      })
    },

    #' @description Add auction listing (Chinese auction format)
    #' @param item_data List with: title, description, country, location, category_id, start_price, condition_id, quantity=1, images, aspects, listing_duration, buy_it_now_price (optional), reserve_price (optional)
    #' @return List with success, item_id, error
    add_auction_item = function(item_data) {
      cat("\n=== Trading API: AddItem (Auction) ===\n")
      cat("   Title:", item_data$title, "\n")
      cat("   Starting Bid:", item_data$start_price, "\n")
      cat("   Duration:", item_data$listing_duration, "\n")
      if (!is.null(item_data$buy_it_now_price)) {
        cat("   Buy It Now:", item_data$buy_it_now_price, "\n")
      }
      if (!is.null(item_data$reserve_price)) {
        cat("   Reserve Price:", item_data$reserve_price, "\n")
      }

      # Validate auction-specific requirements
      validation_result <- private$validate_auction_data(item_data)
      if (!validation_result$valid) {
        return(list(
          success = FALSE,
          error = validation_result$error
        ))
      }

      # Build XML request for auction
      xml_body <- private$build_auction_xml(item_data)

      # Debug: Show token info
      token <- private$oauth$get_access_token()
      if (!is.null(token) && nchar(token) > 20) {
        token_preview <- paste0(
          substr(token, 1, 10), "...",
          substr(token, nchar(token) - 9, nchar(token))
        )
        cat("   🔑 Token being used:", token_preview, "\n")
      }

      # Debug: Save XML request to temp file
      debug_file <- tempfile(pattern = "ebay_auction_request_", fileext = ".xml")
      writeLines(xml_body, debug_file)
      cat("   📄 XML request saved to:", debug_file, "\n")

      cat("   Calling Trading API (AddItem for auction)...\n")

      # Make request
      tryCatch({
        response <- private$make_request(xml_body, "AddItem")

        # Check HTTP status
        if (httr2::resp_is_error(response)) {
          return(list(
            success = FALSE,
            error = paste0("HTTP ", httr2::resp_status(response), ": ", httr2::resp_status_desc(response))
          ))
        }

        # Parse XML response
        xml_response <- httr2::resp_body_string(response)
        cat("   Response length:", nchar(xml_response), "characters\n")

        result <- private$parse_response(xml_response)

        if (result$success) {
          cat("   ✅ Auction listing created via Trading API\n")
          cat("   Item ID:", result$item_id, "\n")
          if (!is.null(result$warnings)) {
            cat("   ⚠️ Warnings:", paste(result$warnings, collapse = "; "), "\n")
          }
        } else {
          cat("   ❌ Trading API failed:", result$error, "\n")
        }

        return(result)

      }, error = function(e) {
        cat("   ⚠️ Exception caught:", e$message, "\n")
        return(list(
          success = FALSE,
          error = paste0("Exception: ", e$message)
        ))
      })
    }
  ),

  private = list(
    oauth = NULL,
    config = NULL,

    #' @description Get Trading API endpoint URL
    get_endpoint = function() {
      if (private$config$environment == "production") {
        "https://api.ebay.com/ws/api.dll"
      } else {
        "https://api.sandbox.ebay.com/ws/api.dll"
      }
    },

    #' @description Build AddFixedPriceItem XML request
    #' @param item_data Item data list
    #' @return XML string
    build_add_item_xml = function(item_data) {
      # Create root element
      doc <- xml2::xml_new_root(
        "AddFixedPriceItemRequest",
        xmlns = "urn:ebay:apis:eBLBaseComponents"
      )

      # NOTE: For OAuth2, token goes in X-EBAY-API-IAF-TOKEN header, NOT in XML body
      # RequesterCredentials is only for old Auth'n'Auth tokens

      # Add Item element
      item <- xml2::xml_add_child(doc, "Item")

      # CRITICAL: Add Country (this is why we need Trading API!)
      xml2::xml_add_child(item, "Country", item_data$country)
      xml2::xml_add_child(item, "Location", item_data$location)

      # Add currency (required by Trading API)
      xml2::xml_add_child(item, "Currency", "USD")

      # Add basic fields
      xml2::xml_add_child(item, "Title", item_data$title)

      # Add description (eBay accepts HTML in Description field)
      # Format description with basic HTML for better presentation
      formatted_description <- paste0(
        "<div style='font-family: Arial, sans-serif;'>",
        "<h2>", item_data$title, "</h2>",
        "<p>", gsub("\n", "<br>", item_data$description), "</p>",
        "</div>"
      )
      xml2::xml_add_child(item, "Description", formatted_description)

      # Add category
      primary_cat <- xml2::xml_add_child(item, "PrimaryCategory")
      xml2::xml_add_child(primary_cat, "CategoryID", as.character(item_data$category_id))

      # Add pricing
      price_node <- xml2::xml_add_child(item, "StartPrice", as.character(item_data$price))
      xml2::xml_set_attr(price_node, "currencyID", "USD")

      # Add condition
      xml2::xml_add_child(item, "ConditionID", as.character(item_data$condition_id))

      # Add quantity and duration
      xml2::xml_add_child(item, "Quantity", as.character(item_data$quantity))
      xml2::xml_add_child(item, "ListingDuration", "GTC")  # Good Till Cancelled

      # Add images
      if (!is.null(item_data$images) && length(item_data$images) > 0) {
        pic_details <- xml2::xml_add_child(item, "PictureDetails")
        for (img_url in item_data$images) {
          xml2::xml_add_child(pic_details, "PictureURL", img_url)
        }
      }

      # Add item specifics (aspects)
      if (!is.null(item_data$aspects) && length(item_data$aspects) > 0) {
        specifics <- xml2::xml_add_child(item, "ItemSpecifics")
        for (aspect_name in names(item_data$aspects)) {
          nvl <- xml2::xml_add_child(specifics, "NameValueList")
          xml2::xml_add_child(nvl, "Name", aspect_name)

          # Handle both single values and vectors
          aspect_values <- item_data$aspects[[aspect_name]]
          if (!is.list(aspect_values)) {
            aspect_values <- list(aspect_values)
          }

          for (val in aspect_values) {
            xml2::xml_add_child(nvl, "Value", as.character(val))
          }
        }
      }

      # Add business policies (uses seller's existing policies from eBay account)
      # This is preferred over hardcoding ShippingDetails/ReturnPolicy
      # Get policy IDs from account or fetch dynamically
      policy_ids <- private$get_business_policy_ids()

      # Only add SellerProfiles if we have at least one policy
      # Empty SellerProfiles element causes eBay to reject the listing
      has_policies <- !is.null(policy_ids$fulfillment_id) ||
                      !is.null(policy_ids$payment_id) ||
                      !is.null(policy_ids$return_id)

      if (has_policies) {
        seller_profiles <- xml2::xml_add_child(item, "SellerProfiles")

        if (!is.null(policy_ids$fulfillment_id)) {
          shipping_profile <- xml2::xml_add_child(seller_profiles, "SellerShippingProfile")
          xml2::xml_add_child(shipping_profile, "ShippingProfileID", policy_ids$fulfillment_id)
        }

        if (!is.null(policy_ids$payment_id)) {
          payment_profile <- xml2::xml_add_child(seller_profiles, "SellerPaymentProfile")
          xml2::xml_add_child(payment_profile, "PaymentProfileID", policy_ids$payment_id)
        }

        if (!is.null(policy_ids$return_id)) {
          return_profile <- xml2::xml_add_child(seller_profiles, "SellerReturnProfile")
          xml2::xml_add_child(return_profile, "ReturnProfileID", policy_ids$return_id)
        }
      } else {
        # Fallback: Add basic shipping and payment details
        cat("   No business policies found, using basic shipping/payment setup\n")

        # Add shipping details (required)
        shipping_details <- xml2::xml_add_child(item, "ShippingDetails")

        # Add a basic economy shipping service
        shipping_service <- xml2::xml_add_child(shipping_details, "ShippingServiceOptions")
        xml2::xml_add_child(shipping_service, "ShippingService", "USPSFirstClass")
        xml2::xml_add_child(shipping_service, "ShippingServicePriority", "1")
        shipping_cost <- xml2::xml_add_child(shipping_service, "ShippingServiceCost", "3.00")
        xml2::xml_set_attr(shipping_cost, "currencyID", "USD")

        # Add payment methods (required)
        xml2::xml_add_child(item, "PaymentMethods", "PayPal")
        xml2::xml_add_child(item, "PayPalEmailAddress", "your-paypal@example.com")

        # Add return policy (required)
        return_policy <- xml2::xml_add_child(item, "ReturnPolicy")
        xml2::xml_add_child(return_policy, "ReturnsAcceptedOption", "ReturnsAccepted")
        xml2::xml_add_child(return_policy, "RefundOption", "MoneyBack")
        xml2::xml_add_child(return_policy, "ReturnsWithinOption", "Days_30")
        xml2::xml_add_child(return_policy, "ShippingCostPaidByOption", "Buyer")
      }

      # Convert to string
      return(as.character(doc))
    },

    #' @description Make Trading API HTTP request
    #' @param xml_body XML request string
    #' @param call_name API call name
    #' @return httr2 response object
    make_request = function(xml_body, call_name) {
      endpoint <- private$get_endpoint()

      # Get OAuth2 token for IAF header
      token <- private$oauth$get_access_token()

      # Build request with Trading API headers
      # IMPORTANT: OAuth2 tokens MUST be in X-EBAY-API-IAF-TOKEN header, NOT in XML body
      req <- httr2::request(endpoint) |>
        httr2::req_headers(
          "X-EBAY-API-SITEID" = "0",  # 0 = US
          "X-EBAY-API-COMPATIBILITY-LEVEL" = "1355",  # Latest version
          "X-EBAY-API-CALL-NAME" = call_name,
          "X-EBAY-API-IAF-TOKEN" = token,  # OAuth2 token goes here!
          "Content-Type" = "text/xml"
        ) |>
        httr2::req_body_raw(xml_body, type = "text/xml")

      # Make POST request
      response <- httr2::req_perform(req)

      # Debug: Log response status
      cat("   HTTP Status:", httr2::resp_status(response), "\n")

      return(response)
    },

    #' @description Parse Trading API XML response
    #' @param xml_string XML response string
    #' @return List with success, item_id, errors
    parse_response = function(xml_string) {
      # Try to parse XML
      doc <- tryCatch({
        xml2::read_xml(xml_string)
      }, error = function(e) {
        cat("   ⚠️ XML parsing failed:", e$message, "\n")
        stop("Failed to parse XML response: ", e$message)
      })

      # Check Ack status (use local-name() to ignore namespace)
      ack <- xml2::xml_text(xml2::xml_find_first(doc, ".//*[local-name()='Ack']"))

      if (ack %in% c("Success", "Warning")) {
        # Success - extract ItemID
        item_id <- xml2::xml_text(xml2::xml_find_first(doc, ".//*[local-name()='ItemID']"))

        warnings <- NULL
        if (ack == "Warning") {
          warning_nodes <- xml2::xml_find_all(doc, ".//*[local-name()='Errors']/*[local-name()='SeverityCode' and text()='Warning']/..")
          warnings <- sapply(warning_nodes, function(node) {
            xml2::xml_text(xml2::xml_find_first(node, ".//*[local-name()='LongMessage']"))
          })
        }

        return(list(
          success = TRUE,
          item_id = item_id,
          warnings = warnings
        ))
      } else {
        # Failure - extract errors (use local-name() to ignore namespace)
        error_nodes <- xml2::xml_find_all(doc, ".//*[local-name()='Errors']")

        cat("   Found", length(error_nodes), "error node(s)\n")

        if (length(error_nodes) == 0) {
          return(list(
            success = FALSE,
            error = "Unknown error - no error details in response"
          ))
        }

        errors <- sapply(error_nodes, function(node) {
          code <- xml2::xml_text(xml2::xml_find_first(node, ".//*[local-name()='ErrorCode']"))
          msg <- xml2::xml_text(xml2::xml_find_first(node, ".//*[local-name()='LongMessage']"))
          short_msg <- xml2::xml_text(xml2::xml_find_first(node, ".//*[local-name()='ShortMessage']"))

          # Use LongMessage if available, otherwise ShortMessage
          error_text <- if (!is.na(msg) && msg != "") msg else short_msg

          if (!is.na(code) && code != "" && !is.na(error_text) && error_text != "") {
            paste0("Error ", code, ": ", error_text)
          } else {
            "Error parsing failed"
          }
        })

        error_message <- paste(errors, collapse = "; ")

        if (error_message == "" || error_message == "Error parsing failed") {
          error_message <- "Unknown error occurred"
        }

        return(list(
          success = FALSE,
          error = error_message
        ))
      }
    },

    #' @description Get business policy IDs (fetches dynamically or from cache)
    #' @return List with fulfillment_id, payment_id, return_id
    get_business_policy_ids = function() {
      cat("   Fetching business policy IDs...\n")

      tryCatch({
        access_token <- private$oauth$get_access_token()
        base_url <- private$config$get_base_url()

        # Fetch fulfillment (shipping) policies
        fulfillment_response <- httr2::request(paste0(base_url, "/sell/account/v1/fulfillment_policy")) |>
          httr2::req_method("GET") |>
          httr2::req_headers(
            "Authorization" = paste("Bearer", access_token),
            "Content-Type" = "application/json"
          ) |>
          httr2::req_url_query(marketplace_id = "EBAY_US") |>
          httr2::req_perform()

        fulfillment_data <- httr2::resp_body_json(fulfillment_response)
        fulfillment_id <- if (!is.null(fulfillment_data$fulfillmentPolicies) && length(fulfillment_data$fulfillmentPolicies) > 0) {
          fulfillment_data$fulfillmentPolicies[[1]]$fulfillmentPolicyId
        } else NULL

        # Fetch payment policies
        payment_response <- httr2::request(paste0(base_url, "/sell/account/v1/payment_policy")) |>
          httr2::req_method("GET") |>
          httr2::req_headers(
            "Authorization" = paste("Bearer", access_token),
            "Content-Type" = "application/json"
          ) |>
          httr2::req_url_query(marketplace_id = "EBAY_US") |>
          httr2::req_perform()

        payment_data <- httr2::resp_body_json(payment_response)
        payment_id <- if (!is.null(payment_data$paymentPolicies) && length(payment_data$paymentPolicies) > 0) {
          payment_data$paymentPolicies[[1]]$paymentPolicyId
        } else NULL

        # Fetch return policies
        return_response <- httr2::request(paste0(base_url, "/sell/account/v1/return_policy")) |>
          httr2::req_method("GET") |>
          httr2::req_headers(
            "Authorization" = paste("Bearer", access_token),
            "Content-Type" = "application/json"
          ) |>
          httr2::req_url_query(marketplace_id = "EBAY_US") |>
          httr2::req_perform()

        return_data <- httr2::resp_body_json(return_response)
        return_id <- if (!is.null(return_data$returnPolicies) && length(return_data$returnPolicies) > 0) {
          return_data$returnPolicies[[1]]$returnPolicyId
        } else NULL

        cat("   Found policies - Shipping:", !is.null(fulfillment_id),
            "Payment:", !is.null(payment_id),
            "Return:", !is.null(return_id), "\n")

        return(list(
          fulfillment_id = fulfillment_id,
          payment_id = payment_id,
          return_id = return_id
        ))

      }, error = function(e) {
        cat("   Warning: Could not fetch business policies:", e$message, "\n")
        cat("   Listing will fail if policies are not configured\n")
        return(list(
          fulfillment_id = NULL,
          payment_id = NULL,
          return_id = NULL
        ))
      })
    },

    #' @description Validate auction-specific data
    #' @param item_data Item data list
    #' @return List with valid (TRUE/FALSE) and error message
    validate_auction_data = function(item_data) {
      # Validate starting price >= $0.99
      if (is.null(item_data$start_price)) {
        return(list(valid = FALSE, error = "Starting bid is required for auctions"))
      }

      start_price <- as.numeric(item_data$start_price)
      if (is.na(start_price) || start_price < 0.99) {
        return(list(valid = FALSE, error = "Starting bid must be at least $0.99"))
      }

      # Validate Buy It Now price (if specified)
      if (!is.null(item_data$buy_it_now_price)) {
        bin_price <- as.numeric(item_data$buy_it_now_price)
        if (is.na(bin_price)) {
          return(list(valid = FALSE, error = "Invalid Buy It Now price"))
        }
        if (bin_price < start_price * 1.3) {
          return(list(
            valid = FALSE,
            error = sprintf("Buy It Now price ($%.2f) must be at least 30%% higher than starting bid ($%.2f)",
                          bin_price, start_price)
          ))
        }
      }

      # Validate Reserve price (if specified)
      if (!is.null(item_data$reserve_price)) {
        reserve <- as.numeric(item_data$reserve_price)
        if (is.na(reserve)) {
          return(list(valid = FALSE, error = "Invalid Reserve price"))
        }
        if (reserve < start_price) {
          return(list(
            valid = FALSE,
            error = sprintf("Reserve price ($%.2f) must be >= starting bid ($%.2f)", reserve, start_price)
          ))
        }
      }

      # Validate duration
      valid_durations <- c("Days_3", "Days_5", "Days_7", "Days_10")
      if (is.null(item_data$listing_duration) || !item_data$listing_duration %in% valid_durations) {
        return(list(
          valid = FALSE,
          error = sprintf("Invalid auction duration. Must be one of: %s", paste(valid_durations, collapse = ", "))
        ))
      }

      # Validate quantity is 1 (eBay requirement for auctions)
      if (!is.null(item_data$quantity) && as.numeric(item_data$quantity) != 1) {
        return(list(valid = FALSE, error = "Auction quantity must be 1"))
      }

      return(list(valid = TRUE, error = NULL))
    },

    #' @description Build AddItem XML request for auction
    #' @param item_data Item data list
    #' @return XML string
    build_auction_xml = function(item_data) {
      # Create root element
      doc <- xml2::xml_new_root(
        "AddItemRequest",
        xmlns = "urn:ebay:apis:eBLBaseComponents"
      )

      # Add Item element
      item <- xml2::xml_add_child(doc, "Item")

      # CRITICAL: Add Country and Location
      xml2::xml_add_child(item, "Country", item_data$country)
      xml2::xml_add_child(item, "Location", item_data$location)

      # Add currency (required by Trading API)
      xml2::xml_add_child(item, "Currency", "USD")

      # Add basic fields
      xml2::xml_add_child(item, "Title", item_data$title)

      # Add description (eBay accepts HTML in Description field)
      formatted_description <- paste0(
        "<div style='font-family: Arial, sans-serif;'>",
        "<h2>", item_data$title, "</h2>",
        "<p>", gsub("\n", "<br>", item_data$description), "</p>",
        "</div>"
      )
      xml2::xml_add_child(item, "Description", formatted_description)

      # Add category
      primary_cat <- xml2::xml_add_child(item, "PrimaryCategory")
      xml2::xml_add_child(primary_cat, "CategoryID", as.character(item_data$category_id))

      # AUCTION-SPECIFIC: ListingType = Chinese
      xml2::xml_add_child(item, "ListingType", "Chinese")

      # AUCTION-SPECIFIC: StartPrice (starting bid)
      start_price_node <- xml2::xml_add_child(item, "StartPrice", as.character(item_data$start_price))
      xml2::xml_set_attr(start_price_node, "currencyID", "USD")

      # AUCTION-SPECIFIC: ListingDuration
      xml2::xml_add_child(item, "ListingDuration", item_data$listing_duration)

      # OPTIONAL: Buy It Now Price
      if (!is.null(item_data$buy_it_now_price)) {
        bin_node <- xml2::xml_add_child(item, "BuyItNowPrice", as.character(item_data$buy_it_now_price))
        xml2::xml_set_attr(bin_node, "currencyID", "USD")
      }

      # OPTIONAL: Reserve Price
      if (!is.null(item_data$reserve_price)) {
        reserve_node <- xml2::xml_add_child(item, "ReservePrice", as.character(item_data$reserve_price))
        xml2::xml_set_attr(reserve_node, "currencyID", "USD")
      }

      # Add condition
      xml2::xml_add_child(item, "ConditionID", as.character(item_data$condition_id))

      # Add quantity (must be 1 for auctions)
      xml2::xml_add_child(item, "Quantity", "1")

      # Add images
      if (!is.null(item_data$images) && length(item_data$images) > 0) {
        pic_details <- xml2::xml_add_child(item, "PictureDetails")
        for (img_url in item_data$images) {
          xml2::xml_add_child(pic_details, "PictureURL", img_url)
        }
      }

      # Add item specifics (aspects)
      if (!is.null(item_data$aspects) && length(item_data$aspects) > 0) {
        specifics <- xml2::xml_add_child(item, "ItemSpecifics")
        for (aspect_name in names(item_data$aspects)) {
          nvl <- xml2::xml_add_child(specifics, "NameValueList")
          xml2::xml_add_child(nvl, "Name", aspect_name)

          # Handle both single values and vectors
          aspect_values <- item_data$aspects[[aspect_name]]
          if (!is.list(aspect_values)) {
            aspect_values <- list(aspect_values)
          }

          for (val in aspect_values) {
            xml2::xml_add_child(nvl, "Value", as.character(val))
          }
        }
      }

      # Add business policies (reuse same logic as fixed price)
      policy_ids <- private$get_business_policy_ids()

      has_policies <- !is.null(policy_ids$fulfillment_id) ||
                      !is.null(policy_ids$payment_id) ||
                      !is.null(policy_ids$return_id)

      if (has_policies) {
        seller_profiles <- xml2::xml_add_child(item, "SellerProfiles")

        if (!is.null(policy_ids$fulfillment_id)) {
          shipping_profile <- xml2::xml_add_child(seller_profiles, "SellerShippingProfile")
          xml2::xml_add_child(shipping_profile, "ShippingProfileID", policy_ids$fulfillment_id)
        }

        if (!is.null(policy_ids$payment_id)) {
          payment_profile <- xml2::xml_add_child(seller_profiles, "SellerPaymentProfile")
          xml2::xml_add_child(payment_profile, "PaymentProfileID", policy_ids$payment_id)
        }

        if (!is.null(policy_ids$return_id)) {
          return_profile <- xml2::xml_add_child(seller_profiles, "SellerReturnProfile")
          xml2::xml_add_child(return_profile, "ReturnProfileID", policy_ids$return_id)
        }
      } else {
        # Fallback: Add basic shipping and payment details
        cat("   No business policies found, using basic shipping/payment setup\n")

        shipping_details <- xml2::xml_add_child(item, "ShippingDetails")

        shipping_service <- xml2::xml_add_child(shipping_details, "ShippingServiceOptions")
        xml2::xml_add_child(shipping_service, "ShippingService", "USPSFirstClass")
        xml2::xml_add_child(shipping_service, "ShippingServicePriority", "1")
        shipping_cost <- xml2::xml_add_child(shipping_service, "ShippingServiceCost", "3.00")
        xml2::xml_set_attr(shipping_cost, "currencyID", "USD")

        xml2::xml_add_child(item, "PaymentMethods", "PayPal")
        xml2::xml_add_child(item, "PayPalEmailAddress", "your-paypal@example.com")

        return_policy <- xml2::xml_add_child(item, "ReturnPolicy")
        xml2::xml_add_child(return_policy, "ReturnsAcceptedOption", "ReturnsAccepted")
        xml2::xml_add_child(return_policy, "RefundOption", "MoneyBack")
        xml2::xml_add_child(return_policy, "ReturnsWithinOption", "Days_30")
        xml2::xml_add_child(return_policy, "ShippingCostPaidByOption", "Buyer")
      }

      # Convert to string
      return(as.character(doc))
    }
  )
)
