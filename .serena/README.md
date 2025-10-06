# .serena Directory

## What is This?

This directory contains **persistent context and memory** for AI assistants (LLMs) working on the Delcampe project. It serves as a knowledge base that survives across different AI sessions, ensuring that solved problems don't need to be re-solved and important context is never lost.

## Purpose

When an AI assistant works on this project, it can:
1. **Read past solutions** - Understand what problems were solved and how
2. **Learn constraints** - Know what must NOT be changed
3. **Follow conventions** - Maintain consistent coding style
4. **Avoid rework** - Not waste time re-solving solved problems
5. **Build on progress** - Continue from where previous assistants left off

## Structure

```
.serena/
├── memories/                    # Knowledge base files
│   ├── INDEX.md                # Navigation hub (START HERE)
│   ├── tech_stack_and_architecture.md
│   ├── draggable_lines_coordinate_fix.md
│   ├── project_purpose_and_overview.md
│   ├── code_style_and_conventions.md
│   ├── critical_constraints_preservation.md
│   ├── existing_module_analysis.md
│   ├── decomposition_progress_summary.md
│   ├── task_completion_procedures.md
│   └── suggested_commands.md
├── cache/                       # Cached data (can be regenerated)
└── project.yml                  # Project configuration
```

## For AI Assistants

### When You Start Working on This Project

1. **First Time?** Read `memories/INDEX.md` - It's your map to everything
2. **Know the Rules:** Read `memories/tech_stack_and_architecture.md` and `memories/critical_constraints_preservation.md`
3. **Check for Solutions:** Before solving a problem, check if it's already solved in `memories/`

### When You Complete a Task

1. **Document Solutions:** If you solved a significant problem, create a memory file
2. **Update INDEX:** Add your solution to `memories/INDEX.md`
3. **Update Related Files:** If architecture changed, update `tech_stack_and_architecture.md`

## For Human Developers

### Why This Exists

Different AI assistants across different sessions would normally start from scratch each time. This directory ensures:
- **Continuity** - Solutions persist across sessions
- **Efficiency** - No re-solving the same problems
- **Quality** - Best practices are documented and followed
- **Safety** - Critical constraints are clearly marked

### How to Use It

**When starting work:**
- Read `memories/INDEX.md` for navigation
- Check for relevant solutions before implementing

**When fixing bugs:**
- Check if the fix is already documented
- If you find a new fix, consider documenting it here

**When adding features:**
- Follow the conventions in `memories/code_style_and_conventions.md`
- Check `memories/critical_constraints_preservation.md` for what can't change

## File Types in memories/

### Overview Files
- **INDEX.md** - Navigation and quick reference
- **project_purpose_and_overview.md** - What the app does
- **tech_stack_and_architecture.md** - Technologies and structure

### Guidelines
- **code_style_and_conventions.md** - How to write code
- **critical_constraints_preservation.md** - What NOT to change
- **task_completion_procedures.md** - How to complete tasks
- **suggested_commands.md** - Useful commands

### Solutions
- **draggable_lines_coordinate_fix.md** - Coordinate mapping solution (2025-01-06)
- More solutions added as needed with format: `<descriptive_name>.md`

### Analysis
- **existing_module_analysis.md** - Module structure
- **decomposition_progress_summary.md** - Refactoring status

## Naming Convention

Solution files follow this pattern:
```
<descriptive_name>.md
```

Example: `draggable_lines_coordinate_fix.md`

Each should include:
- Date implemented
- Problem statement
- Root cause analysis
- Solution overview
- Technical details
- Files modified
- Testing instructions
- Success metrics
- Related components
- Key learnings for future

## Maintenance

### Adding New Memories

1. Create file in `memories/` with descriptive name
2. Follow the standard structure (see existing files)
3. Update `memories/INDEX.md` to include the new file
4. Update relevant overview files if needed

### Updating Existing Memories

1. Add update note with date at relevant section
2. Update version history if file has one
3. Update `memories/INDEX.md` if status changed

### Archiving Old Memories

If a solution becomes obsolete:
1. Mark as "ARCHIVED" in `memories/INDEX.md`
2. Add archive note at top of file explaining why
3. Keep the file for historical reference
4. Don't delete - it helps understand project evolution

## Best Practices

### For AI Assistants

✅ **DO:**
- Always read `memories/INDEX.md` first
- Check for existing solutions before implementing
- Document significant solutions
- Update relevant memory files when making changes
- Follow conventions in memory files
- Ask clarifying questions if memories conflict with user requests

❌ **DON'T:**
- Skip reading memories and re-solve problems
- Make changes that violate critical constraints
- Delete or modify memory files without understanding impact
- Assume you know better than documented solutions
- Ignore coding conventions

### For Humans

✅ **DO:**
- Keep memories up to date
- Document significant fixes and features
- Review memories when onboarding new AI assistants
- Use memories as project documentation
- Add comments when something is unclear

❌ **DON'T:**
- Delete the .serena directory
- Ignore documented constraints
- Let memories become outdated
- Skip documentation for "small" fixes that turn out to be important

## Cache Directory

The `cache/` subdirectory contains temporary cached data that can be regenerated:
- Python symbol caches
- Compiled assets
- Temporary analysis results

**Safe to delete** - Will be regenerated as needed.

## project.yml

Contains project configuration for the Serena system. Typically includes:
- Project metadata
- AI assistant preferences
- Tool configurations

## Integration with Project

The `.serena/memories/` system integrates with the main project documentation:

```
Project Documentation Hierarchy:

.serena/memories/INDEX.md              ← Central navigation
    ↓
├── For Architecture
│   └── memories/tech_stack_and_architecture.md
│       └── Links to: Root docs (COORDINATE_FIX_SUMMARY.md, etc.)
│
├── For Testing
│   └── tests/README.md
│       └── Links to: memories/draggable_lines_coordinate_fix.md
│
└── For Quick Reference
    └── DOCUMENTATION_GUIDE.md (root)
        └── Links to: memories/INDEX.md
```

## Version Control

**What to commit:**
- ✅ All files in `memories/`
- ✅ `project.yml`
- ✅ `.serena/` directory structure

**What to .gitignore:**
- ❌ `cache/` directory contents
- ❌ Temporary files

## Example Usage Flow

### Scenario: New AI Assistant Joins

1. AI reads `.serena/memories/INDEX.md`
2. AI sees coordinate mapping was solved on 2025-01-06
3. AI reads `draggable_lines_coordinate_fix.md` for details
4. AI now knows not to re-solve that problem
5. AI can build on that solution or fix related issues

### Scenario: Human Developer Debugging

1. Developer encounters coordinate issue
2. Developer reads `DOCUMENTATION_GUIDE.md` (root level)
3. Directed to `.serena/memories/draggable_lines_coordinate_fix.md`
4. Finds explanation, tests, and solution details
5. Runs `tests/manual/verify_fix.R` to check current state

### Scenario: AI Implements New Feature

1. AI reads `memories/tech_stack_and_architecture.md` for constraints
2. AI follows conventions in `memories/code_style_and_conventions.md`
3. AI implements feature following Golem structure
4. AI creates `memories/new_feature_implementation.md`
5. AI updates `memories/INDEX.md` with new solution entry

## FAQ

**Q: Can I delete this directory?**  
A: Please don't. It contains valuable context that saves time. If disk space is a concern, you can delete `cache/` but keep `memories/`.

**Q: Should I commit this to Git?**  
A: Yes! The `memories/` directory should be version controlled. Only exclude `cache/` in .gitignore.

**Q: What if a memory file is wrong?**  
A: Update it with correct information and add a note about the correction. Keep the history.

**Q: How often should I update memories?**  
A: Update when you make significant changes to architecture, solve major problems, or discover important patterns.

**Q: Can I reorganize these files?**  
A: Yes, but update `INDEX.md` accordingly and ensure all cross-references are updated.

**Q: What if I'm working without AI?**  
A: The memories are still useful documentation for you! They explain past decisions and solutions.

## Related Documentation

- **Root Level:**
  - `DOCUMENTATION_GUIDE.md` - Overview of all documentation
  - `COORDINATE_FIX_SUMMARY.md` - Technical reference
  - `IMPLEMENTATION_GUIDE.md` - Quick testing guide

- **Tests:**
  - `tests/README.md` - Testing documentation
  - `tests/manual/verify_fix.R` - System verification

## Contact & Support

For questions about this system:
- Check existing memory files first
- Refer to `memories/INDEX.md` for navigation
- Review `DOCUMENTATION_GUIDE.md` in project root

## Philosophy

> "The best documentation is the one that prevents problems from recurring."

This `.serena` directory embodies that philosophy by:
- **Preserving knowledge** across AI sessions
- **Documenting solutions** so they're not forgotten
- **Establishing constraints** so they're not violated
- **Maintaining continuity** across development

## Version History

- **v1.0** (2025-01-06): Initial .serena structure created
- **v1.1** (2025-01-06): Added draggable_lines_coordinate_fix.md
- **v1.2** (2025-01-06): Created comprehensive INDEX.md and documentation system

---

**Remember**: This directory is your project's institutional memory. Treat it well, keep it updated, and it will save you countless hours of rediscovering solutions.
