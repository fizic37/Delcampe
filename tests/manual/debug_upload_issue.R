# Debug script to identify image upload display issue
# Run this in RStudio console after starting the app

library(shiny)

# Test 1: Check if image path is being created correctly
test_image_path_creation <- function() {
  cat("\n=== TEST 1: Image Path Creation ===\n")
  
  # Simulate the path creation logic
  session_temp_dir <- tempfile("shiny_session_images_")
  dir.create(session_temp_dir, showWarnings = FALSE, recursive = TRUE)
  
  timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
  safe_filename <- paste0("uploaded_face_", timestamp, ".jpg")
  upload_path <- file.path(session_temp_dir, safe_filename)
  
  cat("Session temp dir:", session_temp_dir, "\n")
  cat("Upload path:", upload_path, "\n")
  
  # Test path normalization
  norm_session_dir <- normalizePath(session_temp_dir, winslash = "/")
  cat("Normalized session dir:", norm_session_dir, "\n")
  
  # Create a dummy file
  file.create(upload_path)
  norm_upload_path <- normalizePath(upload_path, winslash = "/")
  cat("Normalized upload path:", norm_upload_path, "\n")
  
  # Test URL construction
  rel_path <- sub(paste0("^", gsub("/", "\\\\/", norm_session_dir), "/*"), "", norm_upload_path)
  rel_path <- sub("^/*", "", rel_path)
  
  resource_prefix <- "face_processor-session_images"
  image_url <- file.path(resource_prefix, rel_path)
  
  cat("Relative path:", rel_path, "\n")
  cat("Image URL:", image_url, "\n")
  cat("Full URL:", paste0("/", image_url), "\n")
  
  # Cleanup
  unlink(session_temp_dir, recursive = TRUE)
  
  return(invisible(TRUE))
}

# Test 2: Check CSS visibility issues
test_css_visibility <- function() {
  cat("\n=== TEST 2: CSS Visibility Check ===\n")
  cat("Check these in browser DevTools:\n")
  cat("1. Is #face_processor-grid_ui_wrapper visible?\n")
  cat("2. Does #face_processor-preview_image have display:block?\n")
  cat("3. Is the image src attribute set correctly?\n")
  cat("4. Check Network tab - is the image loading?\n")
  cat("5. Check Console for JavaScript errors\n")
  cat("\nBrowser DevTools Commands:\n")
  cat("document.getElementById('face_processor-grid_ui_wrapper')\n")
  cat("document.getElementById('face_processor-preview_image')\n")
  cat("document.querySelectorAll('.draggable-line').length\n")
}

# Test 3: Check namespace issues
test_namespace <- function() {
  cat("\n=== TEST 3: Namespace Check ===\n")
  
  # Test namespace function
  ns <- NS("face_processor")
  
  cat("Namespace examples:\n")
  cat("grid_ui_wrapper:", ns("grid_ui_wrapper"), "\n")
  cat("preview_image:", ns("preview_image"), "\n")
  cat("hline_1:", ns("hline_1"), "\n")
  cat("vline_1:", ns("vline_1"), "\n")
  
  cat("\nExpected IDs in HTML:\n")
  cat("- face_processor-grid_ui_wrapper\n")
  cat("- face_processor-preview_image\n")
  cat("- face_processor-hline_1, face_processor-hline_2, etc.\n")
  cat("- face_processor-vline_1, face_processor-vline_2, etc.\n")
}

# Run all tests
run_all_debug_tests <- function() {
  cat("\n╔══════════════════════════════════════════════════════════╗\n")
  cat("║  Delcampe Upload Display Debug Tests                    ║\n")
  cat("╚══════════════════════════════════════════════════════════╝\n")
  
  test_image_path_creation()
  test_namespace()
  test_css_visibility()
  
  cat("\n╔══════════════════════════════════════════════════════════╗\n")
  cat("║  Next Steps                                              ║\n")
  cat("╚══════════════════════════════════════════════════════════╝\n")
  cat("1. Start the app: devtools::load_all(); run_app()\n")
  cat("2. Upload an image\n")
  cat("3. Open Browser DevTools (F12)\n")
  cat("4. Check Console for errors\n")
  cat("5. Check Network tab for image request\n")
  cat("6. Run these in Console:\n")
  cat("   - document.getElementById('face_processor-preview_image')\n")
  cat("   - document.getElementById('face_processor-grid_ui_wrapper')\n")
  cat("7. Check Elements tab - inspect the grid wrapper\n\n")
}

# Export function
if (interactive()) {
  run_all_debug_tests()
}
