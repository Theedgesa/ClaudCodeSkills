---
name: critique-plan
description: 7-agent sequential critique of implementation plans. Code verification, plan critique, REQ coverage, and consistency pass. Use when a plan has 2+ phases, touches frontend, or involves risky operations like rebases, migrations, or payment code. Also invoked as Gate 6 of /review-gates.
---

# Critique Plan — 7-Agent Sequential Critique Loop

Run a structured multi-agent critique of an implementation plan before approving it.

**Announce at start:** "Running /critique-plan on `<plan-path>`."

## When to Use

- Any plan with 2+ phases
- Plans touching frontend code
- Plans involving database migrations
- Plans with merge/rebase conflict resolution
- Plans affecting payment or auth flows
- When user says "critique plan", "review plan", or "/critique-plan"
- Automatically invoked as Gate 6 of `/review-gates`

## Input

Accepts one argument: the path to the plan file.

- If no argument provided, look for the most recently written plan in `.claude/work/*/plan.md`
- If multiple candidates, ask which one

## Process

### Step 1: Load Context

Read the full plan file. Also load:
- The spec referenced in the plan header — extract ALL REQs from spec S6.1 and all Success Criteria from spec S3
- `.claude/rules/anti-patterns/past-errors.md`
- `.claude/templates/plan-template.md` for section compliance

### Step 2: Critique Baseline

Extract and present the Critique Baseline to the user for confirmation:

```
Critique Baseline for PROJ-NNN:
- Objective: [from plan]
- Spec REQs: [count] REQs across [count] dimensions
- Success Criteria: [count] items (from spec S3)
- Phases: [count] phases
- Scope: [files/services touched — from plan S2.1 Change Manifest]
- Expected final state: all REQs Green (from plan S1.2)
```

Save to `.claude/work/PROJ-NNN-name/critique-baseline.md`.

Wait for user confirmation before proceeding.

### Step 3: 7-Agent Sequential Critique

Dispatch agents sequentially. Each agent receives the output of previous agents.

#### Agent 0: Code Verifier

Dispatch an Explore agent to read all referenced source files and verify:
- Hardcoded values match reality
- Environment variable names exist in .env files
- Algorithm assumptions match actual implementations
- FK dependencies exist in the database
- Frontend component assumptions match actual components
- Env file audit (all .env* files for referenced vars)

Save to `.claude/work/PROJ-NNN-name/critique-round-0-code-verification.md`

**If Critical findings: STOP and present to user before continuing.**

#### Agent 1: Plan Critic

Dispatch a Plan agent with baseline + Agent 0 findings. Check:

| Category | What to Look For |
|----------|------------------|
| Completeness | TODOs, placeholders, incomplete tasks, missing steps |
| Spec Alignment | Plan covers all spec REQs — every REQ appears in at least one phase gate |
| Section Compliance | All 7 mandatory sections present per plan template (S1-S7) |
| Change Manifest (S2.1) | Every spec design file covered, all rows have verification results |
| Blast Radius (S2.2) | Every modified function has callers listed, HIGH-risk callers have Regression REQs |
| Deploy Safety | Migration/deploy steps properly sequenced (plan S3 before S5 phases) |
| Regression Risk | Production hotfixes and existing behavior preserved |
| Cross-File Consistency | Function signatures, types, column names match across files |
| REQ Gate Tables (S5) | Every phase has a full REQ suite table with Green/Orange/Red scoring |
| REQ Progression (S1.2) | Expected progression is consistent with phase gates |
| Edge Cases | What could go wrong that isn't covered? (cross-reference spec S5 Risk & Adversarial) |

Additional review angles (apply if relevant):
- **Rebase/merge plans:** Are conflict resolutions correct? Could feature code be accidentally dropped?
- **Payment/auth plans:** Is the critical path fully tested? Any silent failure modes?
- **Multi-service plans:** Do inter-service contracts match? Are timeouts handled?
- **Frontend plans:** Are env files audited? Build verification included?
- **Migration plans:** Is rollback tested (plan S3.3)? Are constraints verified (plan S2.3)?
- **Plans with code blocks calling services:** Verify every `serviceName.methodName()` against actual source, NOT architecture docs.
- **Plans adding fields to API responses:** Verify field survives any `.map()` AND frontend type includes it.

Classify findings: Critical / Major / Minor / Advisory.

Save to `.claude/work/PROJ-NNN-name/critique-round-0-agent-1.md`

#### Agent 2: Plan Rewriter

Address all Critical and Major issues from Agent 1. Edit the plan directly.

Save summary to `.claude/work/PROJ-NNN-name/critique-round-1-plan.md`

#### Agent 3: REQ & Verification Critic

Review the rewritten plan's REQ coverage and verification quality:

**REQ Coverage:**
- Every spec REQ (from S6.1) appears in every phase gate table in plan S5
- No REQ is missing from all phase gates
- No REQ is Orange in the final phase (must be Green by end)
- High-effort (H) REQs have proportional verification methods
- REQ evidence descriptions are specific (not vague "verified" / "confirmed")

**Verification Quality:**
- Every Green REQ in the plan specifies an executable verification method (not prose)
- Evidence tiers are appropriate (T3+ for functional/integration REQs)
- Verification methods are independent of the code being tested
- Expected outcomes are specific (exact values, not "works correctly")
- Business outcomes (table.field values) present, not just API signals (200 OK)

**4-Path Coverage (from spec S3 Success Criteria):**
- Each SC has REQs covering: happy path, failure path, boundary path, existing-data path
- Missing paths flagged

**E2E Verification (plan S6):**
- Connected workflow covers all spec Success Criteria as a sequential journey
- Assertions are specific (exact values)
- Cross-frontend checks present if feature spans reception + storefront
- Build verification for all frontends

Classify gaps: High / Medium / Low severity.
**Missing REQ from all phase gates = High. Orange in final phase = High. Vague evidence = Medium.**

Save to `.claude/work/PROJ-NNN-name/critique-round-1-req-coverage.md`

#### Agent 4: Plan Rewriter + REQ Alignment

Integrate all missing REQs and verification improvements from Agent 3. Produce a REQ Coverage Matrix:

```markdown
## REQ Coverage Matrix

| REQ ID | Dimension | Effort | Phase 1 | Phase 2 | Phase 3 | Final Status |
|--------|-----------|--------|---------|---------|---------|-------------|
| REQ-001 | Functional | M | Orange | Green | Green | Green |
| REQ-002 | Data Integrity | M | Green | Green | Green | Green |
| REQ-003 | Security | H | Orange | Orange | Green | Green |
```

All REQs must show Green in the final phase column. Any Orange or Red in the final column = gap to fix.

Save to `.claude/work/PROJ-NNN-name/req-coverage-matrix.md`

#### Agent 5: REQ Coverage Validator

Second pass confirming all gaps from Agent 3 are addressed:
- Re-check every gap flagged by Agent 3
- Verify the coverage matrix has no Orange/Red in the final phase column
- Verify high-effort REQs have adequate verification methods
- Confirm evidence specificity on all updated REQs
- Verify Change Manifest (plan S2.1) covers all files from spec S4 design

If gaps remain: list them explicitly. Do NOT approve.

Save to `.claude/work/PROJ-NNN-name/critique-round-2-req-validation.md`

#### Agent 6: Final Revision

Consistency pass on the complete plan:
- Sequential numbering (no gaps, no duplicates)
- Cross-reference check: all section references point to valid sections (S1-S7 for plan, S1-S10 for spec)
- REQ IDs in phase gates match spec S6.1 REQ IDs exactly
- Phase dependencies are achievable in order
- Expected REQ Progression (plan S1.2) matches actual phase gate tables
- Change Manifest (plan S2.1) Action types consistent with verification results
- No orphaned artifacts from previous critique rounds

Save to `.claude/work/PROJ-NNN-name/critique-round-final.md`

### Step 4: Present Results

```
Critique complete for PROJ-NNN:

Agent 0 (Code Verifier): [N] findings ([Critical/Major/Minor])
Agent 1 (Plan Critic): [N] issues ([Critical/Major/Minor/Advisory])
Agent 2 (Plan Rewrite): [N] issues addressed
Agent 3 (REQ Critic): [N] gaps ([High/Medium/Low])
Agent 4 (REQ Rewrite): [N] REQs updated, coverage matrix produced
Agent 5 (REQ Validator): [PASS/FAIL] — [remaining gaps if any]
Agent 6 (Final Revision): [PASS/FAIL] — [consistency issues if any]

Artifacts saved to .claude/work/PROJ-NNN-name/:
- critique-baseline.md
- critique-round-0-code-verification.md
- critique-round-0-agent-1.md
- critique-round-1-plan.md
- critique-round-1-req-coverage.md
- req-coverage-matrix.md
- critique-round-2-req-validation.md
- critique-round-final.md
```

**Do NOT auto-approve** — present results to user for review.

## Calibration

Only flag issues that would cause real problems during implementation. An implementer building the wrong thing or getting stuck is an issue. Minor wording, stylistic preferences, and "nice to have" suggestions are not.

## Hard Rules

1. All 7 agents run sequentially — each receives prior agent output
2. Critical findings from Agent 0 STOP the loop until user reviews
3. Agent 5 must confirm all Agent 3 gaps are resolved — no silent approvals
4. Do NOT auto-approve — user must review and confirm
5. All artifacts saved to `.claude/work/PROJ-NNN-name/`
6. Verify function calls against actual source code, NOT architecture docs (they drift)
7. Response shape survival must be checked for any new API fields
8. Every spec REQ must appear in every phase gate table — orphaned REQs are failures
9. No REQ may be Orange in the final phase — all must resolve to Green
10. Change Manifest must cover all files referenced in spec design
