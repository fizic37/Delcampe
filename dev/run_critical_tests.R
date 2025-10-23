# Critical Test Suite Runner
#
# Runs only stable, important tests that should always pass
# Use this for regular development and CI/CD
#
# Usage: source("dev/run_critical_tests.R")

cat("==============================================\n")
cat("  Delcampe Critical Test Suite\n")
cat("  (Stable tests for core functionality)\n")
cat("==============================================\n\n")

# Load required packages
required_packages <- c("testthat", "devtools")
missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]

if (length(missing_packages) > 0) {
  cat("Installing missing packages:", paste(missing_packages, collapse = ", "), "\n\n")
  install.packages(missing_packages)
}

library(testthat)
library(devtools)

# Load the package
cat("Loading Delcampe package...\n")
load_result <- tryCatch({
  devtools::load_all()
  cat("✓ Package loaded successfully!\n\n")
  TRUE
}, error = function(e) {
  cat("✗ Error loading package:", e$message, "\n")
  cat("Cannot run tests without package loaded.\n\n")
  return(FALSE)
})

if (!load_result) {
  stop("Package loading failed. Fix errors above before running tests.")
}

# ==== CRITICAL TESTS ====
cat("==============================================\n")
cat("Running Critical Tests\n")
cat("==============================================\n\n")

# Define critical test files
critical_tests <- c(
  "test-ebay_helpers.R",           # eBay functionality (core business logic)
  "test-utils_helpers.R",          # Utility functions (used everywhere)
  "test-mod_delcampe_export.R",    # Delcampe export module (comprehensive)
  "test-mod_tracking_viewer.R"     # Tracking viewer module (comprehensive)
)

# Run each critical test file
all_passed <- TRUE
total_tests <- 0
total_passed <- 0
total_failed <- 0
total_skipped <- 0

for (test_file in critical_tests) {
  cat("\n──────────────────────────────────────────────\n")
  cat("Testing:", test_file, "\n")
  cat("──────────────────────────────────────────────\n")

  result <- tryCatch({
    testthat::test_file(
      paste0("tests/testthat/", test_file),
      reporter = "progress"
    )
  }, error = function(e) {
    cat("✗ Error running test file:", e$message, "\n")
    all_passed <- FALSE
    return(NULL)
  })

  if (!is.null(result)) {
    # Collect results
    total_tests <- total_tests + length(result)
    # Count passed/failed/skipped based on result
    passed <- sum(sapply(result, function(x) inherits(x, "expectation_success")))
    failed <- sum(sapply(result, function(x) inherits(x, "expectation_failure") || inherits(x, "expectation_error")))
    skipped <- sum(sapply(result, function(x) inherits(x, "expectation_skip")))

    total_passed <- total_passed + passed
    total_failed <- total_failed + failed
    total_skipped <- total_skipped + skipped

    if (failed > 0) {
      all_passed <- FALSE
    }
  }
}

# ==== SUMMARY ====
cat("\n")
cat("==============================================\n")
cat("Critical Test Summary\n")
cat("==============================================\n")
cat(sprintf("Total tests run:  %d\n", total_tests))
cat(sprintf("✓ Passed:         %d\n", total_passed))
cat(sprintf("✗ Failed:         %d\n", total_failed))
cat(sprintf("⊘ Skipped:        %d\n", total_skipped))
cat("==============================================\n\n")

if (all_passed && total_failed == 0) {
  cat("✅ SUCCESS! All critical tests passed!\n")
  cat("Your core functionality is working correctly.\n\n")
} else {
  cat("⚠️  FAILURE! Some critical tests failed.\n")
  cat("Review the output above and fix failing tests.\n")
  cat("Critical tests should always pass!\n\n")
}

# ==== NOTES ====
cat("──────────────────────────────────────────────\n")
cat("Notes:\n")
cat("──────────────────────────────────────────────\n")
cat("• Critical tests cover core business logic\n")
cat("• These tests should always pass before committing\n")
cat("• Run discovery tests with: source('dev/run_discovery_tests.R')\n")
cat("• Run ALL tests with: source('dev/run_tests.R')\n\n")

# Return result invisibly for scripting
invisible(all_passed)
