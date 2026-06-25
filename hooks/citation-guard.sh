#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Citation Guard — Stop hook (ACTIVE BLOCKER)
# ═══════════════════════════════════════════════════════════════
# Blocks blanket assertions that lack individual citations.
# Forces evidence-backed specifics instead of confident generalities.
#
# Philosophy: same as weasel-word-guard — if the PHRASE appears,
# block. No exceptions. The cost of a false positive (one rewrite)
# is far lower than the cost of an uncited assertion (production bug).
#
# Categories derived from 50+ real production mistakes:
#   1. Completeness claims — #17940: "49 gaps fixed" but 20+ more found
#   2. Negative claims — #18946: "no other" when 9 methods were missed
#   3. Fix claims — #17116: "deployed" but 126 errors in production
#   4. Readiness claims — #17575: shipped with 42 undefined errors
#   5. Blanket verification — #17940: "zero remaining" was false
#   6. Propagation claims — #18946: "threaded" but internal calls omitted
#   7. Runtime/deploy claims — #17116: "successful" with 126 failures
#   8. Existence claims — #17118: "method available" but not a function
#   9. Correctness claims — #15239: "works" but missing ?.
#  10. Count claims — #18947: "found N" without listing each one
#  11. Scope claims — #18599: "in scope" but variable not visible
#  12. Zero/clean claims — #17940: "zero gaps" was wrong
#
# Stop hook stdin fields:
#   session_id, transcript_path, cwd, permission_mode,
#   hook_event_name, stop_hook_active, last_assistant_message
# ═══════════════════════════════════════════════════════════════

INPUT=$(cat)

# Only in MyProject project
if [[ "$PWD" != *"MyProject"* ]] && [[ "$PWD" != *"MyProject-v3"* ]] && [[ "$PWD" != *"myproject"* ]]; then
    exit 0
fi

RESPONSE=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)

if [[ -z "$RESPONSE" ]]; then
    exit 0
fi

LOWER=$(echo "$RESPONSE" | tr '[:upper:]' '[:lower:]')

# ─── CAT 1: COMPLETENESS CLAIMS ──────────────────────────────
# Claim totality without listing each item. Forces enumeration.
# Incident: #17940 — "All 49 gaps fixed" → 20+ more found later
# Incident: #18946 — All 9 email methods had the same omission
COMPLETENESS_PATTERNS=(
    "all callers"
    "all references"
    "all consumers"
    "every caller"
    "every reference"
    "every consumer"
    "all files updated"
    "all methods updated"
    "all paths covered"
    "all code paths"
    "updated all "
    "fixed all "
    "changed all "
    "modified all "
    "checked all callers"
    "verified all callers"
    "confirmed all callers"
    "all instances updated"
    "all usages updated"
    "every instance"
    "all affected files"
    "all gaps fixed"
    "all gaps resolved"
    "all callers pass"
    "all callers now"
    "every method"
    "every service"
    "all services updated"
    "all controllers updated"
    "every controller"
    "all endpoints"
    "every endpoint"
    "all queries"
    "every query"
    "all routes"
)

# ─── CAT 2: NEGATIVE CLAIMS ──────────────────────────────────
# Dismiss impact without search evidence. Forces grep/search citation.
# Incident: #18946 — 9 internal calls omitted, not "no other"
# Incident: #17955 — Registry "loaded config" but missed property assignment
NEGATIVE_PATTERNS=(
    "no other code"
    "no other files"
    "no other callers"
    "no other consumers"
    "no impact on"
    "nothing else affected"
    "nothing else is affected"
    "doesn't affect anything else"
    "won't break anything"
    "no side effects"
    "no breaking changes"
    "no downstream"
    "nothing else needs"
    "no other references"
    "no other methods"
    "no other services"
    "no other places"
    "no other locations"
    "nothing else calls"
    "nothing else uses"
    "no other imports"
    "no other dependencies"
    "doesn't touch"
    "won't affect"
    "can't affect"
    "isolated change"
    "only affects"
    "only impacts"
    "contained to"
)

# ─── CAT 3: UNSUBSTANTIATED FIX CLAIMS ───────────────────────
# Claim a fix works without citing evidence of execution.
# Incident: #15239 — invoiceId.toString() "fixed" but missed one
# Incident: #17589 — Added fix in two places = duplicate declaration
FIX_PATTERNS=(
    "this fixes the"
    "this resolves the"
    "bug is fixed"
    "issue is resolved"
    "issue is fixed"
    "problem is solved"
    "error is fixed"
    "this corrects the"
    "that fixes the"
    "that resolves the"
    "which fixes"
    "which resolves"
    "fix is complete"
    "fix is done"
    "the fix works"
    "fix has been applied"
    "now handles the"
    "now correctly handles"
)

# ─── CAT 4: READINESS WITHOUT EVIDENCE ───────────────────────
# Claim deploy/ship readiness without citing checklist evidence.
# Incident: #17575 — Shipped with 42 undefined variable errors
READINESS_PATTERNS=(
    "safe to deploy"
    "ready to ship"
    "ready to merge"
    "good to deploy"
    "clear to deploy"
    "ready for production"
    "ship it"
    "can be deployed"
    "can be shipped"
    "can be merged"
    "good to go"
    "ready for review"
    "ready for pr"
)

# ─── CAT 5: BLANKET VERIFICATION ─────────────────────────────
# Claim everything was verified without individual items.
# Incident: #17940 — "zero remaining" was false
BLANKET_PATTERNS=(
    "verified everything"
    "tested everything"
    "checked everything"
    "confirmed everything"
    "all tests pass"
    "everything works"
    "everything is correct"
    "everything looks good"
    "all checks pass"
    "all gates pass"
    "all clean"
    "fully verified"
    "fully tested"
    "comprehensive check"
)

# ─── CAT 6: PROPAGATION/THREADING CLAIMS ─────────────────────
# Claim data flows through call chains without tracing each hop.
# Incident: #18946 — 9 methods received tenantId but NONE passed
#   it to sendTemplatedEmail
# Incident: #18477 — Callers pass tenantKey, not tenantId (name
#   mismatch that looks "passed" but isn't)
# Incident: #18945 — Utility methods lack tenantId parameter
#   entirely but call tenantId-aware downstream methods
PROPAGATION_PATTERNS=(
    "properly threaded"
    "correctly propagated"
    "properly passed through"
    "data flows correctly"
    "value is propagated"
    "parameter is forwarded"
    "correctly threaded"
    "passes it through"
    "threads it through"
    "propagates correctly"
    "flows through correctly"
    "threaded through the"
    "threaded all the way"
    "passed down to"
    "passed along to"
    "forwarded to"
    "propagated down"
    "threaded down"
    "parameter reaches"
    "value reaches"
    "tenantid is passed"
    "tenantid is threaded"
    "tenantid flows"
    "tenantid propagates"
)

# ─── CAT 7: DEPLOYMENT/RUNTIME CLAIMS ────────────────────────
# Claim deployed code works without runtime verification evidence.
# Incident: #17116 — "deployed" but 126 "not a function" errors
# Incident: #17118 — Graceful fallback masked total feature failure
DEPLOY_PATTERNS=(
    "deployment successful"
    "deploy succeeded"
    "successfully deployed"
    "running in production"
    "live in production"
    "working in production"
    "no errors in production"
    "production is clean"
    "zero errors since"
    "confirmed working"
    "confirmed running"
    "server is running"
    "service is running"
    "started successfully"
    "restart successful"
    "deployed and working"
    "deployed and verified"
    "feature is live"
    "feature is working"
    "code is deployed"
    "now running"
    "up and running"
)

# ─── CAT 8: METHOD/EXPORT EXISTENCE CLAIMS ───────────────────
# Claim functions/methods exist at runtime without grep evidence.
# Incident: #17116 — getGatewayAccount deployed but "not a function"
#   at runtime (126 occurrences)
# Incident: #17950 — Base class defines NO tenantId support despite
#   implementations assuming it exists
EXISTENCE_PATTERNS=(
    "method is available"
    "function is available"
    "properly exported"
    "correctly exported"
    "correctly imported"
    "properly imported"
    "method exists"
    "function exists"
    "is exported from"
    "is imported from"
    "available at runtime"
    "available on the"
    "exists on the"
    "exposed by"
    "defined in the"
)

# ─── CAT 9: CORRECTNESS CLAIMS ───────────────────────────────
# Claim code "works" or is "correct" without test execution evidence.
# Incident: #15239 — 4/5 usages had ?. but the one without it crashed
# Incident: #16632 — ::text instead of ::uuid — type mismatch
# Incident: #18896 — undefined silently converts to "undefined" string
CORRECTNESS_PATTERNS=(
    "works correctly"
    "working correctly"
    "functions correctly"
    "behaves correctly"
    "handles correctly"
    "handles this correctly"
    "handles it correctly"
    "is correct"
    "are correct"
    "looks correct"
    "type is correct"
    "types are correct"
    "types match"
    "signature is correct"
    "parameters are correct"
    "correctly handles"
    "correctly processes"
    "correctly returns"
)

# ─── CAT 10: UNCITED COUNT CLAIMS ────────────────────────────
# State a specific count without listing each item as evidence.
# Incident: #17940 — "49 gaps" but many more existed
# Incident: #18947 — Should have listed each of the 9 methods
COUNT_PATTERNS=(
    "only .* callers"
    "only .* references"
    "only .* places"
    "only .* files"
    "only .* methods"
    "only .* usages"
    "only .* locations"
    "found .* callers"
    "found .* references"
)

# ─── CAT 11: SCOPE/AVAILABILITY CLAIMS ───────────────────────
# Claim variable/parameter is in scope without reading the function signature.
# Incident: #18599 — "tenantId available" but not visible in function
# Incident: #17575 — tenantId used in service calls but never declared
#   in the controller scope (42 undefined errors)
SCOPE_PATTERNS=(
    "already in scope"
    "available in scope"
    "in the function scope"
    "variable is available"
    "parameter is available"
    "accessible from"
    "accessible in"
    "already available"
    "already declared"
    "already defined"
    "visible in the"
)

# ─── CAT 12: ZERO/CLEAN STATE CLAIMS ─────────────────────────
# Claim zero issues or clean state without citing the check output.
# Incident: #17940 — "zero remaining gaps" was false
# Incident: #17116 — Log check would have shown 126 errors
ZERO_PATTERNS=(
    "zero gaps"
    "zero errors"
    "zero issues"
    "zero remaining"
    "zero failures"
    "no gaps remain"
    "no issues remain"
    "no errors remain"
    "clean bill"
    "clean state"
    "clean run"
    "all clear"
    "no warnings"
    "passes clean"
    "runs clean"
)

# ─── MATCHING ENGINE ─────────────────────────────────────────

FOUND=""
CATEGORY=""

# Helper: check patterns array against response
check_patterns() {
    local category="$1"
    shift
    local patterns=("$@")
    for PATTERN in "${patterns[@]}"; do
        if echo "$LOWER" | grep -qF "$PATTERN"; then
            FOUND="$PATTERN"
            CATEGORY="$category"
            return 0
        fi
    done
    return 1
}

# Helper: check regex patterns (for count claims with .*)
check_regex_patterns() {
    local category="$1"
    shift
    local patterns=("$@")
    for PATTERN in "${patterns[@]}"; do
        if echo "$LOWER" | grep -qE "$PATTERN"; then
            MATCH=$(echo "$LOWER" | grep -oE "$PATTERN" | head -1)
            FOUND="$MATCH"
            CATEGORY="$category"
            return 0
        fi
    done
    return 1
}

# Check in priority order (most critical first)
check_patterns "COMPLETENESS CLAIM" "${COMPLETENESS_PATTERNS[@]}" || \
check_patterns "PROPAGATION/THREADING CLAIM" "${PROPAGATION_PATTERNS[@]}" || \
check_patterns "NEGATIVE CLAIM" "${NEGATIVE_PATTERNS[@]}" || \
check_patterns "CORRECTNESS CLAIM" "${CORRECTNESS_PATTERNS[@]}" || \
check_patterns "UNSUBSTANTIATED FIX" "${FIX_PATTERNS[@]}" || \
check_patterns "DEPLOYMENT/RUNTIME CLAIM" "${DEPLOY_PATTERNS[@]}" || \
check_patterns "METHOD EXISTENCE CLAIM" "${EXISTENCE_PATTERNS[@]}" || \
check_patterns "SCOPE/AVAILABILITY CLAIM" "${SCOPE_PATTERNS[@]}" || \
check_patterns "ZERO/CLEAN STATE CLAIM" "${ZERO_PATTERNS[@]}" || \
check_patterns "BLANKET VERIFICATION" "${BLANKET_PATTERNS[@]}" || \
check_patterns "READINESS WITHOUT EVIDENCE" "${READINESS_PATTERNS[@]}" || \
check_regex_patterns "UNCITED COUNT CLAIM" "${COUNT_PATTERNS[@]}"

# ─── Skip if inside a markdown table, code block, or quote ───
# (The phrase might be describing what NOT to say, like in a rule doc)
if [[ -n "$FOUND" ]]; then
    LINE_WITH_MATCH=$(echo "$LOWER" | grep -F "$FOUND" | head -1)
    # Table row
    if echo "$LINE_WITH_MATCH" | grep -qE '^\|.*\|$'; then
        exit 0
    fi
    # Code block, comment, blockquote, bold (rule documentation)
    if echo "$LINE_WITH_MATCH" | grep -qE '^\s*(#|//|`|>|\*\*|-)'; then
        exit 0
    fi
    # Inside backtick-fenced code (``` blocks)
    # Count opening ``` before the match - if odd, we're inside a code block
    LINES_BEFORE=$(echo "$LOWER" | sed "/$FOUND/q" | sed '$d')
    FENCE_COUNT=$(echo "$LINES_BEFORE" | grep -c '```')
    if (( FENCE_COUNT % 2 == 1 )); then
        exit 0
    fi
fi

# ─── EMIT BLOCK ──────────────────────────────────────────────

if [[ -n "$FOUND" ]]; then
    DISPLAY=$(echo "$FOUND" | xargs)
    case "$CATEGORY" in
        "COMPLETENESS CLAIM")
            GUIDANCE="List EACH item individually with file:line citations. Replace '$DISPLAY' with a numbered list of specific items and their locations. Incident: #17940 claimed '49 gaps fixed, zero remaining' but 20+ more were found in email, location, and finance services."
            ;;
        "PROPAGATION/THREADING CLAIM")
            GUIDANCE="Trace the FULL call chain with file:line at each hop. Show: (1) parameter in caller signature, (2) passed at call site, (3) received in callee, (4) used in final query. Incident: #18946 — 9 methods 'received' tenantId but NONE passed it to sendTemplatedEmail. #18477 — callers passed tenantKey but function expected tenantId."
            ;;
        "NEGATIVE CLAIM")
            GUIDANCE="Cite the search command and its results. Show grep output that proves no other references exist, or list the references you found and explain why they're unaffected. Incident: #18946 — 'no other' gaps, but 9 internal calls were missed."
            ;;
        "CORRECTNESS CLAIM")
            GUIDANCE="Show test execution output or runtime evidence. 'Correct' requires proof: run the code path, show the output, verify the result matches expectations. Incident: #15239 — 4/5 usages had ?. but the one without it crashed in production. #16632 — ::text instead of ::uuid type mismatch."
            ;;
        "UNSUBSTANTIATED FIX")
            GUIDANCE="Show execution evidence: error reproduction before fix, successful execution after fix, or test output proving the fix. Incident: #17589 — 'fixed' tenantId but added it twice, creating duplicate declaration error."
            ;;
        "DEPLOYMENT/RUNTIME CLAIM")
            GUIDANCE="Cite specific runtime evidence: pm2 logs showing startup, curl/API response, or log tail showing no errors. Incident: #17116 — 'deployed successfully' but production had 126 'not a function' errors that graceful fallback masked."
            ;;
        "METHOD EXISTENCE CLAIM")
            GUIDANCE="Cite grep output showing the method/function in the source file's exports. Show the import statement in the consumer. Incident: #17116 — getGatewayAccount was 'deployed' but 'is not a function' at runtime (126 occurrences). #17950 — base class had ZERO tenantId support despite implementations assuming it."
            ;;
        "SCOPE/AVAILABILITY CLAIM")
            GUIDANCE="Read and cite the function signature showing the parameter/variable declaration. Show file:line of the declaration. Incident: #18599 — 'tenantId available' but not visible in function scope. #17575 — 42 undefined variable errors because tenantId was used but never declared in controller scope."
            ;;
        "ZERO/CLEAN STATE CLAIM")
            GUIDANCE="Show the command output that produced zero. Cite: the command run, its full output, and the timestamp. Incident: #17940 — 'zero remaining gaps' was factually wrong, 20+ more existed."
            ;;
        "BLANKET VERIFICATION")
            GUIDANCE="List each verification individually with its evidence. Replace blanket claim with specific checks and their results."
            ;;
        "READINESS WITHOUT EVIDENCE")
            GUIDANCE="Show the deploy/ship checklist with evidence for each gate item. Cite test results, log output, and verification commands."
            ;;
        "UNCITED COUNT CLAIM")
            GUIDANCE="List EACH item counted, with file:line for every one. A count without a list is unverified. Incident: #17940 — claimed specific count of gaps but missed entire categories of omissions."
            ;;
    esac

    cat <<HOOKEOF
{"decision":"block","reason":"CITATION GUARD [$CATEGORY]: \"$DISPLAY\". $GUIDANCE REWRITE the section with individually-cited evidence or say \"I haven't verified this yet\". Do NOT just remove the phrase — replace the ENTIRE claim with evidence-backed specifics."}
HOOKEOF
    exit 0
fi

exit 0
