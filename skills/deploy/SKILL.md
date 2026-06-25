---
name: deploy
description: EC2 deploy checklist with evidence at every step. Covers env audit, build verification, backup, PM2 restart, post-deploy smoke test, and rollback plan. Use when deploying to production or staging.
---

# Deploy — Production Deploy Checklist

Follow this checklist exactly. Every step requires evidence. No shortcuts.

## Step 0: Gate

BLOCKED unless:
- Implementation report exists at `.claude/work/PROJ-*/report.md`
- All Self-UAT tests in report show CONFIRMED
- E2E verification section is complete
- PR is merged to the target branch (`staging` or `main`)
- `npm run quality` passed (documented in report)

No exceptions. No hotfix path.

## Step 0.5: Verify Roadmap State

1. Read `.claude/work/roadmap.yaml`
2. Find the entry for the PROJ-NNN being deployed
3. Verify stage is `pr-open` or `staging` (not `idea`, `planned`, etc.)
4. If stage doesn't match expected: WARN (don't block — roadmap may not be up to date for legacy entries)

### Monitoring Scan (runs after roadmap state change)

1. Read `.claude/work/roadmap.yaml`
2. Filter entries where `stage: monitoring` AND `review_after` date is today or earlier
3. If none found: continue silently
4. If found: display list to user:
   ```
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

## Step 1: Identify Scope

What's being deployed?
- Monolith backend (server/)
- Storefront frontend (store-website/)
- Reception frontend (reception-website/)
- Finance-svc (finance-service/)
- Database migration (Supabase)
- Nginx config
- Combination — list each component

Deploy target:
- Production EC2: `prod-server` (<PROD-IP>)
- Staging: LXC staging

## Step 2: Pre-Deploy Checklist

### Backend (server/)
- `git pull` on EC2 — check for merge conflicts
- `npm install` if package.json changed
- Diff server/.env against expected values — no surprises

### Storefront (store-website/)
- Read `.env.production` — verify ALL `NEXT_PUBLIC_*` vars
- `NEXT_PUBLIC_API_URL` MUST be `https://api.example.app/api` (NOT localhost)
- `npm run build` — exit 0
- Post-build: `grep -r 'localhost' .next/` — MUST return ZERO matches
- If localhost found: STOP. Fix .env.production. Rebuild.

### Reception (reception-website/)
- Same .env.production check as storefront
- `npm run build` — exit 0
- Post-build localhost grep

### Finance-svc
- `npm install` if needed
- .env verified (DB connection, port 5002)
- Nginx config routes `/api/payments/` to :5002

### Database
- Invoke `/migrate` skill for full workflow
- Migration tested on staging first
- Rollback SQL prepared

## Step 3: Backup

MANDATORY before any file change on EC2.

### Git pull deploy
- Record current commit: `git rev-parse HEAD` → save as ROLLBACK_COMMIT

### Nginx
- `cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.PROJ-NNN-bak`

### Database
- Rollback SQL saved to `.claude/work/PROJ-NNN/rollback.sql`

## Step 4: Execute

### Standard deploy
```
1. ssh prod-server
2. cd /var/www/MyProject
3. git pull origin main
4. MANDATORY: check if package.json changed — run npm install BEFORE pm2 restart
   git diff HEAD~1 -- server/package.json store-website/package.json reception-website/package.json
   If ANY changed: cd <dir> && npm install (for each changed dir)
   If skipped: pm2 restart will crash on missing deps (past-errors #39)
5. cd store-website && npm run build
6. cd ../reception-website && npm run build
7. pm2 restart main-api finance-service
   ALWAYS restart BOTH — never just one. Past-errors #53.
8. MANDATORY: Verify restart timestamps match the deploy:
   pm2 describe main-api | grep created
   pm2 describe finance-service | grep created
   Both created_at must be AFTER the git pull. If not, restart again.
```

### Database
```
1. Run migration SQL on Supabase
2. Run verification SELECT immediately
```

## Step 5: Post-Deploy Verification

EVERY check requires evidence (actual command output).

### PM2 Restart Verification (MANDATORY — past-errors #53)
- `pm2 describe main-api | grep created` — must be AFTER git pull timestamp
- `pm2 describe finance-service | grep created` — must be AFTER git pull timestamp
- If either shows a stale timestamp: STOP. Restart the stale process immediately.

### Backend
- `pm2 logs main-api --lines 20` — "listening on 5001", no crash
- `pm2 logs finance-service --lines 20` — "listening on 5002", no crash
- Health check endpoint — 200 OK

### Storefront
- Load `https://store.example.com` — page renders
- Network tab: API calls hit `api.example.app`, NOT localhost
- Test one user-visible flow related to the change

### Reception
- Load `https://reception.example.com` — page renders
- Login with test admin account
- Navigate to affected page — data loads

### Finance-svc (if deployed)
- `pm2 logs finance-service --lines 20` — "listening on 5002", no crash
- Test one payment flow if payment code changed

### Database (if migrated)
- SELECT to verify migration applied
- Test one flow that uses the new column/table

Grade each: CONFIRMED / PARTIAL / REFUTED
If REFUTED on ANY check: STOP. Execute rollback (Step 6).

## Step 6: Rollback

Pre-written, ready to execute if post-deploy fails.

### Git pull deploy
```
ssh prod-server "cd /var/www/MyProject && git checkout ROLLBACK_COMMIT"
# Rebuild frontends
# pm2 restart main-api
```

### Database
```
Run rollback.sql from .claude/work/PROJ-NNN/rollback.sql
Verify with SELECT
```

### Nginx
```
ssh prod-server "cp default.PROJ-NNN-bak default && nginx -t && systemctl reload nginx"
```

## Step 7: Deploy Report

```
## Deploy Report: PROJ-NNN

### Scope: [components deployed]
### Target: [production/staging]

### Pre-deploy
- .env.production: [VERIFIED / ISSUE]
- Builds: [exit codes]
- Backup: [commit hash / file paths]

### Execution
- [step]: [result]

### Post-deploy verification
- [check]: [CONFIRMED / REFUTED] — [evidence]

### Status: [DEPLOYED / ROLLED BACK]
### Rollback: [command to execute if issues found later]
```
