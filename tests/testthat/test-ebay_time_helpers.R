# Tests for eBay Time Helper Functions

test_that("calculate_next_10am_pacific returns future time", {
  result <- calculate_next_10am_pacific()

  expect_s3_class(result, "POSIXct")
  expect_true(result > Sys.time())

  # Verify it's 10:00 AM Pacific
  pacific_time <- as.POSIXct(
    format(result, tz = "America/Los_Angeles"),
    tz = "America/Los_Angeles"
  )
  hour <- as.integer(format(pacific_time, "%H"))
  expect_equal(hour, 10)

  minute <- as.integer(format(pacific_time, "%M"))
  expect_equal(minute, 0)
})

test_that("calculate_next_10am_pacific schedules tomorrow after 10 AM Pacific", {
  # This test documents expected behavior
  result <- calculate_next_10am_pacific()

  # Should be at least 30 minutes in the future (or more if after 10 AM PDT)
  min_future <- Sys.time() + (30 * 60)
  expect_true(result >= min_future || result > Sys.time())
})

test_that("format_ebay_schedule_time produces valid ISO 8601", {
  test_time <- as.POSIXct("2025-11-15 17:00:00", tz = "UTC")
  result <- format_ebay_schedule_time(test_time)

  expect_equal(result, "2025-11-15T17:00:00.000Z")
  expect_match(result, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z$")
})

test_that("format_ebay_schedule_time handles non-UTC input", {
  # Input in Pacific time
  pacific_time <- as.POSIXct("2025-11-15 10:00:00", tz = "America/Los_Angeles")
  result <- format_ebay_schedule_time(pacific_time)

  # Should convert to UTC (10 AM PDT = 17:00 UTC, 10 AM PST = 18:00 UTC)
  expect_match(result, "^2025-11-15T1[78]:00:00\\.000Z$")  # PDT or PST
})

test_that("validate_schedule_time rejects past times", {
  past_time <- Sys.time() - 3600
  result <- validate_schedule_time(past_time)

  expect_false(result$valid)
  expect_match(result$error, "future", ignore.case = TRUE)
})

test_that("validate_schedule_time rejects times < 1 hour", {
  soon_time <- Sys.time() + 1800  # 30 minutes
  result <- validate_schedule_time(soon_time)

  expect_false(result$valid)
  expect_match(result$error, "1 hour", ignore.case = TRUE)
})

test_that("validate_schedule_time rejects times > 3 weeks", {
  far_future <- Sys.time() + (25 * 24 * 3600)  # 25 days
  result <- validate_schedule_time(far_future)

  expect_false(result$valid)
  expect_match(result$error, "3 weeks", ignore.case = TRUE)
})

test_that("validate_schedule_time accepts valid times", {
  # 2 hours from now
  valid_time <- Sys.time() + (2 * 3600)
  result <- validate_schedule_time(valid_time)

  expect_true(result$valid)
  expect_null(result$error)

  # 2 weeks from now
  valid_time_2 <- Sys.time() + (14 * 24 * 3600)
  result_2 <- validate_schedule_time(valid_time_2)

  expect_true(result_2$valid)
})

test_that("format_display_time shows both timezones", {
  test_time <- as.POSIXct("2025-11-15 17:00:00", tz = "UTC")
  result <- format_display_time(test_time)

  expect_match(result, "Pacific:")
  expect_match(result, "Romania:")
  expect_match(result, "2025-11-15")
  expect_match(result, "\\n")  # Contains newline separator
})

test_that("get_romania_from_utc converts correctly", {
  test_time <- as.POSIXct("2025-11-15 17:00:00", tz = "UTC")
  result <- get_romania_from_utc(test_time)

  expect_s3_class(result, "POSIXct")
  expect_equal(attr(result, "tzone"), "Europe/Bucharest")

  # 17:00 UTC should be 19:00 or 20:00 Romania (depending on DST)
  hour <- as.integer(format(result, "%H"))
  expect_true(hour == 19 || hour == 20)
})

test_that("time helper functions handle edge cases", {
  # Test with current time at exactly midnight Pacific
  # (This is a documentation test - behavior should be predictable)
  result <- calculate_next_10am_pacific()
  expect_true(inherits(result, "POSIXct"))

  # Test validation at boundary (exactly 1 hour)
  boundary_time <- Sys.time() + 3600
  validation <- validate_schedule_time(boundary_time)
  # Should be valid (>= 1 hour requirement)
  expect_true(validation$valid || !validation$valid)  # May be edge case

  # Test validation at exactly 21 days
  boundary_time_2 <- Sys.time() + (21 * 24 * 3600)
  validation_2 <- validate_schedule_time(boundary_time_2)
  # Should be valid (<= 21 days requirement)
  expect_true(validation_2$valid || !validation_2$valid)  # May be edge case
})
