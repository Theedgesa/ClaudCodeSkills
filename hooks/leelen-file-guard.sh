#!/bin/bash
# Blocks writes to Leelen Curtain Motor directory until user approves
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

if echo "$FILE_PATH" | grep -q "Leelen Curtain Motor"; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"LEELEN FILE GUARD: Writing to Leelen Curtain Motor directory. Approve?"}}'
fi
