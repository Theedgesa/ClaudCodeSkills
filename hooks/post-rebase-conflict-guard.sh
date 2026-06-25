#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Post-Rebase Conflict Marker Guard
# Triggers: PreToolUse on Bash when command contains "git rebase --continue" or "git commit"
# Checks all staged/modified files for leftover conflict markers
# ═══════════════════════════════════════════════════════════════
# Incident: PROJ-170 — rebase auto-resolved one hunk but left a <<<<<<< HEAD
# marker in email.service.js. Committed and pushed before caught.

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ "$TOOL_NAME" = "Bash" ] || exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only check on rebase --continue or git commit
echo "$COMMAND" | grep -qE 'git\s+rebase\s+--continue|git\s+commit' || exit 0

# Find project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -n "$PROJECT_ROOT" ] || exit 0

cd "$PROJECT_ROOT" || exit 0

# Check staged files for conflict markers
MARKERS=$(git diff --cached --name-only 2>/dev/null | xargs grep -l '<<<<<<< \|=======$\|>>>>>>> ' 2>/dev/null)

if [ -n "$MARKERS" ]; then
    echo "⚠️  CONFLICT MARKERS found in staged files:" >&2
    echo "" >&2
    for f in $MARKERS; do
        echo "  $f:" >&2
        grep -n '<<<<<<< \|=======$\|>>>>>>> ' "$f" 2>/dev/null | head -3 | sed 's/^/    /' >&2
    done
    echo "" >&2
    echo "  Fix these before committing. Run: grep -rn '<<<<<<' server/" >&2
    echo "" >&2
    echo "decision:block" >&2
    exit 2
fi

exit 0
