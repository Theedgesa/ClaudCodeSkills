#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Pre-Tool Guard — Consolidated PreToolUse Hook
# ═══════════════════════════════════════════════════════════════
# Routes by tool_name:
#   Bash        → Destructive command guard
#   Write|Edit  → Plan versioning (if .claude/work/*/plan.md)
#   Write|Edit  → Approved-plan-before-implementation guard
#   Write       → SQL migration validation (if *.sql in migration dirs)
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# ─── ROUTE 1: DESTRUCTIVE COMMAND GUARD (Bash) ────────────────
if [[ "$TOOL_NAME" == "Bash" ]]; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

    if [[ -z "$COMMAND" ]]; then
        exit 0
    fi

    CMD_LOWER=$(echo "$COMMAND" | tr '[:upper:]' '[:lower:]' | tr -s ' ')

    # ── BLOCK: rm -rf on dangerous paths ──
    if echo "$CMD_LOWER" | grep -qE 'rm\s+(-[a-z]*r[a-z]*f|--recursive)\s'; then
        if echo "$CMD_LOWER" | grep -qE 'rm\s+(-[a-z]*r[a-z]*f|--recursive)\s+(node_modules|\.next|dist|build|out|\.cache|tmp|\.turbo|coverage)'; then
            exit 0
        fi
        if echo "$CMD_LOWER" | grep -qE 'rm\s+(-[a-z]*r[a-z]*f|--recursive)\s+(/|/\*|\.\s|\./)'; then
            echo "BLOCKED: Destructive rm -rf on root/current directory. Specify a safe target." >&2
            exit 2
        fi
    fi

    # ── BLOCK: git push --force to main/master ──
    if echo "$CMD_LOWER" | grep -qE 'git\s+push\s+.*--force\s' && echo "$CMD_LOWER" | grep -qE '\s(main|master)(\s|$)'; then
        if echo "$CMD_LOWER" | grep -qE '--force-with-lease'; then
            exit 0
        fi
        echo "BLOCKED: Force push to main/master is prohibited. Use --force-with-lease or push to a feature branch." >&2
        exit 2
    fi

    # ── BLOCK: git push directly to main/staging/master (must use PRs) ──
    if echo "$CMD_LOWER" | grep -qE 'git\s+push\s'; then
        # Check for push targeting protected branches: "git push origin branch:main", "git push origin branch:staging"
        if echo "$CMD_LOWER" | grep -qE ':(main|staging|master)(\s|$)'; then
            echo "BLOCKED: Direct push to protected branch (main/staging/master) is prohibited." >&2
            echo "  Create a PR instead. Never merge PRs yourself — send the link to the user." >&2
            exit 2
        fi
        # Also block "git push origin main" or "git push origin staging" (pushing current branch named main/staging)
        if echo "$CMD_LOWER" | grep -qE 'git\s+push\s+\S+\s+(main|staging|master)(\s|$)'; then
            echo "BLOCKED: Direct push to protected branch (main/staging/master) is prohibited." >&2
            echo "  Create a PR instead. Never merge PRs yourself — send the link to the user." >&2
            exit 2
        fi
    fi

    # ── BLOCK: git reset --hard ──
    if echo "$CMD_LOWER" | grep -qE 'git\s+reset\s+--hard'; then
        echo "BLOCKED: git reset --hard discards all uncommitted changes. Use git stash or commit first." >&2
        exit 2
    fi

    # ── BLOCK: DROP TABLE / TRUNCATE ──
    if echo "$CMD_LOWER" | grep -qE '(drop\s+table|truncate\s+table)'; then
        echo "BLOCKED: DROP/TRUNCATE TABLE detected. This is irreversible. Use a migration with safeguards." >&2
        exit 2
    fi

    # ── BLOCK: git checkout . / git restore . ──
    if echo "$CMD_LOWER" | grep -qE 'git\s+(checkout|restore)\s+\.(\s|$)'; then
        echo "BLOCKED: git checkout/restore . discards all unstaged changes. Use git stash or be more specific." >&2
        exit 2
    fi

    # ── Auto-clear SKIP after git commit (past-errors #40) ──
    if echo "$CMD_LOWER" | grep -qE 'git\s+commit'; then
        DYNAMIC_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PROJECT_ROOT")
        ACTIVE_FILE="$DYNAMIC_ROOT/.claude/work/.active"
        if [[ -f "$ACTIVE_FILE" ]]; then
            SKIP_CHECK=$(cat "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')
            if [[ "$SKIP_CHECK" == "SKIP" ]]; then
                echo ""
                echo "  SKIP will auto-clear after this commit (past-errors #40)."
                echo "  Next edit will require an approved plan."
                echo ""
                # Write a post-commit marker — cleared in PostToolUse
                echo "CLEAR_SKIP" > "$DYNAMIC_ROOT/.claude/work/.skip-pending-clear"
            fi
        fi
    fi

    # ── REQUIRE: Implementation report before git commit on feature branches ──
    if echo "$CMD_LOWER" | grep -qE 'git\s+commit'; then
        # Find project root by looking for .claude/work directory
        DYNAMIC_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PROJECT_ROOT")
        for PROJECT_DIR in "$DYNAMIC_ROOT"; do
            ACTIVE_FILE="$PROJECT_DIR/.claude/work/.active"
            if [[ -f "$ACTIVE_FILE" ]]; then
                BRANCH=$(cat "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')
                if [[ -n "$BRANCH" && "$BRANCH" != "SKIP" ]]; then
                    PLAN_FILE="$PROJECT_DIR/.claude/work/$BRANCH/plan.md"
                    REPORT_FILE="$PROJECT_DIR/.claude/work/$BRANCH/report.md"
                    # Only enforce if plan exists and is complete/approved
                    if [[ -f "$PLAN_FILE" ]]; then
                        PLAN_STATUS=$(grep -oiE '\*\*Status:\*\*\s*\S+' "$PLAN_FILE" 2>/dev/null | head -1 | sed 's/.*\*\* *//' | tr '[:upper:]' '[:lower:]')
                        if [[ "$PLAN_STATUS" == "complete" && ! -f "$REPORT_FILE" ]]; then
                            echo "BLOCKED: Plan is marked complete but implementation report is missing." >&2
                            echo "" >&2
                            echo "  Plan: .claude/work/$BRANCH/plan.md (Status: complete)" >&2
                            echo "  Expected report: .claude/work/$BRANCH/report.md" >&2
                            echo "" >&2
                            echo "  Write the implementation report before committing." >&2
                            echo "  Reference: .claude/rules/process/implementation-reports.md" >&2
                            exit 2
                        fi
                    fi
                fi
            fi
        done
    fi

    exit 0
fi

# ─── ROUTE 1b: UAT GATE GUARD (TaskUpdate) ────────────────────
# Blocks marking a phase/UAT task as "completed" if its description
# contains PENDING, deferred, or skipped tests. Enforces the rule:
# "ALL Self-UAT must pass before proceeding — PENDING is not PASS."
# Added after PROJ-082 incident where 7 deferred tests hid 2 bugs.
if [[ "$TOOL_NAME" == "TaskUpdate" ]]; then
    NEW_STATUS=$(echo "$INPUT" | jq -r '.tool_input.status // empty' 2>/dev/null)
    DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // empty' 2>/dev/null)
    SUBJECT=$(echo "$INPUT" | jq -r '.tool_input.subject // empty' 2>/dev/null)

    if [[ "$NEW_STATUS" == "completed" ]]; then
        DESC_LOWER=$(echo "$DESCRIPTION" | tr '[:upper:]' '[:lower:]')
        SUBJ_LOWER=$(echo "$SUBJECT" | tr '[:upper:]' '[:lower:]')

        # Check for weasel words that indicate incomplete testing
        if echo "$DESC_LOWER" | grep -qE 'pending|deferred|skipped|not.?tested|manual.?later|todo'; then
            echo "BLOCKED: Cannot mark task as completed with PENDING/deferred/skipped tests." >&2
            echo "" >&2
            echo "  The description contains words indicating incomplete testing." >&2
            echo "  ALL REQ tests must have Green/Orange/Red status before completion." >&2
            echo "  PENDING is not scored. Run the remaining tests first." >&2
            echo "" >&2
            echo "  Rule: past-errors.md #26 — Never defer tests" >&2
            exit 2
        fi

        # ── REPORT GATE: Phase task completion requires report.md update ──
        # Extract phase number from task subject (e.g., "Phase 2: Backend service")
        PHASE_NUM=$(echo "$SUBJ_LOWER" | grep -oE 'phase [0-9]+' | grep -oE '[0-9]+' || true)
        if [[ -n "$PHASE_NUM" ]]; then
            DYNAMIC_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
            if [[ -n "$DYNAMIC_ROOT" ]]; then
                ACTIVE_FILE="$DYNAMIC_ROOT/.claude/work/.active"
                if [[ -f "$ACTIVE_FILE" ]]; then
                    BRANCH=$(cat "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')
                    if [[ -n "$BRANCH" && "$BRANCH" != "SKIP" ]]; then
                        REPORT_FILE="$DYNAMIC_ROOT/.claude/work/$BRANCH/report.md"
                        if [[ -f "$REPORT_FILE" ]]; then
                            if ! grep -qiE "phase $PHASE_NUM gate:.*pass" "$REPORT_FILE" 2>/dev/null; then
                                echo "" >&2
                                echo "  REPORT GATE: Phase $PHASE_NUM task marked completed but report.md" >&2
                                echo "  does not contain 'Phase $PHASE_NUM Gate: ... PASS'." >&2
                                echo "  Update report.md with phase gate verdict before completing the task." >&2
                                echo "" >&2
                            fi
                        else
                            echo "" >&2
                            echo "  REPORT GATE: Phase $PHASE_NUM task marked completed but report.md" >&2
                            echo "  does not exist at .claude/work/$BRANCH/report.md" >&2
                            echo "  Create the report before completing phase tasks." >&2
                            echo "" >&2
                        fi
                    fi
                fi
            fi
        fi

        # ── CR ACKNOWLEDGMENT: Phase completion should acknowledge CR status ──
        if echo "$SUBJ_LOWER" | grep -qE 'phase [0-9]+'; then
            if ! echo "$DESC_LOWER" | grep -qE 'cr-|zero bugs|0 crs|no crs|no bugs|no design change|no cr'; then
                echo "" >&2
                echo "  CR REMINDER: Phase task completed without CR acknowledgment." >&2
                echo "  Task description should state either:" >&2
                echo "    - CRs created (e.g., 'CR-001: ...' — run /cr to create)" >&2
                echo "    - Or why zero: 'zero bugs found — [justification]'" >&2
                echo "" >&2
            fi
        fi
    fi

    exit 0
fi

# ─── ROUTE 2: WRITE|EDIT ON FILES ─────────────────────────────
if [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]]; then
    if [[ -z "$FILE_PATH" ]]; then
        exit 0
    fi

    # ─── ROUTE 2a: PLAN VERSIONING ────────────────────────────
    if [[ "$FILE_PATH" == *"/.claude/work/"*"/plan.md" ]]; then
        if [[ -f "$FILE_PATH" ]]; then
            PROJECT_ROOT=$(echo "$FILE_PATH" | sed 's|/\.claude/work/.*|/|')
            BRANCH_NAME=$(echo "$FILE_PATH" | sed 's|.*\.claude/work/||' | sed 's|/.*||')
            VERSIONS_DIR="${PROJECT_ROOT}.claude/versions"

            mkdir -p "$VERSIONS_DIR"

            VERSION=1
            while [[ -f "$VERSIONS_DIR/${BRANCH_NAME}-plan.v${VERSION}.md" ]]; do
                VERSION=$((VERSION + 1))
            done

            if cp "$FILE_PATH" "$VERSIONS_DIR/${BRANCH_NAME}-plan.v${VERSION}.md" 2>/dev/null; then
                echo ""
                echo "  Plan versioned: ${BRANCH_NAME}-plan.v${VERSION}.md"
                echo ""
            else
                echo "  Warning: Could not create version backup (non-blocking)" >&2
            fi
        fi
        exit 0
    fi

    # ─── ROUTE 2b: APPROVED-PLAN-BEFORE-IMPLEMENTATION GUARD ──
    # Block edits to implementation files unless an APPROVED plan exists
    if echo "$FILE_PATH" | grep -qE '(server/(controllers|services|routes|middleware|jobs)/|reception-website/src/|store-website/src/)'; then
        PROJECT_ROOT=""
        if echo "$FILE_PATH" | grep -qE 'MyProject-v3/'; then
            PROJECT_ROOT=$(echo "$FILE_PATH" | sed 's|/MyProject-v3/.*|/MyProject-v3|')
        fi

        if [[ -n "$PROJECT_ROOT" ]] && [[ -d "$PROJECT_ROOT/.claude" ]]; then
            ACTIVE_FILE="$PROJECT_ROOT/.claude/work/.active"

            # Check 1: .active file exists
            if [[ ! -f "$ACTIVE_FILE" ]]; then
                echo "BLOCKED: No active plan. Implementation requires an APPROVED plan." >&2
                echo "" >&2
                echo "  To start a planned change:" >&2
                echo "    1. Write plan to .claude/work/PROJ-NNN-name/plan.md" >&2
                echo "    2. Get approval (Status: approved)" >&2
                echo "    3. Then implement" >&2
                echo "" >&2
                echo "  For a small fix without a plan:" >&2
                echo "    echo SKIP > $PROJECT_ROOT/.claude/work/.active" >&2
                exit 2
            fi

            BRANCH=$(cat "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')

            # ── BRANCH PROTECTION: Block implementation edits on main/staging ──
            CURRENT_BRANCH=$(cd "$PROJECT_ROOT" && git branch --show-current 2>/dev/null || true)
            if [[ -n "$CURRENT_BRANCH" ]]; then
                if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" || "$CURRENT_BRANCH" == "staging" ]]; then
                    if [[ "$BRANCH" != "SKIP" ]]; then
                        echo "BLOCKED: Cannot edit implementation files on '$CURRENT_BRANCH' branch." >&2
                        echo "" >&2
                        echo "  Implementation must happen on a feature branch or worktree." >&2
                        echo "  Create a worktree: git worktree add .worktrees/PROJ-NNN -b feature/PROJ-NNN origin/main" >&2
                        echo "  Or switch branch: git checkout -b feature/PROJ-NNN" >&2
                        exit 2
                    fi
                fi
            fi

            # SKIP bypass — limited scope
            if [[ "$BRANCH" == "SKIP" ]]; then
                # Audit: log SKIP usage
                SKIP_LOG="$PROJECT_ROOT/.claude/work/.skip-audit.log"
                echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) SKIP used for: $FILE_PATH" >> "$SKIP_LOG" 2>/dev/null
                exit 0
            fi

            # Check 2: Plan file exists and is approved
            PLAN_FILE="$PROJECT_ROOT/.claude/work/$BRANCH/plan.md"
            if [[ -f "$PLAN_FILE" ]]; then
                # Check for approved status (case-insensitive)
                if ! grep -qiE '\*\*Status:\*\*.*approved' "$PLAN_FILE" 2>/dev/null; then
                    CURRENT_STATUS=$(grep -oiE '\*\*Status:\*\*\s*\S+' "$PLAN_FILE" 2>/dev/null | head -1 | sed 's/.*\*\* *//')
                    echo "BLOCKED: Plan exists but is NOT approved (current: ${CURRENT_STATUS:-unknown})." >&2
                    echo "" >&2
                    echo "  Plan: .claude/work/$BRANCH/plan.md" >&2
                    echo "  Action: Review the plan and set **Status:** approved" >&2
                    exit 2
                fi

                # ─── PHASE TASKS GATE ─────────────────────────────
                # If .phases-required exists but .phases-created doesn't,
                # block code edits until phase tasks are created.
                PHASES_REQUIRED="$PROJECT_ROOT/.claude/work/$BRANCH/.phases-required"
                PHASES_CREATED="$PROJECT_ROOT/.claude/work/$BRANCH/.phases-created"
                if [[ -f "$PHASES_REQUIRED" ]] && [[ ! -f "$PHASES_CREATED" ]]; then
                    PHASE_COUNT=$(grep 'phases=' "$PHASES_REQUIRED" 2>/dev/null | sed 's/phases=//' || echo "?")
                    echo "BLOCKED: Phase tasks not yet created." >&2
                    echo "" >&2
                    echo "  Plan has $PHASE_COUNT phases. Create TaskCreate items for each phase" >&2
                    echo "  (with PENDING UAT placeholders), then write .phases-created." >&2
                    echo "" >&2
                    echo "  Pattern:" >&2
                    echo "    TaskCreate('Phase 1: [name]', '...UAT 1.1: PENDING\\nUAT 1.2: PENDING')" >&2
                    echo "    ...repeat for each phase..." >&2
                    echo "    Write .claude/work/$BRANCH/.phases-created" >&2
                    exit 2
                fi
            fi
        fi
    fi

    # ─── ROUTE 2c: SQL MIGRATION VALIDATION ───────────────────
    if [[ "$TOOL_NAME" == "Write" ]] && [[ "$FILE_PATH" == *.sql ]]; then
        if echo "$FILE_PATH" | grep -qiE '(migration|supabase|schema)'; then
            CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null)

            if [[ -n "$CONTENT" ]]; then
                HAS_BEGIN=$(echo "$CONTENT" | grep -ciE '^\s*BEGIN\s*;?\s*$' || true)
                HAS_COMMIT=$(echo "$CONTENT" | grep -ciE '^\s*COMMIT\s*;?\s*$' || true)

                if [[ "$HAS_BEGIN" -eq 0 ]] || [[ "$HAS_COMMIT" -eq 0 ]]; then
                    echo "BLOCKED: SQL migration must be wrapped in BEGIN/COMMIT per Rule #6." >&2
                    echo "Add 'BEGIN;' at the start and 'COMMIT;' at the end." >&2
                    exit 2
                fi
            fi
        fi
    fi
fi

exit 0
