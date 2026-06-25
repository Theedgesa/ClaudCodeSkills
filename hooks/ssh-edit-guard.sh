#!/bin/bash
# Blocks direct SSH file editing and SCP/rsync to servers
INPUT="$TOOL_INPUT"

if echo "$INPUT" | grep -qE '(ssh.*(vim|nano|sed|tee|cat\s*>)|scp.*:/var/www|rsync.*:/var/www)'; then
  echo "BLOCKED: Direct SSH file editing is prohibited."
  echo "All changes must go through: local commit -> push -> PR -> merge -> git pull"
  echo "If this is an emergency, explain the situation and get explicit user approval."
  echo "decision:block"
  exit 2
fi
