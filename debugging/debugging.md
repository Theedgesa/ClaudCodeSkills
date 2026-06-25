# Debugging Patterns

## Pattern 0: SuperTokens SDK v21 Method Signature Mismatch
- `createResetPasswordToken(tenantId, userId, email)` — 3rd param `email` required in v21. Omitting sends `undefined` → 400.
- `EmailPassword.getUserByEmail()` — doesn't exist in v21. Use `SuperTokens.listUsersByAccountInfo(tenantId, {email})`.
- Audit: `node -e "const EP = require('supertokens-node/recipe/emailpassword'); console.log(Object.keys(EP).join(', '))"`.

## Pattern 1: Silent Supabase null from invalid column
- PostgREST returns `{ data: null, error: { code: '42703' } }` for missing columns. Code with `{ data: X }` (no error) silently discards.
- Diagnose: run exact SQL in SQL editor. Check `information_schema.columns`.
- Incident: PROJ-070 — `getMemberDetails` selected `location` (doesn't exist, real column is `purchase_location_id`). 13 members couldn't check in.

## Pattern 2: Two query paths for same data
- `getMemberDetails` vs `scanQRCode` use different queries. One can be broken while the other works.
- If QR kiosk works but reception profile doesn't → `getMemberDetails` is broken.

## Pattern 3: Checkin gap diagnostic query
```sql
SELECT p.first_name || ' ' || p.last_name AS member, p.email,
  up.pass_category, up.expiry_date,
  CASE WHEN cl.id IS NULL THEN 'NO CHECK-IN' ELSE 'checked in at ' || cl.location END AS status
FROM unified_passes up
JOIN profiles p ON p.id = up.user_id
LEFT JOIN checkin_logs cl ON cl.user_id = up.user_id
  AND cl.created_at >= CURRENT_DATE::timestamptz
  AND cl.type = 'checkin' AND cl.status = 'approved'
WHERE up.is_active = true AND up.start_date <= CURRENT_DATE AND up.expiry_date >= CURRENT_DATE
ORDER BY cl.id NULLS LAST, up.expiry_date ASC;
```

## Pattern 4: Supabase email enumeration → FK violation on signup
- Existing email → fake user (`identities: []`). Profile insert → FK violation.
- Fix: check `identities?.length === 0` before `createInitialProfile`.

## Pattern 5: MyFatoorah payment — mobile number too long
- `mobile_number` stored with country code prefix. MF receives doubled code (`+966966...`).
- Fix: strip country code prefix. Diagnostic: `WHERE mobile_number LIKE CONCAT(REPLACE(mobile_country_code, '+', ''), '%')`.

## Pattern 6: Staff email "at Unknown" for location-agnostic passes
- `locationSlug` empty for `valid_at_all_locations = true` passes. Default changed to `'All Locations'`.

## Pattern 7: normalizeEmail() breaks OTP for Gmail
- `validator.normalizeEmail()` strips dots and `+` aliases. Use `.trim().toLowerCase()` instead.

## Pattern 8: Supabase upsert 23505 on trigger-created rows
- DB trigger creates row between check and upsert. Catch `23505` + `profiles_pkey`, retry as `.update()`.

## Finance-svc Patterns
- **MF KeyType** — `gateway_session_id` = InvoiceId. MF redirect URL has PaymentId (different). Must pass `'InvoiceId'` as keyType.
- **Tamara JWT** — Auth-only, no event data. Read event from `req.body`.
- **Tamara dual webhook format** — Merchant URL: `{ order_status }`. Portal: `{ event_type }`. Handle both.
- **Tamara lifecycle** — approved → `/authorise` → authorized → `/capture` → captured. Amount from DB, not webhook.
- **MF strips URL params** — Store `ref` in `sessionStorage` before redirect, read on return.

## Check-in Investigation
- Table: `scan_activity` (NOT `scan_activities`)
- Find unknown: `WHERE member_name IS NULL OR member_name = 'Unknown'`
- Identify user: Nginx `app-api-access.log` → WebSocket upgrade → JWT decode (`?token=` query param)
- `result_type`: `invalid_qr` (parse fail), `validation_error` (no qrData field)

## Zoho SMTP Block
- Symptoms: 550 5.4.6 after batch sends. Breaks all SMTP including Supabase Auth emails.
- Fix: `mail.emailprovider.com/UnblockMe` as the specific mailbox account (not org admin).
- **Escalation:** Zoho escalates after repeated block/unblock cycles. Second block within same period requires Zoho support ticket — self-service UnblockMe no longer works. Stop ALL retry sources BEFORE requesting unblock, or the retry storm re-triggers the block immediately and burns the self-service option.
- Prevention: rate limit batch scripts. PROJ-168 added 1s throttle + circuit breaker (past-error #45).
- Incident: PROJ-168 — safety net retried 979 times after unblock, re-blocked within minutes, escalated to support-only unblock.

## MF Sandbox Payment Failures
- **Test cards rejected on `sa.paymentgw.example.com`:** Check `payment_gateway_config.mode` — if `live`, test cards go to production SA portal where they're rejected. Fix: set `mode='sandbox'` or (better) use `NODE_ENV` to force sandbox.
- **3DS challenge in sandbox:** MF demo portal shows "ACS Emulator for 3DS V2" iframe. Select "(Y) Authentication Successful" and click Submit. Playwright needs to navigate into nested iframes: `page.locator('iframe').contentFrame().locator('iframe').contentFrame().getByRole('button', { name: 'Submit' })`.
- **Test cards (official MF docs):** Visa `<TEST-VISA>` (any expiry, any CVV), MC `<TEST-MC>` (01/39, CVV 100), Mada `<TEST-MADA>` (02/29, CVV 123). Cardholder name must be two-part: "test test".
- **Order not created after successful payment:** Check monolith logs for FK violations on `orders`, `order_items`, `unified_passes`. If any FK still points to `auth.users` instead of `profiles`, the INSERT fails. Finance-svc webhook succeeds but order INSERT is dead-lettered.

## Finance-svc Auth After SuperTokens
- **Symptom:** 401 "Unauthorized" on all finance-service authenticated endpoints.
- **Root cause:** `finance-service/middleware/auth.js` used `supabaseAdmin.auth.getUser(token)` which calls Supabase Auth API. After SuperTokens migration, JWTs are signed locally — Supabase Auth doesn't recognize them.
- **Fix:** Replace with `jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] })` + profile lookup. Same pattern as monolith `server/middleware/auth.middleware.js`.

## Zoho / Finance-svc (PROJ-143)
- **Safety net cron floods historical orders:** If a catch-up cron has no `created_at > startTime` lower bound, it processes ALL historical records on first boot. Fix: capture `const startTime = new Date().toISOString()` at boot, add `.gt('created_at', startTime)` to query.
- **Email dedup never matches:** If dedup uses `orderId.substring(0,8)` (UUID prefix) to match `email_logs.subject`, but subject contains `order_number` (REC-xxx), dedup returns 0 rows every time → duplicate emails every 60s. Fix: load order first, match by `order_number`.
- **Kill switch `status='skipped'` violates CHECK constraint:** `accounting_jobs_status_check` only allows `pending/done/dead`. Must add `skipped` to constraint before deploying kill switch code.
- **`provider.svc` undefined:** `ZohoProvider.createInvoice()` creates `const svc = new ZohoBooksService(...)` as a local variable. Access via `provider.svc` fails. Fix: create a new `ZohoBooksService` instance with `provider._getSecret` and `provider._getConfig`.
- **Staging HMR instability (RESOLVED):** Reception on staging now runs `serve out` (static build), not `next dev`. Previous `next dev` over Cloudflare tunnel caused WebSocket failures that prevented React hydration entirely. Fix: switched PM2 to `npx serve out -l 3001`. After `git pull`, MUST rebuild: `cd reception-website && npm run build`.

## Worktree Environment
- **Symlinks must use absolute paths:** Relative symlinks (`../../server/.env`) break in worktrees because `.worktrees/PROJ-NNN/` has a different directory depth than the main repo. Always: `ln -sf "/absolute/path/to/main/repo/server/.env" ".worktrees/PROJ-NNN/server/.env"`. Verify with `file <path>` — "broken symbolic link" means the path is wrong.
- **finance-service/.env doesn't exist separately:** Quality gate scripts (`tenant-query-check.mjs`) expect `finance-service/.env` to exist. Symlink it to `server/.env`: `ln -sf "/path/to/server/.env" "finance-service/.env"`.
- **SuperTokens blocks local worktree frontend testing:** SSH tunnel to production SuperTokens (localhost:3567) + staging Supabase DB = auth mismatch (user exists in SuperTokens but profile lookup hits staging DB). Backend-only changes can use code path verification + staging UAT. No workaround without a local SuperTokens instance.
- **Workspace hoisting version drift:** Adding a package to npm workspaces changes which version resolves for shared deps. Check: `cat node_modules/next/package.json | grep version` after workspace changes. PROJ-155: 16.1.1→16.2.7 broke staging (allowedDevOrigins + HMR failure).
- **PM2 binary vanishes after workspace change:** `<workspace>/node_modules/.bin/<binary>` moves to root `node_modules/.bin/` when package joins workspaces. PM2 processes with absolute paths to the old location will error. Fix: use `npx <binary>` or `serve` instead of direct binary paths.
- **PM2 logs persist across restarts and AMI copies:** PM2 error/out logs are NOT reset on `pm2 restart` or server reboot. On EU-Region, the log files contained 42,285 lines from the old UAE code (AMI copy). Use `tail -N` for recent lines, not `head` or full file grep. To check post-deploy errors only: `pm2 flush` before deploy, or `tail -500` after. Incident: PROJ-107 — spent 30 min investigating 2,916 webhook errors that were all from old code. Verified by testing current code which handles the case correctly.
- **Missing env vars after auth code deploy:** New auth middleware (SuperTokens) reads `SUPERTOKENS_API_KEY` and `SUPABASE_JWT_SECRET` from `process.env`. Old code never needed these. Deploy fix: `grep -rn 'process.env\.' <changed-files> | sort -u` → verify each var exists on target server's `.env` BEFORE restart. Incident: Phase 0 EU-Region — two separate login failures (API key → 401, JWT secret → "secretOrPrivateKey must have a value").
- **JSONB payload key casing mismatch:** DB trigger `jsonb_build_object('order_id', ...)` vs consumer `const { orderId } = payload`. Snake_case key in trigger, camelCase destructure in consumer → `undefined`, no error, no crash. Diagnose: `SELECT prosrc FROM pg_proc WHERE proname = '<trigger_func>'` then grep consumer for destructure pattern. Prevention: past-error rule #43. Incident: PROJ-161 — all Zoho invoices blocked 24h, 9 dead jobs.
- **Zoho OAuth rate limiting on bulk job retry:** Each `new ZohoBooksService()` has its own token cache. Resetting N dead jobs simultaneously → N token requests → Zoho returns "You have made too many requests continuously." Fix: retry one at a time with 15s gaps. Root: `zoho.provider.js:108` creates new instance per job, `drainJobs()` processes back-to-back.
- **Zoho auto-number collision with manual invoices:** Finance-svc lets Zoho auto-assign invoice numbers. If a manual invoice occupies the next number in Zoho's sequence, `POST /invoices` fails with "Invoice INV-XXXX already exists." Production `createInvoice` path has no retry (staging path does). Fix: advance Next Invoice Number in Zoho Settings. Diagnose: `list_invoices` with the failing number → check if manual invoice exists. Incident: PROJ-161 — INV-XXXXXX through INV-XXXXXX were manual test invoices blocking the auto-number at 1099.

## Pattern 9: PostgREST Schema Cache Staleness at PM2 Restart
- **Symptom:** 42703 "column X.tenant_id does not exist" on tables where the column DOES exist (verified via `information_schema.columns`). Affects many tables simultaneously (locations, passes, pass_categories, system_settings, email_providers, etc.).
- **Root cause:** PostgREST caches the DB schema. After PM2 restart, if PostgREST hasn't refreshed its cache, queries referencing recently-added columns fail with 42703. Self-resolves in ~11 minutes when the cache TTL expires.
- **Diagnosis:** (1) Check `stat -c '%y'` on error log — if last modified at startup time, errors are transient. (2) Direct REST API curl with same filter works? → cache was stale, now refreshed. (3) `SELECT column_name FROM information_schema.columns WHERE table_name='X' AND column_name='tenant_id'` confirms column exists.
- **Fix:** `server.js` warm-up (added PROJ-170): after `server.listen()`, query 5 key tables. If 42703, retry 3× with 3s delay. Reduces window from 11 min to ~10s worst case.
- **Prevention:** `NOTIFY pgrst, 'reload schema'` after `apply_migration`. Hook: `pre-migration-verify.sh`.
- **Incident:** PROJ-170 — 958 errors across 12 tables during 11-min window after PM2 restart on 2026-06-14. PostgREST warm-up eliminated the burst entirely on the next restart.

## Pattern 10: Tenant-scoped RBAC breaks routes without tenantResolverMiddleware
- **Symptom:** Authenticated requests return 403 "Access denied. Required permission: X" even though the user has the role/permission. No auth errors in logs (token is valid).
- **Root cause:** `rbac.js` queries `user_roles` with `.eq('tenant_id', tenantId)`. If `tenantResolverMiddleware` is missing from the route chain, `req.tenant` is undefined, `tenantId` is null, and the query returns empty → 403.
- **Diagnosis:** (1) Add debug log: `console.log("RBAC_DBG", JSON.stringify({t:!!req.tenant}))` — `t:false` confirms missing tenant. (2) Check route file for `tenantResolverMiddleware` — if absent, that's the bug. (3) Check PM2 logs for `MISSING_CONTEXT` on `user_roles` table.
- **Key trap:** Before PROJ-183, RBAC queries didn't filter by `tenant_id`, so routes without tenant resolution worked fine. PROJ-183 added the tenant filter, silently breaking any route that lacked `tenantResolverMiddleware`.
- **Fix:** Add `router.use(tenantResolverMiddleware)` to the route file (same pattern as `payment.routes.js`).
- **Incident:** PROJ-187 — discount-code routes extracted from monolith (PROJ-082) without tenant resolver. Broke after PROJ-183 deploy (PR #274). Fixed in PR #282.
