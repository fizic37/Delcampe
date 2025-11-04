#' Authentication System Functions
#'
#' @description
#' Provides comprehensive user authentication, authorization, and management
#' functions for the Delcampe application. Implements SHA-256 password hashing,
#' role-based access control (master/admin/user), and master user protection.
#'
#' @name auth_system
#' @keywords internal


# ==== PASSWORD HASHING FUNCTIONS ====

#' Hash Password Using SHA-256
#'
#' @description
#' Creates a SHA-256 hash of the provided password string.
#' CRITICAL: Uses serialize=FALSE to hash the string content, not R object structure.
#'
#' @param password Character string - the plain text password to hash
#'
#' @return Character string containing the 64-character SHA-256 hex hash
#'
#' @examples
#' \dontrun{
#' hash <- hash_password("my_secure_password")
#' # Returns: "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8"
#' }
#'
#' @export
hash_password <- function(password) {
  # CRITICAL: serialize=FALSE is required for string input (not R's default!)
  # Without it, we'd hash the R object structure instead of the string content
  digest::digest(password, algo = "sha256", serialize = FALSE)
}


#' Verify Password Against Stored Hash
#'
#' @description
#' Compares a plain text password with a stored hash to verify authentication.
#' Uses constant-time comparison via identical() to prevent timing attacks.
#'
#' @param password Character string - plain text password to verify
#' @param stored_hash Character string - the stored SHA-256 hash to compare against
#'
#' @return Logical - TRUE if password matches hash, FALSE otherwise
#'
#' @examples
#' \dontrun{
#' hash <- hash_password("correct_password")
#' verify_password("correct_password", hash)  # TRUE
#' verify_password("wrong_password", hash)    # FALSE
#' }
#'
#' @export
verify_password <- function(password, stored_hash) {
  computed_hash <- hash_password(password)
  identical(computed_hash, stored_hash)
}


# ==== USER AUTHENTICATION ====

#' Authenticate User Credentials
#'
#' @description
#' Verifies user credentials (email + password) against database.
#' Updates last_login timestamp on successful authentication.
#' Returns generic error messages for security (doesn't reveal if email exists).
#'
#' @param email Character string - user email address
#' @param password Character string - plain text password
#'
#' @return List with components:
#' \describe{
#'   \item{success}{Logical - TRUE if authenticated, FALSE otherwise}
#'   \item{message}{Character - result message}
#'   \item{user}{List or NULL - complete user record if authenticated, NULL if failed}
#' }
#'
#' @examples
#' \dontrun{
#' result <- authenticate_user("user@example.com", "password123")
#' if (result$success) {
#'   message("Welcome ", result$user$email)
#' }
#' }
#'
#' @export
authenticate_user <- function(email, password) {
  tryCatch({
    # Validate inputs
    if (is.null(email) || is.null(password) ||
        email == "" || password == "") {
      return(list(
        success = FALSE,
        message = "Email and password are required",
        user = NULL
      ))
    }

    # Open connection
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    # CRITICAL: Always use on.exit for cleanup
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    # CRITICAL: Use parameterized query (prevent SQL injection)
    user <- DBI::dbGetQuery(
      con,
      "SELECT * FROM users WHERE email = ? AND active = 1",
      params = list(email)
    )

    # Check if user exists
    if (nrow(user) == 0) {
      return(list(
        success = FALSE,
        message = "Invalid email or password",  # Generic message (security)
        user = NULL
      ))
    }

    # Verify password
    if (!verify_password(password, user$password_hash[1])) {
      return(list(
        success = FALSE,
        message = "Invalid email or password",  # Same message (security)
        user = NULL
      ))
    }

    # Update last login
    DBI::dbExecute(
      con,
      "UPDATE users SET last_login = ? WHERE id = ?",
      params = list(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), user$id[1])
    )

    # Success
    message("✅ User authenticated: ", email)
    return(list(
      success = TRUE,
      message = "Authentication successful",
      user = as.list(user[1, ])  # Convert first row to list
    ))

  }, error = function(e) {
    # PATTERN: Consistent error message format
    message("❌ Error in authenticate_user: ", e$message)
    return(list(success = FALSE, message = "Authentication error", user = NULL))
  })
}


# ==== USER MANAGEMENT ====

#' Create New User
#'
#' @description
#' Creates a new user account with hashed password and role assignment.
#' Validates email uniqueness and role values.
#'
#' @param email Character string - user email address (must be unique)
#' @param password Character string - plain text password (will be hashed)
#' @param role Character string - user role: "master", "admin", or "user"
#' @param created_by Character string - email of user creating this account
#'
#' @return List with components:
#' \describe{
#'   \item{success}{Logical - TRUE if created, FALSE if error}
#'   \item{message}{Character - result message}
#'   \item{user_id}{Integer or NULL - ID of created user}
#' }
#'
#' @examples
#' \dontrun{
#' result <- create_user("alice@example.com", "secure_pass", "user", "admin@example.com")
#' if (result$success) {
#'   message("User created with ID: ", result$user_id)
#' }
#' }
#'
#' @export
create_user <- function(email, password, role, created_by) {
  tryCatch({
    # Validate inputs
    if (is.null(email) || email == "") {
      return(list(success = FALSE, message = "Email is required", user_id = NULL))
    }

    if (is.null(password) || password == "") {
      return(list(success = FALSE, message = "Password is required", user_id = NULL))
    }

    if (!role %in% c("master", "admin", "user")) {
      return(list(success = FALSE, message = "Invalid role. Must be: master, admin, or user", user_id = NULL))
    }

    # Open connection
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    # Check if email already exists
    existing <- DBI::dbGetQuery(
      con,
      "SELECT id FROM users WHERE email = ?",
      params = list(email)
    )

    if (nrow(existing) > 0) {
      return(list(success = FALSE, message = "Email already exists", user_id = NULL))
    }

    # Hash password
    password_hash <- hash_password(password)

    # Determine if this is a master user
    is_master <- if (role == "master") 1 else 0

    # Create user
    DBI::dbExecute(
      con,
      "INSERT INTO users (email, password_hash, role, is_master, created_at, created_by, active)
       VALUES (?, ?, ?, ?, ?, ?, 1)",
      params = list(
        email,
        password_hash,
        role,
        is_master,
        format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        created_by
      )
    )

    # Get new user ID
    user_id <- DBI::dbGetQuery(con, "SELECT last_insert_rowid() as id")$id

    message("✅ User created: ", email, " (ID: ", user_id, ", role: ", role, ")")
    return(list(success = TRUE, message = "User created successfully", user_id = user_id))

  }, error = function(e) {
    message("❌ Error in create_user: ", e$message)
    return(list(success = FALSE, message = paste("Error:", e$message), user_id = NULL))
  })
}


#' Get User By Email
#'
#' @description
#' Retrieves complete user record by email address.
#'
#' @param email Character string - user email address
#'
#' @return List containing user data, or NULL if not found
#'
#' @examples
#' \dontrun{
#' user <- get_user_by_email("alice@example.com")
#' if (!is.null(user)) {
#'   message("User role: ", user$role)
#' }
#' }
#'
#' @export
get_user_by_email <- function(email) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    user <- DBI::dbGetQuery(
      con,
      "SELECT * FROM users WHERE email = ? AND active = 1",
      params = list(email)
    )

    if (nrow(user) == 0) {
      return(NULL)
    }

    return(as.list(user[1, ]))

  }, error = function(e) {
    message("❌ Error in get_user_by_email: ", e$message)
    return(NULL)
  })
}


#' Update User Password
#'
#' @description
#' Changes a user's password with proper permission checks.
#' Users can change their own password. Admins/masters can change any non-master user's password.
#' Master users cannot have passwords changed by other masters.
#'
#' @param email Character string - email of user whose password to change
#' @param new_password Character string - new plain text password
#' @param current_user_email Character string - email of user making the change
#' @param current_user_role Character string - role of user making the change
#'
#' @return List with components:
#' \describe{
#'   \item{success}{Logical - TRUE if updated, FALSE if error}
#'   \item{message}{Character - result message}
#' }
#'
#' @examples
#' \dontrun{
#' # User changes own password
#' result <- update_user_password("alice@example.com", "new_pass", "alice@example.com", "user")
#'
#' # Admin changes user password
#' result <- update_user_password("bob@example.com", "new_pass", "admin@example.com", "admin")
#' }
#'
#' @export
update_user_password <- function(email, new_password, current_user_email, current_user_role) {
  tryCatch({
    # Validate inputs
    if (is.null(new_password) || new_password == "") {
      return(list(success = FALSE, message = "New password is required"))
    }

    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    # Get target user
    target_user <- DBI::dbGetQuery(
      con,
      "SELECT id, email, role, is_master FROM users WHERE email = ? AND active = 1",
      params = list(email)
    )

    if (nrow(target_user) == 0) {
      return(list(success = FALSE, message = "User not found"))
    }

    # Permission check
    # 1. Users can change their own password
    if (email == current_user_email) {
      # Allow - user changing own password
    }
    # 2. Admins/masters can change non-master user passwords
    else if (current_user_role %in% c("admin", "master")) {
      # Check if target is a master user
      if (target_user$is_master[1] == 1) {
        return(list(success = FALSE, message = "Cannot change master user password"))
      }
      # Allow - admin changing regular user password
    }
    # 3. Regular users cannot change other users' passwords
    else {
      return(list(success = FALSE, message = "Insufficient permissions"))
    }

    # Hash new password
    new_hash <- hash_password(new_password)

    # Update password
    DBI::dbExecute(
      con,
      "UPDATE users SET password_hash = ? WHERE id = ?",
      params = list(new_hash, target_user$id[1])
    )

    message("✅ Password updated for: ", email)
    return(list(success = TRUE, message = "Password updated successfully"))

  }, error = function(e) {
    message("❌ Error in update_user_password: ", e$message)
    return(list(success = FALSE, message = paste("Error:", e$message)))
  })
}


#' List Users
#'
#' @description
#' Retrieves list of users with role-based filtering.
#' Admins/masters see all users. Regular users see only themselves.
#'
#' @param current_user_role Character string - role of user requesting list
#'
#' @return Data frame with user information (excluding password hashes)
#'
#' @examples
#' \dontrun{
#' # Admin view - sees all users
#' users <- list_users("admin")
#'
#' # User view - sees only self
#' users <- list_users("user")
#' }
#'
#' @export
list_users <- function(current_user_role) {
  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    # Query users (exclude password hash for security)
    if (current_user_role %in% c("admin", "master")) {
      # Admins/masters see all users
      users <- DBI::dbGetQuery(
        con,
        "SELECT id, email, role, is_master, created_at, created_by, last_login, active
         FROM users
         ORDER BY is_master DESC, role, email"
      )
    } else {
      # Regular users see empty list (or could filter to just themselves)
      users <- data.frame(
        id = integer(),
        email = character(),
        role = character(),
        is_master = logical(),
        created_at = character(),
        created_by = character(),
        last_login = character(),
        active = logical()
      )
    }

    return(users)

  }, error = function(e) {
    message("❌ Error in list_users: ", e$message)
    return(data.frame())
  })
}


#' Delete User (Soft Delete)
#'
#' @description
#' Deactivates a user account (soft delete by setting active = 0).
#' Enforces master user protection - master users cannot be deleted.
#' Users cannot delete themselves.
#'
#' @param email Character string - email of user to delete
#' @param current_user_email Character string - email of user performing deletion
#' @param current_user_role Character string - role of user performing deletion
#'
#' @return List with components:
#' \describe{
#'   \item{success}{Logical - TRUE if deleted, FALSE if error}
#'   \item{message}{Character - result message}
#' }
#'
#' @examples
#' \dontrun{
#' result <- delete_user("bob@example.com", "admin@example.com", "admin")
#' if (result$success) {
#'   message("User deleted successfully")
#' }
#' }
#'
#' @export
delete_user <- function(email, current_user_email, current_user_role) {
  # Check permissions
  if (!current_user_role %in% c("admin", "master")) {
    return(list(success = FALSE, message = "Insufficient permissions"))
  }

  tryCatch({
    con <- DBI::dbConnect(RSQLite::SQLite(), get_db_path())
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    # Get target user
    target_user <- DBI::dbGetQuery(
      con,
      "SELECT id, email, is_master FROM users WHERE email = ?",
      params = list(email)
    )

    if (nrow(target_user) == 0) {
      return(list(success = FALSE, message = "User not found"))
    }

    # CRITICAL: Master user protection (per CLAUDE.md)
    if (target_user$is_master[1] == 1) {
      return(list(success = FALSE, message = "Cannot delete master users"))
    }

    # Cannot delete yourself
    if (email == current_user_email) {
      return(list(success = FALSE, message = "Cannot delete your own account"))
    }

    # Soft delete (set active = 0)
    DBI::dbExecute(
      con,
      "UPDATE users SET active = 0 WHERE email = ?",
      params = list(email)
    )

    message("✅ User deleted: ", email)
    return(list(success = TRUE, message = "User deleted successfully"))

  }, error = function(e) {
    message("❌ Error deleting user: ", e$message)
    return(list(success = FALSE, message = paste("Error:", e$message)))
  })
}
