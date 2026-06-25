#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Delete-Reference Guard — PostToolUse Hook (Edit)
# ═══════════════════════════════════════════════════════════════
# When an Edit removes code (old_string > new_string), extracts
# identifiers from the deleted text and greps the file for orphaned
# references. Warns (does not block) if found.
#
# Prevents: stale variable/state references after block deletion.
# Incident: PROJ-135 had 3 stale refs (rentalFormData, newAvailableQuantity,
# rentalExistsInDb) after removing code blocks.
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Only run on Edit (not Write — Write is full file replacement)
if [[ "$TOOL_NAME" != "Edit" ]]; then
    exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
OLD_STRING=$(echo "$INPUT" | jq -r '.tool_input.old_string // empty' 2>/dev/null)
NEW_STRING=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' 2>/dev/null)

# Skip if no file or no old_string
if [[ -z "$FILE_PATH" ]] || [[ -z "$OLD_STRING" ]] || [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi

# Only check deletions: old_string must be significantly longer than new_string
OLD_LEN=${#OLD_STRING}
NEW_LEN=${#NEW_STRING}
DIFF=$((OLD_LEN - NEW_LEN))

# Threshold: at least 100 chars removed (skip trivial edits)
if [[ $DIFF -lt 100 ]]; then
    exit 0
fi

# Skip non-code files
case "$FILE_PATH" in
    *.md|*.yaml|*.yml|*.json|*.txt|*.css|*.html|*.env*) exit 0 ;;
esac

# Extract identifiers from deleted text that are NOT in new text
# Look for: variable names, function names, state setters
# Pattern: camelCase or snake_case identifiers (3+ chars)
DELETED_ONLY=$(diff <(echo "$OLD_STRING") <(echo "$NEW_STRING") | grep "^< " | sed 's/^< //')

# Extract unique identifiers (camelCase words 3+ chars, excluding common keywords)
IDENTIFIERS=$(echo "$DELETED_ONLY" | grep -oE '\b[a-zA-Z_][a-zA-Z0-9_]{2,}\b' | sort -u | \
    grep -vE '^(const|let|var|function|return|import|export|from|true|false|null|undefined|async|await|try|catch|if|else|for|while|new|this|class|extends|typeof|instanceof|void|delete|throw|switch|case|break|continue|default|with|finally|yield|static|super|console|document|window|require|module|error|Error|data|value|index|item|type|string|number|boolean|object|array|props|state|event|prev|next|key|map|filter|find|push|length|toString|trim|parseInt|parseFloat|isNaN|Math|Date|JSON|Object|Array|String|Number|Promise|setTimeout|setInterval|React|useState|useEffect|useCallback|useRef|useRouter|div|span|button|input|select|option|label|form|img|className|onClick|onChange|disabled|children|text|name|description|status|price|quantity|location|slug|created_at|updated_at)$')

if [[ -z "$IDENTIFIERS" ]]; then
    exit 0
fi

# Check which identifiers still exist in the file
ORPHANS=""
while IFS= read -r ident; do
    # Count occurrences in the file AFTER the edit
    COUNT=$(grep -c "\b${ident}\b" "$FILE_PATH" 2>/dev/null || echo "0")
    if [[ "$COUNT" -gt 0 ]]; then
        # It still exists — check if it's ONLY in the remaining code (not a declaration)
        # This means there's a reference but the declaration/assignment was deleted
        ORPHANS="${ORPHANS}\n  - ${ident} (${COUNT} remaining reference(s))"
    fi
done <<< "$IDENTIFIERS"

if [[ -n "$ORPHANS" ]]; then
    FILENAME=$(basename "$FILE_PATH")
    echo "⚠️ DELETE-REFERENCE WARNING: Identifiers from deleted code still referenced in ${FILENAME}:${ORPHANS}"
    echo ""
    echo "Check these aren't orphaned references to removed variables/state/functions."
fi

exit 0
