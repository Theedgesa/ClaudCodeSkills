#!/bin/bash
# After any git pull on EC2, verify PM2 processes were restarted
# Incident: PROJ-170 — finance-service ran old code for 34h because PM2 wasn't restarted after git pull

COMMAND="$TOOL_INPUT"

# Trigger on git pull commands to production/staging servers
if echo "$COMMAND" | grep -qE 'ssh.*(eu-region|myproject|staging).*git pull'; then
  echo "REMINDER: After git pull, restart ALL affected PM2 processes:" >&2
  echo "" >&2
  echo "  pm2 restart main-api finance-service" >&2
  echo "" >&2
  echo "  Then verify restart timestamps:" >&2
  echo "  pm2 describe main-api | grep created" >&2
  echo "  pm2 describe finance-service | grep created" >&2
  echo "" >&2
  echo "  created_at must be AFTER the git pull timestamp." >&2
  echo "  Past-errors rule #53." >&2
  # Don't block — just remind
  exit 0
fi

# Trigger on pm2 restart that only restarts one service
if echo "$COMMAND" | grep -qE 'pm2 restart main-api[^[:space:]]*$' && ! echo "$COMMAND" | grep -q 'finance-service'; then
  echo "WARNING: You restarted main-api but NOT finance-service." >&2
  echo "  If finance-service/ files changed, also run: pm2 restart finance-service" >&2
  echo "  Past-errors rule #53." >&2
  exit 0
fi

if echo "$COMMAND" | grep -qE 'pm2 restart finance-service[^[:space:]]*$' && ! echo "$COMMAND" | grep -q 'main-api'; then
  echo "WARNING: You restarted finance-service but NOT main-api." >&2
  echo "  If server/ files changed, also run: pm2 restart main-api" >&2
  echo "  Past-errors rule #53." >&2
  exit 0
fi
