#!/bin/bash
# PostToolUse: Write|Edit — Warn when package.json changes may break CI
#
# Triggers when package.json is edited with structural changes
# (workspaces, prepare, scripts) that require CI workflow updates.
# Past-errors rule #31: PROJ-153 CI broke because workspace npm ci
# overwrote the @myproject/core symlink.

FILE_PATH="${CLAUDE_FILE_PATH:-$1}"

# Only check root package.json or worktree root package.json
case "$FILE_PATH" in
  */MyProject-v3/package.json|*/PROJ-*/package.json)
    ;;
  *)
    exit 0
    ;;
esac

# Check if the edit touched structural fields
DIFF=$(git diff --no-color -- "$FILE_PATH" 2>/dev/null || cat "$FILE_PATH")

NEEDS_REVIEW=0
REASONS=""

if echo "$DIFF" | grep -q '"workspaces"'; then
  NEEDS_REVIEW=1
  REASONS="${REASONS}\n  - workspaces changed: CI npm install steps must match"
fi

if echo "$DIFF" | grep -q '"prepare"'; then
  NEEDS_REVIEW=1
  REASONS="${REASONS}\n  - prepare script changed: must use '|| true' for CI safety"
fi

if echo "$DIFF" | grep -q '"overrides"'; then
  NEEDS_REVIEW=1
  REASONS="${REASONS}\n  - overrides changed: CI install may resolve different versions"
fi

if [ "$NEEDS_REVIEW" -eq 1 ]; then
  echo "CI-WORKFLOW-GUARD: package.json structural change detected."
  echo -e "Reasons:${REASONS}"
  echo ""
  echo "ACTION REQUIRED: Read .github/workflows/quality.yml and verify:"
  echo "  1. Workspace members do NOT have separate 'npm ci' steps"
  echo "  2. Root 'npm install' handles all workspace members"
  echo "  3. 'prepare' script uses '|| true' for CI safety"
  echo "  4. Any new package has a typecheck step in CI"
  echo ""
  echo "Incident: PROJ-153 — 'cd store-website && npm ci' overwrote workspace symlink"
fi

exit 0
