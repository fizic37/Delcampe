# Diagnosis script for UI issues after redesign
# Run this to check what's working and what's not

cat("\n")
cat("╔══════════════════════════════════════════════════════════════════╗\n")
cat("║  UI Redesign - Diagnosis Script                                 ║\n")
cat("╚══════════════════════════════════════════════════════════════════╝\n\n")

# Check 1: Package dependencies
cat("🔍 Checking Package Dependencies...\n\n")

required_packages <- c("shiny", "golem", "bslib", "shinyjs", "reticulate")
for (pkg in required_packages) {
  installed <- requireNamespace(pkg, quietly = TRUE)
  status <- if (installed) "✅" else "❌"
  cat(sprintf("  %s %s\n", status, pkg))
}

# Check 2: DESCRIPTION file
cat("\n🔍 Checking DESCRIPTION file...\n\n")
desc_file <- "DESCRIPTION"
if (file.exists(desc_file)) {
  desc_content <- readLines(desc_file)
  imports_line <- grep("^Imports:", desc_content)
  
  if (length(imports_line) > 0) {
    # Get all lines from Imports: until next section or end
    start <- imports_line[1]
    end <- start
    for (i in (start + 1):length(desc_content)) {
      if (grepl("^[A-Z]", desc_content[i]) && !grepl("^    ", desc_content[i])) {
        end <- i - 1
        break
      }
      end <- i
    }
    
    imports <- desc_content[start:end]
    cat("  Imports section:\n")
    cat(paste0("    ", imports, collapse = "\n"), "\n\n")
    
    has_shinyjs <- any(grepl("shinyjs", imports))
    has_bslib <- any(grepl("bslib", imports))
    has_reticulate <- any(grepl("reticulate", imports))
    
    cat("  Dependency check:\n")
    cat(sprintf("    %s shinyjs declared\n", if (has_shinyjs) "✅" else "❌"))
    cat(sprintf("    %s bslib declared\n", if (has_bslib) "✅" else "❌"))
    cat(sprintf("    %s reticulate declared\n", if (has_reticulate) "✅" else "❌"))
  } else {
    cat("  ❌ No Imports section found!\n")
  }
} else {
  cat("  ❌ DESCRIPTION file not found!\n")
}

# Check 3: UI files
cat("\n🔍 Checking UI Files...\n\n")

ui_files <- c(
  "R/mod_postal_card_processor.R",
  "inst/app/www/draggable_lines.js",
  "inst/app/www/styles.css"
)

for (file in ui_files) {
  exists <- file.exists(file)
  status <- if (exists) "✅" else "❌"
  size <- if (exists) paste0(" (", file.size(file), " bytes)") else ""
  cat(sprintf("  %s %s%s\n", status, file, size))
}

# Check 4: CSS classes used
cat("\n🔍 Checking New CSS Classes...\n\n")

if (file.exists("inst/app/www/styles.css")) {
  css_content <- readLines("inst/app/www/styles.css", warn = FALSE)
  
  required_classes <- c(
    "upload-controls-wrapper",
    "styled-file-input-wrapper",
    "file-input-inline",
    "btn-extract"
  )
  
  for (class_name in required_classes) {
    found <- any(grepl(paste0("\\.", class_name), css_content))
    status <- if (found) "✅" else "❌"
    cat(sprintf("  %s .%s\n", status, class_name))
  }
} else {
  cat("  ❌ styles.css not found\n")
}

# Check 5: shinyjs usage in R code
cat("\n🔍 Checking shinyjs Usage...\n\n")

if (file.exists("R/mod_postal_card_processor.R")) {
  r_content <- readLines("R/mod_postal_card_processor.R", warn = FALSE)
  
  shinyjs_calls <- c(
    "shinyjs::show",
    "shinyjs::hide",
    "shinyjs::useShinyjs"
  )
  
  for (call in shinyjs_calls) {
    found <- any(grepl(call, r_content, fixed = TRUE))
    count <- sum(grepl(call, r_content, fixed = TRUE))
    status <- if (found) "✅" else "❌"
    cat(sprintf("  %s %s (used %d times)\n", status, call, count))
  }
  
  # Check if shinyjs::useShinyjs is in app_ui.R
  if (file.exists("R/app_ui.R")) {
    app_ui_content <- readLines("R/app_ui.R", warn = FALSE)
    has_use_shinyjs <- any(grepl("shinyjs::useShinyjs", app_ui_content, fixed = TRUE))
    cat(sprintf("\n  %s shinyjs::useShinyjs() in app_ui.R\n", if (has_use_shinyjs) "✅" else "❌"))
  }
} else {
  cat("  ❌ mod_postal_card_processor.R not found\n")
}

# Summary
cat("\n")
cat("╔══════════════════════════════════════════════════════════════════╗\n")
cat("║  Summary & Next Steps                                            ║\n")
cat("╚══════════════════════════════════════════════════════════════════╝\n\n")

cat("If all checks pass:\n")
cat("  1. Restart R: .rs.restartR()\n")
cat("  2. Reinstall package: devtools::install()\n")
cat("  3. Run app: Delcampe::run_app()\n")
cat("  4. Upload test image\n")
cat("  5. Check if grid controls show with correct values\n\n")

cat("If some checks fail:\n")
cat("  - ❌ Missing packages: install.packages(c('shinyjs', 'bslib'))\n")
cat("  - ❌ Missing dependencies in DESCRIPTION: Already fixed, run devtools::document()\n")
cat("  - ❌ Missing CSS classes: File was modified correctly\n")
cat("  - ❌ Missing JavaScript: Check inst/app/www/draggable_lines.js\n\n")

cat("Common issues:\n")
cat("  1. Grid shows 1x1 instead of 3x3:\n")
cat("     → Python detection issue, not UI issue\n")
cat("     → Check: exists('detect_grid_layout', envir = .GlobalEnv)\n")
cat("     → If FALSE, run: source('R/python_cache_utils.R'); init_python_clean()\n\n")

cat("  2. Extract button doesn't work:\n")
cat("     → Check R console for Python errors\n")
cat("     → Check: exists('crop_image_with_boundaries', envir = .GlobalEnv)\n\n")

cat("  3. Controls don't appear:\n")
cat("     → shinyjs not loaded\n")
cat("     → Restart R and reinstall package\n\n")

cat("═══════════════════════════════════════════════════════════════════\n\n")
