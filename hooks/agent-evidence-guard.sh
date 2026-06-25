#!/bin/bash
# PostToolUse: Agent — Remind to verify agent results with /evidence
# Agents can introduce bugs (wrong chain order, undefined tenantId, missed callers).
# Never trust agent output without runtime verification.

cat <<'JSONEOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "AGENT COMPLETE — Run /evidence before claiming results are correct. Verify with runtime test (start server, hit endpoints), not just static analysis (grep, node --check). Past incident: PROJ-MT5 agents introduced 163 wrong .from().eq() chain orders and 4 undefined tenantId sources that only crashed at runtime."
  }
}
JSONEOF
