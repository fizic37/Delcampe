# Product Requirements Prompt (PRP): Delcampe Postal Card Processor Analysis & Rebuild

## Goal
Analyze the existing Delcampe Postal Card Processor Golem project, discover optimal module architecture by examining current large modules, and rebuild with clean, maintainable structure while preserving all proven functionality.

## Why
- **Existing Project**: Golem project already created and configured, needs architectural analysis and improvement
- **Module Optimization**: Current modules may be oversized and need intelligent splitting based on actual functionality
- **Proven Patterns**: Reference implementation exists in `examples/` folder but may need restructuring for optimal Golem compliance
- **Production Ready**: Transform existing working system into maintainable, testable, production-grade application

## What
Comprehensive analysis and refactoring of existing Golem project with:
- **Smart Module Discovery**: Analyze existing code to determine optimal module splitting
- **Golem Compliance**: Restructure according to Golem best practices (LLM decides structure)
- **Preserved Functionality**: Maintain all working features from reference implementation
- **Enhanced Architecture**: Create clean, testable, single-responsibility modules

### Success Criteria
- [ ] Complete analysis of existing project structure and reference examples
- [ ] Intelligent module splitting with clear single responsibilities (max 400 lines each)
- [ ] All functionality from `examples/` preserved and enhanced
- [ ] Comprehensive test coverage for discovered modules
- [ ] Working R-Python integration using existing proven patterns
- [ ] Master user authentication constraints properly implemented
- [ ] Multi-AI provider support with fallback mechanisms
- [ ] Complete end-to-end postal card processing workflow

## All Needed Context

### Project Structure Analysis (CRITICAL - Analyze First)
- **directory**: `./` (project root)  
  **why**: Existing Golem project structure needs analysis  
  **action**: Examine current modules, identify oversized files, discover splitting opportunities

- **directory**: `examples/`  
  **why**: Reference implementation with proven patterns  
  **usage**: Extract working patterns but adapt structure according to Golem best practices  
  **note**: LLM may restructure this according to optimal Golem architecture

- **file**: `examples/modules/mod_postal_cards_face.R`  
  **why**: Existing face processing module (likely oversized)  
  **action**: Analyze functionality and split into focused single-responsibility modules

- **file**: `examples/modules/mod_postal_cards_verso.R`  
  **why**: Existing verso processing module (likely oversized)  
  **action**: Analyze functionality and split into focused single-responsibility modules

- **file**: `examples/R/auth_system.R`  
  **why**: Working authentication system with master user constraints  
  **critical**: Preserve exact master user logic (cannot delete each other)

- **file**: `examples/inst/python/extract_postcards.py`  
  **why**: Battle-tested Python grid detection and extraction  
  **critical**: DO NOT MODIFY - use exactly as implemented

### Test Resources (Use for Validation)
- **file**: `test_images/test_face`  
  **why**: Face side test image for validation and testing  
  **usage**: Use in all face processing tests and integration workflows

- **file**: `test_images/test_verso`  
  **why**: Verso side test image for validation and testing  
  **usage**: Use in all verso processing tests and integration workflows

### Framework Requirements
- **url**: https://thinkr-open.github.io/golem/  
  **section**: Module architecture and best practices  
  **why**: LLM must decide optimal structure following Golem recommendations

- **url**: https://thinkr-open.github.io/golem/articles/b_dev.html  
  **section**: Development workflow  
  **why**: Use proper Golem development patterns

### Known Critical Constraints

```r
# CRITICAL: R-Python Integration - DO NOT MODIFY existing patterns
# Use exactly as implemented in examples/inst/python/extract_postcards.py
reticulate::source_python("inst/python/extract_postcards.py")

# CRITICAL: Master User Authentication Constraint
# Master users CANNOT delete each other - preserve this logic exactly
if (user_role == "master" && target_user_role == "master" && 
    user_id != target_user_id) {
  stop("Master users cannot delete each other")
}

# CRITICAL: Smart Grid Detection Priority Logic
# Grid dimensions detection follows this priority order:
# 1. Database (if same image processed before)
# 2. Cross-sync (if corresponding face/verso processed)  
# 3. Python detection (only if neither exists)
# 4. User adjustments overwrite database values

get_grid_dimensions <- function(image_path, image_type) {
  # 1. Check database for this specific image
  stored_grid <- get_stored_grid(image_path)
  if (!is.null(stored_grid)) return(stored_grid)
  
  # 2. Check database for corresponding image (face<->verso sync)
  corresponding_type <- ifelse(image_type == "face", "verso", "face")
  corresponding_grid <- get_stored_grid_by_type(corresponding_type)
  if (!is.null(corresponding_grid)) return(corresponding_grid)
  
  # 3. Fall back to Python detection
  return(python_detect_grid(image_path))
}

# CRITICAL: File Size Limits
# Every R file must be under 400 lines - analyze and split accordingly
# Command to check: find R/ -name "*.R" -exec wc -l {} \;

# CRITICAL: Test Image Paths for Validation
face_test_image <- "test_images/test_face"
verso_test_image <- "test_images/test_verso"
```

## Implementation Blueprint

### Phase 1: Project Analysis & Module Discovery
```r
# 1.1 Analyze current project structure
# ACTION: Examine all files in R/ directory
list.files("R/", pattern = "*.R", full.names = TRUE)

# 1.2 Analyze reference implementation
# ACTION: Examine examples/ directory structure and identify patterns
# Discover what modules are actually needed based on functionality

# 1.3 Line count analysis of existing modules
# ACTION: Find oversized files that need splitting
system("find examples/ -name '*.R' -exec wc -l {} \\; | sort -nr")

# 1.4 Functionality mapping
# ACTION: Map each function/feature to optimal module structure
# Determine single-responsibility module boundaries

# Example analysis approach:
analyze_module_complexity <- function(module_path) {
  lines <- readLines(module_path)
  
  # Identify distinct functionalities
  ui_functions <- grep("UI|ui", lines, value = TRUE)
  server_functions <- grep("Server|server", lines, value = TRUE)
  reactive_elements <- grep("reactive|observe", lines, value = TRUE)
  
  # Determine splitting opportunities
  return(list(
    total_lines = length(lines),
    ui_complexity = length(ui_functions),
    server_complexity = length(server_functions),
    reactive_complexity = length(reactive_elements),
    split_recommended = length(lines) > 400
  ))
}
```

### Phase 2: Intelligent Module Creation
```r
# 2.1 Based on analysis, create discovered modules
# LLM DECIDES: What modules are needed based on actual functionality analysis

# Example discovery process (LLM executes this logic):
# IF face processing has >400 lines with distinct upload/grid/extract functions
#   THEN split into: mod_face_upload, mod_face_grid, mod_face_extract
# IF authentication has user management + login functions  
#   THEN split into: mod_authentication, mod_user_management
# IF AI processing has extraction + multiple providers
#   THEN split into: mod_ai_extraction, mod_ai_provider_manager

# 2.2 Create modules based on discovered architecture
# Use golem::add_module() ONLY for newly discovered module needs
# Example (actual modules determined by analysis):
# golem::add_module("discovered_module_name")

# 2.3 Move and refactor code from examples/ into new structure
# Preserve all working functionality while improving architecture
```

### Phase 3: Implementation & Integration
```r
# 3.1 Implement discovered modules with single responsibilities
# Each module under 400 lines with clear purpose

# 3.2 Preserve critical working patterns
# Copy exact R-Python integration from examples/inst/python/
file.copy("examples/inst/python/extract_postcards.py", 
          "inst/python/extract_postcards.py", 
          overwrite = FALSE)

# 3.3 Implement master user constraints exactly as in examples
# Reference: examples/R/auth_system.R for exact logic

# 3.4 Multi-AI provider integration
# Based on existing patterns but enhanced for multiple providers
```

### Phase 4: Testing & Validation Integration
```r
# 4.1 Create comprehensive tests for all discovered modules
# Use test images: test_images/test_face and test_images/test_verso

# 4.2 Integration testing with real test images
# Ensure complete workflow works end-to-end
```

## Validation Loop

### Level 1: Project Analysis Validation
```bash
# Verify project structure
ls -la R/
ls -la examples/

# Check current module sizes
find R/ -name "*.R" -exec wc -l {} \; | awk '{print $2 ": " $1 " lines"}' | sort

# Verify test images exist
ls -la test_images/
test -f test_images/test_face && echo "Face test image found"
test -f test_images/test_verso && echo "Verso test image found"

# Check examples structure
find examples/ -name "*.R" | head -10
```

### Level 2: Module Discovery Validation
```r
# Test module analysis approach
test_that("Module analysis discovers split opportunities", {
  # Analyze existing large modules from examples
  face_analysis <- analyze_module_complexity("examples/modules/mod_postal_cards_face.R")
  verso_analysis <- analyze_module_complexity("examples/modules/mod_postal_cards_verso.R")
  
  # Should identify oversized modules
  expect_true(face_analysis$total_lines > 0)
  expect_true(verso_analysis$total_lines > 0)
  
  # Should recommend splits if over 400 lines
  if (face_analysis$total_lines > 400) {
    expect_true(face_analysis$split_recommended)
  }
})

# Test reference pattern preservation
test_that("Critical patterns preserved from examples", {
  # Master user constraint should be preserved
  expect_true(file.exists("examples/R/auth_system.R"))
  
  # Python integration should be preserved
  expect_true(file.exists("examples/inst/python/extract_postcards.py"))
})
```

### Level 3: Functionality Preservation Testing
```r
# Test end-to-end workflow with grid synchronization
test_that("Complete postal card processing with grid sync", {
  # Clear test data
  clear_test_grid_data()
  
  # Step 1: Upload face image (should trigger Python detection)
  face_upload <- upload_test_image("test_images/test_face", type = "face")
  expect_true(face_upload$success)
  expect_true(face_upload$grid_source == "python_detection")
  
  # Step 2: User adjusts grid dimensions
  adjusted_grid <- adjust_grid_dimensions(
    image_path = "test_images/test_face",
    rows = 4, 
    cols = 3
  )
  expect_equal(adjusted_grid$rows, 4)
  expect_equal(adjusted_grid$cols, 3)
  
  # Step 3: Upload verso image (should use face grid dimensions)
  verso_upload <- upload_test_image("test_images/test_verso", type = "verso")
  expect_true(verso_upload$success)
  expect_true(verso_upload$grid_source == "cross_sync")
  expect_equal(verso_upload$grid$rows, 4)
  expect_equal(verso_upload$grid$cols, 3)
  
  # Step 4: Re-upload face image (should use database)
  face_reupload <- upload_test_image("test_images/test_face", type = "face")
  expect_true(face_reupload$grid_source == "database")
  expect_equal(face_reupload$grid$rows, 4)
  expect_equal(face_reupload$grid$cols, 3)
  
  # Step 5: Complete processing workflow
  workflow_result <- process_postal_card_workflow(
    face_image = "test_images/test_face",
    verso_image = "test_images/test_verso"
  )
  
  expect_true(workflow_result$success)
  expect_equal(workflow_result$face_grid$rows, 4)
  expect_equal(workflow_result$verso_grid$rows, 4)
  expect_true(length(workflow_result$processed_lots) > 0)
})

# Test grid synchronization logic
test_that("Grid detection priority logic works correctly", {
  # Setup: Clear any existing grid data
  clear_test_grid_data()
  
  # Test 1: No previous data - should use Python detection
  face_grid_1 <- get_grid_dimensions("test_images/test_face", "face")
  expect_true(!is.null(face_grid_1))
  expect_true(face_grid_1$source == "python_detection")
  
  # Save grid to database (simulate user processing)
  save_grid_dimensions("test_images/test_face", face_grid_1, "face")
  
  # Test 2: Database retrieval - should use stored dimensions
  face_grid_2 <- get_grid_dimensions("test_images/test_face", "face")
  expect_equal(face_grid_2$rows, face_grid_1$rows)
  expect_equal(face_grid_2$cols, face_grid_1$cols)
  expect_true(face_grid_2$source == "database")
  
  # Test 3: Cross-sync - verso should use face dimensions
  verso_grid <- get_grid_dimensions("test_images/test_verso", "verso")
  expect_equal(verso_grid$rows, face_grid_1$rows)
  expect_equal(verso_grid$cols, face_grid_1$cols)
  expect_true(verso_grid$source == "cross_sync")
  
  # Test 4: User adjustment overwrites
  adjusted_grid <- list(rows = 5, cols = 4, source = "user_adjustment")
  save_grid_dimensions("test_images/test_face", adjusted_grid, "face")
  
  face_grid_3 <- get_grid_dimensions("test_images/test_face", "face")
  expect_equal(face_grid_3$rows, 5)
  expect_equal(face_grid_3$cols, 4)
  expect_true(face_grid_3$source == "database")
})

# Test master user constraints
test_that("Master user deletion prevention", {
  # Create test master users
  master1 <- list(id = "master1", role = "master")
  master2 <- list(id = "master2", role = "master")
  
  # Test deletion prevention
  expect_error(
    delete_user_with_constraints(master1$id, master2$id),
    "Master users cannot delete each other"
  )
})

# Test AI integration with multiple providers
test_that("Multi-AI provider functionality", {
  test_image_data <- load_test_image("test_images/test_face")
  
  # Should support multiple providers
  claude_result <- extract_with_ai(test_image_data, provider = "claude")
  openai_result <- extract_with_ai(test_image_data, provider = "openai")
  
  # Both should return structured data
  expect_true(all(c("title", "description") %in% names(claude_result)))
  expect_true(all(c("title", "description") %in% names(openai_result)))
})
```

### Level 4: Architecture Validation
```r
# Validate discovered module structure
test_that("Module architecture follows single responsibility", {
  # Get all R files in project
  r_files <- list.files("R/", pattern = "*.R", full.names = TRUE)
  
  # Check line counts
  line_counts <- sapply(r_files, function(f) length(readLines(f)))
  
  # All files should be under 400 lines
  expect_true(all(line_counts <= 400), 
              info = paste("Oversized files:", 
                          paste(names(line_counts[line_counts > 400]), 
                                collapse = ", ")))
})

# Test Golem compliance
test_that("Golem structure compliance", {
  # Should pass Golem structure checks
  expect_silent(golem::check_golem_structure())
  
  # Should have proper DESCRIPTION file
  expect_true(file.exists("DESCRIPTION"))
  
  # Should have proper module structure
  module_files <- list.files("R/", pattern = "mod_.*\\.R")
  expect_true(length(module_files) > 0)
})

# R package structure validation
devtools::check()

# R code style checking  
lintr::lint_package()

# R code formatting
styler::style_pkg()

```

### Level 5: Integration & Performance Testing
```r
# End-to-end workflow test
test_that("Complete postal card processing pipeline", {
  # Start with test images
  workflow_result <- process_postal_card_workflow(
    face_image = "test_images/test_face",
    verso_image = "test_images/test_verso",
    ai_provider = "claude"
  )
  
  # Should complete successfully
  expect_true(workflow_result$success)
  expect_true(length(workflow_result$processed_lots) > 0)
  expect_true(length(workflow_result$ai_extractions) > 0)
  
  # Should have proper Delcampe export data
  expect_true(all(c("title", "description", "price", "images") %in% 
                  names(workflow_result$delcampe_export[[1]])))
})

# Performance validation
test_that("Memory efficient processing", {
  initial_memory <- pryr::mem_used()
  
  # Process test images
  result <- process_postal_card_workflow(
    face_image = "test_images/test_face",
    verso_image = "test_images/test_verso"
  )
  
  final_memory <- pryr::mem_used()
  memory_increase <- as.numeric(final_memory - initial_memory)
  
  # Should not consume excessive memory
  expect_lt(memory_increase, 100 * 1024^2)  # Less than 100MB increase
})
```

## Critical Analysis Questions for LLM

Before implementation, analyze and answer:

1. **Module Discovery**: What modules are actually needed based on functionality in `examples/`?
2. **Splitting Strategy**: Which files in `examples/` exceed 400 lines and how should they be split?
3. **Dependency Mapping**: What are the reactive dependencies between different functionalities?
4. **Integration Points**: Where does R-Python integration occur and how to preserve it?
5. **Grid Synchronization**: How is the smart grid detection logic implemented across face/verso modules?
6. **Database Schema**: What database tables are needed for grid dimension persistence and image tracking?
7. **User Workflow**: What is the complete user journey from upload to Delcampe export?
8. **Testing Strategy**: What are the critical test cases using `test_images/test_face` and `test_images/test_verso`?

## Environment & Development Commands

```bash
# Check current project status
ls -la
cat DESCRIPTION

# Analyze module complexity
find examples/ -name "*.R" -exec wc -l {} \; | sort -nr

# Test image validation
ls -la test_images/
file test_images/test_face
file test_images/test_verso

# Run discovered module tests
R -e "devtools::test()"

# Check Golem compliance
R -e "golem::check_golem_structure()"

# Start development server
R -e "golem::run_dev()"
```

## Success Metrics

- **Analysis Complete**: Full understanding of existing functionality and optimal module structure
- **Intelligent Splitting**: Large modules split into logical, single-responsibility components
- **Functionality Preserved**: All features from `examples/` working in new structure
- **Test Coverage**: >90% coverage using actual test images
- **Performance**: Complete workflow processes test images efficiently
- **Constraints Maintained**: R-Python integration and master user rules preserved
- **Golem Compliant**: Passes all Golem structure and best practice checks

**Remember**: Start with thorough analysis of existing code and examples, then intelligently discover optimal module architecture. Use test images throughout validation to ensure real-world functionality.