---
name: uat-design
description: Verify spec REQs have adequate coverage — 4-path verification, T3+ evidence quality, no vague outcomes. Use before /plan or /implement, after editing REQs, or as Gate 2 of /review-gates.
---

# REQ Coverage Verifier

You are a REQ quality auditor. Your job is to verify that every REQ in the approved spec has realistic, adequate test coverage — proper evidence tiers, 4-path coverage across success criteria, specific expected outcomes, and independent verification methods.

## Step 1: Locate the Spec

Find the spec:
- If a plan exists at `.claude/work/PROJ-*/plan.md`, read its `**Spec:**` header field
- Otherwise check `docs/specs/*.md` — use the most recently modified with status `approved`
- If no spec found: "No approved spec found. Point me to a spec file."

Read the FULL spec file.

## Step 2: Extract REQs and Success Criteria

From the spec:
1. **Section 3 — Success Criteria** (SC table with quality standard)
2. **Section 6 — Requirements & Scoring** (REQ table: ID, dimension, tier, effort, description, verification method, expected outcome)

If either section is missing or empty, flag as structural gap — cannot proceed.

## Step 3: REQ Quality Audit

For each REQ, check all four quality dimensions. A REQ must pass ALL to be clean.

### A) Evidence Tier Appropriateness

| Tier | Acceptable For | Flag If Used For |
|------|---------------|-----------------|
| T1 (static analysis) | Code structure existence checks only | Functional, integration, or behavioral verification |
| T2 (unit/mocked) | Pure logic with no external dependencies | Anything crossing a DB, auth, or persistence boundary |
| T3+ (integration) | Functional, data integrity, security, UX, invariant REQs | — (always appropriate) |

Flag: `REQ-NNN: T[X] insufficient — [dimension] REQs require T3+ (boundary crossing)`

### B) Verification Method Realism

| Check | Status |
|-------|--------|
| Method is "inspect code", "read file", "verify by inspection" | REJECTED — code reading is discovery, not verification |
| Method references code/endpoints that don't exist yet | OK if plan creates it — note which phase |
| Method is executable (curl, SQL, browser action, `sg` command) | OK |

Flag: `REQ-NNN: verification method is prose, not execution — rejected per Evidence Standard`

### C) Expected Outcome Specificity

| Check | Status |
|-------|--------|
| "works correctly", "handles properly", "data appears", "page loads" | REJECTED — vague |
| "200 OK" or status code alone without business consequence | WEAK — must also verify table.field values |
| Exact values: row counts, field values, visible text, error messages | OK |
| Business outcome: `table.column = expected_value` after operation | OK |

Flag: `REQ-NNN: vague expected outcome "[text]" — must specify exact value/state`

### D) Verification Independence

| Check | Status |
|-------|--------|
| Verification calls the same function being tested and checks its return | REJECTED — circular |
| Verification uses an independent query/path (e.g., DB SELECT after API call) | OK |
| Verification reuses a try/catch fallback path that masks failure | REJECTED — see PROJ-082 |

Flag: `REQ-NNN: verification not independent — uses same code path as implementation`

## Step 4: 4-Path Coverage Matrix

For each Success Criterion, check that REQs cover all 4 paths:

```
SC-N: "[description]"
  Happy path:         REQ-NNN | MISSING
  Failure path:       REQ-NNN | MISSING
  Boundary path:      REQ-NNN | MISSING
  Existing-data path: REQ-NNN | MISSING | EXEMPT (evidence: [why])
```

**Rules:**
- Every SC must have at least one REQ per path
- Exemptions require evidence — "no existing data" must cite the CREATE action in the Change Manifest or `information_schema` query showing the table is new
- "Not applicable" without evidence = MISSING

## Step 5: Dimension Coverage

Verify all 9 spec dimensions have REQs or documented exemptions (per spec S6.2):

| Dimension | REQ Count | Status |
|-----------|-----------|--------|
| Functional | | OK / MISSING |
| Data Integrity | | OK / MISSING |
| Security | | OK / EXEMPT (proof ref) |
| UX | | OK / EXEMPT (proof ref) |
| Performance | | OK / EXEMPT (proof ref) |
| Invariant | | OK / MISSING |
| Regression | | OK / MISSING |
| Observability | | OK / EXEMPT (proof ref) |
| Change Propagation | | OK / EXEMPT (proof ref) |

Exemptions must reference spec S6.2 where the exemption proof is documented.

## Step 6: High-Effort REQ Check

For every REQ tagged `H` (high effort):
- Is the verification method proportionally rigorous? (H-effort REQs with T1/T2 verification = flag)
- Could this REQ be split into smaller, independently verifiable REQs? (flag if compound)
- Is this the REQ most likely to be skipped during implementation? (flag for phase gate prioritization)

## Step 7: Output

```
## REQ Coverage Report for [Spec Title]

### Scores
- REQ quality: X/Y pass all checks (Z%)
- 4-path coverage: X/Y SCs fully covered (Z%)
- Dimension coverage: X/9 dimensions covered
- High-effort REQs with adequate verification: X/Y

### QUALITY FLAGS (must fix before /plan)
- REQ-NNN: [issue — tier/method/outcome/independence]

### COVERAGE GAPS (must add REQs)
- SC-N "[description]" — missing [path] path REQ

### DIMENSION GAPS (must add REQs or document exemption in spec S6.2)
- [Dimension] — no REQs assigned

### HIGH-EFFORT RISKS
- REQ-NNN [H]: [concern]

### CLEAN
- X REQs pass all quality checks
- Y SCs have full 4-path coverage
```

## Step 8: Offer to Fix

After presenting the report:
- Generate missing REQs for coverage gaps — proper tiers, specific expected outcomes, independent verification
- Propose upgraded verification methods for flagged REQs
- Ask permission before editing the spec file
- If editing, preserve existing REQ numbering and append new REQs

## Step 9: Write Validation Marker (if passing)

If REQ quality = 100% AND 4-path coverage = 100% AND dimension coverage = 100%:

```
File: .claude/work/PROJ-NNN-name/.uat-validated
Content:
validated YYYY-MM-DD
req-quality: X/Y (100%)
4-path-coverage: X/Y SCs (100%)
dimension-coverage: 9/9
high-effort-adequate: X/Y
```

If not 100%, do NOT write the marker. Fix gaps first.

## Hard Rules

1. Code reading is discovery, not verification — REQs verified via "read the code" are rejected
2. T1/T2 evidence never satisfies T3+ requirements — mocked boundaries don't prove integration
3. "Works correctly" is never an acceptable expected outcome — exact values required
4. Every SC needs all 4 paths unless exempted with evidence
5. Verification must be independent of the code being tested
6. Business outcomes (`table.field` values) over API signals (`200 OK`)
7. High-effort REQs with low-effort verification methods are flagged
