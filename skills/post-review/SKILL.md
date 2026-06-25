---
name: post-review
description: Structured code review after implementation. Checks plan alignment, past-errors compliance, architecture rules, RBAC, REQ scoring, CR audit, security, performance, and deletion opportunities. Use after completing a phase, before creating a PR, when asked to review code, conduct PR reviews, or give feedback on code quality.
---

# Post-Review — Code Review After Implementation

Review code that was just written. Check it against the plan, spec REQs, past-errors rules, architecture patterns, CR protocol, and REQ scoring coverage.

## Step 1: Scope the Review

Determine what changed:
- List all files modified in this session or since last commit
- Group by: backend / frontend / database / config
- Identify which plan phase these changes belong to
- Pull the phase objective and REQ gate table from the plan (plan S5)
- Load the spec referenced in the plan header — extract all REQs from spec S6.1

## Step 2: Plan & Spec Alignment (Method-Level)

For each changed file:

### File listed in plan?
- YES → verify the change matches what the plan describes (plan S2.1 Change Manifest)
- NO → flag: is this a necessary supporting change, or scope creep?
- If scope creep: recommend removal or plan update

### Methodology match (plan S1.3)?
- If plan says "copy-exact" and code was refactored → CONFLICT
- If plan says "new endpoint" and code modified existing → CONFLICT
- If plan says "edit file X" and a new file was created instead → CONFLICT

### Method-level comparison (plan S4 + spec)

For each method/function the plan describes with pseudocode or flow traces:

1. **Read the plan's flow traces** (plan S4 Cross-Service Data Flow) and the **spec design** (spec S4) side by side
2. **Read the actual code** — compare line by line:
   - **Signature:** Same parameters? Extra/missing params? Type differences?
   - **SELECT columns:** Does the code select the same columns the plan/spec lists? Missing columns the code later uses = plan bug
   - **Filters/WHERE:** Same conditions? Code adds `.or()` or handles NULL that plan didn't mention?
   - **INSERT/UPDATE fields:** Code includes fields the plan omitted? Plan includes fields the code doesn't?
   - **Return shape:** Same structure? Extra/missing fields?
   - **Side effects:** Plan says INSERT into table X — does code do it directly, or delegate to another service that does it? Duplicate inserts?
   - **Error handling:** Plan says "non-blocking" — does code wrap in try/catch?
   - **Date/timezone:** All date computations within the module use the same timezone?

3. **Classify each deviation:**
   - **Plan bug** — plan pseudocode was incomplete/wrong, code is correct
   - **Spec oversight** — spec interface didn't account for real dependency
   - **Code bug** — code deviates incorrectly from plan/spec
   - **Code improvement** — code is more robust than plan specified

4. **Action for each deviation:**
   - Plan bug → update plan to match code
   - Spec oversight → update spec to match code
   - Code bug → fix the code
   - Code improvement → document in report, update plan/spec if significant

Output a table per method:
```
### method_name() — Plan S4 / Spec S4
| Aspect | Plan/Spec | Code | Match? |
|--------|-----------|------|--------|
| Signature | (params) | (params) | MATCH/DEVIATION |
| SELECT | columns | columns | MATCH/DEVIATION |
| Filters | conditions | conditions | MATCH/DEVIATION |
| Return | shape | shape | MATCH/DEVIATION |
| Side effects | description | description | MATCH/DEVIATION |

Deviations:
- [#] [aspect]: [plan says X, code does Y]. Classification: [plan bug/spec oversight/code bug/improvement]. Action: [fix code/update plan/update spec/document]
```

## Step 3: Past-Error Cross-Check (`/check-errors`)

Run `/check-errors` against the changed files. This loads all four error sources (past-errors rules, debugging patterns, claude-mem observations, architecture rules) and produces a structured comparison.

- If any RISK or VIOLATION is found: add to BLOCKERS section
- Include the `/check-errors` summary in the output report

## Step 3.5: Past-Errors Pattern Scan (Detail)

Read `.claude/rules/anti-patterns/past-errors.md`. For each changed file, check every relevant rule:

- Profile code → Rule #2 (no guest profiles)
- UUID generation → Rule #5 (explicit UUIDs for auth tables)
- SQL migration → Rule #7 (BEGIN/COMMIT)
- Supabase queries → Rule #12 (verify data end-to-end)
- Column changes → Rule #15 (check is_nullable via information_schema)
- Data transformations → Rule #16 (trace through every step)
- Payment code → Rule #17 (test one order per payment method)
- Frontend code → Rule #20 (test through frontend, not curl)
- Env files → Rule #23 (audit all .env* before frontend deploy)

For each relevant rule: state whether the code complies or violates.

## Step 4: Architecture Compliance

Load the relevant architecture rule file and check:

### Security
- No hardcoded secrets (API keys, tokens, passwords)
- Input validation on all req.body / req.params / req.query
- Parameterized queries ($1, $2), not string concatenation
- Auth middleware on every new route
- RBAC permission on protected routes: `requirePermission('key')`

### MyProject patterns
- Location code uses `locationService` methods, not hardcoded slugs
- Pass code uses `passCategoryService`, not hardcoded category strings
- Financial code branches on `financial_behavior`, not category name
- Supabase queries check for errors (not silently null)
- Location filtering uses `buildLocationFilter()`, not raw WHERE
- Email sending uses `emailService` / `emailProviderService`

### Code quality
- Follows existing structure in the same file
- Uses existing services — not reinventing
- Structured logging (feature-scoped logger), not console.log
- Error handling: try/catch with logger.error + context
- No dead code, no commented-out code, no unused imports

### Quality gate
- Was `npm run quality` run and documented in the report?
- Did it pass (exit 0)?
- If not documented: flag as BLOCKER — "Quality gate not evidenced"

### codebase-memory (cross-stack changes only)
- Were cross-stack changes made (server + frontend)?
- Was `trace_call_path` queried before editing?
- If not: flag as WARNING — "Cross-stack change without graph query"

### Dead calls check
- Run `node scripts/require-check.mjs --files <changed-files>` on every modified JS file
- Any new unresolved method calls? → flag as BLOCKER
- Any try/catch wrapping a service call with hardcoded fallback? → flag as WARNING — "Silent failure pattern"

### Deletion check
- Any dead code in files touched? → flag for removal
- Any commented-out code? → flag for removal
- Any unused imports? → flag for removal
- Could new code reuse an existing util? → flag

## Step 4.5: Verification Agent (Mandatory)

Dispatch a dedicated subagent whose ONLY job is to independently verify the completeness and correctness of changes. This agent operates in a fresh context — it does not trust your claims from implementation.

**Dispatch the agent with this prompt template** (fill in the changed files list):

```
You are a VERIFICATION AGENT. Your job is to independently verify code changes.
You do NOT trust the implementer's claims. You verify everything yourself.

## Changed files to verify:
[list each changed file path]

## For EACH function whose signature was changed or newly created:

### 1. CALLER SEARCH
Find ALL callers of this function across the entire codebase:
- Run: sg -p 'functionName($$$)' --lang js server/ finance-service/
- If codebase-memory is available: use search_graph for transitive callers
- List EVERY caller with file:line
- Count: N callers found

### 2. PARAMETER VERIFICATION
For each caller found:
- Does the caller pass the new/changed parameters? Quote the call site.
- Where does the caller get those parameter values from? Trace to origin.
- If parameter is missing at any call site: flag as RED.

### 3. DATA FLOW TRACING
For each data value that flows through changed code:
- What is its type/shape at source?
- What type/shape does the destination expect?
- Are there implicit conversions? (null->"null", undefined->"undefined", snake_case vs camelCase)
- For DB payloads: compare producer key names to consumer destructuring (exact match, case-sensitive)

### 4. RETURN VALUE CONSUMERS
For each function whose return value changed:
- Who consumes the return value?
- Do they destructure it correctly?
- Does the new shape match what consumers expect?

## Output format (one block per function):

FUNCTION: [name] at [file:line]
SIGNATURE: [old] -> [new]

CALLERS FOUND: N
  1. [file:line] — param passed: YES/NO — quoted: "[call site code]"
  2. [file:line] — param passed: YES/NO — quoted: "[call site code]"

DATA FLOWS:
  [source:type] -> [destination:expected] — MATCH/MISMATCH: [detail]

PAYLOAD SHAPES:
  Producer [file:line] keys: [list]
  Consumer [file:line] destructures: [list]
  MATCH/MISMATCH: [detail]

VERDICT: GREEN / AMBER / RED
ISSUES: [list problems, or "none found"]

## SUMMARY
Total functions verified: N
GREEN: N | AMBER: N | RED: N
BLOCKING ISSUES: [list, or "none"]
```

**Evaluation:**
- If ANY function has a RED verdict: add to BLOCKERS
- If AMBER verdicts exist: add to WARNINGS
- If verification agent finds callers the implementer missed: BLOCKER

**This step is NOT optional.** The verification agent catches missed callers (tenantId threading), data shape mismatches (JSONB casing), and implicit type conversions.

## Step 5: Proposed-vs-Existing Conflict Check

For each change that modifies an existing flow:
- Does the change introduce a new parameter? → Is there a test WITHOUT it (backward compat)?
- Does the change alter behavior? → Is there a test proving OLD behavior no longer occurs?
- Does the change touch a shared utility? → Are all other callers still working?

## Step 5.5: Change Record Audit

Check compliance with `.claude/rules/process/change-records.md`:

1. **Were CRs created during this phase?** Read the plan's `## Change Records` section.
2. **For each CR:** Verify the propagation checklist is complete:
   - Spec updated (section + REQ reference)
   - Plan updated (phase + REQ gate)
   - Code matches updated spec and plan
3. **CR trigger scan:** Check the git diff for objective CR triggers:
   - Schema changes (new column, altered constraint, new trigger)
   - API response shape changes (new/removed field, changed type)
   - Auth/permission changes (different middleware, different key)
   - State machine changes (new status, different transition)
   - Business rule changes (different calculation, different condition)
4. **If CR triggers found but no CR exists:** BLOCKER — "Objective CR trigger detected but no CR created"
5. **Suspicious zero-CR check:** If 3+ phases completed with 0 CRs total, flag as suspicious: "Zero CRs across [N] phases — complex implementations without a single design change discovered during implementation are statistically unlikely. Justify or review."

## Step 5.6: REQ Scoring Verification

Verify the phase gate scoring from the plan (plan S5):

1. **Load all REQs** from spec S6.1
2. **Check phase gate table:** Every spec REQ must appear in the phase gate table
3. **Verify Green REQs:** Each Green REQ must have T3+ execution evidence pasted (not prose). Check for rejected patterns: "verified", "confirmed", "looks correct", "handles this", "by inspection", "as expected"
4. **Verify Orange REQs:** Each Orange REQ must name the future phase that turns it Green. Orange must mean "code path to test literally doesn't exist yet" — not "I could test it but didn't"
5. **Verify no Red REQs:** Any Red = gate blocked
6. **Regression check:** Compare this phase's scoring to previous phase. Any Green→Red = BLOCKER
7. **Dimension coverage:** All 9 spec dimensions at 100% for testable REQs. If not, flag which dimensions are below 100%
8. **High-effort REQs:** All testable H-effort REQs must be executed this phase — not deferred

## Step 6: Output

```
## Post-Review: PROJ-NNN Phase N — [Name]

### VERDICT: APPROVE / NEEDS WORK / REJECT

### BLOCKERS (must fix before proceeding)
- [file:line] [issue description]

### WARNINGS (should fix)
- [file:line] [issue description]

### PLAN ALIGNMENT
- [file] — matches plan S2.1: YES/NO, deviation: [description]

### VERIFICATION AGENT
- Functions verified: N
- GREEN: N | AMBER: N | RED: N
- Missed callers: [list, or "none"]
- Data flow mismatches: [list, or "none"]
- Payload shape mismatches: [list, or "none"]

### PAST-ERRORS FLAGS
- Rule #N: [compliant/violated] — [detail]

### ARCHITECTURE
- [pattern]: [compliant/violated]

### PROPOSED-vs-EXISTING
- [conflict description, or "no conflicts found"]

### CHANGE RECORD AUDIT
- CRs created this phase: [count]
- CR triggers in diff: [count detected / all have CRs: YES/NO]
- Propagation complete: [YES/NO — list incomplete CRs]
- Suspicious zero-CR: [YES/NO]

### REQ SCORING
- Green: [X]/[total] — all with T3+ evidence: YES/NO
- Orange: [Y]/[total] — all with future phase: YES/NO
- Red: [count] (must be 0)
- Regressions (Green→Red): [count] (must be 0)
- High-effort (H) executed: [X]/[Y testable]
- Dimension coverage: [list any below 100%]

### DELETION OPPORTUNITIES
- [file:line] [what to remove]

### POSITIVE
- [what's done well]

### RECOMMENDATION
[specific next steps to reach APPROVE]
```

## Review Techniques

### Severity Labels
- **[blocking]** — Must fix before merge
- **[important]** — Should fix, discuss if disagree
- **[nit]** — Nice to have, not blocking
- **[suggestion]** — Alternative approach to consider
- **[learning]** — Educational comment, no action needed

### The Question Approach
Ask questions instead of stating problems:
- "What happens if `items` is an empty array?" (not "This will fail if empty")
- "How should this behave if the API call fails?" (not "You need error handling")

### Line-by-Line Checks (for each changed file)
- **Logic** — Edge cases, off-by-one, null checks, race conditions
- **Security** — Input validation, injection risks, XSS, sensitive data exposure
- **Performance** — N+1 queries, unnecessary loops, missing indexes, memory leaks
- **Maintainability** — Clear naming, single responsibility, no magic numbers
