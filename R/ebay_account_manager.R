#' eBay Account Manager
#'
#' Manages multiple eBay seller accounts with token persistence
#' and automatic migration from single-account format
#'
#' @description
#' R6 class for managing multiple eBay seller accounts. Handles storage,
#' switching, and persistence of OAuth tokens for multiple accounts.
#'
#' @export
EbayAccountManager <- R6::R6Class("EbayAccountManager",
  private = list(
    accounts_file = "inst/app/data/ebay_accounts.rds",
    accounts = list(),
    active_account_key = NULL
  ),

  public = list(
    #' @description
    #' Initialize account manager and load existing accounts
    initialize = function() {
      # Load existing accounts from file
      self$load_accounts()

      # Auto-migrate old single-account tokens if they exist
      self$migrate_old_tokens()
    },

    #' @description
    #' Add newly authenticated account
    #'
    #' @param user_id eBay user ID
    #' @param username eBay username
    #' @param environment Environment (sandbox or production)
    #' @param access_token OAuth access token
    #' @param refresh_token OAuth refresh token
    #' @param token_expiry Token expiration time (POSIXct)
    #'
    #' @return Account key (character)
    add_account = function(user_id, username, environment,
                          access_token, refresh_token, token_expiry) {
      # Create unique account key
      account_key <- paste(user_id, environment, sep = "_")

      # Store account details
      private$accounts[[account_key]] <- list(
        user_id = user_id,
        username = username,
        environment = environment,
        access_token = access_token,
        refresh_token = refresh_token,
        token_expiry = token_expiry,
        connected_at = Sys.time(),
        last_used = Sys.time()
      )

      # Set as active if first account or no active account
      if (is.null(private$active_account_key) ||
          !private$active_account_key %in% names(private$accounts)) {
        private$active_account_key <- account_key
      }

      self$save_accounts()

      message("✅ Added account: ", username, " (", environment, ")")
      return(account_key)
    },

    #' @description
    #' Remove specific account
    #'
    #' @param account_key Account key to remove
    #'
    #' @return TRUE if successful, FALSE if account not found
    remove_account = function(account_key) {
      if (!account_key %in% names(private$accounts)) {
        warning("Account not found: ", account_key)
        return(FALSE)
      }

      username <- private$accounts[[account_key]]$username
      private$accounts[[account_key]] <- NULL

      # If removed active account, switch to first available
      if (private$active_account_key == account_key) {
        if (length(private$accounts) > 0) {
          private$active_account_key <- names(private$accounts)[1]
          message("   Switched to: ", private$accounts[[private$active_account_key]]$username)
        } else {
          private$active_account_key <- NULL
          message("   No accounts remaining")
        }
      }

      self$save_accounts()
      message("✅ Removed account: ", username)
      return(TRUE)
    },

    #' @description
    #' Switch active account
    #'
    #' @param account_key Account key to make active
    #'
    #' @return TRUE if successful, FALSE if account not found
    set_active_account = function(account_key) {
      if (!account_key %in% names(private$accounts)) {
        warning("Account not found: ", account_key)
        return(FALSE)
      }

      private$active_account_key <- account_key
      private$accounts[[account_key]]$last_used <- Sys.time()
      self$save_accounts()

      message("✅ Active account: ", private$accounts[[account_key]]$username)
      return(TRUE)
    },

    #' @description
    #' Get active account details
    #'
    #' @return List with account details, or NULL if no active account
    get_active_account = function() {
      if (is.null(private$active_account_key)) return(NULL)
      if (!private$active_account_key %in% names(private$accounts)) return(NULL)

      account <- private$accounts[[private$active_account_key]]
      account$account_key <- private$active_account_key  # Include key
      return(account)
    },

    #' @description
    #' Get all connected accounts
    #'
    #' @return Named list of all accounts
    get_all_accounts = function() {
      return(private$accounts)
    },

    #' @description
    #' Get account choices formatted for dropdown UI
    #'
    #' @return Named list for selectInput choices, or NULL if no accounts
    get_account_choices = function() {
      if (length(private$accounts) == 0) return(NULL)

      # Build choices as a list (more reliable than named vectors in selectInput)
      keys <- names(private$accounts)
      choices <- list()

      for (key in keys) {
        account <- private$accounts[[key]]
        label <- paste0(account$username, " (", account$environment, ")")
        choices[[label]] <- key
      }

      return(choices)
    },

    #' @description
    #' Update tokens for specific account (after refresh)
    #'
    #' @param account_key Account key to update
    #' @param access_token New access token
    #' @param refresh_token New refresh token
    #' @param token_expiry New token expiry
    #'
    #' @return TRUE if successful, FALSE if account not found
    update_account_tokens = function(account_key, access_token,
                                    refresh_token, token_expiry) {
      if (!account_key %in% names(private$accounts)) {
        warning("Account not found for token update: ", account_key)
        return(FALSE)
      }

      private$accounts[[account_key]]$access_token <- access_token
      private$accounts[[account_key]]$refresh_token <- refresh_token
      private$accounts[[account_key]]$token_expiry <- token_expiry

      self$save_accounts()
      return(TRUE)
    },

    #' @description
    #' Save accounts to file
    save_accounts = function() {
      # Ensure directory exists
      dir.create(dirname(private$accounts_file), recursive = TRUE, showWarnings = FALSE)

      data <- list(
        accounts = private$accounts,
        active_account = private$active_account_key,
        last_updated = Sys.time()
      )

      saveRDS(data, file = private$accounts_file)
    },

    #' @description
    #' Load accounts from file
    load_accounts = function() {
      if (file.exists(private$accounts_file)) {
        tryCatch({
          data <- readRDS(private$accounts_file)
          private$accounts <- data$accounts
          private$active_account_key <- data$active_account

          message("📂 Loaded ", length(private$accounts), " account(s)")
        }, error = function(e) {
          warning("Failed to load accounts: ", e$message)
        })
      }
    },

    #' @description
    #' Migrate old single-account tokens to multi-account format
    migrate_old_tokens = function() {
      # Check both possible old token locations
      old_file <- if (file.exists("data/ebay_tokens.rds")) {
        "data/ebay_tokens.rds"
      } else if (file.exists("inst/app/data/ebay_tokens.rds")) {
        "inst/app/data/ebay_tokens.rds"
      } else {
        NULL
      }

      new_file <- private$accounts_file

      # Only migrate if old exists and new doesn't
      if (!is.null(old_file) && !file.exists(new_file)) {
        message("🔄 Migrating old eBay tokens to multi-account format...")

        tryCatch({
          old_data <- readRDS(old_file)

          # Initialize temporary API with old tokens
          temp_api <- init_ebay_api(environment = old_data$environment)
          temp_api$oauth$set_tokens(
            old_data$access_token,
            old_data$refresh_token,
            old_data$token_expiry
          )

          # Fetch user identity
          user_info <- temp_api$oauth$get_user_info()

          if (user_info$success) {
            # Add as first account
            self$add_account(
              user_id = user_info$user_id,
              username = user_info$username,
              environment = old_data$environment,
              access_token = old_data$access_token,
              refresh_token = old_data$refresh_token,
              token_expiry = old_data$token_expiry
            )

            # Backup old file
            file.rename(old_file, paste0(old_file, ".backup"))

            message("✅ Migration successful: ", user_info$username)
          } else {
            warning("Failed to fetch user info during migration: ", user_info$error)
          }
        }, error = function(e) {
          warning("Token migration failed: ", e$message)
        })
      }
    }
  )
)
