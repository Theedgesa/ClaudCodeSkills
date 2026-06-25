#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Plan Save Guard — PreToolUse Hook for ExitPlanMode
# ═══════════════════════════════════════════════════════════════
# Blocks ExitPlanMode unless .active is set and plan.md exists.
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
if [[ "$TOOL_NAME" != "ExitPlanMode" ]]; then
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

# Find the project root
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

# Check .active exists
if [[ ! -f "$ACTIVE_FILE" ]]; then
    echo "BLOCKED: No active plan set. Plans MUST be saved before exiting plan mode." >&2
    echo "" >&2
    echo "  Write your plan to: .claude/work/PROJ-NNN-name/plan.md" >&2
    echo "  (The .active file is set automatically on plan write)" >&2
    exit 2
fi

BRANCH=$(cat "$ACTIVE_FILE")

# SKIP bypass — allow exit without plan file
if [[ "$BRANCH" == "SKIP" ]]; then
    echo ""
    echo "  Plan guard bypassed (SKIP mode)"
    echo ""
    exit 0
fi

# Check plan.md exists for the active branch
PLAN_FILE="$PROJECT_ROOT/.claude/work/$BRANCH/plan.md"
if [[ ! -f "$PLAN_FILE" ]]; then
    echo "BLOCKED: .active is set to '$BRANCH' but plan.md not found at:" >&2
    echo "  $PLAN_FILE" >&2
    echo "" >&2
    echo "  Write your plan to that file first, then exit plan mode." >&2
    exit 2
fi

# ─── Rendering-only test detection ───────────────────────────
# Scans Playwright/UAT test rows for tests that only check
# rendering (navigate → snapshot/console_messages) with no
# data-flow assertion. Violates: "Playwright must test data
# flow, never just rendering."
#
# Strategy: find lines with browser_snapshot or console_messages
# inside test tables (lines containing | ... |). For each match,
# check if the same row contains a data-flow keyword. If not,
# it's rendering-only.

# Data-flow indicators: tool calls, SQL, API calls, form interactions,
# user actions (type/fill/click/select/search/apply/save/confirm),
# and assertions on specific values
DATA_FLOW_PATTERN='execute_sql|browser_run_code|browser_fill_form|browser_click|browser_select_option|browser_drag|SELECT |INSERT |UPDATE |fetch\(|discount_amount|total_discount|current_uses|order_id|perItem|valid:|row |status.*(20[0-9]|429)|→ type |→ fill |→ click |→ search |→ Apply|→ Save|→ select |→ confirm|→ add item|Manual POS|Payment Received|Charge|place.order|complete.order'

BAD_TESTS=""
LINENUM=0
while IFS= read -r line; do
    LINENUM=$((LINENUM + 1))

    # Only check lines inside markdown tables (contain |)
    echo "$line" | grep -q '|' || continue

    # Only check lines mentioning snapshot or console_messages
    echo "$line" | grep -q -i -E 'browser_snapshot|browser_console_messages' || continue

    # Skip lines that are just table headers or separators
    echo "$line" | grep -q -E '^\|[-\s]+\|$' && continue

    # Check if this line also has data-flow indicators
    if echo "$line" | grep -q -i -E "$DATA_FLOW_PATTERN"; then
        continue  # Has data-flow — OK
    fi

    # Extract test description (3rd column typically)
    TEST_DESC=$(echo "$line" | awk -F'|' '{print $3}' | sed 's/^ *//;s/ *$//')
    [[ -z "$TEST_DESC" ]] && TEST_DESC=$(echo "$line" | sed 's/^ *//;s/ *$//')
    BAD_TESTS+="  Line $LINENUM: $TEST_DESC"$'\n'
done < "$PLAN_FILE"

if [[ -n "$BAD_TESTS" ]]; then
    echo "BLOCKED: Plan contains rendering-only Playwright tests (no data-flow assertions)." >&2
    echo "" >&2
    echo "Rule: 'Playwright must test data flow, never just rendering'" >&2
    echo "" >&2
    echo "Offending tests:" >&2
    echo "$BAD_TESTS" >&2
    echo "Fix: Remove these tests or add data-flow assertions" >&2
    echo "(DB queries, API calls, form interactions, response checks)." >&2
    exit 2
fi

# ─── UAT Design Validation Gate ───────────────────────────────
# Checks that /uat-design was run and passed for this plan.
UAT_VALIDATED="$PROJECT_ROOT/.claude/work/$BRANCH/.uat-validated"
if [[ ! -f "$UAT_VALIDATED" ]]; then
    echo "BLOCKED: UAT design validation has not been run for this plan." >&2
    echo "" >&2
    echo "Rule: '/uat-design must pass before exiting plan mode'" >&2
    echo "" >&2
    echo "Run /uat-design to validate test coverage, then the .uat-validated" >&2
    echo "marker will be written automatically when coverage passes." >&2
    echo "" >&2
    echo "Expected marker: $UAT_VALIDATED" >&2
    exit 2
fi

# ─── API Surface Verification Gate ────────────────────────────
# Checks that /verify-plan was run and all references confirmed.
# Prevents plans with wrong method names, missing columns, or
# non-existent SDK methods from being approved.
API_VERIFIED="$PROJECT_ROOT/.claude/work/$BRANCH/.api-verified"
# Also check variant naming (some plans use suffixed markers)
API_VERIFIED_ALT=$(ls "$PROJECT_ROOT/.claude/work/$BRANCH/"*.api-verified* 2>/dev/null | head -1)
if [[ ! -f "$API_VERIFIED" ]] && [[ -z "$API_VERIFIED_ALT" ]]; then
    echo "BLOCKED: API surface verification has not been run for this plan." >&2
    echo "" >&2
    echo "Rule: '/verify-plan must pass before exiting plan mode'" >&2
    echo "Prevents: wrong method names, missing DB columns, SDK signature mismatches." >&2
    echo "" >&2
    echo "Run /verify-plan to check all function/column/API references against source code." >&2
    echo "" >&2
    echo "Expected marker: $API_VERIFIED" >&2
    exit 2
fi

echo ""
echo "  Plan file verified: $BRANCH/plan.md"
echo "  No rendering-only tests detected"
echo "  UAT design validated"
echo "  API surface verified"
echo ""

exit 0
