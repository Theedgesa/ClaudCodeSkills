---
name: cr
description: Create a Change Record when a bug or design change is discovered during implementation. Use when you find something that changes the design, when the user catches you making undocumented changes, or when a hook warns about CR triggers. Invoke with /cr.
---

# CR — Change Record

You found something during implementation that changes the design. Or the user caught you making changes without documenting them. Either way, stop and create a CR now.

**Announce at start:** "Creating Change Record for the current change."

---

## When to Invoke

- You fix a bug during implementation that changes how something works
- You discover a schema/API/auth/state/business-rule difference from the spec
- The `cr-propagation-guard.sh` hook warned about a CR trigger
- The user says "that's a CR", "you changed X without a CR", or invokes `/cr`
- You're about to change something the plan didn't anticipate

---

## Step 1: Identify the Change

What changed? Be specific with evidence.

```
CHANGE DETECTED:
- What I was doing: [phase N, step, file]
- What I expected: [what spec/plan said]
- What actually happened: [the bug, mismatch, or needed deviation]
- Evidence: [error output, query result, code at file:line]
```

If the user invoked this because they caught you: read the recent conversation and git diff to identify what you changed.

## Step 2: Classify Against Objective Triggers

Check each trigger from `.claude/rules/process/change-records.md`:

| Trigger | Detected? | Evidence |
|---------|-----------|----------|
| Database schema change (new column, altered constraint, new trigger) | YES/NO | [what changed] |
| API response shape change (new/removed field, changed type) | YES/NO | [what changed] |
| Auth/permission change (different middleware, different key) | YES/NO | [what changed] |
| State machine change (new status, different transition) | YES/NO | [what changed] |
| Business rule change (different calculation, different condition) | YES/NO | [what changed] |

**If ANY trigger = YES → spec-level CR (mandatory)**
**If all triggers = NO → check the 3 code-only conditions:**

1. Would any REQ's verification method or expected output change? → If yes, not code-only
2. Would any spec section's design description change? → If yes, not code-only
3. Is any invariant from spec S5 affected? → If yes, not code-only

**All 3 = NO → code-only (no CR needed, document in report and move on)**

## Step 3: Find the Active Plan

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
ACTIVE=$(cat "$PROJECT_ROOT/.claude/work/.active" 2>/dev/null)
PLAN="$PROJECT_ROOT/.claude/work/$ACTIVE/plan.md"
```

Read the plan. Find the `## Change Records` section (create it at the end if it doesn't exist). Count existing CRs to determine the next number.

## Step 4: Find the Spec

Read the plan header `**Spec:**` field. Open the spec file.

## Step 5: Write the CR

Append to the plan's `## Change Records` section:

```markdown
### CR-NNN: [Title]
**Found during:** Phase N implementation / UAT / user review
**Root cause:** [What was wrong — with evidence]
**Impact:** Spec-level / Plan-level / Code-only

**What changed:**
- Old behavior: [what spec/plan said]
- New behavior: [what needs to happen]
- Evidence: [log output, error message, test failure output]

**Propagation checklist:**
- [ ] Spec updated (section N, REQ-NNN added/modified)
- [ ] Plan updated (phase N, step N)
- [ ] New REQs added to scoring framework with tier and verification method
- [ ] Affected dimension scores recalculated
- [ ] Code matches updated spec and plan
```

## Step 6: Propagate

For **spec-level** CRs:

1. **Update the spec** — edit the affected section (S3 criteria, S4 design, S5 risk, S6 REQs)
2. **Add/modify REQs** — if the change introduces a new requirement, add it to spec S6.1 with proper tier and verification method
3. **Update the plan** — edit the affected phase gate table, add the new REQ to all phase gates
4. **Update plan S1.2** — Expected REQ Progression if total REQ count changed

For **plan-level** CRs:

1. **Update the plan** — edit the affected phase, data flow (S4), or deploy steps (S7)
2. **No spec changes needed**

For **code-only**:

1. **No CR entry needed** — document in the phase gate report checkpoint instead
2. State: "Code-only fix: [description]. No REQ/spec/plan changes needed because [justification]."

## Step 7: Check Off Propagation

After all updates, re-read the CR entry and check off each propagation item:

```markdown
**Propagation checklist:**
- [x] Spec updated (S6.1 — added REQ-NNN)
- [x] Plan updated (Phase 2 gate table — REQ-NNN added)
- [x] New REQs added to scoring framework with tier and verification method
- [x] Affected dimension scores recalculated
- [x] Code matches updated spec and plan
```

## Step 8: Announce

```
CR-NNN created: [title]
Impact: [spec-level / plan-level / code-only]
Spec updated: [YES — sections X, Y / NO]
Plan updated: [YES — phase N gate / NO]
New REQs: [REQ-NNN added / none]

Propagation complete. Continuing with Phase N.
```

---

## Hard Rules

1. If the user says "that's a CR" — it's a CR. Don't argue classification.
2. Objective triggers are always spec-level. No discretion.
3. Every CR gets a number, even if it turns out to be code-only (audit trail).
4. Propagation must be done NOW, not "later" or "after this phase."
5. The CR entry lives in the plan file, not a separate document.
6. If you already made the code change without a CR — create the CR retroactively and propagate. The change happened; document it.
