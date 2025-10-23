# Discovery Test Suite Runner
#
# Runs exploratory tests that help understand and improve the codebase
# These tests may fail - that's expected! They help discover:
# - Function behavior differences
# - Missing error handling
# - API signature mismatches
# - Edge cases
#
# Use this when:
# - Developing new features
# - Refactoring code
# - Investigating bugs
# - Improving test coverage
#
# Usage: source("dev/run_discovery_tests.R")

cat("==============================================\n")
cat("  Delcampe Discovery Test Suite\n")
cat("  (Exploratory tests - failures expected!)\n")
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

# ==== DISCOVERY TESTS ====
cat("==============================================\n")
cat("Running Discovery Tests\n")
cat("==============================================\n\n")

cat("ℹ️  IMPORTANT: Failures here are LEARNING opportunities!\n")
cat("   These tests help us discover:\n")
cat("   • How functions actually behave\n")
cat("   • Where error handling is needed\n")
cat("   • API signature differences\n")
cat("   • Edge cases to handle\n\n")

# Define discovery test files
discovery_tests <- c(
  "test-ai_api_helpers.R",         # AI integration (exploratory)
  "test-tracking_database.R",      # Database functions (needs setup)
  "test-mod_login.R",              # Module templates (mostly skipped)
  "test-mod_settings_llm.R"        # Module templates (mostly skipped)
)

# Track statistics
total_files <- length(discovery_tests)
files_run <- 0
total_tests <- 0
total_passed <- 0
total_failed <- 0
total_skipped <- 0
total_errors <- 0

for (test_file in discovery_tests) {
  cat("\n──────────────────────────────────────────────\n")
  cat("Testing:", test_file, "\n")
  cat("──────────────────────────────────────────────\n")

  # Check if file exists
  full_path <- paste0("tests/testthat/", test_file)
  if (!file.exists(full_path)) {
    cat("⊘ Skipped - file not found\n")
    next
  }

  result <- tryCatch({
    testthat::test_file(full_path, reporter = "progress")
  }, error = function(e) {
    cat("⚠️  Error running test file:", e$message, "\n")
    total_errors <<- total_errors + 1
    return(NULL)
  })

  files_run <- files_run + 1

  if (!is.null(result)) {
    # Collect results
    total_tests <- total_tests + length(result)
    passed <- sum(sapply(result, function(x) inherits(x, "expectation_success")))
    failed <- sum(sapply(result, function(x) inherits(x, "expectation_failure") || inherits(x, "expectation_error")))
    skipped <- sum(sapply(result, function(x) inherits(x, "expectation_skip")))

    total_passed <- total_passed + passed
    total_failed <- total_failed + failed
    total_skipped <- total_skipped + skipped

    # Show mini-summary for this file
    cat(sprintf("  Passed: %d | Failed: %d | Skipped: %d\n", passed, failed, skipped))
  }
}

# ==== SUMMARY ====
cat("\n")
cat("==============================================\n")
cat("Discovery Test Summary\n")
cat("==============================================\n")
cat(sprintf("Files tested:     %d of %d\n", files_run, total_files))
cat(sprintf("Total tests run:  %d\n", total_tests))
cat(sprintf("✓ Passed:         %d\n", total_passed))
cat(sprintf("✗ Failed:         %d\n", total_failed))
cat(sprintf("⊘ Skipped:        %d\n", total_skipped))
if (total_errors > 0) {
  cat(sprintf("⚠️  Errors:         %d\n", total_errors))
}
cat("==============================================\n\n")

# ==== INSIGHTS ====
cat("──────────────────────────────────────────────\n")
cat("What These Results Tell You\n")
cat("──────────────────────────────────────────────\n")

if (total_failed > 0) {
  cat("✓ GOOD! Failures show learning opportunities:\n")
  cat("  • Where tests and code disagree\n")
  cat("  • Missing error handling\n")
  cat("  • API documentation needs\n")
  cat("  • Edge cases to consider\n\n")
}

if (total_skipped > 0) {
  cat("✓ NORMAL! Skipped tests are:\n")
  cat("  • Templates showing patterns\n")
  cat("  • Tests needing mocking setup\n")
  cat("  • Tests marked for future work\n\n")
}

if (total_passed > 0) {
  cat("✓ GREAT! Passing tests confirm:\n")
  cat("  • Functions work as expected\n")
  cat("  • Tests match implementation\n")
  cat("  • Good test coverage exists\n\n")
}

# ==== NEXT STEPS ====
cat("──────────────────────────────────────────────\n")
cat("Next Steps\n")
cat("──────────────────────────────────────────────\n")
cat("1. Review failed tests - do they reveal bugs or wrong assumptions?\n")
cat("2. Pick ONE failed test to fix (code or test)\n")
cat("3. Run again to see improvement\n")
cat("4. Repeat gradually\n\n")

cat("To add skip() to a test:\n")
cat('  test_that("my test", {\n')
cat('    skip("Reason for skipping")\n')
cat('    # test code\n')
cat('  })\n\n')

# ==== NOTES ====
cat("──────────────────────────────────────────────\n")
cat("Remember:\n")
cat("──────────────────────────────────────────────\n")
cat("• Discovery tests are EXPLORATORY - failures are OK!\n")
cat("• Use these to learn about your codebase\n")
cat("• Critical tests: source('dev/run_critical_tests.R')\n")
cat("• All tests: source('dev/run_tests.R')\n\n")

# Return summary invisibly
invisible(list(
  passed = total_passed,
  failed = total_failed,
  skipped = total_skipped,
  total = total_tests
))
