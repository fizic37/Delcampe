# Delcampe Postal Card Processor - Claude Assistant

## Instructions for AI Assistants

**CRITICAL:**
- **Always use Serena** for semantic code retrieval and editing tools
  - Use `serena:find_symbol` to locate code entities
  - Use `serena:read_file` for reading files
  - Use `serena:replace_symbol_body` and other editing tools for code changes
  - Use `serena:read_memory` to access project context from `.serena/memories/`

## Core Principles

### Design Philosophy
- **Simplicity First**: Choose straightforward solutions over complex ones whenever possible
- **YAGNI Principle**: Avoid building functionality on speculation - implement features only when needed
- **Single Responsibility**: Each module, function, and reactive element should have one clear purpose
- **Fail Fast**: Check for potential errors early and provide immediate user feedback
- **Open/Closed Principle**: Modules should be open for extension but closed for modification

### Architecture Philosophy
- **Golem Framework**: ALWAYS follow Golem guidelines (https://thinkr-open.github.io/golem/)
- **Modular Design**: Each module has a single, clear responsibility
- **Reactive Programming**: Use proper Shiny reactive patterns for data flow
- **Separation of Concerns**: Clear separation between UI and server logic

### Critical Constraints

#### R-Python Communication
- **DO NOT MODIFY** the existing R-Python integration setup
- Current reticulate configuration is stable and battle-tested
- Use established patterns for Python function calls and data exchange
- Only extend, never replace, the working Python integration

#### File Management and Backups
- **CRITICAL**: Never save backup files inside the `R/` directory - they will be loaded into the R environment
- **ALWAYS** store backups in: `C:\Users\mariu\Documents\R_Projects\Delcampe_BACKUP\`
- **Rule**: The `R/` folder should contain ONLY active, production module files
- Before modifying any file, create a timestamped backup in the BACKUP folder outside the project
- Backup naming convention: `filename.R.backup` or `filename_BACKUP_YYYYMMDD.R`

#### Authentication Architecture
- **Master User System**: Two master users with protected status
- Master users can manage their own credentials and created users
- **ABSOLUTE RULE**: Master users CANNOT delete each other
- Authentication logic must preserve master user privileges

#### AI Integration Strategy
- Support multiple AI providers (Claude, GPT-4o)
- Implement provider fallback mechanisms
- Allow user/admin selection of preferred models
- Maintain consistent extraction interface regardless of provider

### Development Standards

#### Shiny API Critical Rules
- **CRITICAL - showNotification() ONLY accepts these type values:**
  - `type = "message"` (default, blue/info style)
  - `type = "warning"` (yellow style)
  - `type = "error"` (red style)
  - **NEVER use `type = "default"`** - this will cause an error!
  - **NEVER use `type = "success"`** - this will cause an error!
  - **DO NOT confuse with JavaScript notification libraries** (Bootstrap, Toastr, etc.) which have different type values
  - This is R Shiny's `showNotification()`, NOT a JavaScript function
  - When in doubt, omit the `type` parameter entirely (defaults to "message")

#### Library Usage Hierarchy
- **First Priority**: Use base Shiny functions when functionality is available
- **Second Priority**: Use bslib components for enhanced UI/styling needs
- **Third Priority**: Use shinyjs for DOM manipulation not available in base Shiny
- **Fourth Priority**: Custom JavaScript code for complex interactions
- **CRITICAL MODULE NAMESPACE RULE**: In Shiny modules, ALWAYS prefer native Shiny/bslib components over custom JavaScript
  - Custom jQuery/JavaScript onclick handlers FAIL in modules due to namespace issues
  - shinyjs functions don't reliably handle module namespaces
  - bslib components (accordion, card, etc.) handle namespacing automatically
  - **Question to ask first**: "Does bslib have a built-in component for this?"

#### JavaScript Integration Constraints
- **Examine All Files**: Include analysis of any JavaScript files in examples/ directory
- **Preserve JS Patterns**: JavaScript integrations must be preserved exactly as implemented
- **CRITICAL MODULE NAMESPACE RULE**: In Shiny modules, ALWAYS prefer native Shiny/bslib components over custom JavaScript
  - Custom jQuery/JavaScript onclick handlers FAIL in modules due to namespace issues
  - shinyjs functions don't reliably handle module namespaces
  - bslib components (accordion, card, etc.) handle namespacing automatically
  - **Question to ask first**: "Does bslib have a built-in component for this?"
- **ULTRA-THINK**: When considering custom JavaScript integration, conduct thorough analysis:
  - What existing JavaScript files are in examples/ and how do they integrate with Shiny?
  - Can the same functionality be achieved with base Shiny or bslib components?
  - How will JavaScript interact with Shiny module namespaces?
  - What are the implications for testing and maintenance?
- **Namespace Handling**: When integrating shinyjs or JavaScript with Shiny modules, ensure namespace compatibility
- **Document Dependencies**: Any JavaScript code must be documented and integrated properly

#### Code Quality Standards
- Follow Golem naming conventions and project structure
- Implement comprehensive error handling with user feedback
- Use meaningful variable names and consistent coding style
- **IMPORTANT**: Never create a single R file longer than 400 lines of code
- **Proactively** suggest module splitting when approaching size limits

#### Documentation Standards
- **Golem Generated Docs**: Golem automatically creates module documentation templates - use them properly
- Each module should have a clear title and description in its generated header
- Update the `@description` parameter in module files to explain the module's specific purpose
- Add `@param` documentation for module parameters beyond Golem defaults
- Include `@examples` section in module documentation when patterns are complex
- Document reactive dependencies and data flow within modules
- **Do NOT** duplicate Golem's auto-generated documentation structure

#### Testing Requirements

##### Core Testing Mandate
- **MANDATORY**: All new features and modules MUST include tests
- **MANDATORY**: Run critical tests before EVERY commit - all must pass
- Tests are NOT optional - they are a deliverable requirement for feature completion
- Use the established testing infrastructure in `tests/testthat/`

##### Testing Infrastructure (Two-Suite Strategy)

**Critical Tests (Must Always Pass)**
- Run before every commit: `source("dev/run_critical_tests.R")`
- Expected result: 100% pass rate (currently ~170 tests)
- Execution time: 10-20 seconds
- Files: `test-ebay_helpers.R`, `test-utils_helpers.R`, `test-mod_delcampe_export.R`, `test-mod_tracking_viewer.R`
- Purpose: Verify core business logic and prevent regressions
- **Blocking**: Cannot commit if critical tests fail

**Discovery Tests (Learning & Exploration)**
- Run during development: `source("dev/run_discovery_tests.R")`
- Expected result: Failures reveal insights (currently ~100 tests)
- Execution time: 20-40 seconds
- Files: `test-ai_api_helpers.R`, `test-tracking_database.R`, module templates
- Purpose: Explore edge cases, document behavior, guide improvements
- **Non-blocking**: Failures are learning opportunities

##### Daily Testing Workflow

```r
# 1. Morning check (optional but recommended)
source("dev/run_critical_tests.R")

# 2. During development
# - Write code
# - Write/update tests
# - Run critical tests frequently

# 3. Before committing (MANDATORY)
source("dev/run_critical_tests.R")
# ALL tests must pass before commit

# 4. When exploring/refactoring (as needed)
source("dev/run_discovery_tests.R")
```

##### Test Development Standards
- Use Golem's testthat framework (3rd edition)
- Leverage helper functions: `helper-setup.R`, `helper-mocks.R`, `helper-fixtures.R`
- Use `with_test_db()` for database testing (automatic cleanup)
- Use `with_mocked_ai()` for API testing (no real API calls)
- Test UI components with `shiny::testServer()` for reactive logic
- Include error scenarios and edge cases
- Follow patterns in existing test files

##### Test File Organization
- **Critical tests**: Core business logic that must always work
  - `test-ebay_helpers.R` - eBay functionality
  - `test-utils_helpers.R` - Utility functions
  - `test-mod_delcampe_export.R` - Delcampe export module
  - `test-mod_tracking_viewer.R` - Tracking viewer module
- **Discovery tests**: Exploratory, edge cases, learning
  - `test-ai_api_helpers.R` - AI integration
  - `test-tracking_database.R` - Database functions
  - `test-mod_login.R`, `test-mod_settings_llm.R` - Module templates
- **New tests**: Start in discovery, migrate to critical when stable

##### New Feature Checklist
When implementing a new feature, you MUST:
1. Write tests alongside code (not after)
2. Use helper functions for test setup/teardown
3. Test both success and error paths
4. Run critical tests before committing
5. Add new stable tests to critical suite (`dev/run_critical_tests.R`)
6. Document test patterns if introducing new approaches

##### Testing Documentation
- **Quick reference**: `dev/TESTING_CHEATSHEET.md`
- **Strategy explanation**: `dev/TESTING_STRATEGY.md`
- **Complete guide**: `dev/TESTING_GUIDE.md`
- **Getting started**: `dev/TESTING_QUICKSTART.md`
- **Serena memory**: `.serena/memories/testing_infrastructure_complete_20251023.md`

##### CI/CD Integration
- GitHub Actions workflow: `.github/workflows/test.yaml`
- Runs on: push to main/master/develop, pull requests
- Must pass before merge

**Remember**: Testing is not a burden - it's a safety net that enables confident refactoring and prevents regressions. The two-suite strategy makes testing fast for daily work (critical) while preserving exploration value (discovery).

### Module Design Principles
- **ULTRA-THINK**: Before creating or splitting modules, conduct deep analysis of functional similarity
  - Do proposed modules perform identical operations with different initialization parameters?
  - Can differences be handled through configuration rather than separate modules?
  - Would a generic parameterized module be more appropriate than multiple specific modules?
- **Functional Similarity Recognition**: Identify if operations are identical with different parameters
- **Generic vs Specific**: Create generic modules that handle multiple similar cases rather than duplicating logic
- **Parameter-Driven Design**: Use configuration parameters instead of separate modules for similar functionality
- **Integration Testing**: When splitting modules, ensure proper inter-module communication and namespace handling

#### Module Design
- Keep modules focused and single-purpose
- **Before splitting**: Analyze if modules perform identical operations with different parameters
- **Prefer generic modules**: Use parameterized modules instead of duplicating similar functionality
- Design for reusability and maintainability
- **When splitting**: Ensure proper namespace implementation and inter-module communication testing
- Implement clear interfaces between modules

### Security Principles
- Use SHA-256 hashing for password storage
- Implement proper session management and cleanup
- Protect sensitive operations with appropriate authorization checks

### Performance Guidelines
- Optimize for typical use cases, not theoretical maximums
- Implement progressive feedback for long-running operations
- Use caching where appropriate to avoid recomputation
- Handle large datasets gracefully with pagination or streaming

### Technology Constraints
- **R/Shiny**: Primary application framework
- **Python Integration**: Via reticulate (existing setup preserved)
- **Database**: SQLite for lightweight, embedded data storage
- **Version Control**: Git with proper branching and commit practices

---

## Documentation Structure

This project maintains multiple documentation layers for different audiences and purposes:

### For AI Assistants (You!)
- **`CLAUDE.md`** (this file) - Core principles, constraints, and development standards
- **`.serena/memories/`** - Technical context, solutions, and implementation details
- **`.serena/memories/INDEX.md`** - Navigation guide for AI-accessible documentation
- **`PRPs/`** - Product Requirement Prompts for feature implementation

### For Human Developers
- **`docs/`** - Human-readable architecture and guides
- **`docs/README.md`** - Documentation overview and navigation
- **`docs/architecture/`** - System architecture and design
- **`docs/guides/`** - Step-by-step development guides
- **`docs/decisions/`** - Architecture Decision Records (ADRs)

### When to Reference What
- **Starting new work?** Read `.serena/memories/INDEX.md` first, then check `docs/architecture/overview.md` for high-level context
- **Making architecture decisions?** Check `docs/decisions/` for precedents, document new decisions there
- **Implementing features?** Use `PRPs/` for specifications, `.serena/memories/` for technical context
- **Onboarding humans?** Point them to `docs/guides/getting-started.md`

---

**Remember**: This document defines the unchanging principles. All detailed requirements, specifications, and implementation details belong in the Product Requirements Document (PRP).
