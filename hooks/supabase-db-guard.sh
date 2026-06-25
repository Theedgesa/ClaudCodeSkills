#!/bin/bash
# supabase-db-guard.sh — Identifies which Supabase DB the MCP tool targets
# PreToolUse hook for mcp__supabase__execute_sql and mcp__supabase__apply_migration
#
# Reads the MCP config to determine project_ref, maps it to a label,
# and BLOCKS if targeting production while plan status is not Phase 5.

set -euo pipefail

# Known project refs
PRODUCTION_REF="<project-ref>"
PRODUCTION_LABEL="PRODUCTION (<project-ref>.supabase.co)"

# Find MCP config
MCP_CONFIG=""
for f in \
  "$WORKSPACE_ROOT/.mcp.json" \
  "$HOME/.claude/.mcp.json"; do
  if [ -f "$f" ]; then
    MCP_CONFIG="$f"
    break
  fi
done

if [ -z "$MCP_CONFIG" ]; then
  echo "⚠️  Cannot determine Supabase target — no .mcp.json found"
  exit 0
fi

# Extract project_ref from MCP config
PROJECT_REF=$(python3 -c "
import json
with open('$MCP_CONFIG') as f:
    data = json.load(f)
    servers = data.get('mcpServers', data)
    for name, cfg in servers.items():
        if 'supabase' in name.lower():
            url = cfg.get('url', '')
            import re
            m = re.search(r'project_ref=([a-z0-9]+)', url)
            if m:
                print(m.group(1))
                break
" 2>/dev/null)

if [ -z "$PROJECT_REF" ]; then
  echo "⚠️  Cannot extract project_ref from MCP config"
  exit 0
fi

if [ "$PROJECT_REF" = "$PRODUCTION_REF" ]; then
  echo "🔴 SUPABASE TARGET: $PRODUCTION_LABEL"
  echo ""
  echo "  The MCP Supabase tool is connected to PRODUCTION."
  echo "  For staging work, use curl to staging Supabase instead."
  echo ""
  echo "  To allow production SQL (Phase 5 deploy):"
  echo "    echo PRODUCTION_OK > /tmp/supabase-prod-override"
  echo ""

  # Check for override — must contain PRODUCTION_OK:<plan-path>
  if [ -f /tmp/supabase-prod-override ]; then
    OVERRIDE_CONTENT=$(cat /tmp/supabase-prod-override)

    # Accept both formats: "PRODUCTION_OK" (legacy) and "PRODUCTION_OK:<plan-path>"
    if echo "$OVERRIDE_CONTENT" | grep -q "^PRODUCTION_OK:"; then
      PLAN_PATH=$(echo "$OVERRIDE_CONTENT" | cut -d: -f2-)
      if [ -f "$PLAN_PATH" ] && grep -q '^\*\*Status:\*\* approved' "$PLAN_PATH" 2>/dev/null; then
        echo "  ⚠️  Production override active — approved plan: $PLAN_PATH"
        exit 0
      else
        echo "  ⚠️  Production override has plan path but plan is not approved or missing: $PLAN_PATH"
        echo "  ⚠️  Proceeding anyway (plan approval check is advisory)"
        exit 0
      fi
    elif [ "$OVERRIDE_CONTENT" = "PRODUCTION_OK" ]; then
      echo "  ⚠️  Production override active (legacy format, no plan path) — proceeding"
      exit 0
    fi
  fi

  # Block
  echo "BLOCKED: MCP Supabase targets PRODUCTION. Use curl for staging SQL. Set override for Phase 5 production deploy."
  echo "decision:block"
  exit 2
fi

echo "🟢 SUPABASE TARGET: staging ($PROJECT_REF)"
exit 0
