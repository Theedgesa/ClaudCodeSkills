# Debugging Patterns — ProjV3

## Pattern 0: SuperTokens SDK v21 Method Signature Mismatch

**Symptom:** SuperTokens Core returns 400 with cryptic message like "Field name 'email' is invalid in JSON input", or code throws `TypeError: X is not a function`.

**Root cause:** SuperTokens Node SDK v21 changed/removed method signatures from earlier versions. The SDK silently includes `undefined` params in the JSON body sent to Core.

**Known mismatches (fixed 2026-06-07):**
- `createResetPasswordToken(tenantId, userId, email)` — 3rd param `email` is required in SDK v21. Omitting it sends `email: undefined` to Core → 400 error.
- `EmailPassword.getUserByEmail()` — method does NOT exist in v21. Use `SuperTokens.listUsersByAccountInfo(tenantId, {email})` instead.

**Audit approach:** `node -e "const EP = require('supertokens-node/recipe/emailpassword'); console.log(Object.keys(EP).join(', ')); console.log('methodName params:', EP.methodName.length)"` — verify all exports exist and check arity.

**Past-errors implication:** When wrapping SDK methods, always verify the actual SDK export signature, not docs or assumptions. SDK upgrades can silently break wrappers.

## Pattern 1: Silent Supabase null from invalid column

**Symptom:** Feature returns empty array, no error in PM2 logs, no crash.

**Root cause:** Supabase PostgREST returns `{ data: null, error: { code: '42703' } }` when a selected column doesn't exist. If code only destructures `data` (not `error`), the error is silently discarded.

```javascript
// SILENT FAILURE — error thrown away:
const { data: unifiedPassesData } = await supabase.from('table').select('bad_column');
// unifiedPassesData = null, no log, no crash

// SAFE — error surfaced:
const { data, error } = await supabase.from('table').select('bad_column');
if (error) console.error('[context] query failed', error);
```

**How to diagnose:**
1. Run the exact SQL the API uses directly in Supabase SQL editor
2. If it returns `ERROR: 42703: column "X" does not exist` → silent null in code
3. Check `information_schema.columns WHERE table_name = 'T' AND column_name = 'X'` to confirm

**How to prevent:** Always add null-check log after parallel Promise.all:
```javascript
if (!queryData) {
  console.error('[functionName] query returned null — check Supabase query for invalid columns');
}
```

**Real incident:** PROJ-070 (2026-05-02) — `getMemberDetails` selected `location` from `unified_passes`. Column doesn't exist (real column is `purchase_location_id`). All 13 members with active unified passes couldn't be checked in at reception. 1 day pass (CustomerA, SAR 90) expired before fix.

---

## Pattern 2: Two query paths for the same data — one broken, one not

**Context:** `unified_passes` data is fetched by two different code paths:
- `getMemberDetails` (`reception.controller.js:3525`) — WAS broken (wrong column)
- `scanQRCode` (`qrScan.controller.js:357`) — NOT broken (`select('*')`)

**Lesson:** When investigating "passes not showing," check WHICH endpoint is being called. The kiosk scan and the member profile lookup use different queries. One can be broken while the other works.

**Check:** If members can check in via QR kiosk but not via reception profile lookup → `getMemberDetails` is the broken path.

---

## Pattern 3: Checkin gap diagnostic query

Run this whenever "member says they can't get in" reports come in:

```sql
SELECT
  p.first_name || ' ' || p.last_name AS member,
  p.email,
  up.pass_category,
  up.expiry_date,
  up.purchase_price::text || ' SAR' AS paid,
  CASE WHEN cl.id IS NULL THEN 'NO CHECK-IN' ELSE 'checked in at ' || cl.location END AS status
FROM unified_passes up
JOIN profiles p ON p.id = up.user_id
LEFT JOIN checkin_logs cl
  ON cl.user_id = up.user_id
  AND cl.created_at >= CURRENT_DATE::timestamptz
  AND cl.type = 'checkin' AND cl.status = 'approved'
WHERE up.is_active = true
  AND up.start_date <= CURRENT_DATE
  AND up.expiry_date >= CURRENT_DATE
ORDER BY cl.id NULLS LAST, up.expiry_date ASC;
-- Rows with status = 'NO CHECK-IN' are members with valid passes who couldn't get in today
```

**Also check `scan_activity`** for failed scans — if it's empty for the affected user, they never reached the kiosk (issue is in the reception profile lookup, not the scanner).

---

## Pattern 4: Supabase email enumeration protection → FK violation on signup

**Symptom:** New user signup returns "Database error saving new user" / FK violation `profiles_id_fkey`.

**Root cause:** When Supabase email confirmation is enabled, signing up with an existing email returns a fake user object (`identities: []`) instead of an error. Inserting a profile with that fake UUID causes FK violation since the UUID isn't in `auth.users`.

**Fix:** Check `authData.user?.identities?.length === 0` before `createInitialProfile`. Return 409 with clear message.

**File:** `server/controllers/auth.controller.js` — PROJ-070 session (hotfix, 2026-05-02).

---

## Pattern 5: MyFatoorah payment fails — mobile number too long

**Symptom:** Customer gets error on payment. No crash in logs — MyFatoorah rejects the request silently.

**Root cause:** `mobile_number` stored with country code prefix (e.g., `<REDACTED-PHONE>`) while `mobile_country_code` is `+966`. MyFatoorah receives `+966<REDACTED-PHONE>` which exceeds the 11-digit `CustomerMobile` limit.

**Fix:** Strip the country code prefix from `mobile_number`:
```sql
UPDATE profiles SET mobile_number = '<REDACTED-PHONE>'
WHERE id = '<uuid>' AND mobile_number LIKE '966%';
```

**Root cause origin:** OnboardingModal has a plain text input — users type full number with country code, stored verbatim. PROJ-067 added server-side normalization in `profile.controller.js:updateProfile`, but profiles created before the fix (or via other paths) may still have the bad format.

**Diagnostic query:**
```sql
SELECT id, email, first_name, last_name, mobile_number, mobile_country_code
FROM profiles
WHERE mobile_country_code IS NOT NULL
  AND mobile_number LIKE CONCAT(REPLACE(mobile_country_code, '+', ''), '%');
```

**Real incidents:**
- PROJ-067 (2026-04-29): 24 profiles bulk-fixed
- 2026-05-09: CustomerB (`user3@example.com`) — same bug, manually fixed

---

## Pattern 6: Staff email shows "at Unknown" for location-agnostic passes

**Symptom:** Staff notification email subject shows "New Pass Purchase — Name (Day Pass) at Unknown".

**Root cause:** `emailWorkflow.service.js:169` defaults `locationName` to `'Unknown'` when `context.locationSlug` is empty. Location-agnostic passes (day passes with `valid_at_all_locations = true`) have no location assigned, so `locationSlug` is always empty string.

**Fix:** Changed default from `'Unknown'` to `'All Locations'` in `emailWorkflow.service.js:169`.

**File:** `server/services/emailWorkflow.service.js` — line 169.

---

## Pattern 7: normalizeEmail() breaks OTP verification for Gmail users

**Symptom:** User enters correct 6-digit OTP code → "Token has expired or is invalid" error.

**Root cause:** `validator.normalizeEmail()` strips Gmail dots (`first.last` → `firstlast`) and `+` subaddresses (`user+tag` → `user`) by default. The mangled email is sent to `supabase.auth.verifyOtp()` which can't find a token for it — auth.users stores the original email.

**Evidence:**
```javascript
validator.normalizeEmail('dev+signuptest@example.com')
// → 'dev@example.com'  (dots stripped, +alias stripped)

validator.normalizeEmail('user2@example.com')
// → 'user2@example.com'  (dots stripped)
```

**Fix:** Replace `.normalizeEmail()` with `.trim().toLowerCase()` in express-validator chains. Preserves exact email while still lowercasing.

**Affected file:** `server/routes/verification.routes.js` — PROJ-101 (2026-05-20).

**Broader lesson:** Never use `normalizeEmail()` on emails that must match Supabase auth records. Gmail dot-equivalence is Gmail's concern, not ours — Supabase stores the exact email.

---

## Pattern 8: Supabase upsert throws 23505 instead of UPDATE

**Symptom:** `.upsert(data, { onConflict: 'id' })` throws `23505 profiles_pkey` instead of doing an UPDATE when the row already exists.

**Root cause:** Supabase client/PostgREST quirk when a DB trigger creates the row between the initial check and the upsert. The upsert sees a conflict but throws instead of updating.

**Fix:** Catch `error.code === '23505'` with `profiles_pkey` in the message, then retry as explicit `.update(fields).eq('id', userId)`.

```javascript
if (error.code === '23505' && (error.message || '').includes('profiles_pkey')) {
  const { id: _id, ...updateFields } = profileData;
  const { error: updateError } = await supabaseAdmin
    .from('profiles').update(updateFields).eq('id', userId);
  if (updateError) throw updateError;
}
```

**Affected file:** `server/controllers/auth.controller.js` — PROJ-100 (2026-05-20).

---

**Updated:** 2026-05-20
