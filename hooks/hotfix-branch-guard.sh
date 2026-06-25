#!/bin/bash
# hotfix-branch-guard.sh — Block creating branches with "hotfix/" prefix
# PreToolUse hook for Bash commands
#
# All changes go through plan → approve → implement → PR.
# No hotfix branches. Use fix/ prefix instead.

TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

if [ -z "$TOOL_INPUT" ]; then
  exit 0
fi

# Extract command from JSON input
COMMAND=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Check for hotfix branch creation
if echo "$COMMAND" | grep -qiE '(git checkout -b|git branch|git switch -c)\s+hotfix/'; then
  echo "BLOCKED: No hotfix branches. Use fix/ prefix instead."
  echo "  All changes go through: plan → approve → implement → PR"
  echo "  Workflow rule: workflow.md line 6"
  echo "decision:block"
  exit 2
fi

exit 0
