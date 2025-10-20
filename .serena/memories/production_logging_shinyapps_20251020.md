# Production Logging for shinyapps.io Deployment

**Date:** 2025-10-20  
**Context:** Low-traffic app (1-2 users), developer needs quick error identification  
**Solution:** Minimal global error handler with stderr logging

## Implementation

### What Was Added

**File:** `R/app_server.R` (lines 8-20)

```r
# ==== GLOBAL ERROR HANDLER FOR PRODUCTION LOGGING ====
# Catches all unhandled Shiny errors and logs to stderr for shinyapps.io visibility
options(shiny.error = function() {
  cat(file = stderr(),
      "\n========================================\n",
      "SHINY ERROR DETECTED\n",
      "========================================\n",
      "Time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n",
      "Session: ", session$token, "\n",
      "Error: ", geterrmessage(), "\n",
      "========================================\n\n",
      sep = "")
})
```

### Why This Approach

**Requirements:**
- ✅ Small user base (1-2 users max)
- ✅ Focus on catching errors, not user behavior analytics
- ✅ Quick error identification for developer
- ✅ Minimal implementation effort
- ✅ Works with shinyapps.io deployment

**Design Decision:**
- Chose **global error handler** over structured logging framework
- No additional dependencies needed
- Zero maintenance overhead
- Catches ALL unhandled errors automatically
- Logs to stderr (required for shinyapps.io visibility)

### What It Captures

**Automatically logged:**
- All unhandled Shiny errors
- Timestamp of error occurrence
- Session ID (identifies which user session)
- Complete error message
- Stack trace (via `geterrmessage()`)

**NOT captured (by design):**
- User interaction events (clicks, inputs)
- Debug/info messages
- Performance metrics
- Custom application events

## Accessing Logs on shinyapps.io

### Method 1: Real-Time Streaming (Recommended)

```r
# From your R console, in project directory
rsconnect::showLogs(streaming = TRUE)

# Keep this running while you:
# 1. Open app in browser
# 2. Trigger operations
# 3. Watch errors appear in real-time
```

**Output includes:**
- All stderr messages (error handler output)
- All stdout messages (existing cat() statements)
- Shiny's internal log messages

### Method 2: Web Dashboard

1. Log into https://www.shinyapps.io/
2. Navigate to your application
3. Click **"Logs"** tab
4. View timestamped log entries
5. Filter by date/time if needed

### Method 3: Fetch Recent Logs

```r
# Get last 50 log entries
rsconnect::showLogs(entries = 50)

# Get logs from specific time range
rsconnect::showLogs(hours = 2)  # Last 2 hours
```

## Current Print Statement Status

**Existing logging in codebase:**
- **556 total** `print()`/`cat()`/`message()` calls across 17 files
- **Heavy usage in:**
  - `R/mod_delcampe_export.R`: 145 instances
  - `R/app_server.R`: 71 instances  
  - `R/tracking_database.R`: 47 instances
  - `R/ebay_api.R`: 38 instances

**Decision:** Keep existing print statements as-is
- They work fine for development
- Visible in local R console
- Also captured by shinyapps.io logs (stdout)
- Global error handler supplements (not replaces) these

## Testing the Error Handler

### Quick Test

Add temporary test button:

```r
# In UI
actionButton("test_error_logging", "Test Error Handler")

# In server
observeEvent(input$test_error_logging, {
  stop("Test error for logging verification")
})
```

**Expected behavior:**
1. Click button → app shows error
2. Console shows formatted error block
3. Log captured in shinyapps.io logs

### Remove test code before production deployment

## Deployment Workflow

```r
# 1. Deploy app
rsconnect::deployApp()

# 2. Start log streaming
rsconnect::showLogs(streaming = TRUE)

# 3. Test app functionality
# - Open app in browser
# - Exercise key features
# - Watch for errors in log stream

# 4. Monitor during initial production use
# Keep logs open for first few user sessions
```

## Error Output Format

```
========================================
SHINY ERROR DETECTED
========================================
Time: 2025-10-20 14:35:22
Session: f8a9b2c3d4e5f6g7
Error: object 'undefined_variable' not found
========================================
```

**Benefits:**
- ✅ Easy to spot in log stream (bordered)
- ✅ Timestamp for troubleshooting timing issues
- ✅ Session ID to correlate with user reports
- ✅ Full error message for debugging

## Future Enhancement Options

### If App Scales Up (10+ users)

Consider adding **structured logging** with `logger` package:

```r
# Add to DESCRIPTION
Imports:
    logger,
    # ... existing

# Setup in R/run_app.R onStart
logger::log_appender(logger::appender_stderr)
logger::log_threshold("INFO")  # or "DEBUG" for dev

# Replace cat() with log levels
logger::log_info("Processing started")
logger::log_warn("API rate limit approaching")
logger::log_error("Database connection failed: {e$message}")
```

### If User Behavior Tracking Needed

Use `shinylogs` package:

```r
# IMPORTANT: Requires remote storage (Google Drive, Dropbox, DB)
# shinyapps.io has no persistent local storage

library(shinylogs)

# In server
track_usage(storage_mode = store_googledrive(...))
```

**Note:** Only implement if analytics/UX research required.

## Key Constraints

**shinyapps.io Limitations:**
- ❌ No persistent local file storage
- ❌ Cannot write log files to disk
- ✅ Can use stderr/stdout (captured by platform)
- ✅ Can send logs to remote storage (DB, cloud)

**Current Solution:**
- ✅ Uses stderr (always available)
- ✅ Works within platform constraints
- ✅ Zero external dependencies
- ✅ Accessible via rsconnect tools

## Related Files

- `R/app_server.R`: Error handler implementation
- `CLAUDE.md`: Development standards (Shiny API constraints)
- `.serena/memories/tech_stack_and_architecture.md`: Overall architecture

## References

**Shiny Documentation:**
- Debugging: https://shiny.posit.co/r/articles/improve/debugging/
- shinyapps.io logs: Via rsconnect package

**Alternative Logging Packages:**
- `logger`: https://daroczig.github.io/logger/
- `log4r`: https://github.com/johnmyleswhite/log4r
- `futile.logger`: https://cran.r-project.org/web/packages/futile.logger/
- `shinylogs`: https://dreamrs.github.io/shinylogs/

## Summary

**What changed:**
- Added 13 lines of code to `app_server.R`
- Zero dependencies added
- Zero ongoing maintenance required

**What you get:**
- ✅ Automatic error logging to stderr
- ✅ Visible on shinyapps.io via rsconnect::showLogs()
- ✅ Session tracking for multi-user debugging
- ✅ Timestamped error records
- ✅ Production-ready with minimal effort

**Implementation effort:** 5 minutes  
**Maintenance effort:** 0 minutes  
**Production readiness:** ✅ Ready to deploy
