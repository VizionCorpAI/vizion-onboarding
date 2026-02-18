# 🚀 Telegram Integration - Quick Start Guide

## ⚡ 3-Step Setup

### Step 1: Fix OpenClaw Config (30 seconds)

```bash
docker exec -it openclaw-xbkt-openclaw-1 openclaw doctor --fix
docker restart openclaw-xbkt-openclaw-1
```

### Step 2: Add Your Telegram User ID (1 minute)

1. Open Telegram
2. Message [@userinfobot](https://t.me/userinfobot)
3. Copy your user ID
4. Run:

```bash
# Replace YOUR_USER_ID with the actual number
docker exec openclaw-xbkt-openclaw-1 sh -c "jq '.channels.telegram.allowFrom += [\"YOUR_USER_ID\"]' ~/.openclaw/openclaw.json > /tmp/c.json && mv /tmp/c.json ~/.openclaw/openclaw.json"
docker restart openclaw-xbkt-openclaw-1
```

### Step 3: Test the Bot (10 seconds)

1. Open Telegram
2. Search: **@VizioncorpAIBot**
3. Send: `/start`
4. ✅ Bot should respond!

---

## 📝 Onboard a New Client with Telegram

```bash
cd /root/VizionAI/WORKSPACES/vizion-onboarding

# Create request file
cat > my_client.json <<'EOF'
{
  "requestId": "req_my_client_001",
  "profile": "smart_full",
  "client": {
    "name": "My Client Name",
    "key": "MYCLIENT",
    "phone": "1234567890",
    "email": "client@example.com",
    "businessType": "Industry Type",
    "clientIps": ["1.2.3.4"]
  }
}
EOF

# Run onboarding
bash scripts/onboard_request.sh my_client.json

# Result: WhatsApp + Telegram channels auto-configured!
```

---

## 🔍 Check Status

```bash
# View OpenClaw logs
docker logs -f openclaw-xbkt-openclaw-1 | grep -i telegram

# Check bot webhook status
curl "https://api.telegram.org/bot8408221035:AAHdCrMQuedmtJPxWiZnzGHEwNT0JTC3ScM/getMe" | jq .

# View onboarding results
cat state/clients/LONGJOHNSILVER.json | jq .
```

---

## 📚 Full Documentation

- **Architecture**: [docs/TELEGRAM_ARCHITECTURE.md](docs/TELEGRAM_ARCHITECTURE.md)
- **Delivery Summary**: [docs/DELIVERY_SUMMARY.md](docs/DELIVERY_SUMMARY.md)

---

**Bot**: @VizioncorpAIBot
**Status**: Ready to test!
