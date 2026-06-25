#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Test Data Email Guard — PreToolUse Hook
# ═══════════════════════════════════════════════════════════════
# Blocks ANY action that could create test data or send emails/
# invoices/notifications to anyone other than the approved test
# account. Covers:
#   - MCP tools (Zoho, Shopify, Make.com, Supabase)
#   - Bash commands (test scripts, curl, sync scripts)
#   - Any tool writing code that sends emails to non-test accounts
#
# Incident: SHOP-XXXX invoice created for Aicha Ibnseddik via
# syncToZohoBooks() webhook flow during testing on 2026-03-26.
# ═══════════════════════════════════════════════════════════════

APPROVED_EMAIL="dev@example.com"
# Staff/system emails that are OK (not customer-facing)
ALLOWED_STAFF_PATTERN="@tenanta\.sa$|@parentcorp\.com$|@myproject\.app$"

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty' 2>/dev/null)

# Flatten the entire tool input to a single string for email scanning
FLAT_INPUT=$(echo "$TOOL_INPUT" | jq -r '.. | strings' 2>/dev/null | tr '\n' ' ')

# ─── Skip if no input or tool name ──────────────────────────
if [[ -z "$TOOL_NAME" ]] || [[ -z "$FLAT_INPUT" ]]; then
    exit 0
fi

# ─── Helper: check if email is allowed ──────────────────────
is_allowed_email() {
    local email_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    # Approved test account
    if [[ "$email_lower" == "$APPROVED_EMAIL" ]]; then
        return 0
    fi
    # Staff/system emails (not customer-facing)
    if echo "$email_lower" | grep -qE "$ALLOWED_STAFF_PATTERN"; then
        return 0
    fi
    return 1
}

# ─── Helper: scan for blocked emails ────────────────────────
check_emails_in_text() {
    local text="$1"
    local context="$2"
    local EMAILS_FOUND=$(echo "$text" | grep -oiE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | sort -u)

    if [[ -n "$EMAILS_FOUND" ]]; then
        while IFS= read -r email; do
            if ! is_allowed_email "$email"; then
                echo "BLOCKED: Test data email guard triggered ($context)." >&2
                echo "" >&2
                echo "  Found email: $email" >&2
                echo "  Approved test email: $APPROVED_EMAIL" >&2
                echo "" >&2
                echo "  ALL test data (orders, invoices, contacts, confirmation emails)" >&2
                echo "  must ONLY target $APPROVED_EMAIL." >&2
                echo "  Staff emails (@tenant-a.example, @parentcorp.example) are allowed." >&2
                echo "" >&2
                echo "  Incident ref: SHOP-XXXX — invoice created for real client during testing." >&2
                exit 2
            fi
        done <<< "$EMAILS_FOUND"
    fi
}

# ─── GUARD 1: MCP tools (Zoho, Shopify, Make.com, Supabase) ─
if echo "$TOOL_NAME" | grep -qiE '(zoho|shopify|make-edge|make-tenant-b|supabase)'; then
    check_emails_in_text "$FLAT_INPUT" "MCP: $TOOL_NAME"
fi

# ─── GUARD 2: Bash commands ─────────────────────────────────
if [[ "$TOOL_NAME" == "Bash" ]]; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
    CMD_LOWER=$(echo "$COMMAND" | tr '[:upper:]' '[:lower:]')

    # Block test-zoho-books.js with test-order (uses real customer data)
    if echo "$CMD_LOWER" | grep -qE 'test-zoho-books.*test-order'; then
        echo "BLOCKED: test-zoho-books.js test-order uses real customer data." >&2
        echo "" >&2
        echo "  This command syncs a real order to Zoho Books, potentially" >&2
        echo "  creating invoices for actual clients." >&2
        echo "  Use 'test-full' mode instead (creates synthetic test data)." >&2
        exit 2
    fi

    # Block sync-order and sync-orders commands that target real orders
    if echo "$CMD_LOWER" | grep -qE '(sync-order|sync-orders|zoho.*sync)'; then
        echo "BLOCKED: Zoho sync commands must be reviewed manually." >&2
        echo "" >&2
        echo "  Running sync commands can create invoices and contacts in Zoho" >&2
        echo "  for real customers. Only sync orders for $APPROVED_EMAIL." >&2
        exit 2
    fi

    # Check for email addresses in commands touching external services
    if echo "$CMD_LOWER" | grep -qiE '(curl|fetch|http|invoice|order|contact|email|webhook|sync|send|notify)'; then
        check_emails_in_text "$COMMAND" "Bash command"
    fi

    # Block running the server's webhook test endpoints with real data
    if echo "$CMD_LOWER" | grep -qE '(myfatoorah|webhook.*test|test.*webhook).*[0-9a-f-]{36}'; then
        echo "BLOCKED: Webhook test with order UUID detected." >&2
        echo "" >&2
        echo "  Triggering webhooks for real orders sends confirmation emails" >&2
        echo "  and creates Zoho invoices for real customers." >&2
        echo "  Only test with orders placed by $APPROVED_EMAIL." >&2
        exit 2
    fi
fi

# ─── GUARD 3: Write/Edit — code that hardcodes non-test emails ─
if [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]]; then
    # Only check files that handle emails/orders/invoices
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    if echo "$FILE_PATH" | grep -qiE '(test|script|migration|seed)'; then
        CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)
        if [[ -n "$CONTENT" ]]; then
            check_emails_in_text "$CONTENT" "Write/Edit in test/script file"
        fi
    fi
fi

exit 0
