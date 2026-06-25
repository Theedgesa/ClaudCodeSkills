#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Require Method Guard — PostToolUse Hook
# ═══════════════════════════════════════════════════════════════
# Triggers: After Write/Edit on server/**/*.js
# Purpose: Verify that require('../services/*') or require('../utils/*')
#          method calls resolve to actual exported methods.
#
# Example catch:
#   const svc = require('../services/permission.service');
#   svc.hasPermission(...)     ← hasPermission doesn't exist
#   svc.userHasPermission(...) ← this is the actual method
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Only run on Write/Edit of server JS files
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
    exit 0
fi

if [[ ! "$FILE_PATH" =~ /server/.+\.js$ ]]; then
    exit 0
fi

if [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi

# Find the server root
SERVER_ROOT=$(echo "$FILE_PATH" | sed 's|\(.*server\)/.*|\1|')
if [[ ! -d "$SERVER_ROOT" ]]; then
    exit 0
fi

WARNINGS=""
WARN_COUNT=0

# Extract require() calls to local service/util modules
while IFS= read -r req_line; do
    [[ -z "$req_line" ]] && continue

    # Skip destructured requires: const { X } = require(...)
    if echo "$req_line" | grep -qE 'const\s*\{'; then
        continue
    fi

    # Extract variable name: const VAR = require(...)
    VAR_NAME=$(echo "$req_line" | sed -nE "s/.*const[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=.*/\1/p")
    [[ -z "$VAR_NAME" ]] && continue

    # Extract module path from require('...')
    MODULE_PATH=$(echo "$req_line" | sed -nE "s/.*require\(['\"](\.\.[^'\"]+)['\"].*/\1/p")
    [[ -z "$MODULE_PATH" ]] && continue

    # Only check services/ and utils/ modules
    if ! echo "$MODULE_PATH" | grep -qE '(services|utils)/'; then
        continue
    fi

    # Resolve absolute path
    FILE_DIR=$(dirname "$FILE_PATH")
    RESOLVED="$FILE_DIR/$MODULE_PATH"
    if [[ ! -f "$RESOLVED" && -f "${RESOLVED}.js" ]]; then
        RESOLVED="${RESOLVED}.js"
    fi
    if [[ ! -f "$RESOLVED" ]]; then
        continue
    fi

    # Extract all method calls on this variable: varName.methodName(
    METHODS_CALLED=$(grep -oE "${VAR_NAME}\.[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(" "$FILE_PATH" 2>/dev/null \
        | sed -E "s/${VAR_NAME}\.//; s/[[:space:]]*\(//" \
        | sort -u)

    for METHOD in $METHODS_CALLED; do
        # Skip private methods (starting with _)
        [[ "$METHOD" =~ ^_ ]] && continue

        # Check if this method exists in the resolved module using multiple patterns:
        # 1. async methodName(        — class async methods
        # 2. indented methodName(     — class sync methods
        # 3. const methodName =       — standalone const functions
        # 4. function methodName(     — function declarations
        # 5. exports.methodName =     — direct exports
        # 6. .methodName =            — prototype or object assignment
        # 7. methodName, or methodName} — in module.exports = { ... }
        FOUND=0

        # Pattern 1: async methodName(
        if grep -qE "async[[:space:]]+${METHOD}[[:space:]]*\(" "$RESOLVED" 2>/dev/null; then
            FOUND=1
        fi

        # Pattern 2: indented methodName( — class methods (2+ spaces/tabs)
        if [[ $FOUND -eq 0 ]] && grep -qE "^[[:space:]]{2,}${METHOD}[[:space:]]*\(" "$RESOLVED" 2>/dev/null; then
            FOUND=1
        fi

        # Pattern 3: const methodName =
        if [[ $FOUND -eq 0 ]] && grep -qE "const[[:space:]]+${METHOD}[[:space:]]*=" "$RESOLVED" 2>/dev/null; then
            FOUND=1
        fi

        # Pattern 4: function methodName(
        if [[ $FOUND -eq 0 ]] && grep -qE "function[[:space:]]+${METHOD}[[:space:]]*\(" "$RESOLVED" 2>/dev/null; then
            FOUND=1
        fi

        # Pattern 5: exports.methodName =
        if [[ $FOUND -eq 0 ]] && grep -qE "exports\.${METHOD}[[:space:]]*=" "$RESOLVED" 2>/dev/null; then
            FOUND=1
        fi

        # Pattern 6: .methodName = (prototype or object)
        if [[ $FOUND -eq 0 ]] && grep -qE "\.${METHOD}[[:space:]]*=[[:space:]]" "$RESOLVED" 2>/dev/null; then
            FOUND=1
        fi

        # Pattern 7: methodName in module.exports = { ... } — as key, with comma or closing brace
        if [[ $FOUND -eq 0 ]] && grep -qE "[[:space:],{]${METHOD}[[:space:]]*[,}]" "$RESOLVED" 2>/dev/null; then
            FOUND=1
        fi

        # Pattern 8: methodName: (as object key in exports)
        if [[ $FOUND -eq 0 ]] && grep -qE "[[:space:]]${METHOD}[[:space:]]*:" "$RESOLVED" 2>/dev/null; then
            FOUND=1
        fi

        if [[ $FOUND -eq 0 ]]; then
            MODULE_BASENAME=$(basename "$RESOLVED")
            WARN_COUNT=$((WARN_COUNT + 1))
            WARNINGS="${WARNINGS}\n  ${VAR_NAME}.${METHOD}() — method not found in ${MODULE_BASENAME}"
            # Show available methods
            AVAILABLE=$({
                grep -oE 'async[[:space:]]+[a-zA-Z][a-zA-Z0-9_]*[[:space:]]*\(' "$RESOLVED" 2>/dev/null \
                    | sed -E 's/async[[:space:]]+//; s/[[:space:]]*\(//'
                grep -oE '^[[:space:]]{2,}[a-zA-Z][a-zA-Z0-9_]*[[:space:]]*\(' "$RESOLVED" 2>/dev/null \
                    | sed -E 's/^[[:space:]]+//; s/[[:space:]]*\(//'
                grep -oE 'const[[:space:]]+[a-zA-Z][a-zA-Z0-9_]*[[:space:]]*=' "$RESOLVED" 2>/dev/null \
                    | sed -E 's/const[[:space:]]+//; s/[[:space:]]*=//'
                grep -oE 'function[[:space:]]+[a-zA-Z][a-zA-Z0-9_]*[[:space:]]*\(' "$RESOLVED" 2>/dev/null \
                    | sed -E 's/function[[:space:]]+//; s/[[:space:]]*\(//'
            } | grep -v '^_' | sort -u | head -15 | tr '\n' ', ' | sed 's/,$//')
            WARNINGS="${WARNINGS}\n    Available: ${AVAILABLE}"
        fi
    done

done < <(grep -n "const.*=.*require.*\.\.\/" "$FILE_PATH" 2>/dev/null)

if [[ $WARN_COUNT -gt 0 ]]; then
    echo "decision:block"
    echo ""
    echo "REQUIRE METHOD GUARD: ${WARN_COUNT} unresolved method call(s) in $(basename "$FILE_PATH")"
    echo -e "$WARNINGS"
    echo ""
    echo "The called method(s) do not exist on the required module."
    echo "Check the actual method names in the service file before calling."
    echo ""
    echo "Common cause: architecture docs (rbac.md, etc.) may be stale."
    echo "Always verify method names against the actual source file."
    exit 0
fi

exit 0
