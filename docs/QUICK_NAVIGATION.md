# Quick Reference: Documentation Navigation

## For Humans Starting Out

### First Time Here?
1. 📖 **Read:** `docs/README.md` (5 min)
2. 🏗️ **Understand:** `docs/architecture/overview.md` (15 min)
3. 🚀 **Setup:** `docs/guides/getting-started.md` (30 min)

### Working on Features?
1. 📋 Check if feature has PRP in `PRPs/`
2. 🔍 Search `.serena/memories/INDEX.md` for related context
3. 💡 Reference `CLAUDE.md` for principles

### Making Architecture Decisions?
1. 📚 Review existing ADRs in `docs/decisions/`
2. 📝 Use `docs/decisions/template.md` for new decisions
3. 🔗 Update cross-references

---

## For AI Assistants

### Starting New Work?
```
1. Read .serena/memories/INDEX.md
2. Load relevant memory files
3. Check CLAUDE.md for constraints
4. Reference docs/architecture/overview.md for high-level context
```

### Implementing Features?
```
1. Check if PRP exists in PRPs/
2. Load PRP context
3. Read related memories
4. Execute tasks iteratively
5. Document in new memory file
```

### Need Architecture Context?
```
1. Read docs/architecture/overview.md (high-level)
2. Check docs/decisions/ for decision rationale
3. Refer to .serena/memories/ for technical details
```

---

## Document Locations Quick Map

```
project-root/
│
├── CLAUDE.md ----------------------> Core principles & constraints
│
├── docs/ --------------------------> HUMAN documentation
│   ├── README.md -----------------> Start here for navigation
│   ├── architecture/
│   │   └── overview.md -----------> System design & patterns
│   ├── guides/
│   │   └── getting-started.md ----> Onboarding guide
│   ├── decisions/
│   │   ├── template.md -----------> ADR template
│   │   └── *.md ------------------> Architecture decisions
│   └── PROJECT_STRUCTURE_TEMPLATE.md -> Replication guide
│
├── .serena/ -----------------------> AI documentation
│   ├── memories/
│   │   ├── INDEX.md --------------> AI navigation (START HERE)
│   │   └── *.md ------------------> Technical solutions & context
│   └── session_archives/ ---------> Completed session details
│
└── PRPs/ --------------------------> Feature specifications
    ├── templates/ ----------------> PRP templates
    └── README.md -----------------> PRP methodology
```

---

## Common Questions

### "Where do I learn about the system?"
→ `docs/architecture/overview.md`

### "How do I set up my environment?"
→ `docs/guides/getting-started.md`

### "Why was this decision made?"
→ `docs/decisions/` (search by topic)

### "How do I implement a feature?"
→ Create/use PRP in `PRPs/`, reference `.serena/memories/`

### "What are the core principles?"
→ `CLAUDE.md`

### "What was implemented recently?"
→ `.serena/memories/INDEX.md` (check "Latest Session")

### "How do I find a past solution?"
→ `.serena/memories/INDEX.md` search tips, or ask AI to search

### "How do I replicate this for another project?"
→ `docs/PROJECT_STRUCTURE_TEMPLATE.md`

---

## Documentation Layers Cheat Sheet

| Need | AI Docs | PRPs | Human Docs |
|------|---------|------|------------|
| **High-level understanding** | ❌ | ❌ | ✅ docs/architecture/ |
| **Onboarding guide** | ❌ | ❌ | ✅ docs/guides/ |
| **Decision rationale** | ❌ | ❌ | ✅ docs/decisions/ |
| **Technical solutions** | ✅ .serena/memories/ | ❌ | ❌ |
| **Implementation details** | ✅ .serena/memories/ | ✅ PRPs/ | ❌ |
| **Feature specifications** | ❌ | ✅ PRPs/ | ❌ |
| **Core principles** | See CLAUDE.md | See CLAUDE.md | See CLAUDE.md |

---

## Workflow Quick Guides

### New Developer Onboarding
```
1. docs/README.md
2. docs/guides/getting-started.md
3. docs/architecture/overview.md
4. Clone & setup (follow getting-started)
5. Browse .serena/memories/INDEX.md
6. Make first small change
```

### Implementing New Feature
```
1. Create PRP in PRPs/ (use template)
2. Read relevant .serena/memories/
3. Check CLAUDE.md for constraints
4. Implement iteratively
5. Test continuously
6. Document in .serena/memories/
7. Update INDEX.md
```

### Making Architecture Decision
```
1. Research options
2. Check existing ADRs in docs/decisions/
3. Consult team
4. Use docs/decisions/template.md
5. Create ADR document
6. Link from relevant docs
7. Communicate to team
```

---

## File Creation Guide

### Creating New Human Doc
```bash
# Choose correct folder
docs/architecture/  # System design
docs/guides/        # How-to guides
docs/decisions/     # ADRs

# Follow existing patterns
# Update docs/README.md with link
# Cross-reference related docs
```

### Creating New Memory
```
# AI assistants use:
serena:write_memory(
  memory_name="feature_name_YYYYMMDD",
  content="..."
)

# Update .serena/memories/INDEX.md
# Add to appropriate section
# Cross-reference related memories
```

### Creating New PRP
```bash
# Copy template
cp PRPs/templates/prp_task.md PRPs/my-feature.md

# Fill in:
- Context (docs, patterns, gotchas)
- Tasks with validation
- Success criteria

# Execute with AI assistant
```

---

## Maintenance Reminders

### Weekly
- [ ] New memories archived if completed
- [ ] INDEX.md updated
- [ ] PRPs moved if completed

### Monthly
- [ ] docs/ reviewed for outdated content
- [ ] Old memories archived
- [ ] ADRs reviewed

### Quarterly
- [ ] Full documentation audit
- [ ] Structure refinements
- [ ] Team feedback incorporated

---

## Getting Help

### For Documentation Issues
1. Check docs/README.md
2. Search .serena/memories/INDEX.md
3. Ask team or AI assistant

### For Technical Issues
1. Check .serena/memories/ for past solutions
2. Review relevant ADRs
3. Consult CLAUDE.md for constraints

### For Process Questions
1. Read docs/guides/
2. Check PRPs/README.md
3. Review PROJECT_STRUCTURE_TEMPLATE.md

---

**Last Updated:** 2025-10-11  
**Quick Access:** Keep this file open as reference  
**Full Guide:** See docs/README.md
