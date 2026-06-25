---
name: zoom-out
description: Re-orient to the big picture during implementation. Shows current phase, objective, where you are in the user journey, which UAT you're satisfying, success criteria progress, and code architecture context. Use when lost in details, debugging rabbit holes, or before making decisions.
---

# Zoom Out — Big Picture Re-orientation

You've been deep in implementation details. Stop. Re-orient across five layers before continuing.

## Step 1: Find Context Anchors

Automatically detect:
- What files have been read/edited in recent conversation turns?
- Is there an active plan? Find the most recently modified `.claude/work/PROJ-*/plan.md`
- Is there an implementation report in progress? Check for `report.md` in the same directory
- What phase appears to be in progress? (scan plan for last phase section discussed, or check report progress)

If no plan found: skip to Layer 5 (code architecture only — the old zoom-out behavior).

## Step 2: Output Five Layers

Output these five sections. Each must be ONE short paragraph — this is a quick re-orientation, not a report.

### Layer 1: THE MISSION (from plan Section 2)

What is this feature? Why does it exist? One sentence from the plan summary.

### Layer 2: WHERE YOU ARE (from plan Section 12)

Which phase, what's its objective, rough progress within the phase. Flag if you appear to be working on a file not listed in the current phase (drift warning).

### Layer 3: THE USER JOURNEY (from plan Section 3)

List all workflow steps from Section 3. Mark completed ones, mark the current one with an arrow. Show where the current code work fits in the end-to-end user experience.

### Layer 4: WHAT PROVES THIS WORKS (from Section 3 Success Criteria + Section 12 UAT)

Which specific UAT test will prove the current work is done? Quote it. Which success criteria checkboxes is this work advancing? Mark completed vs remaining.

### Layer 5: CODE ARCHITECTURE

The module map — what file you're in, what calls it, what it calls, where data flows. This is what the old zoom-out skill did.

## Step 3: Flag Drift

If the files being edited don't match the current phase's file list from the plan:

```
DRIFT WARNING: You've been editing [file] but that belongs to Phase N.
Current phase is Phase M. The plan says Phase M must pass all UATs
before Phase N work begins.
```

## Step 4: Suggest Next Action

Based on current state:
- If mid-implementation: "Finish [specific thing] then run [specific UAT test]"
- If debugging: "You've been on this for N turns. Consider: is this blocking the phase objective, or a rabbit hole?"
- If between phases: "Phase N complete. Run /zoom-out after reading the next phase section."

## Design Principles

- FAST — read one plan file, output structured text. No subagents, no web fetches.
- NON-DESTRUCTIVE — pure read, never edits anything.
- ALWAYS AVAILABLE — works without a plan (falls back to Layer 5 only).
- SHORT — five paragraphs, not five pages. Re-orient in 10 seconds.
