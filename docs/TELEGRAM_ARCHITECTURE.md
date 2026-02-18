# VizionAI Telegram Integration Architecture

Complete Telegram bot integration for VizionAI multi-channel automation platform.

## Overview

The VizionAI Telegram integration provides:
- **Main bot**: Shared router for all clients (@VizioncorpAIBot)
- **Per-client routing**: Automatic client identification via user ID allowlists
- **Auto-onboarding**: Telegram setup integrated into onboarding pipeline
- **OpenClaw integration**: Full Telegram channel support with webhook routing
- **n8n workflows**: Message routing and processing via n8n

## Architecture

```
Telegram User
   ↓
@VizioncorpAIBot (Main Bot)
   ↓ webhook
telegram.vizionai.iamvisioncorp.org
   ↓ Caddy HTTPS reverse proxy
OpenClaw Telegram Gateway (port 48950)
   ↓ n8n webhook
wf_telegram_router workflow
   ↓ client identification
Client workspace / agent
   ↓ response
Telegram message reply
```

## Components

### 1. Main Bot
- **Name**: VizionAI Main Bot
- **Username**: @VizioncorpAIBot
- **Token**: Stored in Infisical as `VIZIONAI__SOCIAL__TELEGRAM__MAIN_BOT_TOKEN`
- **Webhook**: `https://telegram.vizionai.iamvisioncorp.org/webhook/main`

### 2. Client-Specific Routing
Each client is identified by:
- Telegram user ID allowlist
- Client key mapping
- Message context

Secrets stored as:
```
CLIENT_<KEY>__SOCIAL__TELEGRAM__PRIMARY_BOT_TOKEN
CLIENT_<KEY>__SOCIAL__TELEGRAM__PRIMARY_BOT_ALLOWED_IDS
```

### 3. OpenClaw Configuration
Located at: `/docker/openclaw-xbkt/data/.openclaw/openclaw.json`

```json
{
  "channels": {
    "telegram": {
      "botToken": "${VIZIONAI__SOCIAL__TELEGRAM__MAIN_BOT_TOKEN}",
      "dmPolicy": "allowlist",
      "allowFrom": [],
      "groupPolicy": "allowlist",
      "allowGroups": [],
      "mediaMaxMb": 50,
      "debounceMs": 0
    }
  },
  "plugins": {
    "entries": {
      "telegram": {
        "enabled": true
      }
    }
  }
}
```

### 4. Caddy Webhook Configuration
File: `/etc/caddy/conf.d/telegram.caddy`

Routes:
- `https://telegram.vizionai.iamvisioncorp.org/webhook/main` → Main bot
- `https://telegram.vizionai.iamvisioncorp.org/webhook/<client_key>` → Client-specific

### 5. n8n Router Workflow
File: `/root/VizionAI/WORKSPACES/vizion-onboarding/templates/workflows/wf_telegram_router.json`

Flow:
1. Receive Telegram webhook
2. Parse message data
3. Identify client by user ID
4. Route to OpenClaw gateway
5. Log to learning system
6. Respond to Telegram

## Onboarding Integration

### Smart Profile
Profile: `smart_full`

Modules (in order):
1. **ai_expand** - Generate default channels (WhatsApp + Telegram)
2. **preflight_checks** - Verify system readiness
3. **channel_setup** - Register WhatsApp channels
4. **telegram_setup** - Register Telegram bots
5. **agent_setup** - Configure agents
6. **n8n_import** - Import workflows
7. **postflight** - Log results

### Onboarding Request Example

```json
{
  "requestId": "req_2026_02_18_client_telegram",
  "profile": "smart_full",
  "client": {
    "name": "Client Name",
    "key": "CLIENTKEY",
    "phone": "1234567890",
    "email": "client@example.com",
    "businessType": "Industry Type",
    "businessDescription": "What they do",
    "clientIps": ["1.2.3.4"],
    "aliases": ["Alias1", "Alias2"]
  },
  "channels": [],
  "agents": [],
  "workflows": [],
  "workspace": "none"
}
```

**Note**: Empty arrays are automatically populated by AI expansion module.

### What Happens During Onboarding

1. **AI Expansion** generates:
   - WhatsApp channel (if phone provided)
   - Telegram channel (main bot)
   - Default workflows

2. **Channel Setup** creates:
   - WhatsApp secrets in Infisical
   - Channel state files
   - OpenClaw allowlists

3. **Telegram Setup** performs:
   - Bot token storage (if client-specific bot)
   - User ID allowlist configuration
   - OpenClaw Telegram channel enablement
   - Webhook documentation

4. **Postflight** logs:
   - Onboarding results
   - Learning signals
   - Alert events

## Secret Management

All secrets stored in Infisical:

### Main Bot
```
Project: vizion-infrastructure-fu5-p
Env: prod
Path: /platform

VIZIONAI__SOCIAL__TELEGRAM__MAIN_BOT_TOKEN=<token>
```

### Client-Specific
```
Project: vizion-infrastructure-fu5-p
Env: prod
Path: /clients/<CLIENT_KEY>

CLIENT_<KEY>__SOCIAL__TELEGRAM__PRIMARY_BOT_TOKEN=<token>
CLIENT_<KEY>__SOCIAL__TELEGRAM__PRIMARY_BOT_ALLOWED_IDS=<user_ids>
```

## Scripts

### Setup Main Bot
```bash
cd /root/VizionAI/WORKSPACES/vizion-onboarding
bash scripts/setup_main_telegram_bot.sh
```

### Onboard Client with Telegram
```bash
cd /root/VizionAI/WORKSPACES/vizion-onboarding
bash scripts/onboard_request.sh templates/onboarding/<client_request>.json
```

### Set Webhook Manually
```bash
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/setWebhook" \
  -d "url=https://telegram.vizionai.iamvisioncorp.org/webhook/main"
```

### Check Webhook Status
```bash
curl "https://api.telegram.org/bot<BOT_TOKEN>/getWebhookInfo"
```

## Testing

### Test Main Bot
1. Open Telegram
2. Search for @VizioncorpAIBot
3. Send `/start`
4. Verify response

### Test Client Routing
1. Ensure client's Telegram user ID is in allowlist
2. Send message to bot
3. Check OpenClaw logs: `docker logs openclaw-xbkt-openclaw-1`
4. Verify n8n workflow execution

### Debug Webhook
```bash
# Check Caddy logs
tail -f /var/log/caddy/telegram-webhook.log

# Check OpenClaw logs
docker logs -f openclaw-xbkt-openclaw-1

# Test webhook endpoint
curl https://telegram.vizionai.iamvisioncorp.org/health
```

## Client Example: Long John Silver

### Onboarding Request
File: `templates/onboarding/long_john_silver_telegram.json`

```json
{
  "requestId": "req_2026_02_18_ljs_telegram",
  "profile": "smart_full",
  "client": {
    "name": "Long John Silver",
    "key": "LONGJOHNSILVER",
    "phone": "7373934343",
    "businessType": "Pirate Operations & Treasure Management",
    "clientIps": ["107.218.137.219"]
  }
}
```

### Result
- ✅ WhatsApp channel: 7373934343
- ✅ Telegram bot: @VizioncorpAIBot (shared main bot)
- ✅ OpenClaw configured
- ✅ Secrets stored
- ✅ Workflows imported
- ✅ Learning signals logged

### Secrets Created
```
CLIENT_LONGJOHNSILVER__SOCIAL__WHATSAPP__PRIMARY_PHONE
CLIENT_LONGJOHNSILVER__SOCIAL__TELEGRAM__PRIMARY_BOT_TOKEN
CLIENT_LONGJOHNSILVER__SOCIAL__CHANNELS__INDEX_JSON
```

## Troubleshooting

### Bot not responding
1. Check webhook is set: `curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"`
2. Check Caddy is running: `systemctl status caddy`
3. Check OpenClaw is running: `docker ps | grep openclaw`
4. Check logs: `docker logs openclaw-xbkt-openclaw-1`

### Webhook errors
1. Verify DNS: `dig telegram.vizionai.iamvisioncorp.org`
2. Test HTTPS: `curl https://telegram.vizionai.iamvisioncorp.org/health`
3. Check Caddy config: `caddy validate --config /etc/caddy/Caddyfile`

### User ID not recognized
1. Check OpenClaw allowlist: `cat /docker/openclaw-xbkt/data/.openclaw/openclaw.json | jq '.channels.telegram.allowFrom'`
2. Check Infisical secret: `CLIENT_<KEY>__SOCIAL__TELEGRAM__PRIMARY_BOT_ALLOWED_IDS`
3. Get user ID: have user send message, check logs

## Future Enhancements

### Phase 2 (Planned)
- [ ] Per-client bot creation via BotFather automation
- [ ] Telegram group management
- [ ] Rich media support (photos, documents, voice)
- [ ] Inline keyboards for interactive menus
- [ ] Bot commands (/help, /status, /admin)

### Phase 3 (Planned)
- [ ] Telegram channel broadcasting
- [ ] Payment integration via Telegram Payments
- [ ] Bot analytics dashboard
- [ ] Multi-language support
- [ ] Voice message transcription

## Support

- OpenClaw docs: [openclaw.ai](https://openclaw.ai)
- Telegram Bot API: [core.telegram.org/bots/api](https://core.telegram.org/bots/api)
- n8n docs: [docs.n8n.io](https://docs.n8n.io)

---

**Last Updated**: 2026-02-18
**Maintainer**: VizionAI Platform Team
**Version**: 1.0.0
