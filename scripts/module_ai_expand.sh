#!/usr/bin/env bash
# module_ai_expand.sh - AI-powered requirement expansion using Claude API
set -euo pipefail

CLIENT_NAME=${CLIENT_NAME:-}
CLIENT_KEY=${CLIENT_KEY:-}
CLIENT_EMAIL=${CLIENT_EMAIL:-}
CLIENT_PHONE=${CLIENT_PHONE:-}
CLIENT_IPS=${CLIENT_IPS:-}
BUSINESS_TYPE=${BUSINESS_TYPE:-}
BUSINESS_DESCRIPTION=${BUSINESS_DESCRIPTION:-}
AI_EXPAND_ENABLED=${AI_EXPAND_ENABLED:-1}
REQUEST_ID=${REQUEST_ID:-}

# Idempotency check - if exports already exist, load and skip
if [ -n "$REQUEST_ID" ] && [ -f "state/exports/${REQUEST_ID}.sh" ]; then
  echo "module_ai_expand: already ran for $REQUEST_ID, loading previous results"
  source "state/exports/${REQUEST_ID}.sh"
  exit 0
fi

# If AI expansion is disabled or Claude API key not available, skip
if [ "$AI_EXPAND_ENABLED" != "1" ]; then
  echo "module_ai_expand: AI expansion disabled (AI_EXPAND_ENABLED != 1)"
  exit 0
fi

if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${CLAUDE_API_KEY:-}" ]; then
  echo "module_ai_expand: Claude API key not set (ANTHROPIC_API_KEY or CLAUDE_API_KEY required)"
  echo "module_ai_expand: Skipping AI expansion - generating defaults from client info"

  # Generate sensible defaults when AI is not available
  DEFAULT_RECOMMENDATIONS=$(cat <<'DEFAULTS'
{
  "channels": [],
  "workflows": [],
  "access": {
    "ips": [],
    "level": "staging",
    "roles": ["admin"]
  },
  "integrations": [],
  "security": {
    "mfa_required": false,
    "ip_allowlist_strict": false,
    "session_timeout": "4h"
  },
  "reasoning": "AI expansion disabled - using defaults. Add Claude API key for intelligent recommendations."
}
DEFAULTS
)

  # If client phone is provided, add default WhatsApp channel
  if [ -n "${CLIENT_PHONE:-}" ]; then
    DEFAULT_RECOMMENDATIONS=$(printf '%s' "$DEFAULT_RECOMMENDATIONS" | jq --arg phone "$CLIENT_PHONE" '.channels += [{"kind": "WHATSAPP", "identifier": "PRIMARY_PHONE", "domain": "SOCIAL", "value": $phone}]')
  fi

  # Add default Telegram bot (main VizionAI bot for all clients)
  DEFAULT_RECOMMENDATIONS=$(printf '%s' "$DEFAULT_RECOMMENDATIONS" | jq '.channels += [{"kind": "TELEGRAM", "identifier": "PRIMARY_BOT", "domain": "SOCIAL", "value": "8408221035:AAHdCrMQuedmtJPxWiZnzGHEwNT0JTC3ScM", "username": "@VizioncorpAIBot"}]')

  # If client IPs provided, add to access config
  if [ -n "${CLIENT_IPS:-}" ]; then
    DEFAULT_RECOMMENDATIONS=$(printf '%s' "$DEFAULT_RECOMMENDATIONS" | jq --arg ips "$CLIENT_IPS" '.access.ips = ($ips | split(","))')
  fi

  export AI_RECOMMENDATIONS="$DEFAULT_RECOMMENDATIONS"
  export AI_EXPANDED="0"
  export CHANNELS_JSON=$(printf '%s' "$DEFAULT_RECOMMENDATIONS" | jq -c '.channels // []')
  export WORKFLOWS_JSON=$(printf '%s' "$DEFAULT_RECOMMENDATIONS" | jq -c '.workflows // []')

  # Write exports to file for onboard_request.sh to source
  if [ -n "${REQUEST_ID:-}" ]; then
    mkdir -p state/exports
    cat > "state/exports/${REQUEST_ID}.sh" <<EXPORTS
export CHANNELS_JSON='$CHANNELS_JSON'
export WORKFLOWS_JSON='$WORKFLOWS_JSON'
export AI_RECOMMENDATIONS='$DEFAULT_RECOMMENDATIONS'
export AI_EXPANDED='0'
EXPORTS
  fi

  echo "module_ai_expand: defaults generated (phone: ${CLIENT_PHONE:-none}, ips: ${CLIENT_IPS:-none})"
  exit 0
fi

if [ -z "$CLIENT_NAME" ]; then
  echo "module_ai_expand: CLIENT_NAME required for AI expansion"
  exit 1
fi

# Build the AI prompt
AI_PROMPT=$(cat <<PROMPT
You are an expert onboarding consultant for VizionAI, a multi-channel automation platform.

Given this client information:
- Name: ${CLIENT_NAME}
- Phone: ${CLIENT_PHONE:-not provided}
- Email: ${CLIENT_EMAIL:-not provided}
- Access IPs: ${CLIENT_IPS:-not provided}
- Business Type: ${BUSINESS_TYPE:-not specified}
- Description: ${BUSINESS_DESCRIPTION:-not provided}

Infer and recommend:
1. **Channels**: What communication channels should be enabled? (WhatsApp, Email, SMS, Discord, Telegram, Slack)
2. **Workflows**: What n8n workflows would be valuable? (e.g., lead capture, appointment scheduling, payment reminders, CRM sync)
3. **Access Pattern**: Should they have IP restrictions? What level of access (staging vs production, admin vs operator)?
4. **Integrations**: What third-party integrations might they need? (CRM, payment processors, calendar, etc.)
5. **Security Posture**: Recommended security settings based on their business type

Output as JSON only, no explanation:
{
  "channels": [{"kind": "WHATSAPP", "identifier": "PRIMARY_PHONE"}],
  "workflows": ["wf_lead_capture", "wf_appointment_reminder"],
  "access": {
    "ips": ["${CLIENT_IPS}"],
    "level": "staging",
    "roles": ["admin"]
  },
  "integrations": ["hubspot", "stripe"],
  "security": {
    "mfa_required": false,
    "ip_allowlist_strict": true,
    "session_timeout": "4h"
  },
  "reasoning": "Brief 1-2 sentence explanation of recommendations"
}
PROMPT
)

# Call Claude API using curl (fallback if SDK not available)
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-${CLAUDE_API_KEY:-}}"

AI_RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -d @- << REQEOF
{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 2048,
  "messages": [{
    "role": "user",
    "content": $(printf '%s' "$AI_PROMPT" | jq -Rs .)
  }]
}
REQEOF
)

# Extract the content
AI_RECOMMENDATIONS=$(printf '%s' "$AI_RESPONSE" | jq -r '.content[0].text' 2>/dev/null || echo "{}")

# Store recommendations for next modules
export AI_RECOMMENDATIONS="$AI_RECOMMENDATIONS"
export AI_EXPANDED="1"

# Export channels/agents/workflows for downstream modules
export CHANNELS_JSON=$(printf '%s' "$AI_RECOMMENDATIONS" | jq -c '.channels // []' 2>/dev/null || echo '[]')
export AGENTS_JSON=$(printf '%s' "$AI_RECOMMENDATIONS" | jq -c '.agents // []' 2>/dev/null || echo '[]')
export WORKFLOWS_JSON=$(printf '%s' "$AI_RECOMMENDATIONS" | jq -c '.workflows // []' 2>/dev/null || echo '[]')

# Write to state for postflight logging
if [ -n "${REQUEST_ID:-}" ]; then
  printf '%s' "$AI_RECOMMENDATIONS" > "state/ai_recommendations_${REQUEST_ID}.json" 2>/dev/null || true

  # Write exports to file for onboard_request.sh to source
  mkdir -p state/exports
  cat > "state/exports/${REQUEST_ID}.sh" <<EXPORTS
export CHANNELS_JSON='$CHANNELS_JSON'
export AGENTS_JSON='$AGENTS_JSON'
export WORKFLOWS_JSON='$WORKFLOWS_JSON'
export AI_RECOMMENDATIONS='$AI_RECOMMENDATIONS'
export AI_EXPANDED='1'
EXPORTS
fi

echo "module_ai_expand: AI recommendations generated"
echo "$AI_RECOMMENDATIONS" | jq '.' 2>/dev/null || echo "$AI_RECOMMENDATIONS"
