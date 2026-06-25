#!/bin/bash
# playwright-test-data-guard.sh
# BLOCKS direct INSERT INTO destination tables when used as Playwright test data.
# Test data must flow through real API endpoints, not be manually inserted.
#
# Triggers on: mcp__supabase__execute_sql (PreToolUse)
# Checks: SQL contains INSERT INTO known destination tables
#
# Destination tables (data created BY the application, not prerequisites):
#   scan_activity, checkin_logs, financial_transactions, audit_log,
#   daily_consolidations, monthly_consolidations, punch_usage
#
# Allowed:
#   - DDL (ALTER, CREATE, DROP) — migrations, not test data
#   - SELECT — read queries
#   - DELETE — cleanup
#   - UPDATE — state changes
#   - INSERT into source/prerequisite tables (unified_passes, profiles, orders, etc.)

INPUT=$(cat)
SQL=$(echo "$INPUT" | grep -i "query" | head -1)

# Only check INSERT statements
if ! echo "$SQL" | grep -qi "INSERT"; then
  exit 0
fi

# Destination tables — data that should be created by the application code, not manual INSERTs
DESTINATION_TABLES="scan_activity|checkin_logs|financial_transactions|audit_log|daily_consolidations|monthly_consolidations|punch_usage"

if echo "$SQL" | grep -qiE "INSERT\s+INTO\s+($DESTINATION_TABLES)"; then
  TABLE=$(echo "$SQL" | grep -oiE "INSERT\s+INTO\s+($DESTINATION_TABLES)" | awk '{print $3}')
  cat <<EOF
BLOCKED: Direct INSERT into destination table '$TABLE' detected.

  This table is populated BY the application code during real operations.
  Inserting test data directly into it bypasses the actual code path and
  creates false-positive test results.

  Instead:
    1. Create prerequisite data in SOURCE tables (unified_passes, profiles, etc.)
    2. Trigger the real action via API (POST /api/qr-scan/log-checkin, etc.)
    3. Verify the destination table was populated correctly
    4. Then check the frontend displays the data

  Incident ref: PROJ-043 — 22 Playwright tests passed with manual INSERTs
  but enrichment fields were never populated by the real code path.

  To override (e.g., for data migration scripts):
    Add '--migration' or '--backfill' in a SQL comment.
EOF
  exit 1
fi

exit 0
