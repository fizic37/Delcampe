# Getting Started Guide

Welcome to the Delcampe Postal Card Processor project! This guide will help you set up your development environment and understand the codebase.

## Prerequisites

### Required Software
- **R** (version 4.0 or higher)
  - Download: https://cran.r-project.org/
- **RStudio** (recommended)
  - Download: https://posit.co/download/rstudio-desktop/
- **Python** 3.12.9
  - Virtual environment is pre-configured in `venv_proj/`
- **Git** for version control

### Required R Packages
```r
# Install Golem and development tools
install.packages("golem")
install.packages("devtools")
install.packages("testthat")

# The project will install other dependencies via DESCRIPTION file
```

## Project Setup

### 1. Clone the Repository
```bash
git clone <repository-url>
cd Delcampe
```

### 2. Open in RStudio
- Open `Delcampe.Rproj` in RStudio
- This will set the correct working directory and R environment

### 3. Install Dependencies
```r
# In R console
devtools::install_deps()
```

### 4. Verify Python Environment
```r
# Check Python setup
reticulate::py_config()

# Should show Python 3.12.9 from venv_proj/
```

### 5. Run the Application
```r
# Development mode
source("dev/run_dev.R")

# Or load and run
golem::run_dev()
```

## Project Structure Overview

```
Delcampe/
├── R/                    # R source code
│   ├── app_*.R          # Main app files
│   ├── mod_*.R          # Shiny modules
│   ├── fct_*.R          # Business logic functions
│   └── utils_*.R        # Utility functions
│
├── inst/
│   ├── app/www/         # Static assets (JS, CSS)
│   └── python/          # Python scripts
│
├── tests/
│   ├── testthat/        # Automated tests
│   └── manual/          # Manual verification scripts
│
├── dev/                 # Development scripts
│   ├── 01_start.R      # Initial setup
│   ├── 02_dev.R        # Development workflow
│   └── run_dev.R       # Run dev version
│
├── PRPs/                # Product Requirement Prompts
├── .serena/             # AI assistant context
│   └── memories/        # Technical documentation
│
└── docs/                # Human documentation (you are here!)
```

## Understanding the Codebase

### Key Concepts

#### 1. Golem Framework
This project uses Golem, a framework for production-ready Shiny apps:
- Modules in `R/mod_*.R`
- Functions in `R/fct_*.R`
- Utilities in `R/utils_*.R`
- Configuration in `inst/golem-config.yml`

📖 **Learn more:** https://thinkr-open.github.io/golem/

#### 2. Shiny Modules
Each major feature is a self-contained module:
```r
# UI function
mod_feature_ui <- function(id) {
  ns <- NS(id)
  # UI elements
}

# Server function
mod_feature_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    # Server logic
  })
}
```

#### 3. R-Python Integration
Python functions are called via reticulate:
```r
# Python function is loaded at startup
detect_grid_layout(image_path, rows, cols)

# The actual Python code is in inst/python/extract_postcards.py
```

⚠️ **Important:** Never modify the reticulate setup!

### Essential Files to Read

#### Start Here
1. **`CLAUDE.md`** - Core principles and constraints
2. **`.serena/memories/INDEX.md`** - Technical knowledge base
3. **`R/app_ui.R`** - Main UI structure
4. **`R/app_server.R`** - Server orchestration

#### Core Modules
1. **`R/mod_postal_card_processor.R`** - Main processing module
2. **`R/mod_settings.R`** - Settings interface
3. **`inst/python/extract_postcards.py`** - Python image processing

#### Recent Changes
Check `.serena/memories/` for recent implementation notes:
- Latest session summaries
- Bug fixes
- Feature implementations

## Development Workflow

### Daily Workflow

#### 1. Start Development Server
```r
# In R console
source("dev/run_dev.R")
```

#### 2. Make Changes
- Edit files in `R/`
- Reload: Ctrl+Shift+L (or `devtools::load_all()`)
- Test in browser

#### 3. Run Tests
```r
# All tests
devtools::test()

# Specific test file
testthat::test_file("tests/testthat/test-mod_postal_card_processor.R")
```

#### 4. Check Code Quality
```r
# Check package
devtools::check()

# Should have 0 errors, 0 warnings
```

### Creating a New Feature

#### Using PRP Framework
1. **Create a PRP** (Product Requirement Prompt)
   - Copy template from `PRPs/templates/prp_task.md`
   - Fill in feature details, context, and validation

2. **Implement with AI Assistant**
   - Load PRP context
   - Work through tasks iteratively
   - Validate after each step

3. **Document in Serena Memories**
   - Create memory file in `.serena/memories/`
   - Update INDEX.md
   - Archive session details if needed

📖 **See:** `/docs/guides/development-workflow.md` for detailed steps

### Adding a New Module

#### 1. Create Module Files
```r
# In R console
golem::add_module("feature_name")

# This creates:
# - R/mod_feature_name.R
# - tests/testthat/test-mod_feature_name.R
```

#### 2. Implement Module
```r
# Edit R/mod_feature_name.R
# Implement UI and server functions
```

#### 3. Add to App
```r
# In R/app_ui.R
mod_feature_name_ui("feature_name_1")

# In R/app_server.R
mod_feature_name_server("feature_name_1")
```

#### 4. Write Tests
```r
# Edit tests/testthat/test-mod_feature_name.R
test_that("feature works", {
  # Test code
})
```

## Common Tasks

### Running Tests
```r
# All tests
devtools::test()

# Watch mode (re-runs on file changes)
testthat::test_local(stop_on_failure = FALSE)

# Specific file
testthat::test_file("tests/testthat/test-specific.R")
```

### Debugging
```r
# Insert breakpoint
browser()

# Or use RStudio's visual breakpoints
# Click left of line number in editor
```

### Checking Code Quality
```r
# Full package check
devtools::check()

# Quick load test
devtools::load_all()

# Document functions
devtools::document()
```

### Working with Python
```r
# Verify Python config
reticulate::py_config()

# Test Python function directly
reticulate::source_python("inst/python/extract_postcards.py")
detect_grid_layout(test_image, 2, 3)
```

## Troubleshooting

### Python Environment Issues
```r
# Check current Python
reticulate::py_config()

# If wrong version, check venv_proj/ exists
# Re-run: reticulate::use_virtualenv("venv_proj", required = TRUE)
```

### Module Not Loading
```r
# Reload all code
devtools::load_all()

# If still issues, restart R session
# Session > Restart R
```

### Tests Failing
```r
# Run with verbose output
testthat::test_file("tests/testthat/test-file.R", reporter = "progress")

# Check for namespace issues
devtools::document()
devtools::load_all()
```

### JavaScript Not Working
1. Check browser console (F12)
2. Verify file paths in `inst/app/www/`
3. Clear browser cache
4. Check module namespacing

## Getting Help

### Documentation
- **Architecture:** `/docs/architecture/overview.md`
- **AI Context:** `.serena/memories/INDEX.md`
- **Code Principles:** `CLAUDE.md`
- **Recent Work:** `.serena/memories/<recent_files>`

### External Resources
- [Golem Book](https://thinkr-open.github.io/golem/)
- [Shiny Documentation](https://shiny.rstudio.com/)
- [reticulate Guide](https://rstudio.github.io/reticulate/)

### Community
- Ask team members about architectural decisions
- Check `.serena/memories/` for past solutions
- Review ADRs in `/docs/decisions/` for design rationale

## Next Steps

1. **✅ Complete this setup guide**
2. **📖 Read:** `/docs/architecture/overview.md`
3. **🔍 Explore:** Browse `.serena/memories/INDEX.md`
4. **🧪 Try:** Run the app and upload a test image
5. **📝 Practice:** Make a small change and run tests
6. **🚀 Build:** Pick a feature from backlog and create a PRP

## Welcome!

You're now ready to contribute to the Delcampe project. Start with small changes, run tests frequently, and don't hesitate to ask questions.

Happy coding! 🎉

---

**Last Updated:** 2025-10-11  
**Maintained By:** Development Team  
**Related:** See `development-workflow.md` for detailed workflow steps
