# Project Structure Template

This document describes the standardized project structure used in Delcampe, designed to be replicated for other projects.

## Overview

This structure supports three key workflows:
1. **AI-Assisted Development** (PRP + Serena + Claude)
2. **Human Developer Onboarding**
3. **Long-term Maintainability**

## Directory Structure

```
project-root/
├── .serena/                    # AI assistant context (Serena framework)
│   ├── memories/               # Technical documentation for AI
│   │   ├── INDEX.md           # Navigation guide
│   │   ├── project_purpose_and_overview.md
│   │   ├── tech_stack_and_architecture.md
│   │   ├── code_style_and_conventions.md
│   │   └── [solution files]
│   ├── session_archives/       # Completed session details
│   └── project.yml            # Serena configuration
│
├── PRPs/                       # Product Requirement Prompts
│   ├── templates/              # PRP templates
│   │   ├── prp_base.md
│   │   ├── prp_task.md
│   │   └── prp_planning.md
│   ├── scripts/               # PRP automation (optional)
│   └── README.md              # PRP methodology guide
│
├── docs/                       # Human-readable documentation
│   ├── architecture/           # System design docs
│   │   ├── overview.md
│   │   ├── data-flow.md
│   │   └── [other architecture docs]
│   ├── guides/                # How-to guides
│   │   ├── getting-started.md
│   │   ├── development-workflow.md
│   │   ├── testing-guide.md
│   │   └── deployment-guide.md
│   ├── decisions/             # Architecture Decision Records
│   │   ├── template.md
│   │   ├── 001-first-decision.md
│   │   └── [other ADRs]
│   └── README.md              # Documentation navigation
│
├── examples/                   # Code examples (for PRP context)
├── ai_docs/                   # Library documentation (for PRP context)
│
├── CLAUDE.md                  # Core principles for AI assistants
├── INITIAL.md                 # Feature request template (optional)
├── README.md                  # Project overview
│
└── [language-specific structure, e.g., R/, src/, lib/]
```

## Core Files to Create

### 1. CLAUDE.md
**Purpose:** Core principles, constraints, and development standards for AI assistants

**Template Sections:**
```markdown
# [Project Name] - Claude Assistant

## Core Principles
- Design Philosophy
- Architecture Philosophy
- Critical Constraints

## Development Standards
- Library Usage Hierarchy
- Code Quality Standards
- Documentation Standards
- Testing Requirements
- Security Principles

## Technology Constraints
- List of technologies used
- Version requirements
- Integration notes

## Documentation Structure
- Reference to docs/, .serena/, and PRPs/
```

### 2. docs/README.md
**Purpose:** Navigation guide for human documentation

**Key Sections:**
- Documentation structure overview
- When to use each documentation type
- Contributing guidelines
- External resources

### 3. docs/architecture/overview.md
**Purpose:** High-level system architecture

**Key Sections:**
- Architecture diagram
- Core components
- Technology stack
- Architectural patterns
- Data flow
- Scalability considerations

### 4. docs/guides/getting-started.md
**Purpose:** New developer onboarding

**Key Sections:**
- Prerequisites
- Setup instructions
- Project structure explanation
- First steps
- Common tasks
- Troubleshooting

### 5. docs/decisions/template.md
**Purpose:** Template for Architecture Decision Records

**Standard ADR Sections:**
- Status, Date, Deciders
- Context and Problem Statement
- Decision Drivers
- Considered Options
- Decision Outcome
- Implementation Notes
- Related Decisions
- References

### 6. .serena/memories/INDEX.md
**Purpose:** Navigation for AI-accessible documentation

**Key Sections:**
- Quick navigation by topic
- File relationships diagram
- When to read what
- Critical files to not miss
- Solution registry
- Search tips

### 7. PRPs/README.md
**Purpose:** Explain PRP methodology

**Key Sections:**
- What is a PRP
- How to use PRPs
- Template descriptions
- Workflow integration

## Setup Checklist for New Projects

### Phase 1: Initial Structure (30 minutes)
```bash
# Create directories
mkdir -p .serena/memories .serena/session_archives
mkdir -p PRPs/templates PRPs/scripts
mkdir -p docs/architecture docs/guides docs/decisions
mkdir -p examples ai_docs

# Copy templates from Delcampe project
cp Delcampe/CLAUDE.md ./CLAUDE.md
cp Delcampe/docs/README.md ./docs/README.md
cp Delcampe/docs/decisions/template.md ./docs/decisions/template.md
cp -r Delcampe/PRPs/templates/* ./PRPs/templates/
```

### Phase 2: Customize Core Files (1 hour)
- [ ] Edit `CLAUDE.md` with project-specific principles
- [ ] Create `docs/architecture/overview.md` with system design
- [ ] Create `docs/guides/getting-started.md` with setup instructions
- [ ] Write first ADR for key technology choice
- [ ] Create `.serena/memories/INDEX.md` with initial structure

### Phase 3: Serena Setup (30 minutes)
- [ ] Initialize Serena: `serena project generate-yml`
- [ ] Create initial memories:
  - `project_purpose_and_overview.md`
  - `tech_stack_and_architecture.md`
  - `code_style_and_conventions.md`
- [ ] Update `.serena/memories/INDEX.md` with these files

### Phase 4: PRP Setup (30 minutes)
- [ ] Copy PRP templates from Delcampe
- [ ] Customize templates for project language/stack
- [ ] Write `PRPs/README.md` with methodology
- [ ] Create example PRP for reference

### Phase 5: Integration (30 minutes)
- [ ] Configure MCP server for Serena
- [ ] Test Claude Desktop integration
- [ ] Verify PRP workflow works
- [ ] Create first feature using PRP

**Total Time:** ~3 hours for complete setup

## Adaptation Guidelines

### For Different Languages

#### Python Projects
```
project-root/
├── src/                # Source code
├── tests/              # Tests
├── pyproject.toml      # Dependencies
└── [standard structure above]
```

#### JavaScript/TypeScript Projects
```
project-root/
├── src/                # Source code
├── tests/              # Tests
├── package.json        # Dependencies
└── [standard structure above]
```

#### R Shiny (Golem) Projects
```
project-root/
├── R/                  # R source code
├── inst/               # Installation files
├── tests/              # Tests
├── DESCRIPTION         # R package description
└── [standard structure above]
```

### For Different Team Sizes

#### Solo Developer
- Simplify `.serena/memories/` (fewer files)
- Skip session archives initially
- Focus on ADRs for major decisions only
- Use PRPs for complex features only

#### Small Team (2-5 people)
- Full structure as described
- Regular memory cleanup
- Weekly ADR reviews
- PRP for all medium+ features

#### Larger Team (5+ people)
- Add `docs/contributing.md`
- Stricter memory lifecycle
- Mandatory ADRs for decisions
- PRP for all new features
- Consider adding `.github/` workflows

### For Different Project Phases

#### New Project (Greenfield)
- Start with minimal memories
- Focus on ADRs early
- Build examples as you go
- Establish patterns quickly

#### Existing Project (Migration)
- Document current state first
- Create ADRs retroactively
- Build memories from tribal knowledge
- Migrate documentation gradually

## Maintenance Guidelines

### Weekly
- [ ] Review new memory files
- [ ] Update INDEX.md if needed
- [ ] Archive completed PRPs

### Monthly
- [ ] Review and archive old memories
- [ ] Update architecture docs if changed
- [ ] Check ADRs for outdated decisions
- [ ] Update getting-started guide

### Quarterly
- [ ] Full documentation audit
- [ ] Consolidate similar memories
- [ ] Update all outdated content
- [ ] Review and improve structure

## Benefits of This Structure

### For AI Assistants
- ✅ Clear context in `.serena/memories/`
- ✅ Structured prompts in `PRPs/`
- ✅ Core principles in `CLAUDE.md`
- ✅ Historical context in session archives

### For Human Developers
- ✅ Onboarding guide in `docs/guides/`
- ✅ Architecture understanding in `docs/architecture/`
- ✅ Decision rationale in `docs/decisions/`
- ✅ Clear project navigation

### For Long-term Maintenance
- ✅ Knowledge preservation across team changes
- ✅ Decision history for future reference
- ✅ Consistent development patterns
- ✅ Reduced onboarding time

## Template Repository

Consider creating a template repository with this structure:

```bash
# Create template repo
git init project-template
cd project-template

# Copy structure from Delcampe
# ... copy files ...

# Commit template
git add .
git commit -m "Initial project structure template"

# Use for new projects
git clone project-template new-project
cd new-project
# Customize for new project
```

## Questions to Consider

When adapting this structure, ask:

1. **Team Size:** How many developers?
2. **Project Complexity:** Simple tool or complex system?
3. **AI Usage:** Heavy AI assistance or occasional?
4. **Documentation Needs:** Internal only or public?
5. **Maintenance Burden:** Can we commit to maintaining this?

Adjust the structure based on your answers.

---

**Last Updated:** 2025-10-11  
**Source Project:** Delcampe Postal Card Processor  
**Status:** Proven in production use

## Related Documents

- `CLAUDE.md` - See "Documentation Structure" section
- `docs/README.md` - Human documentation navigation
- `.serena/memories/INDEX.md` - AI documentation navigation
- `PRPs/README.md` - PRP methodology
