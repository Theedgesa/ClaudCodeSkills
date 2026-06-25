#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Weasel Word Guard — Stop hook (ACTIVE BLOCKER)
# ═══════════════════════════════════════════════════════════════
# Checks Claude's last_assistant_message for hedging language.
# If found, blocks with decision:block so Claude must revise.
#
# Stop hook stdin fields:
#   session_id, transcript_path, cwd, permission_mode,
#   hook_event_name, stop_hook_active, last_assistant_message
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

# Only in MyProject project
if [[ "$PWD" != *"MyProject"* ]] && [[ "$PWD" != *"MyProject-v3"* ]] && [[ "$PWD" != *"myproject"* ]]; then
    exit 0
fi

# Extract ONLY the assistant's prose — not tool results or code
RESPONSE=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)

if [[ -z "$RESPONSE" ]]; then
    exit 0
fi

# Convert to lowercase for matching
LOWER=$(echo "$RESPONSE" | tr '[:upper:]' '[:lower:]')

# Weasel patterns — ordered most-specific first
WEASEL_PATTERNS=(
    "should work"
    "i think "
    "i believe "
    "most likely"
    "it looks like"
    "appears to be"
    "appears to "
    "might be "
    "could be "
    "probably"
    "presumably"
    "likely"
    "seems "
    "seems,"
    "seems."
    "pre-date"
    "predate"
)

FOUND=""
for PATTERN in "${WEASEL_PATTERNS[@]}"; do
    if echo "$LOWER" | grep -q "$PATTERN"; then
        FOUND="$PATTERN"
        break
    fi
done

# Skip "likely" if it's only "unlikely"
if [[ "$FOUND" == "likely" ]]; then
    WITHOUT_UNLIKELY=$(echo "$LOWER" | sed 's/unlikely//g')
    if ! echo "$WITHOUT_UNLIKELY" | grep -q "likely"; then
        FOUND=""
    fi
fi

if [[ -n "$FOUND" ]]; then
    DISPLAY=$(echo "$FOUND" | xargs)
    cat <<HOOKEOF
{"decision":"block","reason":"WEASEL WORD: \"$DISPLAY\". You used speculative language. REWRITE the entire finding/section from scratch with evidence (logs, query results, code references) or say \"I don't know\". Do NOT just address the weasel word in isolation — output the complete corrected version so the user doesn't have to scroll up. Never hedge. Rule: past-errors #18."}
HOOKEOF
    exit 0
fi

exit 0
