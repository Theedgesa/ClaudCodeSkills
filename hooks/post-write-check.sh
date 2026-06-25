#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Post-Write Check — Consolidated PostToolUse Hook
# ═══════════════════════════════════════════════════════════════
# Routes by file path:
#   .claude/work/*/report.md   → Report compliance (10 checks)
#   .claude/work/*/plan.md     → Plan compliance (reads count from template) + set .active
#   server/(controllers|services|routes|middleware|jobs)/*.js → Server restart reminder
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# ═══════════════════════════════════════════════════════════════
# ROUTE: SKIP auto-clear after git commit (past-errors #40)
# ═══════════════════════════════════════════════════════════════
if [[ "$TOOL_NAME" == "Bash" ]]; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
    if echo "$COMMAND" | grep -qE 'git\s+commit'; then
        PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PROJECT_ROOT")
        PENDING="$PROJECT_ROOT/.claude/work/.skip-pending-clear"
        ACTIVE="$PROJECT_ROOT/.claude/work/.active"
        if [[ -f "$PENDING" ]]; then
            rm -f "$PENDING"
            rm -f "$ACTIVE"
            echo ""
            echo "  SKIP auto-cleared. Next edit requires an approved plan."
            echo ""
        fi
    fi
    exit 0
fi

if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# ROUTE: IMPLEMENTATION REPORT COMPLIANCE
# Match: .claude/work/*/report.md
# ═══════════════════════════════════════════════════════════════
if [[ "$FILE_PATH" == *"/.claude/work/"*"/report.md" ]]; then
    if [[ ! -f "$FILE_PATH" ]]; then
        exit 0
    fi

    CONTENT=$(cat "$FILE_PATH")
    REPORT_NAME=$(echo "$FILE_PATH" | sed 's|.*\.claude/work/||' | sed 's|/.*||')
    FAILURES=0
    TOTAL=0

    rcheck() {
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
            echo "  ✅ $id. $desc"
        else
            echo "  ❌ $id. $desc"
            FAILURES=$((FAILURES + 1))
        fi
    }

    echo ""
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│  Implementation Report Check: $REPORT_NAME"
    echo "└──────────────────────────────────────────────────────────────┘"

    echo ""
    echo "== REQUIRED SECTIONS (10) =="
    echo ""

    rcheck "R1 " "Executive Summary" \
        "executive summary" "^#+ *1\\..*summary"

    rcheck "R2 " "Deliverables (files, DB, API)" \
        "deliverables" "modified files" "new files" "database changes"

    rcheck "R3 " "Phase-by-Phase Results with Self-UAT" \
        "phase.*(result|by|complete)" "phase [0-9].*complete" \
        "phase [0-9].*—" "self-uat"

    rcheck "R4 " "Verification Matrix" \
        "verification matrix" "verification.*table" \
        "command.*expected.*actual"

    rcheck "R5 " "E2E Verification Results" \
        "e2e.*verif" "end.to.end.*verif" \
        "workflow.*verif" "all.*steps.*verif"

    rcheck "R6 " "Cloud & External Dependencies" \
        "cloud.*depend" "external depend" \
        "supabase\|ec2\|shopify\|zoho" "deploy"

    rcheck "R7 " "Remaining Actions" \
        "remaining action" "remaining.*step" \
        "action.*blocker" "post.deploy"

    rcheck "R8 " "Risk Assessment" \
        "risk assess" "risk.*likelihood.*impact" \
        "risk.*mitigation"

    rcheck "R9 " "Rollback Plan" \
        "rollback plan" "rollback.*command" \
        "rollback.*action" "rollback.*step"

    rcheck "R10" "Self-UAT Results (actual output, not just PASS)" \
        "self-uat.*result" "actual.*output" \
        "PASS|FAIL" "status.*cloud"

    PASSED=$((TOTAL - FAILURES))
    echo ""
    echo "================================================================"
    echo ""

    if [ $FAILURES -eq 0 ]; then
        echo "  ✅ REPORT COMPLIANT — $PASSED/$TOTAL sections present."
        echo "     Ready for /ship."
    else
        echo "  ⚠️  $FAILURES/$TOTAL section(s) MISSING from implementation report."
        echo ""
        echo "  ACTION: Add the missing sections before declaring done."
    fi

    echo ""
    echo "================================================================"
    echo ""
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# ROUTE: SERVER/FINANCE-SVC IMPLEMENTATION FILE
# Match: server/ or finance-service/ implementation JS files
# ═══════════════════════════════════════════════════════════════
if echo "$FILE_PATH" | grep -qE '(server|finance-service)/(controllers|services|routes|middleware|jobs|modules)/.*\.(js|mjs)$'; then
    echo ""
    echo "  REMINDER: Implementation file modified. Restart dev server before testing."

    # Quick method-existence spot-check on the edited file
    PROJECT_ROOT=$(echo "$FILE_PATH" | sed 's|/\(server\|finance-service\)/.*||')
    if [[ -f "$PROJECT_ROOT/scripts/require-check.mjs" ]]; then
        RESULT=$(cd "$PROJECT_ROOT" && node scripts/require-check.mjs --files "$FILE_PATH" 2>&1)
        if [[ $? -ne 0 ]]; then
            echo ""
            echo "  ⚠️  METHOD CHECK: Dead call detected in this file:"
            echo "$RESULT" | grep -E "^\s" | head -5
            echo ""
            echo "  A method you're calling doesn't exist on the required module."
            echo "  Verify method names against the actual service source file."
        fi
    fi

    echo ""
    exit 0
fi

# ═══════════════════════════════════════════════════════════════
# ROUTE: WORKSPACE CONFIG CHANGE
# Match: package.json (root only, not subdirectories)
# Triggers: version audit reminder, CI check, PM2 check
# Incident: PROJ-155 — workspace hoisting bumped Next.js 16.1→16.2,
#   broke staging dev mode. CI had stale install steps. PM2 binary gone.
# ═══════════════════════════════════════════════════════════════
if [[ "$FILE_PATH" == *"/package.json" ]] && [[ "$FILE_PATH" != *"node_modules"* ]]; then
    # Only trigger on root package.json (contains workspaces)
    DIR=$(dirname "$FILE_PATH")
    if [[ -f "$DIR/.github/workflows/quality.yml" ]] || [[ -f "$DIR/package-lock.json" ]]; then
        if [[ -f "$FILE_PATH" ]] && grep -q '"workspaces"' "$FILE_PATH" 2>/dev/null; then
            echo ""
            echo "  ⚠️  WORKSPACE CONFIG CHANGED — Blast radius checklist:"
            echo "  1. Run: npm run quality:ci-drift (CI workflow alignment)"
            echo "  2. Check node_modules/<pkg>/package.json versions for critical deps (next, react)"
            echo "  3. Verify PM2 script paths still resolve (workspace hoisting moves binaries)"
            echo "  4. Test npm run build in ALL workspace members"
            echo "  5. After deploy: verify staging PM2 processes start without error"
            echo "  6. Index codebase-memory: npm run index (if available)"
            echo ""
        fi
    fi
fi

# ═══════════════════════════════════════════════════════════════
# ROUTE: PLAN FILES
# Match: .claude/work/*/plan.md (exact filename only)
# ═══════════════════════════════════════════════════════════════
if [[ "$FILE_PATH" != *"/.claude/work/"*"/plan.md" ]]; then
    exit 0
fi

if [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi

# ─── Auto-set .active on plan write ──────────────────────────
PROJECT_ROOT=$(echo "$FILE_PATH" | sed 's|/\.claude/work/.*||')
BRANCH_NAME=$(echo "$FILE_PATH" | sed 's|.*\.claude/work/||' | sed 's|/.*||')
ACTIVE_FILE="$PROJECT_ROOT/.claude/work/.active"

if echo "$BRANCH_NAME" > "$ACTIVE_FILE" 2>/dev/null; then
    echo ""
    echo "  Active plan set: $BRANCH_NAME"
    echo ""
else
    echo "  Warning: Could not set .active file (non-blocking)" >&2
fi

CONTENT=$(cat "$FILE_PATH")
PLAN_NAME="$BRANCH_NAME/plan.md"
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
        echo "  ✅ $id. $desc"
    else
        echo "  ❌ $id. $desc"
        FAILURES=$((FAILURES + 1))
    fi
}

# ─── Detect execution markers ────────────────────────────────
HAS_EXEC_MARKERS=$(echo "$CONTENT" | grep -ciE "(status:.*complete|\[x\].*phase [0-9]|all phases (complete|done))" || true)

# ═══════════════════════════════════════════════════════════════
# BRANCH A: EXECUTION VERIFICATION (has exec markers)
# ═══════════════════════════════════════════════════════════════
if [ "$HAS_EXEC_MARKERS" -gt 0 ]; then

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│  Post-Execution Verification: $PLAN_NAME"
echo "└──────────────────────────────────────────────────────────────┘"

echo ""
echo "== PHASE COMPLETION =="
echo ""

PHASE_HEADERS=$(echo "$CONTENT" | grep -ciE "^#+ *(phase|step) [0-9]" || true)
COMPLETED_PHASES=$(echo "$CONTENT" | grep -ciE "(\[x\].*phase|\[x\].*step|phase.*✅|phase.*(complete|done)|completed.*phase)" || true)

TOTAL=$((TOTAL + 1))
if [ "$PHASE_HEADERS" -gt 0 ]; then
    if [ "$COMPLETED_PHASES" -ge "$PHASE_HEADERS" ]; then
        echo "  ✅ P1. All $PHASE_HEADERS phase(s) marked complete"
    else
        echo "  ❌ P1. $PHASE_HEADERS phase(s) defined but only $COMPLETED_PHASES marked complete"
        FAILURES=$((FAILURES + 1))
    fi
else
    echo "  ⚠️  P1. No numbered phases found"
fi

echo ""
echo "== DELIVERABLES =="
echo ""

check "D1" "Backend changes implemented" \
    "server/.*✅" "server/.*(done|complete|implemented|created|updated)" \
    "\[x\].*server/" "no (backend|server) change"

check "D2" "Frontend changes implemented" \
    "reception-website/.*✅" "reception-website/.*(done|complete|implemented)" \
    "\[x\].*reception-website/" "no (frontend|reception) change"

check "D3" "Database changes applied" \
    "migration.*(applied|run|executed|complete)" \
    "no (db|database|migration|schema) change" \
    "\[x\].*migrat"

check "D4" "Self-UAT tests executed with results" \
    "self-uat" "PASS" "FAIL" \
    "actual.*output" "actual.*result"

echo ""
echo "== QUALITY GATES =="
echo ""

check "Q1" "Syntax/compilation checks passed" \
    "node --check" "tsc.*(pass|✅|clean)" \
    "\[x\].*syntax" "\[x\].*tsc"

check "Q2" "Frontend build succeeded" \
    "build.*(pass|success|✅|succeed)" \
    "\[x\].*build" "build.*complete"

check "Q3" "Server restart + E2E verification" \
    "server.*(restart|started)" "e2e.*(pass|complete|verified)" \
    "\[x\].*restart" "\[x\].*e2e"

check "Q4" "Rollback plan present" \
    "rollback.*(valid|ready|confirmed|✅)" \
    "\[x\].*rollback" "rollback.*(plan|strateg)"

echo ""
echo "== IMPLEMENTATION REPORT =="
echo ""

REPORT_PATH="$PROJECT_ROOT/.claude/work/$BRANCH_NAME/report.md"
TOTAL=$((TOTAL + 1))

if [[ -f "$REPORT_PATH" ]]; then
    REPORT_CONTENT=$(cat "$REPORT_PATH")
    REPORT_SECTIONS=0
    for SECTION in "executive summary" "deliverables" "phase.*results" "verification" "rollback"; do
        if echo "$REPORT_CONTENT" | grep -qiE "$SECTION"; then
            REPORT_SECTIONS=$((REPORT_SECTIONS + 1))
        fi
    done

    if [[ "$REPORT_SECTIONS" -ge 3 ]]; then
        echo "  ✅ R1. Implementation report exists with $REPORT_SECTIONS/5 key sections"
    else
        echo "  ⚠️  R1. Implementation report exists but only $REPORT_SECTIONS/5 key sections found"
        FAILURES=$((FAILURES + 1))
    fi
else
    echo "  ❌ R1. Implementation report NOT FOUND at $REPORT_PATH"
    echo "         Write the implementation report before declaring done."
    echo "         Reference: .claude/rules/process/implementation-reports.md"
    FAILURES=$((FAILURES + 1))
fi

# ═══════════════════════════════════════════════════════════════
# BRANCH B: PLAN COMPLIANCE CHECK (reads count from template header)
# ═══════════════════════════════════════════════════════════════
else

# Read expected section count from template header
TEMPLATE_PATH="$PROJECT_ROOT/.claude/templates/plan-template.md"
EXPECTED_SECTIONS=7
if [[ -f "$TEMPLATE_PATH" ]]; then
    TMPL_COUNT=$(grep -oE 'Template sections: [0-9]+' "$TEMPLATE_PATH" | grep -oE '[0-9]+' || true)
    if [[ -n "$TMPL_COUNT" ]]; then
        EXPECTED_SECTIONS="$TMPL_COUNT"
    fi
fi

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│  Plan Compliance Check: $PLAN_NAME"
echo "│  Template: $EXPECTED_SECTIONS mandatory sections"
echo "└──────────────────────────────────────────────────────────────┘"

echo ""
echo "== CORE SECTIONS ($EXPECTED_SECTIONS) =="
echo ""

check "S1 " "Implementation Overview" \
    "^#+ *1\\..*implementation overview" "## 1\\." \
    "phase summary" "expected req progression"

check "S1a" "  -> Phase summary table" \
    "phase.*name.*what it achieves" "phase summary"

check "S1b" "  -> Expected REQ Progression" \
    "expected req progression" "green.*orange.*red"

check "S2 " "Code Surface & Blast Radius" \
    "^#+ *2\\..*code surface" "## 2\\." \
    "change manifest" "blast radius"

check "S2a" "  -> Change Manifest with verification results" \
    "change manifest" "action.*layer.*environment" \
    "what.*type.*action"

check "S2b" "  -> Blast radius (callers documented)" \
    "blast radius" "modified function" "caller"

check "S2c" "  -> Mutation constraints & environment" \
    "mutation constraint" "not null.*without default" \
    "env var.*staging.*production"

check "S3 " "Database Schema & Migration" \
    "^#+ *3\\..*database" "^#+ *3\\..*migration" \
    "no database change" "migration sql"

check "S4 " "Cross-Service Data Flow" \
    "^#+ *4\\..*cross.service" "^#+ *4\\..*data flow" \
    "flow trace" "→.*→.*→" "->.*->.*->"

check "S5 " "Implementation Phases" \
    "^#+ *5\\..*implementation phase" "^#+ *(phase|step) [0-9]" \
    "### phase [0-9]"

check "S5a" "  -> Phase objectives defined" \
    "objective.*what this phase" "\*\*objective\*\*"

check "S5b" "  -> REQ gate tables (Green/Orange/Red)" \
    "req.*gate\|phase gate" "green\|orange\|red" \
    "REQ-[0-9]"

check "S5c" "  -> Weakest element per phase" \
    "weakest element"

check "S5d" "  -> CR checkpoint per phase" \
    "change record check\|cr checkpoint\|cr.*check"

check "S6 " "E2E Verification" \
    "^#+ *6\\..*e2e" "^#+ *6\\..*verif" \
    "connected workflow" "browser.*protocol"

check "S7 " "Ship & Deploy" \
    "^#+ *7\\..*ship" "^#+ *7\\..*deploy" \
    "pr flow" "staging uat" "production deploy"

check "S7a" "  -> Architecture doc gate" \
    "architecture doc" "docs updated"

check "S7b" "  -> PM2 freshness verification" \
    "pm2.*fresh\|pm2.*created\|pm2.*restart\|freshness"

check "S7c" "  -> Production verification queries" \
    "production verif\|post-deploy\|review window\|no production verification"

# ─── SPEC REFERENCE CHECK ────────────────────────────────────
echo ""
echo "  == SPEC REFERENCE =="
echo ""

TOTAL=$((TOTAL + 1))
SPEC_REF=$(echo "$CONTENT" | grep -oE 'Spec:.*`[^`]+`' | head -1 || true)
if [[ -n "$SPEC_REF" ]]; then
    SPEC_PATH=$(echo "$SPEC_REF" | grep -oE '`[^`]+`' | tr -d '`')
    if [[ -f "$PROJECT_ROOT/$SPEC_PATH" ]]; then
        SPEC_STATUS=$(grep -oE 'Status:.*approved' "$PROJECT_ROOT/$SPEC_PATH" || true)
        if [[ -n "$SPEC_STATUS" ]]; then
            echo "  [PASS] SP. Spec reference points to approved spec"
        else
            echo "  [FAIL] SP. Spec exists but status is not 'approved'"
            FAILURES=$((FAILURES + 1))
        fi
    else
        echo "  [FAIL] SP. Spec file not found: $SPEC_PATH"
        FAILURES=$((FAILURES + 1))
    fi
else
    echo "  [FAIL] SP. No spec reference found in plan header"
    FAILURES=$((FAILURES + 1))
fi

# ─── EVIDENCE PROSE SCAN ─────────────────────────────────────
echo ""
echo "  == EVIDENCE QUALITY =="
echo ""

PROSE_PATTERNS="verified by inspection|I read the code|confirmed by reading|looks correct|handles this|by inspection|as expected"
PROSE_COUNT=$(echo "$CONTENT" | grep -ciE "$PROSE_PATTERNS" || true)

TOTAL=$((TOTAL + 1))
if [ "$PROSE_COUNT" -eq 0 ]; then
    echo "  [PASS] EV. No prose evidence detected in phase gates"
else
    echo "  [FAIL] EV. $PROSE_COUNT prose evidence phrase(s) found — replace with execution output"
    echo "$CONTENT" | grep -niE "$PROSE_PATTERNS" | head -3 | while read -r line; do
        echo "         $line"
    done
    FAILURES=$((FAILURES + 1))
fi

fi  # End of plan compliance vs execution branch

# ─── RESULTS ──────────────────────────────────────────────────
PASSED=$((TOTAL - FAILURES))
echo ""
echo "================================================================"
echo ""

if [ $FAILURES -eq 0 ]; then
    if [ "$HAS_EXEC_MARKERS" -gt 0 ]; then
        echo "  ✅ EXECUTION VERIFIED — $PASSED/$TOTAL checks passed."
        echo "     Ready for /ship."
    else
        echo "  ✅ PLAN COMPLIANT — $PASSED/$TOTAL checks passed."
        echo "     Get approval (set Status: approved) then /implement."
    fi
else
    echo "  ⚠️  $FAILURES/$TOTAL check(s) FAILED."
    echo ""
    if [ "$HAS_EXEC_MARKERS" -gt 0 ]; then
        echo "  ACTION: Complete missing deliverables before declaring done."
    else
        echo "  ACTION: Add the missing sections before seeking approval."
        echo ""
        echo "  Reference: .claude/templates/plan-template.md"
    fi
fi

echo ""
echo "================================================================"
echo ""
