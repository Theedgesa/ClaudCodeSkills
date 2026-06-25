#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Merge Conflict Guard — PreToolUse Hook (Bash)
# ═══════════════════════════════════════════════════════════════
# Before creating a PR, checks for merge conflicts against the
# target branch using git merge --no-commit (more reliable than
# git merge-tree which can miss conflicts).
#
# Prevents: PRs with merge conflicts that require extra fixup commits.
# Incidents:
#   PROJ-135 PR #198 (staging→main) had roadmap.yaml conflict.
#   PROJ-150 PR #213 merge-tree showed 0 but real merge had 9 conflicts.
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only check gh pr create commands targeting main or staging
if ! echo "$COMMAND" | grep -qE 'gh\s+pr\s+create'; then
    exit 0
fi

# Extract --base branch
BASE=$(echo "$COMMAND" | grep -oE '\-\-base\s+(main|staging|master)' | awk '{print $2}')

if [[ -z "$BASE" ]]; then
    exit 0
fi

# Fetch latest target branch
git fetch origin "$BASE" 2>/dev/null

# Try a real merge (no-commit, no-ff) to detect conflicts accurately
MERGE_OUTPUT=$(git merge --no-commit --no-ff "origin/$BASE" 2>&1)
MERGE_EXIT=$?

if [[ $MERGE_EXIT -ne 0 ]]; then
    # Conflicts detected — extract conflicting files
    CONFLICTS=$(echo "$MERGE_OUTPUT" | grep "CONFLICT" | sed 's/CONFLICT.*: Merge conflict in /  - /' | sed 's/CONFLICT.*: /  - /')

    # Abort the test merge
    git merge --abort 2>/dev/null

    echo "BLOCKED: Merge conflicts detected against origin/${BASE}."
    echo ""
    echo "Conflicting files:"
    echo "$CONFLICTS"
    echo ""
    echo "Fix: rebase on origin/${BASE} first:"
    echo "  git fetch origin ${BASE}"
    echo "  git rebase origin/${BASE}"
    echo "  # resolve conflicts"
    echo "  git push --force-with-lease"
    echo ""
    echo "decision:block"
    exit 2
fi

# No conflicts — abort the test merge and allow PR creation
git merge --abort 2>/dev/null

exit 0
