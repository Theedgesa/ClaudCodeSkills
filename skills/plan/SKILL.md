---
name: plan
description: Write a structured implementation plan using the 7-section plan template. Requires an approved spec. Maps spec REQs to phases with Green/Orange/Red scoring at every phase gate. Use when user says "plan", "write a plan", "let's plan", or needs to plan implementation after a spec is approved.
---

# Plan — Structured Implementation Planning

Write an implementation plan for MyProject v3 that maps an approved spec's requirements to executable phases with Green/Orange/Red scoring at every phase gate.

**Announce at start:** "Using /plan to write a structured implementation plan."

---

## The Spec <-> Plan Boundary

| Spec (/spec) | Plan (this skill) |
|-------------|-------------------|
| Defines WHAT, WHY, WHAT COULD GO WRONG | Defines HOW, IN WHAT ORDER, HOW TO VERIFY, HOW TO DEPLOY |
| Owns: problem, design, REQs, risks, monitoring, rollback | Owns: phases, file changes, SQL, data flow, deployment |
| Scoring framework defined (REQs, dimensions, tiers) | Scoring framework executed (Green/Orange/Red per phase) |
| **Must be approved before this skill runs** | **Cannot start without approved spec** |

---

## Pre-flight

1. **Verify approved spec exists** — Read the spec file, confirm status = `approved`. If no approved spec → STOP. Run `/spec` first.
2. **Read the plan template** — `.claude/templates/plan-template.md` (source of truth)
3. **Read `past-errors.md`** — `.claude/rules/anti-patterns/past-errors.md`
4. **Read `.claude/rules/process/change-records.md`** — CR protocol for implementation
5. **Index all repositories** — `index_repository` for server, finance-service, frontends, core. Verify node counts non-zero.
6. **Verify ast-grep available** — `sg --version`
7. **Determine plan ID** — Use the spec's PROJ-NNN number

---

## Plan Document Structure (7 Sections)

**Location:** `.claude/work/PROJ-NNN-feature-name/plan.md`
**Template:** `.claude/templates/plan-template.md` (source of truth for section format)

Every plan MUST contain all 7 sections plus header. Missing sections = plan not approvable.

| # | Section | Purpose |
|---|---------|---------|
| 1 | Implementation Overview | Phase summary, expected REQ progression (Green/Orange/Red), execution strategy |
| 2 | Code Surface & Blast Radius | Change manifest (CREATE/EDIT/USE with verification), blast radius (callers + consumption), mutation constraints + environment |
| 3 | Database Schema & Migration | Migration SQL, verification queries, rollback SQL, data backfill |
| 4 | Cross-Service Data Flow | Variable-level traces per entry point, non-caller transformations |
| 5 | Implementation Phases | Phases with full REQ suite scoring at every gate (Green/Orange/Red), weakest element, CR checkpoint |
| 6 | E2E Verification | Browser protocol, connected workflow, cross-frontend, build verification |
| 7 | Ship & Deploy | PR flow, staging UAT, deploy checklist, production verification, documentation |

**Header includes:** Spec reference, scope summary, prerequisites checklist, evidence standard.

---

## Evidence Standard

**Execution output is the only acceptable evidence. Code reading is discovery, not verification.**

This applies to every section: pre-implementation verification (S2), migration verification (S3), phase gates (S5), E2E (S6), deploy (S7).

- **Accepted:** Bash output, browser snapshots, `sg` output, `search_graph` results, SQL execution results
- **Rejected:** "I read the code and confirmed", "verified by inspection", "looks correct", any prose without execution proof. Subagent claims without execution output also rejected.

---

## Writing Process

### Step 1: Header & Prerequisites

1. **Link to approved spec** — verify status = `approved`
2. **Extract spec summary** — work type, complexity tier, total REQs, dimensions, exemptions
3. **Calculate scope** — count files, layers, environments from the plan's upcoming analysis
4. **Verify prerequisites** — spec approved, past-errors read, repos indexed

### Step 2: Code Surface & Blast Radius (Section 2)

1. **Build Change Manifest** — list everything the plan touches (files, functions, endpoints, tables, columns, triggers, env vars). Each row verified via AST/SQL with execution output.
   - **CREATE items:** verify they DON'T already exist
   - **EDIT items:** verify they DO exist and current state matches assumptions
   - **USE items:** verify they exist with expected interface
2. **Map blast radius** — for every modified function: current signature, all callers via `trace_call_path`, how each caller consumes the return value, risk level
3. **Document middleware chains** — for every modified route
4. **Query mutation constraints** — full constraint map for every INSERT/UPDATE target
5. **Verify environment values** — env var VALUES (not just existence) per environment
6. **Scan file hazards** — module-scope SDKs, hardcoded URLs in modified files

### Step 3: Database Migration (Section 3)

1. **Write migration SQL** — BEGIN/COMMIT, idempotent, follow supabase-patterns.md
2. **Respect data classification** — new tables follow spec S2.6 tenant scope
3. **Write verification queries** — prove migration applied correctly
4. **Write rollback SQL** — test: migrate → rollback → migrate again
5. **Plan data backfill** — if adding NOT NULL columns to populated tables

### Step 4: Cross-Service Data Flow (Section 4)

1. **One trace per entry point** — if feature has multiple paths, each gets its own trace
2. **Mark required parameters** — tenantId, userId at every hop. Missing parameter = visible gap.
3. **Document non-caller transformations** — internal `.map()`, response builders, spread operators where fields get added or dropped

### Step 5: Implementation Phases (Section 5)

1. **Design phases** — each phase is a testable increment
2. **Map files to phases** — from Change Manifest
3. **Add error handling per phase** — structured logging table
4. **Design phase gates** — full REQ suite table (ALL REQs, every phase)
   - Green/Orange/Red status with execution evidence
   - Regression detection (Green→Red = blocked)
   - Weakest element identification + additional test
   - CR checkpoint

### Step 6: E2E & Deploy (Sections 6-7)

1. **Define browser protocol** — single headed session, MCP first, Playwright after
2. **Map connected workflow** — sequential walk through spec's Success Criteria
3. **Cross-frontend checks** — if applicable
4. **Build verification** — both frontends + server
5. **PR flow** — architecture doc update gate, staging UAT, production deploy
6. **Deploy checklist** — pre-deploy env verification, deploy execution, PM2 freshness check
7. **Production verification** — spec's monitoring queries with timing/thresholds

### Step 7: Implementation Overview (Section 1)

Write this LAST — after all other sections. It summarizes:
1. Phase summary table
2. Expected REQ progression (forecast Green/Orange/Red after each phase)
3. Execution strategy (2-3 sentences: why this phase order, critical path, risk concentration)

### Step 8: Self-Review

Before presenting to user, verify against the automated checklist in the template's Approval section.

### Step 9: Create Worktree & Branch

After plan is approved:

1. **Branch base check:**
   ```bash
   git fetch origin staging main
   AHEAD=$(git rev-list --count main..origin/staging)
   echo "Staging ahead of main by: $AHEAD commits"
   ```
   If `$AHEAD > 0`, branch from `origin/staging`. Otherwise branch from `origin/main`.

2. **Create worktree:**
   ```bash
   BRANCH="feature/PROJ-NNN-name"
   BASE="origin/staging"  # or origin/main per step 1
   git worktree add .worktrees/PROJ-NNN-name -b "$BRANCH" "$BASE"
   ```

3. **Env setup, install deps, verify quality gate** — per existing worktree protocol.

### Step 10: Update Roadmap

1. Find or create entry in `.claude/work/roadmap.yaml`
2. Set `stage: planned`, `plan:` path, `branch:`, `worktree:`
3. Run monitoring scan for entries past review date

### Step 11: Present to User

```
Plan complete: `.claude/work/PROJ-NNN-name/plan.md`
Spec: [path]

Sections: 7/7
Phases: [N]
REQs mapped: [total] across [N] dimensions
Expected final state: [total]/[total] Green, 0 Orange, 0 Red

Ready to approve and /implement.
```

---

## Phase Gate Scoring (Green / Orange / Red)

The core innovation: ALL REQs from the spec run at EVERY phase gate.

- **Green** — passes with T3+ execution output. Evidence must meet spec's Evidence Quality rules (boundary crossing, independence, business outcome).
- **Orange** — code/infrastructure to test this REQ doesn't exist yet. Must state which future phase turns it Green. Orange is NOT a deferral — the code path to test literally doesn't exist yet.
- **Red** — fails, or CAN be tested but hasn't been. Blocks the phase gate. A testable-but-untested REQ = Red, not Orange.

**Gate pass criteria:** Zero Red. Zero regressions (Green→Red). All testable high-effort (H) REQs executed.

**Regression detection:** Any REQ that was Green in a previous phase and is now Red = phase gate blocked. Fix before proceeding.

---

## Hard Rules

1. Plan location: `.claude/work/PROJ-NNN-feature-name/plan.md` — always
2. Template: `.claude/templates/plan-template.md` — single source of truth
3. 7 sections — all mandatory, no exceptions
4. **Approved spec required** — plan cannot be written without one
5. All evidence execution-based — no prose descriptions accepted
6. Full REQ suite at every phase gate — not just "this phase's" REQs
7. Zero Red at every gate — no exceptions
8. Regression detection — Green→Red = blocked
9. CR protocol per `.claude/rules/process/change-records.md` — checked at every phase gate
10. grep/rg banned — AST tools only for code verification
11. Architecture docs updated before PR — gate in S7.1
12. Status transitions: `draft` → `approved` (only after user reviews)
