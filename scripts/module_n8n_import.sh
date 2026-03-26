#!/usr/bin/env bash
# module_n8n_import.sh — Import or update n8n workflows from WORKFLOWS_JSON or workflows/n8n/*.json
set -euo pipefail

N8N_URL=${N8N_URL:-http://127.0.0.1:32769}
N8N_API_KEY=${N8N_API_KEY:-}
WORKFLOWS_JSON=${WORKFLOWS_JSON:-}
WORKFLOWS_DIR=${WORKFLOWS_DIR:-workflows/n8n}
CLIENT_KEY=${CLIENT_KEY:-}
INFISICAL_DOMAIN=${INFISICAL_DOMAIN:-${INFISICAL_API_URL:-https://app.infisical.com/api}}
INFISICAL_ENV=${INFISICAL_ENV:-prod}
N8N_INFISICAL_PROJECT_ID=${N8N_INFISICAL_PROJECT_ID:-${INFISICAL_PROJECT_INFRA_ID:-918f6641-7111-4c80-b08a-46321c6b81ab}}
N8N_INFISICAL_PATH=${N8N_INFISICAL_PATH:-/platform/n8n}

if ! command -v curl >/dev/null 2>&1; then
  echo "module_n8n_import: curl is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "module_n8n_import: jq is required" >&2
  exit 1
fi

# Verify n8n is reachable — check root URL (always 200), not API (needs auth)
n8n_http=$(curl -o /dev/null -sw '%{http_code}' "${N8N_URL}/" 2>/dev/null)
if [ "$n8n_http" = "000" ]; then
  echo "WARNING: n8n not reachable at ${N8N_URL}" >&2
  /root/VizionAI/WORKSPACES/vizion-onboarding/scripts/learning_signal.sh \
    "onboarding_n8n_unreachable" "onboarding_n8n" \
    "n8n not reachable at ${N8N_URL}" "high" \
    '{"module":"n8n_import"}' || true
  if [ "${STRICT_MODE:-0}" = "1" ]; then exit 1; fi
  exit 0
fi
echo "module_n8n_import: n8n reachable at ${N8N_URL} (HTTP ${n8n_http})"

login_infisical() {
  local client_id client_secret token
  client_id="${INFISICAL_CLIENT_ID:-${INFISICAL_RUNTIME_CLIENT_ID:-${INFISICAL_PROVISIONER_CLIENT_ID:-${INFISICAL_ADMIN_CLIENT_ID:-}}}}"
  client_secret="${INFISICAL_CLIENT_SECRET:-${INFISICAL_RUNTIME_CLIENT_SECRET:-${INFISICAL_PROVISIONER_CLIENT_SECRET:-${INFISICAL_ADMIN_CLIENT_SECRET:-}}}}"

  if [ -z "$client_id" ] || [ -z "$client_secret" ]; then
    return 1
  fi

  token="$(infisical login --method=universal-auth \
    --client-id="$client_id" \
    --client-secret="$client_secret" \
    --domain="$INFISICAL_DOMAIN" \
    --plain 2>/dev/null | tail -n1 || true)"

  if [ -z "$token" ]; then
    return 1
  fi

  INFISICAL_TOKEN="$token"
  export INFISICAL_TOKEN
}

resolve_n8n_api_key() {
  if [ -n "${N8N_API_KEY:-}" ]; then
    return 0
  fi

  if ! command -v infisical >/dev/null 2>&1; then
    return 1
  fi

  if [ -z "${INFISICAL_TOKEN:-}" ]; then
    login_infisical || return 1
  fi

  N8N_API_KEY="$(infisical secrets get N8N_API_KEY \
    --projectId="$N8N_INFISICAL_PROJECT_ID" \
    --env="$INFISICAL_ENV" \
    --path="$N8N_INFISICAL_PATH" \
    --token="$INFISICAL_TOKEN" \
    --plain 2>/dev/null || true)"

  if [ -z "${N8N_API_KEY:-}" ]; then
    return 1
  fi

  export N8N_API_KEY
  echo "module_n8n_import: loaded N8N_API_KEY from Infisical ${N8N_INFISICAL_PATH} (project ${N8N_INFISICAL_PROJECT_ID})"
}

resolve_n8n_api_key || {
  echo "module_n8n_import: N8N_API_KEY missing and Infisical lookup failed" >&2
  if [ "${STRICT_MODE:-0}" = "1" ]; then exit 1; fi
}

import_workflow() {
  local wf_file="$1"
  local wf_payload
  local wf_name
  local existing_id
  local existing_description
  wf_name=$(jq -r '.name // .id // "unknown"' "$wf_file" 2>/dev/null || echo "unknown")
  # Short context used only when neither the source file nor the existing
  # workflow already has a description.
  default_desc=$(case "$wf_name" in
    *staging*|*staging_1d*) echo "Daily CRM staging sync from analytics into VizionAI CRM." ;;
    *review*|*review_1h*) echo "Hourly review sweep for CRM trading candidates." ;;
    *promotion*|*promotion_4h*) echo "Every 4 hours, promote approved CRM trading candidates into VizionAI Library." ;;
    *) echo "Auto-published workflow imported by onboarding." ;;
  esac)

  # Check if workflow already exists (by name match)
  existing_id=$(curl -fsS "${N8N_URL}/api/v1/workflows?limit=100" \
    ${N8N_API_KEY:+-H "X-N8N-API-KEY: ${N8N_API_KEY}"} 2>/dev/null | \
    jq -r --arg name "$wf_name" '.data[] | select(.name == $name) | .id' 2>/dev/null | head -1 || echo "")

  if [ -n "$existing_id" ]; then
    existing_description=$(curl -fsS "${N8N_URL}/api/v1/workflows/${existing_id}" \
      ${N8N_API_KEY:+-H "X-N8N-API-KEY: ${N8N_API_KEY}"} 2>/dev/null | \
      jq -r '.data.description // .description // empty' 2>/dev/null || echo "")
  fi

  wf_payload=$(jq -c \
    --arg desc "$default_desc" \
    --arg existing_desc "${existing_description:-}" '
      def nonempty(s): (s // "") | tostring | gsub("^\\s+|\\s+$"; "");
      {
        name,
        nodes,
        connections,
        description: (
          if nonempty($existing_desc) != "" then $existing_desc
          elif nonempty(.description) != "" then .description
          else $desc
          end
        ),
        settings: ((.settings // {}) | .availableInMCP = true),
        staticData,
        pinData,
        tags
      }
      | with_entries(select(.value != null))
    ' "$wf_file")

  if [ -n "$existing_id" ]; then
    # Update existing workflow
    result=$(curl -fsS -X PUT "${N8N_URL}/api/v1/workflows/${existing_id}" \
      -H "Content-Type: application/json" \
      ${N8N_API_KEY:+-H "X-N8N-API-KEY: ${N8N_API_KEY}"} \
      -d "$wf_payload")
    echo "module_n8n_import: updated workflow '${wf_name}' (id: ${existing_id})"
    workflow_id="$existing_id"
  else
    # Create new workflow
    result=$(curl -fsS -X POST "${N8N_URL}/api/v1/workflows" \
      -H "Content-Type: application/json" \
      ${N8N_API_KEY:+-H "X-N8N-API-KEY: ${N8N_API_KEY}"} \
      -d "$wf_payload")
    new_id=$(printf '%s' "${result}" | jq -r '.id // "unknown"' 2>/dev/null || echo "unknown")
    echo "module_n8n_import: created workflow '${wf_name}' (id: ${new_id})"
    workflow_id="$new_id"
  fi

  if [ -n "${workflow_id:-}" ] && [ "$workflow_id" != "unknown" ]; then
    curl -fsS -X POST "${N8N_URL}/api/v1/workflows/${workflow_id}/activate" \
      -H "Content-Type: application/json" \
      ${N8N_API_KEY:+-H "X-N8N-API-KEY: ${N8N_API_KEY}"} \
      >/dev/null
    echo "module_n8n_import: activated workflow '${wf_name}' (id: ${workflow_id})"
  fi
}

import_count=0

# Path 1: WORKFLOWS_JSON from onboarding request (array of {file, name} or file paths)
if [ -n "$WORKFLOWS_JSON" ] && [ "$WORKFLOWS_JSON" != "[]" ] && [ "$WORKFLOWS_JSON" != "null" ]; then
  while IFS= read -r entry; do
    wf_file=$(printf '%s' "$entry" | jq -r '.file // .path // empty' 2>/dev/null || true)
    if [ -z "$wf_file" ]; then
      # treat entry as a plain path string
      wf_file=$(printf '%s' "$entry" | jq -r '. // empty' 2>/dev/null || true)
    fi
    [ -z "$wf_file" ] && continue
    if [ ! -f "$wf_file" ]; then
      # Try relative to repo workflows dir
      candidate="${WORKFLOWS_DIR}/${wf_file}"
      [ -f "$candidate" ] && wf_file="$candidate" || { echo "WARNING: workflow file not found: $wf_file" >&2; continue; }
    fi
    import_workflow "$wf_file"
    import_count=$((import_count + 1))
  done < <(printf '%s' "$WORKFLOWS_JSON" | jq -c '.[]' 2>/dev/null)
fi

# Path 2: All files in workflows/n8n/ directory (when no explicit list given)
if [ "$import_count" -eq 0 ] && [ -d "$WORKFLOWS_DIR" ]; then
  for wf in "${WORKFLOWS_DIR}"/*.json; do
    [ -f "$wf" ] || continue
    import_workflow "$wf"
    import_count=$((import_count + 1))
  done
fi

if [ "$import_count" -eq 0 ]; then
  echo "module_n8n_import: no workflows to import"
else
  echo "module_n8n_import: imported/updated ${import_count} workflow(s)"
fi
