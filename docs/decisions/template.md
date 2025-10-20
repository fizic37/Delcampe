# Architecture Decision Record Template

Use this template to document important architectural decisions.

## ADR-XXX: [Decision Title]

**Status:** [Proposed | Accepted | Deprecated | Superseded]  
**Date:** YYYY-MM-DD  
**Deciders:** [List of people involved in the decision]  
**Technical Story:** [Link to issue/ticket if applicable]

## Context and Problem Statement

Describe the context and problem statement in free form using two to three sentences. You may want to articulate the problem in the form of a question.

**Example:**
> We need to process images of postal cards, including grid detection and individual card extraction. What technology should we use for image processing?

## Decision Drivers

List the factors that influenced the decision:
- **Factor 1:** [Description]
- **Factor 2:** [Description]
- **Factor 3:** [Description]

**Example:**
- Need robust computer vision capabilities
- Must integrate with R Shiny application
- Team has Python experience
- Performance requirements for real-time processing

## Considered Options

List all options that were considered:

### Option 1: [Name of option]
**Description:** Brief description of the option

**Pros:**
- ✅ Advantage 1
- ✅ Advantage 2

**Cons:**
- ❌ Disadvantage 1
- ❌ Disadvantage 2

### Option 2: [Name of option]
**Description:** Brief description of the option

**Pros:**
- ✅ Advantage 1
- ✅ Advantage 2

**Cons:**
- ❌ Disadvantage 1
- ❌ Disadvantage 2

## Decision Outcome

**Chosen option:** "[Option name]", because [justification. e.g., only option which meets k.o. criterion decision driver | which resolves force force | … | comes out best (see below)].

### Positive Consequences
- Consequence 1
- Consequence 2
- Consequence 3

### Negative Consequences
- Consequence 1
- Consequence 2
- Mitigation: How we'll handle this

## Implementation Notes

Any specific details about how to implement this decision:
- Technical considerations
- Code locations
- Dependencies
- Configuration requirements

## Related Decisions

Links to related ADRs:
- ADR-001: [Related decision title]
- ADR-005: [Another related decision]

## References

Links to external resources that informed this decision:
- [Technology documentation]
- [Blog posts]
- [Research papers]
- [Team discussions]

## Validation

How do we know if this decision was correct?
- **Success Criteria:** What would indicate success
- **Review Date:** When to review this decision
- **Metrics:** How to measure impact

---

**Last Updated:** [Date of last update]  
**Author:** [Your name]  
**Reviewers:** [People who reviewed this]
