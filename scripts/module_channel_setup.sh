#!/usr/bin/env bash
set -euo pipefail

state="state/channels.json"
mkdir -p state
if [ ! -f "$state" ]; then
  echo '{}' > "$state"
fi

cat <<'MSG'
Channel setup placeholder: store WhatsApp/Telegram channels in Infisical and update OpenClaw allowlists.
MSG
