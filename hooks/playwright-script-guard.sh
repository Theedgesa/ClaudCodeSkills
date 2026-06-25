#!/bin/bash
# Block Playwright test scripts — enforce MCP browser tools instead
# Incident: PROJ-170 — 6 failed PW script iterations (3+ hours) vs 1 MCP browser session (15 min)

# --- Bash matcher: block running playwright test commands ---
if [ "$TOOL_NAME" = "Bash" ]; then
  COMMAND="$TOOL_INPUT"
  if echo "$COMMAND" | grep -qE 'npx playwright test|npx playwright run'; then
    echo "BLOCKED: Use MCP browser tools (browser_navigate, browser_snapshot, browser_click) for interactive UI testing." >&2
    echo "" >&2
    echo "  MCP browser tools give you the accessibility snapshot with exact element" >&2
    echo "  refs before each click. Playwright scripts require knowing selectors upfront." >&2
    echo "" >&2
    echo "  If you need to run an existing regression suite, ask the user first." >&2
    echo "  Past-errors rule #54." >&2
    exit 1
  fi
fi

# --- Write matcher: block creating new .spec.ts files ---
if [ "$TOOL_NAME" = "Write" ]; then
  FILE_PATH="$TOOL_FILE_PATH"
  if echo "$FILE_PATH" | grep -qE '\.spec\.ts$'; then
    echo "BLOCKED: Do not create new Playwright test scripts." >&2
    echo "  Use MCP browser tools (browser_navigate/snapshot/click) for interactive testing." >&2
    echo "  Past-errors rule #54." >&2
    exit 1
  fi
fi
