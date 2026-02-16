#!/usr/bin/env bash
set -euo pipefail

# Consume platform-dispatched tasks from Postgres (alert_event) for workspace_key='onboarding'
# and append payload JSON to tasks/inbox/platform_tasks.jsonl.

cd "$(dirname "$0")/.."
mkdir -p tasks/inbox state

CURSOR_FILE="state/platform_task_cursor"
INBOX="tasks/inbox/platform_tasks.jsonl"

last=0
if [ -f "$CURSOR_FILE" ]; then
  last=$(cat "$CURSOR_FILE" 2>/dev/null || echo 0)
fi

mapfile -t rows < <(./scripts/psql_exec.sh -Atq -c "select id, payload::text from alert_event where id > ${last:-0} and workspace_key='onboarding' and source='platform' and title='platform_task' order by id asc;")

max_id=${last:-0}
count=0
for r in "${rows[@]}"; do
  id="${r%%|*}"
  payload="${r#*|}"
  case "$id" in
    ''|*[!0-9]*) continue ;;
  esac
  printf '%s\n' "$payload" >> "$INBOX"
  max_id="$id"
  count=$((count+1))
done

echo "$max_id" > "$CURSOR_FILE"

# Acknowledge back to alert-reporting (best-effort)
if [ "$count" -gt 0 ]; then
  ack=$(printf '{"consumer_workspace_key":"%s","consumed":%s,"last_event_id":%s}' "onboarding" "$count" "$max_id")
  ./scripts/psql_exec.sh -c "insert into alert_event (workspace_key, source, severity, title, body, payload) values ('alert_reporting','agent-builder-task-consumer','info','task_received','', '$ack'::jsonb);" >/dev/null || true
fi
