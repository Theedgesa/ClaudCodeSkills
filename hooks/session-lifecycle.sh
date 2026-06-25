#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Session Lifecycle — Consolidated SessionStart + Stop Hook
# ═══════════════════════════════════════════════════════════════
# Routes by hook_event_name:
#   SessionStart → Project context injection
#   Stop         → Uncommitted changes reminder + cleanup
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)

# Detect MyProject project
IS_PROJECT=0
if [[ "$PWD" == *"MyProject"* ]] || [[ "$PWD" == *"MyProject-v3"* ]] || [[ "$PWD" == *"myproject"* ]]; then
    IS_PROJECT=1
fi

# Outside project → silent exit
if [ "$IS_PROJECT" -eq 0 ]; then
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# ROUTE: SESSION START — Context injection
# ═══════════════════════════════════════════════════════════════
if [[ "$EVENT" == "SessionStart" ]]; then
    BRANCH=$(git -C "$PWD" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    UNCOMMITTED=$(git -C "$PWD" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    LAST_COMMIT=$(git -C "$PWD" log -1 --format="%h %s" 2>/dev/null || echo "none")

    echo ""
    echo "PROJECT: branch=$BRANCH | uncommitted=$UNCOMMITTED | last=$LAST_COMMIT"
    echo "RULES: (1) Restart server before testing (2) BEGIN/COMMIT for SQL (3) Never commit to main"
    echo ""

    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# ROUTE: STOP — Uncommitted changes reminder + cleanup
# ═══════════════════════════════════════════════════════════════
if [[ "$EVENT" == "Stop" ]]; then
    UNCOMMITTED=$(git -C "$PWD" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    if [ "$UNCOMMITTED" -gt 0 ]; then
        echo ""
        echo "NOTE: $UNCOMMITTED uncommitted file(s). Consider committing before ending session."
        echo ""
    fi

    # Clean up .active session lock file
    for CANDIDATE in "$PWD/.claude/work/.active" "$PWD/MyProject-v3/.claude/work/.active"; do
        if [[ -f "$CANDIDATE" ]]; then
            rm -f "$CANDIDATE"
            echo "  Cleaned up .active session lock."
            break
        fi
    done

    exit 0
fi

# Unknown event — silent exit
exit 0
