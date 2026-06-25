#!/bin/bash
# PostToolUse hook: Warn when req.tenant?.id or req.tenant.id appears
# in server/**/*.js files outside the tenant module. Advisory only.

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
FILE_PATH="${CLAUDE_FILE_PATH:-}"

if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

# Only check server/ JS files
if [[ "$FILE_PATH" != *"server/"* ]] || [[ "$FILE_PATH" != *".js" ]]; then
  exit 0
fi

# Skip allowed files
if [[ "$FILE_PATH" == *"modules/tenant/"* ]] || \
   [[ "$FILE_PATH" == *"tenantResolver.middleware.js"* ]] || \
   [[ "$FILE_PATH" == *"contact.routes.js"* ]]; then
  exit 0
fi

if [[ -f "$FILE_PATH" ]]; then
  VIOLATIONS=$(grep -cE 'req\.tenant\?' "$FILE_PATH" 2>/dev/null || echo 0)
  DIRECT=$(grep -cE 'req\.tenant\.' "$FILE_PATH" 2>/dev/null || echo 0)
  TOTAL=$((VIOLATIONS + DIRECT))

  if [[ "$TOTAL" -gt 0 ]]; then
    echo "WARNING: Tenant filter — this file has direct req.tenant access ($TOTAL occurrence(s))."
    echo "  Use getTenantId(req) or getTenant(req) from server/modules/tenant/ instead."
    echo "  Run: npm run quality:tenant-filter"
  fi
fi

exit 0
