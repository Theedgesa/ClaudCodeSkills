#!/bin/bash
# PostToolUse hook: Warn when .from('profiles') or .from('checkin_logs') appears
# outside server/modules/customer/. Advisory only (does not block).

# Only check Write and Edit tool calls on server/ files
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
FILE_PATH="${CLAUDE_FILE_PATH:-}"

if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

# Only check server/ JS files
if [[ "$FILE_PATH" != *"server/"* ]] || [[ "$FILE_PATH" != *".js" ]]; then
  exit 0
fi

# Skip if inside the customer module (that's the owner)
if [[ "$FILE_PATH" == *"modules/customer/"* ]]; then
  exit 0
fi

# Check if file contains table violations
if [[ -f "$FILE_PATH" ]]; then
  PROFILES=$(grep -c "\.from('profiles')" "$FILE_PATH" 2>/dev/null || echo 0)
  CHECKIN=$(grep -c "\.from('checkin_logs')" "$FILE_PATH" 2>/dev/null || echo 0)

  if [[ "$PROFILES" -gt 0 ]] || [[ "$CHECKIN" -gt 0 ]]; then
    echo "WARNING: Table ownership — this file has .from('profiles') ($PROFILES) or .from('checkin_logs') ($CHECKIN) calls."
    echo "  New code should use customerService or customerCheckin from server/modules/customer/"
    echo "  Existing violations are baselined. Run: npm run quality:table-ownership"
  fi
fi

exit 0
