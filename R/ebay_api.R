# eBay API Integration Module
# This module handles all eBay API interactions

library(httr2)
library(jsonlite)
library(base64enc)
library(R6)

# eBay API Configuration Class
EbayAPIConfig <- R6::R6Class("EbayAPIConfig",
  public = list(
    client_id = NULL,
    client_secret = NULL,
    cert_id = NULL,
    dev_id = NULL,
    redirect_uri = NULL,
    environment = NULL,
    
    initialize = function(environment = NULL) {
      # Use environment variable if not specified
      self$environment <- environment %||% Sys.getenv("EBAY_ENVIRONMENT", "sandbox")
      
      # Load credentials based on environment
      if (self$environment == "sandbox") {
        self$client_id <- Sys.getenv("EBAY_SANDBOX_CLIENT_ID")
        self$client_secret <- Sys.getenv("EBAY_SANDBOX_CLIENT_SECRET")
        self$cert_id <- Sys.getenv("EBAY_SANDBOX_CERT_ID")
        self$dev_id <- Sys.getenv("EBAY_SANDBOX_DEV_ID")
      } else {
        self$client_id <- Sys.getenv("EBAY_PROD_CLIENT_ID")
        self$client_secret <- Sys.getenv("EBAY_PROD_CLIENT_SECRET")
        self$cert_id <- Sys.getenv("EBAY_PROD_CERT_ID")
        self$dev_id <- Sys.getenv("EBAY_PROD_DEV_ID")
      }
      
      self$redirect_uri <- Sys.getenv("EBAY_REDIRECT_URI", "http://localhost:3838/callback")
      
      # Validate credentials
      if (self$client_id == "" || self$client_secret == "") {
        warning("eBay API credentials not found. Please set them in .Renviron file.")
      }
    },
    
    get_base_url = function() {
      if (self$environment == "sandbox") {
        return("https://api.sandbox.ebay.com")
      } else {
        return("https://api.ebay.com")
      }
    },
    
    get_auth_url = function() {
      if (self$environment == "sandbox") {
        return("https://auth.sandbox.ebay.com")
      } else {
        return("https://auth.ebay.com")
      }
    }
  )
)

# eBay OAuth Handler
EbayOAuth <- R6::R6Class("EbayOAuth",
  private = list(
    config = NULL,
    access_token = NULL,
    refresh_token = NULL,
    token_expiry = NULL,
    token_file = "data/ebay_tokens.rds"
  ),
  
  public = list(
    initialize = function(config) {
      private$config <- config
      # Try to load existing tokens
      self$load_tokens()
    },
    
    # Generate authorization URL for user consent
    generate_auth_url = function(scope = NULL) {
      # Default scopes for postcard selling
      if (is.null(scope)) {
        scope <- paste(
          "https://api.ebay.com/oauth/api_scope/sell.inventory",
          "https://api.ebay.com/oauth/api_scope/sell.account",
          "https://api.ebay.com/oauth/api_scope/sell.fulfillment",
          sep = " "
        )
      }
      
      auth_url <- paste0(
        private$config$get_auth_url(),
        "/oauth2/authorize?",
        "client_id=", private$config$client_id,
        "&redirect_uri=", URLencode(private$config$redirect_uri),
        "&response_type=code",
        "&scope=", URLencode(scope)
      )
      return(auth_url)
    },
    
    # Exchange authorization code for access token
    get_user_token = function(authorization_code) {
      # IMPORTANT: Token endpoint uses api.*.ebay.com, NOT auth.*.ebay.com
      token_url <- paste0(private$config$get_base_url(), "/identity/v1/oauth2/token")
      
      # Create basic auth header
      auth_string <- paste0(private$config$client_id, ":", private$config$client_secret)
      auth_header <- paste0("Basic ", base64encode(charToRaw(auth_string)))
      
      tryCatch({
        response <- request(token_url) |>
          req_method("POST") |>
          req_headers(
            "Authorization" = auth_header,
            "Content-Type" = "application/x-www-form-urlencoded"
          ) |>
          req_body_form(
            grant_type = "authorization_code",
            code = authorization_code,
            redirect_uri = private$config$redirect_uri
          ) |>
          req_perform()
        
        token_data <- resp_body_json(response)
        
        private$access_token <- token_data$access_token
        private$refresh_token <- token_data$refresh_token
        private$token_expiry <- Sys.time() + as.numeric(token_data$expires_in)
        
        # Save tokens to file for persistence
        self$save_tokens()
        
        return(list(
          success = TRUE,
          access_token = token_data$access_token,
          expires_in = token_data$expires_in
        ))
        
      }, error = function(e) {
        return(list(
          success = FALSE,
          error = e$message
        ))
      })
    },
    
    # Get application token (for public data)
    get_app_token = function(scope = "https://api.ebay.com/oauth/api_scope") {
      # IMPORTANT: Token endpoint uses api.*.ebay.com, NOT auth.*.ebay.com
      token_url <- paste0(private$config$get_base_url(), "/identity/v1/oauth2/token")
      
      auth_string <- paste0(private$config$client_id, ":", private$config$client_secret)
      auth_header <- paste0("Basic ", base64encode(charToRaw(auth_string)))
      
      tryCatch({
        response <- request(token_url) |>
          req_method("POST") |>
          req_headers(
            "Authorization" = auth_header,
            "Content-Type" = "application/x-www-form-urlencoded"
          ) |>
          req_body_form(
            grant_type = "client_credentials",
            scope = scope
          ) |>
          req_perform()
        
        token_data <- resp_body_json(response)
        private$access_token <- token_data$access_token
        private$token_expiry <- Sys.time() + as.numeric(token_data$expires_in)
        
        return(list(
          success = TRUE,
          access_token = token_data$access_token
        ))
        
      }, error = function(e) {
        return(list(
          success = FALSE,
          error = e$message
        ))
      })
    },
    
    # Refresh the user token
    refresh_user_token = function() {
      if (is.null(private$refresh_token)) {
        return(list(success = FALSE, error = "No refresh token available"))
      }

      # IMPORTANT: Token endpoint uses api.*.ebay.com, NOT auth.*.ebay.com
      token_url <- paste0(private$config$get_base_url(), "/identity/v1/oauth2/token")
      
      auth_string <- paste0(private$config$client_id, ":", private$config$client_secret)
      auth_header <- paste0("Basic ", base64encode(charToRaw(auth_string)))
      
      tryCatch({
        response <- request(token_url) |>
          req_method("POST") |>
          req_headers(
            "Authorization" = auth_header,
            "Content-Type" = "application/x-www-form-urlencoded"
          ) |>
          req_body_form(
            grant_type = "refresh_token",
            refresh_token = private$refresh_token
          ) |>
          req_perform()
        
        token_data <- resp_body_json(response)
        
        private$access_token <- token_data$access_token
        if (!is.null(token_data$refresh_token)) {
          private$refresh_token <- token_data$refresh_token
        }
        private$token_expiry <- Sys.time() + as.numeric(token_data$expires_in)
        
        self$save_tokens()
        
        return(list(success = TRUE))
        
      }, error = function(e) {
        return(list(success = FALSE, error = e$message))
      })
    },
    
    # Check if token needs refresh
    needs_refresh = function() {
      if (is.null(private$token_expiry)) return(TRUE)
      return(Sys.time() >= (private$token_expiry - 300)) # Refresh 5 minutes before expiry
    },
    
    # Get current access token
    get_access_token = function() {
      if (self$needs_refresh() && !is.null(private$refresh_token)) {
        self$refresh_user_token()
      }
      return(private$access_token)
    },
    
    # Save tokens to file
    save_tokens = function() {
      tokens <- list(
        access_token = private$access_token,
        refresh_token = private$refresh_token,
        token_expiry = private$token_expiry,
        environment = private$config$environment
      )
      saveRDS(tokens, file = private$token_file)
    },
    
    # Load tokens from file
    load_tokens = function() {
      if (file.exists(private$token_file)) {
        tokens <- readRDS(private$token_file)
        # Only load if same environment
        if (tokens$environment == private$config$environment) {
          private$access_token <- tokens$access_token
          private$refresh_token <- tokens$refresh_token
          private$token_expiry <- tokens$token_expiry
          return(TRUE)
        }
      }
      return(FALSE)
    },
    
    # Check if authenticated
    is_authenticated = function() {
      return(!is.null(private$access_token) && !self$needs_refresh())
    }
  )
)

# eBay Inventory API Client
EbayInventoryAPI <- R6::R6Class("EbayInventoryAPI",
  private = list(
    oauth = NULL,
    config = NULL
  ),
  
  public = list(
    initialize = function(oauth, config) {
      private$oauth <- oauth
      private$config <- config
    },
    
    # Create or update inventory location
    create_location = function(merchant_location_key, location_data) {
      url <- paste0(
        private$config$get_base_url(),
        "/sell/inventory/v1/location/",
        merchant_location_key
      )
      
      tryCatch({
        response <- request(url) |>
          req_method("POST") |>
          req_headers(
            "Authorization" = paste("Bearer", private$oauth$get_access_token()),
            "Content-Type" = "application/json",
            "Content-Language" = "en-US"
          ) |>
          req_body_json(location_data) |>
          req_perform()
        
        return(list(success = TRUE))
        
      }, error = function(e) {
        return(list(success = FALSE, error = e$message))
      })
    },
    
    # Create or replace inventory item
    create_inventory_item = function(sku, item_data) {
      url <- paste0(
        private$config$get_base_url(),
        "/sell/inventory/v1/inventory_item/",
        sku
      )

      # Get access token
      access_token <- private$oauth$get_access_token()

      # Debug: Check if token exists
      if (is.null(access_token) || access_token == "") {
        cat("   ❌ ERROR: Access token is NULL or empty\n")
        cat("      OAuth authenticated:", private$oauth$is_authenticated(), "\n")
        cat("      Token needs refresh:", private$oauth$needs_refresh(), "\n")
        return(list(success = FALSE, error = "Missing access token. Please authenticate with eBay first."))
      }

      cat("   ✅ Access token available (length:", nchar(access_token), ")\n")

      tryCatch({
        response <- request(url) |>
          req_method("PUT") |>
          req_headers(
            "Authorization" = paste("Bearer", access_token),
            "Content-Type" = "application/json",
            "Content-Language" = "en-US"
          ) |>
          req_body_json(item_data) |>
          req_error(function(resp) {
            status <- resp_status(resp)
            # HTTP 204 No Content is SUCCESS for eBay inventory item creation
            # Only treat 4xx and 5xx as errors (except 204)
            if (status == 204) {
              return(FALSE)  # Not an error
            }

            # Extract error details from eBay response
            body <- tryCatch(resp_body_json(resp), error = function(e) NULL)
            if (!is.null(body) && !is.null(body$errors)) {
              error_msg <- paste(
                sapply(body$errors, function(err) {
                  paste0(err$errorId, ": ", err$message)
                }),
                collapse = "; "
              )
              stop(error_msg, call. = FALSE)
            } else {
              stop(paste("HTTP", status, resp_status_desc(resp)), call. = FALSE)
            }
          }) |>
          req_perform()

        # HTTP 204 No Content = success with no body returned
        status <- resp_status(response)
        if (status %in% c(200, 201, 204)) {
          cat("   ✅ Inventory item created (HTTP", status, ")\n")
          return(list(success = TRUE))
        } else {
          return(list(success = FALSE, error = paste("Unexpected status:", status)))
        }

      }, error = function(e) {
        return(list(success = FALSE, error = e$message))
      })
    },
    
    # Create offer
    create_offer = function(offer_data) {
      url <- paste0(
        private$config$get_base_url(),
        "/sell/inventory/v1/offer"
      )

      tryCatch({
        response <- request(url) |>
          req_method("POST") |>
          req_headers(
            "Authorization" = paste("Bearer", private$oauth$get_access_token()),
            "Content-Type" = "application/json",
            "Content-Language" = "en-US"
          ) |>
          req_body_json(offer_data) |>
          req_error(function(resp) {
            status <- resp_status(resp)
            # HTTP 201 Created is SUCCESS for offer creation
            if (status == 201 || status == 200) {
              return(FALSE)  # Not an error
            }

            # Extract detailed error from eBay
            body <- tryCatch(resp_body_json(resp), error = function(e) NULL)
            if (!is.null(body) && !is.null(body$errors)) {
              errors <- sapply(body$errors, function(err) {
                msg <- paste0(err$errorId, ": ", err$message)
                if (!is.null(err$parameters)) {
                  params <- paste(sapply(err$parameters, function(p) {
                    paste0(p$name, "=", p$value)
                  }), collapse = ", ")
                  msg <- paste0(msg, " (", params, ")")
                }
                msg
              })
              cat("   eBay API Error Details:\n")
              cat("  ", paste(errors, collapse = "\n   "), "\n")
              stop(paste(errors, collapse = "; "), call. = FALSE)
            } else {
              stop(paste("HTTP", status, resp_status_desc(resp)), call. = FALSE)
            }
          }) |>
          req_perform()

        status <- resp_status(response)
        if (status %in% c(200, 201)) {
          result <- resp_body_json(response)
          cat("   ✅ Offer created (HTTP", status, "), ID:", result$offerId, "\n")
          return(list(success = TRUE, offer_id = result$offerId))
        } else {
          return(list(success = FALSE, error = paste("Unexpected status:", status)))
        }

      }, error = function(e) {
        return(list(success = FALSE, error = e$message))
      })
    },
    
    # Publish offer
    publish_offer = function(offer_id) {
      url <- paste0(
        private$config$get_base_url(),
        "/sell/inventory/v1/offer/",
        offer_id,
        "/publish"
      )

      tryCatch({
        response <- request(url) |>
          req_method("POST") |>
          req_headers(
            "Authorization" = paste("Bearer", private$oauth$get_access_token()),
            "Content-Type" = "application/json"
          ) |>
          req_error(function(resp) {
            status <- resp_status(resp)
            # Extract detailed error from eBay
            body <- tryCatch(resp_body_json(resp), error = function(e) NULL)
            if (!is.null(body) && !is.null(body$errors)) {
              errors <- sapply(body$errors, function(err) {
                msg <- paste0(err$errorId, ": ", err$message)
                if (!is.null(err$parameters)) {
                  params <- paste(sapply(err$parameters, function(p) {
                    paste0(p$name, "=", p$value)
                  }), collapse = ", ")
                  msg <- paste0(msg, " (", params, ")")
                }
                msg
              })
              cat("   eBay Publish Error Details:\n")
              cat("  ", paste(errors, collapse = "\n   "), "\n")
              stop(paste(errors, collapse = "; "), call. = FALSE)
            } else {
              stop(paste("HTTP", status, resp_status_desc(resp)), call. = FALSE)
            }
          }) |>
          req_perform()

        result <- resp_body_json(response)
        return(list(success = TRUE, listing_id = result$listingId))

      }, error = function(e) {
        return(list(success = FALSE, error = e$message))
      })
    },
    
    # Helper function to create postcard listing
    create_postcard_listing = function(
      sku,
      title,
      description,
      price,
      quantity,
      image_urls = list(),
      condition = "USED_EXCELLENT",
      aspects = list(),
      location_key = "default_location",
      listing_policies = list()
    ) {
      
      # Step 1: Create inventory item
      inventory_data <- list(
        product = list(
          title = title,
          description = description,
          imageUrls = image_urls,
          aspects = aspects
        ),
        condition = condition,
        availability = list(
          shipToLocationAvailability = list(
            quantity = quantity
          )
        )
      )
      
      item_result <- self$create_inventory_item(sku, inventory_data)
      
      if (!item_result$success) {
        return(item_result)
      }
      
      # Step 2: Create offer
      offer_data <- list(
        sku = sku,
        marketplaceId = "EBAY_US",
        format = "FIXED_PRICE",
        availableQuantity = quantity,
        pricingSummary = list(
          price = list(
            currency = "USD",
            value = as.character(price)
          )
        ),
        listingPolicies = listing_policies,
        merchantLocationKey = location_key,
        categoryId = "914"  # Postcards category
      )
      
      offer_result <- self$create_offer(offer_data)
      
      if (!offer_result$success) {
        return(offer_result)
      }
      
      # Step 3: Publish offer
      publish_result <- self$publish_offer(offer_result$offer_id)
      
      if (publish_result$success) {
        return(list(
          success = TRUE,
          offer_id = offer_result$offer_id,
          listing_id = publish_result$listing_id
        ))
      } else {
        return(publish_result)
      }
    }
  )
)

# Initialize eBay API connection
#' @export
init_ebay_api <- function(environment = NULL) {
  config <- EbayAPIConfig$new(environment)
  oauth <- EbayOAuth$new(config)
  inventory_api <- EbayInventoryAPI$new(oauth, config)
  
  return(list(
    config = config,
    oauth = oauth,
    inventory = inventory_api
  ))
}
