# Delcampe Postal Card Processor - Claude Assistant

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
- **Mandatory testing** for every module created
- Use Golem's testing framework with testthat
- Test UI components, server logic, and module interactions
- Include error scenario and edge case testing

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
- Store API keys in environment variables only
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

**Remember**: This document defines the unchanging principles. All detailed requirements, specifications, and implementation details belong in the Product Requirements Document (PRP).
