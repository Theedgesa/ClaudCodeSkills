#!/bin/bash
# production-override-expiry.sh — Auto-expire the production Supabase override
# PostToolUse hook for Bash commands
#
# If /tmp/supabase-prod-override exists and is older than 10 minutes, delete it.
# Prevents stale overrides from persisting across unrelated work.

OVERRIDE="/tmp/supabase-prod-override"

if [ ! -f "$OVERRIDE" ]; then
  exit 0
fi

# Check file age (macOS stat format)
FILE_AGE=$(( $(date +%s) - $(stat -f %m "$OVERRIDE" 2>/dev/null || echo 0) ))
MAX_AGE=600  # 10 minutes

if [ "$FILE_AGE" -gt "$MAX_AGE" ]; then
  rm -f "$OVERRIDE"
  echo "⚠️  Production Supabase override expired (${FILE_AGE}s old, max ${MAX_AGE}s). Deleted."
  echo "  Re-enable with: echo PRODUCTION_OK > /tmp/supabase-prod-override"
fi

exit 0
