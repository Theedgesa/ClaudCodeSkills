#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# PR Merge Guard — PreToolUse Hook
# ═══════════════════════════════════════════════════════════════
# Blocks `gh pr merge` commands. PRs must never be merged without
# explicit user approval.
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if echo "$COMMAND" | grep -qE 'gh\s+pr\s+merge'; then
    echo '{"decision":"block","reason":"BLOCKED: gh pr merge is not allowed. Create the PR and send the link — never merge without explicit user approval."}'
    exit 0
fi

exit 0
