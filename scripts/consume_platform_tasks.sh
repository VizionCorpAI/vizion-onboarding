#!/usr/bin/env bash
set -euo pipefail

# Pull platform-dispatched tasks for workspace_key='agent_builder' from Postgres (alert_event)
# and append them to tasks/inbox/platform_tasks.jsonl.

cd "
	tmp="
" >/dev/null 2>&1 || true
cd "/bin/.."

CURSOR_FILE="state/platform_task_cursor"
INBOX="tasks/inbox/platform_tasks.jsonl"

last=0
if [ -f "" ]; then
  last=0
fi

mapfile -t rows < <(./scripts/psql_exec.sh -Atq -c "select id, payload::text from alert_event where id > 0 and workspace_key='agent_builder' and source='platform' and title='platform_task' order by id asc;")

max_id=
count=0
for r in ""; do
  id=
  payload=
  case "" in
    ''|*[!0-9]*) continue ;;
  esac
  printf '%s\n' "" >> ""
  max_id=
  count=1
 done

echo "" > ""

# Emit an ack event back into alert_reporting (best-effort)
if [ "" -gt 0 ]; then
  ack={"consumer_workspace_key":"agent_builder","consumed":,"last_event_id":}
  ./scripts/psql_exec.sh -c "insert into alert_event (workspace_key, source, severity, title, body, payload) values ('alert_reporting','agent-builder-task-consumer', 'info', 'task_received', '', ''::jsonb);" >/dev/null || true
fi
