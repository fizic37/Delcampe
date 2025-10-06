# Tests for mod_postal_card_processor module
# Specifically: Coordinate mapping for draggable lines

test_that("Coordinate conversion math is accurate", {
  # Test case: Image 1915 x 3507 displayed in 800 x 400 wrapper
  orig_width <- 1915
  orig_height <- 3507
  wrapper_width <- 800
  wrapper_height <- 400
  
  # Calculate rendered dimensions (object-fit: contain)
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
  
  # Test forward conversion: Original -> Screen
  test_boundary <- orig_height / 2  # 1753.5 px (50%)
  percent_of_original <- test_boundary / orig_height
  pos_in_rendered <- percent_of_original * rendered_height
  final_wrapper_pos <- offset_top + pos_in_rendered
  
  expect_equal(percent_of_original, 0.5)
  expect_equal(pos_in_rendered, 200)
  
  # Test reverse conversion: Screen -> Original
  pos_in_rendered_back <- final_wrapper_pos - offset_top
  percent_of_rendered <- pos_in_rendered_back / rendered_height
  original_coord_back <- percent_of_rendered * orig_height
  
  # Verify round-trip accuracy (should be within 0.1 pixels)
  error <- abs(original_coord_back - test_boundary)
  expect_lt(error, 0.1)
})

test_that("Rendered image bounds calculation is correct", {
  # Wide image in tall wrapper
  expect_equal({
    img_aspect <- 2.0
    wrapper_aspect <- 0.5
    result <- if (img_aspect > wrapper_aspect) "width_limited" else "height_limited"
    result
  }, "width_limited")
  
  # Tall image in wide wrapper (your case)
  expect_equal({
    img_aspect <- 1915 / 3507  # ~0.546
    wrapper_aspect <- 800 / 400  # 2.0
    result <- if (img_aspect > wrapper_aspect) "width_limited" else "height_limited"
    result
  }, "height_limited")
})

test_that("Offset calculations are correct", {
  # Your specific case
  orig_width <- 1915
  orig_height <- 3507
  wrapper_width <- 800
  wrapper_height <- 400
  
  img_aspect <- orig_width / orig_height
  wrapper_aspect <- wrapper_width / wrapper_height
  
  rendered_height <- wrapper_height
  rendered_width <- rendered_height * img_aspect
  offset_top <- 0
  offset_left <- (wrapper_width - rendered_width) / 2
  
  expect_equal(rendered_height, 400)
  expect_equal(round(rendered_width, 2), 218.49)
  expect_equal(offset_top, 0)
  expect_equal(round(offset_left, 2), 290.75)
})

test_that("Scale factor conversion matches JavaScript", {
  # This tests the R side conversion that receives data from JavaScript
  orig_height <- 3507
  rendered_height <- 400
  
  # JavaScript sends position in rendered image
  pos_in_rendered <- 225.5
  
  # R converts to original coordinates
  scale_factor <- orig_height / rendered_height
  orig_y <- round(pos_in_rendered * scale_factor)
  
  expect_equal(round(scale_factor, 4), 8.7675)
  expect_equal(orig_y, 1977)
  
  # Verify reverse
  pos_back <- orig_y / scale_factor
  expect_equal(round(pos_back, 1), 225.5)
})

test_that("Boundary arrays maintain correct order", {
  # Test that boundaries stay sorted and within image dimensions
  orig_height <- 3507
  
  h_boundaries <- c(0, 1753, 3507)
  
  expect_true(all(diff(h_boundaries) > 0))  # Ascending order
  expect_equal(min(h_boundaries), 0)        # Starts at 0
  expect_equal(max(h_boundaries), orig_height)  # Ends at max
  expect_true(all(h_boundaries >= 0))       # All non-negative
  expect_true(all(h_boundaries <= orig_height))  # All within bounds
})

test_that("Grid dimensions derived correctly from boundaries", {
  h_boundaries <- c(0, 1000, 2000, 3507)
  v_boundaries <- c(0, 638, 1277, 1915)
  
  num_rows <- length(h_boundaries) - 1
  num_cols <- length(v_boundaries) - 1
  
  expect_equal(num_rows, 3)
  expect_equal(num_cols, 3)
  expect_equal(num_rows * num_cols, 9)  # 3x3 grid = 9 cells
})
