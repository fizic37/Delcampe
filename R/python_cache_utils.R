# Add this function to your utils_helpers.R or source it at app startup
# It will automatically clear Python cache when the app starts

#' Clear Python bytecode cache to ensure fresh module loading
#'
#' @param python_dir Directory containing Python files (default: "inst/python")
#' @param verbose Whether to print status messages (default: TRUE)
#' @return Logical indicating whether cache was found and cleared
#' @export
clear_python_cache <- function(python_dir = "inst/python", verbose = TRUE) {
  cache_dir <- file.path(python_dir, "__pycache__")
  
  if (dir.exists(cache_dir)) {
    if (verbose) {
      cat("🧹 Found Python cache at:", cache_dir, "\n")
    }
    
    # Try to remove cache
    removed <- tryCatch({
      unlink(cache_dir, recursive = TRUE)
      TRUE
    }, error = function(e) {
      if (verbose) {
        warning("Could not remove cache: ", e$message)
      }
      FALSE
    })
    
    if (removed && verbose) {
      cat("✅ Python cache cleared successfully\n")
      cat("⚠️  Please restart R session for changes to take full effect\n")
    }
    
    return(removed)
  } else {
    if (verbose) {
      cat("ℹ️  No Python cache found (this is good!)\n")
    }
    return(FALSE)
  }
}

#' Force reload of Python module
#'
#' @param module_name Name of the Python module (without .py extension)
#' @return Logical indicating success
#' @export
force_reload_python_module <- function(module_name = "extract_postcards") {
  tryCatch({
    reticulate::py_run_string("import sys")
    reload_code <- sprintf(
      "if '%s' in sys.modules: del sys.modules['%s']",
      module_name, module_name
    )
    reticulate::py_run_string(reload_code)
    TRUE
  }, error = function(e) {
    warning("Could not force reload module: ", e$message)
    FALSE
  })
}

#' Initialize Python with cache clearing
#'
#' @param python_file Path to Python file to source
#' @param clear_cache Whether to clear cache before loading (default: TRUE in interactive mode)
#' @param verbose Whether to print status messages (default: TRUE)
#' @return Logical indicating whether Python was successfully loaded
#' @export
init_python_clean <- function(python_file = "inst/python/extract_postcards.py",
                              clear_cache = interactive(),
                              verbose = TRUE) {
  
  # Clear cache if requested
  if (clear_cache) {
    python_dir <- dirname(python_file)
    clear_python_cache(python_dir, verbose = verbose)
    
    # Force reload module
    module_name <- tools::file_path_sans_ext(basename(python_file))
    force_reload_python_module(module_name)
  }
  
  # Source Python file
  success <- tryCatch({
    reticulate::source_python(python_file)
    if (verbose) {
      cat("✅ Python module loaded:", python_file, "\n")
    }
    TRUE
  }, error = function(e) {
    if (verbose) {
      cat("❌ Failed to load Python module:", e$message, "\n")
    }
    FALSE
  })
  
  return(success)
}

# Auto-clear cache when this file is sourced (only in interactive sessions)
if (interactive()) {
  clear_python_cache(verbose = FALSE)
}
