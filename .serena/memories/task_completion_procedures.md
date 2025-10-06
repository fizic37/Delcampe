# Task Completion Procedures

## Mandatory Steps After Task Completion

### Code Quality Validation
1. **R Package Check**: Run `devtools::check()` to ensure package integrity
2. **Documentation**: Ensure all new functions have proper roxygen2 documentation
3. **Linting**: Follow Golem coding standards (no specific linter configured)
4. **File Size Limits**: Verify no R file exceeds 400 lines (CRITICAL)

### Testing Requirements
1. **Module Testing**: Every new module MUST have corresponding tests
2. **Test Framework**: Use testthat via Golem's testing framework
3. **Test Location**: Tests should be in `tests/testthat/` (if created)
4. **Run Tests**: Execute `devtools::test()` or `testthat::test_dir("tests/testthat")`
5. **Coverage**: Check `covr::package_coverage()` for test coverage

### Integration Testing
1. **R-Python Integration**: Verify reticulate connection works
2. **Module Integration**: Test module interactions work correctly
3. **Development Mode**: Test app functionality with `dev/run_dev.R`
4. **Error Scenarios**: Test error handling and user feedback

### Documentation Updates
1. **README**: Update `README.Rmd` if functionality changes
2. **Build README**: Run `devtools::build_readme()`
3. **Module Documentation**: Update `@description` in module headers
4. **Golem Documentation**: Utilize Golem's auto-generated documentation

### Before Committing (if applicable)
1. **Package Dependencies**: Run `attachment::att_amend_desc()` to update DESCRIPTION
2. **Documentation Build**: Ensure `golem::document_and_reload()` runs cleanly
3. **Final Check**: One last `devtools::check()` before commit

## Validation Levels (for complex tasks)

### Level 1: Syntax & Style
- R syntax validation via `devtools::check()`
- File size constraints verification
- Golem convention adherence

### Level 2: Unit Testing
- Individual module/function tests
- Test coverage validation
- Edge case testing

### Level 3: Integration Testing
- R-Python communication tests
- Module interaction validation
- Full application functionality test

### Level 4: Application Validation
- End-to-end user workflow testing
- Error handling validation
- Performance verification

## Failure Protocol
1. **Fix Issues**: Address any validation failures immediately
2. **Re-run Validation**: Repeat failed validation level
3. **Document Changes**: Update relevant documentation
4. **Iterative Testing**: Continue until all levels pass