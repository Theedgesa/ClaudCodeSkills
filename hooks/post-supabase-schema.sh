#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Post-Supabase Schema Change Hook
# ═══════════════════════════════════════════════════════════════
# Triggers after mcp__supabase__execute_sql or mcp__supabase__apply_migration
# Detects schema-changing DDL and warns about PostgREST cache staleness
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Only check Supabase SQL tools
if [[ "$TOOL_NAME" != *"supabase"*"execute_sql"* && "$TOOL_NAME" != *"supabase"*"apply_migration"* ]]; then
    exit 0
fi

# Get the SQL query from tool input
QUERY=$(echo "$INPUT" | jq -r '.tool_input.query // empty' 2>/dev/null)

if [[ -z "$QUERY" ]]; then
    exit 0
fi

QUERY_LOWER=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')

# Detect schema-changing DDL
IS_DDL=0
if echo "$QUERY_LOWER" | grep -qE '(alter\s+table|create\s+table|drop\s+table|add\s+column|drop\s+column|rename\s+column|add\s+constraint|drop\s+constraint)'; then
    IS_DDL=1
fi

if [[ "$IS_DDL" -eq 1 ]]; then
    echo ""
    echo "  ⚠️  SCHEMA CHANGE DETECTED — PostgREST cache may be stale."
    echo ""
    echo "  The running dev server's Supabase client may return stale data"
    echo "  for new/modified columns until the server is restarted."
    echo ""
    echo "  Action: Restart the dev server before testing queries that use new columns."
    echo "    lsof -ti:5001 | xargs kill -9 2>/dev/null"
    echo "    cd server && node server.js &"
    echo ""
    echo "  Note: Production deploys always restart PM2, so this is dev-only."
    echo ""
fi

exit 0
