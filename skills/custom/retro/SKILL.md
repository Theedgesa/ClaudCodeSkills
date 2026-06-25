---
name: retro
description: Post-session retrospective that analyzes implementation errors, UAT design quality, efficiency, and updates memory. Use when session ends, after /ship, after debugging, or when user says "retro" or "what did we learn".
allowed-tools: Read, Write, Edit, Glob, Grep, Agent, AskUserQuestion
---

# Retro -- Session Retrospective

Analyze the session. Extract learnings. Update memory. Compound knowledge.

## Step 1: Session Summary

Reconstruct from conversation context:

- **Task ID:** PROJ-NNN or description
- **Goal:** What was the objective?
- **Outcome:** Achieved / Partial / Blocked
- **Phases completed:** N of M (if plan-based)
- **Report path:** `.claude/work/PROJ-NNN-name/report.md` (if exists, read it)

## Step 2: Efficiency Audit

Score 1-5 with specific evidence for each:

| Dimension | What to look for |
|-----------|-----------------|
| **Focus** | Rabbit holes, tangents, scope creep |
| **First-try accuracy** | Changes that worked without retry vs needed 2+ attempts |
| **Search efficiency** | Tool calls to find what was needed (fewer = better) |
| **Context usage** | Used memory/docs vs re-discovered known facts |
| **Evidence discipline** | Proved claims vs got blocked by weasel-word hook |

Detect and list:
- **Doom loops:** Same approach tried 2+ times without change
- **Wasted context:** Large file reads or searches that didn't contribute
- **Blocked moments:** Where progress stalled and what unblocked it

## Step 3: Implementation Error Analysis

For EVERY error encountered this session (not just the final state -- include errors that were fixed mid-session):

```
- Error: [exact message or symptom]
  Phase: [which plan phase]
  Root cause: [what actually caused it]
  Time to resolve: Quick (< 5 min) / Medium (5-30 min) / Rabbit hole (30+ min)
  Preventable? Yes/No -- [how]
  Category: env | schema | api-contract | stale-context | tool-misuse | logic | integration | build
```

Build an error heat map -- count per category. Flag any category with 3+ errors across recent sessions as systemic.

Cross-reference each error against `past-errors.md`:
- Was there already a rule that should have prevented this? If yes, the rule failed -- why?
- Is this a NEW pattern not yet captured? If yes, propose a new rule.

## Step 4: UAT Design Audit

For each Self-UAT test in the plan, grade:

```
- Phase N, Test M: [test name]
  As designed: [what plan said]
  As executed: [what actually happened]
  Grade: GOOD | WEAK | UNTESTABLE | WRONG-TIER | REDUNDANT | MISSING
  Note: [why this grade]
```

Grade definitions:
- `GOOD` -- caught what it targeted, ran as designed
- `WEAK` -- passed but a real issue was found later that this should have caught
- `UNTESTABLE` -- couldn't run as designed (wrong preconditions, env issue, missing data)
- `WRONG-TIER` -- classified as WORKFLOW but was OUTPUT, or vice versa
- `REDUNDANT` -- duplicated another test's coverage entirely
- `MISSING` -- an issue was found that NO existing test covered (add this as a proposed test)

Calculate: **UAT Design Accuracy = tests graded GOOD / total tests x 100%**

List separately:
- Issues found OUTSIDE test coverage
- Tests that gave false confidence (passed but feature was broken)
- Proposed new test patterns for the gaps

## Step 5: Report Cross-Reference

If `report.md` exists, compare plan vs reality:

- **Divergence:** Phases that went differently than planned (longer, different approach, skipped steps)
- **Suspiciously clean phases:** 0 issues in a phase = potential under-testing. Flag it.
- **High-issue phases:** 3+ issues = needs better upfront analysis. What was missed in planning?
- **Rollback validity:** Given what we learned, would the documented rollback actually work?
- **Test data discipline:** Was all test data scoped to `dev@example.com`? Cleaned up?

## Step 6: Pipeline Fidelity Check

Trace the work through every stage of the pipeline. At each boundary, check: was anything lost, invented, or mutated?

### Locate artifacts

Find which artifacts exist for this task (not all will exist for every session):

| Stage | Artifact | Location |
|-------|----------|----------|
| Request | User's original message | Conversation context |
| Spec | Spec document (if written) | `docs/specs/` or conversation |
| Plan | Plan document | `.claude/work/PROJ-NNN-name/plan.md` |
| Implementation | Changed files | `git diff` or conversation context |
| Report | Implementation report | `.claude/work/PROJ-NNN-name/report.md` |
| Ship | PR description + deploy evidence | GitHub PR |

### Check each boundary

**Request -> Spec/Plan** (Intent preservation)
- Requirements in user's request that are NOT in the plan: [list or "none"]
- Things in the plan that the user did NOT ask for: [list or "none"]
- Ambiguities in the request that the plan resolved -- did the plan assume or ask? [list]
- Verdict: `FAITHFUL` | `DRIFT` | `SCOPE-CREEP` | `SCOPE-LOSS`

**Plan -> Implementation** (Execution fidelity)
- Plan phases that were implemented as written: [list]
- Plan phases that were modified during implementation -- why?: [list]
- Plan phases that were skipped entirely: [list]
- Unplanned changes made (not in any phase): [list]
- Verdict: `FAITHFUL` | `DRIFT` | `SCOPE-CREEP` | `SCOPE-LOSS`

**Plan UATs -> Report UATs** (Test fidelity)
- UATs in plan that appear in report with matching criteria: [count]
- UATs in plan that are MISSING from report: [list -- these are coverage gaps]
- UATs in report that are NOT in plan: [list -- were tests invented post-hoc?]
- UATs where pass criteria changed between plan and report: [list -- was the bar lowered?]
- Verdict: `FAITHFUL` | `DRIFT` | `TESTS-DROPPED` | `BAR-LOWERED`

**Success Criteria -> Evidence** (Proof completeness)
- For each success criterion in the plan:
  - Criterion: [text]
  - Evidence provided: [specific report section/test/command output, or "NONE"]
  - Verdict: `PROVEN` | `CLAIMED` | `MISSING`
- Any criterion marked CLAIMED (asserted without evidence) or MISSING is a red flag.

**Report -> Actual State** (Truth check)
- If time permits, spot-check 2-3 claims from the report against reality:
  - Claim: [what report says]
  - Check: [command run or file read]
  - Match: `YES` | `NO` | `STALE`

### Pipeline Fidelity Score

```
Request -> Plan:    FAITHFUL | DRIFT | SCOPE-CREEP | SCOPE-LOSS
Plan -> Impl:       FAITHFUL | DRIFT | SCOPE-CREEP | SCOPE-LOSS
Plan UATs -> Report: FAITHFUL | DRIFT | TESTS-DROPPED | BAR-LOWERED
Criteria -> Evidence: N/M PROVEN, N CLAIMED, N MISSING
Report -> Reality:  N/N spot-checks passed
```

Flag any boundary with a non-FAITHFUL verdict for discussion in Step 7 learnings.

## Step 7: Extract Learnings

Categorize into three buckets:

### Gotchas
- Pattern: what happened
- Fix: what we did
- Prevention: what would avoid it next time (hook? memory? skill update?)

### Discoveries
- Codebase fact or tool behavior learned
- Where it applies going forward

### Process Gaps
- What was missing from our workflow
- Concrete fix (new hook, skill update, memory entry, past-errors rule)

## Step 8: Update Memory

For each learning, route to the right destination:

| Type | Destination |
|------|-------------|
| Recurring error pattern | `past-errors.md` -- append new numbered rule |
| Codebase fact | `MEMORY.md` or topic file -- add/update entry |
| Debugging technique | `debugging_patterns.md` -- add pattern |
| UAT design pattern | Propose addition to plan template UAT section |
| Process improvement | Propose hook or skill change |
| One-off insight | Skip -- not worth persisting |

Rules:
- Check if similar memory exists before writing (grep first)
- Only persist things confirmed by evidence this session
- **Present ALL proposed updates to user before writing anything**

## Step 9: Output

```
## Session Retro: [Task ID]

**Efficiency Score:** X/25
**Errors encountered:** N (N preventable)
**UAT Design Accuracy:** X%
**Learnings:** N gotchas, N discoveries, N process gaps

### Error Heat Map
env: N | schema: N | api-contract: N | stale-context: N
tool-misuse: N | logic: N | integration: N | build: N

### Pipeline Fidelity
Request -> Plan:       FAITHFUL | DRIFT | SCOPE-CREEP | SCOPE-LOSS
Plan -> Impl:          FAITHFUL | DRIFT | SCOPE-CREEP | SCOPE-LOSS
Plan UATs -> Report:   FAITHFUL | DRIFT | TESTS-DROPPED | BAR-LOWERED
Criteria -> Evidence:  N/M PROVEN, N CLAIMED, N MISSING
Report -> Reality:     N/N spot-checks passed

### What went well
- [bullet list]

### What to improve
- [bullet list with specific actions]

### Proposed Memory Updates
1. [file] -- [change description]
2. [file] -- [change description]

### Proposed New Past-Error Rules
- Rule N+1: [description]

### Proposed UAT Additions
- [new test pattern for plan template]

Approve updates? (y/n/edit)
```

**STOP and wait for approval before writing any files.**
