#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# No Scope Dodge Guard — Stop hook (ACTIVE BLOCKER)
# ═══════════════════════════════════════════════════════════════
# Catches when Claude tries to dismiss something as "pre-existing",
# "out of scope", or "not introduced by this work" instead of
# investigating it as part of the current task.
#
# User rule: always study and address issues encountered during
# current work, never wave them away.
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

# Only in MyProject project
if [[ "$PWD" != *"MyProject"* ]] && [[ "$PWD" != *"MyProject-v3"* ]] && [[ "$PWD" != *"myproject"* ]]; then
    exit 0
fi

RESPONSE=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)

if [[ -z "$RESPONSE" ]]; then
    exit 0
fi

# Strip fenced code blocks (```...```), inline code (`...`), and
# bullet lists that merely enumerate patterns (lines starting with - `)
# to avoid false positives when describing the hook itself or listing patterns.
PROSE=$(echo "$RESPONSE" \
    | sed '/^```/,/^```/d' \
    | sed 's/`[^`]*`//g' \
    | sed '/^[[:space:]]*[-*] `/d' \
    | sed '/^[[:space:]]*[-*] \*\*/d' \
    | sed '/^|\|^+--/d' \
)

# Also skip if the response is primarily about the hook itself
if echo "$PROSE" | grep -qiE "(hook|guard|pattern).*(catches|detects|blocks|triggers|scans|monitors)"; then
    exit 0
fi

LOWER=$(echo "$PROSE" | tr '[:upper:]' '[:lower:]')

# Dismissive scope-dodge patterns
DODGE_PATTERNS=(
    "pre-existing"
    "preexisting"
    "out of scope"
    "outside the scope"
    "beyond the scope"
    "not introduced by"
    "was already present"
    "already existed"
    "predates this"
    "predates the current"
    "existing issue"
    "known issue"
    "unrelated to current"
    "unrelated to this"
    "separate issue"
    "tracked separately"
    "not part of this"
    "existing behavior"
    "legacy issue"
    "not caused by"
    "existed before"
    "existed prior"
    "prior to this"
    "introduced previously"
    "previously introduced"
    "not in scope"
    "outside scope"
    "defer to a future"
    "defer this to"
    "separate ticket"
    "separate task"
    "backlog item"
)

FOUND=""
for PATTERN in "${DODGE_PATTERNS[@]}"; do
    if echo "$LOWER" | grep -q "$PATTERN"; then
        FOUND="$PATTERN"
        break
    fi
done

if [[ -n "$FOUND" ]]; then
    DISPLAY=$(echo "$FOUND" | xargs)
    cat <<HOOKEOF
{"decision":"block","reason":"SCOPE DODGE: \"$DISPLAY\". You tried to dismiss something as pre-existing or out of scope. User rule: ALWAYS investigate and address issues encountered during current work. Study the problem, find the root cause, present findings and incorporate it into wider current work analysis and implications. Never wave issues away."}
HOOKEOF
    exit 0
fi

exit 0
