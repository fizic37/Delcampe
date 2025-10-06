#!/usr/bin/env Rscript
# Quick verification script for coordinate mapping fix

cat("\n")
cat("╔══════════════════════════════════════════════════════════════════╗\n")
cat("║  Draggable Lines Coordinate Mapping - Verification Script       ║\n")
cat("╚══════════════════════════════════════════════════════════════════╝\n\n")

# Check if required files exist
files_to_check <- c(
  "inst/app/www/draggable_lines.js",
  "inst/app/www/styles.css",
  "R/mod_postal_card_processor.R",
  "tests/test_coordinate_mapping.R",
  "COORDINATE_FIX_SUMMARY.md",
  "IMPLEMENTATION_GUIDE.md"
)

cat("🔍 Checking files...\n\n")
all_exist <- TRUE
for (file in files_to_check) {
  exists <- file.exists(file)
  status <- if (exists) "✅" else "❌"
  cat(sprintf("  %s %s\n", status, file))
  if (!exists) all_exist <- FALSE
}

if (!all_exist) {
  cat("\n❌ Some files are missing! Please ensure all files are present.\n\n")
  quit(status = 1)
}

cat("\n✅ All required files found!\n\n")

# Check JavaScript file content
cat("🔍 Verifying JavaScript implementation...\n\n")

js_content <- readLines("inst/app/www/draggable_lines.js", warn = FALSE)
js_checks <- list(
  "getRenderedImageBounds" = "getRenderedImageBounds function",
  "updateLinePositions" = "updateLinePositions function",
  "imgAspect" = "aspect ratio calculation",
  "data-boundary-value" = "boundary value storage",
  "addEventListener('resize'" = "resize event handler"
)

js_ok <- TRUE
for (check in names(js_checks)) {
  found <- any(grepl(check, js_content, fixed = TRUE))
  status <- if (found) "✅" else "❌"
  cat(sprintf("  %s %s\n", status, js_checks[[check]]))
  if (!found) js_ok <- FALSE
}

if (!js_ok) {
  cat("\n⚠️ JavaScript file may not have all required changes.\n")
  cat("   Please review COORDINATE_FIX_SUMMARY.md\n\n")
} else {
  cat("\n✅ JavaScript implementation looks good!\n\n")
}

# Check R module
cat("🔍 Verifying R module...\n\n")

r_content <- readLines("R/mod_postal_card_processor.R", warn = FALSE)
r_checks <- list(
  "data-original-width" = "original width attribute",
  "data-original-height" = "original height attribute",
  "data-boundary-value" = "boundary value attribute",
  "hline_moved_direct" = "horizontal line observer",
  "vline_moved_direct" = "vertical line observer"
)

r_ok <- TRUE
for (check in names(r_checks)) {
  found <- any(grepl(check, r_content, fixed = TRUE))
  status <- if (found) "✅" else "❌"
  cat(sprintf("  %s %s\n", status, r_checks[[check]]))
  if (!found) r_ok <- FALSE
}

if (!r_ok) {
  cat("\n⚠️ R module may be missing required attributes.\n")
  cat("   Your current R code should already be correct.\n\n")
} else {
  cat("\n✅ R module looks good!\n\n")
}

# Mathematical verification
cat("🧮 Running mathematical verification...\n\n")

orig_width <- 1915
orig_height <- 3507
wrapper_width <- 800
wrapper_height <- 400

img_aspect <- orig_width / orig_height
wrapper_aspect <- wrapper_width / wrapper_height

if (img_aspect > wrapper_aspect) {
  rendered_width <- wrapper_width
  rendered_height <- rendered_width / img_aspect
  offset_left <- 0
  offset_top <- (wrapper_height - rendered_height) / 2
} else {
  rendered_height <- wrapper_height
  rendered_width <- rendered_height * img_aspect
  offset_top <- 0
  offset_left <- (wrapper_width - rendered_width) / 2
}

cat(sprintf("  Original dimensions: %d × %d px\n", orig_width, orig_height))
cat(sprintf("  Rendered dimensions: %.2f × %.2f px\n", rendered_width, rendered_height))
cat(sprintf("  Offset in wrapper: %.2f px left, %.2f px top\n\n", offset_left, offset_top))

# Test coordinate conversion
test_boundary <- orig_height / 2
percent_of_original <- test_boundary / orig_height
pos_in_rendered <- percent_of_original * rendered_height
final_wrapper_pos <- offset_top + pos_in_rendered

cat(sprintf("  Test: Line at 50%% of original height (%.1f px)\n", test_boundary))
cat(sprintf("    → Percentage: %.2f%%\n", percent_of_original * 100))
cat(sprintf("    → Rendered position: %.2f px\n", pos_in_rendered))
cat(sprintf("    → Wrapper position: %.2f px\n\n", final_wrapper_pos))

# Reverse conversion
pos_in_rendered_back <- final_wrapper_pos - offset_top
percent_of_rendered <- pos_in_rendered_back / rendered_height
original_coord_back <- percent_of_rendered * orig_height

cat(sprintf("  Reverse: Wrapper position %.2f px\n", final_wrapper_pos))
cat(sprintf("    → Rendered position: %.2f px\n", pos_in_rendered_back))
cat(sprintf("    → Percentage: %.2f%%\n", percent_of_rendered * 100))
cat(sprintf("    → Original coordinate: %.2f px\n\n", original_coord_back))

error <- abs(original_coord_back - test_boundary)
cat(sprintf("  Conversion error: %.4f px\n\n", error))

if (error < 0.1) {
  cat("  ✅ Mathematical verification PASSED!\n\n")
} else {
  cat("  ❌ Mathematical verification FAILED!\n")
  cat("     Error exceeds acceptable threshold.\n\n")
}

# Final summary
cat("╔══════════════════════════════════════════════════════════════════╗\n")
cat("║                    VERIFICATION SUMMARY                          ║\n")
cat("╚══════════════════════════════════════════════════════════════════╝\n\n")

if (all_exist && js_ok && r_ok && error < 0.1) {
  cat("✅ ALL CHECKS PASSED!\n\n")
  cat("Your coordinate mapping fix is properly implemented.\n\n")
  cat("Next steps:\n")
  cat("  1. Clear browser cache (Ctrl+Shift+R)\n")
  cat("  2. Run app: Delcampe::run_app()\n")
  cat("  3. Upload test image\n")
  cat("  4. Open DevTools (F12) → Console\n")
  cat("  5. Drag lines and verify alignment\n")
  cat("  6. Extract cards and check crops\n\n")
  cat("For detailed testing instructions, see IMPLEMENTATION_GUIDE.md\n\n")
} else {
  cat("⚠️ SOME CHECKS FAILED\n\n")
  cat("Please review:\n")
  if (!all_exist) cat("  - Missing files\n")
  if (!js_ok) cat("  - JavaScript implementation\n")
  if (!r_ok) cat("  - R module configuration\n")
  if (error >= 0.1) cat("  - Coordinate conversion math\n")
  cat("\nSee COORDINATE_FIX_SUMMARY.md for complete documentation.\n\n")
}

cat("═══════════════════════════════════════════════════════════════════\n\n")
