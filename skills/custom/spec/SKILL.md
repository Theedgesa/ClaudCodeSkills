---
name: spec
description: Write a structured spec using the 10-section spec template with scoring framework, adversarial analysis, and evidence-backed verification. Use when user says "spec", "write a spec", "let's spec this", or needs to define requirements before planning. Must be approved before /plan can begin.
---

# Spec — Structured Specification

Write a specification for MyProject v3 using the 10-section template. The spec defines WHAT, WHY, and WHAT COULD GO WRONG. The plan (written separately via `/plan`) defines HOW, IN WHAT ORDER, and HOW TO VERIFY.

**Announce at start:** "Using /spec to write a structured specification."

---

## The Spec <-> Plan Boundary

| Spec (this skill) | Plan (/plan) |
|-------------------|-------------|
| Defines the problem with evidence | References the spec |
| Maps current state via AST tools | Maps what will change |
| Defines success criteria with 4-path coverage | Maps REQs to phases |
| Designs the solution with before/after | Implements the solution phase by phase |
| Identifies risks and adversarial scenarios | Runs full REQ suite at every phase gate |
| Defines monitoring and kill switches | Executes deploy with freshness verification |
| Defines the scoring framework (REQs, dimensions, tiers) | Scores Green/Orange/Red at each phase gate |
| **EXIT GATE: Spec must be approved by user** | **ENTRY GATE: Approved spec must exist** |

---

## Pre-flight

1. **Read the spec template** — `.claude/templates/spec-template.md` (source of truth)
2. **Read `past-errors.md`** — `.claude/rules/anti-patterns/past-errors.md`
3. **Read relevant architecture docs** — `.claude/rules/architecture/` for the areas being touched
4. **Index all repositories** — `index_repository` for server, finance-service, frontends, core. Verify node counts non-zero.
5. **Verify ast-grep available** — `sg --version`
6. **Determine spec ID** — Next PROJ-NNN number (check `.claude/work/.next-ppv3`)

---

## Spec Document Structure (10 Sections)

**Location:** `docs/specs/YYYY-MM-DD-feature-name.md`
**Template:** `.claude/templates/spec-template.md` (source of truth for section format)

Every spec MUST contain all 10 sections. Missing sections = spec not approvable.

| # | Section | Purpose |
|---|---------|---------|
| 1 | Problem | Evidence-backed justification with work type (8 types) |
| 2 | Current State | Code surface via AST (no grep), data state via SQL, architecture doc check, past error check, risk scoring, data classification |
| 3 | Success Criteria | 4-element quality standard (actor/action/result/negative proof), 4-path coverage per criterion |
| 4 | Design | Before/after architecture, design decisions with alternatives, scope boundary, external API verification, feasibility check via AST |
| 5 | Risk & Adversarial Analysis | 16 categories: invariant + scenario + code trace + assumptions + REQ per category |
| 6 | Requirements & Scoring Framework | REQs with evidence tiers (T1-T5), effort tags (L/M/H), 3 rule groups, structural minimums, 9 dimensions at 100% |
| 7 | Monitoring & Observability | Leading + lagging indicators, failure detection linked to kill switches, post-deploy queries |
| 8 | Performance & Load | Metrics with degradation behavior, mandatory upper bounds, N/A requires evidence |
| 9 | Dependencies & Scope Decomposition | 4 dependency types, downstream includes CI/infra, weighted complexity (decompose if >12) |
| 10 | Rollback Strategy | Per-layer, partial failure, urgency, irreversible effects, collateral damage |

---

## Writing Process

### Step 1: Problem & Current State (Sections 1-2)

1. **Identify work type** — Bug fix / New feature / Refactor / Infrastructure / Integration / Migration / Compliance / Security
2. **Gather evidence** — Error counts, row counts, query results, log output. Every claim must cite data.
3. **Map code surface via AST** — `search_graph`, `trace_call_path`, `sg` patterns. No grep.
4. **Verify data state** — Run SQL queries, paste actual output.
5. **Check architecture docs** — Read each relevant doc, state constraints, verify compliance.
6. **Check past errors** — Read `past-errors.md`, list every relevant error.
7. **Score codebase risk** — Count incidents per area from `past-errors.md`, derive risk levels and minimum REQ counts.
8. **Classify data** — Tenant scope and sensitivity per table touched.

### Step 2: Success Criteria & Design (Sections 3-4)

1. **Define success criteria** — Every criterion must have: actor, action, observable result (exact tables/fields/values), negative proof (what must NOT happen).
2. **Map 4-path coverage** — Each SC gets: happy-path REQ, failure-path REQ, boundary REQ, existing-data REQ.
3. **Design before/after architecture** — Current state diagram vs proposed state diagram with delta table.
4. **Document design decisions** — Every non-obvious decision with alternatives and rationale.
5. **Define scope boundary** — Included and excluded with justification per exclusion.
6. **Verify external APIs** — Read actual API docs, verify assumptions against documentation.
7. **Check design feasibility** — Verify every proposed function call via `search_graph`/`sg`.

### Step 3: Risk Analysis & Requirements (Sections 5-6)

1. **Walk through all 16 risk categories** — For each: state invariant, describe adversarial scenario, trace code path with file:line, list assumptions, create REQ.
2. **Write all REQs** — ID, dimension, tier, effort, assertion, verification method, expected output (business outcome, not API signal).
3. **Verify structural minimums** — API endpoint → Security REQ, DB mutation → Data Integrity REQ, code with callers → Regression REQ.
4. **Verify 4-path coverage** — Every SC has happy + failure + boundary + existing-data REQs.
5. **Check for orphans** — No SC without REQs, no REQs without SC parent.

### Step 4: Monitoring, Performance, Dependencies, Rollback (Sections 7-10)

1. **Define monitoring** — Leading AND lagging indicators. Every failure mode from Section 5 → detection query → kill switch.
2. **Define upper bounds** — Every resource-consuming operation has a max rate/count and degradation behavior.
3. **Map dependencies** — Upstream (4 types), downstream (includes CI/infra), scope decomposition (weighted complexity).
4. **Define rollback** — Per-layer undo, partial failure recovery, urgency classification, irreversible effects, collateral damage.

### Step 5: Self-Review

Before presenting to user, verify against the automated checklist in the template's Approval section. The hook will catch structural issues; focus on content quality.

### Step 6: Present to User

```
Spec complete: `docs/specs/YYYY-MM-DD-feature-name.md`

Sections: 10/10
REQs: [count] across [N] dimensions
Risk categories: [N]/16 applicable
Complexity score: [N] → Tier: [Micro/Standard/High-Risk]

Ready for review. Please check the 7 user judgment items in the Approval section.
```

---

## Evidence Standard

**Execution output is the only acceptable evidence throughout this spec.**

- Code surface: AST tool output (`search_graph`, `trace_call_path`, `sg`). No grep.
- Data state: SQL query output pasted from execution.
- Architecture compliance: File:line references from Read tool.
- Risk analysis: Code path traces with file:line references.
- Feasibility checks: `sg` or `search_graph` output showing method definitions.

Code reading is discovery. Execution output is evidence. They are not interchangeable.

---

## Hard Rules

1. Spec location: `docs/specs/YYYY-MM-DD-feature-name.md` — always
2. Template: `.claude/templates/spec-template.md` — single source of truth
3. 10 sections — all mandatory, no exceptions
4. All evidence execution-based — no "I read the code and confirmed"
5. All REQs have T3+ verification methods with exact expected output
6. All success criteria have 4-path coverage (happy/failure/boundary/existing-data)
7. All risk categories answered or explicitly N/A with evidence
8. Complexity score calculated — decompose if > 12
9. grep/rg banned — AST tools only for code verification
10. Status transitions: `draft` → `approved` (only after user reviews)
11. **Spec must be approved before `/plan` can begin**
