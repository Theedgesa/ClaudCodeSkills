#!/usr/bin/env bash
# roadmap-validation.sh — PostToolUse hook for Write|Edit on *roadmap.yaml
# Validates roadmap.yaml schema: required fields, valid enums, conditional fields.
# Advisory only (exit 0 always) — outputs warnings for Claude to fix.

set -euo pipefail

# Only fire for roadmap.yaml
TOOL_INPUT="${TOOL_INPUT:-}"
if ! echo "$TOOL_INPUT" | grep -q "roadmap.yaml"; then
  exit 0
fi

ROADMAP_FILE=""
# Find roadmap.yaml — check common locations
for candidate in \
  ".claude/work/roadmap.yaml" \
  "MyProject-v3/.claude/work/roadmap.yaml"; do
  if [ -f "$candidate" ]; then
    ROADMAP_FILE="$candidate"
    break
  fi
done

# Also check if the tool input contains an absolute path
ABS_PATH=$(echo "$TOOL_INPUT" | grep -oE '/[^ "]+roadmap\.yaml' | head -1 || true)
if [ -n "$ABS_PATH" ] && [ -f "$ABS_PATH" ]; then
  ROADMAP_FILE="$ABS_PATH"
fi

if [ -z "$ROADMAP_FILE" ]; then
  exit 0
fi

# Validate YAML can be parsed and check schema
WARNINGS=$(node -e "
const yaml = require('js-yaml');
const fs = require('fs');

try {
  const data = yaml.load(fs.readFileSync('$ROADMAP_FILE', 'utf8'));
  const warnings = [];

  // Check strategy section
  if (!data.strategy) {
    warnings.push('Missing strategy section');
  }

  // Valid enums
  const VALID_THEMES = ['platform', 'tenant', 'customer'];
  const VALID_PRIORITIES = ['P0', 'P1', 'P2', 'P3'];
  const VALID_STAGES = [
    'idea', 'spec', 'planned', 'in-progress', 'pr-open',
    'staging', 'production', 'monitoring', 'closed', 'cancelled'
  ];
  const REQUIRED_FIELDS = ['id', 'title', 'theme', 'priority', 'stage', 'created'];

  if (!data.entries || !Array.isArray(data.entries)) {
    warnings.push('Missing or invalid entries list');
  } else {
    for (const entry of data.entries) {
      const id = entry.id || 'UNKNOWN';

      // Required fields
      for (const field of REQUIRED_FIELDS) {
        if (!entry[field]) {
          warnings.push(id + ': missing required field \"' + field + '\"');
        }
      }

      // Enum validation
      if (entry.theme && !VALID_THEMES.includes(entry.theme)) {
        warnings.push(id + ': invalid theme \"' + entry.theme + '\" (must be: ' + VALID_THEMES.join(', ') + ')');
      }
      if (entry.priority && !VALID_PRIORITIES.includes(entry.priority)) {
        warnings.push(id + ': invalid priority \"' + entry.priority + '\" (must be: ' + VALID_PRIORITIES.join(', ') + ')');
      }
      if (entry.stage && !VALID_STAGES.includes(entry.stage)) {
        warnings.push(id + ': invalid stage \"' + entry.stage + '\" (must be: ' + VALID_STAGES.join(', ') + ')');
      }

      // Conditional fields
      if (entry.stage === 'cancelled' && !entry.cancel_reason) {
        warnings.push(id + ': cancelled entries must have cancel_reason');
      }
      if (entry.stage === 'monitoring') {
        if (!entry.verify) warnings.push(id + ': monitoring entries must have verify');
        if (!entry.review_after) warnings.push(id + ': monitoring entries must have review_after');
      }
    }
  }

  if (warnings.length > 0) {
    console.log('ROADMAP VALIDATION WARNINGS:');
    warnings.forEach(w => console.log('  - ' + w));
  } else {
    console.log('Roadmap validation: OK (' + (data.entries ? data.entries.length : 0) + ' entries)');
  }
} catch (e) {
  console.log('ROADMAP VALIDATION ERROR: ' + e.message);
}
" 2>&1)

echo "$WARNINGS"
exit 0
