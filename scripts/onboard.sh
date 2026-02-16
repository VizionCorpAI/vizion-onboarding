#!/usr/bin/env bash
set -euo pipefail
profile=${1:-default}
profile_file="profiles/${profile}.yaml"
if [ ! -f "$profile_file" ]; then
  echo "Profile '$profile' not found." >&2
  exit 1
fi
modules=()
while IFS= read -r line; do
  line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [[ $line == -* ]]; then
    modules+=("${line#- }")
  fi
done < "$profile_file"
if [ ${#modules[@]} -eq 0 ]; then
  echo "Profile '$profile' defines no modules." >&2
  exit 1
fi
for mod in "${modules[@]}"; do
  mod_dir="modules/$(printf '%s' "$mod")"
  if [ ! -f "$mod_dir/module.yaml" ]; then
    echo "Module $mod missing definition." >&2
    exit 1
  fi
  script=$(grep '^script:' "$mod_dir/module.yaml" | cut -d: -f2- | xargs)
  if [ -z "$script" ]; then
    echo "Module $mod has no script." >&2
    exit 1
  fi
  echo "Running module $mod ($script)"
  "$script"
done
