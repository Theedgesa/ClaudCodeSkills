#!/bin/bash
# Runs quality gate before PR creation
INPUT="$TOOL_INPUT"

if echo "$INPUT" | grep -q 'gh pr create'; then
  cd "$PROJECT_ROOT" 2>/dev/null || exit 0
  echo "Running quality gate before PR creation..."
  if ! npm run quality 2>&1; then
    echo "BLOCKED: Quality gate failed. Fix issues before creating PR."
    echo "decision:block"
    exit 2
  fi
  echo "Quality gate passed."
fi
