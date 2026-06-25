---
name: simplify
description: Review changed or planned code for over-engineering, unnecessary complexity, and missed reuse opportunities. Strips AI slop, removes redundant variables/functions/routes, and finds simpler paths to the same result. Use after implementation, during plan review, or when code feels bloated.
allowed-tools: Bash, Read, Edit, Glob, Grep, Agent
---

# Simplify — Strip Over-Engineering & Find the Shortest Path

You are an aggressive simplification reviewer. Claude (and AI in general) systematically over-engineers: adding unnecessary variables, creating new functions for one-time use, adding extra routes, extra error handling, extra abstraction layers, and extra logic steps. Your job is to find every case where the same result can be achieved with less.

**Announce at start:** "Running /simplify on [target]."

## Input

Accepts one of:
- A file path or glob pattern — review those files
- A plan path — review the plan's proposed code for over-engineering BEFORE implementation
- No argument — review all uncommitted changes (`git diff --name-only`)

## The Simplification Checklist

For every file or plan section, check ALL of the following:

### 1. Unnecessary Variables
- Variable assigned once and used once on the next line → inline it
- Variable that just renames another variable → use the original
- Destructuring that creates names identical to the source → skip destructuring
- `const result = await foo(); return result;` → `return await foo();`

### 2. Unnecessary Functions & Abstractions
- Function called from exactly one place → inline it at the call site
- Wrapper function that just forwards all args to another function → call the inner function directly
- Helper that adds zero logic (just re-exports or renames) → delete it
- New utility file for a single function → put it where it's used
- Abstract base class with one implementation → delete the base class

### 3. Unnecessary Routes & Endpoints
- New API route that duplicates an existing route's behavior → reuse existing
- Route that could be a query parameter on an existing route → add the parameter
- Separate GET endpoint for data already returned by another endpoint → extend the existing one

### 4. Unnecessary Logic & Steps
- If/else that could be a single expression (ternary, `||`, `??`)
- Try/catch around code that can't throw → remove the try/catch
- Validation for values that are already validated upstream → remove
- Null checks on values guaranteed non-null by the query/flow → remove
- `.map().filter()` that could be a single `.reduce()` or `.flatMap()`
- Sequential awaits that could be `Promise.all()` → parallelize
- Intermediate data transformations that could be done in the query → push to SQL

### 5. Existing Code Reuse
- New function that duplicates logic already in an existing service → use the existing one
- New constant/enum that mirrors existing values → use existing
- New type/interface that overlaps with existing types → extend or reuse
- Copy-pasted code block with minor differences → parameterize the existing one

### 6. AI Code Slop Detection
- Comments that state the obvious (e.g., `// Check if user exists` before `if (!user)`)
- Excessive JSDoc on internal functions that are self-documenting
- Try/catch blocks that just log and rethrow without adding context
- `console.log` debug statements left behind
- Type casts to `any` to work around type issues → fix the type
- Defensive checks in internal code paths called by already-validated callers
- Overly verbose error messages that leak implementation details
- **Try/catch wrapping a service call with hardcoded fallback** → the primary path is dead code if the method doesn't exist, and the fallback masks the bug forever. Pattern: `try { result = svc.method(); } catch { result = HARDCODED; }`. Flag as Critical — either implement the method or remove the try/catch and use the direct value. Incident: `getGatewayAccount()` never existed, try/catch fell back to hardcoded IDs, survived 33 days across 6 PRs undetected.

### 7. Structural Simplification
- Deeply nested conditionals (3+ levels) → early returns / guard clauses
- Long switch/if-else chains → lookup object/map
- Complex boolean expressions → extract to a descriptively-named const
- Function with 5+ parameters → consider an options object (only if it genuinely clarifies)
- File over 400 lines → check if it has multiple concerns that should be split

## Output Format

```
## Simplification Report

### Summary
- Files reviewed: N
- Simplifications found: N (Critical: X, Moderate: Y, Minor: Z)
- Estimated lines removable: ~N

### Critical (actively harmful complexity)
1. **[file:line]** — [what's wrong] → [fix]

### Moderate (unnecessary but not harmful)
1. **[file:line]** — [what's wrong] → [fix]

### Minor (polish)
1. **[file:line]** — [what's wrong] → [fix]

### Existing Reuse Opportunities
1. **[new code location]** duplicates **[existing code location]** — use [existing function/constant]

### No Change Needed
- [file] — already clean
```

## Applying Fixes

After presenting the report:
1. Ask: "Want me to apply these simplifications?"
2. If yes: apply Critical and Moderate fixes. Skip Minor unless requested.
3. After applying: run `npm run quality` to verify nothing broke
4. Show a before/after line count comparison

## Hard Rules

1. **Simpler = easier to understand on first read.** Not fewer lines, not cleverer.
2. **Never change behavior.** This is refactoring. If a simplification might change behavior, flag it but don't apply.
3. **Respect existing patterns.** If the codebase uses a style consistently, don't fight it.
4. **Three similar lines > premature abstraction.** Duplication across module boundaries is fine if coupling would be worse.
5. **Existing code is the best code.** Always check if something already exists before accepting new code.
6. **Domain complexity is not over-engineering.** If logic is complex because the domain is complex, add a comment instead of simplifying away correctness.
7. **Don't add while simplifying.** No new files, functions, or abstractions to "improve" the simplification. Only remove and inline.
