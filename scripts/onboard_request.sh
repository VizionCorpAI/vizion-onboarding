#!/usr/bin/env bash
set -euo pipefail

request_file=${1:-}
if [ -z "$request_file" ] || [ ! -f "$request_file" ]; then
  echo "Usage: $0 <request.json>" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "onboard_request: jq is required" >&2
  exit 1
fi

request_id=$(jq -r '.requestId // empty' "$request_file")
profile=$(jq -r '.profile // "default"' "$request_file")
client_name=$(jq -r '.client.name // empty' "$request_file")
client_key=$(jq -r '.client.key // empty' "$request_file")
client_first_name=$(jq -r '.client.firstName // empty' "$request_file")
client_last_name=$(jq -r '.client.lastName // empty' "$request_file")
client_email=$(jq -r '.client.email // empty' "$request_file")
client_phone=$(jq -r '.client.phone // empty' "$request_file")
business_type=$(jq -r '.client.businessType // empty' "$request_file")
business_description=$(jq -r '.client.businessDescription // empty' "$request_file")
client_ips_json=$(jq -c '.client.clientIps // []' "$request_file")
client_aliases=$(jq -c '.client.aliases // []' "$request_file")
channels_json=$(jq -c '.channels // []' "$request_file")
workflows_json=$(jq -c '.workflows // []' "$request_file")
workspace_mode=$(jq -r '.workspace // "none"' "$request_file")
payload_json=$(jq -c '.' "$request_file")
agents_json=$(jq -c '.agents // []' "$request_file")

if [ -z "$client_name" ]; then
  echo "onboard_request: client.name is required" >&2
  exit 1
fi

state_dir="state/requests"
mkdir -p "$state_dir"
state_file=""
if [ -n "$request_id" ]; then
  state_file="$state_dir/${request_id}.json"
fi

db_idempotent=0
if [ -n "$request_id" ]; then
  db_check=$(/root/VizionAI/WORKSPACES/vizion-onboarding/scripts/psql_exec.sh -Atc "select status from onboard_request where request_id='${request_id}'" 2>/dev/null || true)
  if [ -n "$db_check" ]; then
    echo "onboard_request: requestId already processed in DB ($request_id). Skipping." >&2
    exit 0
  fi
  /root/VizionAI/WORKSPACES/vizion-onboarding/scripts/psql_exec.sh -v ON_ERROR_STOP=1 \
    -v request_id="$request_id" \
    -v client_key="$client_key" \
    -v payload="$payload_json" \
    -c "insert into onboard_request (request_id, client_key, status, payload) values (:'request_id', :'client_key', 'received', (:'payload')::jsonb);" \
    >/dev/null 2>&1 || db_idempotent=1
fi

if [ -n "$request_id" ] && [ "$db_idempotent" -eq 1 ]; then
  if [ -f "$state_file" ]; then
    echo "onboard_request: requestId already processed in local state ($request_id). Skipping." >&2
    exit 0
  fi
fi

export CLIENT_NAME="$client_name"
export CLIENT_KEY="$client_key"
export CLIENT_FIRST_NAME="$client_first_name"
export CLIENT_LAST_NAME="$client_last_name"
export CLIENT_EMAIL="$client_email"
export CLIENT_PHONE="$client_phone"
export BUSINESS_TYPE="$business_type"
export BUSINESS_DESCRIPTION="$business_description"
export CLIENT_IPS=$(printf '%s' "$client_ips_json" | jq -r 'join(",")' 2>/dev/null || echo "")
export CLIENT_ALIASES="$client_aliases"
export PROFILE="$profile"
export REQUEST_ID="${request_id:-}"
export WORKSPACE_MODE="$workspace_mode"

if [ "$channels_json" != "null" ] && [ "$channels_json" != "[]" ]; then
  export CHANNELS_JSON="$channels_json"
fi

if [ "$workflows_json" != "null" ] && [ "$workflows_json" != "[]" ]; then
  export WORKFLOWS_JSON="$workflows_json"
fi

if [ "$agents_json" != "null" ] && [ "$agents_json" != "[]" ]; then
  export AGENTS_JSON="$agents_json"
fi

# Run the profile modules (includes n8n_import and postflight if wired in profile)
_postflight_sentinel="/tmp/onboard_postflight_${request_id:-$$}"
export _POSTFLIGHT_SENTINEL="$_postflight_sentinel"
rm -f "$_postflight_sentinel"

# For smart profiles, run ai_expand first to generate CHANNELS_JSON before running rest of profile
if [ "$profile" = "smart_full" ] && [ -n "$request_id" ]; then
  # Run ai_expand module standalone
  ./scripts/module_ai_expand.sh || true

  # Source exported variables if available
  if [ -f "state/exports/${request_id}.sh" ]; then
    source "state/exports/${request_id}.sh"
  fi
fi

set +e
./scripts/onboard.sh "$profile"
status=$?
set -e

# Update DB status
if [ -n "$request_id" ]; then
  if [ "$status" -eq 0 ]; then
    status_label="completed"
  else
    status_label="failed"
  fi
  /root/VizionAI/WORKSPACES/vizion-onboarding/scripts/psql_exec.sh -v ON_ERROR_STOP=1 -c \
    "update onboard_request set status='${status_label}', updated_at=now() where request_id='${request_id}';" \
    >/dev/null 2>&1 || true
fi

# Fallback postflight if not in profile (e.g. legacy default profile)
# Sentinel file written by module_postflight.sh prevents double-run
if [ ! -f "${_postflight_sentinel}" ]; then
  export ONBOARD_STATUS="$([ "$status" -eq 0 ] && echo completed || echo failed)"
  /root/VizionAI/WORKSPACES/vizion-onboarding/scripts/module_postflight.sh || true
fi
rm -f "${_postflight_sentinel}" 2>/dev/null || true

if [ "$status" -ne 0 ]; then
  exit "$status"
fi

# Save request state
if [ -n "$request_id" ] && [ -n "$state_file" ]; then
  cp "$request_file" "$state_file"
fi

printf 'onboard_request: completed profile %s for %s\n' "$profile" "$client_name"
