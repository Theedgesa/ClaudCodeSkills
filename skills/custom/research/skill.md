---
name: research
description: Enter verified research mode where every finding goes through 4 stages — FIND, CROSS-REFERENCE, CHALLENGE, RATE. Use when debugging, investigating root causes, analyzing code behavior, diagnosing production issues, or any exploratory work before making changes. Invoke with /research.
---

# Research Mode — 4-Stage Verified Discovery

You are entering verified research mode. Every observation you make goes through 4 stages before you can build on it. This prevents the pattern where you read one file, draw a conclusion, and run with it — which has caused tenantId threading bugs, UUID undefined errors, and JSONB casing mismatches.

## When to Use

- Debugging a production issue
- Investigating root cause of a bug
- Analyzing code behavior before writing a plan
- Tracing data flows across services
- Any work where wrong conclusions lead to wrong fixes

## The 4 Stages

Every finding MUST pass through all 4 stages before you can use it as the basis for a decision or recommendation.

### Stage 1: FIND — Raw Observation

State exactly what you observed, with its source.

```
FINDING #N: [what you observed]
  SOURCE: [file:line with quoted snippet, or command output, or query result]
```

Rules:
- Cite the EXACT source — file path, line number, quoted code
- For log evidence: include timestamp and the relevant log line
- For DB evidence: include the query AND the result
- No interpretation yet — just what you see

### Stage 2: CROSS-REFERENCE — Verify Against Second Source

Check the finding against at least one independent source.

```
  CROSS-REF: [second source that confirms or contradicts]
    Source: [file:line, different log, different query, documentation]
    Result: CONFIRMS / CONTRADICTS / PARTIAL
```

Cross-reference strategies by finding type:

| Finding type | Cross-reference with |
|---|---|
| "Function X takes params A, B" | Read actual callers — do they pass A, B? |
| "Column X exists on table Y" | `information_schema.columns` query |
| "This code path handles case Z" | Trace from the entrypoint (route → controller → service) |
| "Error caused by X" | Reproduce the error, check if X is present |
| "Config value is Y" | Read the .env file AND the code that reads it |
| "Service A calls service B" | grep for the import/require AND the method call |
| "Data flows from A to B" | Read both A's output and B's input — do shapes match? |

Rules:
- The second source must be INDEPENDENT (not just re-reading the same file)
- If cross-reference contradicts: STOP. Investigate the discrepancy before proceeding.
- If no second source is available: mark as SINGLE-SOURCE and flag it.

### Stage 3: CHALLENGE — Search for Counter-Evidence

Actively try to disprove your finding. This is the stage that prevents overconfidence.

```
  CHALLENGE: [what you searched for to disprove this]
    Search: [grep command, query, or code path explored]
    Result: NO CONTRADICTION FOUND / CONTRADICTION: [detail]
```

Challenge strategies:

| Finding | Challenge with |
|---|---|
| "Only 3 callers of function X" | `grep -rn 'X(' --include='*.js'` across ENTIRE codebase |
| "Parameter always has value" | Search for code paths where it could be null/undefined |
| "This is the only code that writes to table Y" | `grep -rn 'table_y' --include='*.js'` + check DB triggers |
| "Error only happens in scenario Z" | Check logs for the error in other scenarios |
| "Config is always set" | Check what happens when .env is missing the key |
| "These two values always match" | Query for mismatches: `SELECT ... WHERE a != b` |

Rules:
- You MUST actively search for evidence that contradicts your finding
- "I looked and didn't find anything" requires citing what you searched and where
- If contradiction found: the finding is WRONG or INCOMPLETE. Update it.
- Do NOT skip this stage. The bugs we miss are the ones we don't look for.

### Stage 4: RATE — Confidence Assessment

Based on all 3 prior stages, assign a confidence rating.

```
  RATING: GREEN / AMBER / RED
  REASON: [specific justification]
```

| Rating | Criteria | Action |
|---|---|---|
| GREEN | Confirmed by 2+ sources, no contradictions found, challenge search was thorough | Safe to build on this finding |
| AMBER | Single source only, OR cross-reference was partial, OR challenge search was limited | Flag it. Do not make critical decisions based on AMBER findings alone. Seek more evidence. |
| RED | Contradiction found, OR sources conflict, OR finding is based on assumption not evidence | STOP. Do not proceed. Investigate the contradiction or replace the assumption with evidence. |

## Output Format

Present findings as a numbered research log:

```
## Research Log: [topic]

### FINDING #1: [summary]
  SOURCE: [file:line — "quoted code"]
  CROSS-REF: [second source] — CONFIRMS/CONTRADICTS
  CHALLENGE: searched [what] in [where] — NO CONTRADICTION / CONTRADICTION: [detail]
  RATING: GREEN
  REASON: Two independent sources confirm, thorough challenge search found no counter-evidence.

### FINDING #2: [summary]
  SOURCE: [file:line — "quoted code"]
  CROSS-REF: [second source] — PARTIAL (only confirms X, silent on Y)
  CHALLENGE: searched [what] in [where] — NO CONTRADICTION
  RATING: AMBER
  REASON: Cross-reference only partially confirms. Y component unverified.

### FINDING #3: [summary]
  SOURCE: [log output at timestamp]
  CROSS-REF: [DB query result] — CONTRADICTS (log says X, DB says Y)
  CHALLENGE: N/A — contradiction already found
  RATING: RED
  REASON: Log and DB disagree. Must resolve before proceeding.
```

## Decision Gate

Before making any recommendation or starting implementation based on research:

1. Count findings by rating:
   - All GREEN → proceed with confidence
   - Any AMBER → call out explicitly: "Decision based on N AMBER findings — [list which ones]. Additional verification recommended for: [specific items]"
   - Any RED → STOP. Do not recommend action. Report the contradictions and ask for guidance.

2. State the decision with its evidence chain:
```
DECISION: [what you recommend]
BASED ON: Findings #1 (GREEN), #3 (GREEN), #5 (AMBER)
AMBER RISK: Finding #5 — [what's uncertain and why]
```

## Hard Rules

1. **No building on RED findings.** Period. Resolve contradictions first.
2. **No skipping stages.** Every finding goes through all 4 stages. Even obvious ones.
3. **Challenge is mandatory, not optional.** If you can't think of how to challenge a finding, that's a sign you don't understand it well enough.
4. **Single-source findings are AMBER at best.** GREEN requires 2+ independent confirmations.
5. **Reading code is Stage 1 only.** Cross-referencing means checking a DIFFERENT source. Re-reading the same file doesn't count.
6. **"I didn't find contradictions" requires citing what you searched.** The absence of a search is not the absence of contradictions.
7. **Update findings as you go.** If Finding #3 contradicts Finding #1, go back and update Finding #1's rating to RED.
