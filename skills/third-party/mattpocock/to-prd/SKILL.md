---
name: to-prd
description: Turn the current conversation context into a PRD. Use when user wants to create a PRD from the current context, synthesize discussion into a spec, or formalize requirements.
---

> **Original author:** [Matt Pocock](https://github.com/mattpocock/skills)  
> **Source:** [mattpocock/skills/skills/engineering/to-prd](https://github.com/mattpocock/skills/tree/main/skills/engineering/to-prd)

# To PRD

Synthesize the current conversation context and codebase understanding into a PRD. Do NOT interview the user — just synthesize what you already know.

## Process

1. **Explore** the repo to understand current state if you haven't already.

2. **Sketch modules** you will need to build or modify. Look for opportunities to extract deep modules (small interface, deep implementation). Check with the user that modules match expectations.

3. **Write the PRD** using the template below.

## Template

```markdown
## Problem Statement
The problem from the user's perspective.

## Solution
The solution from the user's perspective.

## User Stories
Extensive numbered list:
1. As an <actor>, I want a <feature>, so that <benefit>

## Implementation Decisions
- Modules to build/modify
- Interfaces and their shape
- Technical clarifications
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include file paths or code snippets (they become outdated quickly).

## Testing Decisions
- What makes a good test (behavior, not implementation)
- Which modules will be tested
- Prior art for the tests

## Out of Scope
Things explicitly excluded.

## Further Notes
Any additional context.
```
