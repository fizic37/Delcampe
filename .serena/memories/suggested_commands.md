# Development Commands and Workflow

## Primary Development Commands

### Running the Application
- **Development Mode**: `Rscript dev/run_dev.R` or source `dev/run_dev.R` in R console
- **Production Mode**: `Delcampe::run_app()` (after installation)

### Golem Development Workflow
- **Start Project**: Source `dev/01_start.R` (initial setup, already done)
- **Development**: Use `dev/02_dev.R` for ongoing development tasks
- **Deploy**: Use `dev/03_deploy.R` for deployment preparation

### R Package Development
- **Documentation**: `golem::document_and_reload()` (included in run_dev.R)
- **Check Package**: `devtools::check()`
- **Install Dependencies**: `golem::install_dev_deps()`
- **Build README**: `devtools::build_readme()`

### Testing Commands
- **Run Tests**: `devtools::test()` or `testthat::test_dir("tests/testthat")`
- **Coverage**: `covr::package_coverage()`

### Python Environment Management
- **Activate Environment**: Already configured via reticulate
- **Python Location**: `venv_proj/Scripts/python.exe` (Windows) or `venv_proj/bin/python` (Linux/Mac)

## Development Best Practices

### Module Development
- **Add Module**: `golem::add_module(name = "module_name", with_test = TRUE)`
- **Add Helper Functions**: `golem::add_fct("name", with_test = TRUE)`
- **Add Utils**: `golem::add_utils("name", with_test = TRUE)`

### File Management
- **External Resources**: Use `inst/app/www/` for static files
- **Add JavaScript**: `golem::add_js_file("script")`
- **Add CSS**: `golem::add_css_file("custom")`

### Git Commands (if initialized)
- Standard git workflow: `git add`, `git commit`, `git push`
- Repository URL: https://github.com/fizic37/Delcampe

## Important Notes
- Always use `dev/run_dev.R` for development instead of direct `run_app()`
- The app runs on a random port by default (configurable)
- Development mode is set via `options(golem.app.prod = FALSE)`
- Python integration happens automatically via reticulate configuration