---
name: tc-impact
description: Analyze tenant and client impact of planned changes across all tenants. Checks data isolation, config divergence, client-facing UX changes, breaking API changes, and migration requirements per tenant. Use before approving plans that touch shared infrastructure, multi-tenant code, or client-visible features.
allowed-tools: Bash, Read, Glob, Grep, Agent
---

# T&C Impact — Tenant & Client Impact Analysis

You are analyzing the impact of a planned change on all tenants and their end-user clients. This skill ensures no tenant is broken, no client experience degrades, and no data leaks across tenant boundaries.

**Announce at start:** "Running /tc-impact on [target]."

## Input

Accepts one of:
- A plan path — analyze tenant/client impact of the planned changes
- A file path or glob — analyze impact of changes in those files
- No argument — analyze all uncommitted changes

## Context: MyProject Tenants

Current tenants (from multi-tenant spec):
- **TenantA** — primary tenant, production (live)
- **TenantB** — planned second tenant (PROJ-143)
- **Future tenants** — any facility onboarded via the SaaS platform

Client types per tenant:
- **Admin staff** — reception dashboard users (manage_settings, manage_members, etc.)
- **Receptionists** — check-in, order placement, member lookup
- **Kiosk** — self-service check-in terminal
- **Members** — authenticated customers with profiles and passes
- **Guests** — unauthenticated visitors (Shopify orders, walk-ins)

## Analysis Framework

### 1. Tenant Data Isolation

For every DB query or mutation in the change:

- [ ] Query includes tenant_id filter (or will after multi-tenant migration)
- [ ] No cross-tenant data leakage possible (user A can't see tenant B's data)
- [ ] Tenant-specific config (locations, pass categories, email templates) is scoped
- [ ] Shared tables (if any) have proper tenant_id columns
- [ ] Cron jobs and background workers are tenant-aware

**Flag:** Any query that accesses data without tenant scoping = HIGH impact.

### 2. Tenant Configuration Divergence

Check if the change assumes configuration that may differ between tenants:

- [ ] Location slugs — hardcoded values that only exist for one tenant?
- [ ] Pass categories — assuming specific slugs (day_pass, punch_card) exist everywhere?
- [ ] Payment gateways — assuming MyFatoorah is available (TenantB might use different gateway)?
- [ ] Email templates — assuming specific template slugs exist?
- [ ] Zoho integration — assuming Zoho is configured (some tenants may not use it)?
- [ ] Shopify — assuming Shopify webhooks are active (currently DOWN for TenantA)?
- [ ] Operating hours, timezone, currency — hardcoded or configurable?

**Flag:** Any hardcoded assumption about tenant-specific config = MEDIUM impact.

### 3. Client-Facing UX Impact

For each client type, assess:

**Admin staff:**
- Does the change affect dashboard layout, navigation, or available actions?
- Are new permissions required that existing admin users don't have?
- Does it change how existing features work (breaking muscle memory)?

**Receptionists:**
- Does the change affect check-in flow, order placement, or member lookup?
- Is the change visible immediately or requires page refresh?
- Does it affect POS/payment flow?

**Kiosk:**
- Does the change affect the self-service check-in screen?
- Is the kiosk role properly excluded from non-kiosk features?

**Members (storefront):**
- Does the change affect the public booking/purchase flow?
- Are existing bookings/passes affected?
- Does it change URLs or navigation?

**Guests:**
- Does the change affect unauthenticated purchase flow?
- Are guest orders still tracked via shopify_customer_id?

### 4. Breaking API Changes

For every API endpoint modified:

- [ ] Existing request format still accepted (backward compatible)
- [ ] Existing response shape preserved (no removed fields)
- [ ] New required fields have defaults or migration path
- [ ] Frontend code updated to match any response changes
- [ ] Mobile/APK clients considered (if applicable)

### 5. Migration Requirements Per Tenant

If the change requires data migration:

- [ ] Migration SQL is tenant-aware (runs per tenant, not globally)
- [ ] Existing data is preserved (no destructive changes without backup)
- [ ] Migration is idempotent (safe to re-run)
- [ ] Migration order matters? (tenant A before tenant B?)
- [ ] Rollback plan exists per tenant

### 6. Feature Flag & Rollout Strategy

- [ ] Can this be rolled out to one tenant at a time?
- [ ] Is there a feature flag or config toggle to enable/disable per tenant?
- [ ] What's the rollback plan if it breaks for one tenant but works for another?
- [ ] Does the change require coordinated deployment across all tenants?

## Output Format

```
## T&C Impact Report

### Summary
- Tenants affected: [list]
- Client types affected: [list]
- Impact level: HIGH / MEDIUM / LOW
- Migration required: Yes / No
- Breaking changes: Yes / No

### Per-Tenant Impact

#### TenantA (production)
- **Data isolation:** [SAFE / AT RISK — details]
- **Config compatibility:** [COMPATIBLE / NEEDS CONFIG — details]
- **Client impact:** [list affected client types and what changes for them]
- **Migration:** [needed? SQL? manual steps?]

#### TenantB (planned)
- **Data isolation:** [SAFE / AT RISK — details]
- **Config compatibility:** [COMPATIBLE / NEEDS CONFIG — details]
- **Client impact:** [list affected client types and what changes for them]
- **Migration:** [needed? SQL? manual steps?]

#### Future Tenants
- **Onboarding impact:** Does this change make onboarding harder or easier?
- **Assumptions:** What tenant-specific assumptions does this change introduce?

### Breaking Changes
1. [endpoint/feature] — [what breaks] — [who is affected] — [mitigation]

### Recommendations
1. [specific action to take before shipping]

### Rollout Strategy
- [ ] Phase 1: [deploy to staging, verify for tenant X]
- [ ] Phase 2: [deploy to production for tenant X]
- [ ] Phase 3: [enable for tenant Y]
```

## Hard Rules

1. **Every DB query must be checked for tenant scoping.** Even if multi-tenant isn't live yet, changes should be forward-compatible.
2. **Never assume tenant config is uniform.** What works for TenantA may not exist for TenantB.
3. **Client impact is per-type, not aggregate.** "Users are affected" is not specific enough — which users? Doing what?
4. **Breaking API changes require migration path.** You can't just change the response shape and hope frontends adapt.
5. **Data isolation violations are always HIGH.** Cross-tenant data access is the most critical multi-tenant bug.
6. **Backward compatibility is mandatory.** Unless the plan explicitly documents a breaking change with migration.
