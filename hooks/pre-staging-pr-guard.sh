#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Pre-Staging PR Guard — PreToolUse Hook
# ═══════════════════════════════════════════════════════════════
# Blocks `gh pr create --base staging` unless a report.md exists
# in the active .claude/work/PROJ-* directory with UAT evidence.
#
# Flow: implement → UAT → report → PR. Never skip UAT.
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only check gh pr create targeting staging
if ! echo "$COMMAND" | grep -qE 'gh\s+pr\s+create'; then
    exit 0
fi

if ! echo "$COMMAND" | grep -qE '(--base\s+staging|staging)'; then
    exit 0
fi

# Find the project root
PROJECT_ROOT=""
for candidate in "$PROJECT_ROOT" "$(pwd)"; do
    if [[ -d "$candidate/.claude/work" ]]; then
        PROJECT_ROOT="$candidate"
        break
    fi
done

if [[ -z "$PROJECT_ROOT" ]]; then
    exit 0
fi

# Get branch from --head flag in command, fall back to current branch
BRANCH=$(echo "$COMMAND" | grep -oE '\-\-head\s+[^ ]+' | sed 's/--head\s*//')
if [[ -z "$BRANCH" ]]; then
    BRANCH=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null)
fi
if [[ -z "$BRANCH" ]]; then
    exit 0
fi

# Extract PROJ-NNN or PROJ2-NNN from branch name
TICKET=$(echo "$BRANCH" | grep -oE 'PPV[23]-[0-9]+' | head -1)
if [[ -z "$TICKET" ]]; then
    # Not a tracked feature branch — allow
    exit 0
fi

# Find matching work directory
WORK_DIR=$(find "$PROJECT_ROOT/.claude/work" -maxdepth 1 -type d -name "${TICKET}-*" 2>/dev/null | head -1)
if [[ -z "$WORK_DIR" ]]; then
    # No work directory — allow (might be a simple fix without a plan)
    exit 0
fi

# Check plan exists
PLAN_FILE="$WORK_DIR/plan.md"
if [[ ! -f "$PLAN_FILE" ]]; then
    exit 0
fi

# Check report exists
REPORT_FILE="$WORK_DIR/report.md"
if [[ ! -f "$REPORT_FILE" ]]; then
    DIRNAME=$(basename "$WORK_DIR")
    echo '{"decision":"block","reason":"BLOCKED: No implementation report found.\n\nBefore creating a PR to staging, you must:\n1. Complete ALL Self-UAT tests locally\n2. Write the implementation report to .claude/work/'"$DIRNAME"'/report.md\n3. Report must include per-test evidence (Action/Expected/Actual/Grade)\n\nNever PR to staging without local UAT evidence."}'
    exit 0
fi

# Check report has UAT content (look for PASS or CONFIRMED markers)
if ! grep -qiE '(PASS|CONFIRMED|COMPLETE)' "$REPORT_FILE" 2>/dev/null; then
    DIRNAME=$(basename "$WORK_DIR")
    echo '{"decision":"block","reason":"BLOCKED: Implementation report exists but has no UAT results.\n\nReport at .claude/work/'"$DIRNAME"'/report.md must contain UAT test results with PASS/CONFIRMED grades before creating a PR to staging."}'
    exit 0
fi

# All checks passed
exit 0
