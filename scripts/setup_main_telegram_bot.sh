#!/usr/bin/env bash
# setup_main_telegram_bot.sh - One-time setup for VizionAI Main Bot
set -euo pipefail

MAIN_BOT_TOKEN="${MAIN_BOT_TOKEN:-8408221035:AAHdCrMQuedmtJPxWiZnzGHEwNT0JTC3ScM}"
MAIN_BOT_USERNAME="${MAIN_BOT_USERNAME:-@VizioncorpAIBot}"

infisical_project="${INFISICAL_PROJECT:-vizion-infrastructure-fu5-p}"
infisical_env="${INFISICAL_ENV:-prod}"
openclaw_config="${OPENCLAW_CONFIG:-/docker/openclaw-xbkt/data/.openclaw/openclaw.json}"

echo "Setting up VizionAI Main Telegram Bot..."

# Store main bot token in Infisical
if command -v infisical >/dev/null 2>&1 && [ -n "${INFISICAL_TOKEN:-}" ]; then
  infisical secrets set \
    --projectSlug="$infisical_project" \
    --env="$infisical_env" \
    --path=/platform \
    "VIZIONAI__SOCIAL__TELEGRAM__MAIN_BOT_TOKEN=$MAIN_BOT_TOKEN" >/dev/null

  echo "✓ Main bot token stored in Infisical"
else
  echo "⚠ Infisical not available, skipping token storage"
fi

# Configure OpenClaw for Telegram
if [ -f "$openclaw_config" ]; then
  # Create backup
  cp "$openclaw_config" "${openclaw_config}.bak.$(date +%s)"

  # Enable Telegram plugin
  jq '.plugins.entries.telegram.enabled = true' "$openclaw_config" > "${openclaw_config}.tmp" && mv "${openclaw_config}.tmp" "$openclaw_config"

  # Add Telegram channel config
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

  # Add bot token reference
  jq --arg token "\${VIZIONAI__SOCIAL__TELEGRAM__MAIN_BOT_TOKEN}" \
    '.channels.telegram.botToken = $token' \
    "$openclaw_config" > "${openclaw_config}.tmp" && mv "${openclaw_config}.tmp" "$openclaw_config"

  echo "✓ OpenClaw configured for Telegram"
else
  echo "⚠ OpenClaw config not found at $openclaw_config"
fi

# Set webhook URL
webhook_url="https://telegram.vizionai.iamvisioncorp.org/webhook/main"

echo ""
echo "Main Bot Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Bot: VizionAI Main Bot"
echo "Username: $MAIN_BOT_USERNAME"
echo "Webhook URL: $webhook_url"
echo ""
echo "Next steps:"
echo "1. Set webhook (run this command):"
echo ""
echo "   curl -X POST \"https://api.telegram.org/bot${MAIN_BOT_TOKEN}/setWebhook\" \\"
echo "     -d \"url=$webhook_url\""
echo ""
echo "2. Configure Caddy webhook endpoint (see /etc/caddy/conf.d/telegram.caddy)"
echo "3. Restart OpenClaw to load new config:"
echo "   docker restart openclaw-xbkt"
echo "4. Test by sending /start to $MAIN_BOT_USERNAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
