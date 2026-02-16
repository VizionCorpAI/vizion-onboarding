#!/usr/bin/env bash
set -euo pipefail

mkdir -p agents/main agents/workers
for f in AGENT.md SOUL.md MEMORY.md TOOLS.md; do
  if [ ! -f "agents/main/$f" ]; then
    cat <<'MD' > "agents/main/$f"
# $f

Created by vizion-onboarding module_agent_setup.
MD
  fi
done

if [ -n "${AGENTS_JSON:-}" ] && command -v jq >/dev/null 2>&1; then
  printf '%s' "$AGENTS_JSON" | jq -r '.[]' | while IFS= read -r agent_key; do
    [ -z "$agent_key" ] && continue
    safe_key=$(printf "%s" "$agent_key" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' '_')
    agent_dir="agents/workers/${safe_key}"
    mkdir -p "$agent_dir"
    for f in AGENT.md SOUL.md MEMORY.md TOOLS.md; do
      if [ ! -f "$agent_dir/$f" ]; then
        cat <<MD > "$agent_dir/$f"
# $f

Created by vizion-onboarding module_agent_setup for $agent_key.
MD
      fi
    done
  done
fi
