#!/usr/bin/env bash
set -euo pipefail

fingerprint=${1:-}
source_system=${2:-onboarding}
summary=${3:-}
severity=${4:-medium}
payload=${5:-"{}"}

if [ -z "$fingerprint" ] || [ -z "$summary" ]; then
  echo "Usage: $0 <fingerprint> <source_system> <summary> [severity] [payload_json]" >&2
  exit 1
fi

sql=$(cat <<'SQL'
INSERT INTO learn_signal (fingerprint, source_system, severity, summary, payload)
VALUES (:'fingerprint', :'source_system', :'severity', :'summary', (:'payload')::jsonb)
ON CONFLICT (fingerprint) DO UPDATE
SET last_seen = now(),
    seen_count = learn_signal.seen_count + 1,
    summary = COALESCE(EXCLUDED.summary, learn_signal.summary),
    payload = learn_signal.payload || EXCLUDED.payload;
SQL
)

/root/VizionAI/WORKSPACES/vizion-onboarding/scripts/psql_exec.sh \
  -v fingerprint="$fingerprint" \
  -v source_system="$source_system" \
  -v severity="$severity" \
  -v summary="$summary" \
  -v payload="$payload" \
  <<< "$sql"
