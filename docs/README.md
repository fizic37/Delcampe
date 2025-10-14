# Delcampe Documentation

This directory contains human-readable documentation for the Delcampe Postal Card Processor project.

## 📚 Documentation Structure

### 📁 `/architecture`
High-level system architecture and design documentation:
- **overview.md** - System architecture overview
- **data-flow.md** - How data flows through the application
- **r-python-integration.md** - R and Python integration details
- **module-structure.md** - Shiny module organization

### 📁 `/guides`
Step-by-step guides for common tasks:
- **getting-started.md** - New developer onboarding
- **development-workflow.md** - Day-to-day development process
- **testing-guide.md** - How to write and run tests
- **deployment-guide.md** - Production deployment steps

### 📁 `/decisions`
Architecture Decision Records (ADRs) documenting important choices:
- **001-golem-framework.md** - Why Golem was chosen
- **002-python-opencv.md** - Python for image processing
- **003-sqlite-database.md** - SQLite for data storage
- **template.md** - Template for new ADRs

## 🔄 Relationship with Other Documentation

### AI-Accessible Documentation
- **`.serena/memories/`** - Detailed technical context for AI assistants
- **`.serena/memories/INDEX.md`** - AI documentation navigation

### Implementation Specifications
- **`PRPs/`** - Product Requirement Prompts for feature implementation
- **`PRPs/templates/`** - PRP templates

### Quick References
- **`CLAUDE.md`** - Core principles and constraints for AI assistants
- **`INTEGRATION_GUIDE.md`** - Step-by-step integration instructions
- **`QUICK_REFERENCE.md`** - Function reference and examples

## 🎯 When to Use This Documentation

### Use `/docs` when you need to:
- Understand the overall system architecture
- Onboard a new human developer
- Make an architecture decision
- Document deployment procedures
- Explain the system to non-technical stakeholders

### Use `.serena/memories/` when you need to:
- Work with AI assistants (Claude, etc.)
- Find technical solutions to specific problems
- Understand implementation details
- Review past debugging sessions

### Use `PRPs/` when you need to:
- Implement a new feature
- Plan complex changes
- Provide context for AI-driven development

## 📝 Contributing to Documentation

### Adding New Documentation
1. Choose the appropriate directory based on content type
2. Use clear, descriptive filenames
3. Follow the existing documentation style
4. Update this README with links to new docs

### Adding Architecture Decisions
1. Copy `decisions/template.md`
2. Number sequentially (e.g., `004-new-decision.md`)
3. Fill in all sections
4. Update the decisions index

### Maintaining Documentation
- Review quarterly for outdated information
- Update when significant changes occur
- Keep examples current with codebase
- Cross-reference related documentation

## 🔗 External Resources

- [Golem Framework](https://thinkr-open.github.io/golem/) - R Shiny application framework
- [Shiny Documentation](https://shiny.rstudio.com/) - R Shiny reference
- [reticulate](https://rstudio.github.io/reticulate/) - R-Python integration
- [OpenCV Python](https://docs.opencv.org/4.x/d6/d00/tutorial_py_root.html) - Image processing

## 📋 Documentation Standards

### Writing Style
- Clear and concise
- Use examples liberally
- Assume intermediate technical knowledge
- Link to code examples where applicable

### Format
- Use Markdown for all documentation
- Include table of contents for long documents
- Use diagrams when helpful (Mermaid syntax preferred)
- Keep line length reasonable (80-100 characters)

### Maintenance
- Mark outdated sections with `⚠️ OUTDATED` warning
- Update modification date at bottom of file
- Version control through Git, not document versioning

---

**Last Updated:** 2025-10-11  
**Maintained By:** Development Team  
**Related:** See `CLAUDE.md` for AI assistant principles, `.serena/memories/INDEX.md` for AI documentation
