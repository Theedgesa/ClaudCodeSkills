# Check-in Investigation: Unknown / Invalid QR Scan Attempts

## How to Find Unknown Attempts

Table: `scan_activity` (NOT `scan_activities`)
Columns: `id, location, user_id, member_name, scan_source, status, result_type, result_message, pass_type, checkin_log_id, created_at, id_number, pass_expiry, entries_remaining, entries_total`

```sql
-- Find unknown/failed check-in attempts
SELECT id, created_at AT TIME ZONE 'Asia/Riyadh' AS local_time,
  location, user_id, member_name, scan_source,
  status, result_type, result_message
FROM scan_activity
WHERE member_name IS NULL OR member_name = '' OR member_name = 'Unknown'
ORDER BY created_at DESC LIMIT 20;
```

## How to Identify the User Behind a Session

1. Check **Nginx app-api-access.log** (not `access.log`) for the time window:
   ```bash
   sudo grep '02/May/2026:16:18' /var/log/nginx/app-api-access.log.1 | head -40
   ```
   - Logs rotate: today = `app-api-access.log`, yesterday = `app-api-access.log.1`, older = `.log.2.gz` etc.

2. Look for a **WebSocket upgrade** request (`HTTP/1.1" 101`) — it carries a JWT token as `?token=` query param.

3. Decode the JWT payload (second `.`-delimited segment, URL-safe base64):
   ```python
   import base64, json
   payload_b64 = token.split('.')[1]
   payload_b64 += '=' * (4 - len(payload_b64) % 4)
   print(base64.urlsafe_b64decode(payload_b64).decode('utf-8'))
   ```
   Reveals: `email`, `first_name`, `last_name`, `sub` (user_id), `role`.

## Failure Types

| `result_type` | Meaning |
|---|---|
| `invalid_qr` | QR data failed to parse (wrong format, ProjV2 QR, screen glare, empty body) |
| `validation_error` | No `qrData` field sent at all |

- `result_message` in older code = `"Invalid QR code data"` (no length)
- `result_message` in current code = `"Invalid QR code data (len=N)"` — length helps distinguish empty vs. garbage payload

## May 2 2026 Investigation: 5 Unknown Scans at Alnakheel

- **Who:** AdminUser (`admin@tenant-a.example`, user_id `<REDACTED-UUID>`)
- **When:** 2026-05-02 19:18:20–19:18:36 local (16:18 UTC) — 5 scans in 18 seconds
- **Location:** location-a, from Safari 16.6 on macOS (not the Android kiosk)
- **Session:** Started at location-b 15:40 UTC, switched to location-a 16:15 UTC
- **Cause:** Admin test scans during investigation of CustomerD/CustomerE check-in failure claims
- **ProjV2 context:** AWS EU-Region IP `<LAMBDA-IP-1>` was firing `proj2-forward/checkin` at the same time — ProjV2 members (MEM-XXXX-XXXX, MEM-XXXX-XXXX) were active at location-a, possibly their QR codes were tested on the ProjV3 scanner
- **Verdict:** Not a real incident. Own admin test session.

## Key Infrastructure Notes

- Raw QR payload is **never logged** — only result_message and length (in newer code). POST body not captured by Nginx.
- `proj2-forward/checkin` calls come from AWS EU-Region (`<LAMBDA-IP-1>`, `<LAMBDA-IP-2>`, `<LAMBDA-IP-3>`) — these are ProjV2 Lambda check-ins being forwarded to ProjV3 and are unrelated to `invalid_qr` events.
- All known `invalid_qr` events to date have originated from the `location-a` location.
