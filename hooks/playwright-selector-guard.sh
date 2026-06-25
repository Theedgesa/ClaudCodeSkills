#!/usr/bin/env bash
# Hook: PostToolUse Write|Edit — warn on page-wide text matching in Playwright tests
# Past-errors rule #41: Never use page-wide text matching in Playwright tests

set -euo pipefail

# Only check .spec.ts files
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only apply to Playwright spec files
if [[ "$FILE_PATH" != *.spec.ts ]]; then
  exit 0
fi

# Check for page-wide text matching anti-patterns
WARNINGS=""

if grep -qE "page\.textContent\(['\"]body['\"]" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS}\n  - page.textContent('body') — matches unrelated text anywhere on page"
fi

if grep -qE "pageContent\?\.\includes\(|pageContent\.includes\(" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS}\n  - pageContent.includes() — page-wide string search produces false positives"
fi

if grep -qE "await page\.content\(\)" "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS}\n  - page.content() — full HTML string match is fragile"
fi

if [[ -n "$WARNINGS" ]]; then
  echo "WARNING (past-errors #41): Page-wide text matching in Playwright test."
  echo "  File: $FILE_PATH"
  echo -e "  Found:$WARNINGS"
  echo "  Fix: Use scoped selectors — page.getByText(), page.getByRole(), or [data-testid] within a locator."
  echo ""
  echo "  Example:"
  echo "    BAD:  const text = await page.textContent('body'); expect(text?.includes('X')).toBeTruthy();"
  echo "    GOOD: await expect(page.getByText('X')).toBeVisible();"
fi

# Advisory only — don't block
exit 0
