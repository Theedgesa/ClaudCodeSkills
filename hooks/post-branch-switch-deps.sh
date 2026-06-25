#!/bin/bash
# post-branch-switch-deps.sh
# Warns when package.json files differ after branch operations (checkout, stash pop, merge)
# Triggers on: Bash commands containing git checkout, git switch, git stash pop, git merge
#
# Checks server/, reception-website/, store-website/ for package.json changes

INPUT=$(cat)
CMD=$(echo "$INPUT" | head -1)

# Only check git branch-switching commands
if ! echo "$CMD" | grep -qiE "git (checkout|switch|stash pop|merge|pull|rebase)"; then
  exit 0
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PROJECT_ROOT")
WARNINGS=""

for DIR in server reception-website store-website; do
  PKG="$REPO_ROOT/$DIR/package.json"
  LOCK="$REPO_ROOT/$DIR/node_modules/.package-lock.json"

  if [ ! -f "$PKG" ]; then continue; fi
  if [ ! -f "$LOCK" ]; then
    WARNINGS="$WARNINGS\n  ⚠ $DIR/node_modules missing — run: cd $DIR && npm install"
    continue
  fi

  # Check if package.json is newer than node_modules
  if [ "$PKG" -nt "$LOCK" ]; then
    WARNINGS="$WARNINGS\n  ⚠ $DIR/package.json newer than node_modules — run: cd $DIR && npm install"
  fi
done

if [ -n "$WARNINGS" ]; then
  echo "NOTICE: Dependencies may be out of sync after branch operation."
  echo -e "$WARNINGS"
  echo ""
  echo "Run npm install in affected directories to prevent runtime errors."
  # Don't block — just warn
fi

exit 0
