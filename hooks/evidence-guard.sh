#!/bin/bash
# Evidence guard — catches probabilistic/hedging language in assistant output
# Hook type: Stop
# When triggered: forces the assistant to gather evidence instead of speculating

INPUT=$(cat)
MESSAGE=$(echo "$INPUT" | jq -r '.message // empty' 2>/dev/null)

if [ -z "$MESSAGE" ]; then
  exit 0
fi

# Case-insensitive matching
MESSAGE_LOWER=$(echo "$MESSAGE" | tr '[:upper:]' '[:lower:]')

# Weasel words — hedging, uncertainty, speculation
# Each pattern checked as a word/phrase boundary match
PATTERNS=(
  "probably"
  "likely"
  "unlikely"
  "most likely"
  "might be"
  "might have"
  "could be"
  "should work"
  "should be fine"
  "should fix"
  "should have"
  "i think"
  "i believe"
  "i assume"
  "i guess"
  "i expect"
  "i suspect"
  "i imagine"
  "i would assume"
  "seems like"
  "seems to"
  "appears to"
  "appears"
  "presumably"
  "my guess"
  "in theory"
  "theoretically"
  "looks like it"
  "that would explain"
)

FOUND=""
for PATTERN in "${PATTERNS[@]}"; do
  if echo "$MESSAGE_LOWER" | grep -q "$PATTERN"; then
    FOUND="$PATTERN"
    break
  fi
done

if [ -n "$FOUND" ]; then
  echo "EVIDENCE REQUIRED: You used '$FOUND'. Back up your claim with actual evidence — run a command, query the DB, or load the page. If you genuinely cannot verify right now, say UNVERIFIABLE and explain why. Do not speculate."
  exit 1
fi

exit 0
