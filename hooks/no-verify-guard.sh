#!/bin/bash
# Blocks any git command with --no-verify
INPUT="$TOOL_INPUT"

if echo "$INPUT" | grep -q -- '--no-verify'; then
  echo "BLOCKED: --no-verify is prohibited. All commits must pass hooks."
  echo "decision:block"
  exit 2
fi
