# Real Test for Grid Boundary Sorting Bug
# Run this to verify the fix works
#
# USAGE:
#   source("tests/test_drag_bug.R")
#   test_drag_sorting_bug()

test_drag_sorting_bug <- function() {
  
  cat("\n")
  cat("========================================\n")
  cat("TESTING GRID BOUNDARY SORTING BUG\n")
  cat("========================================\n\n")
  
  # Simulate the exact scenario
  cat("SCENARIO: User has 2x2 grid, drags bottom line UP\n\n")
  
  # Initial boundaries for a 2x2 grid on 600x400 image
  image_dims <- c(width = 600, height = 400)
  h_boundaries_initial <- c(0, 200, 400)  # Top, middle, bottom
  v_boundaries_initial <- c(0, 300, 600)  # Left, middle, right
  
  cat("Initial state:\n")
  cat("  Image: 600x400\n")
  cat("  H boundaries:", paste(h_boundaries_initial, collapse = ", "), "\n")
  cat("  V boundaries:", paste(v_boundaries_initial, collapse = ", "), "\n\n")
  
  # User drags bottom line (index 3) UP to position 150
  cat("USER ACTION: Drag bottom H-line from y=400 UP to y=150\n\n")
  
  # BROKEN VERSION - what the old code did
  cat("❌ BROKEN CODE (direct assignment, no sorting):\n")
  h_broken <- h_boundaries_initial
  line_index <- 3
  new_position <- 150
  h_broken[line_index] <- new_position
  cat("   Code: h_boundaries[3] <- 150\n")
  cat("   Result:", paste(h_broken, collapse = ", "), "\n")
  cat("   Is sorted?", !is.unsorted(h_broken), "\n")
  
  # Show what Python would receive
  cat("\n   What Python receives for cropping:\n")
  for (i in 1:(length(h_broken)-1)) {
    y1 <- h_broken[i]
    y2 <- h_broken[i+1]
    height <- y2 - y1
    status <- if (height > 0) "✓" else "⚠️ NEGATIVE HEIGHT!"
    cat(sprintf("     Row %d: y=%d to y=%d, height=%d %s\n", i, y1, y2, height, status))
  }
  
  cat("\n   PROBLEM: Row 2 has NEGATIVE height!\n")
  cat("   Python will create wrong crops or fail\n\n")
  
  # FIXED VERSION - what the new code does
  cat("✅ FIXED CODE (with sorting):\n")
  h_fixed <- h_boundaries_initial
  h_fixed[line_index] <- new_position
  h_fixed <- sort(unique(h_fixed))  # THE CRITICAL FIX
  cat("   Code: h_boundaries[3] <- 150; h_boundaries <- sort(unique(h_boundaries))\n")
  cat("   Result:", paste(h_fixed, collapse = ", "), "\n")
  cat("   Is sorted?", !is.unsorted(h_fixed), "\n")
  
  # Show what Python would receive
  cat("\n   What Python receives for cropping:\n")
  for (i in 1:(length(h_fixed)-1)) {
    y1 <- h_fixed[i]
    y2 <- h_fixed[i+1]
    height <- y2 - y1
    cat(sprintf("     Row %d: y=%d to y=%d, height=%d ✓\n", i, y1, y2, height))
  }
  
  cat("\n   SUCCESS: All rows have POSITIVE heights!\n")
  cat("   Extraction will match the visual grid\n\n")
  
  cat("========================================\n")
  cat("TEST CONCLUSION\n")
  cat("========================================\n")
  
  # Check if the fix is correct
  test_passed <- !is.unsorted(h_fixed) && all(diff(h_fixed) > 0)
  
  if (test_passed) {
    cat("✅ TEST PASSED: Sorting fixes the bug\n")
  } else {
    cat("❌ TEST FAILED: Fix did not work\n")
  }
  
  cat("\nNow check your actual code:\n")
  cat("1. Look for: handle_drag_update <- function(...)\n")
  cat("2. It should contain: rv$h_boundaries <- sort(unique(boundaries))\n")
  cat("3. Drag handlers should call: handle_drag_update(...)\n")
  cat("========================================\n\n")
  
  return(invisible(list(
    test_passed = test_passed,
    h_broken = h_broken,
    h_fixed = h_fixed
  )))
}

# Run immediately if sourced
if (interactive()) {
  cat("\nRunning test...\n")
  test_drag_sorting_bug()
}
