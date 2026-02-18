#!/usr/bin/env bash
# module_postflight.sh — Auto-ingest results into learning tables, emit alert event, optionally generate doc snapshot
set -euo pipefail

CLIENT_KEY=${CLIENT_KEY:-}
CLIENT_NAME=${CLIENT_NAME:-}
PROFILE=${PROFILE:-default}
REQUEST_ID=${REQUEST_ID:-}
ONBOARD_STATUS=${ONBOARD_STATUS:-completed}

_payload() {
  printf '{"profile":"%s","client":"%s","request_id":"%s","status":"%s"}' \
    "$PROFILE" "$CLIENT_KEY" "${REQUEST_ID:-}" "$ONBOARD_STATUS"
}

# 1) Learning signal — ingest onboarding outcome
fingerprint="onboarding:${REQUEST_ID:-${CLIENT_KEY}}:${ONBOARD_STATUS}"
/root/VizionAI/WORKSPACES/vizion-onboarding/scripts/learning_signal.sh \
  "$fingerprint" "onboarding" \
  "Onboarding ${ONBOARD_STATUS} for ${CLIENT_NAME:-${CLIENT_KEY}}" \
  "$([ "$ONBOARD_STATUS" = "completed" ] && echo medium || echo high)" \
  "$(_payload)" || true

# 2) vizion-infra learning_ingest (if available) — promotes to knowledge base
if [ -x /root/VizionAI/WORKSPACES/vizion-infra/scripts/learning_ingest.sh ]; then
  entry_type="$([ "$ONBOARD_STATUS" = "completed" ] && echo state || echo problem)"
  /root/VizionAI/WORKSPACES/vizion-infra/scripts/learning_ingest.sh \
    --fingerprint "onboarding:${REQUEST_ID:-${CLIENT_KEY}}:${ONBOARD_STATUS}" \
    --source-system onboarding \
    --summary "Onboarding ${ONBOARD_STATUS} for ${CLIENT_NAME:-${CLIENT_KEY}} (profile: ${PROFILE})" \
    --payload "$(_payload)" \
    --severity "$([ "$ONBOARD_STATUS" = "completed" ] && echo low || echo high)" \
    --workspace onboarding \
    --entry-type "$entry_type" \
    --tags "onboarding,${ONBOARD_STATUS},${PROFILE}" \
    --promote || true
fi

# 3) Alert event emission (vizion-alert-reporting)
if [ -x /root/VizionAI/WORKSPACES/vizion-alert-reporting/scripts/emit_event.sh ]; then
  /root/VizionAI/WORKSPACES/vizion-alert-reporting/scripts/emit_event.sh \
    --type "onboarding.${ONBOARD_STATUS}" \
    --source onboarding \
    --client "${CLIENT_KEY}" \
    --payload "$(_payload)" || true
fi

# 4) Doc snapshot — runs only for full_stack profile or if workspace=full
if [ "$PROFILE" = "full_stack" ] || [ "${WORKSPACE_MODE:-none}" = "full" ]; then
  echo "module_postflight: triggering doc snapshot for full_stack profile"
  if [ -x /root/VizionAI/WORKSPACES/vizion-infra/scripts/docops_run.sh ]; then
    /root/VizionAI/WORKSPACES/vizion-infra/scripts/docops_run.sh || true
  fi
fi

echo "module_postflight: completed (${ONBOARD_STATUS})"
# Write sentinel so onboard_request.sh fallback knows postflight already ran
[ -n "${_POSTFLIGHT_SENTINEL:-}" ] && touch "${_POSTFLIGHT_SENTINEL}" 2>/dev/null || true
