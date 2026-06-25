# Claude Code Skills, Hooks & Lessons Learned

A battle-tested collection of **Claude Code skills** (slash commands), **guardrail hooks** (pre/post tool guards), and **debugging patterns** built over 6+ months of daily production use across a multi-tenant SaaS platform.

These aren't theoretical — every skill, hook, and past-error rule was born from real incidents, real bugs, and real process failures encountered during active development with Claude Code.

## Repository Structure

```
skills/
├── custom/                    ← 23 original skills (spec→plan→implement→ship pipeline)
├── third-party/
│   ├── mattpocock/            ← 8 skills by Matt Pocock
│   └── obra/                  ← 14 skills by Jesse Vincent (Superpowers)
hooks/                         ← 47 guardrail hooks
past-errors/                   ← 57 numbered rules from production incidents
debugging/                     ← 4 domain-specific debugging playbooks
```

## Third-Party Credits

This collection includes skills from two authors whose work integrates into the development workflow:

### [Matt Pocock](https://github.com/mattpocock/skills) — 8 skills
From the "Skills for Real Engineers" collection. General-purpose development skills for TDD, domain modeling, issue creation, and architecture analysis.

Skills: `caveman`, `tdd`, `grill-with-docs`, `to-issues`, `to-prd`, `write-a-skill`, `git-guardrails`, `improve-codebase-architecture`

### [Jesse Vincent / obra](https://github.com/obra/superpowers) — 14 skills
The Superpowers agentic skills framework, distributed via [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official). Provides brainstorming, parallel agent coordination, systematic debugging, and verification discipline.

Skills: `brainstorming`, `dispatching-parallel-agents`, `executing-plans`, `finishing-a-development-branch`, `receiving-code-review`, `requesting-code-review`, `subagent-driven-development`, `systematic-debugging`, `test-driven-development`, `using-git-worktrees`, `using-superpowers`, `verification-before-completion`, `writing-plans`, `writing-skills`

---

## The Planning & Implementation System

The core of this collection is a **structured development pipeline** that enforces discipline through every stage of work: from requirement gathering to production deployment. The system is designed to prevent the failure modes that AI coding assistants commonly exhibit — scope creep, unverified claims, silent regressions, and skipped testing.

### The Pipeline

```
User Request → /spec → /plan → /review-gates → /implement → /post-review → /ship → /deploy → /retro
```

Each stage has explicit entry/exit gates. No stage can be skipped. The system enforces this through hooks that block tool calls when prerequisites aren't met.

### Key Concepts

**REQs (Requirements):** Every spec defines numbered requirements (REQ-001, REQ-002, etc.) with evidence tiers (T1-T5), effort tags (L/M/H), and 9 scoring dimensions (Functional, Data Integrity, Security, UX, Performance, Invariant, Regression, Observability, Change Propagation).

**Green/Orange/Red Scoring:** At every implementation phase gate, ALL REQs from the spec are scored:
- **Green** — passes with execution output as evidence (not code reading)
- **Orange** — code to test this REQ doesn't exist yet (future phase will turn it Green)
- **Red** — fails, or CAN be tested but hasn't been. Blocks the phase gate.

**Evidence Standard:** Code reading is discovery, not verification. Only execution output (bash, browser snapshots, SQL results, AST tool output) counts as evidence. The `weasel-word-guard` hook enforces this by blocking speculative language.

**Change Records (CRs):** When implementation deviates from the spec, a formal Change Record must be created, classified (spec-level / plan-level / code-only), and propagated back to both the spec and plan before continuing.

### Pipeline Stages in Detail

#### Stage 1: `/spec` — Define What & Why
Produces a 10-section specification document with evidence-backed requirements, adversarial analysis, and scoring framework. The spec answers WHAT, WHY, and WHAT COULD GO WRONG.

#### Stage 2: `/plan` — Define How & In What Order
Produces a 7-section implementation plan that maps spec REQs to executable phases. Each phase has a gate with the full REQ scoring table. The plan answers HOW, IN WHAT ORDER, HOW TO VERIFY, and HOW TO DEPLOY.

#### Stage 3: `/review-gates` — 7-Gate Validation
Runs all 7 review gates sequentially. All must pass before the plan is approved:
1. Past-error cross-check
2. API surface verification
3. REQ coverage analysis
4. Simplification review
5. Security audit
6. Tenant impact analysis
7. Multi-agent plan critique

#### Stage 4: `/implement` — Phase-by-Phase Execution
Executes the approved plan phase by phase. Each phase ends with a gate: all REQs scored, regression detection (Green→Red = blocked), CR checkpoint, weakest-element identification.

#### Stage 5: `/post-review` — Code Review
Structured review checking plan alignment, past-error compliance, architecture rules, RBAC, REQ scoring, CR audit, security, and deletion opportunities.

#### Stage 6: `/ship` — PR & Deploy
Creates PR with documentation, waits for user merge approval, then deploys to EC2 with health checks and rollback plan.

#### Stage 7: `/retro` — Session Retrospective
Analyzes implementation errors, UAT design quality, pipeline fidelity, and extracts learnings into past-errors rules and debugging patterns.

---

## Skill Reference

### Planning Skills

#### `/spec` — Structured Specification
Writes a 10-section spec document using evidence-backed requirements. Requires AST tools (ast-grep) for code surface mapping — grep is banned.

**10 Sections:**
1. **Problem** — Evidence-backed justification with work type classification (bug fix, feature, refactor, etc.)
2. **Current State** — Code surface via AST, data state via SQL, architecture doc check, past error check, risk scoring, data classification
3. **Success Criteria** — 4-element quality standard (actor/action/result/negative proof) with 4-path coverage (happy/failure/boundary/existing-data)
4. **Design** — Before/after architecture, design decisions with alternatives, scope boundary, external API verification
5. **Risk & Adversarial Analysis** — 16 risk categories, each with invariant, adversarial scenario, code trace, assumptions, and generated REQ
6. **Requirements & Scoring Framework** — All REQs with evidence tiers (T1-T5), effort tags, 9 dimensions, structural minimums
7. **Monitoring & Observability** — Leading/lagging indicators, failure detection linked to kill switches
8. **Performance & Load** — Metrics with degradation behavior and mandatory upper bounds
9. **Dependencies & Scope Decomposition** — 4 dependency types, weighted complexity (decompose if >12)
10. **Rollback Strategy** — Per-layer undo, partial failure recovery, irreversible effects

**Hard Rules:**
- All evidence execution-based (no "I read the code and confirmed")
- All REQs require T3+ verification with exact expected output
- grep/rg banned — AST tools only
- Must be approved by user before `/plan` can begin

---

#### `/plan` — Implementation Planning
Writes a 7-section implementation plan mapping an approved spec's REQs to executable phases with Green/Orange/Red scoring at every phase gate.

**7 Sections:**
1. **Implementation Overview** — Phase summary, expected REQ progression, execution strategy (written LAST)
2. **Code Surface & Blast Radius** — Change manifest (CREATE/EDIT/USE with verification), all callers mapped via `trace_call_path`, middleware chains, mutation constraints, env var VALUES per environment
3. **Database Schema & Migration** — Migration SQL with BEGIN/COMMIT, verification queries, rollback SQL, data backfill
4. **Cross-Service Data Flow** — Variable-level traces per entry point, non-caller transformations (`.map()`, response builders, spread operators)
5. **Implementation Phases** — Each phase is a testable increment with full REQ suite scoring at every gate
6. **E2E Verification** — Browser protocol (MCP first, Playwright after), connected workflow, cross-frontend checks, build verification
7. **Ship & Deploy** — PR flow, staging UAT, deploy checklist, PM2 freshness check, production verification

**Phase Gate Chain (per phase):**
1. Execute phase steps
2. Score ALL REQs (not just this phase's) — Green/Orange/Red
3. Detect regressions (Green→Red = blocked)
4. Identify weakest element, add additional test
5. CR checkpoint — any unrecorded changes?
6. Phase gate report
7. Proceed or fix

**Hard Rules:**
- Approved spec required — plan cannot start without one
- Full REQ suite at every phase gate — not just "this phase's" REQs
- Zero Red at every gate
- CR protocol checked at every gate

---

#### `/review-gates` — 7 Sequential Quality Gates
Orchestrates all 7 review gates on an implementation plan. Each gate runs independently — failures don't stop remaining gates.

**The 7 Gates:**

| Gate | Skill Invoked | What It Checks | Pass Condition |
|------|---------------|----------------|----------------|
| 0 | `/check-errors` | Past error rules, debugging patterns, architecture violations | 0 RISKS, 0 VIOLATIONS |
| 1 | `/verify-plan` | Function calls, column names, constraints, SDK methods against actual source | 0 FAIL items |
| 2 | `/uat-design` | REQ quality, 4-path coverage, 9-dimension coverage | 100% on all three |
| 3 | `/simplify` | Over-engineering, unnecessary abstractions, AI code slop | 0 Critical findings |
| 4 | `/security-review` | OWASP Top 10, auth bypass, RBAC, webhook/payment security | 0 HIGH findings |
| 5 | `/tc-impact` | Data isolation, config divergence, client UX, breaking API changes | No unmitigated HIGH items |
| 6 | `/critique-plan` | 7-agent sequential critique loop | User confirmed |

**Minimum gates by plan size:**
- Hotfix (1 phase): Gate 1 only
- Small (1-2 phases): Gates 1, 2
- Medium (2-3 phases): Gates 0-4
- Large (4+ phases): All 7

---

#### `/critique-plan` — 7-Agent Sequential Critique
Runs 7 specialized agents in sequence, each building on the previous agent's output:

1. **Agent 0: Code Verifier** — Reads actual source code for every function/method the plan references. Verifies signatures, return types, side effects.
2. **Agent 1: Plan Critic** — Challenges assumptions, finds logical gaps, stress-tests edge cases.
3. **Agent 2: Plan Rewriter** — Rewrites plan sections based on Agent 1's findings.
4. **Agent 3: REQ & Verification Critic** — Checks REQ quality, verification method realism, expected outcome specificity.
5. **Agent 4: Plan Rewriter + REQ Alignment** — Aligns plan with REQ critique findings.
6. **Agent 5: REQ Coverage Validator** — Maps every spec REQ to plan phases, finds orphans and gaps.
7. **Agent 6: Final Revision** — Consistency pass across all plan sections.

---

#### `/verify-plan` — API Surface Verification
Dispatches a verification agent that checks every concrete reference in the plan against actual source code:

- Function calls — method exists with expected signature
- Column names — column exists in `information_schema`
- DB constraints — CHECK, NOT NULL, UNIQUE, FK all verified
- SDK methods — method exists on the imported module
- Route middleware chains — auth middleware present on every protected route
- Object property chains — every `.property` access resolves
- String-match queries — `ilike`/`eq` values match actual data
- Temporal bounds — date/time logic is consistent
- REQ-to-phase-gate coverage — every REQ appears in every phase gate table
- Change Manifest completeness — every file mentioned in phases appears in the manifest

Writes `.api-verified` marker on pass.

---

#### `/uat-design` — REQ Coverage Verifier
Audits spec REQs across four quality dimensions:

1. **Evidence Tier Appropriateness** — T1/T2 rejected for functional/integration REQs; T3+ required
2. **Verification Method Realism** — "Inspect code" rejected; must be executable (curl, SQL, browser action)
3. **Expected Outcome Specificity** — "Works correctly" rejected; must specify exact values/states
4. **Verification Independence** — Can't verify using the same code being tested

Also checks 4-path coverage per Success Criterion (happy/failure/boundary/existing-data) and all 9 dimension coverage.

Writes `.uat-validated` marker on pass.

---

### Implementation Skills

#### `/implement` — Phase-by-Phase Execution
Executes an approved plan phase by phase with mandatory task tracking. Each phase follows a strict pattern:

1. **Read** the phase from the plan
2. **Execute** the steps (code changes, migrations, config)
3. **Score** ALL REQs at the phase gate — Green/Orange/Red with execution evidence
4. **Detect regressions** — any Green→Red = blocked
5. **CR checkpoint** — any unrecorded changes?
6. **Report** phase results
7. **Proceed** or fix

**Evidence Standard:** "Code reading is discovery, not verification." Every Green REQ must have execution output attached — bash output, browser snapshot, SQL result. The `evidence-tier-guard` hook warns when static analysis (T1) is used for T3+ requirements.

---

#### `/tdd` — Test-Driven Development
Enforces red-green-refactor with vertical slices (tracer bullets), not horizontal slices.

**Anti-pattern it prevents:** Writing all tests first, then all implementation. This produces tests that verify imagined behavior, not actual behavior.

**Correct flow:**
1. Write ONE test for first behavior → test fails (RED)
2. Write minimal code to pass → test passes (GREEN)
3. Repeat for each remaining behavior
4. Refactor only when GREEN

**Mocking rules:** Mock at system boundaries only (external APIs, databases, time). Never mock your own classes or internal collaborators.

---

#### `/cr` — Change Record
Creates a formal Change Record when implementation deviates from the spec. Triggered by:
- Bug found during implementation that changes behavior
- Schema/API/auth/state/business-rule difference from spec
- `cr-propagation-guard.sh` hook warning
- User saying "that's a CR"

**Classification:**
- **Spec-level** (mandatory) — any of 5 objective triggers detected (DB schema, API shape, auth, state machine, business rule change)
- **Plan-level** — implementation approach changed but no spec impact
- **Code-only** — no CR needed, documented in phase gate report

**Propagation:** Spec-level CRs must update the spec (sections, REQs), the plan (phase gates, REQ progression), and verify code matches. Propagation must happen NOW, not "later."

---

### Quality Skills

#### `/post-review` — Structured Code Review
6-step review process run after implementation:

1. **Scope** — identify all changed files and their categories
2. **Plan & Spec Alignment** — method-level comparison of what was planned vs what was built
3. **Past-Error Cross-Check** — invokes `/check-errors` against changed code
4. **Architecture Compliance** — 7 sub-checks (RBAC, tenant scoping, auth middleware, error handling, logging, type safety, test coverage)
5. **Verification Agent** — dispatches agent to verify specific claims in the implementation
6. **REQ Scoring** — re-scores all REQs against final implementation state

Output: APPROVE / REQUEST CHANGES / BLOCK with severity-labeled findings.

---

#### `/check-errors` — Past Error Cross-Reference
Loads 4 error sources in parallel and matches against current work scope:

1. **Past Errors Rules** (`.claude/rules/anti-patterns/past-errors.md`) — numbered rules from production incidents
2. **Debugging Patterns** (`memory/base/debugging.md`) — named patterns (SuperTokens, Supabase, finance-svc, etc.)
3. **Claude-Mem Observations** — cross-session memories tagged as bugfixes
4. **Architecture Rules** (`.claude/rules/architecture/`) — per-domain critical rules

For each matched error, checks if the current work has protection:
- **RISK** — prevention is MISSING
- **PROTECTED** — prevention is PRESENT
- **VIOLATION** — architecture rule broken

Used standalone or invoked automatically by `/plan`, `/implement`, `/verify-plan`, `/review-gates` (Gate 0), and `/post-review`.

---

#### `/simplify` — Over-Engineering Detection
Aggressive simplification reviewer that checks 7 categories:

1. **Unnecessary Variables** — assigned once, used once on next line → inline
2. **Unnecessary Functions** — called from one place → inline at call site
3. **Unnecessary Routes** — duplicates existing behavior → reuse
4. **Unnecessary Logic** — if/else that could be ternary, try/catch around non-throwing code
5. **Existing Code Reuse** — new function duplicates logic already in a service
6. **AI Code Slop** — obvious comments, excessive JSDoc, try/catch with hardcoded fallback masking dead primary path
7. **Structural Simplification** — deep nesting → guard clauses, long switch → lookup object

Findings rated Critical / Moderate / Minor. Only Critical blocks shipping.

**Hard Rule:** "Three similar lines > premature abstraction." Duplication across module boundaries is fine if coupling would be worse.

---

#### `/security-review` — OWASP Confidence-Rated Audit
Security audit with confidence-based severity to prevent noise:

| Confidence | Definition | Action |
|-----------|-----------|--------|
| **HIGH** | Vulnerable pattern confirmed AND attacker-controlled input reaches it | BLOCKING |
| **MEDIUM** | Pattern found but input source unclear | FLAG |
| **LOW** | Theoretical/best-practice | ADVISORY |

**10-area checklist:** Injection (A1), Broken Auth (A2), Data Exposure (A3), Broken Access Control (A4), Misconfig (A5), XSS (A6), Dependencies (A7), Webhooks (A8), Payments (A9), Logging (A10).

**Process:** Identify attack surface → Trace data flow from input to DB → Check auth chain per route → Produce confidence-rated report.

---

#### `/evidence` — Force Verification
Companion to the `weasel-word-guard` hook. When a claim is challenged, forces execution-based evidence gathering.

**Evidence classification:**

| Claim Type | Required Evidence |
|-----------|-------------------|
| "Code works" | Run it, show output |
| "Server starts" | PM2 logs showing the listening line |
| "Migration ran" | SELECT query showing new column/data |
| "Build passes" | Actual `npm run build` output with exit code |
| "No regressions" | Load adjacent pages, run existing tests |
| "Error is fixed" | Reproduce original scenario, show it succeeds |

**Grades:** CONFIRMED (executed, output matches) / PARTIAL (gaps remain) / UNVERIFIABLE (cannot test — explain why) / REFUTED (evidence contradicts claim — STOP and fix).

**Hard Rules:**
- Reading code is not evidence that code works
- A passing build is not evidence of correct behavior
- "I tested this earlier" is not current evidence
- UNVERIFIABLE is an honest answer — never fake a PASS

---

### Research Skills

#### `/research` — 4-Stage Verified Discovery
Every observation goes through 4 stages before it can be used as basis for decisions:

1. **FIND** — Raw observation with exact source (file:line, command output, query result)
2. **CROSS-REFERENCE** — Verify against at least one independent source. Second source must be different from the first (re-reading same file doesn't count).
3. **CHALLENGE** — Actively search for counter-evidence. Must cite what was searched and where.
4. **RATE** — GREEN (2+ sources, no contradictions) / AMBER (single source or partial cross-ref) / RED (contradiction found)

**Decision gate:** All GREEN → proceed. Any AMBER → call out explicitly. Any RED → STOP, resolve contradictions.

**Hard Rule:** "No building on RED findings. Period."

---

#### `/diagnose` — Systematic Bug Diagnosis
6-phase discipline for hard bugs:

1. **Build a feedback loop** — This is the core skill. 10 strategies listed in priority order: failing test, curl script, CLI invocation, headless browser, replay captured trace, throwaway harness, property/fuzz loop, bisection harness, differential loop, HITL bash script. Iterate on the loop itself — make it faster, sharper, more deterministic.
2. **Reproduce** — Confirm the loop produces the failure mode the user described, not a nearby different failure.
3. **Hypothesise** — Generate 3-5 ranked hypotheses before testing any. Each must be falsifiable. Show list to user before testing.
4. **Instrument** — One variable at a time. Tag every debug log with unique prefix (e.g., `[DEBUG-a4f2]`) for easy cleanup.
5. **Fix + regression test** — Write regression test before fix (if correct seam exists). Watch it fail, apply fix, watch it pass.
6. **Cleanup + post-mortem** — Remove all `[DEBUG-...]` instrumentation, delete throwaway prototypes. Ask: what would have prevented this bug?

---

#### `/zoom-out` — Big Picture Re-orientation
Quick 5-layer re-orientation when lost in implementation details:

1. **THE MISSION** — One sentence from plan summary
2. **WHERE YOU ARE** — Current phase, objective, progress. Drift warning if editing files not in current phase.
3. **THE USER JOURNEY** — All workflow steps marked complete/current
4. **WHAT PROVES THIS WORKS** — Specific UAT test and success criteria for current work
5. **CODE ARCHITECTURE** — Module map: current file, callers, callees, data flow

**Design:** Fast (reads one file), non-destructive (never edits), always available (works without a plan).

---

### Shipping Skills

#### `/ship` — PR Creation & Deployment
3-phase ship workflow:

1. **Documentation** — Generates implementation report (11 sections: executive summary, deliverables, phase-by-phase results, verification matrix, integration points, before/after comparison, cloud dependencies, remaining actions, risk assessment, rollback plan, UAT scenarios)
2. **PR Creation** — Stage, commit (with Co-Authored-By), push, create PR via `gh pr create` with structured body. Warns if `.env` or credentials are staged.
3. **Deploy** — SSH into EC2, git pull, npm install if package.json changed, rebuild frontends if changed, PM2 restart, health check (8s wait + verify online status), crash loop detection

**Hard Gate:** Waits for user merge confirmation between PR creation and deploy. Never auto-deploys.

---

#### `/deploy` — Production Deploy Checklist
Step-by-step deploy with evidence at every checkpoint:

**Pre-deploy gates:** Implementation report exists, all Self-UATs CONFIRMED, E2E complete, PR merged, quality gate passed.

**6 Steps:**
0. Gate check + roadmap verification
1. Identify scope (which components: backend, frontend, finance-svc, DB, nginx)
2. Pre-deploy checklist (env audit, build verification, localhost grep in built output)
3. Backup (git commit hash, nginx config copy, rollback SQL)
4. Execute (git pull → npm install → rebuild → PM2 restart → timestamp verification)
5. Post-deploy verification (PM2 logs, page loads, API calls, payment flow)
6. Rollback plan (pre-written, ready to execute)

**Hard Rule:** PM2 `created_at` timestamps must be AFTER git pull timestamp. Stale timestamp = process never restarted.

---

#### `/retro` — Session Retrospective
9-step post-session analysis:

1. **Session Summary** — Task, goal, outcome, phases completed
2. **Efficiency Audit** — Score 1-5 on focus, first-try accuracy, search efficiency, context usage, evidence discipline. Detect doom loops, wasted context, blocked moments.
3. **Implementation Error Analysis** — Every error categorized (env/schema/api-contract/stale-context/tool-misuse/logic/integration/build), cross-referenced against past-errors.md
4. **UAT Design Audit** — Grade each test (GOOD/WEAK/UNTESTABLE/WRONG-TIER/REDUNDANT/MISSING). Calculate UAT Design Accuracy %.
5. **Report Cross-Reference** — Compare plan vs reality: divergent phases, suspiciously clean phases, rollback validity
6. **Pipeline Fidelity Check** — Trace through every pipeline boundary (Request→Plan, Plan→Implementation, Plan UATs→Report, Criteria→Evidence, Report→Reality). Grade each: FAITHFUL/DRIFT/SCOPE-CREEP/SCOPE-LOSS
7. **Extract Learnings** — Gotchas, discoveries, process gaps
8. **Update Memory** — Route learnings to past-errors.md, debugging patterns, MEMORY.md, or propose hook/skill changes
9. **Output** — Structured summary with all scores. Wait for user approval before writing any files.

---

### Analysis Skills

#### `/tc-impact` — Tenant & Client Impact Analysis
Analyzes planned changes across all tenants and client types (admin, receptionist, kiosk, member, guest).

**6 checks:**
1. Tenant data isolation — every DB query has tenant_id filter
2. Configuration divergence — hardcoded assumptions about tenant-specific config
3. Client-facing UX impact — per client type assessment
4. Breaking API changes — backward compatibility verification
5. Migration requirements per tenant — tenant-aware, idempotent, ordered
6. Feature flag & rollout strategy — per-tenant enablement

---

#### `/gemini-review` — Cross-AI Second Opinion
Packages current work context into a markdown prompt and sends to Gemini CLI (`gemini -p`) for independent review. Works for code, research, plans, and documentation.

**Process:** Determine scope → Package context to `/tmp/gemini-review-prompt.md` → Send to Gemini → Present results with agree/disagree analysis per point.

---

#### `/grill-with-docs` — Domain Model Stress Test
Interview-style grilling that challenges plans against the existing domain model. Walks down each branch of the design tree, resolving dependencies one-by-one.

**During session:**
- Challenges against the project glossary (CONTEXT.md) — flags term conflicts
- Sharpens fuzzy language — proposes precise canonical terms
- Cross-references claims with actual code — surfaces contradictions
- Updates CONTEXT.md inline as terms are resolved
- Offers ADRs (Architecture Decision Records) sparingly — only when hard to reverse, surprising, and result of real trade-off

---

### Utility Skills

#### `/roadmap` — Full Themed View
Reads `roadmap.yaml`, groups entries by strategic theme (Platform/Tenant/Customer), orders by priority (P0-P3), shows monitoring items past their review date, and offers to run verification queries on monitored items.

#### `/roadmap-summary` — Compact View
One-line-per-entry summary: `P[N]: PROJ-NNN stage — title`. No descriptions, no links.

#### `/to-issues` — Plan to Issues
Breaks a plan into independently-grabbable issues using vertical slices (tracer bullets). Each issue cuts through ALL integration layers end-to-end. Issues marked HITL (human required) or AFK (autonomous).

#### `/to-prd` — Conversation to PRD
Synthesizes current conversation context into a PRD with problem statement, solution, user stories, implementation decisions, testing decisions, and scope.

#### `/caveman` — Ultra-Compressed Communication
Drops articles, filler words, pleasantries, and hedging. Keeps all technical substance. Cuts token usage ~75%. Active until user says "stop caveman."

Pattern: `[thing] [action] [reason]. [next step].`

#### `/write-a-skill` — Skill Authoring
Guides creation of new Claude Code skills with proper SKILL.md structure, description triggers, progressive disclosure, and utility scripts.

#### `/git-guardrails` — Git Safety Hooks
Creates PreToolUse hooks that block dangerous git commands (push, reset --hard, clean -f, branch -D, checkout .) before execution.

#### `/improve-codebase-architecture` — Deep Module Finder
Surfaces architectural friction and proposes refactors that turn shallow modules into deep ones. Uses the **deletion test**: imagine deleting the module — if complexity vanishes, it was a pass-through; if complexity reappears across N callers, it was earning its keep.

---

## Hooks Reference

### How Hooks Work
Claude Code hooks are shell scripts that run before (PreToolUse) or after (PostToolUse) specific tool calls. They can:
- **Block** operations by exiting with code 2 and printing to stderr
- **Warn** by printing to stderr and exiting 0
- **Inject context** by outputting JSON with `additionalContext`

### Database Safety

| Hook | Trigger | What It Does |
|------|---------|-------------|
| `supabase-db-guard.sh` | PreToolUse: Supabase tools | Detects production project ref in MCP config, requires temp override file to proceed |
| `supabase-chain-guard.sh` | PostToolUse: Write/Edit | Detects `.from('table').eq()` without `.select()` — a chain bug that crashes at runtime |
| `pre-migration-verify.sh` | PostToolUse: apply_migration | Reminds to verify schema state via `information_schema` before migration (past-errors #51) |
| `table-ownership-guard.sh` | PostToolUse: Write/Edit | Warns on queries to tables owned by other modules |

### Git Safety

| Hook | Trigger | What It Does |
|------|---------|-------------|
| `pre-tool-guard.sh` | PreToolUse: Bash | Blocks git push to protected branches, git reset --hard, DROP TABLE, checkout ., and scripts containing dangerous commands |
| `branch-base-guard.sh` | PreToolUse: Bash | Warns when creating branch from main while staging is ahead |
| `merge-tree-guard.sh` | PreToolUse: Bash | Checks for merge conflicts before PR creation |
| `post-rebase-conflict-guard.sh` | PreToolUse: Bash | Blocks commit/rebase-continue if staged files contain `<<<<<<` markers |
| `no-verify-guard.sh` | PreToolUse: Bash | Blocks `--no-verify` on any git command |

### Deploy Safety

| Hook | Trigger | What It Does |
|------|---------|-------------|
| `pm2-restart-guard.sh` | PostToolUse: Bash | After SSH git pull, reminds to restart ALL PM2 processes and verify timestamps |
| `pre-commit-runtime-guard.sh` | PreToolUse: Bash | Blocks git commit without recent runtime evidence |
| `ssh-edit-guard.sh` | PreToolUse: Bash | Blocks direct SSH file editing (vim, nano, sed, scp, rsync on servers) |
| `production-override-expiry.sh` | PostToolUse | Auto-expires production Supabase override after 10 minutes |

### Evidence & Quality

| Hook | Trigger | What It Does |
|------|---------|-------------|
| `citation-guard.sh` | Stop | Blocks 12 categories of blanket assertions (170+ patterns) like "everything works", "all tests pass" without individual evidence |
| `weasel-word-guard.sh` | Stop | Blocks hedging language ("probably", "should work", "I think", "seems like") — forces evidence |
| `evidence-guard.sh` | Stop | Catches probabilistic language ("likely", "appears to", "presumably") |
| `agent-evidence-guard.sh` | PostToolUse: Agent | Reminds to verify agent results with runtime tests, not just static analysis |
| `evidence-tier-guard.sh` | PostToolUse | Warns when static analysis (T1) is used as evidence for T3+ requirements |

### Process Enforcement

| Hook | Trigger | What It Does |
|------|---------|-------------|
| `plan-save-guard.sh` | PreToolUse: ExitPlanMode | Blocks exit without plan saved + UAT validated + API verified |
| `post-skill-phase-gate.sh` | PostToolUse | Writes `.phases-required` manifest after `/implement` |
| `no-scope-dodge-guard.sh` | Stop | Blocks dismissing issues as "pre-existing" or "out of scope" without evidence |
| `no-hotfix-guard.sh` | Stop | Blocks responses suggesting skipping the plan workflow |
| `cr-propagation-guard.sh` | PreToolUse | Detects objective CR triggers in git diff during implementation |
| `shallow-cr-guard.sh` | PostToolUse | Flags reports with 3+ phases but zero Change Records |
| `spec-compliance-check.sh` | PostToolUse | Validates spec files have all 10 sections |
| `post-write-check.sh` | PostToolUse | Validates plan compliance (7 sections), report compliance (10 sections), server restart reminder |

### Test Safety

| Hook | Trigger | What It Does |
|------|---------|-------------|
| `test-data-email-guard.sh` | PreToolUse: Bash/MCP | Blocks test data targeting non-approved email addresses. Prevents real customer invoices during testing. |
| `playwright-test-data-guard.sh` | PreToolUse | Blocks direct INSERT into destination tables for test data |
| `playwright-selector-guard.sh` | PostToolUse | Warns on page-wide text matching in Playwright tests |
| `playwright-script-guard.sh` | PreToolUse | Blocks Playwright script creation — use MCP browser tools for interactive testing |

### SDK & Build

| Hook | Trigger | What It Does |
|------|---------|-------------|
| `sdk-wrapper-guard.sh` | PostToolUse | Warns when files import SDKs directly instead of using wrapper services |
| `npm-save-guard.sh` | PreToolUse: Bash | Blocks bare `npm install <package>` (must use --save or --save-dev) |
| `ci-workflow-guard.sh` | PostToolUse | Warns when package.json changes may break CI workflow |
| `cross-stack-guard.sh` | PostToolUse | Warns on server+frontend edits in same session |

### Other

| Hook | Trigger | What It Does |
|------|---------|-------------|
| `session-lifecycle.sh` | SessionStart/Stop | Context injection on start, uncommitted changes reminder on stop |
| `roadmap-validation.sh` | PostToolUse | Validates roadmap.yaml schema |
| `roadmap-mindmap-gen.sh` | PostToolUse | Regenerates mindmap when roadmap.yaml changes |
| `post-branch-switch-deps.sh` | PostToolUse | Warns when deps may be out of sync after branch switch |
| `delete-reference-guard.sh` | PostToolUse | Detects orphaned references after code block deletion |
| `url-in-sql-guard.sh` | PostToolUse | Verifies URLs in SQL files are accessible |
| `require-method-guard.sh` | PostToolUse | Verifies `require()` method calls resolve to actual exports |
| `pre-pr-quality.sh` | PreToolUse | Runs quality gate before PR creation |
| `pr-merge-guard.sh` | PreToolUse | Blocks `gh pr merge` — PRs need user approval |
| `pre-staging-pr-guard.sh` | PreToolUse | Blocks staging PR without implementation report |
| `hotfix-branch-guard.sh` | PreToolUse | Blocks `hotfix/` branch prefix |

---

## Past Errors & Debugging Patterns

### `/past-errors/past-errors.md`
57 numbered rules from production incidents covering:
- Database safety (BEGIN/COMMIT, constraints, FK violations, PostgREST cache)
- Frontend deployment (env var auditing, localhost in builds, module-scope SDKs)
- Testing discipline (Self-UAT enforcement, evidence requirements, per-payment-method testing)
- API integration (verify method signatures against actual code, not docs)
- Multi-tenant isolation (tenantId threading through ALL internal calls)
- Deploy safety (PM2 restart verification, env var presence, CI workflow sync)
- Error handling (never mask with try/catch, never dismiss errors as "pre-existing")

### `/debugging/`
Domain-specific playbooks:
- **debugging.md** — 10 named patterns (SuperTokens SDK, Supabase silent null, MyFatoorah payment, Zoho SMTP block, PostgREST schema cache, tenant-scoped RBAC, finance-svc auth, worktree environment issues)
- **debugging_patterns.md** — Original 8 patterns with diagnostic queries and fix procedures
- **debugging_checkin_unknown_scans.md** — QR scan investigation playbook
- **debugging_finance_svc_patterns.md** — Payment gateway integration debugging

---

## How to Use

### Install a Skill
Copy any skill directory into `~/.claude/skills/` or your project's `.claude/skills/`:

```bash
# Custom skills
cp -r skills/custom/diagnose ~/.claude/skills/

# Third-party skills
cp -r skills/third-party/mattpocock/tdd ~/.claude/skills/
```

Then invoke with `/diagnose` or `/tdd` in Claude Code.

### Install Superpowers (obra)
The Superpowers skills are best installed as a plugin:
```bash
/install-plugin superpowers@claude-plugins-official
```

### Install a Hook
Copy hook files to `~/.claude/hooks/` and register them in your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": ["~/.claude/hooks/supabase-db-guard.sh"]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": ["~/.claude/hooks/weasel-word-guard.sh"]
      }
    ]
  }
}
```

### Use Past Errors
Copy `past-errors.md` into your project's `.claude/rules/anti-patterns/` directory. The `/check-errors` skill will automatically cross-reference it against your plans.

---

## Sanitization Note

All identifying information has been removed from these files:
- Company/product names replaced with generic placeholders
- IP addresses, domains, and URLs redacted
- Person names, emails, and phone numbers removed
- AWS account IDs, Supabase project refs sanitized
- Server hostnames and SSH aliases genericized

The patterns and lessons remain fully intact.

## License

MIT
