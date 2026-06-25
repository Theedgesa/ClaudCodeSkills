#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Pre-Migration DB State Verification
# Triggers: PostToolUse on mcp__supabase__apply_migration
# Reminds to verify schema BEFORE applying migration
# ═══════════════════════════════════════════════════════════════
# Incident: PROJ-170 — plan said "column email_providers.tenant_id does not
# exist" but it had existed since March 29 (proj_042). Migration had to be
# adapted at execution time. Rule #51: always verify information_schema first.

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ "$TOOL_NAME" = "mcp__supabase__apply_migration" ] || exit 0

QUERY=$(echo "$INPUT" | jq -r '.tool_input.query // empty' 2>/dev/null)

# Check if migration adds columns
if echo "$QUERY" | grep -qiE 'ADD\s+COLUMN'; then
    COLUMNS=$(echo "$QUERY" | grep -oiE 'ADD\s+COLUMN\s+(IF\s+NOT\s+EXISTS\s+)?[a-z_]+' | awk '{print $NF}')
    TABLES=$(echo "$QUERY" | grep -oiE 'ALTER\s+TABLE\s+[a-z_]+' | sed 's/.*\s//')

    echo ""
    echo "  📋 Migration adds columns. Did you verify they don't already exist?"
    echo "  Run BEFORE applying:"
    echo "    SELECT table_name, column_name FROM information_schema.columns"
    echo "    WHERE column_name IN ('${COLUMNS}') AND table_schema = 'public'"
    echo ""
    echo "  Past-errors rule #51: Always verify DB state before migration."
    echo ""
fi

exit 0
