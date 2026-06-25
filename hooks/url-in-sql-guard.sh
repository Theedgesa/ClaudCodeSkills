#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# URL-in-SQL Guard — PostToolUse Hook for Write/Edit on .sql files
# ═══════════════════════════════════════════════════════════════
# After writing a SQL file, checks any URLs found in the content
# and warns if they return non-200 status codes.
# Past-errors rule #29: Verify URLs are accessible when storing
# them in DB config.
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
if [[ "$TOOL_NAME" != "Write" ]] && [[ "$TOOL_NAME" != "Edit" ]]; then
    exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)
[[ -z "$FILE_PATH" ]] && exit 0

# Only check SQL files
[[ "$FILE_PATH" != *.sql ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

# Extract URLs from the file
URLS=$(grep -oE 'https?://[^ "'"'"'\\)]+' "$FILE_PATH" 2>/dev/null | sort -u)
[[ -z "$URLS" ]] && exit 0

FAILED=0
echo ""
echo "  [url-in-sql-guard] URLs found in SQL file — verifying accessibility:"

while IFS= read -r url; do
    # Skip localhost URLs (dev environment)
    if echo "$url" | grep -q 'localhost'; then
        continue
    fi
    STATUS=$(curl -sI -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
    if [ "$STATUS" = "200" ] || [ "$STATUS" = "301" ] || [ "$STATUS" = "302" ]; then
        echo "    OK ($STATUS) $url"
    elif [ "$STATUS" = "000" ]; then
        echo "    WARN (timeout) $url — could not reach"
        FAILED=1
    else
        echo "    WARN ($STATUS) $url — verify this URL is correct"
        FAILED=1
    fi
done <<< "$URLS"

if [ "$FAILED" = "1" ]; then
    echo ""
    echo "  WARNING: One or more URLs returned non-200."
    echo "  Past-errors #29: Verify URLs are accessible when storing in DB config."
    echo ""
fi

exit 0
