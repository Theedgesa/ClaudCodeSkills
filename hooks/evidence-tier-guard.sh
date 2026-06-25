#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Evidence Tier Guard — PostToolUse on Bash
# Warns when static analysis (T1) or unit/mocked (T2) output
# is used as evidence for T3+ requirements during verification.
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[[ "$TOOL_NAME" != "Bash" ]] && exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Check if we're in an active plan (implementation mode)
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[[ -z "$PROJECT_ROOT" ]] && exit 0

ACTIVE_FILE="$PROJECT_ROOT/.claude/work/.active"
[[ ! -f "$ACTIVE_FILE" ]] && exit 0

# Detect T1 static analysis commands used during verification
T1_PATTERNS="node --check|npx tsc --noEmit|npm run quality|eslint|prettier --check"

if echo "$COMMAND" | grep -qE "$T1_PATTERNS"; then
    # Check if the output context suggests this is being used as REQ evidence
    TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // empty' 2>/dev/null)

    # Only warn — don't block. These commands are valid for build checks.
    echo ""
    echo "  T1 EVIDENCE REMINDER: This is static analysis (T1)."
    echo "  T1 evidence is valid for build/syntax checks but NOT for:"
    echo "  - Functional REQs (need T3+: DB query after operation)"
    echo "  - Data Integrity REQs (need T3+: independent verification)"
    echo "  - Security REQs (need T3+: actual auth validation)"
    echo "  If scoring a REQ as Green, ensure you also have T3+ evidence."
    echo ""
fi

exit 0
