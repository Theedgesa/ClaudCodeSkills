---
name: verify-plan
description: Verify Plan — API Surface Verification Gate. Checks every function call, column name, DB constraint, REQ-to-phase mapping, and Change Manifest completeness against actual source code. Mandatory gate before plan approval.
---

# Verify Plan — API Surface Verification Gate

Verify every function call, method reference, column name, DB constraint, REQ coverage, and Change Manifest entry in a plan against actual source code. Mandatory gate before plan approval, alongside `/uat-design`.

**Announce at start:** "Running /verify-plan on `<plan-path>`."

---

## When to Use

- Mandatory: Before plan approval (enforced by /plan skill exit gate)
- Manually: When reviewing a plan that calls existing functions or modifies DB schemas
- After `/critique-plan` finds verification issues

## Input

Accepts one argument: path to the plan file.

- If no argument provided, find the most recently modified plan in `.claude/work/*/plan.md`
- If multiple candidates, ask which one

## Process

### Step 1: Extract All References

Read the full plan. Also read the spec referenced in the plan header. Extract every reference to:

**Functions & Methods:**
- Any `serviceName.methodName()` call
- Any `controllerName.methodName()` call
- Any `supabaseAdmin.` chain
- Any `require('...')` or import path
- Any helper function called (e.g., `_resolvePass`, `linkPastShopifyOrders`)

**Database:**
- Column names referenced in SELECT, INSERT, UPDATE statements
- Table names
- Constraint assumptions (NOT NULL, FK, UNIQUE)
- Trigger function names

**Request/Response shapes:**
- `req.propertyName` references (what middleware sets them?)
- Response object shapes (does a `.map()` pass through new fields?)
- Frontend type/interface names

**External APIs:**
- SDK method calls (Supabase, Shopify, Zoho, etc.)
- Parameter shapes
- Return value shapes

### Step 2: Dispatch Verification Agent

Launch an Explore agent for each group (max 3 parallel). Each agent:

1. Reads the actual source file referenced
2. Confirms the function/method EXISTS at the claimed location
3. Verifies the EXACT signature (params, return type)
4. Checks constraints (NOT NULL, required params, nullable columns)
5. Reports PASS or FAIL with evidence (file path, line number, actual signature)

**Agent prompt template:**
```
Verify these function/method/column references from plan [path] against actual source code in [repo-root].

For each item:
1. Read the source file
2. Find the function/method/column
3. Report: EXISTS or DOES NOT EXIST
4. If EXISTS: exact signature, file path, line number
5. If EXISTS but different from plan: describe the mismatch
6. If DOES NOT EXIST: what similar thing exists? (suggest correction)

Items to verify:
[list extracted references]
```

### Step 3: Check Response Shape Survival

For every plan change that adds a field to an API response:

1. Find the controller method that builds the response
2. Check if there's a `.map()` or explicit object construction that would DROP the new field
3. If yes: flag as "field will be dropped by response mapping at [file:line]"
4. Check if the frontend type/interface includes the field
5. If no: flag as "frontend type missing field"

### Step 4: Check DB Constraint Compatibility

For every DB operation in the plan:

1. Identify the table and columns involved
2. Check NOT NULL constraints on columns receiving values from the plan
3. Check FK constraints on referenced IDs
4. Check if nullable assumptions match reality
5. Flag any plan code that passes NULL to a NOT NULL column

**Step 4b: Check Column Types for Migration SQL**

For every `UPDATE table SET column = expression` or `INSERT INTO table (column) VALUES (expression)` in migration SQL (plan S3):

1. Query `SELECT data_type, udt_name FROM information_schema.columns WHERE table_name = 'X' AND column_name = 'Y'`
2. Verify the expression's output type matches the column type
3. Flag any type mismatch as FAIL

**Step 4c: Check Existing Function Body for Replacement SQL**

For every `CREATE OR REPLACE FUNCTION` in migration SQL (plan S3):

1. Query `SELECT prosrc FROM pg_proc WHERE proname = 'func_name'` to read the current function
2. Verify the replacement function produces the same **output type/format** for each column it writes to
3. Flag any output format mismatch as FAIL

Incident: PROJ-137 migration used `count(*)` (INT) for `member_hub.active_passes` (JSONB). Would have broken the entire member hub.

**Step 4d: Check Shared Mutable State Between New Methods**

For every new method that writes to a database table:

1. Identify which table and column the method modifies
2. Search for other methods in the same flow that READ from the same table with a filter on the modified column
3. If found: verify the plan specifies sequential execution (await). If concurrent/fire-and-forget, flag as FAIL: "race condition"
4. The writer must complete before readers execute, unless the plan documents why concurrent is safe

Incident: PROJ-137 — `handleGuestAccount` writes `unified_passes.for_someone_else=false`, `sendOrderConfirmationEmail` reads `WHERE for_someone_else=true`. Non-blocking call created race condition.

**Step 4e: Check Pseudocode Source Citations**

For every block of plan pseudocode (plan S5 phases) that copies or mirrors existing code:

1. Verify the pseudocode cites the source file and line number
2. Read the actual source and compare: date format, query order, column types, variable names
3. Flag any pseudocode that uses a different pattern than the cited source

Incident: PROJ-137 plan pseudocode had 3 bugs from uncited patterns.

**Step 4f: Verify Frontend Components Render Referenced Fields**

For every REQ or success criterion that references a visible UI element:

1. Identify the frontend component that renders the element
2. Use `sg` to search the component for the field name
3. If zero matches: FAIL — "Component has no reference to field"
4. Check the TypeScript type — if the field is missing, it will be silently dropped
5. Check git history for intentional removal

Incident: PROJ-104 plan stated "Day pass cards show capacity status" but component had zero capacity references.

**Step 4g: Verify FK Insert Order for Multi-Table Batches**

For every plan that has INSERT statements into multiple tables within the same transaction (plan S3):

1. Identify all tables being inserted into
2. Query FK constraints between them
3. Build dependency graph: parent must be inserted first
4. Verify plan's INSERT order is topologically sorted
5. If out of order: FAIL

Incident: PROJ-150 inserted into child table before parent — all batches failed with FK violation.

**Step 4h: Verify SDK Method Exports for Third-Party Wrappers**

For every plan that wraps third-party SDK methods:

1. Identify the SDK package name and methods being wrapped
2. Run: `node -e "const pkg = require('<package>'); console.log(Object.keys(pkg).join(', '))"`
3. Verify each wrapped method exists and param count matches
4. If method doesn't exist: FAIL

Incident: PROJ-150 wrapped `EmailPassword.getUserByEmail()` which doesn't exist in supertokens-node v21.

**Step 4i: Verify Route Middleware Chains**

For every route that the plan modifies, creates, or rewrites (plan S2.2 middleware chain):

1. Read plan S2.2 for middleware chain documentation on modified routes
2. Read plan S5 phase changes for the route handler
3. **Cross-reference:** If S2.2 shows middleware requirements, verify S5 phase code preserves them
4. If S2.2 requires middleware but S5 pseudocode omits it — FAIL
5. **Existing route preservation:** Read the CURRENT route definition in source. Extract middleware. If the plan replaces the handler, verify it preserves all middleware.

Incident: PROJ-143 rewrote endpoints without `isAuthenticated` despite plan requiring it and original routes having it.

**Step 4j: Verify Object Property Access Chains**

For every `object.property.method()` in plan pseudocode:

1. Identify the object's class — trace to constructor or factory
2. Read the class definition file
3. For each `.property`, verify it exists as `this.property` in the constructor, a class method, or a module export
4. If the property is a **local variable** inside a method body — FAIL

Incident: PROJ-143 plan referenced `provider.svc.getInvoicePDF()` but `svc` was a local variable.

**Step 4k: Verify Temporal Bounds on Catch-Up Queries**

For every `setInterval`, `cron`, or scheduled function in the plan:

1. Identify the query that finds candidates
2. Check for BOTH upper and lower bounds on `created_at`
3. If **no lower bound** — FAIL: "will process entire historical backlog on first startup"
4. Also check: is the query result rate-limited with `.limit(N)`?

Incident: PROJ-143 safety net cron sent 125 emails to historical customers on first boot.

**Step 4l: Verify Cross-Section Consistency**

For every risk mitigation stated in spec S5, and every requirement in the spec's Success Criteria (S3):

1. Find the corresponding implementation detail in plan S5 (phases)
2. Verify the phase code implements the stated requirement
3. Flag contradictions:
   - Spec S5 says "requires auth" but plan S5 shows no middleware — FAIL
   - Spec S5 says "handle NULL tenant_id" but plan S5 doesn't show COALESCE — FAIL
4. For each plan S5 phase, check: does the REQ gate include a test that would catch if the requirement was omitted?

Incident: PROJ-143 spec stated "manual sync endpoints keep `isAuthenticated`" but plan phase pseudocode, implementation, and UAT all missed the requirement.

**Step 4m: Verify String-Match Queries Against Actual Data Format**

For every query in plan pseudocode that matches by string content (`ilike`, `LIKE`, `.includes()`, etc.):

1. Identify the target field being searched
2. Identify the match value being used
3. Trace what the target field actually contains
4. Compare: does the match value appear in the target field's format?
5. If not: FAIL — identify what value WOULD match

Incident: PROJ-143 email dedup used UUID prefix to match email subjects that contain order numbers. Never matched.

**Step 4n: Verify Migration SQL Consistency with Phase Descriptions**

For every SQL statement in plan S3 (Database Schema & Migration):

1. Find the corresponding phase in plan S5 that executes this SQL
2. Compare SQL parameters against phase description
3. Flag contradictions (bulk vs individual, different status values, missing operations)
4. Verify target column constraints

Incident: PROJ-161 — plan S3 had bulk UPDATE but plan S5 specified one-at-a-time resets.

### Step 5: REQ-to-Phase-Gate Verification (NEW)

Verify that every spec REQ is represented in at least one phase gate:

1. Load all REQs from spec S6.1
2. For each phase in plan S5, extract the REQ gate table
3. Build a matrix: REQ ID → which phases include it

| REQ ID | Phase 1 | Phase 2 | Phase 3 | In Any Gate? |
|--------|---------|---------|---------|-------------|
| REQ-001 | Green | Green | Green | YES |
| REQ-002 | Orange | Green | Green | YES |
| REQ-003 | — | — | — | NO → FAIL |

4. Any REQ missing from ALL phase gates = FAIL: "REQ-NNN not represented in any phase gate — will never be scored"
5. Any REQ that is Orange in the final phase = FAIL: "REQ-NNN is Orange in the last phase — when does it turn Green?"
6. Verify the plan's Expected REQ Progression (plan S1.2) is consistent with the phase gates

### Step 6: Change Manifest Completeness (NEW)

Verify plan S2.1 Change Manifest against spec S4 (Design):

1. Read spec S4 design — extract all files, functions, tables, and endpoints the design touches
2. Read plan S2.1 Change Manifest — extract all items
3. **Spec coverage:** Every file/function/table from the spec's design must appear in the Change Manifest. If missing: FAIL — "Spec design references [item] but Change Manifest doesn't include it"
4. **Verification completeness:** Every Change Manifest row must have a non-empty Result column with execution output (not prose). If empty: FAIL — "Change Manifest row [item] has no verification result"
5. **Action consistency:** If a Change Manifest row says Action = Create but verification shows item already exists → FAIL — "Plan says Create but item exists — change Action to Edit"

### Step 7: Run Past-Error Cross-Check

Invoke `/check-errors` on the plan. This loads all past errors, debugging patterns, and architecture rules.

- If `/check-errors` returns RISKS or VIOLATIONS: append to FAIL section
- Past-error RISKS count as FAIL items
- Architecture VIOLATIONS count as FAIL items

### Step 8: Produce Report

```
## Plan Verification Report for PROJ-NNN

### Summary
- References checked: N
- PASS: N
- FAIL: N
- WARNINGS: N

### PASS (verified against source)
| # | Reference | Source | Evidence |
|---|-----------|--------|----------|
| 1 | `emailService.sendGiftPassNotification(giftData)` | server/services/email.service.js:394 | Signature matches plan |

### FAIL (must fix before approval)
| # | Reference | Plan Says | Actual | Fix |
|---|-----------|-----------|--------|-----|
| 1 | `unified_passes.product_id` | Column exists | Column is `pass_type_id` | Replace all references |

### WARNINGS (review)
| # | Reference | Issue |
|---|-----------|-------|
| 1 | `listUsers()` | No pagination — defaults to 50 results |

### Response Shape Survival
| # | New Field | Controller | .map() at line | Survives? |
|---|-----------|-----------|---------------|-----------|
| 1 | `guestName` | dashboard.controller.js | lines 303-320 | NO — must add |

### DB Constraint Check
| # | Operation | Table.Column | Constraint | Compatible? |
|---|-----------|-------------|-----------|-------------|
| 1 | INSERT null | checkin_logs.user_id | NOT NULL | NO — will fail |

### REQ-to-Phase-Gate Coverage
| Status | Count |
|--------|-------|
| All gates covered | [X]/[total] |
| Missing from all gates | [list REQ IDs] |
| Orange in final phase | [list REQ IDs] |

### Change Manifest Completeness
| Status | Count |
|--------|-------|
| Spec items in manifest | [X]/[total] |
| Missing from manifest | [list items] |
| Empty verification results | [list items] |
| Action mismatches | [list items] |
```

### Step 9: Write Marker (if passing)

If all references PASS (zero FAIL items):

```
Write to: .claude/work/PROJ-NNN-name/.api-verified
Content:
verified YYYY-MM-DD
references-checked: N
pass: N
fail: 0
warnings: N
req-phase-coverage: [total]/[total]
manifest-completeness: [total]/[total]
```

If any FAIL items exist: do NOT write the marker. List failures and offer to fix.

### Step 10: Offer Fixes

For each FAIL item:
- Show the exact plan line(s) that need correction
- Propose the fix with the correct function name / column name / signature
- Ask permission before editing

---

## Hard Rules

1. Every function call in a plan must be verified against actual source — architecture docs drift
2. Column names must be verified against actual table schema
3. `req.propertyName` references must trace back to middleware that sets them
4. Response shapes must survive any `.map()` or explicit object construction
5. NOT NULL constraints must be checked before any plan code passes null/undefined
6. SDK method signatures must be verified against actual usage
7. Zero FAIL items required for `.api-verified` marker
8. Column **types** must be verified for migration SQL — existence alone is insufficient
9. Replacement trigger functions must be verified against current function body (`pg_proc.prosrc`)
10. Route middleware chains must be verified — plan S2.2 and plan S5 must be consistent
11. Object property chains must be verified against actual class definitions
12. Catch-up queries must have temporal lower bounds
13. String-match queries must be verified against actual data format
14. Migration SQL (plan S3) must be consistent with phase descriptions (plan S5)
15. Every spec REQ must appear in at least one phase gate — no orphaned REQs
16. Every Change Manifest row must have verification results — no unchecked assumptions
