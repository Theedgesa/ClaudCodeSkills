#!/bin/bash
# Reminds to query codebase-memory when editing across server + frontend
INPUT="$TOOL_INPUT"
FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')

if echo "$FILE_PATH" | grep -qE '(store-website|reception-website)'; then
  # Check if server files were edited in recent context
  if [ -f /tmp/.claude-cross-stack-server ]; then
    echo "Cross-stack change detected (server + frontend in same session)."
    echo "Query codebase-memory trace_call_path before proceeding."
    rm -f /tmp/.claude-cross-stack-server
    echo "decision:warn"
    exit 1
  fi
elif echo "$FILE_PATH" | grep -q 'server/'; then
  touch /tmp/.claude-cross-stack-server
fi
