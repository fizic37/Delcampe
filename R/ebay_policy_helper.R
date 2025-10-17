#' Fetch eBay Business Policy IDs
#'
#' Helper function to retrieve your eBay sandbox/production business policy IDs
#' This is useful for setting up your .Renviron file with the required policy IDs
#'
#' @param ebay_api An authenticated eBay API object from mod_ebay_auth_server
#' @return A list with fulfillment, payment, and return policy IDs
#' @export
fetch_ebay_policy_ids <- function(ebay_api) {

  if (is.null(ebay_api)) {
    stop("eBay API object is NULL. Please authenticate first.")
  }

  cat("\n=== FETCHING EBAY BUSINESS POLICY IDS ===\n")
  cat("Environment:", ebay_api$config$environment, "\n\n")

  # Get access token
  access_token <- ebay_api$oauth$get_access_token()

  if (is.null(access_token) || access_token == "") {
    stop("Not authenticated. Please complete OAuth flow first.")
  }

  base_url <- ebay_api$config$get_base_url()

  results <- list(
    fulfillment = NULL,
    payment = NULL,
    return_policy = NULL
  )

  # 1. Fetch Fulfillment Policies
  cat("📦 Fetching Fulfillment Policies...\n")
  tryCatch({
    response <- httr2::request(paste0(base_url, "/sell/account/v1/fulfillment_policy")) |>
      httr2::req_method("GET") |>
      httr2::req_headers(
        "Authorization" = paste("Bearer", access_token),
        "Content-Type" = "application/json"
      ) |>
      httr2::req_url_query(marketplace_id = "EBAY_US") |>
      httr2::req_perform()

    data <- httr2::resp_body_json(response)

    if (!is.null(data$fulfillmentPolicies) && length(data$fulfillmentPolicies) > 0) {
      results$fulfillment <- data$fulfillmentPolicies
      cat("   ✅ Found", length(data$fulfillmentPolicies), "fulfillment policy(ies)\n")

      for (i in seq_along(data$fulfillmentPolicies)) {
        policy <- data$fulfillmentPolicies[[i]]
        cat("      [", i, "]", policy$name, "\n")
        cat("          ID:", policy$fulfillmentPolicyId, "\n")
      }
    } else {
      cat("   ⚠️  No fulfillment policies found\n")
    }

  }, error = function(e) {
    cat("   ❌ Error:", e$message, "\n")
  })

  cat("\n")

  # 2. Fetch Payment Policies
  cat("💳 Fetching Payment Policies...\n")
  tryCatch({
    response <- httr2::request(paste0(base_url, "/sell/account/v1/payment_policy")) |>
      httr2::req_method("GET") |>
      httr2::req_headers(
        "Authorization" = paste("Bearer", access_token),
        "Content-Type" = "application/json"
      ) |>
      httr2::req_url_query(marketplace_id = "EBAY_US") |>
      httr2::req_perform()

    data <- httr2::resp_body_json(response)

    if (!is.null(data$paymentPolicies) && length(data$paymentPolicies) > 0) {
      results$payment <- data$paymentPolicies
      cat("   ✅ Found", length(data$paymentPolicies), "payment policy(ies)\n")

      for (i in seq_along(data$paymentPolicies)) {
        policy <- data$paymentPolicies[[i]]
        cat("      [", i, "]", policy$name, "\n")
        cat("          ID:", policy$paymentPolicyId, "\n")
      }
    } else {
      cat("   ⚠️  No payment policies found\n")
    }

  }, error = function(e) {
    cat("   ❌ Error:", e$message, "\n")
  })

  cat("\n")

  # 3. Fetch Return Policies
  cat("↩️  Fetching Return Policies...\n")
  tryCatch({
    response <- httr2::request(paste0(base_url, "/sell/account/v1/return_policy")) |>
      httr2::req_method("GET") |>
      httr2::req_headers(
        "Authorization" = paste("Bearer", access_token),
        "Content-Type" = "application/json"
      ) |>
      httr2::req_url_query(marketplace_id = "EBAY_US") |>
      httr2::req_perform()

    data <- httr2::resp_body_json(response)

    if (!is.null(data$returnPolicies) && length(data$returnPolicies) > 0) {
      results$return_policy <- data$returnPolicies
      cat("   ✅ Found", length(data$returnPolicies), "return policy(ies)\n")

      for (i in seq_along(data$returnPolicies)) {
        policy <- data$returnPolicies[[i]]
        cat("      [", i, "]", policy$name, "\n")
        cat("          ID:", policy$returnPolicyId, "\n")
      }
    } else {
      cat("   ⚠️  No return policies found\n")
    }

  }, error = function(e) {
    cat("   ❌ Error:", e$message, "\n")
  })

  cat("\n=== SUMMARY ===\n")

  # Print .Renviron format
  if (!is.null(results$fulfillment) && length(results$fulfillment) > 0) {
    cat("\nCopy these to your .Renviron file:\n")
    cat("=====================================\n")

    # Use first policy of each type
    fulfillment_id <- results$fulfillment[[1]]$fulfillmentPolicyId
    payment_id <- if (!is.null(results$payment) && length(results$payment) > 0) {
      results$payment[[1]]$paymentPolicyId
    } else {
      "NOT_FOUND"
    }
    return_id <- if (!is.null(results$return_policy) && length(results$return_policy) > 0) {
      results$return_policy[[1]]$returnPolicyId
    } else {
      "NOT_FOUND"
    }

    cat("EBAY_FULFILLMENT_POLICY_ID=", fulfillment_id, "\n", sep = "")
    cat("EBAY_PAYMENT_POLICY_ID=", payment_id, "\n", sep = "")
    cat("EBAY_RETURN_POLICY_ID=", return_id, "\n", sep = "")
    cat("=====================================\n")
  } else {
    cat("\n⚠️  WARNING: No policies found!\n")
    cat("You need to create business policies first.\n")
    cat("Use create_default_ebay_policies() to create them automatically.\n")
  }

  cat("\n")

  invisible(results)
}


#' Create Default eBay Business Policies
#'
#' Creates default business policies for eBay sandbox/production if none exist
#'
#' @param ebay_api An authenticated eBay API object from mod_ebay_auth_server
#' @return A list with created policy IDs
#' @export
create_default_ebay_policies <- function(ebay_api) {

  if (is.null(ebay_api)) {
    stop("eBay API object is NULL. Please authenticate first.")
  }

  cat("\n=== CREATING DEFAULT EBAY BUSINESS POLICIES ===\n")
  cat("Environment:", ebay_api$config$environment, "\n\n")

  # Get access token
  access_token <- ebay_api$oauth$get_access_token()

  if (is.null(access_token) || access_token == "") {
    stop("Not authenticated. Please complete OAuth flow first.")
  }

  base_url <- ebay_api$config$get_base_url()

  results <- list(
    fulfillment_id = NULL,
    payment_id = NULL,
    return_id = NULL
  )

  # 1. Create Fulfillment Policy
  cat("📦 Creating Fulfillment Policy...\n")
  tryCatch({
    fulfillment_data <- list(
      name = "Standard Shipping",
      marketplaceId = "EBAY_US",
      categoryTypes = list(
        list(name = "ALL_EXCLUDING_MOTORS_VEHICLES")
      ),
      handlingTime = list(
        value = 3,
        unit = "DAY"
      ),
      shippingOptions = list(
        list(
          optionType = "DOMESTIC",
          costType = "FLAT_RATE",
          shippingServices = list(
            list(
              shippingServiceCode = "USPSPriority",
              shippingCost = list(
                value = "5.00",
                currency = "USD"
              ),
              sortOrder = 1
            )
          )
        )
      )
    )

    response <- httr2::request(paste0(base_url, "/sell/account/v1/fulfillment_policy")) |>
      httr2::req_method("POST") |>
      httr2::req_headers(
        "Authorization" = paste("Bearer", access_token),
        "Content-Type" = "application/json"
      ) |>
      httr2::req_body_json(fulfillment_data) |>
      httr2::req_perform()

    data <- httr2::resp_body_json(response)
    results$fulfillment_id <- data$fulfillmentPolicyId
    cat("   ✅ Created: ID =", results$fulfillment_id, "\n")

  }, error = function(e) {
    cat("   ❌ Error:", e$message, "\n")
  })

  # 2. Create Payment Policy
  cat("💳 Creating Payment Policy...\n")
  tryCatch({
    payment_data <- list(
      name = "Immediate Payment Required",
      marketplaceId = "EBAY_US",
      categoryTypes = list(
        list(name = "ALL_EXCLUDING_MOTORS_VEHICLES")
      ),
      paymentMethods = list(
        list(
          paymentMethodType = "PAYPAL",
          recipientAccountReference = list(
            referenceId = "paypal@example.com",
            referenceType = "PAYPAL_EMAIL"
          )
        )
      ),
      immediatePay = TRUE
    )

    response <- httr2::request(paste0(base_url, "/sell/account/v1/payment_policy")) |>
      httr2::req_method("POST") |>
      httr2::req_headers(
        "Authorization" = paste("Bearer", access_token),
        "Content-Type" = "application/json"
      ) |>
      httr2::req_body_json(payment_data) |>
      httr2::req_perform()

    data <- httr2::resp_body_json(response)
    results$payment_id <- data$paymentPolicyId
    cat("   ✅ Created: ID =", results$payment_id, "\n")

  }, error = function(e) {
    cat("   ❌ Error:", e$message, "\n")
  })

  # 3. Create Return Policy
  cat("↩️  Creating Return Policy...\n")
  tryCatch({
    return_data <- list(
      name = "30-Day Returns Accepted",
      marketplaceId = "EBAY_US",
      categoryTypes = list(
        list(name = "ALL_EXCLUDING_MOTORS_VEHICLES")
      ),
      returnsAccepted = TRUE,
      returnPeriod = list(
        value = 30,
        unit = "DAY"
      ),
      refundMethod = "MONEY_BACK",
      returnShippingCostPayer = "BUYER"
    )

    response <- httr2::request(paste0(base_url, "/sell/account/v1/return_policy")) |>
      httr2::req_method("POST") |>
      httr2::req_headers(
        "Authorization" = paste("Bearer", access_token),
        "Content-Type" = "application/json"
      ) |>
      httr2::req_body_json(return_data) |>
      httr2::req_perform()

    data <- httr2::resp_body_json(response)
    results$return_id <- data$returnPolicyId
    cat("   ✅ Created: ID =", results$return_id, "\n")

  }, error = function(e) {
    cat("   ❌ Error:", e$message, "\n")
  })

  cat("\n=== SUMMARY ===\n")
  cat("\nCopy these to your .Renviron file:\n")
  cat("=====================================\n")
  cat("EBAY_FULFILLMENT_POLICY_ID=", results$fulfillment_id %||% "FAILED", "\n", sep = "")
  cat("EBAY_PAYMENT_POLICY_ID=", results$payment_id %||% "FAILED", "\n", sep = "")
  cat("EBAY_RETURN_POLICY_ID=", results$return_id %||% "FAILED", "\n", sep = "")
  cat("=====================================\n")
  cat("\n")

  invisible(results)
}
