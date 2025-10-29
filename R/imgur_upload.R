#' Upload Image to imgbb
#'
#' @description Upload an image file to imgbb and get a public HTTPS URL
#' @param image_path Local file path to image
#' @param api_key imgbb API key (get from https://api.imgbb.com/)
#' @return List with success, url, delete_url
#' @export
upload_to_imgbb <- function(image_path, api_key = Sys.getenv("IMGBB_API_KEY")) {

  cat("\n=== Uploading to imgbb ===\n")
  cat("   Image path:", image_path, "\n")

  # Check file exists
  if (!file.exists(image_path)) {
    return(list(
      success = FALSE,
      error = "Image file not found"
    ))
  }

  # Check API key
  if (is.null(api_key) || api_key == "" || api_key == "YOUR_API_KEY_HERE") {
    cat("   ⚠️ No imgbb API key found in environment\n")
    cat("   Set IMGBB_API_KEY in .Renviron file\n")
    cat("   Get API key from: https://api.imgbb.com/\n")
    return(list(
      success = FALSE,
      error = "imgbb API key not configured. Set IMGBB_API_KEY environment variable."
    ))
  }

  tryCatch({
    # Read image as base64
    image_binary <- readBin(image_path, "raw", file.info(image_path)$size)
    image_base64 <- base64enc::base64encode(image_binary)

    cat("   Image size:", length(image_binary), "bytes\n")
    cat("   Uploading to imgbb...\n")

    # Make request to imgbb API
    response <- httr2::request("https://api.imgbb.com/1/upload") |>
      httr2::req_method("POST") |>
      httr2::req_body_form(
        key = api_key,
        image = image_base64,
        name = tools::file_path_sans_ext(basename(image_path))
      ) |>
      httr2::req_perform()

    # Check response
    if (httr2::resp_status(response) != 200) {
      error_msg <- paste0("HTTP ", httr2::resp_status(response))
      cat("   ❌ Upload failed:", error_msg, "\n")
      return(list(
        success = FALSE,
        error = error_msg
      ))
    }

    # Parse response
    data <- httr2::resp_body_json(response)

    if (!data$success) {
      error_msg <- if (!is.null(data$error$message)) data$error$message else "Unknown error"
      cat("   ❌ imgbb API returned error:", error_msg, "\n")
      return(list(
        success = FALSE,
        error = paste0("imgbb API error: ", error_msg)
      ))
    }

    image_url <- data$data$url
    delete_url <- data$data$delete_url

    cat("   ✅ Image uploaded to imgbb\n")
    cat("   URL:", image_url, "\n")

    return(list(
      success = TRUE,
      url = image_url,
      delete_url = delete_url,
      id = data$data$id
    ))

  }, error = function(e) {
    cat("   ❌ Upload exception:", e$message, "\n")
    return(list(
      success = FALSE,
      error = paste0("Upload exception: ", e$message)
    ))
  })
}

#' Upload Image to Imgur (DEPRECATED - use imgbb instead)
#'
#' @description Upload an image file to Imgur and get a public HTTPS URL
#' @param image_path Local file path to image
#' @param client_id Imgur Client ID (get from https://api.imgur.com/oauth2/addclient)
#' @return List with success, url, delete_hash
#' @export
upload_to_imgur <- function(image_path, client_id = Sys.getenv("IMGUR_CLIENT_ID")) {

  cat("\n=== Uploading to Imgur ===\n")
  cat("   Image path:", image_path, "\n")

  # Check file exists
  if (!file.exists(image_path)) {
    return(list(
      success = FALSE,
      error = "Image file not found"
    ))
  }

  # Check client ID
  if (is.null(client_id) || client_id == "" || client_id == "YOUR_CLIENT_ID_HERE") {
    cat("   ⚠️ No Imgur Client ID found in environment\n")
    cat("   Set IMGUR_CLIENT_ID in .Renviron file\n")
    cat("   Get Client ID from: https://api.imgur.com/oauth2/addclient\n")
    return(list(
      success = FALSE,
      error = "Imgur Client ID not configured. Set IMGUR_CLIENT_ID environment variable."
    ))
  }

  tryCatch({
    # Read image as base64
    image_binary <- readBin(image_path, "raw", file.info(image_path)$size)
    image_base64 <- base64enc::base64encode(image_binary)

    cat("   Image size:", length(image_binary), "bytes\n")
    cat("   Uploading to Imgur...\n")

    # Make request to Imgur API
    response <- httr2::request("https://api.imgur.com/3/image") |>
      httr2::req_method("POST") |>
      httr2::req_headers(
        "Authorization" = paste("Client-ID", client_id)
      ) |>
      httr2::req_body_form(
        image = image_base64,
        type = "base64",
        name = basename(image_path),
        title = "Postcard Image"
      ) |>
      httr2::req_perform()

    # Check response
    if (httr2::resp_status(response) != 200) {
      error_msg <- paste0("HTTP ", httr2::resp_status(response))
      cat("   ❌ Upload failed:", error_msg, "\n")
      return(list(
        success = FALSE,
        error = error_msg
      ))
    }

    # Parse response
    data <- httr2::resp_body_json(response)

    if (!data$success) {
      cat("   ❌ Imgur API returned error\n")
      return(list(
        success = FALSE,
        error = "Imgur API error"
      ))
    }

    image_url <- data$data$link
    delete_hash <- data$data$deletehash

    cat("   ✅ Image uploaded to Imgur\n")
    cat("   URL:", image_url, "\n")
    cat("   Delete hash:", delete_hash, "(save this to delete image later)\n")

    return(list(
      success = TRUE,
      url = image_url,
      delete_hash = delete_hash,
      id = data$data$id
    ))

  }, error = function(e) {
    cat("   ❌ Upload exception:", e$message, "\n")
    return(list(
      success = FALSE,
      error = paste0("Upload exception: ", e$message)
    ))
  })
}

#' Delete Image from Imgur
#'
#' @param delete_hash Delete hash from upload response
#' @param client_id Imgur Client ID
#' @export
delete_from_imgur <- function(delete_hash, client_id = Sys.getenv("IMGUR_CLIENT_ID")) {
  tryCatch({
    response <- httr2::request(paste0("https://api.imgur.com/3/image/", delete_hash)) |>
      httr2::req_method("DELETE") |>
      httr2::req_headers(
        "Authorization" = paste("Client-ID", client_id)
      ) |>
      httr2::req_perform()

    return(httr2::resp_status(response) == 200)
  }, error = function(e) {
    return(FALSE)
  })
}
