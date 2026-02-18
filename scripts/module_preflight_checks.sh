#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "WARNING: jq is required for onboarding modules" >&2
  if [ "${STRICT_MODE:-0}" = "1" ]; then
    exit 1
  fi
fi

if ! command -v infisical >/dev/null 2>&1; then
  echo "WARNING: infisical CLI not found; secrets will not be written" >&2
  if [ "${STRICT_MODE:-0}" = "1" ]; then
    exit 1
  fi
fi

N8N_URL=${N8N_URL:-http://127.0.0.1:32769}

/root/VizionAI/WORKSPACES/vizion-onboarding/scripts/openclaw_verify.sh || true

if command -v curl >/dev/null 2>&1; then
  # Use HTTP code check: 000 = connection refused (truly down), 5xx = up but starting
  n8n_code=$(curl -o /dev/null -sw '%{http_code}' "$N8N_URL/" 2>/dev/null)
  if [ "$n8n_code" = "000" ]; then
    echo "WARNING: n8n not reachable at $N8N_URL (connection refused)" >&2
    /root/VizionAI/WORKSPACES/vizion-onboarding/scripts/learning_signal.sh \
      "onboarding_preflight_n8n_unreachable" "onboarding_preflight" \
      "n8n not reachable at $N8N_URL" "high" '{"module":"n8n_verify"}' || true
    if [ "${STRICT_MODE:-0}" = "1" ]; then
      exit 1
    fi
  else
    echo "preflight: n8n reachable at $N8N_URL (HTTP ${n8n_code})"
  fi
fi
