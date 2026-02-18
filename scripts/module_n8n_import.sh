#!/usr/bin/env bash
# module_n8n_import.sh — Import or update n8n workflows from WORKFLOWS_JSON or workflows/n8n/*.json
set -euo pipefail

N8N_URL=${N8N_URL:-http://127.0.0.1:32769}
N8N_API_KEY=${N8N_API_KEY:-}
WORKFLOWS_JSON=${WORKFLOWS_JSON:-}
WORKFLOWS_DIR=${WORKFLOWS_DIR:-workflows/n8n}
CLIENT_KEY=${CLIENT_KEY:-}

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

import_workflow() {
  local wf_file="$1"
  local wf_name
  wf_name=$(jq -r '.name // .id // "unknown"' "$wf_file" 2>/dev/null || echo "unknown")

  # Check if workflow already exists (by name match)
  local existing_id
  existing_id=$(curl -fsS "${N8N_URL}/api/v1/workflows?limit=100" \
    ${N8N_API_KEY:+-H "X-N8N-API-KEY: ${N8N_API_KEY}"} 2>/dev/null | \
    jq -r --arg name "$wf_name" '.data[] | select(.name == $name) | .id' 2>/dev/null | head -1 || echo "")

  if [ -n "$existing_id" ]; then
    # Update existing workflow
    result=$(curl -fsS -X PUT "${N8N_URL}/api/v1/workflows/${existing_id}" \
      -H "Content-Type: application/json" \
      ${N8N_API_KEY:+-H "X-N8N-API-KEY: ${N8N_API_KEY}"} \
      -d @"$wf_file" 2>&1) || true
    echo "module_n8n_import: updated workflow '${wf_name}' (id: ${existing_id})"
  else
    # Create new workflow
    result=$(curl -fsS -X POST "${N8N_URL}/api/v1/workflows" \
      -H "Content-Type: application/json" \
      ${N8N_API_KEY:+-H "X-N8N-API-KEY: ${N8N_API_KEY}"} \
      -d @"$wf_file" 2>&1) || true
    new_id=$(printf '%s' "${result}" | jq -r '.id // "unknown"' 2>/dev/null || echo "unknown")
    echo "module_n8n_import: created workflow '${wf_name}' (id: ${new_id})"
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
