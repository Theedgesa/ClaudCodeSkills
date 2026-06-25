#!/bin/bash
# Stop hook: Block responses that suggest skipping the plan workflow.
# Triggers on: "hotfix", "quick fix", "direct fix", "patch it directly",
# "fix it directly", "skip the plan", "go straight to the fix"

LAST_MSG="${CLAUDE_LAST_ASSISTANT_MESSAGE:-}"

if [ -z "$LAST_MSG" ]; then
  exit 0
fi

# Check for hotfix/process-skipping language
HOTFIX_PATTERNS="hotfix|hot fix|quick fix|direct fix|patch it directly|fix it directly|skip the plan|go straight to the fix|straight to fix|bypass the plan|without a plan"

if echo "$LAST_MSG" | grep -iEq "$HOTFIX_PATTERNS"; then
  echo "BLOCKED: No hotfixes. Every change goes through plan → approve → implement → PR."
  echo "  Write a plan first: .claude/work/PROJ-NNN-name/plan.md"
  echo "  Urgency does not justify skipping process."
  echo "decision:block"
  exit 1
fi

exit 0
