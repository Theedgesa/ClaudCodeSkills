---
name: check-errors
description: Load all past errors, debugging patterns, and lessons learned, then compare against the current plan, implementation, or code changes. Use when user says "check errors", "check past errors", before planning, during implementation, or as part of review gates. Also invoked automatically by /plan, /implement, /verify-plan, /review-gates, and /post-review.
---

# Check Errors — Past Error & Lesson Comparison

Load every recorded mistake, debugging pattern, and incident from memory. Compare against current work to catch recurrence before it happens.

**Announce at start:** "Running /check-errors against current work."

---

## When to Use

- Standalone: user says "check errors", "check past errors", "what mistakes apply here"
- Automatic: invoked by /plan (Pre-flight), /implement (Phase Preparation), /verify-plan, /review-gates (Gate 0), /post-review (Step 3.5)

## Input

Accepts one optional argument: path to a plan file, changed file list, or "current" (auto-detect).

- If no argument: detect from context — look for active plan in `.claude/work/.active`, or recent git changes
- If plan path: scan the plan for patterns that match past errors
- If "phase N": scan only that phase's code and UATs

---

## Error Sources (Load All)

### Source 1: Past Errors Rules
**File:** `.claude/rules/anti-patterns/past-errors.md`
**Contains:** Numbered rules (1-44+) from production incidents. Each has: rule text, incident reference, prevention pattern.

### Source 2: Debugging Patterns
**File:** `memory/base/debugging.md` (auto-memory)
**Contains:** Named patterns (SuperTokens SDK, Supabase silent null, finance-service, check-in, Zoho SMTP, MF sandbox, etc.)

### Source 3: Claude-Mem Observations
**Tool:** `claude-mem:mem-search` with query "error OR bug OR incident OR mistake OR lesson OR fix"
**Contains:** Cross-session observations tagged as bugfixes, discoveries, and decisions.

### Source 4: Architecture Rules
**Files:** `.claude/rules/architecture/*.md`
**Contains:** Critical rules per domain (auth, payments, email, RBAC, locations, passes). Violations of these rules are a category of past error.

---

## Process

### Step 1: Load Error Database

Read all four sources in parallel:

1. Read `.claude/rules/anti-patterns/past-errors.md` — extract every numbered rule
2. Read `memory/base/debugging.md` — extract every named pattern
3. Search claude-mem: `smart_search` for "error bug incident fix lesson" — get recent observations
4. Identify which architecture rule files are relevant to the current work (based on file paths, domains touched)

### Step 2: Identify Current Work Scope

Determine what's being checked:

- **Plan mode:** Read the plan file. Extract: files to modify, DB tables touched, services called, APIs integrated, payment code, auth code, frontend code, cron/scheduled jobs, webhooks
- **Implementation mode:** List changed files since last commit. Categorize by domain (backend/frontend/DB/config)
- **Review mode:** Read the plan + diff of changed files

### Step 3: Match Errors to Scope

For each error source, check relevance against the current scope:

| Domain Signal | Relevant Rules (past-errors) | Relevant Patterns (debugging) |
|---------------|-------------------------------|-------------------------------|
| Profile/auth code | #2, #4, #5 | Pattern 4 (FK violation), Pattern 0 (SuperTokens) |
| SQL migration | #7, #15, #34 | Pattern 1 (silent null) |
| Payment gateway | #17, #23 | MF KeyType, MF sandbox, Tamara JWT/lifecycle |
| Frontend deploy | #20, #23, #25, #26 | Staging HMR, workspace hoisting |
| Supabase queries | #7, #12 | Pattern 1 (silent null), Pattern 2 (two query paths) |
| Zoho integration | #35, #43, #44 | Zoho SMTP block, OAuth rate limiting, auto-number collision |
| Webhook code | #22, #36, #43 | Tamara dual format, JSONB key casing |
| Cron/scheduled jobs | #35 | Safety net floods |
| Email code | #8 | Pattern 6 (at Unknown), Pattern 7 (normalizeEmail) |
| Env vars | #8, #23, #26 | Missing env vars after auth deploy |
| Data transformations | #16 | — |
| Express routes | #36, #39 | — |
| Pass/check-in | — | Pattern 2, Pattern 3, check-in investigation |
| DB triggers | #43 | JSONB payload key mismatch |
| Service method calls | #22, #37, #39 | provider.svc undefined |
| Workspace/deps | #26 | PM2 binary vanishes, version drift |
| Multi-tenant | — | (check architecture rules for tenant_id scoping) |

### Step 4: Deep Scan Each Match

For each matched error/pattern, verify whether the current work has protection:

**For past-error rules:**
1. Read the rule's prevention pattern
2. Search the current plan/code for the prevention pattern
3. If prevention is MISSING → flag as RISK
4. If prevention is PRESENT → flag as PROTECTED

**For debugging patterns:**
1. Read the pattern's diagnostic and fix
2. Check if the current work introduces or touches the same code path
3. If same code path AND no guard → flag as RISK

**For architecture rule violations:**
1. Read the critical rules section
2. Check current code against each relevant rule
3. If violation found → flag as VIOLATION

### Step 5: Produce Report

```
## /check-errors Report

### Scope
- Mode: [plan/implementation/review]
- Files: [N files in scope]
- Domains: [list of domains detected]

### RISKS (past errors that could recur)

| # | Source | Rule/Pattern | Why It Matches | Protection Status |
|---|--------|-------------|----------------|-------------------|
| 1 | past-errors #7 | BEGIN/COMMIT for SQL | Plan §9 has migration SQL | MISSING — no BEGIN/COMMIT wrapper |
| 2 | past-errors #43 | JSONB key casing | Plan creates DB trigger with jsonb_build_object | PROTECTED — consumer uses matching snake_case |
| 3 | debugging | MF sandbox test cards | Plan touches payment flow | RISK — no sandbox mode check |

### VIOLATIONS (architecture rules broken)

| # | Rule File | Rule | Violation |
|---|-----------|------|-----------|
| 1 | option1-auth.md | Never create profiles for guests | Code inserts profile without auth check |

### PROTECTED (past errors with active prevention)

| # | Rule/Pattern | Protection Found |
|---|-------------|-----------------|
| 1 | past-errors #12 | End-to-end verification in UAT Tier 2 |
| 2 | past-errors #20 | Playwright tests in every phase |

### Summary
- Errors checked: [N]
- RISK (needs fix): [N]
- VIOLATION: [N]
- PROTECTED: [N]
- Not applicable: [N]
```

### Step 6: Recommend Fixes

For each RISK or VIOLATION:
- State the specific fix needed (exact code change, plan section edit, UAT addition)
- Reference the original incident so the user understands the severity
- If in plan mode: suggest plan edits
- If in implementation mode: suggest code changes
- If in review mode: flag as blocker

---

## Integration Contract

When invoked by other skills, return a structured result:

- **Pass:** 0 RISKS, 0 VIOLATIONS → "Past-error check: CLEAR (N rules checked)"
- **Fail:** Any RISK or VIOLATION → "Past-error check: N RISKS, N VIOLATIONS — see report"

The calling skill decides whether to block or warn based on the result.

---

## Hard Rules

1. Load ALL four error sources — never skip a source
2. Every matched rule must be checked for protection — never assume compliance
3. Architecture rule violations are always VIOLATION severity — never downgrade
4. Past-error rules with incident references are HIGH priority — these happened in production
5. Debugging patterns without incident references are MEDIUM priority — these are recurring traps
6. Report must be actionable — every RISK gets a specific fix recommendation
7. Never mark a rule as "not applicable" without stating why
8. If invoked standalone, write report to stdout. If invoked by another skill, return structured result.
