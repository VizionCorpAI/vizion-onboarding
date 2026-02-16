#!/usr/bin/env bash
set -euo pipefail

base_dir="$PWD"
for dirname in agents docs infra scripts workflows; do
  mkdir -p "$dirname"
done
cat <<'EOF2' > README.md
# $(basename "$PWD")

This workspace was scaffolded by vizion-onboarding modules.
EOF2
