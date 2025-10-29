# eBay API Integration Module
# This module handles all eBay API interactions

library(httr2)
library(jsonlite)
library(base64enc)
library(digest)
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
      # Default scopes for postcard selling via Trading API
      # NOTE: Trading API requires different scopes than Inventory API
      if (is.null(scope)) {
        scope <- paste(
          "https://api.ebay.com/oauth/api_scope",  # General API access (Trading API)
          "https://api.ebay.com/oauth/api_scope/sell.inventory",  # Inventory API (backup)
          "https://api.ebay.com/oauth/api_scope/sell.account",  # Account info
          "https://api.ebay.com/oauth/api_scope/sell.fulfillment",  # Order fulfillment
          "https://api.ebay.com/oauth/api_scope/commerce.identity.readonly",  # User identity (for username)
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

    # Get current refresh token
    get_refresh_token = function() {
      return(private$refresh_token)
    },

    # Get current token expiry
    get_token_expiry = function() {
      return(private$token_expiry)
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
    },

    # Fetch eBay user identity (for multi-account support)
    get_user_info = function() {
      token <- self$get_access_token()

      if (is.null(token)) {
        return(list(
          success = FALSE,
          error = "No access token available"
        ))
      }

      cat("\n🔍 Attempting to extract user info from eBay token...\n")

      # Try to decode JWT token to extract user info
      jwt_result <- tryCatch({
        # Split token and decode payload (middle part)
        token_parts <- strsplit(token, "\\.")[[1]]
        if (length(token_parts) >= 2) {
          # Decode base64url payload (JWT uses base64url encoding)
          payload_encoded <- token_parts[2]

          # Add padding if needed for base64 decoding
          missing_padding <- (4 - nchar(payload_encoded) %% 4) %% 4
          if (missing_padding > 0) {
            payload_encoded <- paste0(payload_encoded, paste(rep("=", missing_padding), collapse = ""))
          }

          # Replace URL-safe characters with standard base64
          payload_encoded <- gsub("-", "+", payload_encoded)
          payload_encoded <- gsub("_", "/", payload_encoded)

          # Decode
          payload_json <- rawToChar(base64decode(payload_encoded))
          payload_data <- jsonlite::fromJSON(payload_json)

          cat("📋 JWT Payload claims found:\n")
          cat("  ", paste(names(payload_data), collapse = ", "), "\n")

          # Extract user info from JWT payload
          # eBay tokens include user_name and user_id in the payload
          user_id <- payload_data$`https://apiz.ebay.com/useridz`
          username <- payload_data$`https://apiz.ebay.com/usernamez`

          cat("  useridz claim:", if (!is.null(user_id)) user_id else "NULL", "\n")
          cat("  usernamez claim:", if (!is.null(username)) username else "NULL", "\n")

          # Fallback to alternative claim names if primary ones don't exist
          if (is.null(user_id)) user_id <- payload_data$user_id
          if (is.null(username)) username <- payload_data$username
          if (is.null(username)) username <- payload_data$sub

          if (!is.null(user_id) && !is.null(username)) {
            cat("✅ JWT extraction successful!\n")
            cat("  User ID:", user_id, "\n")
            cat("  Username:", username, "\n\n")
            return(list(
              success = TRUE,
              user_id = as.character(user_id),
              username = as.character(username)
            ))
          } else {
            cat("⚠️ JWT extraction incomplete (user_id or username missing)\n")
            return(NULL)
          }
        }
        return(NULL)
      }, error = function(e) {
        cat("❌ JWT decoding failed:", e$message, "\n")
        return(NULL)
      })

      # If JWT worked, return it
      if (!is.null(jwt_result)) {
        return(jwt_result)
      }

      # Try API call as fallback
      cat("🌐 Attempting eBay User API call...\n")
      api_result <- tryCatch({
        # IMPORTANT: Identity API uses apiz.ebay.com, not api.ebay.com
        base_url <- private$config$get_base_url()
        identity_url <- gsub("^https://api\\.", "https://apiz.", base_url)
        user_url <- paste0(identity_url, "/commerce/identity/v1/user")

        cat("  URL:", user_url, "\n")

        response <- request(user_url) |>
          req_headers("Authorization" = paste("Bearer", token)) |>
          req_perform()

        user_data <- resp_body_json(response)

        cat("✅ API call successful!\n")
        cat("  API response fields:", paste(names(user_data), collapse = ", "), "\n")

        # Extract userId and username from response
        user_id <- if (!is.null(user_data$userId)) user_data$userId else user_data$user_id
        username <- if (!is.null(user_data$username)) user_data$username else user_data$userName

        cat("  User ID:", user_id, "\n")
        cat("  Username:", username, "\n\n")

        return(list(
          success = TRUE,
          user_id = user_id,
          username = username
        ))

      }, error = function(e) {
        cat("❌ API call failed:", e$message, "\n\n")
        return(NULL)
      })

      # If API worked, return it
      if (!is.null(api_result)) {
        return(api_result)
      }

      # Last resort fallback - generate from token hash
      cat("⚠️ All methods failed - using generated fallback username\n")
      token_hash <- substr(digest::digest(token, algo = "md5"), 1, 8)

      return(list(
        success = TRUE,
        user_id = paste0("ebay_user_", token_hash),
        username = paste0("eBay_", private$config$environment, "_", token_hash)
      ))
    },

    # Inject stored tokens (for account switching)
    set_tokens = function(access_token, refresh_token, token_expiry) {
      private$access_token <- access_token
      private$refresh_token <- refresh_token
      private$token_expiry <- token_expiry

      message("🔑 Tokens injected (expires: ", format(token_expiry, "%H:%M"), ")")
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
    
    # Get all inventory locations (diagnostic)
    get_locations = function() {
      url <- paste0(
        private$config$get_base_url(),
        "/sell/inventory/v1/location"
      )

      tryCatch({
        response <- request(url) |>
          req_method("GET") |>
          req_headers(
            "Authorization" = paste("Bearer", private$oauth$get_access_token()),
            "Content-Type" = "application/json"
          ) |>
          req_perform()

        result <- resp_body_json(response)
        return(list(success = TRUE, locations = result$locations))

      }, error = function(e) {
        return(list(success = FALSE, error = e$message))
      })
    },

    # Get user registration information (for diagnostics)
    get_registration_address = function() {
      url <- "https://api.ebay.com/commerce/identity/v1/user/"

      tryCatch({
        response <- request(url) |>
          req_method("GET") |>
          req_headers(
            "Authorization" = paste("Bearer", private$oauth$get_access_token()),
            "Content-Type" = "application/json"
          ) |>
          req_perform()

        result <- resp_body_json(response)
        reg_addr <- result$registrationAddress

        return(list(
          success = TRUE,
          country = reg_addr$country %||% NA,
          city = reg_addr$city %||% NA,
          address = reg_addr$addressLine1 %||% NA,
          postal_code = reg_addr$postalCode %||% NA
        ))

      }, error = function(e) {
        return(list(success = FALSE, error = e$message))
      })
    },

    # Create or update inventory location
    create_location = function(merchant_location_key, location_data) {
      url <- paste0(
        private$config$get_base_url(),
        "/sell/inventory/v1/location/",
        merchant_location_key
      )

      # Debug: Print request details
      cat("   DEBUG - Location Request:\n")
      cat("      URL:", url, "\n")
      cat("      Method: PUT\n")
      cat("      Body:", jsonlite::toJSON(location_data, auto_unbox = TRUE), "\n")

      tryCatch({
        response <- request(url) |>
          req_method("PUT") |>
          req_headers(
            "Authorization" = paste("Bearer", private$oauth$get_access_token()),
            "Content-Type" = "application/json",
            "Content-Language" = "en-US"
          ) |>
          req_body_json(location_data) |>
          req_error(function(resp) {
            status <- resp_status(resp)
            cat("   DEBUG - Location Error Response:\n")
            cat("      Status:", status, resp_status_desc(resp), "\n")

            # Try to get response body as text first
            body_text <- tryCatch(resp_body_string(resp), error = function(e) {
              cat("      (Could not read response body as text)\n")
              NULL
            })

            if (!is.null(body_text)) {
              cat("      Raw body:", body_text, "\n")
            }

            # Extract detailed error from eBay
            body <- tryCatch(resp_body_json(resp), error = function(e) NULL)
            if (!is.null(body) && !is.null(body$errors)) {
              cat("   eBay Location Error Details:\n")
              errors <- sapply(body$errors, function(err) {
                msg <- paste0(err$errorId, ": ", err$message)
                cat("      Error ID:", err$errorId, "\n")
                cat("      Message:", err$message, "\n")
                if (!is.null(err$parameters)) {
                  cat("      Parameters:\n")
                  for (param in err$parameters) {
                    cat("         -", param$name, "=", param$value, "\n")
                  }
                }
                msg
              })
              stop(paste(errors, collapse = "; "), call. = FALSE)
            } else {
              stop(paste("HTTP", status, resp_status_desc(resp)), call. = FALSE)
            }
          }) |>
          req_perform()

        cat("   ✅ Location request successful\n")
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

            # Extract error details from eBay response with enhanced debugging
            body <- tryCatch(resp_body_json(resp), error = function(e) NULL)
            if (!is.null(body) && !is.null(body$errors)) {
              cat("   DEBUG - eBay Inventory Item Error Details:\n")
              error_msgs <- sapply(body$errors, function(err) {
                msg <- paste0(err$errorId, ": ", err$message)
                cat("      Error ID:", err$errorId, "\n")
                cat("      Message:", err$message, "\n")

                # Show parameters if available
                if (!is.null(err$parameters)) {
                  cat("      Parameters:\n")
                  for (param in err$parameters) {
                    cat("         -", param$name, "=", param$value, "\n")
                  }
                }

                # Show domain/subdomain if available
                if (!is.null(err$domain)) cat("      Domain:", err$domain, "\n")
                if (!is.null(err$subdomain)) cat("      Subdomain:", err$subdomain, "\n")

                msg
              })
              error_msg <- paste(error_msgs, collapse = "; ")
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

# eBay Media API Client
# Handles image uploads to eBay Picture Services (EPS)
EbayMediaAPI <- R6::R6Class("EbayMediaAPI",
  public = list(
    config = NULL,
    oauth = NULL,

    initialize = function(config, oauth) {
      self$config <- config
      self$oauth <- oauth
    },

    # Upload image file to eBay Picture Services
    # Returns: list(success = TRUE/FALSE, image_url = "...", image_id = "...", expiration = "...", error = "...")
    upload_image = function(image_path) {
      # Step 1: Validate file exists and is supported image format
      if (!file.exists(image_path)) {
        return(list(success = FALSE, error = paste("File not found:", image_path)))
      }

      ext <- tolower(tools::file_ext(image_path))
      if (!ext %in% c("jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp")) {
        return(list(success = FALSE, error = "Unsupported format. Use JPG, PNG, GIF, BMP, TIFF, or WEBP"))
      }

      # Step 2: Construct multipart upload request
      base_url <- if (self$config$environment == "sandbox") {
        "https://api.sandbox.ebay.com"
      } else {
        "https://api.ebay.com"
      }

      token <- self$oauth$get_access_token()

      # Map file extension to MIME type
      mime_type <- switch(ext,
        "jpg" = "image/jpeg",
        "jpeg" = "image/jpeg",
        "png" = "image/png",
        "gif" = "image/gif",
        "bmp" = "image/bmp",
        "tiff" = "image/tiff",
        "webp" = "image/webp",
        paste0("image/", ext)
      )

      req <- httr2::request(paste0(base_url, "/commerce/media/v1_beta/image/create_image_from_file")) |>
        httr2::req_method("POST") |>
        httr2::req_headers(
          Authorization = paste("Bearer", token),
          "Content-Language" = "en-US"
        ) |>
        httr2::req_body_multipart(
          image = curl::form_file(image_path, type = mime_type)
        )

      # Step 3: Perform request and extract image_id from Location header
      resp <- tryCatch({
        httr2::req_perform(req)
      }, error = function(e) {
        return(list(success = FALSE, error = paste("Upload failed:", e$message)))
      })

      # Check if response is an error list (from tryCatch)
      if (is.list(resp) && !is.null(resp$error)) {
        return(resp)
      }

      status <- httr2::resp_status(resp)
      if (status != 201) {
        # Try to extract eBay error details with enhanced logging
        error_msg <- tryCatch({
          # Log response details for debugging
          cat("   DEBUG - Media API Response:\n")
          cat("      Status:", status, "\n")
          cat("      Content-Type:", httr2::resp_header(resp, "content-type") %||% "unknown", "\n")

          # Try to get response body as text first
          body_text <- tryCatch(httr2::resp_body_string(resp), error = function(e) NULL)
          if (!is.null(body_text) && nchar(body_text) > 0) {
            cat("      Body (first 200 chars):", substr(body_text, 1, 200), "\n")
          }

          # Try JSON parsing
          body <- httr2::resp_body_json(resp)
          if (!is.null(body$errors) && length(body$errors) > 0) {
            paste0("eBay error ", body$errors[[1]]$errorId, ": ", body$errors[[1]]$message)
          } else if (!is.null(body$error)) {
            paste0("eBay error: ", body$error)
          } else {
            paste("Upload failed with status", status, httr2::resp_status_desc(resp))
          }
        }, error = function(e) {
          paste("Upload failed with status", status, httr2::resp_status_desc(resp))
        })
        return(list(success = FALSE, error = error_msg))
      }

      # Extract image_id from Location header
      location <- httr2::resp_header(resp, "location")
      if (is.null(location)) {
        location <- httr2::resp_header(resp, "Location")
      }

      if (is.null(location)) {
        return(list(success = FALSE, error = "Location header not found in response"))
      }

      image_id <- gsub(".*/image/", "", location)

      # Step 4: Retrieve EPS URL via getImage
      image_details <- self$get_image(image_id)
      if (!image_details$success) {
        return(image_details)
      }

      return(list(
        success = TRUE,
        image_url = image_details$image_url,
        image_id = image_id,
        expiration = image_details$expiration_date
      ))
    },

    # Retrieve image details from eBay (internal method)
    # Returns: list(success = TRUE/FALSE, image_url = "...", expiration_date = "...", error = "...")
    get_image = function(image_id) {
      base_url <- if (self$config$environment == "sandbox") {
        "https://api.sandbox.ebay.com"
      } else {
        "https://api.ebay.com"
      }

      token <- self$oauth$get_access_token()

      req <- httr2::request(paste0(base_url, "/commerce/media/v1_beta/image/", image_id)) |>
        httr2::req_method("GET") |>
        httr2::req_headers(
          Authorization = paste("Bearer", token),
          "Content-Language" = "en-US"
        )

      resp <- tryCatch({
        httr2::req_perform(req)
      }, error = function(e) {
        return(list(success = FALSE, error = paste("Failed to retrieve image:", e$message)))
      })

      # Check if response is an error list (from tryCatch)
      if (is.list(resp) && !is.null(resp$error)) {
        return(resp)
      }

      status <- httr2::resp_status(resp)
      if (status != 200) {
        return(list(success = FALSE, error = paste("Get image failed with status", status)))
      }

      data <- httr2::resp_body_json(resp)

      return(list(
        success = TRUE,
        image_url = data$imageUrl,
        expiration_date = data$expirationDate
      ))
    }
  )
)

# Handles eBay Taxonomy API for category aspects and suggestions
# Handles eBay Taxonomy API for category aspects and suggestions
# Handles eBay Taxonomy API for category aspects and suggestions
# Handles eBay Taxonomy API for category aspects and suggestions
# Handles eBay Taxonomy API for category aspects and suggestions
# NOTE: Uses application-level tokens (client_credentials), not user tokens
EbayTaxonomyAPI <- R6::R6Class("EbayTaxonomyAPI",
  public = list(
    config = NULL,
    oauth = NULL,
    
    initialize = function(oauth, config) {
      self$oauth <- oauth
      self$config <- config
      private$base_url <- if (config$environment == "sandbox") {
        "https://api.sandbox.ebay.com"
      } else {
        "https://api.ebay.com"
      }
      # US marketplace category tree (0 = EBAY_US)
      private$marketplace_id <- "0"
      
      # Get application token for public APIs (Taxonomy doesn't require user auth)
      cat("   📋 Getting application token for Taxonomy API...\n")
      app_token_result <- self$oauth$get_app_token()
      if (app_token_result$success) {
        cat("   ✓ Application token obtained\n")
      } else {
        warning("Failed to get application token: ", app_token_result$error)
      }
    },

    get_category_aspects = function(category_id) {
      # Check cache first
      cache_key <- paste0("cat_", category_id)
      if (!is.null(private$cache_category_aspects[[cache_key]])) {
        cat("   (Using cached data)\n")
        return(private$cache_category_aspects[[cache_key]])
      }

      # Build request URL with proper marketplace ID
      url <- paste0(
        private$base_url,
        "/commerce/taxonomy/v1/category_tree/", private$marketplace_id,
        "/get_item_aspects_for_category?category_id=",
        category_id
      )

      cat("   API URL:", url, "\n")

      # Make API call using application token (not user token)
      tryCatch({
        # Use the application token that was set in initialize()
        token <- self$oauth$get_access_token()
        
        if (is.null(token) || token == "") {
          # Try to get fresh application token
          app_token_result <- self$oauth$get_app_token()
          if (!app_token_result$success) {
            return(list(
              success = FALSE,
              error = paste("Failed to get application token:", app_token_result$error)
            ))
          }
          token <- app_token_result$access_token
        }
        
        response <- httr2::request(url) |>
          httr2::req_method("GET") |>
          httr2::req_headers(
            "Authorization" = paste("Bearer", token),
            "Content-Type" = "application/json",
            "Content-Language" = "en-US"
          ) |>
          httr2::req_perform()

        # Check for HTTP errors
        if (httr2::resp_status(response) >= 400) {
          body_text <- tryCatch(
            httr2::resp_body_string(response),
            error = function(e) "(Could not read response body)"
          )
          return(list(
            success = FALSE,
            error = paste0("HTTP ", httr2::resp_status(response), ": ", body_text)
          ))
        }

        # Parse response
        result <- httr2::resp_body_json(response)

        # Extract condition aspect
        conditions <- NULL
        if (!is.null(result$aspects) && length(result$aspects) > 0) {
          # Find condition aspect by searching through aspects list
          for (i in seq_along(result$aspects)) {
            aspect <- result$aspects[[i]]
            if (!is.null(aspect$localizedAspectName) && aspect$localizedAspectName == "Condition") {
              # Found condition aspect - extract values
              if (!is.null(aspect$aspectValues) && length(aspect$aspectValues) > 0) {
                conditions <- sapply(aspect$aspectValues, function(v) {
                  if (!is.null(v$localizedValue)) v$localizedValue else NA
                })
                conditions <- conditions[!is.na(conditions)]
              }
              break
            }
          }
        }

        # Cache result
        cache_data <- list(
          success = TRUE,
          conditions = conditions,
          aspects = result$aspects
        )
        private$cache_category_aspects[[cache_key]] <- cache_data

        return(cache_data)

      }, error = function(e) {
        return(list(
          success = FALSE,
          error = paste("API error:", e$message)
        ))
      })
    },

    get_suggested_categories = function(query_text) {
      # Implement: POST /commerce/taxonomy/v1/category_tree/MARKETPLACE_ID/get_category_suggestions
      stop("Not implemented yet - see Task 3B.1")
    }
  ),
  private = list(
    base_url = NULL,
    marketplace_id = NULL,
    cache_category_aspects = list()  # Cache to avoid repeated API calls
  )
)

# Initialize eBay API connection
#' @export
init_ebay_api <- function(environment = NULL) {
  config <- EbayAPIConfig$new(environment)
  oauth <- EbayOAuth$new(config)

  # Inventory API (DEPRECATED for listings - kept for reference only)
  # NOTE: Cannot create cross-border listings (Error 25002 - no Item.Country field)
  # Use Trading API instead for listing creation
  inventory_api <- EbayInventoryAPI$new(oauth, config)

  # Media API (still needed for image uploads)
  media_api <- EbayMediaAPI$new(config, oauth)

  # Taxonomy API (category lookups)
  taxonomy_api <- EbayTaxonomyAPI$new(oauth, config)

  # Trading API (NEW - primary listing API for cross-border sellers)
  trading_api <- EbayTradingAPI$new(oauth, config)

  return(list(
    config = config,
    oauth = oauth,
    inventory = inventory_api,  # DEPRECATED for listings
    media = media_api,
    taxonomy = taxonomy_api,
    trading = trading_api  # NEW PRIMARY API
  ))
}
