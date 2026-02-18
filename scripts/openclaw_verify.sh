#!/usr/bin/env bash
set -euo pipefail

STRICT_MODE=${STRICT_MODE:-0}
OPENCLAW_CONFIG=${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}
OPENCLAW_CONTAINER=${OPENCLAW_CONTAINER:-openclaw-xbkt-openclaw-1}
CHANNELS_JSON=${CHANNELS_JSON:-}
OPENCLAW_URL=${OPENCLAW_URL:-http://127.0.0.1:48950/health}
OPENCLAW_UI_URL=${OPENCLAW_UI_URL:-http://127.0.0.1:18789}
SKILLS_DIR=${OPENCLAW_SKILLS_DIR:-/docker/openclaw-xbkt/data/skills}
REQUIRED_SKILLS=${OPENCLAW_REQUIRED_SKILLS:-vizion-platform,vizion-onboarding,vizion-infra,vizion-security}

warn() {
  local msg="$*"
  echo "WARNING: ${msg}" >&2
  if [ "${LEARN_LOG_WARNINGS:-1}" = "1" ]; then
    fp=$(printf '%s' "${msg}" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' '_' | cut -c1-80)
    /root/VizionAI/WORKSPACES/vizion-onboarding/scripts/learning_signal.sh "onboarding_preflight_${fp}" "onboarding_preflight" "${msg}" "high" '{"module":"openclaw_verify"}' || true
  fi
  if [ "$STRICT_MODE" = "1" ]; then
    exit 1
  fi
}

if [ ! -f "$OPENCLAW_CONFIG" ]; then
  if command -v docker >/dev/null 2>&1; then
    tmp_cfg="/tmp/openclaw.json"
    if docker exec "$OPENCLAW_CONTAINER" sh -lc "cat /data/.openclaw/openclaw.json" > "$tmp_cfg" 2>/dev/null; then
      OPENCLAW_CONFIG="$tmp_cfg"
    else
      warn "OpenClaw config not found at $OPENCLAW_CONFIG"
      exit 0
    fi
  else
    warn "OpenClaw config not found at $OPENCLAW_CONFIG"
    exit 0
  fi
fi

if command -v curl >/dev/null 2>&1; then
  if ! curl -fsS "$OPENCLAW_URL" >/dev/null 2>&1; then
    warn "OpenClaw health endpoint not reachable at $OPENCLAW_URL"
  else
    echo "openclaw_verify: health endpoint OK ($OPENCLAW_URL)"
  fi
  # Check Control UI port (18789) - expects HTTP 200
  # Note: curl -w '%{http_code}' already writes "000" on connect failure; don't add || echo
  ui_status=$(curl -o /dev/null -sw '%{http_code}' "$OPENCLAW_UI_URL" 2>/dev/null)
  if [ "$ui_status" != "200" ]; then
    warn "OpenClaw Control UI not reachable at $OPENCLAW_UI_URL (got: $ui_status). Check gateway.controlUi.allowInsecureAuth and container port mapping."
  else
    echo "openclaw_verify: Control UI OK ($OPENCLAW_UI_URL)"
  fi
else
  warn "curl not available; cannot verify OpenClaw health"
fi

if [ ! -d "$SKILLS_DIR" ]; then
  warn "OpenClaw skills directory not found at $SKILLS_DIR"
else
  IFS=',' read -r -a skills <<< "$REQUIRED_SKILLS"
  for s in "${skills[@]}"; do
    if [ ! -d "$SKILLS_DIR/$s" ]; then
      warn "Required skill missing: $s"
    fi
  done
fi

if ! command -v jq >/dev/null 2>&1; then
  warn "jq not available; cannot validate OpenClaw config"
  exit 0
fi

if ! jq -e . >/dev/null 2>&1 < "$OPENCLAW_CONFIG"; then
  warn "OpenClaw config is not valid JSON"
  exit 0
fi

if [ -z "$CHANNELS_JSON" ]; then
  echo "openclaw_verify: no CHANNELS_JSON provided; skipping channel checks"
  exit 0
fi

channel_kinds=$(printf '%s' "$CHANNELS_JSON" | jq -r '.[].kind' 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort -u)
if [ -z "$channel_kinds" ]; then
  echo "openclaw_verify: no channel kinds detected"
  exit 0
fi

for kind in $channel_kinds; do
  # enabled check: OpenClaw >=2026.2.9 uses plugins.entries.<kind>.enabled, NOT channels.<kind>.enabled
  plugin_enabled=$(jq -r --arg k "$kind" '.plugins.entries[$k].enabled // empty' "$OPENCLAW_CONFIG")
  dm_policy=$(jq -r --arg k "$kind" '.channels[$k].dmPolicy // empty' "$OPENCLAW_CONFIG")
  allow_count=$(jq -r --arg k "$kind" '.channels[$k].allowFrom | length' "$OPENCLAW_CONFIG" 2>/dev/null || echo 0)

  if [ "$plugin_enabled" != "true" ]; then
    warn "OpenClaw plugin '${kind}' is not enabled in plugins.entries (plugins.entries.${kind}.enabled != true)"
  fi

  if [ -n "$dm_policy" ] && [ "$dm_policy" != "allowlist" ]; then
    warn "OpenClaw channel '$kind' dmPolicy is '${dm_policy}' — recommend 'allowlist'"
  fi

  if [ "$allow_count" -eq 0 ] && [ "$dm_policy" = "allowlist" ]; then
    warn "OpenClaw channel '$kind' dmPolicy=allowlist but allowFrom is empty — no senders will be accepted"
  fi

done

echo "openclaw_verify: completed"
