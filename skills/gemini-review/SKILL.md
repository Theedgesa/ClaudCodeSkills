---
name: gemini-review
description: Send work to Gemini CLI for a second-opinion review. Works for code (PRs, implementations, plans) and non-code (research findings, device reverse-engineering, documentation, investigations). Use when user says "gemini review", "send to gemini", "get gemini's opinion", "/gemini-review", or wants a second AI perspective on any work.
---

# Gemini Review

Send current work context to Gemini CLI for an independent review.

## Prerequisites

Gemini CLI must be available. Check with `which gemini`. If missing:
```bash
npm install -g @google/gemini-cli
```
First run requires `gemini` (interactive) to authenticate with Google.

## Workflow

### 1. Determine review scope

Ask the user if not obvious from context:
- **What to review:** specific files, git diff, research findings, a plan, conversation summary
- **Review focus:** correctness, approach, gaps, alternatives, security, completeness
- **Type:** `code` | `research` | `plan` | `docs` | `general`

### 2. Package the context

Write a single markdown file to `/tmp/gemini-review-prompt.md` containing:

```markdown
# Review Request

## Type
[code | research | plan | docs | general]

## Focus
[What specifically to evaluate — e.g. "correctness of Zigbee cluster commands", "security of auth flow", "gaps in reverse-engineering findings"]

## Context
[Background the reviewer needs — project, goals, constraints]

## Work to Review
[The actual content — code, findings, plan, etc.]

## Specific Questions
[Numbered list of specific things to validate or get opinions on]
```

**Packaging rules:**
- For code: include the actual file contents, not just descriptions
- For research/investigations: include raw findings, commands tried, results observed
- For plans: include the full plan text
- For git changes: include `git diff` output
- Keep under 100K characters — Gemini has context limits too
- Strip irrelevant noise (node_modules paths, build output, etc.)

### 3. Send to Gemini

```bash
gemini -p "You are reviewing work done by another AI agent (Claude). Read the review request below and provide a thorough, critical review. Be specific — cite line numbers, quote exact values, and flag anything that looks wrong, incomplete, or could be done better. Do not be polite — be useful.

$(cat /tmp/gemini-review-prompt.md)" 2>&1 | tee /tmp/gemini-review-response.md
```

**If `gemini` is not in PATH**, fall back to:
```bash
npx -y @google/gemini-cli -p "..." 2>&1 | tee /tmp/gemini-review-response.md
```

**Flags:**
- Always use `-p` (headless/non-interactive)
- Use `--approval-mode plan` if available (read-only, no file edits)
- Timeout: 120s should be enough; bump to 300s for large reviews

### 4. Present results

Read `/tmp/gemini-review-response.md` and present to the user with:
- Key findings summarized at top
- Whether you agree/disagree with each point
- Any action items you'd recommend based on the review

## Examples

**Code review:**
```
/gemini-review — review the changes in leelen_k3.js converter
```

**Research review:**
```
/gemini-review — review our Zigbee curtain motor reverse-engineering findings
```

**Plan review:**
```
/gemini-review — review the plan at .claude/work/PROJ-144/plan.md
```

**Quick general:**
```
/gemini-review "is this the right approach for multi-tenant auth?"
```
