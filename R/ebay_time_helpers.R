# eBay Time Helper Functions
# Utilities for handling scheduled listing times with proper timezone support

#' Calculate next 10:00 AM Pacific time from current moment
#'
#' Returns the next occurrence of 10:00 AM Pacific Time (PDT/PST).
#' R automatically handles daylight saving time transitions when using
#' the "America/Los_Angeles" timezone.
#'
#' @return POSIXct object in UTC timezone representing next 10:00 AM Pacific
#' @export
#' @examples
#' next_10am <- calculate_next_10am_pacific()
#' format(next_10am, "%Y-%m-%d %H:%M:%S %Z")
calculate_next_10am_pacific <- function() {
  # Get current time in UTC
  now_utc <- as.POSIXct(Sys.time(), tz = "UTC")

  # Convert to Pacific (R handles PDT/PST automatically)
  now_pacific <- as.POSIXct(
    format(now_utc, tz = "America/Los_Angeles"),
    tz = "America/Los_Angeles"
  )

  # Target: 10:00 AM today
  target_date <- as.Date(now_pacific, tz = "America/Los_Angeles")
  target_pacific <- as.POSIXct(
    paste(target_date, "10:00:00"),
    tz = "America/Los_Angeles"
  )

  # If passed, schedule for tomorrow
  if (now_pacific >= target_pacific) {
    target_pacific <- target_pacific + (24 * 3600)
  }

  # Convert to UTC for eBay API
  as.POSIXct(format(target_pacific, tz = "UTC"), tz = "UTC")
}

#' Format datetime for eBay ScheduleTime field (ISO 8601)
#'
#' Converts a POSIXct datetime to eBay's required ISO 8601 format with
#' milliseconds and Z suffix (UTC indicator).
#'
#' @param datetime POSIXct object (will be converted to UTC if not already)
#' @return Character string in format YYYY-MM-DDTHH:MM:SS.SSSZ
#' @export
#' @examples
#' schedule_time <- Sys.time() + 7200  # 2 hours from now
#' format_ebay_schedule_time(schedule_time)
#' # Returns: "2025-11-01T19:00:00.000Z"
format_ebay_schedule_time <- function(datetime) {
  utc_time <- as.POSIXct(format(datetime, tz = "UTC"), tz = "UTC")
  format(utc_time, "%Y-%m-%dT%H:%M:%S.000Z")
}

#' Validate scheduled time meets eBay requirements
#'
#' Checks that the scheduled time is:
#' - In the future
#' - At least 1 hour from now (eBay requirement)
#' - No more than 3 weeks (21 days) in the future (eBay limit)
#'
#' @param schedule_time POSIXct object in UTC timezone
#' @return List with 'valid' (TRUE/FALSE) and 'error' (message if invalid)
#' @export
#' @examples
#' # Valid time (2 hours from now)
#' valid_time <- Sys.time() + 7200
#' validate_schedule_time(valid_time)
#' # Returns: list(valid = TRUE)
#'
#' # Invalid time (in the past)
#' past_time <- Sys.time() - 3600
#' validate_schedule_time(past_time)
#' # Returns: list(valid = FALSE, error = "Scheduled time must be in the future")
validate_schedule_time <- function(schedule_time) {
  now_utc <- as.POSIXct(Sys.time(), tz = "UTC")

  # Check: In the past
  if (schedule_time <= now_utc) {
    return(list(valid = FALSE, error = "Scheduled time must be in the future"))
  }

  # Check: Minimum 1 hour buffer
  min_time <- now_utc + 3600
  if (schedule_time < min_time) {
    return(list(valid = FALSE, error = "Scheduled time must be at least 1 hour in the future"))
  }

  # Check: Maximum 3 weeks (21 days)
  max_time <- now_utc + (21 * 24 * 3600)
  if (schedule_time > max_time) {
    return(list(valid = FALSE, error = "Scheduled time cannot be more than 3 weeks in the future"))
  }

  list(valid = TRUE)
}

#' Format scheduled time for user display
#'
#' Shows the scheduled time in both Pacific Time and Romania time zones
#' for transparency and clarity. Both times are displayed with appropriate
#' formatting for each locale.
#'
#' @param schedule_time_utc POSIXct object in UTC timezone
#' @return Character string with both timezones separated by newline
#' @export
#' @examples
#' schedule_time <- as.POSIXct("2025-11-15 17:00:00", tz = "UTC")
#' cat(format_display_time(schedule_time))
#' # Pacific: 2025-11-15 09:00 AM PST
#' # Romania: 2025-11-15 19:00 EET
format_display_time <- function(schedule_time_utc) {
  # Pacific
  pacific_time <- as.POSIXct(
    format(schedule_time_utc, tz = "America/Los_Angeles"),
    tz = "America/Los_Angeles"
  )
  pacific_str <- format(pacific_time, "%Y-%m-%d %I:%M %p %Z")

  # Romania
  romania_time <- as.POSIXct(
    format(schedule_time_utc, tz = "Europe/Bucharest"),
    tz = "Europe/Bucharest"
  )
  romania_str <- format(romania_time, "%Y-%m-%d %H:%M %Z")

  paste0(
    "Pacific: ", pacific_str, "\n",
    "Romania: ", romania_str
  )
}

#' Convert UTC to Romania time
#'
#' Helper function to convert UTC time to Europe/Bucharest timezone.
#' R automatically handles daylight saving time transitions.
#'
#' @param utc_time POSIXct object in UTC timezone
#' @return POSIXct object in Europe/Bucharest timezone
#' @export
#' @examples
#' utc_time <- as.POSIXct("2025-11-15 17:00:00", tz = "UTC")
#' romania_time <- get_romania_from_utc(utc_time)
#' format(romania_time, "%Y-%m-%d %H:%M %Z")
#' # Returns: "2025-11-15 19:00 EET"
get_romania_from_utc <- function(utc_time) {
  as.POSIXct(
    format(utc_time, tz = "Europe/Bucharest"),
    tz = "Europe/Bucharest"
  )
}
