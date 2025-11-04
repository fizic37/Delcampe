# Tests for auth_system.R
# Covers user authentication, authorization, password management, and user CRUD

# ==== PASSWORD HASHING TESTS ====

test_that("hash_password creates consistent SHA-256 hash", {
  hash1 <- hash_password("test_password")
  hash2 <- hash_password("test_password")

  # Should be deterministic
  expect_equal(hash1, hash2)

  # SHA-256 produces 64 hex characters
  expect_equal(nchar(hash1), 64)

  # Should be character string
  expect_type(hash1, "character")
})

test_that("hash_password produces different hashes for different passwords", {
  hash1 <- hash_password("password1")
  hash2 <- hash_password("password2")

  expect_false(hash1 == hash2)
})

test_that("verify_password correctly verifies matching password", {
  password <- "my_secure_password"
  hash <- hash_password(password)

  expect_true(verify_password(password, hash))
})

test_that("verify_password rejects non-matching password", {
  hash <- hash_password("correct_password")

  expect_false(verify_password("wrong_password", hash))
})


# ==== USER CREATION TESTS ====

test_that("create_user creates new user successfully", {
  with_test_db({
    result <- create_user(
      email = "alice@example.com",
      password = "password123",
      role = "user",
      created_by = "admin@example.com"
    )

    expect_true(result$success)
    expect_type(result$user_id, "integer")
    expect_equal(result$message, "User created successfully")

    # Verify in database
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    user <- DBI::dbGetQuery(
      con,
      "SELECT * FROM users WHERE email = ?",
      params = list("alice@example.com")
    )

    expect_equal(nrow(user), 1)
    expect_equal(user$role, "user")
    expect_equal(user$is_master, 0)
    expect_true(user$active == 1)
    # Password should be hashed, not plaintext
    expect_false(user$password_hash == "password123")
  })
})

test_that("create_user rejects duplicate email", {
  with_test_db({
    # Create first user
    create_user("alice@example.com", "pass1", "user", "admin@example.com")

    # Try to create duplicate
    result <- create_user("alice@example.com", "pass2", "user", "admin@example.com")

    expect_false(result$success)
    expect_true(grepl("already exists", result$message, ignore.case = TRUE))
  })
})

test_that("create_user rejects empty email", {
  with_test_db({
    result <- create_user("", "password123", "user", "admin@example.com")

    expect_false(result$success)
    expect_true(grepl("required", result$message, ignore.case = TRUE))
  })
})

test_that("create_user rejects empty password", {
  with_test_db({
    result <- create_user("alice@example.com", "", "user", "admin@example.com")

    expect_false(result$success)
    expect_true(grepl("required", result$message, ignore.case = TRUE))
  })
})

test_that("create_user rejects invalid role", {
  with_test_db({
    result <- create_user("alice@example.com", "pass", "invalid_role", "admin@example.com")

    expect_false(result$success)
    expect_true(grepl("Invalid role", result$message))
  })
})

test_that("create_user sets is_master correctly for master role", {
  with_test_db({
    result <- create_user("master@example.com", "pass", "master", "system")

    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    user <- DBI::dbGetQuery(
      con,
      "SELECT is_master FROM users WHERE email = ?",
      params = list("master@example.com")
    )

    expect_equal(user$is_master, 1)
  })
})

test_that("create_user sets is_master to 0 for non-master roles", {
  with_test_db({
    result <- create_user("admin@example.com", "pass", "admin", "master@example.com")

    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    user <- DBI::dbGetQuery(
      con,
      "SELECT is_master FROM users WHERE email = ?",
      params = list("admin@example.com")
    )

    expect_equal(user$is_master, 0)
  })
})


# ==== AUTHENTICATION TESTS ====

test_that("authenticate_user succeeds with correct credentials", {
  with_test_db({
    create_user("alice@example.com", "correct_password", "user", "admin@example.com")

    result <- authenticate_user("alice@example.com", "correct_password")

    expect_true(result$success)
    expect_equal(result$message, "Authentication successful")
    expect_false(is.null(result$user))
    expect_equal(result$user$email, "alice@example.com")
    expect_equal(result$user$role, "user")
  })
})

test_that("authenticate_user fails with wrong password", {
  with_test_db({
    create_user("alice@example.com", "correct_password", "user", "admin@example.com")

    result <- authenticate_user("alice@example.com", "wrong_password")

    expect_false(result$success)
    expect_equal(result$message, "Invalid email or password")
    expect_null(result$user)
  })
})

test_that("authenticate_user fails with nonexistent email", {
  with_test_db({
    result <- authenticate_user("nonexistent@example.com", "any_password")

    expect_false(result$success)
    expect_equal(result$message, "Invalid email or password")
    expect_null(result$user)
  })
})

test_that("authenticate_user rejects empty email", {
  with_test_db({
    result <- authenticate_user("", "password")

    expect_false(result$success)
  })
})

test_that("authenticate_user rejects empty password", {
  with_test_db({
    result <- authenticate_user("alice@example.com", "")

    expect_false(result$success)
  })
})

test_that("authenticate_user rejects NULL email", {
  with_test_db({
    result <- authenticate_user(NULL, "password")

    expect_false(result$success)
  })
})

test_that("authenticate_user rejects NULL password", {
  with_test_db({
    result <- authenticate_user("alice@example.com", NULL)

    expect_false(result$success)
  })
})

test_that("authenticate_user only authenticates active users", {
  with_test_db({
    # Create user and deactivate
    create_user("alice@example.com", "password123", "user", "admin@example.com")

    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    DBI::dbExecute(
      con,
      "UPDATE users SET active = 0 WHERE email = ?",
      params = list("alice@example.com")
    )

    # Try to authenticate inactive user
    result <- authenticate_user("alice@example.com", "password123")

    expect_false(result$success)
  })
})


# ==== USER LOOKUP TESTS ====

test_that("get_user_by_email returns user data", {
  with_test_db({
    create_user("alice@example.com", "password123", "user", "admin@example.com")

    user <- get_user_by_email("alice@example.com")

    expect_false(is.null(user))
    expect_equal(user$email, "alice@example.com")
    expect_equal(user$role, "user")
    expect_type(user$id, "integer")
  })
})

test_that("get_user_by_email returns NULL for nonexistent email", {
  with_test_db({
    user <- get_user_by_email("nonexistent@example.com")

    expect_null(user)
  })
})

test_that("get_user_by_email only returns active users", {
  with_test_db({
    create_user("alice@example.com", "password123", "user", "admin@example.com")

    # Deactivate user
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    DBI::dbExecute(
      con,
      "UPDATE users SET active = 0 WHERE email = ?",
      params = list("alice@example.com")
    )

    user <- get_user_by_email("alice@example.com")

    expect_null(user)
  })
})


# ==== PASSWORD UPDATE TESTS ====

test_that("update_user_password allows user to change own password", {
  with_test_db({
    create_user("alice@example.com", "old_password", "user", "admin@example.com")

    result <- update_user_password(
      email = "alice@example.com",
      new_password = "new_password",
      current_user_email = "alice@example.com",
      current_user_role = "user"
    )

    expect_true(result$success)

    # Verify new password works
    auth_result <- authenticate_user("alice@example.com", "new_password")
    expect_true(auth_result$success)
  })
})

test_that("update_user_password allows admin to change user password", {
  with_test_db({
    create_user("alice@example.com", "old_password", "user", "admin@example.com")
    create_user("admin@example.com", "admin_pass", "admin", "system")

    result <- update_user_password(
      email = "alice@example.com",
      new_password = "new_password",
      current_user_email = "admin@example.com",
      current_user_role = "admin"
    )

    expect_true(result$success)

    # Verify new password works
    auth_result <- authenticate_user("alice@example.com", "new_password")
    expect_true(auth_result$success)
  })
})

test_that("update_user_password prevents admin from changing master password", {
  with_test_db({
    create_user("master@example.com", "master_pass", "master", "system")
    create_user("admin@example.com", "admin_pass", "admin", "system")

    result <- update_user_password(
      email = "master@example.com",
      new_password = "new_password",
      current_user_email = "admin@example.com",
      current_user_role = "admin"
    )

    expect_false(result$success)
    expect_true(grepl("Cannot change master", result$message, ignore.case = TRUE))
  })
})

test_that("update_user_password prevents regular user from changing other users' passwords", {
  with_test_db({
    create_user("alice@example.com", "alice_pass", "user", "admin@example.com")
    create_user("bob@example.com", "bob_pass", "user", "admin@example.com")

    result <- update_user_password(
      email = "bob@example.com",
      new_password = "new_password",
      current_user_email = "alice@example.com",
      current_user_role = "user"
    )

    expect_false(result$success)
    expect_true(grepl("Insufficient permissions", result$message))
  })
})

test_that("update_user_password rejects empty new password", {
  with_test_db({
    create_user("alice@example.com", "old_password", "user", "admin@example.com")

    result <- update_user_password(
      email = "alice@example.com",
      new_password = "",
      current_user_email = "alice@example.com",
      current_user_role = "user"
    )

    expect_false(result$success)
    expect_true(grepl("required", result$message, ignore.case = TRUE))
  })
})


# ==== USER LISTING TESTS ====

test_that("list_users returns all users for admin", {
  with_test_db({
    create_user("alice@example.com", "pass1", "user", "admin@example.com")
    create_user("bob@example.com", "pass2", "user", "admin@example.com")
    create_user("admin@example.com", "admin_pass", "admin", "system")

    users <- list_users("admin")

    expect_s3_class(users, "data.frame")
    expect_gte(nrow(users), 3)
    expect_true("email" %in% colnames(users))
    expect_true("role" %in% colnames(users))
    # Should NOT include password_hash
    expect_false("password_hash" %in% colnames(users))
  })
})

test_that("list_users returns all users for master", {
  with_test_db({
    create_user("alice@example.com", "pass1", "user", "admin@example.com")
    create_user("master@example.com", "master_pass", "master", "system")

    users <- list_users("master")

    expect_s3_class(users, "data.frame")
    expect_gte(nrow(users), 2)
  })
})

test_that("list_users returns empty for regular user", {
  with_test_db({
    users <- list_users("user")

    expect_s3_class(users, "data.frame")
    expect_equal(nrow(users), 0)
  })
})


# ==== USER DELETION TESTS ====

test_that("delete_user successfully deletes regular user", {
  with_test_db({
    create_user("alice@example.com", "pass", "user", "admin@example.com")
    create_user("admin@example.com", "admin_pass", "admin", "system")

    result <- delete_user(
      email = "alice@example.com",
      current_user_email = "admin@example.com",
      current_user_role = "admin"
    )

    expect_true(result$success)

    # Verify user is inactive (soft delete)
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    user <- DBI::dbGetQuery(
      con,
      "SELECT active FROM users WHERE email = ?",
      params = list("alice@example.com")
    )

    expect_equal(user$active, 0)
  })
})

test_that("delete_user prevents deleting master users", {
  with_test_db({
    create_user("master1@example.com", "pass1", "master", "system")
    create_user("master2@example.com", "pass2", "master", "system")

    result <- delete_user(
      email = "master1@example.com",
      current_user_email = "master2@example.com",
      current_user_role = "master"
    )

    expect_false(result$success)
    expect_true(grepl("Cannot delete master", result$message, ignore.case = TRUE))
  })
})

test_that("delete_user prevents self-deletion", {
  with_test_db({
    create_user("admin@example.com", "admin_pass", "admin", "system")

    result <- delete_user(
      email = "admin@example.com",
      current_user_email = "admin@example.com",
      current_user_role = "admin"
    )

    expect_false(result$success)
    expect_true(grepl("Cannot delete your own account", result$message))
  })
})

test_that("delete_user requires admin or master role", {
  with_test_db({
    create_user("alice@example.com", "pass1", "user", "admin@example.com")
    create_user("bob@example.com", "pass2", "user", "admin@example.com")

    result <- delete_user(
      email = "bob@example.com",
      current_user_email = "alice@example.com",
      current_user_role = "user"
    )

    expect_false(result$success)
    expect_true(grepl("Insufficient permissions", result$message))
  })
})

test_that("delete_user returns error for nonexistent user", {
  with_test_db({
    create_user("admin@example.com", "admin_pass", "admin", "system")

    result <- delete_user(
      email = "nonexistent@example.com",
      current_user_email = "admin@example.com",
      current_user_role = "admin"
    )

    expect_false(result$success)
    expect_true(grepl("not found", result$message, ignore.case = TRUE))
  })
})


# ==== DATABASE INTEGRATION TESTS ====

test_that("users table exists after database initialization", {
  with_test_db({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    tables <- DBI::dbListTables(con)
    expect_true("users" %in% tables)
  })
})

test_that("users table has correct schema", {
  with_test_db({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    columns <- DBI::dbGetQuery(con, "PRAGMA table_info(users)")

    expected_columns <- c("id", "email", "password_hash", "role", "is_master",
                          "created_at", "created_by", "last_login", "active")

    expect_true(all(expected_columns %in% columns$name))
  })
})

test_that("master users are seeded on database initialization", {
  with_test_db({
    con <- DBI::dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(DBI::dbDisconnect(con), add = TRUE)

    masters <- DBI::dbGetQuery(
      con,
      "SELECT COUNT(*) as count FROM users WHERE is_master = 1"
    )

    expect_gte(masters$count, 2)
  })
})
