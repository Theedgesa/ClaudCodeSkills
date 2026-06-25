#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# SDK Wrapper Guard — PostToolUse Advisory Hook for Write/Edit
# ═══════════════════════════════════════════════════════════════
# When a file is written/edited that requires a third-party SDK
# (supertokens-node, @supabase/supabase-js, shopify-api-node, etc.),
# reminds to audit method signatures.
# Past-errors rule #30: Audit all SDK method signatures when
# wrapping a third-party SDK.
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
if [[ "$TOOL_NAME" != "Write" ]] && [[ "$TOOL_NAME" != "Edit" ]]; then
    exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)
[[ -z "$FILE_PATH" ]] && exit 0

# Only check JS files in server/
[[ "$FILE_PATH" != *server/*.js ]] && exit 0
[[ "$FILE_PATH" == *node_modules* ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

# Check for third-party SDK requires
SDK_FOUND=""
if grep -q "require('supertokens-node" "$FILE_PATH" 2>/dev/null; then
    SDK_FOUND="supertokens-node"
elif grep -q "require('@shopify" "$FILE_PATH" 2>/dev/null; then
    SDK_FOUND="shopify"
elif grep -q "require('myfatoorah" "$FILE_PATH" 2>/dev/null; then
    SDK_FOUND="myfatoorah"
elif grep -q "require('zoho" "$FILE_PATH" 2>/dev/null; then
    SDK_FOUND="zoho"
fi

if [[ -n "$SDK_FOUND" ]]; then
    echo ""
    echo "  [sdk-wrapper-guard] This file wraps $SDK_FOUND SDK methods."
    echo "  Past-errors #30: Audit SDK method signatures before shipping."
    echo "  Run: node -e \"const pkg = require('$SDK_FOUND'); Object.keys(pkg).forEach(k => typeof pkg[k]==='function' && console.log(k, pkg[k].length, 'params'))\""
    echo ""
fi

exit 0
