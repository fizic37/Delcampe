test_that("Stamp grade mapping works correctly", {
  expect_equal(map_stamp_grade_to_ebay("MNH"), "USED")  # Per postal card pattern
  expect_equal(map_stamp_grade_to_ebay("Mint Never Hinged"), "USED")
  expect_equal(map_stamp_grade_to_ebay("Mint Hinged"), "USED")
  expect_equal(map_stamp_grade_to_ebay("MH"), "USED")
  expect_equal(map_stamp_grade_to_ebay("Used"), "USED")
  expect_equal(map_stamp_grade_to_ebay("Unused"), "USED")
  expect_equal(map_stamp_grade_to_ebay("Unknown"), "UNSPECIFIED")
  expect_equal(map_stamp_grade_to_ebay(NULL), "UNSPECIFIED")
  expect_equal(map_stamp_grade_to_ebay(NA), "UNSPECIFIED")
})

test_that("Stamp aspects extraction includes stamp-specific fields", {
  ai_data <- list(
    country = "United States",
    year = 1963,
    denomination = "5c",
    grade = "MNH",
    scott_number = "US-1234",
    stamp_count = 1
  )

  aspects <- extract_stamp_aspects(ai_data, "USED")

  expect_true("Type" %in% names(aspects))
  expect_true("Country/Region of Manufacture" %in% names(aspects))
  expect_true("Year of Issue" %in% names(aspects))
  expect_true("Grade" %in% names(aspects))
  expect_true("Catalog Number" %in% names(aspects))
  expect_true("Certification" %in% names(aspects))
  expect_equal(aspects$Type[[1]], "Individual Stamp")
  expect_equal(aspects$`Country/Region of Manufacture`[[1]], "United States")
  expect_equal(aspects$`Year of Issue`[[1]], "1963")
})

test_that("Stamp aspects marks lot correctly", {
  ai_data <- list(
    country = "Romania",
    year = 1920,
    stamp_count = 5
  )

  aspects <- extract_stamp_aspects(ai_data)

  expect_equal(aspects$Type[[1]], "Lot")
})

test_that("Stamp prompt includes philatelic fields", {
  prompt <- build_stamp_prompt("individual", 1)

  expect_true(grepl("DENOMINATION", prompt))
  expect_true(grepl("SCOTT_NUMBER", prompt))
  expect_true(grepl("PERFORATION", prompt))
  expect_true(grepl("GRADE", prompt))
  expect_true(grepl("WATERMARK", prompt))
  expect_true(grepl("ASCII", prompt))
})

test_that("Stamp lot prompt mentions multiple stamps", {
  prompt <- build_stamp_prompt("lot", 6)

  expect_true(grepl("lot of 6 stamps", prompt, ignore.case = TRUE))
  expect_true(grepl("TOP ROW.*Front", prompt))
  expect_true(grepl("BOTTOM ROW.*Back", prompt))
})

test_that("Stamp item data uses category 260", {
  ai_data <- list(
    title = "USA - 1963 5c WASHINGTON",
    description = "1963 George Washington stamp",
    recommended_price = 3.50,
    country = "United States",
    year = 1963,
    grade = "MNH"
  )

  item_data <- build_stamp_item_data(ai_data, list("http://example.com/img.jpg"), 3.50, 1)

  expect_equal(item_data$PrimaryCategory$CategoryID, "260")
  expect_equal(item_data$StartPrice, 3.50)
  expect_equal(item_data$ConditionID, "3000")  # Used condition
})

test_that("Stamp response parsing extracts all fields", {
  response <- "TITLE: USA - 1963 5c WASHINGTON
DESCRIPTION: 1963 George Washington coil stamp with perforation
RECOMMENDED_PRICE: 3.50
COUNTRY: United States
YEAR: 1963
DENOMINATION: 5c
SCOTT_NUMBER: US-1234
PERFORATION: Perf 12
WATERMARK: None
GRADE: MNH"

  result <- parse_stamp_response(response)

  expect_equal(result$title, "USA - 1963 5c WASHINGTON")
  expect_equal(result$description, "1963 George Washington coil stamp with perforation")
  expect_equal(result$recommended_price, 3.50)
  expect_equal(result$country, "United States")
  expect_equal(result$year, 1963)
  expect_equal(result$denomination, "5c")
  expect_equal(result$scott_number, "US-1234")
  expect_equal(result$perforation, "Perf 12")
  expect_equal(result$watermark, "None")
  expect_equal(result$grade, "MNH")
})

test_that("Stamp response parsing handles missing fields", {
  response <- "TITLE: ROMANIA - 1920 FERDINAND
DESCRIPTION: Romanian stamp from 1920
RECOMMENDED_PRICE: 2.00"

  result <- parse_stamp_response(response)

  expect_equal(result$title, "ROMANIA - 1920 FERDINAND")
  expect_true(is.na(result$country))
  expect_true(is.na(result$year))
  expect_true(is.na(result$scott_number))
})
