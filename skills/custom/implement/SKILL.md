---
name: implement
description: Phase-by-phase implementation with REQ-based Green/Orange/Red scoring at every phase gate. Use when user says "implement", "execute plan", or wants to implement an approved plan.
---

# Implement — Phase-by-Phase Execution with REQ Scoring

You are executing the implementation workflow for MyProject v3. This skill guides you through phase-by-phase implementation with Green/Orange/Red REQ gates, Change Record protocol, and mandatory task tracking.

## Pre-flight

1. **Check for plan:** The user must provide a plan path or you must identify the current plan at `.claude/work/PROJ-*/plan.md`
2. **Validate plan:** Run plan validation script to ensure plan is complete and approved
3. **Check approval:** Plan must have `**Status:** approved` before implementation
4. **Critical review:** Review the plan critically — identify gaps, missing dependencies, unclear instructions, or risky assumptions. If concerns exist, raise them with the user before proceeding. Do not start implementation with unresolved questions.
5. **REQ coverage validation:** Confirm `.uat-validated` marker exists (from /uat-design during planning). If missing, run `/uat-design` now and fix gaps before proceeding.
6. **Load spec REQs:** Read the spec referenced in the plan header. Extract the full REQ table from spec S6.1. These REQs are the scoring framework for every phase gate — the plan does not redefine them.
7. **Review phases:** Understand the implementation phases from the plan
8. **Verify workspace:** The worktree should already exist from `/plan` step 5.5. **Never start implementation on main or master branch.**
   - **Check worktree exists:**
     ```bash
     WT=".worktrees/PROJ-NNN-name"
     [ -d "$WT" ] && echo "Worktree exists" || echo "MISSING — run worktree setup"
     ```
   - **If worktree missing** (plan was written in a previous session or before this step was added), create it now:
     ```bash
     git fetch origin staging main
     AHEAD=$(git rev-list --count main..origin/staging)
     BASE=$( [ "$AHEAD" -gt 0 ] && echo "origin/staging" || echo "origin/main" )
     git worktree add "$WT" -b feature/PROJ-NNN-name "$BASE"
     ```
   - **Verify env symlinks (MANDATORY every time):** Symlinks can break between sessions (main repo moved, .env files recreated).
     ```bash
     MAIN_REPO="$(git rev-parse --show-toplevel)"
     for f in server/.env server/.env.staging finance-service/.env; do
       [ -L "$WT/$f" ] && file "$WT/$f" | grep -q "broken" && echo "BROKEN: $WT/$f — re-symlink with absolute path" && ln -sf "$MAIN_REPO/$( [ "$f" = "finance-service/.env" ] && echo "server/.env" || echo "$f" )" "$WT/$f"
     done
     ```
     Past-errors rule #49: worktree symlinks must use absolute paths.
   - **Verify deps installed (symlink ALL node_modules):** Worktrees share no `node_modules`. Quality gate (ESLint) fails if ANY workspace node_modules is missing. Symlink from main repo using absolute paths:
     ```bash
     for d in node_modules store-website/node_modules reception-website/node_modules; do
       [ -e "$WT/$d" ] || ln -s "$MAIN_REPO/$d" "$WT/$d"
     done
     [ -d "$WT/server/node_modules" ] || (cd "$WT/server" && npm ci)
     [ -d "$WT/finance-service/node_modules" ] || (cd "$WT/finance-service" && npm ci)
     ```
     Incident: PROJ-168 — missing store-website/node_modules caused ESLint circular structure error.
9. **Activate plan in BOTH main repo and worktree:** The pre-tool-guard hook checks `.active` relative to the file being edited.
   **CRITICAL:** `.active` must contain ONLY the directory name (e.g., `PROJ-NNN-name`), NOT the full path to plan.md.
   ```bash
   echo "PROJ-NNN-name" > .claude/work/.active
   mkdir -p "$WT/.claude/work/PROJ-NNN-name"
   cp .claude/work/PROJ-NNN-name/plan.md "$WT/.claude/work/PROJ-NNN-name/plan.md"
   echo "PROJ-NNN-name" > "$WT/.claude/work/.active"
   ```
   Incident: PROJ-168/170 — `.active` path bugs blocked all edits.
10. **Create phase tasks (MANDATORY):** See Task Management section below. Code edits are BLOCKED until this is done.

## Pre-flight Step 3.5: Update Roadmap

After checking approval and before setting up workspace:

1. Read `.claude/work/roadmap.yaml`
2. Find the entry matching the current PROJ-NNN
3. Set `stage: in-progress`
4. Set `branch:` to the current branch name
5. Write updated YAML back to `roadmap.yaml`
6. Run the **Monitoring Scan** (see below)

### Monitoring Scan (runs after roadmap state change)

1. Read `.claude/work/roadmap.yaml`
2. Filter entries where `stage: monitoring` AND `review_after` date is today or earlier
3. If none found: continue silently
4. If found: display list to user:
   ```
   Roadmap updated.

   N items awaiting production verification:
   - PROJ-NNN (title) — review by: YYYY-MM-DD — "verify criteria"
   ...

   Check logs for any of these now? (y/list numbers/skip)
   ```
5. Wait for user response
6. If user picks entries to check:
   a. Read the `verify` field for each
   b. Run the SQL/log queries specified
   c. If all pass: set `stage: closed`, `evidence:` query results, `closed_at:` today
   d. If any fail: report findings, leave at `monitoring`

---

## Task Management (Hook-Enforced)

After `/implement` loads, the PostToolUse hook writes `.phases-required`. Code edits are BLOCKED by the PreToolUse hook until `.phases-created` exists. This forces task creation before any implementation.

### Task Creation Pattern

For each phase in the plan, create ONE task with embedded REQ placeholders from the spec:

```
TaskCreate("Phase N: [phase name]", description:
  "Objective: [from plan]
  Files: [list from plan]

  REQ Gate (all spec REQs — Green/Orange/Red):
  - REQ-001 [Functional/M]: [description] → PENDING
  - REQ-002 [Data Integrity/M]: [description] → PENDING
  - REQ-003 [Security/H]: [description] → PENDING
  ...
  (list ALL REQs from spec S6.1, every phase)")
```

After creating ALL phase tasks, write the marker:
```
Write to: .claude/work/PROJ-NNN-name/.phases-created
Content: "created YYYY-MM-DD\nphases=N\ntasks=[task IDs]\nreqs=[total REQ count]"
```

### Task Lifecycle

| Action | Task Status | Description Update |
|--------|-------------|-------------------|
| Phase starts | `in_progress` | No change |
| REQ verified | `in_progress` | Replace PENDING with Green/Orange/Red + evidence |
| All REQs scored | `in_progress` | All PENDING replaced with status + evidence |
| Gate passes | `completed` | Report.md contains phase gate verdict |

**Gate chain (sequential, each step blocks the next):**
1. All REQs scored (PENDING → Green/Orange/Red with evidence)
2. Zero Red, zero regressions, high-effort REQs executed
3. CR checkpoint completed
4. Weakest element identified and tested
5. Report.md written/updated with phase results + gate verdict
6. TaskUpdate to `completed`

**Hook enforcement:** TaskUpdate to `completed` is BLOCKED if description still contains "PENDING". You must replace every PENDING with actual status and evidence.

### Task Granularity

- **Phase-level tasks (3-7 total)** — NOT per-REQ tasks (too noisy)
- Each phase task embeds the full REQ suite in its description
- Evidence replaces PENDING inline as REQs are verified

---

## Evidence Standard

**Execution output is the only acceptable evidence. Code reading is discovery, not verification.**

This standard applies everywhere — pre-implementation verification, phase gates, E2E, deploy.

**Accepted:** Output pasted from tool execution — Bash (curl response, SQL result, server output), browser snapshot (MCP `browser_snapshot`), ast-grep (`sg` output), codebase-memory (`search_graph`/`trace_call_path` results), Supabase MCP (`execute_sql` result).

**Rejected:** "I read the code and confirmed", "the function handles this", "verified by inspection", "verified", "confirmed", "looks correct", "handles this", "by inspection", "as expected", any prose description without execution proof. Subagent claims without pasted execution output are also rejected.

**T3+ means** the test crosses a real process boundary — DB query after operation, auth validation against actual service, or data persisting across restart. Full tier definitions (T1-T5) in spec S6.1.

---

## Green / Orange / Red Scoring

Every phase gate runs the FULL REQ suite from the spec — every REQ, every phase.

| Status | Meaning | Rule |
|--------|---------|------|
| **Green** | Passes with T3+ execution output | Evidence must meet spec's quality rules: boundary crossing, independence, business outcome, red/green (test fails before change, passes after) |
| **Orange** | Code/infrastructure to test doesn't exist yet | Must state WHICH future phase turns it Green. Orange is not a deferral — the code path to test literally doesn't exist yet |
| **Red** | Fails, or CAN be tested but hasn't been | Blocks the phase gate. Testable-but-untested = Red, not Orange |

**Regression detection:** Any REQ that was Green in a previous phase and is now Red = **regression**. Phase gate blocked. Fix the regression before proceeding.

**Gate pass criteria:** Zero Red. Zero regressions (Green→Red). All testable high-effort (H) REQs executed.

---

## When to Stop and Ask

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails repeatedly, instruction unclear)
- Plan has critical gaps preventing progress
- You don't understand an instruction
- Verification fails more than twice on the same check
- A deviation from the plan would change user-facing behavior

**Ask for clarification rather than guessing. Don't force through blockers.**

## When to Revisit the Plan

**Return to Pre-flight (Critical Review) when:**
- User updates the plan based on your feedback
- Fundamental approach needs rethinking after hitting a wall
- New information invalidates earlier assumptions

---

## Phase Execution Pattern

For each phase in the plan:

### 1. Phase Preparation — Load Context

Read these BEFORE touching any code. Every time. No shortcuts.

- **Plan** — Read the full phase section: objective, files to modify, specific changes, REQ gate table
- **Spec REQs** — Re-read the full REQ table from spec S6.1 to confirm understanding
- **Check-errors** — Run `/check-errors` against this phase's files and domain. If any RISK or VIOLATION is found, address it before writing code.
- **Past-errors** — Read `.claude/rules/anti-patterns/past-errors.md`. Identify which rules apply:
  - Payment code? → Rule #17 (test one order per payment method)
  - Frontend? → Rule #20 (test through frontend), Rule #23 (audit .env files)
  - Auth/profiles? → Rule #2 (no guest profiles)
  - DB migration? → Rule #7 (BEGIN/COMMIT), Rule #15 (check is_nullable)
  - Existing flows? → Rule #16 (trace data through every transformation)
- **Architecture rule** — Load the relevant `.claude/rules/architecture/` file for the domain
- **Files to modify or call into** — Read COMPLETE files you will modify AND files you will `require()` and invoke methods on
- **Cross-stack** — If phase touches server + frontend: run codebase-memory `trace_call_path`
- **Blast radius verification** — For every function you will call: use `sg` to verify it exists with the expected signature. For every function you modify: use `trace_call_path` to find callers, verify your changes don't break their assumptions.
- **Method existence check (MANDATORY)** — For every `service.method()` call you write or modify, run `sg -p 'async method($$$) { $$$ }' <service-file> --lang js`. If the method doesn't exist, implement it or remove the call. **Never wrap a call to a non-existent method in try/catch with a fallback** — this creates a silent failure. Incident: PROJ-082.
- Mark phase task as `in_progress` (TaskUpdate)
- If phase has 2+ independent tasks: consider `superpowers:subagent-driven-development` for parallel execution

**Subagent post-dispatch verification (MANDATORY if agents were used):**

After ALL agents complete and BEFORE committing:

1. **Caller-match scan:** Run `node scripts/tenant-caller-check.mjs` (or equivalent). Agents that add params to service methods don't update callers in other agents' files.
2. **Ground truth query scan:** Run `node scripts/tenant-query-check.mjs` (or equivalent) if DB queries were modified.
3. **Targeted endpoint test:** For every file an agent modified, identify the API endpoint that exercises it. Start the server (`PORT=5555 node server/server.js`), hit that endpoint with an auth token, verify non-500 response.
4. **Fix gaps between agents:** If scans find mismatches, fix them. Re-run scans. Only proceed to commit when all 3 checks pass.

Do NOT trust agent-reported results. Verify → fix → re-verify → commit.
Past-errors #46: PROJ-MT5 agents created 86 caller mismatches, 163 Supabase chain bugs.

**Announce before writing any code:**
```
PHASE: [N] — [Name]
OBJECTIVE: [from plan]
FILES: [path] ([create/edit] — [what changes])
PAST-ERRORS RELEVANT: [rule numbers and why]
CHECK-ERRORS: [CLEAR / N RISKS — list]
```

### 2. Implementation

**Follow existing patterns:**
- New endpoint? Copy structure of adjacent endpoint in same file
- New service method? Match signature style of sibling methods
- New route? Follow same middleware chain as neighboring routes

**Hard rules:**
- NEVER create a new file if an existing file covers this domain
- NEVER add a dependency without checking if an existing util does it
- NEVER invent a new pattern when the codebase has an established one
- NEVER hardcode locations, categories, role names, or config values
- NEVER use `console.log` in new code — use structured logging
- NEVER skip RBAC middleware on new routes

**Framework constraints (inject into agent prompts when dispatching):**

| Framework | Constraint | Wrong | Right |
|-----------|-----------|-------|-------|
| Supabase | `.eq()` requires `.select()` first | `.from('t').eq('col', v)` | `.from('t').select('*').eq('col', v)` |
| Supabase | `.update()` then `.eq()` for WHERE | `.from('t').eq('id', v).update({})` | `.from('t').update({}).eq('id', v)` |
| Supabase | Always destructure `{ data, error }` | `const data = await query` | `const { data, error } = await query` |
| Supabase | `.single()` throws on 0 rows | Use when row MUST exist | Use `.maybeSingle()` when row may not exist |
| Express | Middleware chain must be preserved | Rewrite handler, drop `isAuthenticated` | Copy middleware chain from original route |
| Express | `getTenantId(req)` throws if missing | Use in middleware (tenant may not resolve) | Use `req.tenant?.id` in middleware only |
| Node/CJS | `require()` resolves at load time | Call method on module that may not export it | `sg` the file for the method before calling |

Past-errors #48: PROJ-MT5 agents placed `.eq()` after `.from()` 163 times without the chain rule.

**DB migration (if phase includes SQL):**
Follow the Supabase migration workflow: staging-first, BEGIN/COMMIT, constraint verification, rollback SQL, post-migration evidence. Run SELECT to verify column/table exists. Test FK constraints.

- Document any deviations from the plan
- **FK blast radius (if phase adds FOREIGN KEY):** After running migration SQL, use `sg` to find ALL existing queries joining the two tables. If multiple FKs exist between the same table pair, EVERY join must use explicit `!fk_constraint_name` hint. Past-errors rule #37.

**Backfill / one-off script (if phase creates a script with hardcoded ID lists):**
- Re-run the extraction query at execution time (not plan time). Diff against the hardcoded list. If new records exist, add them before executing.
- Incident: PROJ-167 — 41-UUID list went stale between plan-write and deploy. Past-errors rule #49.

**Build check after every file change:**
- Backend: restart dev server, verify starts without crash
- Frontend: `npx tsc --noEmit`, every 2-3 files `npm run build`
- Quality gate: `npm run quality` must exit 0 before proceeding to REQ verification
- **If quality gate fails: STOP. Investigate. Find root cause. Fix it.** Never label a failure as "pre-existing" or "unrelated". Every failure encountered during your work is your responsibility to understand. Incident: PROJ-168 — ESLint failure dismissed instead of investigated. Past-errors #21.

### 3. REQ Suite Execution

Run ALL REQs from the spec against the current state. Every REQ. Every phase.

**Port pre-check (mandatory before starting dev servers):** Read `playwright.config.ts` and extract `baseURL` port for each project. Start dev servers on those exact ports. Do NOT guess ports.

**For each REQ, determine status:**

1. **Can this REQ be tested right now?**
   - If the code/endpoint/UI to test doesn't exist yet → **Orange** (state which phase creates it)
   - If testable → proceed to verification

2. **Execute the verification method from the spec:**
   - Use the exact verification method defined in spec S6.1
   - Paste execution output as evidence
   - Evidence must meet spec's quality rules: boundary crossing (T3+), independence (different code path), business outcome (table.field values not just status codes)

3. **Score the REQ:**
   - Verification passes with T3+ evidence → **Green**
   - Verification fails → **Red** (blocks gate)
   - Not yet testable → **Orange** (with future phase reference)

4. **Check for regressions:**
   - Was this REQ Green in a previous phase? If now Red → **regression** (blocks gate)

**Update task description:** Replace each REQ's PENDING with:
```
- REQ-001 [Functional/M]: [description] → Green | [paste: evidence summary]
- REQ-003 [Security/H]: [description] → Orange — endpoint not yet created (Phase 2)
- REQ-005 [UX/M]: [description] → Red | [paste: failure output]
```

**Frontend verification rules:**
- Test through real frontend at the ports from playwright.config.ts
- No server restarts between tests
- Must have specific expected visible results
- Never use `page.textContent('body').includes()` — always use scoped selectors (past-errors #41)
- First-time flows: use MCP browser tools (`browser_navigate`/`browser_snapshot`/`browser_click`) for interactive exploration. Write Playwright scripts only after the flow is proven interactively.

### 3.5. Verification & Review Gate (Mandatory)

After REQ suite execution but BEFORE the phase gate report:

1. **Run `/post-review`** — This dispatches the verification agent which independently traces:
   - Every function signature change → finds callers → verifies parameter passing
   - Every data flow → traces source to sink → checks type/shape matches
   - Every payload → compares producer keys to consumer destructuring

   Then performs the full code review (plan alignment, past-errors, architecture, REQ coverage).

2. **Evaluate verdict:**
   - `/post-review` returns **APPROVE** → proceed to phase gate
   - `/post-review` returns **NEEDS WORK** → fix the issues, re-run `/post-review`
   - `/post-review` returns **REJECT** → STOP. Major issues found. Fix before continuing.

3. **Verification agent RED verdicts are BLOCKERS.** Fix them, then re-run `/post-review`.

**This gate catches the exact bugs that have caused production incidents.** It is not optional.

### 4. Phase Gate — Scoring + CR + Report + Task Completion

**Gate chain (sequential, each step blocks the next):**

**Step 1 — REQ Scoring Summary**

| Metric | Value |
|--------|-------|
| Green | [X] / [total] |
| Orange | [Y] / [total] — all documented with future phase |
| Red | must be 0 to pass gate |
| Regressions (Green→Red) | must be 0 to pass gate |
| High-effort REQs (H) executed | [count] / [total H REQs testable this phase] |

**Gate pass criteria:** Zero Red. Zero regressions. All testable high-effort REQs executed.

**Step 2 — Weakest Element**

Name the single weakest aspect of this phase's implementation — the thing most likely to fail in production. Apply an additional T3+ verification test to it now.

If the additional test reveals a problem → create a CR before proceeding.
If it passes → document the test and result.

**Step 3 — Change Record Checkpoint**

Were any bugs found and fixed during this phase?
- If yes → does the fix trigger an objective CR trigger (schema, API shape, auth, state, business rule change)? See `.claude/rules/process/change-records.md`.
- If CR required → create it, propagate to spec + plan, before proceeding.
- If zero bugs found in a phase with 3+ file changes → flag as suspicious and state why you believe zero bugs is accurate.

**Step 4 — Verification & Review gate passed**

`/post-review` returned APPROVE (includes verification agent with 0 RED verdicts).

**Step 5 — Write/update report**

Create or append to `.claude/work/PROJ-*/report.md`:
- Phase header: `### Phase N: [Name] — COMPLETE`
- What was done (bullet list with file paths and line numbers)
- Full REQ scoring table with evidence references
- Weakest element test result
- CR checkpoint result (CRs created or "zero bugs — [justification]")
- Quality gate output summary
- Phase summary (2-3 sentences)
- Phase gate verdict: `**Phase N Gate: [Green]/[Orange]/0 Red — PASS**`
- Continuity notes for next phase

**Step 6 — TaskUpdate**

Set status to `completed` (BLOCKED if PENDING remains OR report doesn't contain this phase's gate verdict).

**Step 7 — Announce and wait**

```
Phase N complete.
Gate: [Green]/[Orange]/0 Red — PASS
Weakest element: [name] — tested, [result]
CRs: [count created / "zero — justified"]
Report updated at [path].
/clear or /compact available.
```

Wait for user confirmation before next phase.

**Report is part of the gate, not an afterthought.** You cannot mark a task complete without first recording its results in report.md.

---

## Required Files Structure

```
.claude/work/PROJ-NNN-feature-name/
├── plan.md                    # Main plan document
├── report.md                  # Implementation report (updated per phase)
├── .uat-validated             # Written by /uat-design (required before implementation)
├── .phases-required           # Written by hook (auto, after /implement loads)
└── .phases-created            # Written by agent (after TaskCreate for all phases)
```

---

## Implementation Workflow

### Step 1: Plan Validation + Critical Review
```bash
grep "^\*\*Status:\*\*" <plan-path>
```
After confirming approval, read the full plan and raise any concerns before proceeding.

### Step 2: Load Spec REQs
Read the spec referenced in the plan header. Extract ALL REQs from S6.1. These are your scoring framework.

### Step 3: REQ Coverage Check
Confirm `.uat-validated` exists. If not, run `/uat-design` and fix gaps first.

### Step 4: Setup Workspace
Use `superpowers:using-git-worktrees` to create an isolated branch. Never work directly on main/master.

### Step 5: Create Phase Tasks (HOOK-ENFORCED)
The `.phases-required` hook has fired. Code edits are BLOCKED until you:
1. Create TaskCreate for each phase (with ALL spec REQs as PENDING)
2. Write `.phases-created` marker

### Step 6: Execute Phases
For each phase in the plan:
1. TaskUpdate: mark phase `in_progress`
2. Read phase details from plan + spec REQs
3. **Phase Preparation:** Load context, check errors, announce
4. **Implementation:** Execute changes (follow Phase Execution Pattern above)
5. **REQ Suite Execution:** Score ALL REQs (Green/Orange/Red with evidence)
6. Update task description: replace all PENDING with status + evidence
7. **Verification & Review gate:** Run `/post-review`. Resolve BLOCKERS. Re-run if NEEDS WORK.
8. **Phase Gate:** Scoring summary → Weakest element → CR checkpoint → Report → TaskUpdate
9. Wait for user confirmation before next phase

If blocked at any point: stop, report the blocker, ask for guidance.

### Step 7: Final Verification
After all phases complete:
1. Run `npm run quality` — full chain must pass
2. If cross-stack changes: run codebase-memory `trace_call_path` for modified functions
3. Run E2E verification from plan S6
4. Validate all spec REQs are Green (zero Orange, zero Red)
5. Update implementation report with final results

### Step 8: Ship
1. All tasks show `completed`
2. All spec REQs are Green
3. Provide summary to user
4. Run /post-review
5. Invoke `superpowers:finishing-a-development-branch` for structured completion
6. /ship — first PR targets `staging` branch
7. After staging UAT passes: second PR from `staging` to `main`

---

## Success Criteria

Implementation is complete when:
- [ ] Spec REQs loaded and understood (from spec S6.1)
- [ ] REQ coverage validated (`.uat-validated` exists)
- [ ] Phase tasks created and tracked (`.phases-created` exists)
- [ ] All phases completed (all tasks show `completed`, no PENDING)
- [ ] All spec REQs are Green with T3+ execution evidence
- [ ] Zero Red REQs across all phases
- [ ] Zero regressions (no Green→Red transitions)
- [ ] All high-effort (H) REQs have proportional verification
- [ ] `npm run quality` passes (exit 0)
- [ ] E2E verification successful (plan S6)
- [ ] `/post-review` returned APPROVE for each phase
- [ ] Weakest element identified and tested each phase
- [ ] CR checkpoint completed each phase (CRs created or zero justified)
- [ ] Implementation report contains every phase's gate verdict
- [ ] Report written incrementally per phase (not batched at the end)
- [ ] Work completed on isolated branch (not main/master)
