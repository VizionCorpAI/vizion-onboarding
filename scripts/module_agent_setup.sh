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
