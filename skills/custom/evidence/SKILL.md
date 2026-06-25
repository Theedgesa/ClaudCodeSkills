---
name: evidence
description: Force evidence gathering before any claim. Use when catching unverified assertions, before marking UATs as PASS, before commits, before deploys. Companion to the weasel-word Stop hook.
---

# Evidence — Prove It Before You Claim It

You made a claim. Now prove it. No assertion without execution output.

## Step 1: Identify the Claim

Extract the specific assertion from the most recent response or the user's challenge:

```
CLAIM: "[exact statement being verified]"
```

If the user invoked this without a specific claim, review your last 2-3 responses and identify any unverified assertions.

## Step 2: Classify Evidence Needed

| Claim Type | Required Evidence |
|-----------|-------------------|
| "Code works" / "Fix works" | Run it. Show output. |
| "Server starts" | pm2 logs or dev server stdout — show the listening line |
| "Migration ran" | SELECT query showing the new column/data exists |
| "Build passes" | Actual `npm run build` output with exit code |
| "UI shows X" | Load the page, describe what's visible |
| "No regressions" | Load adjacent pages, run existing tests |
| "Doesn't affect X" | Read the code path for X, show it's untouched, or test X |
| "Error is fixed" | Reproduce the original error scenario — show it now succeeds |
| "Data flows correctly" | DB query at source AND destination |
| "Test passes" | Full test execution output, not just "PASS" |

## Step 3: Gather Evidence

For each piece of required evidence, EXECUTE the command or action. Do not describe what would happen — run it and show the output.

Format each piece:

```
EVIDENCE [N]:
  Command: [what was run]
  Output: [actual output, copy-pasted]
  Proves: [which part of the claim this confirms]
```

## Step 4: Grade

| Grade | Meaning |
|-------|---------|
| CONFIRMED | Executed live, output matches claim exactly |
| PARTIAL | Some evidence gathered but gaps remain — list the gaps |
| UNVERIFIABLE | Cannot verify right now — explain why honestly (needs production access, needs real payment, needs third-party service) |
| REFUTED | Evidence contradicts the claim — STOP, fix the issue |

## Step 5: Output

```
CLAIM: "[statement]"
GRADE: [CONFIRMED / PARTIAL / UNVERIFIABLE / REFUTED]

Evidence:
- [command]: [output summary]
- [command]: [output summary]

Gaps (if PARTIAL): [what couldn't be verified and why]
Reason (if UNVERIFIABLE): [honest explanation]
Contradiction (if REFUTED): [what the evidence actually shows]
```

If REFUTED: Do not continue with the original plan. Fix the issue first.

## Hard Rules

1. **Reading code is not evidence that code works.** Code review is not evidence. Evidence = execution output.
2. **A passing build is not evidence of correct behavior.** `npm run build` proves syntax, not business logic.
3. **grep output is not evidence of a workflow.** Finding a string in a file proves the string exists, not that the workflow functions.
4. **"I tested this earlier" is not current evidence.** Code changes since "earlier" invalidate prior evidence. Evidence must be from the current state.
5. **Absence of errors is not evidence of correctness.** "No errors in logs" might mean the code path was never hit.
6. **UNVERIFIABLE is an honest answer.** If you cannot test it, say so. Mark it. Do not fake a PASS.
7. **Never grade CONFIRMED without showing the actual output.** The output is the evidence. Without it, the grade is meaningless.
