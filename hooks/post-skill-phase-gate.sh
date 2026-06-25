#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Phase Gate Manifest — PostToolUse Hook for Skill
# ═══════════════════════════════════════════════════════════════
# After /implement loads, writes .phases-required manifest from plan.
# Informs agent to create phase tasks before editing code.
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
if [[ "$TOOL_NAME" != "Skill" ]]; then
    exit 0
fi

# Only trigger for implement skill
SKILL_NAME=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
if [[ "$SKILL_NAME" != "implement" ]]; then
    exit 0
fi

# Detect MyProject project
IS_PROJECT=0
if [[ "$PWD" == *"MyProject"* ]] || [[ "$PWD" == *"MyProject-v3"* ]] || [[ "$PWD" == *"myproject"* ]]; then
    IS_PROJECT=1
fi

if [ "$IS_PROJECT" -eq 0 ]; then
    exit 0
fi

# Find project root
PROJECT_ROOT=""
CHECK_DIR="$PWD"
while [[ "$CHECK_DIR" != "/" ]]; do
    if [[ -d "$CHECK_DIR/MyProject-v3/.claude" ]]; then
        PROJECT_ROOT="$CHECK_DIR/MyProject-v3"
        break
    elif [[ -d "$CHECK_DIR/.claude/work" ]]; then
        PROJECT_ROOT="$CHECK_DIR"
        break
    fi
    CHECK_DIR=$(dirname "$CHECK_DIR")
done

if [[ -z "$PROJECT_ROOT" ]]; then
    exit 0
fi

ACTIVE_FILE="$PROJECT_ROOT/.claude/work/.active"
if [[ ! -f "$ACTIVE_FILE" ]]; then
    exit 0
fi

BRANCH=$(cat "$ACTIVE_FILE")
if [[ "$BRANCH" == "SKIP" ]]; then
    exit 0
fi

PLAN_FILE="$PROJECT_ROOT/.claude/work/$BRANCH/plan.md"
if [[ ! -f "$PLAN_FILE" ]]; then
    exit 0
fi

WORK_DIR="$PROJECT_ROOT/.claude/work/$BRANCH"

# Count phases
PHASE_COUNT=$(grep -cE '^#{2,3} *(Phase|phase) [0-9]+' "$PLAN_FILE" 2>/dev/null)
[[ -z "$PHASE_COUNT" ]] && PHASE_COUNT=0

# Count UAT test rows (lines in tables starting with | N.N | or | N |, excluding headers)
UAT_COUNT=$(grep -cE '^\| *[0-9]+\.?[0-9]* *\|' "$PLAN_FILE" 2>/dev/null)
[[ -z "$UAT_COUNT" ]] && UAT_COUNT=0

# Write manifest
cat > "$WORK_DIR/.phases-required" << EOF
phases=$PHASE_COUNT
uat_tests=$UAT_COUNT
created=$(date -u +%Y-%m-%dT%H:%M:%SZ)
plan=$PLAN_FILE
EOF

# Inform agent (non-blocking)
echo "" >&2
echo "  IMPLEMENTATION GATE: Plan has $PHASE_COUNT phases with $UAT_COUNT UAT tests." >&2
echo "  Create phase tasks (TaskCreate) before editing implementation files." >&2
echo "  Then write .phases-created to unlock code edits." >&2
echo "" >&2

exit 0
