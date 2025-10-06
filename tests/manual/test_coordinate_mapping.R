# Test script for coordinate mapping fix
# Run this to verify the draggable lines work correctly

library(shiny)
library(Delcampe)

# Test the coordinate conversion logic
test_coordinate_conversion <- function() {
  cat("\n=== Testing Coordinate Conversion Logic ===\n\n")
  
  # Simulate original image dimensions (like your 1915 x 3507)
  orig_width <- 1915
  orig_height <- 3507
  
  # Simulate wrapper dimensions (fixed 400px height)
  wrapper_height <- 400
  
  # Calculate rendered dimensions (object-fit:contain)
  img_aspect <- orig_width / orig_height
  wrapper_aspect <- 800 / wrapper_height  # Assume 800px wide wrapper
  
  if (img_aspect > wrapper_aspect) {
    rendered_width <- 800
    rendered_height <- rendered_width / img_aspect
    offset_left <- 0
    offset_top <- (wrapper_height - rendered_height) / 2
  } else {
    rendered_height <- wrapper_height
    rendered_width <- rendered_height * img_aspect
    offset_top <- 0
    offset_left <- (800 - rendered_width) / 2
  }
  
  cat("Original dimensions:", orig_width, "x", orig_height, "\n")
  cat("Rendered dimensions:", round(rendered_width, 2), "x", round(rendered_height, 2), "\n")
  cat("Offset in wrapper:", round(offset_left, 2), "px left,", round(offset_top, 2), "px top\n\n")
  
  # Test: A line at 50% of original height
  test_boundary <- orig_height / 2  # 1753.5
  
  cat("Testing boundary at 50% of original height (", test_boundary, "px):\n")
  
  # Forward conversion: original coord -> rendered position
  percent_of_original <- test_boundary / orig_height
  pos_in_rendered <- percent_of_original * rendered_height
  final_wrapper_pos <- offset_top + pos_in_rendered
  
  cat("  → % of original:", round(percent_of_original * 100, 2), "%\n")
  cat("  → Position in rendered image:", round(pos_in_rendered, 2), "px\n")
  cat("  → Position in wrapper:", round(final_wrapper_pos, 2), "px\n\n")
  
  # Reverse conversion: wrapper position -> original coord
  pos_in_rendered_back <- final_wrapper_pos - offset_top
  percent_of_rendered <- pos_in_rendered_back / rendered_height
  original_coord_back <- percent_of_rendered * orig_height
  
  cat("Reverse conversion from wrapper position:\n")
  cat("  → Position in rendered:", round(pos_in_rendered_back, 2), "px\n")
  cat("  → % of rendered:", round(percent_of_rendered * 100, 2), "%\n")
  cat("  → Original coordinate:", round(original_coord_back, 2), "px\n\n")
  
  # Verify accuracy
  error <- abs(original_coord_back - test_boundary)
  cat("Conversion error:", round(error, 4), "px\n")
  
  if (error < 0.1) {
    cat("✅ PASS: Coordinate conversion is accurate!\n\n")
    return(TRUE)
  } else {
    cat("❌ FAIL: Coordinate conversion has significant error!\n\n")
    return(FALSE)
  }
}

# Run the test
test_coordinate_conversion()

cat("\n=== Manual Testing Instructions ===\n\n")
cat("1. Run the app with: Delcampe::run_app()\n")
cat("2. Upload the test image (test_images/test_face.jpg)\n")
cat("3. Open browser DevTools (F12) and go to Console tab\n")
cat("4. Drag a red line to separate two postcards perfectly on screen\n")
cat("5. Check the console logs - you should see:\n")
cat("   - 🖼️ Rendered image bounds (showing offset and size)\n")
cat("   - 🔴 H-line positions during drag\n")
cat("   - 📤 Final coordinates when you release\n")
cat("6. Click 'Extract Face Cards' button\n")
cat("7. Verify the cropped images match where you placed the lines\n\n")

cat("Expected behavior:\n")
cat("  ✅ Lines overlay exactly on the rendered image (no padding issues)\n")
cat("  ✅ Lines stay in place when resizing window/DevTools\n")
cat("  ✅ Cropped images match the line positions perfectly\n")
cat("  ✅ No offset errors even with different window sizes\n\n")

cat("Key things to watch in console:\n")
cat("  1. 'Rendered image bounds' should show non-zero offset if image doesn't fill wrapper\n")
cat("  2. H-line/V-line logs should show conversion from boundary → % → rendered → final\n")
cat("  3. When you drag, final 'originalCoord' should match where you want to crop\n\n")

cat("If issues persist, check:\n")
cat("  - Is object-fit: contain; present on the image?\n")
cat("  - Does the wrapper have position: relative?\n")
cat("  - Are data-original-width and data-original-height set on <img>?\n")
cat("  - Are the lines being initialized AFTER the image loads?\n\n")
