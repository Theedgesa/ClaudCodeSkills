# Claude Code Skills, Hooks & Lessons Learned

A battle-tested collection of **Claude Code skills** (slash commands), **guardrail hooks** (pre/post tool guards), and **debugging patterns** built over 6+ months of daily production use across a multi-tenant SaaS platform.

These aren't theoretical — every skill, hook, and past-error rule was born from real incidents, real bugs, and real process failures encountered during active development with Claude Code.

## What's Inside

### `/skills` — 33 Slash Command Skills

Full-lifecycle development workflow skills:

| Category | Skills | Description |
|----------|--------|-------------|
| **Planning** | `spec`, `plan`, `review-gates`, `critique-plan`, `verify-plan`, `uat-design` | Structured spec writing, implementation planning, and 7-gate review process |
| **Implementation** | `implement`, `tdd`, `cr` | Phase-by-phase implementation with REQ scoring, TDD, and Change Records |
| **Quality** | `post-review`, `check-errors`, `simplify`, `security-review`, `evidence` | Code review, past-error cross-checking, over-engineering detection, OWASP audit |
| **Research** | `research`, `diagnose`, `zoom-out` | Verified research mode, systematic debugging, big-picture re-orientation |
| **Shipping** | `ship`, `deploy`, `retro` | PR creation, EC2 deployment, post-session retrospectives |
| **Analysis** | `tc-impact`, `gemini-review`, `grill-with-docs` | Tenant impact analysis, cross-AI review, domain model stress-testing |
| **Utilities** | `roadmap`, `roadmap-summary`, `to-issues`, `to-prd`, `caveman` | Roadmap views, issue creation, PRD generation, ultra-compressed communication |
| **Meta** | `write-a-skill`, `git-guardrails`, `improve-codebase-architecture` | Skill authoring, git safety, architecture improvement |

### `/hooks` — 47 Shell Script Guards

Pre-tool and post-tool hooks that prevent common mistakes:

| Category | Hooks | What They Prevent |
|----------|-------|-------------------|
| **Database Safety** | `supabase-db-guard`, `supabase-chain-guard`, `pre-migration-verify`, `table-ownership-guard` | Accidental production DB changes, broken query chains, stale migration assumptions |
| **Git Safety** | `branch-base-guard`, `merge-tree-guard`, `post-rebase-conflict-guard`, `no-verify-guard` | Wrong base branches, hidden merge conflicts, skipped hooks |
| **Deploy Safety** | `pm2-restart-guard`, `pre-commit-runtime-guard`, `ssh-edit-guard`, `production-override-expiry` | Forgotten PM2 restarts, direct SSH edits, stale production overrides |
| **Code Quality** | `citation-guard`, `weasel-word-guard`, `agent-evidence-guard`, `evidence-tier-guard` | Unverified claims, speculation, agents bypassing evidence requirements |
| **Process** | `pre-tool-guard`, `plan-save-guard`, `post-skill-phase-gate`, `no-scope-dodge-guard`, `no-hotfix-guard` | Skipping plans, scope creep, unauthorized hotfixes |
| **Test Safety** | `test-data-email-guard`, `playwright-test-data-guard`, `playwright-selector-guard`, `playwright-script-guard` | Real customer data in tests, brittle selectors, script-based Playwright failures |
| **SDK/Build** | `sdk-wrapper-guard`, `npm-save-guard`, `ci-workflow-guard`, `cross-stack-guard` | Direct SDK usage, unsaved deps, CI breakage, cross-stack contamination |

### `/past-errors` — Numbered Rules from Real Incidents

130+ rules extracted from production incidents. Each rule has:
- The exact mistake that was made
- The incident that caused it (with ticket reference)
- The prevention mechanism

### `/debugging` — Debugging Patterns

Domain-specific debugging playbooks covering:
- Payment gateway integration patterns
- Check-in system QR code debugging
- Finance service reconciliation
- Auth/session debugging
- Multi-tenant data isolation

## Philosophy

### Evidence Over Speculation
The `weasel-word-guard` hook catches phrases like "probably", "should work", "I think" and forces verification with actual evidence (logs, queries, runtime tests). This alone prevented dozens of false-positive "it works" claims.

### Past Errors Compound
Every debugging session ends with a `/retro` that extracts patterns into `past-errors.md`. The `/check-errors` skill cross-references these against every new plan. Mistakes compound into prevention.

### Multi-Gate Review
Plans go through 7 sequential gates before approval:
1. Past-error cross-check
2. API surface verification (against actual source code)
3. REQ coverage analysis
4. Simplification review
5. Security audit
6. Tenant impact analysis
7. Multi-agent plan critique

### Green/Orange/Red Scoring
Every implementation phase gate scores requirements as Green (verified), Orange (partial), or Red (failing). No phase advances with Red scores.

## How to Use

### Install a Skill
Copy any skill directory into `~/.claude/skills/` or your project's `.claude/skills/`:

```bash
cp -r skills/diagnose ~/.claude/skills/
```

Then invoke with `/diagnose` in Claude Code.

### Install a Hook
Copy hook files to `~/.claude/hooks/` and register them in your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": ["~/.claude/hooks/supabase-db-guard.sh"]
      }
    ]
  }
}
```

### Use Past Errors
Copy `past-errors.md` into your project's `.claude/rules/anti-patterns/` directory. The `/check-errors` skill will automatically cross-reference it against your plans.

## Sanitization Note

All identifying information has been removed from these files:
- Company/product names replaced with generic placeholders
- IP addresses, domains, and URLs redacted
- Person names, emails, and phone numbers removed
- AWS account IDs, Supabase project refs sanitized
- Server hostnames and SSH aliases genericized

The patterns and lessons remain fully intact.

## License

MIT
