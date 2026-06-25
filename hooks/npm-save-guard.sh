#!/bin/bash
# Blocks npm install with package names (which modifies package.json).
# Prevents accidental package.json corruption in worktrees.
# Allowed: npm install (no args — installs from existing package.json)
# Allowed: npm install --silent, --legacy-peer-deps (flags only)
# Blocked: npm install <package>, npm install --save-dev <package>

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[ -z "$CMD" ] && exit 0

# Skip for SSH/SCP commands — remote installs don't modify local package.json
if echo "$CMD" | grep -qE '^(ssh|scp)\s'; then
  exit 0
fi
# Also skip piped/heredoc scripts sent to remote
if echo "$CMD" | grep -qE 'cat.*\|\s*ssh|ssh.*bash'; then
  exit 0
fi

# Extract the npm install portion, strip all --flags, check if package names remain
if echo "$CMD" | grep -q 'npm install'; then
  PKGS=$(echo "$CMD" | grep -oE 'npm install[^&|;]*' | sed 's/npm install//' | sed 's/--[a-z-]*//g' | xargs)
  if [ -n "$PKGS" ]; then
    cat <<BLOCK
BLOCKED: npm install with package names modifies package.json.

  Packages detected: $PKGS

  To install existing deps: npm install (no package names)
  To add a new package: add it in the main repo, not a worktree.
decision:block
BLOCK
    exit 2
  fi
fi
