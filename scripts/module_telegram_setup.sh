#!/usr/bin/env bash
# module_telegram_setup.sh - Telegram bot registration and configuration
set -euo pipefail

CLIENT_NAME=${CLIENT_NAME:-}
CLIENT_KEY=${CLIENT_KEY:-}
TELEGRAM_JSON=${TELEGRAM_JSON:-}
CHANNELS_JSON=${CHANNELS_JSON:-}

if [ -z "$CLIENT_NAME" ]; then
  echo "module_telegram_setup: CLIENT_NAME is required" >&2
  exit 1
fi

if [ -z "$CLIENT_KEY" ]; then
  CLIENT_KEY=$(printf "%s" "$CLIENT_NAME" | tr '[:lower:]' '[:upper:]' | tr -c '[:alnum:]' '_')
fi

# Extract Telegram channels from CHANNELS_JSON
telegram_channels=$(printf '%s' "${CHANNELS_JSON:-[]}" | jq -c '[.[] | select(.kind == "TELEGRAM" or .kind == "telegram")]' 2>/dev/null || echo "[]")

if [ "$telegram_channels" = "[]" ] || [ -z "$telegram_channels" ]; then
  echo "module_telegram_setup: no Telegram channels configured, skipping"
  exit 0
fi

infisical_project="${INFISICAL_PROJECT:-vizion-infrastructure-fu5-p}"
infisical_env="${INFISICAL_ENV:-prod}"
openclaw_config="${OPENCLAW_CONFIG:-/docker/openclaw-xbkt/data/.openclaw/openclaw.json}"

# Store secret in Infisical
set_secret() {
  local key="$1"
  local value="$2"
  if [ -z "$value" ]; then
    echo "module_telegram_setup: skipping empty secret $key"
    return 0
  fi
  if ! command -v infisical >/dev/null 2>&1; then
    echo "module_telegram_setup: infisical CLI not available, skipping $key" >&2
    return 0
  fi
  if [ -z "${INFISICAL_TOKEN:-}" ]; then
    echo "module_telegram_setup: INFISICAL_TOKEN not set, skipping $key" >&2
    return 0
  fi
  local path="/clients/${CLIENT_KEY}"
  infisical secrets set --projectSlug="$infisical_project" --env="$infisical_env" --path="$path" "$key=$value" >/dev/null
  echo "module_telegram_setup: stored $key in Infisical"
}

# Process each Telegram channel
bot_configs=()
all_allowed_ids=""
printf '%s' "$telegram_channels" | jq -c '.[]' | while IFS= read -r channel; do
  identifier=$(printf '%s' "$channel" | jq -r '.identifier // "PRIMARY_BOT"')
  bot_token=$(printf '%s' "$channel" | jq -r '.value // empty')
  bot_username=$(printf '%s' "$channel" | jq -r '.username // empty')
  channel_allowed_ids=$(printf '%s' "$channel" | jq -r '.telegramIds // [] | join(",")')

  secret_key="CLIENT_${CLIENT_KEY}__SOCIAL__TELEGRAM__${identifier}_TOKEN"
  allowlist_key="CLIENT_${CLIENT_KEY}__SOCIAL__TELEGRAM__${identifier}_ALLOWED_IDS"

  if [ -n "$bot_token" ]; then
    set_secret "$secret_key" "$bot_token"
    echo "module_telegram_setup: registered bot for $CLIENT_NAME ($identifier)"
  fi

  if [ -n "$channel_allowed_ids" ]; then
    set_secret "$allowlist_key" "$channel_allowed_ids"
    echo "module_telegram_setup: stored allowed Telegram IDs for $CLIENT_NAME"
    all_allowed_ids="${all_allowed_ids},${channel_allowed_ids}"
  fi

  # Collect bot config for OpenClaw update
  if [ -n "$bot_token" ]; then
    bot_configs+=("$bot_token|$channel_allowed_ids")
  fi
done

# Clean up collected IDs
all_allowed_ids=$(printf '%s' "$all_allowed_ids" | tr ',' '\n' | grep -v '^$' | sort -u | paste -sd, || echo "none")

# Update OpenClaw configuration to enable Telegram channel
if [ ! -f "$openclaw_config" ]; then
  echo "module_telegram_setup: OpenClaw config not found at $openclaw_config" >&2
  exit 0
fi

# Check if Telegram channel is already configured
telegram_enabled=$(jq -r '.plugins.entries.telegram.enabled // false' "$openclaw_config")

if [ "$telegram_enabled" != "true" ]; then
  echo "module_telegram_setup: enabling Telegram in OpenClaw config"

  # Create backup
  cp "$openclaw_config" "${openclaw_config}.bak.$(date +%s)"

  # Enable Telegram plugin
  jq '.plugins.entries.telegram.enabled = true' "$openclaw_config" > "${openclaw_config}.tmp" && mv "${openclaw_config}.tmp" "$openclaw_config"

  # Add Telegram channel if not exists
  has_telegram=$(jq -r '.channels.telegram // "missing"' "$openclaw_config")
  if [ "$has_telegram" = "missing" ]; then
    jq '.channels.telegram = {
      "dmPolicy": "allowlist",
      "allowFrom": [],
      "groupPolicy": "allowlist",
      "allowGroups": [],
      "mediaMaxMb": 50,
      "debounceMs": 0
    }' "$openclaw_config" > "${openclaw_config}.tmp" && mv "${openclaw_config}.tmp" "$openclaw_config"
  fi

  echo "module_telegram_setup: Telegram channel enabled in OpenClaw"
fi

# Add client's allowed Telegram IDs to OpenClaw allowlist
if [ -n "$all_allowed_ids" ] && [ "$all_allowed_ids" != "none" ]; then
  current_allowed=$(jq -r '.channels.telegram.allowFrom // [] | join(",")' "$openclaw_config")

  # Merge new IDs with existing
  merged_ids=$(printf '%s,%s' "$current_allowed" "$all_allowed_ids" | tr ',' '\n' | sort -u | grep -v '^$' | paste -sd,)

  jq --arg ids "$merged_ids" '.channels.telegram.allowFrom = ($ids | split(","))' "$openclaw_config" > "${openclaw_config}.tmp" && mv "${openclaw_config}.tmp" "$openclaw_config"

  echo "module_telegram_setup: added client to OpenClaw Telegram allowlist"
fi

# Set up webhook endpoint (documented for manual setup)
webhook_url="https://telegram.vizionai.iamvisioncorp.org/webhook/${CLIENT_KEY,,}"

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Telegram Bot Configuration Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Client: $CLIENT_NAME ($CLIENT_KEY)
Bot(s) registered: $(printf '%s' "$telegram_channels" | jq -r '.[].username // "token-only"' | paste -sd, || echo "unknown")

Secrets stored in Infisical:
$(printf '%s' "$telegram_channels" | jq -r '.[] | "  - CLIENT_'${CLIENT_KEY}'__SOCIAL__TELEGRAM__" + (.identifier // "PRIMARY_BOT") + "_TOKEN"')

Webhook URL (set manually via BotFather /setWebhook):
  $webhook_url

Or via curl:
  curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/setWebhook" \\
    -d "url=$webhook_url"

OpenClaw Status:
  - Telegram channel: ENABLED
  - Allowed IDs: $all_allowed_ids

Next steps:
  1. Set webhook URL for each bot
  2. Test message to bot: send "/start" to verify routing
  3. Check OpenClaw logs: docker logs openclaw-xbkt

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

printf 'module_telegram_setup: completed for %s\n' "$CLIENT_NAME"
