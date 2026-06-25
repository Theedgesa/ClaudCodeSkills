---
name: ship
description: Create PR with documentation and deploy after merge. Use when user says "ship it", "create PR", "push and deploy", or wants to finalize and deploy a feature.
---

# Ship — PR Creation, Documentation & Deployment

You are executing the full ship workflow for MyProject v3. This has 3 phases: Document, PR (two-PR flow), Deploy.

## Pre-flight

1. Run `git status` and `git diff --stat` to understand what's being shipped
2. Identify the current branch name — it MUST follow `feature/PROJ-NNN-*` or `fix/PROJ-NNN-*` pattern
3. If on `main` or `staging`, STOP and tell the user to create a feature branch first
4. Extract the PPV3 number and description from the branch name
5. **Worktree env check (if in a worktree):** Verify all `.env` symlinks are valid (not broken):
   ```bash
   for f in server/.env server/.env.staging finance-service/.env; do
     [ -L "$f" ] && file "$f" | grep -q "broken" && echo "BROKEN SYMLINK: $f — fix before shipping" && exit 1
   done
   ```
   Incident: PROJ-167 — broken relative symlinks caused quality gate failure. Past-errors rule #49.
6. Run `npm run quality` — must exit 0 before proceeding
7. **Architecture doc gate:** Check if any modified files appear in `.claude/rules/architecture/*.md`. If so, verify the architecture docs have been updated to reflect the changes. Stale docs cause incidents (PROJ-091: wrong method name documented for 2 months). If docs are stale: STOP and update before PR.

## Phase 1: Documentation

Generate or update an implementation report at `.claude/work/PROJ-NNN-description/report.md`.

Analyze ALL changes on this branch (use `git log main..HEAD` and `git diff main...HEAD`) to build the report.

**Report must include these sections (from template):**
1. **Executive Summary** — What was built, why, outcome
2. **Deliverables** — New files, modified files, configuration changes
3. **Phase-by-Phase Results** — Status per phase with REQ scoring (Green/Orange/Red)
4. **Verification Matrix** — Key verification commands with outcomes
5. **Integration Points** — Source → calls → destination mapping
6. **Before/After Comparison** — What changed functionally
7. **Risk Assessment** — Likelihood/Impact/Mitigation table
8. **Rollback Plan** — Per-component revert steps (including staging rollback)
9. **REQ Scoring Summary** — Final REQ status (all Green required)
10. **Remaining Actions** — Post-deploy manual steps

## Phase 2: PR Creation — Two-PR Flow

### PR #1: Feature -> Staging

#### Step 1: Quality gate
Run `npm run quality`. If fails: STOP. Fix before PR.

#### Step 2: Check for sensitive files
Run `git status` — WARN if `.env`, credentials, or secret files staged.

#### Step 2b: Check branch base + merge conflicts (MANDATORY)
```bash
# 1. Fetch latest target
git fetch origin staging

# 2. Check if branch is behind staging (would cause conflicts)
BEHIND=$(git rev-list --count HEAD..origin/staging)
echo "Behind staging by: $BEHIND commits"

# 3. If behind, do a test merge to check for conflicts
if [ "$BEHIND" -gt 0 ]; then
  git merge --no-commit --no-ff origin/staging
  # If conflicts: STOP. Rebase first: git rebase origin/staging
  # If clean: git merge --abort (we just tested)
fi
```
**If merge conflicts found:** STOP. Rebase on staging first (`git rebase origin/staging`), resolve conflicts, then continue. Never create a PR with known conflicts. Past-errors rule #26.

#### Step 2c: CI compatibility check (MANDATORY if package.json changed)
If `git diff origin/staging -- package.json` shows changes to `workspaces`, `prepare`, `scripts`, or `overrides`:
1. Read `.github/workflows/quality.yml`
2. Verify workspace members do NOT have separate `npm ci` steps (root `npm install` handles them)
3. Verify `prepare` script uses `|| true` for CI safety
4. Verify new packages have typecheck steps in CI
Past-errors rule #31. Incident: PROJ-153 CI broke because `cd store-website && npm ci` overwrote the workspace symlink.

#### Step 3: Push to remote
```bash
git push -u origin <branch-name>
```

#### Step 4: Create PR to staging
```bash
gh pr create --base staging --title "[feat|fix]: <description> (PROJ-NNN)" --body "..."
```
Include implementation report link.

#### Step 5: Verify CI passes
After push, poll CI status until complete:
```bash
gh pr checks <PR-NUMBER> --watch
```
If `gh pr checks` fails due to permissions, use:
```bash
gh run list --branch <branch-name> --limit 1 --json status,conclusion
```
**If CI fails:** Read the failure logs (`gh run view <run-id> --log-failed`), fix locally, commit, push, and re-check. Do NOT proceed to Step 6 with failing CI.

#### Step 6: Output PR URL
Output the PR URL to the user. User merges.

#### Step 7: Deploy to staging
After merge: `ssh staging-server "cd /var/www/MyProject && git pull origin staging"`
Run manual UAT on staging server. Verify webhook flows if applicable.

### PR #2: Staging -> Main

Only after staging UAT passes.

#### Step 1: Create PR from staging to main
```bash
gh pr create --base main --head staging --title "[feat|fix]: <description> (PROJ-NNN) — staging verified"
```

#### Step 2: Verify CI passes
Same as PR #1 Step 5 — poll and confirm CI passes before proceeding.

#### Step 3: Output PR URL
User reviews and merges.

#### Step 4: Deploy to production
After merge: `ssh prod-server "cd /var/www/MyProject && git pull origin main"`
Follow `/deploy` skill checklist for post-deploy verification.

#### Step 4b: PM2 freshness verification (MANDATORY)
After `git pull`, restart ALL affected PM2 processes and verify timestamps:

```bash
# Restart
pm2 restart main-api
pm2 restart finance-service  # if applicable

# Verify freshness — created timestamp must be AFTER git pull
pm2 describe main-api | grep created
pm2 describe finance-service | grep created
```

**If PM2 created timestamp is BEFORE git pull → the process is running old code.** Restart it.
Past-errors rule #53. Incident: PROJ-170 — finance-service not restarted, 34h of errors.

#### Step 4c: Frontend build (if applicable)
```bash
# Only if frontend files changed
cd store-website && npm run build
cd reception-website && npm run build
```

#### Step 5: External system reconciliation (if plan touches external APIs)
Read plan S7.4 (Production Verification) and spec S7 (Monitoring & Observability). If the plan modifies integration with Zoho Books, payment gateways, email providers, or any external API:
1. Query the external system for ALL affected records — not just the pre-planned list
2. For Zoho: `list_invoices({ status: 'overdue' })` and check for API-sourced invoices
3. For payment gateways: verify pending payments are resolved
4. Fix any records that accumulated between plan-write and deploy
Incident: PROJ-167 — backfill script had 41 hardcoded UUIDs from June 11. By deploy on June 14, 2 new overdue invoices had accumulated. Past-errors rule #50.

## Roadmap Integration

At each stage transition during shipping, update `.claude/work/roadmap.yaml`:

- **Phase 2 Step 4** (PR created): set `stage: pr-open`, set `pr:` to PR number
- **Phase 2 Step 7** (staging deployed): set `stage: staging`
- **Phase 3 Step 2** (production deployed): set `stage: production`
- **Phase 3 Step 3** (final verification passes): set `stage: monitoring`
  - Read the plan's S7.4 Production Verification section
  - Propose `verify:` criteria and `review_after:` date to user, wait for confirmation
  - Write `verify` + `review_after` to the roadmap entry

After the final step, run the **Monitoring Scan**:

1. Read `.claude/work/roadmap.yaml`
2. Filter entries where `stage: monitoring` AND `review_after` date is today or earlier
3. If none found: continue silently
4. If found: display list to user:
   ```
   Roadmap updated.

   N items awaiting production verification:
   - PROJ-NNN (title) — review by: YYYY-MM-DD — "verify criteria"
   ...

   Check logs for any of these now? (y/list numbers/skip)
   ```
5. Wait for user response
6. If user picks entries to check:
   a. Read the `verify` field for each
   b. Run the SQL/log queries specified
   c. If all pass: set `stage: closed`, `evidence:` query results, `closed_at:` today
   d. If any fail: report findings, leave at `monitoring`

## Phase 3: Validation and Final Steps

### Step 1: Verify deploy
Check that the deployment completed successfully on the target environment.

### Step 2: Post-deploy verification
Run verification checks from the plan's S7.4 Production Verification section:
- Kill switches operational (from spec S7.3)
- Health signals monitored (from spec S7.1)
- Post-deploy queries pass (from spec S7.4)

### Step 3: Final report
Output a shipping summary with PR URLs, deploy status, and any remaining actions.

## Success Criteria

Shipping is complete when:
- [ ] Implementation report generated/updated
- [ ] Architecture docs updated (if modified files appear in architecture docs)
- [ ] All spec REQs are Green (from implementation report)
- [ ] `npm run quality` passes (exit 0)
- [ ] Changes committed and pushed
- [ ] PR #1 created to staging, CI passes, merged, deployed
- [ ] Staging UAT passes
- [ ] PR #2 created to main, CI passes, merged, deployed
- [ ] PM2 freshness verified (timestamps after git pull)
- [ ] Post-deploy verification passes (plan S7.4)
