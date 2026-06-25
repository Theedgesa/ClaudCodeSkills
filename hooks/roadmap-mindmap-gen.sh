#!/usr/bin/env bash
# PostToolUse hook: regenerate mindmap when roadmap.yaml is written
# Runs async so it doesn't block the main flow

TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
FILE=$(echo "$TOOL_INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')

# Only trigger on roadmap.yaml
if [[ "$FILE" != *"roadmap.yaml"* ]]; then
  exit 0
fi

SCRIPT="$PROJECT_ROOT/scripts/roadmap-mindmap.mjs"

if [[ -f "$SCRIPT" ]]; then
  node "$SCRIPT" >/dev/null 2>&1 &
fi

exit 0
