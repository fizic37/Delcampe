# Code Style and Conventions

## Golem Framework Conventions

### Naming Conventions
- **Modules**: Use snake_case, prefix with `mod_` (e.g., `mod_upload_ui`, `mod_upload_server`)
- **Functions**: Use snake_case for regular functions
- **Helper Functions**: Prefix with `fct_` (e.g., `fct_helpers.R`)
- **Utilities**: Prefix with `utils_` (e.g., `utils_helpers.R`)
- **Package Name**: `Delcampe` (PascalCase for package, lowercase for files)

### File Structure
- **UI Modules**: `mod_*_ui()` functions for module UI
- **Server Modules**: `mod_*_server()` functions for module logic
- **App Files**: `app_ui.R`, `app_server.R`, `app_config.R`, `run_app.R`
- **Maximum File Length**: Never exceed 400 lines per R file (CRITICAL CONSTRAINT)

### Documentation Standards
- **Golem Auto-Generated Docs**: Use Golem's documentation templates
- **roxygen2**: Use `#'` for function documentation
- **Required Fields**:
  - `@description`: Clear explanation of module/function purpose
  - `@param`: Document parameters beyond Golem defaults
  - `@examples`: Include for complex patterns
  - `@export`: For functions that should be exported

### R Code Style
- **Assignment**: Use `<-` for assignment (R standard)
- **Function Arguments**: Follow Golem patterns for module parameters
- **Reactive Programming**: Proper Shiny reactive patterns
- **Error Handling**: Implement comprehensive error handling with user feedback
- **Comments**: Minimal inline comments, rely on good function/variable names

## Python Code Style (inst/python/)
- **Functions**: Use snake_case
- **Constants**: Use UPPER_CASE
- **Documentation**: Use docstrings for function documentation
- **Debug Output**: Use `print()` statements prefixed with "PYTHON DEBUG:" for debugging
- **Error Handling**: Return structured error information in dictionaries

## Integration Patterns
- **R-Python Communication**: Use established reticulate patterns
- **Data Exchange**: Pass structured data (lists, dictionaries) between R and Python
- **File Paths**: Use absolute paths for cross-language file operations
- **Error Propagation**: Python errors should be handled gracefully in R

## Security Practices
- **API Keys**: Store in environment variables only
- **File Uploads**: Validate file types and sizes
- **Path Handling**: Sanitize file paths to prevent directory traversal