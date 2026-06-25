---
name: review-gates
description: Run all 7 review gates (Gate 0-6) on an existing plan. Sequential quality gates that must all pass before plan approval. Use when user says "/review-gates", "run the gates", "validate the plan", or wants to re-run gates after plan edits. Also called automatically by /plan after writing.
---

# Review Gates — 7 Sequential Quality Gates for Plans

Run all 7 review gates on an implementation plan. Each gate has a pass/fail condition. All 7 must pass before the plan can be approved.

**Announce at start:** "Running /review-gates on `<plan-path>`."

## When to Use

- After writing a plan (called by `/plan` automatically)
- After editing a plan that previously passed gates (re-validate)
- When user says "/review-gates", "run the gates", "validate the plan"
- Before `/implement` if gates haven't been run yet

## Input

Accepts one argument: the path to the plan file.

- If no argument provided, look for the most recently modified plan in `.claude/work/*/plan.md`
- If multiple candidates, ask which one

## Flags

- `--skip-critique` — Skip Gate 6 for simple single-phase plans
- `--gate N` — Run only gate N (0-6) for targeted re-validation
- `--from N` — Start from gate N, skip already-passed gates

## The 7 Gates

Gates run sequentially. A gate failure does NOT stop the remaining gates — all 7 run, then results are presented together so the user sees the full picture.

### Gate 0: Past-Error Cross-Check (`/check-errors`)

Invoke `/check-errors` on the plan.

Checks: every past error rule, debugging pattern, architecture rule violation, and claude-mem incident against the plan's scope (files, domains, services, DB tables, APIs).

**Pass condition:** 0 RISKS, 0 VIOLATIONS
**No marker** — blocking gate, RISKS and VIOLATIONS must be resolved

### Gate 1: API Surface Verification (`/verify-plan`)

Invoke `/verify-plan` on the plan.

Checks: every function call, method reference, column name, DB constraint, SDK method, route middleware chain, object property chain, temporal bounds, string-match queries, REQ-to-phase-gate coverage, and Change Manifest completeness against actual source code.

**Pass condition:** 0 FAIL items
**Marker:** `.claude/work/PROJ-NNN-name/.api-verified`

### Gate 2: REQ Coverage (`/uat-design`)

Invoke `/uat-design` on the spec referenced in the plan header.

Checks: REQ quality (evidence tier, verification method realism, outcome specificity, independence), 4-path coverage per SC (happy/failure/boundary/existing-data), 9-dimension coverage, high-effort REQ verification adequacy.

**Pass condition:** 100% REQ quality AND 100% 4-path coverage AND 100% dimension coverage
**Marker:** `.claude/work/PROJ-NNN-name/.uat-validated`

### Gate 3: Simplify (`/simplify`)

Invoke `/simplify` reviewing the plan's proposed code changes.

Checks: over-engineering, unnecessary variables/functions/routes, one-use abstractions, AI code slop, missed reuse of existing utilities.

**Pass condition:** 0 Critical findings
**No marker** — advisory gate, Critical findings block

### Gate 4: Security Review (`/security-review`)

Invoke `/security-review` on the plan.

Checks: OWASP Top 10, injection, auth bypass, RBAC, XSS, webhook/payment security, sensitive data exposure.

**Pass condition:** 0 HIGH confidence findings
**No marker** — advisory gate, HIGH findings block

### Gate 5: Tenant & Client Impact (`/tc-impact`)

Invoke `/tc-impact` on the plan.

Checks: data isolation, config divergence per tenant, client-facing UX changes, breaking API changes, migration requirements per tenant.

**Pass condition:** No unmitigated HIGH impact items
**No marker** — advisory gate, unmitigated HIGH items block

### Gate 6: Plan Critique (`/critique-plan`)

Invoke `/critique-plan` on the plan. This is the 7-agent sequential critique loop.

Checks: code verification, completeness, spec alignment, deploy safety, cross-file consistency, REQ coverage matrix, consistency pass.

**Pass condition:** All issues resolved, user reviewed and confirmed
**No marker** — user confirmation required

## Output

After all 7 gates complete:

```
Review Gates for PROJ-NNN:

Gate 0 (check-errors):    PASS / FAIL — [N] rules checked, [N] RISKS, [N] VIOLATIONS
Gate 1 (verify-plan):     PASS / FAIL — [N] references checked, [N] failures, REQ coverage [X/Y], manifest [X/Y]
Gate 2 (uat-design):      PASS / FAIL — REQ quality [X/Y], 4-path [X/Y], dimensions [X/9]
Gate 3 (simplify):        PASS / FAIL — [N] Critical, [N] Moderate, [N] Minor
Gate 4 (security-review): PASS / FAIL — [N] HIGH, [N] MEDIUM, [N] LOW
Gate 5 (tc-impact):       PASS / FAIL — [N] HIGH, [N] MEDIUM
Gate 6 (critique-plan):   PASS / FAIL — [N] agents run, [N] issues resolved

Overall: [ALL PASS / N gates failed]
```

If all 7 pass: "All gates passed. Plan is ready for approval."
If any fail: list the specific failures and offer to fix them.

## Exit Condition

All 7 gates must pass before the plan's `**Status:**` can be set to `approved`.

Required markers (checked by ExitPlanMode hook):
1. `.uat-validated` exists (Gate 2)
2. `.api-verified` exists (Gate 1)
3. Critique complete with user review (Gate 6)
4. No blocking findings from Gates 3-5

## Hard Rules

1. All 7 gates run on every plan — no exceptions unless `--skip-critique` for trivial plans
2. Gate failures present the full picture — don't stop at the first failure
3. Markers are written by the individual skills, not by this orchestrator
4. User must confirm Gate 6 results — no auto-approval
5. Re-running gates after edits clears and re-checks markers
