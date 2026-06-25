#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# CR Propagation Guard — PreToolUse on Write/Edit
# During active plan implementation, checks git diff for
# objective CR triggers. If schema, API shape, auth, state, or
# business rule changes detected without a CR, warns.
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

[[ -z "$FILE_PATH" ]] && exit 0

# Only during active plan implementation
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[[ -z "$PROJECT_ROOT" ]] && exit 0

ACTIVE_FILE="$PROJECT_ROOT/.claude/work/.active"
[[ ! -f "$ACTIVE_FILE" ]] && exit 0

ACTIVE_BRANCH=$(cat "$ACTIVE_FILE" 2>/dev/null)
[[ -z "$ACTIVE_BRANCH" ]] && exit 0

PLAN_FILE="$PROJECT_ROOT/.claude/work/$ACTIVE_BRANCH/plan.md"
[[ ! -f "$PLAN_FILE" ]] && exit 0

# Skip if editing plan/spec/report files (those ARE the CR propagation)
if [[ "$FILE_PATH" == *"/plan.md" ]] || [[ "$FILE_PATH" == *"/report.md" ]] || [[ "$FILE_PATH" == *"/specs/"* ]]; then
    exit 0
fi

# Only check implementation files
if ! echo "$FILE_PATH" | grep -qE '\.(js|mjs|ts|tsx|sql)$'; then
    exit 0
fi

# Check staged + unstaged diff for objective CR triggers
DIFF=$(git diff HEAD -- "$FILE_PATH" 2>/dev/null || true)
[[ -z "$DIFF" ]] && exit 0

TRIGGERS_FOUND=""

# Schema changes (new column, altered constraint, new trigger)
if echo "$DIFF" | grep -qE '^\+.*(ALTER TABLE|ADD COLUMN|DROP COLUMN|CREATE TRIGGER|ADD CONSTRAINT|DROP CONSTRAINT)'; then
    TRIGGERS_FOUND="${TRIGGERS_FOUND}schema "
fi

# API response shape changes (new/removed fields in res.json)
if echo "$DIFF" | grep -qE '^\+.*res\.(json|send)\(' && echo "$DIFF" | grep -qE '^\-.*res\.(json|send)\('; then
    TRIGGERS_FOUND="${TRIGGERS_FOUND}api-shape "
fi

# Auth/permission changes
if echo "$DIFF" | grep -qE '^\+.*(requirePermission|isAuthenticated|requireAuth)' || \
   echo "$DIFF" | grep -qE '^\-.*(requirePermission|isAuthenticated|requireAuth)'; then
    TRIGGERS_FOUND="${TRIGGERS_FOUND}auth "
fi

# State machine changes (status values)
if echo "$DIFF" | grep -qE "^\+.*status.*=.*['\"]" && echo "$DIFF" | grep -qE "^\-.*status.*=.*['\"]"; then
    TRIGGERS_FOUND="${TRIGGERS_FOUND}state "
fi

if [[ -n "$TRIGGERS_FOUND" ]]; then
    # Check if plan already has a Change Records section with entries
    CR_COUNT=$(grep -c "^### CR-" "$PLAN_FILE" 2>/dev/null || true)

    echo ""
    echo "  CR TRIGGER DETECTED in $(basename "$FILE_PATH"): $TRIGGERS_FOUND"
    echo "  ───────────────────────────────────────────────────"
    echo "  Objective CR triggers require a Change Record."
    echo "  Run /cr to create one, or justify why this is planned (not a bug fix)."
    echo ""
    echo "  Current CRs in plan: $CR_COUNT"
    echo ""
fi

exit 0
