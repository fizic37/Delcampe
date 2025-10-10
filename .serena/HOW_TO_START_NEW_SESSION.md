# How to Start a New LLM Session

## Quick Start Template

```
I'm working on the Delcampe R Shiny project (Golem framework).

Please read .serena/memories/INDEX.md for context first.

My issue: [describe problem]

[Include screenshots/errors if relevant]
```

## Issue-Specific Templates

### UI Problem
```
Delcampe project - read .serena/memories/INDEX.md

UI Issue: [visual problem]
Location: [module/page]
Expected vs Actual: [describe]
```

### Bug Report
```
Delcampe - read .serena/memories/INDEX.md

Bug: [what's broken]
Steps to reproduce: [1, 2, 3...]
Error: [paste error message]
```

### Coordinate/Lines
```
Delcampe - coordinate issue

Read: .serena/memories/draggable_lines_coordinate_fix.md

Problem: [alignment/positioning issue]
Console logs: [paste]
```

### New Feature
```
Delcampe - new feature request

Read: .serena/memories/INDEX.md
Read: .serena/memories/tech_stack_and_architecture.md

Feature: [what you want to add]
Requirements: [specifics]
```

## Key Files to Reference

- **Always start here**: `.serena/memories/INDEX.md`
- **Architecture**: `.serena/memories/tech_stack_and_architecture.md`
- **Constraints**: `.serena/memories/critical_constraints_preservation.md`
- **Coordinate issues**: `.serena/memories/draggable_lines_coordinate_fix.md`

## Best Practices

✅ DO:
- Mention .serena/memories/INDEX.md first
- Be specific about the problem
- Include error messages
- Mention relevant files/modules
- Attach screenshots for UI issues

❌ DON'T:
- Skip mentioning the memory system
- Be vague ("fix everything")
- Forget to mention Golem framework
- Skip console logs

## Quick Reference

View available documentation:
```r
file.show(".serena/memories/INDEX.md")
```

View all memory files:
```r
list.files(".serena/memories/")
```

## Example Session Starters

**Good:**
> Delcampe project - read .serena/memories/INDEX.md. Image upload broken in Face module. Console shows resource path error.

**Better:**
> Delcampe R Shiny (read .serena/memories/INDEX.md). Face module image preview blank after upload. R console: [logs]. Browser: 404 on /face-session_images/. Suspect resource path issue in mod_postal_card_processor.R line 195.

---

Save this file for future reference!
