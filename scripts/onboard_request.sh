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
export CLIENT_ALIASES="$client_aliases"

if [ "$channels_json" != "null" ] && [ "$channels_json" != "[]" ]; then
  export CHANNELS_JSON="$channels_json"
fi

if [ "$workflows_json" != "null" ] && [ "$workflows_json" != "[]" ]; then
  export WORKFLOWS_JSON="$workflows_json"
fi

if [ "$agents_json" != "null" ] && [ "$agents_json" != "[]" ]; then
  export AGENTS_JSON="$agents_json"
fi

set +e
./scripts/onboard.sh "$profile"
status=$?
set -e

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

if [ "$status" -ne 0 ]; then
  /root/VizionAI/WORKSPACES/vizion-onboarding/scripts/learning_signal.sh \"onboarding_${request_id:-manual}_failed\" \"onboarding\" \"Onboarding failed for ${client_name}\" \"high\" \"{\\\"profile\\\":\\\"${profile}\\\"}\" || true
  if [ -x /root/VizionAI/WORKSPACES/vizion-infra/scripts/learning_ingest.sh ]; then
    /root/VizionAI/WORKSPACES/vizion-infra/scripts/learning_ingest.sh \
      --fingerprint "onboarding:${request_id:-manual}:failed" \
      --source-system onboarding \
      --summary "Onboarding failed for ${client_name}" \
      --payload '{}' \
      --severity high \
      --workspace onboarding \
      --entry-type problem \
      --tags "onboarding,failed" \
      --promote || true
  fi
  exit "$status"
fi

/root/VizionAI/WORKSPACES/vizion-onboarding/scripts/learning_signal.sh \"onboarding_${request_id:-manual}_completed\" \"onboarding\" \"Onboarding completed for ${client_name}\" \"medium\" \"{\\\"profile\\\":\\\"${profile}\\\"}\" || true

if [ -x /root/VizionAI/WORKSPACES/vizion-infra/scripts/learning_ingest.sh ]; then
  /root/VizionAI/WORKSPACES/vizion-infra/scripts/learning_ingest.sh \
    --fingerprint "onboarding:${request_id:-manual}:completed" \
    --source-system onboarding \
    --summary "Onboarding completed for ${client_name}" \
    --payload '{}' \
    --severity low \
    --workspace onboarding \
    --entry-type state \
    --tags "onboarding,completed" \
    --promote || true
fi

if [ "$workflows_json" != "null" ] && [ "$workflows_json" != "[]" ]; then
  /root/VizionAI/WORKSPACES/vizion-platform/scripts/n8n_import_workflows.sh || true
fi

if [ "$profile" = "full_stack" ] || [ "$workspace_mode" = "full" ]; then
  /root/VizionAI/WORKSPACES/vizion-infra/scripts/docops_run.sh || true
fi

if [ -n "$request_id" ] && [ -n "$state_file" ]; then
  cp "$request_file" "$state_file"
fi

printf 'onboard_request: completed profile %s for %s\n' "$profile" "$client_name"
