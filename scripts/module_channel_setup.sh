#!/usr/bin/env bash
set -euo pipefail

state_dir="state/clients"
mkdir -p "$state_dir"

if ! command -v jq >/dev/null 2>&1; then
  echo "module_channel_setup: jq is required" >&2
  exit 1
fi

client_name="${CLIENT_NAME:-}"
client_key="${CLIENT_KEY:-}"
client_aliases="${CLIENT_ALIASES:-[]}"
channels_json="${CHANNELS_JSON:-}"

if [ -z "$client_name" ]; then
  echo "module_channel_setup: CLIENT_NAME is required" >&2
  exit 1
fi

if [ -z "$client_key" ]; then
  client_key=$(printf "%s" "$client_name" | tr '[:lower:]' '[:upper:]' | tr -c '[:alnum:]' '_')
fi

infisical_project="${INFISICAL_PROJECT:-vizion-infrastructure-fu5-p}"
infisical_env="${INFISICAL_ENV:-prod}"
infisical_path="${INFISICAL_PATH:-/clients/${client_key}}"

# Build channels list from legacy env vars if CHANNELS_JSON is not set.
if [ -z "$channels_json" ]; then
  whatsapp_number="${WHATSAPP_NUMBER:-}"
  telegram_number="${TELEGRAM_NUMBER:-$whatsapp_number}"

  if [ -z "$whatsapp_number" ]; then
    echo "module_channel_setup: WHATSAPP_NUMBER or CHANNELS_JSON is required" >&2
    exit 1
  fi

  channels_json=$(jq -c -n \
    --arg w "$whatsapp_number" \
    --arg t "$telegram_number" \
    '[
      {domain:"SOCIAL", kind:"WHATSAPP", identifier:"PRIMARY_PHONE", value:$w},
      {domain:"SOCIAL", kind:"TELEGRAM", identifier:"PRIMARY_PHONE", value:$t}
    ]')
fi

# Normalize channels
channels_json=$(printf '%s' "$channels_json" | jq -c '.[] | {domain:(.domain|ascii_upcase), kind:(.kind|ascii_upcase), identifier:(.identifier|ascii_upcase), value:(.value // "") }' | jq -cs '.')

if [ -z "$channels_json" ] || [ "$channels_json" = "null" ]; then
  echo "module_channel_setup: CHANNELS_JSON is invalid" >&2
  exit 1
fi

set_secret() {
  local key="$1"
  local value="$2"
  if [ -z "$value" ]; then
    return 0
  fi
  if command -v infisical >/dev/null 2>&1; then
    if [ -z "${INFISICAL_TOKEN:-}" ]; then
      echo "infisical: INFISICAL_TOKEN not set; skipping $key" >&2
      return 0
    fi
    infisical secrets set --projectSlug="$infisical_project" --env="$infisical_env" --path="$infisical_path" "$key=$value" >/dev/null
    echo "infisical: set $key"
  else
    echo "infisical: CLI missing; skipping $key" >&2
  fi
}

index_map=$(printf '%s' "$channels_json" | jq -c --arg ck "$client_key" 'reduce .[] as $c ({}; .[$c.kind][$c.identifier] = ("CLIENT_" + $ck + "__" + $c.domain + "__" + $c.kind + "__" + $c.identifier))')

# Write secrets and build state catalog (no secret values stored)
state_file="$state_dir/${client_key}.json"
updated="$(date -u +%FT%TZ)"

catalog=$(printf '%s' "$channels_json" | jq -c --arg ck "$client_key" --arg cn "$client_name" --arg updated "$updated" --arg idx "$index_map" --argjson aliases "$client_aliases" '
  {
    client_key: $ck,
    client_name: $cn,
    aliases: ($aliases // []),
    updated: $updated,
    channels: [
      .[] | {
        domain: .domain,
        kind: .kind,
        identifier: .identifier,
        secret_key: ("CLIENT_" + $ck + "__" + .domain + "__" + .kind + "__" + .identifier),
        has_value: ((.value // "") != "")
      }
    ],
    index_secret_key: ("CLIENT_" + $ck + "__SOCIAL__CHANNELS__INDEX_JSON"),
    index_map: ($idx | fromjson)
  }
')

printf '%s' "$catalog" > "$state_file"

# Apply secrets to Infisical
printf '%s' "$channels_json" | jq -c '.[]' | while IFS= read -r row; do
  key=$(printf '%s' "$row" | jq -r --arg ck "$client_key" '"CLIENT_" + $ck + "__" + .domain + "__" + .kind + "__" + .identifier')
  value=$(printf '%s' "$row" | jq -r '.value')
  set_secret "$key" "$value"
done

# Write index map secret (contains only secret keys)
if [ -n "$index_map" ]; then
  set_secret "CLIENT_${client_key}__SOCIAL__CHANNELS__INDEX_JSON" "$index_map"
fi

printf 'Channel catalog written: %s\n' "$state_file"

# Suggest OpenClaw next actions
printf '\nSecret keys created (values live only in Infisical):\n'
printf '%s' "$catalog" | jq -r '.channels[] | "- " + .secret_key'

printf '\n\nNext actions:\n'
printf '%s\n' '- Ensure ~/.openclaw/openclaw.json has allowlists for relevant channels.'
printf '%s\n' '- Run `openclaw channels login --qr` (or `openclaw gateway start`) and scan QR for WhatsApp if needed.'
