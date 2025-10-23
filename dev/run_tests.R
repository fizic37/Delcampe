# Development Script: Run Tests and Generate Coverage Report
#
# This script provides an easy way to run the test suite locally
# and generate coverage reports during development.
#
# Usage:
#   source("dev/run_tests.R")
#
# Or from command line:
#   Rscript dev/run_tests.R

cat("==============================================\n")
cat("  Delcampe Test Suite Runner (ALL TESTS)\n")
cat("==============================================\n\n")

cat("ℹ️  TIP: For faster, focused testing use:\n")
cat("   • Critical tests only: source('dev/run_critical_tests.R')\n")
cat("   • Discovery tests only: source('dev/run_discovery_tests.R')\n")
cat("   • See strategy: dev/TESTING_STRATEGY.md\n\n")

# Load required packages
required_packages <- c("testthat", "covr", "devtools")
missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]

if (length(missing_packages) > 0) {
  cat("Installing missing packages:", paste(missing_packages, collapse = ", "), "\n\n")
  install.packages(missing_packages)
}

library(testthat)
library(covr)
library(devtools)

# ==== CRITICAL: LOAD THE PACKAGE FIRST ====
cat("==============================================\n")
cat("Loading Delcampe package...\n")
cat("==============================================\n\n")

load_result <- tryCatch({
  devtools::load_all()
  cat("✓ Package loaded successfully!\n\n")
  TRUE
}, error = function(e) {
  cat("✗ Error loading package:", e$message, "\n")
  cat("Tests cannot run without package loaded.\n\n")
  return(FALSE)
})

if (!load_result) {
  stop("Package loading failed. Fix errors above before running tests.")
}

# ==== OPTION 1: RUN ALL TESTS ====
cat("==============================================\n")
cat("Running all tests...\n")
cat("==============================================\n\n")

test_results <- tryCatch({
  testthat::test_dir("tests/testthat", reporter = "progress")
}, error = function(e) {
  cat("Error running tests:", e$message, "\n")
  NULL
})

cat("\n")

# ==== OPTION 2: RUN SPECIFIC TEST FILE ====
run_specific_test <- function(file_name) {
  cat("==============================================\n")
  cat("Running specific test:", file_name, "\n")
  cat("==============================================\n\n")

  testthat::test_file(paste0("tests/testthat/", file_name))
}

# Example usage (uncomment to run):
# run_specific_test("test-tracking_database.R")
# run_specific_test("test-ai_api_helpers.R")

# ==== OPTION 3: GENERATE COVERAGE REPORT ====
cat("==============================================\n")
cat("Generating coverage report...\n")
cat("==============================================\n\n")

coverage <- tryCatch({
  covr::package_coverage(
    type = "tests",
    quiet = FALSE,
    clean = FALSE
  )
}, error = function(e) {
  cat("Error generating coverage:", e$message, "\n")
  return(NULL)
})

if (!is.null(coverage)) {
  # Print coverage summary
  cat("\n==============================================\n")
  cat("Coverage Summary\n")
  cat("==============================================\n")
  print(coverage)

  # Calculate overall coverage percentage
  cov_data <- covr::percent_coverage(coverage)
  cat(sprintf("\nOverall Coverage: %.2f%%\n", cov_data))

  # Show coverage by file
  cat("\n==============================================\n")
  cat("Coverage by File\n")
  cat("==============================================\n")
  file_coverage <- covr::file_coverage(coverage)
  print(file_coverage)

  # Generate HTML report (opens in browser)
  cat("\n==============================================\n")
  cat("Generating HTML coverage report...\n")
  cat("==============================================\n")
  report_file <- covr::report(coverage, file = "coverage-report.html", browse = FALSE)
  cat("Coverage report saved to:", report_file, "\n")
  cat("Open in browser to view detailed coverage.\n")
}

# ==== SUMMARY ====
cat("\n==============================================\n")
cat("Test Run Summary\n")
cat("==============================================\n")

if (!is.null(test_results)) {
  cat("Tests completed successfully!\n")
} else {
  cat("Some tests failed or errored. Check output above.\n")
}

if (!is.null(coverage)) {
  cov_pct <- covr::percent_coverage(coverage)
  if (cov_pct >= 70) {
    cat(sprintf("✓ Coverage (%.2f%%) meets target of 70%%\n", cov_pct))
  } else {
    cat(sprintf("✗ Coverage (%.2f%%) below target of 70%%\n", cov_pct))
  }
}

cat("\n==============================================\n")
cat("Done!\n")
cat("==============================================\n")

# ==== HELPER FUNCTIONS ====

#' Run tests for a specific module
#'
#' @param module_name Name of the module (e.g., "login", "ai_extraction")
run_module_tests <- function(module_name) {
  test_file <- paste0("test-mod_", module_name, ".R")
  run_specific_test(test_file)
}

#' Run tests for a specific component
#'
#' @param component Name of the component (e.g., "tracking_database", "ai_api_helpers")
run_component_tests <- function(component) {
  test_file <- paste0("test-", component, ".R")
  run_specific_test(test_file)
}

#' Show coverage for a specific file
#'
#' @param file_path Relative path to R file (e.g., "R/tracking_database.R")
show_file_coverage <- function(file_path) {
  coverage <- covr::file_coverage(file_path, "tests/testthat")
  print(coverage)
  covr::report(coverage)
}

# Export functions for interactive use
cat("\nAvailable helper functions:\n")
cat("  - run_module_tests('login')\n")
cat("  - run_component_tests('tracking_database')\n")
cat("  - show_file_coverage('R/tracking_database.R')\n\n")
