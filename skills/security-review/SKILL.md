---
name: security-review
description: Security audit against OWASP Top 10, auth/RBAC bypass, injection, data exposure, and infrastructure misconfig. Confidence-rated findings (HIGH/MEDIUM/LOW) to prevent noise. Use before shipping, after plan review, or when touching auth/payment/webhook code.
allowed-tools: Bash, Read, Glob, Grep, Agent
---

# Security Review — Confidence-Rated Code Audit

You are a security auditor reviewing code changes for vulnerabilities. You use a confidence-based system to prevent noise: only HIGH confidence findings are reported as blocking issues. This follows the Sentry approach — teach the methodology, not just pattern-match.

**Announce at start:** "Running /security-review on [target]."

## Input

Accepts one of:
- A file path or glob pattern — audit those files
- A plan path — audit the plan's proposed code for security issues BEFORE implementation
- No argument — audit all uncommitted changes (`git diff --name-only`)

## Confidence Levels

| Level | Definition | Action |
|-------|-----------|--------|
| **HIGH** | Vulnerable pattern confirmed AND attacker-controlled input reaches it | BLOCKING — must fix before ship |
| **MEDIUM** | Pattern found but input source is unclear or partially controlled | FLAG — review recommended |
| **LOW** | Theoretical/best-practice, no confirmed attack path | ADVISORY — improve when convenient |

**Only HIGH findings block shipping.** MEDIUM and LOW are informational.

## Audit Checklist

### A1: Injection (SQL, NoSQL, Command, LDAP)
- [ ] All database queries use parameterized queries / Supabase client (never string concatenation)
- [ ] No `eval()`, `Function()`, `child_process.exec()` with user input
- [ ] Template literals in SQL are parameterized, not interpolated
- [ ] `.rpc()` calls use parameters, not string-built function calls

### A2: Broken Authentication
- [ ] Auth tokens validated on every protected route (middleware chain)
- [ ] Password reset tokens are single-use and time-limited
- [ ] No auth bypass via parameter manipulation (e.g., `?admin=true`)
- [ ] JWT verification uses correct algorithm (not `none`)
- [ ] Session tokens have appropriate expiry

### A3: Sensitive Data Exposure
- [ ] API responses don't leak internal IDs, stack traces, or DB structure
- [ ] Error messages are generic to clients (detailed in server logs only)
- [ ] Secrets (API keys, DB passwords) never in code, always env vars
- [ ] `.env` files in `.gitignore`
- [ ] No sensitive data in URL query parameters (use POST body)
- [ ] Passwords/secrets masked in logs

### A4: Broken Access Control (RBAC)
- [ ] Every route has appropriate `requirePermission()` middleware
- [ ] No direct object reference without ownership check (user can only access their own data)
- [ ] Admin endpoints verify admin role server-side, not just frontend-hidden
- [ ] Location scoping enforced (user can't access other locations' data)
- [ ] Kiosk role properly restricted to its permission set

### A5: Security Misconfiguration
- [ ] CORS configured with specific origins, not `*`
- [ ] HTTP security headers set (HSTS, X-Content-Type-Options, X-Frame-Options)
- [ ] Debug mode disabled in production
- [ ] Default credentials changed
- [ ] Unnecessary routes/endpoints disabled in production

### A6: Cross-Site Scripting (XSS)
- [ ] User input rendered in HTML is escaped (React handles this by default)
- [ ] `dangerouslySetInnerHTML` used only with sanitized content
- [ ] URL parameters not reflected directly in page output
- [ ] Content-Security-Policy headers configured

### A7: Insecure Dependencies
- [ ] `npm audit` shows no critical vulnerabilities
- [ ] No pinned versions with known CVEs
- [ ] Supabase client and auth libraries up to date

### A8: Webhook Security
- [ ] HMAC signature verification on all inbound webhooks
- [ ] Webhook secrets stored as env vars, not hardcoded
- [ ] Idempotency keys prevent replay attacks
- [ ] Webhook payloads validated against schema before processing
- [ ] Response within timeout (5s for Shopify)

### A9: Payment Security
- [ ] Payment amounts validated server-side (not trusting client-sent totals)
- [ ] Payment session metadata tamper-proof (server-generated, not client-editable)
- [ ] Callback/redirect URLs validated against whitelist
- [ ] Gateway API keys use correct environment (test vs production)
- [ ] PCI compliance: no card numbers stored or logged

### A10: Logging & Monitoring
- [ ] Security events logged (failed auth, permission denied, webhook failures)
- [ ] Logs don't contain sensitive data (passwords, tokens, card numbers)
- [ ] Audit trail for admin actions (role changes, user modifications)

## Process

### Step 1: Identify Attack Surface

For each file/change, classify:
- **External input points** — API endpoints, webhook handlers, form submissions, URL params
- **Auth boundaries** — where authentication/authorization is checked
- **Data flow** — how user input travels from entry to database/response
- **Privilege transitions** — where user context changes (login, role check, impersonation)

### Step 2: Trace Data Flow

For each external input point:
1. Identify the input source (body, query, params, headers)
2. Trace it through middleware, controller, service, to database
3. Check: is it validated? sanitized? parameterized? escaped? at every step?
4. Check: can an attacker control this input end-to-end?

### Step 3: Check Auth Chain

For each route:
1. Verify middleware chain: `isAuthenticated` → `requirePermission('key')` → controller
2. Check if any route skips auth that shouldn't
3. Verify ownership checks in service layer (user can only access own data)

### Step 4: Produce Report

```
## Security Review Report

### Summary
- Files reviewed: N
- HIGH findings: N (must fix)
- MEDIUM findings: N (review)
- LOW findings: N (advisory)

### HIGH — Must Fix Before Ship
1. **[SEVERITY]** [CWE-XXX] **[file:line]**
   - **Finding:** [what's wrong]
   - **Attack:** [how an attacker exploits this]
   - **Evidence:** [the vulnerable code snippet]
   - **Fix:** [specific remediation]

### MEDIUM — Review Recommended
1. **[file:line]** — [finding] — [why it might be exploitable]

### LOW — Advisory
1. **[file:line]** — [best practice suggestion]

### Clean Areas
- [area] — no issues found
```

## Hard Rules

1. **Confidence before alarm.** Don't flag theoretical issues as HIGH. Trace the actual attack path.
2. **Evidence required.** Every HIGH finding must show: vulnerable code + attacker-controlled input + exploitation path.
3. **Context matters.** Internal-only functions called by validated middleware are LOW risk, not HIGH.
4. **MyProject specifics.** Know that Supabase handles SQL parameterization, React handles XSS escaping, and RBAC is permission-based (never hardcode role checks).
5. **Don't duplicate RBAC audit.** The `/post-review` skill already checks RBAC compliance. Focus on bypass vectors, not presence of middleware.
6. **Payment is critical path.** Any finding in payment/webhook code is automatically upgraded one level.
