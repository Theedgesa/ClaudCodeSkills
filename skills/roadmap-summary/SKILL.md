---
name: roadmap-summary
description: Compact one-liner roadmap summary with theme counts. Use when user says "/roadmap-summary", "quick roadmap", "roadmap status", or wants a brief overview of tracked work.
---

# Roadmap Summary — Compact View

Display a compact one-line-per-entry summary of the roadmap.

**Announce at start:** "Roadmap summary:"

## Instructions

1. **Read** `.claude/work/roadmap.yaml` using the Read tool.
2. **Parse** the YAML content.
3. **Exclude `closed` and `cancelled` entries.**
4. **Group by theme** — Platform, Tenant, Customer.
5. **Within each theme, order by priority** — P0 first.
6. **Format output** as:

```
## Platform (N)
P1: PROJ-105 in-progress — Roadmap System
P2: PROJ-106 idea — Skill Unification

## Tenant (N)
P1: PROJ-107 planned — Some Feature

## Customer (N)
P2: PROJ-108 idea — Another Feature

---
Monitoring: N awaiting verification
Closed: N | Cancelled: N
```

Each entry is exactly one line: `P[N]: PROJ-NNN stage — title`

No descriptions, no links, no detail.

7. **Show monitoring count** at the bottom — count of entries with `stage: monitoring`.
8. **Show closed/cancelled counts** at the bottom.

## Edge Cases

- If `roadmap.yaml` does not exist: report "No roadmap found. Run /roadmap to create one."
- If a theme has no active entries: skip that theme section.
- If no monitoring entries: show `Monitoring: 0`
