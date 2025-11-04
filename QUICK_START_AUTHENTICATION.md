# 🚀 Quick Start - Authentication System

**3 Simple Steps to Test Login**

---

## Step 1: Setup Authentication Database

In R console, run:

```r
source("dev/setup_authentication.R")
```

✅ This creates the users table and master accounts.

---

## Step 2: Launch the App

```r
golem::run_dev()
```

✅ You should see a green login screen.

---

## Step 3: Login

Enter these credentials:

- **Email**: `master1@delcampe.com`
- **Password**: `DelcampeMaster2025!`

Click **SIGN IN**

✅ Main app should appear!

---

## Test Logout

Click the **Logout** button in the top-right navbar.

✅ You should return to the login screen.

---

## ⚠️ Got an Error?

### "Error: no such column: active"
Run this to fix:
```r
source("dev/setup_authentication.R")
```

### "Invalid email or password"
Make sure you ran Step 1 first!

---

## 📖 Full Guide

For complete testing instructions, see: **AUTHENTICATION_TESTING_GUIDE.md**

---

## 🎯 Summary

**Login Credentials**:
- Email: `master1@delcampe.com`
- Password: `DelcampeMaster2025!`

**Setup Command**:
```r
source("dev/setup_authentication.R")
```

**That's it!** 🎉
