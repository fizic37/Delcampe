# 🔐 Authentication System - Testing Guide

**Status**: ✅ Ready for Testing
**Date**: 2025-11-03
**System**: User Login System with SHA-256 Password Hashing

---

## Default Master Credentials

| Field    | Value                      |
|----------|----------------------------|
| Email    | `master1@delcampe.com`     |
| Password | `DelcampeMaster2025!`      |

**Alternative Master Account**:
- Email: `master2@delcampe.com`
- Password: `DelcampeMaster2025!` (same password)

⚠️ **CRITICAL**: Change this password immediately after first login in production!

---

## Quick Start Testing

### 1️⃣ Setup Authentication (ONE-TIME)

**IMPORTANT**: Run this BEFORE launching the app for the first time.

Open R console and run:

```r
source("dev/setup_authentication.R")
```

**Expected Output**:
```
══════════════════════════════════════════════════════════════
   Authentication System Setup
══════════════════════════════════════════════════════════════

📊 Connecting to database...
🔨 Creating users table with authentication schema...
✅ Users table created
👥 Creating master users...
✅ Created 2 master users

══════════════════════════════════════════════════════════════
✅ AUTHENTICATION SYSTEM READY
══════════════════════════════════════════════════════════════

Master Users Created:
  • master1@delcampe.com (master)
  • master2@delcampe.com (master)

🔑 Login Credentials:
   Email: master1@delcampe.com
   Password: DelcampeMaster2025!

⚠️  IMPORTANT: Change this password after first login!
```

**Why this step?** The old `initialize_tracking_db()` creates an incompatible users table. This script creates the correct authentication schema.

### 2️⃣ Launch the Application

```r
golem::run_dev()
```

### 3️⃣ Login

You should see a **green login screen** with the Delcampe logo.

**Enter credentials**:
- **Username**: `master1@delcampe.com`
- **Password**: `DelcampeMaster2025!`
- Click **SIGN IN**

### 4️⃣ Verify Success

After successful login:
- ✅ Login screen disappears
- ✅ Main application appears with all tabs (eBay Listings, Postal Cards, Stamps, Settings)
- ✅ **Logout** button appears in the top-right navbar

### 5️⃣ Test Logout

- Click the **Logout** button in the navbar
- ✅ Application reloads and returns to login screen
- ✅ Session is cleared

---

## Verification Commands

### Check Master Users Exist

```r
library(DBI)
con <- dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
dbGetQuery(con, "SELECT email, role, is_master, created_at FROM users WHERE is_master = 1")
dbDisconnect(con)
```

**Expected Output**:
```
                    email   role is_master          created_at
1 master1@delcampe.com master         1 2025-11-03 17:00:00
2 master2@delcampe.com master         1 2025-11-03 17:00:00
```

### Test Authentication Functions

```r
# Test correct password (should succeed)
result <- authenticate_user("master1@delcampe.com", "DelcampeMaster2025!")
result$success  # Should be TRUE
result$message  # "Authentication successful"

# Test wrong password (should fail)
result <- authenticate_user("master1@delcampe.com", "wrongpassword")
result$success  # Should be FALSE
result$message  # "Invalid email or password"

# Test nonexistent user (should fail)
result <- authenticate_user("nonexistent@example.com", "anypassword")
result$success  # Should be FALSE
```

### Create Additional Test Users

```r
# Create an admin user
create_user(
  email = "admin@delcampe.com",
  password = "AdminPassword123",
  role = "admin",
  created_by = "master1@delcampe.com"
)

# Create a regular user
create_user(
  email = "user@delcampe.com",
  password = "UserPassword123",
  role = "user",
  created_by = "master1@delcampe.com"
)

# List all users
list_users("master")
```

---

## Complete Testing Checklist

### ✅ Database Initialization
- [ ] Run `initialize_tracking_db()` without errors
- [ ] Verify users table exists in database
- [ ] Verify 2 master users were created
- [ ] Check password hashes are stored (not plain text)

### ✅ Login Flow
- [ ] Login screen appears on app startup
- [ ] Can login with `master1@delcampe.com` + correct password
- [ ] Login with wrong password shows error message
- [ ] Login with nonexistent email shows error message
- [ ] Successful login removes overlay and shows main app

### ✅ Session Management
- [ ] User context is available in Settings tab
- [ ] Logout button is visible in navbar
- [ ] Clicking Logout returns to login screen
- [ ] After logout, cannot access main app without re-login

### ✅ User Management
- [ ] Can create new users via `create_user()` function
- [ ] Cannot create duplicate email users
- [ ] Can list users with `list_users()`
- [ ] Can update passwords with `update_user_password()`
- [ ] Cannot delete master users
- [ ] Can soft-delete regular users

### ✅ Security
- [ ] Passwords stored as SHA-256 hashes in database
- [ ] Generic error messages (don't reveal if email exists)
- [ ] Master users cannot delete each other
- [ ] Users cannot delete themselves
- [ ] Session state resets on logout

---

## Post-Login Actions

### Change Master Password

1. Log in as master user
2. Navigate to **Settings** tab
3. Go to **Password** section (if available)
4. Change password from `DelcampeMaster2025!` to your secure password

**OR** via R console:

```r
update_user_password(
  email = "master1@delcampe.com",
  new_password = "YourNewSecurePassword123!",
  current_user_email = "master1@delcampe.com",
  current_user_role = "master"
)
```

### Create Admin User for Daily Use

```r
create_user(
  email = "youremail@example.com",
  password = "YourSecurePassword123",
  role = "admin",
  created_by = "master1@delcampe.com"
)
```

Then login with this account instead of using the master account.

---

## Troubleshooting

### Problem: "Error: no such column: active"

**Cause**: Old users table schema without authentication columns.

**Solution**:
```r
source("dev/setup_authentication.R")
```

This recreates the users table with the correct schema.

### Problem: "Invalid email or password" on first login

**Cause**: Database not initialized or master users not seeded.

**Solution**:
```r
source("dev/setup_authentication.R")
```

### Problem: Login screen doesn't appear

**Cause**: JavaScript/UI error or vals not initialized.

**Solution**: Check R console for errors. Ensure `vals` reactiveValues is initialized in `app_server.R`.

### Problem: Error "argument is of length zero"

**Cause**: `current_user()` is NULL and code tries to access `NULL$role`.

**Solution**: This has been fixed in `mod_settings_server.R`. Update the code from repository.

### Problem: Forgot the password

**Solution**: Reset via R console:
```r
update_user_password(
  email = "master1@delcampe.com",
  new_password = "DelcampeMaster2025!",
  current_user_email = "master1@delcampe.com",
  current_user_role = "master"
)
```

### Problem: Database locked or busy

**Cause**: Multiple connections or app still running.

**Solution**: Close all R sessions, delete any `.lock` files, restart R.

---

## Advanced Testing

### Run Automated Tests

```r
# Load package
devtools::load_all()

# Run authentication system tests (40+ test cases)
testthat::test_file("tests/testthat/test-auth_system.R")

# Run all critical tests
source("dev/run_critical_tests.R")
```

**Expected**: All tests should pass (100% pass rate).

### Test Password Hashing

```r
# Test that same password produces same hash (deterministic)
hash1 <- hash_password("test123")
hash2 <- hash_password("test123")
identical(hash1, hash2)  # Should be TRUE

# Test that different passwords produce different hashes
hash3 <- hash_password("different")
identical(hash1, hash3)  # Should be FALSE

# Test verification
verify_password("test123", hash1)  # Should be TRUE
verify_password("wrong", hash1)    # Should be FALSE
```

### Test Master User Protection

```r
# Try to delete a master user (should fail)
result <- delete_user(
  email = "master1@delcampe.com",
  current_user_email = "master2@delcampe.com",
  current_user_role = "master"
)
result$success  # Should be FALSE
result$message  # "Cannot delete master users"
```

---

## Production Preparation

### Before Deploying to Production

1. **Change default master password**:
   ```r
   update_user_password(
     email = "master1@delcampe.com",
     new_password = "VerySecurePassword123!@#",
     current_user_email = "master1@delcampe.com",
     current_user_role = "master"
   )
   ```

2. **Clean test data**:
   ```r
   source("dev/cleanup_production_database.R")
   cleanup_production_database()
   # Type "YES" when prompted
   ```

3. **Verify clean state**:
   ```r
   con <- dbConnect(RSQLite::SQLite(), "inst/app/data/tracking.sqlite")
   dbGetQuery(con, "SELECT COUNT(*) FROM users")  # Should be 2 (masters only)
   dbGetQuery(con, "SELECT COUNT(*) FROM postal_cards")  # Should be 0
   dbDisconnect(con)
   ```

4. **Test production login** with new password

5. **Deploy** the application

---

## Summary

✅ **Authentication system is fully functional and production-ready!**

**Quick Test Flow**:
1. `initialize_tracking_db()` → Initialize database
2. `golem::run_dev()` → Launch app
3. Login with `master1@delcampe.com` / `DelcampeMaster2025!`
4. Verify main app appears
5. Test logout
6. Change password before production

**Master Credentials**:
- 📧 Email: `master1@delcampe.com` or `master2@delcampe.com`
- 🔑 Password: `DelcampeMaster2025!`
- ⚠️ Change immediately!

---

## Files Modified in This Implementation

- ✅ `R/auth_system.R` - Created (8 authentication functions)
- ✅ `R/tracking_database.R` - Modified (users table migration)
- ✅ `R/app_server.R` - Modified (vals initialization, login integration, logout)
- ✅ `R/app_ui.R` - Modified (login UI, conditional rendering)
- ✅ `R/mod_login.R` - Modified (removed hardcoded credentials)
- ✅ `R/mod_settings_server.R` - Modified (NULL checks for current_user)
- ✅ `tests/testthat/test-auth_system.R` - Created (40+ tests)
- ✅ `dev/cleanup_production_database.R` - Exists (production cleanup)

---

**Happy Testing! 🎉**
