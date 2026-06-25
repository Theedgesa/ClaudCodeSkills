---
name: Finance-svc debugging patterns
description: Hard-won debugging knowledge from May 6-7 session. MF KeyType, Tamara JWT, webhook dual-format, sessionStorage for gateway-stripped params.
type: reference
---

# Finance-svc Debugging Patterns

## MF GetPaymentStatus KeyType
- `gateway_session_id` in `payment_sessions` stores MF's **InvoiceId** (e.g., `<INVOICE-REF>`)
- MF's redirect URL has **PaymentId** (e.g., `<PAYMENT-REF>`) — completely different value
- `verifyPayment(reference, keyType)` defaults to `keyType='PaymentId'`
- When calling from verify endpoint with `gateway_session_id`, MUST pass `'InvoiceId'` as keyType
- Wrong keyType → `"No data match the provided values"` every time — looks like a timing issue but isn't

## Tamara JWT is Auth-Only
- Tamara webhook JWT contains ONLY `{ exp, iat, iss }` — no event data
- Event data (`order_status`, `order_id`, `order_reference_id`) is in `req.body`
- JWT is for signature verification only, not a data carrier
- `handleNotification` must read from `req.body`, use JWT only for `jwt.verify()`

## Tamara Dual Webhook Format
- **merchant_url webhook** (per-checkout): `{ order_status: "approved", order_id, order_reference_id }`
- **Portal webhook** (registered in Tamara dashboard): `{ event_type: "order_approved", order_id, order_reference_id, order_number }`
- Must handle both: `req.body.event_type || ('order_' + req.body.order_status)`

## Tamara Lifecycle: approved → authorized → captured
- `approved` webhook → call `/authorise` API → update tamara_state to `authorized`
- `authorised` webhook (from portal) → write outbox + call `/capture` API → update to `captured`
- Capture needs `amount` from `session.amount` DB column (not from webhook body — body has no amount)
- Portal webhooks must be registered for ALL events in Tamara Partner Portal (Settings → Webhooks)

## MF Strips URL Params
- MF's `SendPayment` API accepts our `CallBackUrl` but replaces query params on redirect
- We send: `?gateway=myfatoorah&ref=X` → MF redirects with: `?paymentId=X&Id=X`
- Solution: store `ref` in `sessionStorage` before redirect, read on return
- `paymentApi.initializePayment` stores `response.data.ref` in sessionStorage
- Success page reads: `searchParams.get('ref') || sessionStorage.getItem('payment_ref')`

## Two-Layer Inventory System
- Parent table: `products.stock_quantity` / `rentals.available_quantity` — flat number, **storefront reads this**
- Per-location: `product_inventory.quantity` / `rental_inventory.quantity` — per-location, **reception reads this**
- Must update BOTH when changing stock
- Per-location rows must exist for the correct location slugs (staging: location-b/location-a, not tenant-a-store/tenant-a)
- Catalog has 15-minute in-memory cache — restart API after DB changes

## Staging vs Local Worktree Drift
- Changes applied via SSH on staging are NOT in the local git worktree
- Critique agents read local files → false positives if staging has newer code
- Always commit staging changes to git before running critique
- Use `ssh staging-server` as source of truth, not local file reads
