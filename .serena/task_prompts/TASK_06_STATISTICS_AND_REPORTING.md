# TASK 06: Statistics and Reporting

**Estimated Time:** 1 hour  
**Priority:** MEDIUM  
**Status:** 🔴 Not Started  
**Depends On:** TASK_01 complete (can do independently)

---

## Goal
Add comprehensive statistics functions to analyze tracking data across sessions.

---

## What You Need to Do

### Step 1: Copy Statistics Functions

```r
file.copy(
  from = "Test_Delcampe/R/fct_tracking.R",
  to = "R/fct_tracking.R"
)
```

### Step 2: Adapt for SQLite Database

The Test_Delcampe version uses JSON. Update to query SQLite:

#### Function 1: Session Statistics

```r
#' Calculate statistics for a specific session
#' 
#' @param session_id Character: Session ID to analyze
#' @return List with session statistics
calculate_session_stats <- function(session_id) {
  con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
  on.exit(dbDisconnect(con))
  
  # Get session info
  session_info <- dbGetQuery(con, "
    SELECT * FROM sessions WHERE session_id = ?
  ", list(session_id))
  
  if (nrow(session_info) == 0) {
    stop("Session not found")
  }
  
  # Count images uploaded
  images_uploaded <- dbGetQuery(con, "
    SELECT COUNT(*) as count FROM images WHERE session_id = ?
  ", list(session_id))$count
  
  # Count processed images (those with extraction_complete)
  images_processed <- dbGetQuery(con, "
    SELECT COUNT(DISTINCT image_id) as count 
    FROM processing_log 
    WHERE session_id = ? AND action = 'extraction_complete'
  ", list(session_id))$count
  
  # Count AI extractions
  ai_extractions <- dbGetQuery(con, "
    SELECT 
      COUNT(*) as total,
      SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) as successful,
      COUNT(DISTINCT model) as models_used
    FROM ai_extractions 
    WHERE image_id IN (SELECT image_id FROM images WHERE session_id = ?)
  ", list(session_id))
  
  # Count eBay posts
  ebay_posts <- dbGetQuery(con, "
    SELECT 
      COUNT(*) as total,
      SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) as successful
    FROM ebay_posts 
    WHERE image_id IN (SELECT image_id FROM images WHERE session_id = ?)
  ", list(session_id))
  
  # Count reused crops
  crops_reused <- dbGetQuery(con, "
    SELECT COUNT(*) as count 
    FROM processing_log 
    WHERE session_id = ? AND action = 'crops_reused'
  ", list(session_id))$count
  
  # Session duration
  session_duration <- as.numeric(difftime(
    session_info$end_time,
    session_info$start_time,
    units = "mins"
  ))
  
  return(list(
    session_id = session_id,
    user_id = session_info$user_id,
    start_time = session_info$start_time,
    end_time = session_info$end_time,
    duration_minutes = round(session_duration, 2),
    images_uploaded = images_uploaded,
    images_processed = images_processed,
    crops_reused = crops_reused,
    ai_extractions = list(
      total = ai_extractions$total,
      successful = ai_extractions$successful,
      success_rate = round(ai_extractions$successful / ai_extractions$total * 100, 1),
      models_used = ai_extractions$models_used
    ),
    ebay_posts = list(
      total = ebay_posts$total,
      successful = ebay_posts$successful,
      success_rate = round(ebay_posts$successful / ebay_posts$total * 100, 1)
    ),
    processing_rate = round(images_processed / session_duration, 2)
  ))
}
```

#### Function 2: Overall Statistics

```r
#' Calculate overall system statistics
#' 
#' @param start_date Optional: Start date for filtering (Date or character)
#' @param end_date Optional: End date for filtering (Date or character)
#' @return List with system-wide statistics
calculate_overall_stats <- function(start_date = NULL, end_date = NULL) {
  con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
  on.exit(dbDisconnect(con))
  
  # Build date filter if provided
  date_filter <- ""
  params <- list()
  
  if (!is.null(start_date)) {
    date_filter <- "WHERE start_time >= ?"
    params <- list(as.character(start_date))
  }
  
  if (!is.null(end_date)) {
    if (nchar(date_filter) > 0) {
      date_filter <- paste(date_filter, "AND start_time <= ?")
      params <- c(params, list(as.character(end_date)))
    } else {
      date_filter <- "WHERE start_time <= ?"
      params <- list(as.character(end_date))
    }
  }
  
  # Total sessions
  query <- paste("SELECT COUNT(*) as count FROM sessions", date_filter)
  total_sessions <- dbGetQuery(con, query, params)$count
  
  # Total users
  query <- paste("SELECT COUNT(DISTINCT user_id) as count FROM sessions", date_filter)
  total_users <- dbGetQuery(con, query, params)$count
  
  # Total images
  total_images <- dbGetQuery(con, "SELECT COUNT(*) as count FROM images")$count
  
  # Images by type
  images_by_type <- dbGetQuery(con, "
    SELECT image_type, COUNT(*) as count 
    FROM images 
    GROUP BY image_type
  ")
  
  # AI extraction stats
  ai_stats <- dbGetQuery(con, "
    SELECT 
      COUNT(*) as total,
      SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) as successful,
      model,
      COUNT(*) as count
    FROM ai_extractions
    GROUP BY model
  ")
  
  # eBay posting stats
  ebay_stats <- dbGetQuery(con, "
    SELECT 
      COUNT(*) as total,
      SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) as successful
    FROM ebay_posts
  ")
  
  # Crops reused (deduplication savings)
  crops_reused <- dbGetQuery(con, "
    SELECT COUNT(*) as count 
    FROM processing_log 
    WHERE action = 'crops_reused'
  ")$count
  
  # Average processing time per session
  avg_session_duration <- dbGetQuery(con, paste("
    SELECT AVG(
      CAST((julianday(end_time) - julianday(start_time)) * 24 * 60 AS REAL)
    ) as avg_minutes
    FROM sessions", date_filter), params)$avg_minutes
  
  return(list(
    date_range = list(
      start = start_date,
      end = end_date
    ),
    sessions = list(
      total = total_sessions,
      total_users = total_users,
      avg_duration_minutes = round(avg_session_duration, 2)
    ),
    images = list(
      total = total_images,
      by_type = images_by_type
    ),
    ai_extractions = list(
      total = sum(ai_stats$total),
      successful = sum(ai_stats$successful),
      success_rate = round(sum(ai_stats$successful) / sum(ai_stats$total) * 100, 1),
      by_model = ai_stats
    ),
    ebay_posts = list(
      total = ebay_stats$total,
      successful = ebay_stats$successful,
      success_rate = round(ebay_stats$successful / ebay_stats$total * 100, 1)
    ),
    deduplication = list(
      crops_reused = crops_reused,
      time_saved_estimate = crops_reused * 2  # Assume 2 min per crop
    )
  ))
}
```

#### Function 3: Export Statistics Report

```r
#' Export statistics report to CSV or JSON
#' 
#' @param output_file Character: Output file path
#' @param format Character: "csv" or "json"
#' @param start_date Optional: Start date for filtering
#' @param end_date Optional: End date for filtering
export_statistics_report <- function(output_file, 
                                     format = "csv", 
                                     start_date = NULL, 
                                     end_date = NULL) {
  stats <- calculate_overall_stats(start_date, end_date)
  
  if (format == "json") {
    jsonlite::write_json(stats, output_file, pretty = TRUE, auto_unbox = TRUE)
  } else if (format == "csv") {
    # Flatten statistics for CSV
    con <- dbConnect(SQLite(), "inst/app/data/tracking.sqlite")
    on.exit(dbDisconnect(con))
    
    # Get detailed session data
    sessions_data <- dbGetQuery(con, "
      SELECT 
        s.session_id,
        s.user_id,
        s.start_time,
        s.end_time,
        (SELECT COUNT(*) FROM images WHERE session_id = s.session_id) as images_uploaded,
        (SELECT COUNT(DISTINCT image_id) FROM processing_log 
         WHERE session_id = s.session_id AND action = 'extraction_complete') as images_processed,
        (SELECT COUNT(*) FROM processing_log 
         WHERE session_id = s.session_id AND action = 'crops_reused') as crops_reused
      FROM sessions s
      ORDER BY s.start_time DESC
    ")
    
    write.csv(sessions_data, output_file, row.names = FALSE)
  }
  
  return(invisible(output_file))
}
```

### Step 3: Add Comparison Functions

```r
#' Compare statistics between time periods
#' 
#' @param period1_start Start date of first period
#' @param period1_end End date of first period
#' @param period2_start Start date of second period
#' @param period2_end End date of second period
compare_periods <- function(period1_start, period1_end, period2_start, period2_end) {
  stats1 <- calculate_overall_stats(period1_start, period1_end)
  stats2 <- calculate_overall_stats(period2_start, period2_end)
  
  return(list(
    period1 = list(
      dates = paste(period1_start, "to", period1_end),
      stats = stats1
    ),
    period2 = list(
      dates = paste(period2_start, "to", period2_end),
      stats = stats2
    ),
    comparison = list(
      sessions_change = stats2$sessions$total - stats1$sessions$total,
      sessions_change_pct = round((stats2$sessions$total - stats1$sessions$total) / 
                                  stats1$sessions$total * 100, 1),
      images_change = stats2$images$total - stats1$images$total,
      ai_success_rate_change = stats2$ai_extractions$success_rate - 
                               stats1$ai_extractions$success_rate
    )
  ))
}
```

### Step 4: Test Statistics Functions

Create `test_statistics.R`:

```r
library(testthat)
source("R/tracking_database.R")
source("R/fct_tracking.R")

# Test 1: Session statistics
test_that("Session statistics calculated correctly", {
  # Create test session with data
  session_id <- create_tracking_session("test_user")
  image_id <- track_image_upload(session_id, "test.jpg", "face")
  
  track_ai_extraction(
    image_id = image_id,
    model = "claude-3-5-sonnet",
    title = "Test Title",
    success = TRUE
  )
  
  stats <- calculate_session_stats(session_id)
  
  expect_equal(stats$images_uploaded, 1)
  expect_equal(stats$ai_extractions$total, 1)
})

# Test 2: Overall statistics
test_that("Overall statistics calculated correctly", {
  stats <- calculate_overall_stats()
  
  expect_true(stats$sessions$total >= 0)
  expect_true(stats$images$total >= 0)
  expect_type(stats$ai_extractions$success_rate, "double")
})

# Test 3: Export report
test_that("Statistics export works", {
  temp_file <- tempfile(fileext = ".json")
  export_statistics_report(temp_file, format = "json")
  
  expect_true(file.exists(temp_file))
  
  # Read and verify JSON is valid
  data <- jsonlite::fromJSON(temp_file)
  expect_true("sessions" %in% names(data))
  
  unlink(temp_file)
})
```

---

## Add to UI (Optional)

```r
# In UI
tabPanel("Statistics",
  fluidRow(
    column(6,
      h4("Current Session"),
      verbatimTextOutput("current_session_stats")
    ),
    column(6,
      h4("Overall Statistics"),
      verbatimTextOutput("overall_stats")
    )
  ),
  hr(),
  downloadButton("download_stats_csv", "Export CSV"),
  downloadButton("download_stats_json", "Export JSON")
)

# In Server
output$current_session_stats <- renderPrint({
  stats <- calculate_session_stats(session$token)
  
  cat(sprintf("Session ID: %s\n", stats$session_id))
  cat(sprintf("Duration: %.1f minutes\n", stats$duration_minutes))
  cat(sprintf("Images: %d uploaded, %d processed\n", 
              stats$images_uploaded, stats$images_processed))
  cat(sprintf("Crops Reused: %d\n", stats$crops_reused))
  cat(sprintf("AI Extractions: %d (%.1f%% success)\n", 
              stats$ai_extractions$total, stats$ai_extractions$success_rate))
})

output$overall_stats <- renderPrint({
  stats <- calculate_overall_stats()
  
  cat(sprintf("Total Sessions: %d\n", stats$sessions$total))
  cat(sprintf("Total Users: %d\n", stats$sessions$total_users))
  cat(sprintf("Total Images: %d\n", stats$images$total))
  cat(sprintf("AI Success Rate: %.1f%%\n", stats$ai_extractions$success_rate))
  cat(sprintf("eBay Success Rate: %.1f%%\n", stats$ebay_posts$success_rate))
  cat(sprintf("Crops Reused: %d (saved ~%d min)\n", 
              stats$deduplication$crops_reused,
              stats$deduplication$time_saved_estimate))
})

output$download_stats_csv <- downloadHandler(
  filename = function() {
    paste0("statistics_", Sys.Date(), ".csv")
  },
  content = function(file) {
    export_statistics_report(file, format = "csv")
  }
)

output$download_stats_json <- downloadHandler(
  filename = function() {
    paste0("statistics_", Sys.Date(), ".json")
  },
  content = function(file) {
    export_statistics_report(file, format = "json")
  }
)
```

---

## Deliverables

- ✅ `R/fct_tracking.R` adapted for SQLite
- ✅ Session statistics function working
- ✅ Overall statistics function working
- ✅ Export functions working (CSV and JSON)
- ✅ Optional: Period comparison function
- ✅ Optional: Statistics UI panel
- ✅ Tests passing

---

## Next Steps
Once this task is complete, proceed to **TASK_07_DOCUMENTATION.md**
