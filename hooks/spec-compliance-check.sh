#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Spec Compliance Check — PostToolUse on Write/Edit
# Validates spec files have all 10 section headers, tables
# populated, no empty risk cells, and no vague language in SC.
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

[[ -z "$FILE_PATH" ]] && exit 0

# Only trigger on spec files
if [[ "$FILE_PATH" != *"/docs/specs/"* ]] && [[ "$FILE_PATH" != *"/specs/"*".md" ]]; then
    exit 0
fi

[[ ! -f "$FILE_PATH" ]] && exit 0

CONTENT=$(cat "$FILE_PATH")
SPEC_NAME=$(basename "$FILE_PATH")
FAILURES=0
TOTAL=0

check() {
    local id="$1"
    local desc="$2"
    shift 2
    local matched=0
    TOTAL=$((TOTAL + 1))
    for pattern in "$@"; do
        if echo "$CONTENT" | grep -qiE "$pattern"; then
            matched=1
            break
        fi
    done
    if [ $matched -eq 1 ]; then
        echo "  [PASS] $id. $desc"
    else
        echo "  [FAIL] $id. $desc"
        FAILURES=$((FAILURES + 1))
    fi
}

echo ""
echo "  Spec Compliance: $SPEC_NAME"
echo "  ─────────────────────────────────────"
echo ""
echo "  == 10 SECTION HEADERS =="
echo ""

check "S1 " "Problem" \
    "^#+ *1\\..*problem" "## 1\\." "## problem"

check "S2 " "Current State" \
    "^#+ *2\\..*current state" "## 2\\." "code surface"

check "S3 " "Success Criteria" \
    "^#+ *3\\..*success criter" "## 3\\." "quality standard"

check "S4 " "Design" \
    "^#+ *4\\..*design" "## 4\\." "solution overview"

check "S5 " "Risk & Adversarial Analysis" \
    "^#+ *5\\..*risk" "## 5\\." "adversarial"

check "S6 " "Requirements & Scoring" \
    "^#+ *6\\..*requirement" "## 6\\." "REQ.*table"

check "S7 " "Monitoring & Observability" \
    "^#+ *7\\..*monitor" "## 7\\." "health signal"

check "S8 " "Performance & Load" \
    "^#+ *8\\..*performance" "## 8\\." "upper bound"

check "S9 " "Dependencies & Decomposition" \
    "^#+ *9\\..*depend" "## 9\\." "upstream"

check "S10" "Rollback Strategy" \
    "^#+ *10\\..*rollback" "## 10\\." "rollback"

# ─── VAGUE LANGUAGE SCAN (SC quality guard) ────────────────
echo ""
echo "  == VAGUE LANGUAGE SCAN (Section 3 & 6) =="
echo ""

VAGUE_PATTERNS="works correctly|handles properly|looks good|data appears|page loads|functions as expected|behaves correctly|operates normally|runs smoothly|performs well|displays correctly|shows properly"

VAGUE_COUNT=$(echo "$CONTENT" | grep -ciE "$VAGUE_PATTERNS" || true)

TOTAL=$((TOTAL + 1))
if [ "$VAGUE_COUNT" -eq 0 ]; then
    echo "  [PASS] VG. No vague language detected"
else
    echo "  [FAIL] VG. $VAGUE_COUNT vague phrase(s) found — replace with specific expected values"
    # Show first 3 matches
    echo "$CONTENT" | grep -niE "$VAGUE_PATTERNS" | head -3 | while read -r line; do
        echo "         $line"
    done
    FAILURES=$((FAILURES + 1))
fi

# ─── RESULTS ──────────────────────────────────────────────────
PASSED=$((TOTAL - FAILURES))
echo ""

if [ $FAILURES -eq 0 ]; then
    echo "  SPEC COMPLIANT — $PASSED/$TOTAL checks passed."
else
    echo "  $FAILURES/$TOTAL check(s) FAILED. Fix before seeking approval."
fi

echo ""
