# PRP: eBay Scheduled Listing with 10:00 AM PDT Default Time

**Priority**: HIGH
**Status**: Ready for Implementation
**Created**: 2025-11-01
**Estimated Effort**: 4-6 hours
**Related Memories**:
- `.serena/memories/ebay_trading_api_complete_20251028.md`
- `.serena/memories/ebay_trading_api_implementation_complete_20251028.md`

---

## Problem Statement

Users need the ability to **schedule eBay listings to start at a specific future time** rather than immediately publishing them. This is particularly useful for:

1. **Strategic Launch Timing**: Starting auctions at peak browsing hours (e.g., 10:00 AM PDT when US buyers are active)
2. **Batch Preparation**: Prepare multiple listings and have them go live at the same optimal time
3. **International Sellers**: Romania-based sellers targeting US market need to schedule for US time zones
4. **Listing Management**: Schedule listings to start on specific dates for promotional campaigns

**Current Limitation**: All listings (Fixed Price and Auction) go live immediately when created via `AddFixedPriceItem` or `AddItem` API calls.

**User Impact**: HIGH - Users cannot optimize listing start times for maximum visibility and engagement, potentially reducing sales effectiveness.

---

## Requirements

### Functional Requirements

#### FR1: Scheduled Start Time UI Control
- **MUST** add a datetime picker/selector for "Schedule Start Time" in both postcard and stamp eBay export UIs
- **MUST** default to **10:00 AM Pacific Daylight Time (PDT) on the next appropriate date**:
  - If current Romania time < 10:00 AM PDT equivalent: Schedule for today at 10:00 AM PDT
  - If current Romania time >= 10:00 AM PDT equivalent: Schedule for tomorrow at 10:00 AM PDT
- **MUST** allow user to override and select custom date/time
- **MUST** display the scheduled time in BOTH:
  - Pacific Time (PDT/PST) - for eBay reference
  - Romania Time (EET/EEST) - for user reference
- **MUST** include a checkbox "List Immediately" to bypass scheduling (default: unchecked)

#### FR2: Time Zone Conversions
- **MUST** implement accurate Romania (EET/EEST) to Pacific (PDT/PST) conversions
  - Romania Standard Time (EET): UTC+2
  - Romania Daylight Time (EEST): UTC+3
  - Pacific Daylight Time (PDT): UTC-7
  - Pacific Standard Time (PST): UTC-8
- **MUST** handle daylight saving time transitions correctly
- **MUST** convert selected time to ISO 8601 UTC format for eBay API: `YYYY-MM-DDTHH:MM:SS.SSSZ`

#### FR3: Smart Default Calculation
- **MUST** calculate "next 10:00 AM PDT" based on current Romania time:
  ```r
  calculate_next_10am_pdt <- function() {
    # Get current time in Romania (respects DST)
    romania_now <- Sys.time()  # R automatically handles local timezone

    # Convert 10:00 AM PDT to UTC (PDT = UTC-7, so 10:00 AM PDT = 17:00 UTC)
    # During PST (UTC-8): 10:00 AM PST = 18:00 UTC
    target_hour_utc <- 17  # For PDT

    # Calculate target time today
    today_target <- as.POSIXct(format(romania_now, "%Y-%m-%d"), tz = "UTC") +
                    (target_hour_utc * 3600)

    # If we've passed 10:00 AM PDT today, schedule for tomorrow
    if (romania_now >= today_target) {
      tomorrow_target <- today_target + (24 * 3600)
      return(tomorrow_target)
    } else {
      return(today_target)
    }
  }
  ```

#### FR4: eBay API Integration
- **MUST** add `ScheduleTime` field to Trading API XML requests:
  ```xml
  <Item>
    <ScheduleTime>2025-11-15T17:00:00.000Z</ScheduleTime>
    <!-- Other fields... -->
  </Item>
  ```
- **MUST** use `ScheduleTime` in both:
  - `AddFixedPriceItem` (Buy It Now listings)
  - `AddItem` (Auction listings)
- **MUST** handle eBay scheduling fees notification (scheduled listings incur a fee)
- **MUST** validate that scheduled time is:
  - In the future (not past)
  - Within 3 weeks from now (eBay limit)
  - At least 1 hour in the future (minimum buffer)

#### FR5: Database Schema
- **MUST** add `schedule_time` column to `ebay_listings` table (DATETIME, nullable)
- **MUST** add `is_scheduled` column to track scheduled vs immediate listings (BOOLEAN)
- **MUST** add `actual_start_time` column to store eBay's returned StartTime (DATETIME, nullable)
- **MUST** provide automatic migration for existing databases

#### FR6: User Feedback
- **MUST** show confirmation message with:
  - Scheduled date/time in PDT/PST
  - Scheduled date/time in Romania time
  - Warning: "Listing will not be visible until scheduled time"
  - Warning: "Scheduling fee applies"
- **MUST** update progress messages to indicate "Scheduling listing..." vs "Creating listing..."
- **MUST** display scheduled listings differently in tracking database

### Non-Functional Requirements

#### NFR1: User Experience
- UI **MUST** be intuitive - user should immediately understand the default and how to change it
- Time zone conversion **MUST** be transparent - show both PDT and Romania times side-by-side
- Validation errors **MUST** be clear: "Scheduled time must be at least 1 hour in the future"
- Default behavior **MUST** be smart - automatically calculate next 10:00 AM PDT

#### NFR2: Code Quality
- **MUST** follow Golem module conventions
- **MUST** include comprehensive unit tests (critical test suite)
- **MUST** maintain existing code style and patterns
- **MUST** backup original files before modification

#### NFR3: Backwards Compatibility
- Existing immediate listing functionality **MUST** continue to work
- Database migration **MUST** be automatic and safe
- Listings without `schedule_time` **MUST** be treated as immediate

---

## Technical Research

### eBay Trading API - ScheduleTime Field

#### Field Specifications
- **Field Name**: `Item.ScheduleTime`
- **Data Type**: DateTime (ISO 8601 format)
- **Format**: `YYYY-MM-DDTHH:MM:SS.SSSZ` (UTC time zone)
- **Example**: `2025-11-15T17:00:00.000Z` (10:00 AM PDT = 17:00 UTC)
- **Supported Calls**: `AddItem`, `AddFixedPriceItem`, `RelistItem`

#### eBay Scheduling Rules
1. **Future Limit**: Can schedule up to **3 weeks (21 days)** in the future
2. **Minimum Buffer**: Should be at least **1 hour** in the future (practical minimum)
3. **Visibility**: Scheduled items are **NOT visible** to buyers until scheduled time
4. **Fees**: Scheduling incurs a **SchedulingFee** (charged when listing goes live)
5. **Rescheduling**: Can be rescheduled many times before scheduled start date
6. **Listing Count**: Does NOT count against listing limits until it goes live

#### API Response Fields
- `Item.StartTime`: The actual time eBay started the listing (returned in response)
- `Item.EndTime`: The calculated end time based on duration
- **Best Practice**: Store `StartTime` from response, not the `ScheduleTime` from request

### Time Zone Math

#### Conversion Table: 10:00 AM Pacific → UTC → Romania

| Season | Pacific Time | UTC Time | Romania Time (approx) |
|--------|--------------|----------|----------------------|
| **Spring-Fall (PDT/EEST)** | 10:00 AM PDT (UTC-7) | 17:00 UTC | 20:00 EEST (UTC+3) |
| **Winter (PST/EET)** | 10:00 AM PST (UTC-8) | 18:00 UTC | 20:00 EET (UTC+2) |

#### Key Observations
- 10:00 AM Pacific Time = approximately 20:00 (8:00 PM) Romania Time year-round
- Romania seller preparing listings at 2:00 PM Romania time → targets same day 10:00 AM PDT (8 PM Romania)
- Romania seller preparing listings at 9:00 PM Romania time → targets next day 10:00 AM PDT

#### ISO 8601 Examples
```
# 10:00 AM PDT on November 15, 2025
ScheduleTime: 2025-11-15T17:00:00.000Z

# 10:00 AM PST on January 15, 2026
ScheduleTime: 2026-01-15T18:00:00.000Z
```

---

## Implementation Plan

### Phase 1: Time Utility Functions (1 hour)

**File**: `R/ebay_time_helpers.R` (NEW)

Create comprehensive time zone handling utilities:

```r
#' Calculate next 10:00 AM Pacific time from current Romania time
#' @return POSIXct in UTC timezone representing next 10:00 AM Pacific
#' @export
calculate_next_10am_pacific <- function() {
  # Get current time in UTC
  now_utc <- as.POSIXct(Sys.time(), tz = "UTC")

  # Convert to Pacific timezone (handles PST/PDT automatically)
  now_pacific <- as.POSIXct(format(now_utc, tz = "America/Los_Angeles"),
                            tz = "America/Los_Angeles")

  # Target: 10:00 AM Pacific today
  target_date <- as.Date(now_pacific, tz = "America/Los_Angeles")
  target_pacific <- as.POSIXct(
    paste(target_date, "10:00:00"),
    tz = "America/Los_Angeles"
  )

  # If we've passed 10:00 AM Pacific today, move to tomorrow
  if (now_pacific >= target_pacific) {
    target_pacific <- target_pacific + (24 * 3600)
  }

  # Convert to UTC for eBay API
  target_utc <- as.POSIXct(format(target_pacific, tz = "UTC"), tz = "UTC")

  return(target_utc)
}

#' Format datetime for eBay ScheduleTime field (ISO 8601 UTC)
#' @param datetime POSIXct object
#' @return Character string in format YYYY-MM-DDTHH:MM:SS.SSSZ
#' @export
format_ebay_schedule_time <- function(datetime) {
  # Ensure UTC timezone
  utc_time <- as.POSIXct(format(datetime, tz = "UTC"), tz = "UTC")

  # Format to ISO 8601 with milliseconds
  formatted <- format(utc_time, "%Y-%m-%dT%H:%M:%S.000Z")

  return(formatted)
}

#' Validate scheduled time is within eBay limits
#' @param schedule_time POSIXct object in UTC
#' @return List with valid (TRUE/FALSE) and error message
#' @export
validate_schedule_time <- function(schedule_time) {
  now_utc <- as.POSIXct(Sys.time(), tz = "UTC")

  # Check if in the past
  if (schedule_time <= now_utc) {
    return(list(
      valid = FALSE,
      error = "Scheduled time must be in the future"
    ))
  }

  # Check minimum buffer (1 hour)
  min_time <- now_utc + 3600  # 1 hour from now
  if (schedule_time < min_time) {
    return(list(
      valid = FALSE,
      error = "Scheduled time must be at least 1 hour in the future"
    ))
  }

  # Check maximum limit (3 weeks)
  max_time <- now_utc + (21 * 24 * 3600)  # 21 days
  if (schedule_time > max_time) {
    return(list(
      valid = FALSE,
      error = "Scheduled time cannot be more than 3 weeks in the future"
    ))
  }

  return(list(valid = TRUE))
}

#' Format scheduled time for user display (Pacific and Romania times)
#' @param schedule_time_utc POSIXct in UTC
#' @return Character string with both timezones
#' @export
format_display_time <- function(schedule_time_utc) {
  # Convert to Pacific
  pacific_time <- as.POSIXct(
    format(schedule_time_utc, tz = "America/Los_Angeles"),
    tz = "America/Los_Angeles"
  )
  pacific_str <- format(pacific_time, "%Y-%m-%d %I:%M %p %Z")

  # Convert to Romania (Europe/Bucharest handles EET/EEST)
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
```

**Testing**:
- Test `calculate_next_10am_pacific()` at various Romania times
- Test ISO 8601 formatting
- Test validation rejects past times
- Test validation rejects times > 3 weeks
- Test display formatting shows correct timezones

### Phase 2: Database Extension (30 minutes)

**File**: `R/ebay_database_extension.R`

Add scheduled listing fields:

```r
migrate_add_scheduled_fields <- function(con) {
  cat("🔧 Migrating database: Adding scheduled listing fields...\n")

  # Check if migration already applied
  columns <- DBI::dbListFields(con, "ebay_listings")

  if (!"schedule_time" %in% columns) {
    DBI::dbExecute(con, "
      ALTER TABLE ebay_listings
      ADD COLUMN schedule_time TEXT;
    ")
    cat("   ✅ Added schedule_time column\n")
  }

  if (!"is_scheduled" %in% columns) {
    DBI::dbExecute(con, "
      ALTER TABLE ebay_listings
      ADD COLUMN is_scheduled INTEGER DEFAULT 0;
    ")
    cat("   ✅ Added is_scheduled column\n")
  }

  if (!"actual_start_time" %in% columns) {
    DBI::dbExecute(con, "
      ALTER TABLE ebay_listings
      ADD COLUMN actual_start_time TEXT;
    ")
    cat("   ✅ Added actual_start_time column\n")
  }

  # Create index for scheduled listings
  DBI::dbExecute(con, "
    CREATE INDEX IF NOT EXISTS idx_ebay_listings_is_scheduled
    ON ebay_listings(is_scheduled);
  ")

  cat("✅ Scheduled listing migration complete\n")
}
```

Update `save_ebay_listing()` to accept new parameters:

```r
save_ebay_listing <- function(
  session_id,
  card_id,
  item_id,
  listing_url,
  api_type = "trading",
  listing_type = "fixed_price",
  listing_duration = "GTC",
  buy_it_now_price = NULL,
  reserve_price = NULL,
  schedule_time = NULL,      # NEW
  is_scheduled = FALSE,      # NEW
  actual_start_time = NULL   # NEW
) {
  # ... existing code ...

  query <- "
    INSERT INTO ebay_listings (
      session_id, card_id, item_id, listing_url, created_at, api_type,
      listing_type, listing_duration, buy_it_now_price, reserve_price,
      schedule_time, is_scheduled, actual_start_time
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  "

  DBI::dbExecute(con, query, params = list(
    session_id, card_id, item_id, listing_url,
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    api_type, listing_type, listing_duration,
    buy_it_now_price, reserve_price,
    if (!is.null(schedule_time)) format(schedule_time, "%Y-%m-%d %H:%M:%S") else NULL,
    as.integer(is_scheduled),
    if (!is.null(actual_start_time)) format(actual_start_time, "%Y-%m-%d %H:%M:%S") else NULL
  ))
}
```

**Testing**:
- Test migration on empty database
- Test migration on database with existing records
- Test saving scheduled listing
- Test saving immediate listing

### Phase 3: Trading API Enhancement (1.5 hours)

**File**: `R/ebay_trading_api.R`

Update XML builders to include ScheduleTime:

```r
# In build_add_item_xml() method (around line 356)
build_add_item_xml = function(item_data) {
  # ... existing code ...

  item <- xml2::xml_add_child(doc, "Item")

  # Add ScheduleTime if specified (MUST come before other fields per eBay best practice)
  if (!is.null(item_data$schedule_time)) {
    xml2::xml_add_child(item, "ScheduleTime", item_data$schedule_time)
  }

  # CRITICAL: Add Country (this is why we need Trading API!)
  xml2::xml_add_child(item, "Country", item_data$country)
  # ... rest of existing code ...
}

# Same update for build_auction_xml() method (around line 731)
build_auction_xml = function(item_data) {
  # ... existing code ...

  item <- xml2::xml_add_child(doc, "Item")

  # Add ScheduleTime if specified
  if (!is.null(item_data$schedule_time)) {
    xml2::xml_add_child(item, "ScheduleTime", item_data$schedule_time)
  }

  # ... rest of existing code ...
}
```

Update `parse_response()` to extract StartTime:

```r
parse_response = function(xml_string) {
  # ... existing code ...

  if (ack %in% c("Success", "Warning")) {
    # Success - extract ItemID
    item_id <- xml2::xml_text(xml2::xml_find_first(doc, ".//*[local-name()='ItemID']"))

    # Extract StartTime (actual listing start time)
    start_time <- xml2::xml_text(xml2::xml_find_first(doc, ".//*[local-name()='StartTime']"))

    # ... extract warnings ...

    return(list(
      success = TRUE,
      item_id = item_id,
      start_time = if (!is.na(start_time) && start_time != "") start_time else NULL,
      warnings = warnings
    ))
  }
  # ... rest of existing code ...
}
```

**Testing**:
- Test XML generation with ScheduleTime
- Test XML generation without ScheduleTime (immediate)
- Test response parsing extracts StartTime
- Test scheduled listing creation in sandbox

### Phase 4: Integration Layer Update (1 hour)

**File**: `R/ebay_integration.R`

Update `create_ebay_listing_from_card()`:

```r
create_ebay_listing_from_card <- function(
  ebay_api,
  session_id,
  card_id,
  ai_data,
  image_url,
  listing_type = "fixed_price",
  listing_duration = "GTC",
  buy_it_now_price = NULL,
  reserve_price = NULL,
  schedule_time_utc = NULL  # NEW: POSIXct in UTC or NULL for immediate
) {
  # ... existing validation ...

  # Validate schedule time if provided
  if (!is.null(schedule_time_utc)) {
    validation <- validate_schedule_time(schedule_time_utc)
    if (!validation$valid) {
      return(list(
        success = FALSE,
        error = validation$error
      ))
    }
  }

  # Prepare item data
  item_data <- build_trading_item_data(
    card_id = card_id,
    ai_data = ai_data,
    image_url = image_url,
    country = "RO",
    location = "Bucharest, Romania"
  )

  # Add scheduling if requested
  if (!is.null(schedule_time_utc)) {
    item_data$schedule_time <- format_ebay_schedule_time(schedule_time_utc)
  }

  # Call appropriate API method
  if (listing_type == "auction") {
    result <- ebay_api$trading$add_auction_item(item_data)
  } else {
    result <- ebay_api$trading$add_fixed_price_item(item_data)
  }

  if (result$success) {
    # Save to database
    save_ebay_listing(
      session_id = session_id,
      card_id = card_id,
      item_id = result$item_id,
      listing_url = generate_listing_url(result$item_id, ebay_api$config$environment),
      api_type = "trading",
      listing_type = listing_type,
      listing_duration = listing_duration,
      buy_it_now_price = buy_it_now_price,
      reserve_price = reserve_price,
      schedule_time = schedule_time_utc,
      is_scheduled = !is.null(schedule_time_utc),
      actual_start_time = if (!is.null(result$start_time)) {
        as.POSIXct(result$start_time, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
      } else NULL
    )
  }

  return(result)
}
```

**Testing**:
- Test creating scheduled listing
- Test creating immediate listing
- Test database saves schedule_time correctly
- Test database saves actual_start_time

### Phase 5: UI Updates - Postcards (1.5 hours)

**File**: `R/mod_delcampe_export.R`

Add scheduling UI controls (insert after listing type/duration fields):

```r
# Scheduling Section (new)
bslib::card(
  bslib::card_header("Listing Schedule"),
  bslib::card_body(
    checkboxInput(
      ns(paste0("list_immediately_", idx)),
      "List Immediately (skip scheduling)",
      value = FALSE
    ),

    conditionalPanel(
      condition = sprintf("!input['%s']", ns(paste0("list_immediately_", idx))),

      # Scheduled time input
      dateInput(
        ns(paste0("schedule_date_", idx)),
        "Scheduled Start Date",
        value = Sys.Date(),  # Will be updated by observer
        min = Sys.Date(),
        max = Sys.Date() + 21  # 3 weeks limit
      ),

      selectInput(
        ns(paste0("schedule_hour_", idx)),
        "Hour (Pacific Time)",
        choices = sprintf("%02d", 0:23),
        selected = "10"  # Default 10:00 AM
      ),

      selectInput(
        ns(paste0("schedule_minute_", idx)),
        "Minute",
        choices = sprintf("%02d", c(0, 15, 30, 45)),
        selected = "00"
      ),

      # Display calculated times
      uiOutput(ns(paste0("schedule_display_", idx)))
    )
  )
)
```

Add observer to calculate default time and update display:

```r
# Calculate default scheduled time when UI loads
observe({
  # Calculate next 10:00 AM Pacific
  next_10am <- calculate_next_10am_pacific()

  # Convert to Pacific for UI
  pacific_time <- as.POSIXct(
    format(next_10am, tz = "America/Los_Angeles"),
    tz = "America/Los_Angeles"
  )

  # Update date input
  updateDateInput(
    session,
    paste0("schedule_date_", i),
    value = as.Date(pacific_time)
  )

  # Update hour/minute selects
  updateSelectInput(
    session,
    paste0("schedule_hour_", i),
    selected = sprintf("%02d", as.integer(format(pacific_time, "%H")))
  )

  updateSelectInput(
    session,
    paste0("schedule_minute_", i),
    selected = sprintf("%02d", as.integer(format(pacific_time, "%M")))
  )
})

# Dynamic display of scheduled time in both timezones
output[[paste0("schedule_display_", i)]] <- renderUI({
  req(input[[paste0("schedule_date_", i)]])
  req(input[[paste0("schedule_hour_", i)]])
  req(input[[paste0("schedule_minute_", i)]])

  # Build Pacific time from inputs
  pacific_str <- sprintf(
    "%s %s:%s:00",
    input[[paste0("schedule_date_", i)]],
    input[[paste0("schedule_hour_", i)]],
    input[[paste0("schedule_minute_", i)]]
  )

  pacific_time <- as.POSIXct(
    pacific_str,
    tz = "America/Los_Angeles",
    format = "%Y-%m-%d %H:%M:%S"
  )

  # Convert to UTC
  utc_time <- as.POSIXct(format(pacific_time, tz = "UTC"), tz = "UTC")

  # Convert to Romania
  romania_time <- as.POSIXct(
    format(utc_time, tz = "Europe/Bucharest"),
    tz = "Europe/Bucharest"
  )

  div(
    class = "alert alert-info",
    style = "margin-top: 10px; font-size: 0.9em;",
    strong("Scheduled Start Time:"),
    tags$br(),
    sprintf("🇺🇸 Pacific: %s", format(pacific_time, "%Y-%m-%d %I:%M %p %Z")),
    tags$br(),
    sprintf("🇷🇴 Romania: %s", format(romania_time, "%Y-%m-%d %H:%M %Z")),
    tags$br(),
    tags$small(
      style = "color: #856404;",
      "⚠️ Listing will not be visible until scheduled time. Scheduling fee applies."
    )
  )
})
```

Update Send to eBay observer:

```r
observeEvent(input[[paste0("send_to_ebay_", i)]], {
  # ... existing validation ...

  # Determine if scheduled
  list_immediately <- input[[paste0("list_immediately_", i)]]
  schedule_time_utc <- NULL

  if (!list_immediately) {
    # Build scheduled time from user inputs
    schedule_date <- input[[paste0("schedule_date_", i)]]
    schedule_hour <- input[[paste0("schedule_hour_", i)]]
    schedule_minute <- input[[paste0("schedule_minute_", i)]]

    pacific_str <- sprintf(
      "%s %s:%s:00",
      schedule_date, schedule_hour, schedule_minute
    )

    pacific_time <- as.POSIXct(
      pacific_str,
      tz = "America/Los_Angeles",
      format = "%Y-%m-%d %H:%M:%S"
    )

    # Convert to UTC
    schedule_time_utc <- as.POSIXct(format(pacific_time, tz = "UTC"), tz = "UTC")

    # Validate
    validation <- validate_schedule_time(schedule_time_utc)
    if (!validation$valid) {
      showNotification(validation$error, type = "error")
      return()
    }
  }

  # Show confirmation modal (include schedule info)
  show_ebay_confirmation_modal(
    idx = i,
    title = ai_data$title,
    price = price_value,
    condition = ai_data$condition,
    listing_type = listing_type,
    duration = duration,
    schedule_time = schedule_time_utc
  )
})
```

Update confirmation modal to show schedule:

```r
show_ebay_confirmation_modal = function(idx, title, price, condition, listing_type, duration, schedule_time = NULL) {
  type_label <- if (listing_type == "auction") {
    paste0("Auction (", duration, ")")
  } else {
    "Buy It Now"
  }

  # Build schedule display
  schedule_display <- if (!is.null(schedule_time)) {
    tagList(
      p(strong("Scheduled Start:")),
      pre(format_display_time(schedule_time)),
      p(
        style = "color: #856404; font-size: 0.9em;",
        "⚠️ Listing will not be visible until scheduled time"
      )
    )
  } else {
    p(strong("Start:"), "Immediately")
  }

  showModal(modalDialog(
    title = "Confirm eBay Listing",
    tagList(
      p(strong("Title:"), title),
      p(strong("Type:"), type_label),
      p(strong(if (listing_type == "auction") "Starting Bid:" else "Price:"), price),
      p(strong("Condition:"), condition),
      schedule_display
    ),
    footer = tagList(
      modalButton("Cancel"),
      actionButton(ns(paste0("confirm_send_to_ebay_", idx)), "Confirm & Send", class = "btn-success")
    )
  ))
}
```

Update Confirm Send observer:

```r
observeEvent(input[[paste0("confirm_send_to_ebay_", i)]], {
  removeModal()

  # ... read all inputs including schedule_time_utc ...

  withProgress(message = if (!is.null(schedule_time_utc)) "Scheduling listing..." else "Creating listing...", {
    # ... existing code ...

    result <- create_ebay_listing_from_card(
      ebay_api = api,
      session_id = session_id,
      card_id = card_id,
      ai_data = ai_data,
      image_url = eps_result$image_url,
      listing_type = listing_type,
      listing_duration = duration,
      buy_it_now_price = buy_it_now_price,
      reserve_price = reserve_price,
      schedule_time_utc = schedule_time_utc  # NEW
    )

    # ... handle result ...

    if (result$success) {
      success_message <- if (!is.null(schedule_time_utc)) {
        paste0(
          "Listing scheduled successfully!\n",
          format_display_time(schedule_time_utc)
        )
      } else {
        "Listing created successfully!"
      }

      showNotification(success_message, type = "message", duration = 10)
    }
  })
})
```

**Testing**:
- Test default time calculates to next 10:00 AM PDT
- Test time displays update when user changes date/hour/minute
- Test "List Immediately" checkbox hides scheduling controls
- Test validation rejects past times
- Test validation rejects times > 3 weeks
- Test confirmation modal shows schedule correctly

### Phase 6: UI Updates - Stamps (1 hour)

**File**: `R/mod_stamp_export.R`

Apply the same scheduling UI pattern as postcards (reuse components):

```r
# Add scheduling section to stamp export UI
# (Same structure as Phase 5, but with stamp-specific namespacing)
```

**Testing**:
- Same tests as Phase 5 but for stamps module

### Phase 7: Helper Functions & Testing (1 hour)

**File**: `tests/testthat/test-ebay_time_helpers.R` (NEW)

```r
test_that("calculate_next_10am_pacific returns future time", {
  result <- calculate_next_10am_pacific()

  expect_s3_class(result, "POSIXct")
  expect_true(result > Sys.time())

  # Convert to Pacific and check hour
  pacific_time <- as.POSIXct(format(result, tz = "America/Los_Angeles"),
                             tz = "America/Los_Angeles")
  hour <- as.integer(format(pacific_time, "%H"))
  expect_equal(hour, 10)

  minute <- as.integer(format(pacific_time, "%M"))
  expect_equal(minute, 0)
})

test_that("format_ebay_schedule_time produces valid ISO 8601", {
  test_time <- as.POSIXct("2025-11-15 17:00:00", tz = "UTC")
  result <- format_ebay_schedule_time(test_time)

  expect_equal(result, "2025-11-15T17:00:00.000Z")
  expect_match(result, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z$")
})

test_that("validate_schedule_time rejects past times", {
  past_time <- Sys.time() - 3600  # 1 hour ago
  result <- validate_schedule_time(past_time)

  expect_false(result$valid)
  expect_match(result$error, "future")
})

test_that("validate_schedule_time rejects times > 3 weeks", {
  far_future <- Sys.time() + (25 * 24 * 3600)  # 25 days
  result <- validate_schedule_time(far_future)

  expect_false(result$valid)
  expect_match(result$error, "3 weeks")
})

test_that("validate_schedule_time accepts valid times", {
  valid_time <- Sys.time() + (2 * 3600)  # 2 hours from now
  result <- validate_schedule_time(valid_time)

  expect_true(result$valid)
})

test_that("format_display_time shows both timezones", {
  test_time <- as.POSIXct("2025-11-15 17:00:00", tz = "UTC")
  result <- format_display_time(test_time)

  expect_match(result, "Pacific:")
  expect_match(result, "Romania:")
  expect_match(result, "2025-11-15")
})
```

**File**: `tests/testthat/test-ebay_trading_api_scheduled.R` (NEW)

```r
test_that("build_add_item_xml includes ScheduleTime when provided", {
  # Mock data with schedule time
  item_data <- list(
    title = "Test Item",
    description = "Test",
    country = "RO",
    location = "Bucharest",
    category_id = 262042,
    price = "9.99",
    condition_id = 3000,
    quantity = 1,
    images = list("http://example.com/img.jpg"),
    aspects = list(),
    schedule_time = "2025-11-15T17:00:00.000Z"
  )

  # Build XML
  xml <- private$build_add_item_xml(item_data)

  # Parse and check for ScheduleTime
  doc <- xml2::read_xml(xml)
  schedule_node <- xml2::xml_find_first(doc, ".//*[local-name()='ScheduleTime']")

  expect_false(is.na(schedule_node))
  expect_equal(xml2::xml_text(schedule_node), "2025-11-15T17:00:00.000Z")
})

test_that("build_add_item_xml omits ScheduleTime when NULL", {
  # Mock data without schedule time
  item_data <- list(
    title = "Test Item",
    description = "Test",
    country = "RO",
    location = "Bucharest",
    category_id = 262042,
    price = "9.99",
    condition_id = 3000,
    quantity = 1,
    images = list("http://example.com/img.jpg"),
    aspects = list()
  )

  # Build XML
  xml <- private$build_add_item_xml(item_data)

  # Parse and check ScheduleTime is absent
  doc <- xml2::read_xml(xml)
  schedule_node <- xml2::xml_find_first(doc, ".//*[local-name()='ScheduleTime']")

  expect_true(is.na(schedule_node))
})
```

**Add to Critical Test Suite**:
```r
# Update dev/run_critical_tests.R
testthat::test_file("tests/testthat/test-ebay_time_helpers.R")
testthat::test_file("tests/testthat/test-ebay_trading_api_scheduled.R")
```

---

## Database Schema Changes

```sql
-- Migration: Add scheduled listing support to ebay_listings table

ALTER TABLE ebay_listings
ADD COLUMN schedule_time TEXT;

ALTER TABLE ebay_listings
ADD COLUMN is_scheduled INTEGER DEFAULT 0;

ALTER TABLE ebay_listings
ADD COLUMN actual_start_time TEXT;

-- Index for querying scheduled listings
CREATE INDEX idx_ebay_listings_is_scheduled
ON ebay_listings(is_scheduled);

-- Update existing records (backward compatibility)
UPDATE ebay_listings
SET is_scheduled = 0
WHERE is_scheduled IS NULL;
```

---

## UI Mockup

### Before (Immediate Listing Only)

```
┌─────────────────────────────────┐
│ eBay Export                     │
├─────────────────────────────────┤
│ Title: Vintage Bucharest...     │
│ Listing Type: [Auction ▼]      │
│ Starting Bid: 4.99              │
│ Duration: [7 Days ▼]           │
│ [Send to eBay]                  │
└─────────────────────────────────┘
```

### After (With Scheduling Support)

```
┌─────────────────────────────────────────────────┐
│ eBay Export                                     │
├─────────────────────────────────────────────────┤
│ Title: Vintage Bucharest...                     │
│ Listing Type: [Auction ▼]                      │
│ Starting Bid: 4.99                              │
│ Duration: [7 Days ▼]                           │
│                                                 │
│ ┌─ Listing Schedule ────────────────────┐     │
│ │ ☐ List Immediately (skip scheduling)  │     │
│ │                                        │     │
│ │ Scheduled Start Date: [2025-11-02]    │     │
│ │ Hour (Pacific Time): [10]              │     │
│ │ Minute: [00]                           │     │
│ │                                        │     │
│ │ ╭─────────────────────────────────╮   │     │
│ │ │ Scheduled Start Time:           │   │     │
│ │ │ 🇺🇸 Pacific: 2025-11-02 10:00 AM PDT│   │
│ │ │ 🇷🇴 Romania: 2025-11-02 20:00 EEST  │   │
│ │ │ ⚠️ Listing will not be visible  │   │     │
│ │ │    until scheduled time.        │   │     │
│ │ │    Scheduling fee applies.      │   │     │
│ │ ╰─────────────────────────────────╯   │     │
│ └────────────────────────────────────────┘     │
│                                                 │
│ [Send to eBay]                                  │
└─────────────────────────────────────────────────┘
```

When "List Immediately" is checked:

```
┌─────────────────────────────────────────────────┐
│ eBay Export                                     │
├─────────────────────────────────────────────────┤
│ Title: Vintage Bucharest...                     │
│ Listing Type: [Auction ▼]                      │
│ Starting Bid: 4.99                              │
│ Duration: [7 Days ▼]                           │
│                                                 │
│ ┌─ Listing Schedule ────────────────────┐     │
│ │ ☑ List Immediately (skip scheduling)  │     │
│ └────────────────────────────────────────┘     │
│                                                 │
│ [Send to eBay]                                  │
└─────────────────────────────────────────────────┘
```

---

## Success Criteria

### Definition of Done

- [ ] Time utility functions created (`ebay_time_helpers.R`)
- [ ] `calculate_next_10am_pacific()` correctly calculates next 10 AM PDT
- [ ] ISO 8601 formatting works correctly
- [ ] Time validation rejects invalid times (past, > 3 weeks, < 1 hour)
- [ ] Database schema updated with scheduling fields
- [ ] Migration function created and tested
- [ ] Trading API XML builders include ScheduleTime
- [ ] Trading API response parser extracts StartTime
- [ ] Integration layer passes schedule_time to API
- [ ] UI shows scheduling controls for postcards
- [ ] UI shows scheduling controls for stamps
- [ ] UI defaults to next 10:00 AM PDT
- [ ] UI displays both Pacific and Romania times
- [ ] UI "List Immediately" checkbox bypasses scheduling
- [ ] Confirmation modal shows schedule information
- [ ] Database saves schedule_time and actual_start_time
- [ ] Comprehensive unit tests written and passing (critical suite)
- [ ] End-to-end test: Schedule listing in sandbox
- [ ] End-to-end test: Immediate listing still works
- [ ] Documentation updated (this PRP serves as docs)
- [ ] Backups created before modifying files

### Verification Steps

1. **Unit Tests Pass**:
   ```r
   # Run time helper tests
   testthat::test_file("tests/testthat/test-ebay_time_helpers.R")

   # Run Trading API scheduled tests
   testthat::test_file("tests/testthat/test-ebay_trading_api_scheduled.R")

   # Run critical test suite
   source("dev/run_critical_tests.R")
   # Expected: All tests pass (100%)
   ```

2. **Manual Sandbox Test - Scheduled Listing**:
   - Launch app in sandbox mode
   - Process a postcard with AI extraction
   - Leave "List Immediately" unchecked
   - Verify default shows next 10:00 AM PDT
   - Change to custom time (e.g., 2 hours from now)
   - Verify Romania time display updates
   - Click "Send to eBay"
   - Verify confirmation modal shows schedule
   - Confirm and send
   - Check eBay sandbox: Listing should NOT be visible yet
   - Check database: `is_scheduled = 1`, `schedule_time` populated

3. **Manual Sandbox Test - Immediate Listing**:
   - Check "List Immediately"
   - Click "Send to eBay"
   - Verify listing created immediately
   - Check eBay sandbox: Listing visible now
   - Check database: `is_scheduled = 0`, `schedule_time = NULL`

4. **Time Calculation Verification**:
   ```r
   # Test at various Romania times
   # 14:00 Romania (2 PM) = 04:00 PDT (4 AM) → Should schedule for TODAY 10:00 AM PDT
   # 21:00 Romania (9 PM) = 11:00 PDT (11 AM) → Should schedule for TOMORROW 10:00 AM PDT

   next_time <- calculate_next_10am_pacific()
   format_display_time(next_time)
   ```

5. **Database Verification**:
   ```r
   # Check scheduled listing record
   DBI::dbGetQuery(con, "
     SELECT item_id, is_scheduled, schedule_time, actual_start_time
     FROM ebay_listings
     WHERE is_scheduled = 1
     ORDER BY created_at DESC
     LIMIT 1
   ")
   # Expected: schedule_time in ISO format, actual_start_time from eBay response
   ```

---

## Dependencies

### R Packages
- `xml2` (already installed) - XML generation
- `httr2` (already installed) - HTTP requests
- `R6` (already installed) - OOP for API client
- `DBI` (already installed) - Database operations
- `shiny` (already installed) - UI components
- `bslib` (already installed) - UI layout

### External APIs
- eBay Trading API - `AddItem` with ScheduleTime field
- eBay Trading API - `AddFixedPriceItem` with ScheduleTime field

### Time Zone Data
- R's built-in timezone database (`America/Los_Angeles`, `Europe/Bucharest`)
- Handles PDT/PST and EET/EEST transitions automatically

---

## Risks and Mitigations

### Risk 1: Daylight Saving Time Transitions
**Likelihood**: Medium
**Impact**: High (incorrect scheduled times)
**Mitigation**:
- Use R's native timezone support (`America/Los_Angeles`, `Europe/Bucharest`)
- R automatically handles DST transitions
- Always convert to UTC for eBay API
- Test during DST transition periods (March, November)

### Risk 2: eBay Scheduling Fees
**Likelihood**: High
**Impact**: Low (user surprise)
**Mitigation**:
- Display clear warning: "Scheduling fee applies"
- Show warning in confirmation modal
- Document fee in user guide
- Consider making "List Immediately" the default if fees are concerning

### Risk 3: User Confusion with Time Zones
**Likelihood**: Medium
**Impact**: Medium
**Mitigation**:
- Show BOTH Pacific and Romania times side-by-side
- Use clear labels and timezone abbreviations
- Provide visual confirmation before sending
- Test with real users for UX feedback

### Risk 4: Scheduled Time Already Passed
**Likelihood**: Low
**Impact**: Medium
**Mitigation**:
- Validate with 1-hour minimum buffer
- Show real-time validation errors
- Auto-calculate smart default (next 10 AM PDT)
- Prevent form submission if validation fails

### Risk 5: Backwards Compatibility
**Likelihood**: Low
**Impact**: High
**Mitigation**:
- Make schedule_time nullable in database
- Default `is_scheduled = 0` for existing records
- Existing code works without changes (schedule_time = NULL)
- Test with existing data before deploying

---

## Future Enhancements (Out of Scope)

### Nice-to-Have Features
1. **Preset Times**: Quick buttons for common times (10 AM, 12 PM, 6 PM PDT)
2. **Bulk Scheduling**: Schedule multiple listings for same time
3. **Schedule Calendar View**: Visual calendar showing all scheduled listings
4. **Reschedule Feature**: Change scheduled time before listing goes live
5. **Schedule Templates**: Save and reuse favorite schedule times
6. **Optimal Time Suggestions**: ML-based suggestions for best listing times based on category
7. **Email Reminders**: Notify user when scheduled listing goes live
8. **Schedule Queue**: Queue up multiple listings at different times

### Analytics
1. Track scheduled vs immediate listing performance
2. Monitor conversion rates by listing time
3. Analyze optimal listing times by category
4. A/B test different scheduling strategies

---

## References

### eBay API Documentation
- [AddItem API Reference](https://developer.ebay.com/devzone/xml/docs/reference/ebay/additem.html)
- [ScheduleTime Field Specification](https://developer.ebay.com/support/kb-article?KBid=1473)
- [GeteBayTime API](https://developer.ebay.com/devzone/shopping/docs/CallRef/GeteBayTime.html)

### Time Zone References
- [Pacific Daylight Time (PDT)](https://www.timeanddate.com/time/zones/pdt) - UTC-7
- [Eastern European Time (EET)](https://www.timeanddate.com/time/zones/eet) - UTC+2
- [ISO 8601 DateTime Format](https://en.wikipedia.org/wiki/ISO_8601)

### Project Documentation
- `CLAUDE.md` - Core principles and constraints
- `.serena/memories/ebay_trading_api_complete_20251028.md` - Current Trading API implementation
- `.serena/memories/testing_infrastructure_complete_20251023.md` - Testing strategy

### Related PRPs
- `PRP_EBAY_AUCTION_SUPPORT.md` - Auction listing implementation
- `PRP_EBAY_TRADING_API_IMPLEMENTATION.md` - Original Trading API work

---

## Notes for Implementation

### Code Style Reminders
1. **Follow Golem conventions** - Use established patterns
2. **Backup before modifying** - Save to `Delcampe_BACKUP/` folder (OUTSIDE R/ directory)
3. **Test-driven development** - Write tests alongside code
4. **Run critical tests** - Must pass before committing
5. **showNotification types** - Only use "message", "warning", "error" (NOT "success")

### Development Workflow
```r
# 1. Create time helpers
# Create R/ebay_time_helpers.R

# 2. Write tests first
# Create tests/testthat/test-ebay_time_helpers.R
testthat::test_file("tests/testthat/test-ebay_time_helpers.R")

# 3. Database migration
source("dev/migrate_add_scheduled_fields.R")

# 4. Update Trading API
# Edit R/ebay_trading_api.R
# Edit R/ebay_integration.R

# 5. Write Trading API tests
# Create tests/testthat/test-ebay_trading_api_scheduled.R
testthat::test_file("tests/testthat/test-ebay_trading_api_scheduled.R")

# 6. Update UI (postcards)
# Edit R/mod_delcampe_export.R

# 7. Update UI (stamps)
# Edit R/mod_stamp_export.R

# 8. Test end-to-end in sandbox
devtools::load_all()
golem::run_dev()

# 9. Run critical tests before committing
source("dev/run_critical_tests.R")

# 10. Commit with clear message
# git add -A
# git commit -m "feat: Add eBay scheduled listing support with 10 AM PDT default"
```

### Testing Priority
1. **CRITICAL** - Time calculation (next 10 AM PDT)
2. **CRITICAL** - ISO 8601 formatting
3. **CRITICAL** - Schedule time validation (future, < 3 weeks, > 1 hour)
4. **CRITICAL** - XML generation with ScheduleTime
5. **HIGH** - UI time zone display (Pacific + Romania)
6. **HIGH** - Database save/retrieve
7. **MEDIUM** - Confirmation modal display
8. **LOW** - Edge cases (DST transitions)

---

## Questions for Clarification

Before starting implementation, confirm:

1. ✅ **Default Time** - 10:00 AM PDT confirmed as default?
   - **Answer**: User specified "10:00 AM Pacific Daylight Time" - Confirmed ✅

2. ⚠️ **Default Behavior** - Should scheduling be ON by default or OFF?
   - **Option A**: Default to scheduled (10 AM PDT), user checks "List Immediately" to skip
   - **Option B**: Default to immediate, user unchecks "List Immediately" to schedule
   - **Recommendation**: Option A - Scheduling ON by default (matches user's strategic intent)

3. ⚠️ **PST vs PDT** - How to handle PST season (November - March)?
   - **Recommendation**: Always calculate "10:00 AM Pacific" (let R handle PDT/PST)
   - Labels should say "Pacific Time" not explicitly "PDT"

4. ⚠️ **UI Placement** - Where to place scheduling controls?
   - **Option A**: Separate accordion panel "Listing Schedule"
   - **Option B**: Inline after listing type/duration
   - **Recommendation**: Option A - Separate panel for clarity

5. ⚠️ **Scheduling Fees** - Should we warn user about fees more prominently?
   - **Recommendation**: Yes - show warning in UI and confirmation modal

6. ⚠️ **Stamps vs Postcards** - Same scheduling UI for both?
   - **Recommendation**: Yes - identical functionality, reuse components

---

## Completion Checklist

When implementation is complete, create a Serena memory:
`.serena/memories/ebay_scheduled_listing_10am_pdt_complete_YYYYMMDD.md`

Include:
- ✅ Time calculation algorithm and accuracy
- ✅ Time zone conversion examples
- ✅ Database schema changes
- ✅ API methods updated
- ✅ UI components and user flow
- ✅ Test coverage (X tests passing)
- ✅ Sandbox verification (scheduled item IDs)
- ⚠️ Known limitations (DST edge cases, etc.)
- 📋 Future enhancements (from this PRP)

---

**End of PRP**

**Next Step**: Review with user, confirm default behavior (scheduling ON or OFF by default), then begin Phase 1 (Time Utility Functions).
