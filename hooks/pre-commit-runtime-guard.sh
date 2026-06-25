#!/bin/bash
# PreToolUse: Bash — Block git commit if no runtime smoke test evidence
# Prevents: committing code that passes static analysis but crashes at runtime
# Incident: PROJ-MT5 — 163 .from().eq() chain bugs, 4 undefined tenantId sources
#           all passed npm run quality but 500'd on actual HTTP requests

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only check git commit commands
if ! echo "$COMMAND" | grep -qE "git commit"; then
  exit 0
fi

# Check for runtime evidence marker
EVIDENCE_FILE=".claude/work/.runtime-evidence"
if [ -f "$EVIDENCE_FILE" ]; then
  # Evidence exists — check it's from the last 30 minutes
  EVIDENCE_AGE=$(( $(date +%s) - $(stat -f %m "$EVIDENCE_FILE" 2>/dev/null || echo 0) ))
  if [ "$EVIDENCE_AGE" -lt 1800 ]; then
    exit 0
  fi
fi

cat <<'JSONEOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "PRE-COMMIT RUNTIME CHECK: No recent runtime evidence found. Before committing, start the server and hit key endpoints to verify no 500s. Run: PORT=5555 node server/server.js & sleep 5 && curl -s -o /dev/null -w '%{http_code}' http://localhost:5555/api/locations. Then write evidence: echo $(date) > .claude/work/.runtime-evidence"
  }
}
JSONEOF
