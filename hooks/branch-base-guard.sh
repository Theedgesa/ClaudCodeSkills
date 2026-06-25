#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Branch Base Guard — PreToolUse Hook (Bash)
# ═══════════════════════════════════════════════════════════════
# Warns when creating a worktree/branch from main while staging
# is ahead. Prevents merge conflicts when PR targets staging.
#
# Incident: PROJ-150 branched from main, missed 3 PRs on staging,
# caused 9 merge conflicts.
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[ -z "$COMMAND" ] && exit 0

# Check for git worktree add or git checkout -b from main
IS_WORKTREE=$(echo "$COMMAND" | grep -E 'git\s+worktree\s+add')
IS_BRANCH=$(echo "$COMMAND" | grep -E 'git\s+(checkout|switch)\s+-b')

[ -z "$IS_WORKTREE" ] && [ -z "$IS_BRANCH" ] && exit 0

# Check if branching from main (explicit or implicit via current branch)
BRANCHING_FROM_MAIN=false

if echo "$COMMAND" | grep -qE '\bmain\b|\bmaster\b'; then
  BRANCHING_FROM_MAIN=true
fi

# If not explicitly from main, check current branch
if [ "$BRANCHING_FROM_MAIN" = "false" ] && [ -n "$IS_BRANCH" ]; then
  CURRENT=$(git branch --show-current 2>/dev/null)
  if [ "$CURRENT" = "main" ] || [ "$CURRENT" = "master" ]; then
    BRANCHING_FROM_MAIN=true
  fi
fi

[ "$BRANCHING_FROM_MAIN" = "false" ] && exit 0

# Check if staging is ahead of main
git fetch origin staging main 2>/dev/null
AHEAD=$(git rev-list --count main..origin/staging 2>/dev/null)

if [ -n "$AHEAD" ] && [ "$AHEAD" -gt 0 ]; then
  COMMITS=$(git log --oneline main..origin/staging 2>/dev/null | head -5)
  cat <<WARN

WARNING: Staging is ${AHEAD} commit(s) ahead of main.
Creating a branch from main will miss these changes and cause merge conflicts when PR targets staging.

Recent staging-only commits:
${COMMITS}

Recommended: branch from origin/staging instead.
  git worktree add <path> -b <branch> origin/staging

Proceeding anyway (not blocked — just a warning).
WARN
fi

exit 0
