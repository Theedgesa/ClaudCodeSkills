#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Shallow CR Guard — PostToolUse on Write/Edit
# When implementation report is written with 3+ phases and
# zero CRs, flags as suspicious.
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

[[ -z "$FILE_PATH" ]] && exit 0

# Only trigger on report.md files
if [[ "$FILE_PATH" != *"/.claude/work/"*"/report.md" ]]; then
    exit 0
fi

[[ ! -f "$FILE_PATH" ]] && exit 0

CONTENT=$(cat "$FILE_PATH")

# Count completed phases in report
PHASE_COUNT=$(echo "$CONTENT" | grep -ciE "^### Phase [0-9].*—.*(COMPLETE|PASS)" || true)

# Count CRs mentioned
CR_COUNT=$(echo "$CONTENT" | grep -ciE "(CR-[0-9]+|change record|zero bugs|0 CRs)" || true)

# Only flag if 3+ phases completed and zero CR references
if [ "$PHASE_COUNT" -ge 3 ] && [ "$CR_COUNT" -eq 0 ]; then
    echo ""
    echo "  SUSPICIOUS: $PHASE_COUNT phases completed with zero Change Records."
    echo "  ───────────────────────────────────────────────────────────────"
    echo "  Complex implementations without a single design change discovered"
    echo "  during implementation are statistically unlikely."
    echo ""
    echo "  Either:"
    echo "  1. CRs were created but not documented in the report (add them)"
    echo "  2. No bugs were found (justify in each phase gate CR checkpoint)"
    echo "  3. Bugs were found but no CRs created (review change-records.md)"
    echo ""
fi

exit 0
