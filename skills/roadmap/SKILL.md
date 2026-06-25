---
name: roadmap
description: Full roadmap view with themed grouping, priority ordering, and monitoring scan. Use when user says "/roadmap", "show roadmap", "what's on the roadmap", or wants to see all tracked work.
---

# Roadmap — Full Themed View

Display the complete roadmap grouped by strategic theme with priority ordering.

**Announce at start:** "Loading roadmap..."

## Instructions

1. **Read** `.claude/work/roadmap.yaml` using the Read tool.
2. **Parse** the YAML content.
3. **Display the strategy section** — show the vision statement.
4. **Group entries by theme** — Platform, Tenant, Customer (use `strategy.themes[key].name` for headers).
5. **Within each theme, order by priority** — P0 first, then P1, P2, P3.
6. **Exclude `closed` and `cancelled` entries** from the main view.
7. **Format each entry** as:

```
### [theme name] ([count] items)

| Priority | ID | Stage | Title |
|----------|----|-------|-------|
| P1 | PROJ-105 | in-progress | Roadmap System |
```

For each entry, show below the table row:
- Summary (one line)
- Links: spec, plan, branch, PR (if present)
- `blocked_by:` references (if present)

8. **Monitoring section** — After the themed sections, add:

```
## Monitoring

Items deployed and awaiting production verification:
```

List entries where `stage: monitoring`. Show: ID, title, `review_after` date, `verify` criteria.

9. **Run monitoring scan** — Check for entries where `stage: monitoring` AND `review_after` date is today or earlier. If found, prompt:

```
N items awaiting production verification:
- PROJ-NNN (title) — review by: YYYY-MM-DD — "verify criteria"
...

Check logs for any of these now? (y/list numbers/skip)
```

Wait for user response. If user picks entries:
- Read the `verify` field for each
- Execute the verification (SQL queries, log checks, etc.)
- If all pass: update entry to `stage: closed`, set `evidence` and `closed_at`
- If any fail: report findings, leave at `monitoring`

10. **Show closed/cancelled count** at the bottom:
```
---
Closed: N | Cancelled: N
```

## Edge Cases

- If `roadmap.yaml` does not exist: create it with empty entries list and strategy section from CONTEXT.md.
- If no entries exist for a theme: skip that theme section entirely.
- If no monitoring entries exist: omit the Monitoring section.
