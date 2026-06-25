#!/bin/bash
# PostToolUse: Write|Edit — Check for .from('table').eq() without .select() in between
# Prevents: Supabase chain order bug where .eq() is called on QueryBuilder instead of FilterBuilder
# Incident: PROJ-MT5 — 163 instances of .from('table').eq('tenant_id') that crash at runtime

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_response.filePath // .tool_input.file_path // ""')

# Only check .js files in server/ or finance-service/
if ! echo "$FILE" | grep -qE "(server|finance-service)/.*\.js$"; then
  exit 0
fi

if [ ! -f "$FILE" ]; then
  exit 0
fi

# Check for .from('table').eq( pattern (without .select/.update/.delete/.insert in between)
VIOLATIONS=$(grep -n "\.from(['\"][^'\"]*['\"])\.eq(" "$FILE" 2>/dev/null | grep -v "\.update\|\.delete\|\.insert\|\.upsert\|//" | head -5)

if [ -n "$VIOLATIONS" ]; then
  cat <<JSONEOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "SUPABASE CHAIN BUG: .from('table').eq() found — Supabase requires .select() (or .update/.delete/.insert) before .eq(). The pattern .from().eq() crashes with 'eq is not a function'. Fix: move .eq() after .select(). Violations:\n$VIOLATIONS"
  }
}
JSONEOF
fi
