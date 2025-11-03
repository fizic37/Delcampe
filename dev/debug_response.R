# Quick debug - show what eBay returned

source("R/ebay_api.R")
library(xml2)
library(httr2)

api_result <- init_ebay_api(environment = "production")
oauth <- api_result$oauth
config <- api_result$config

xml_body <- '<?xml version="1.0" encoding="utf-8"?>
<GetCategoriesRequest xmlns="urn:ebay:apis:eBLBaseComponents">
  <CategoryParent>260</CategoryParent>
  <DetailLevel>ReturnAll</DetailLevel>
  <ViewAllNodes>true</ViewAllNodes>
  <LevelLimit>5</LevelLimit>
</GetCategoriesRequest>'

endpoint <- "https://api.ebay.com/ws/api.dll"
token <- oauth$get_access_token()

req <- httr2::request(endpoint) |>
  httr2::req_headers(
    "X-EBAY-API-SITEID" = "0",
    "X-EBAY-API-COMPATIBILITY-LEVEL" = "1355",
    "X-EBAY-API-CALL-NAME" = "GetCategories",
    "X-EBAY-API-IAF-TOKEN" = token,
    "Content-Type" = "text/xml"
  ) |>
  httr2::req_body_raw(xml_body, type = "text/xml")

http_response <- httr2::req_perform(req)
xml_string <- httr2::resp_body_string(http_response)

cat("\n=== RAW RESPONSE ===\n\n")
cat(xml_string)
cat("\n\n=== END RESPONSE ===\n")

# Save to file for inspection
writeLines(xml_string, "dev/ebay_response_debug.xml")
cat("\nSaved to: dev/ebay_response_debug.xml\n")
