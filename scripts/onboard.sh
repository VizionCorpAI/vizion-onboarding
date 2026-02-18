#!/usr/bin/env bash
set -uo pipefail
# STRICT_MODE=1 → exit on first module failure
# STRICT_MODE=0 (default) → fast mode: continue on failure, log warnings
STRICT_MODE=${STRICT_MODE:-0}

profile=${1:-default}
profile_file="profiles/${profile}.yaml"
if [ ! -f "$profile_file" ]; then
  echo "Profile '$profile' not found." >&2
  exit 1
fi

modules=()
while IFS= read -r line; do
  line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  case "$line" in
    -* )
      module_name=${line#-}
      module_name=$(echo "$module_name" | sed 's/^[[:space:]]*//')
      modules+=("$module_name")
      ;;
  esac
done < "$profile_file"

if [ ${#modules[@]} -eq 0 ]; then
  echo "Profile '$profile' defines no modules." >&2
  exit 1
fi

overall_status=0
warnings=0

for mod in "${modules[@]}"; do
  mod_dir="modules/$(printf '%s' "$mod")"
  if [ ! -f "$mod_dir/module.yaml" ]; then
    echo "WARNING: Module $mod missing definition — skipping" >&2
    warnings=$((warnings + 1))
    if [ "$STRICT_MODE" = "1" ]; then exit 1; fi
    continue
  fi
  script=$(grep '^script:' "$mod_dir/module.yaml" | cut -d: -f2- | xargs)
  if [ -z "$script" ]; then
    echo "WARNING: Module $mod has no script — skipping" >&2
    warnings=$((warnings + 1))
    if [ "$STRICT_MODE" = "1" ]; then exit 1; fi
    continue
  fi

  # Set ONBOARD_STATUS before postflight so it gets the right value
  if [ "$mod" = "postflight" ]; then
    export ONBOARD_STATUS="$([ "$overall_status" -eq 0 ] && echo completed || echo failed)"
  fi

  echo "--- Running module: $mod ($script)"
  set +e
  "$script"
  mod_exit=$?
  set -e

  if [ "$mod_exit" -ne 0 ]; then
    echo "WARNING: Module $mod exited with code $mod_exit" >&2
    overall_status=$((overall_status + 1))
    if [ "$STRICT_MODE" = "1" ]; then exit "$mod_exit"; fi
  fi
done

if [ "$warnings" -gt 0 ] || [ "$overall_status" -gt 0 ]; then
  echo "onboard.sh: completed with $overall_status module failure(s) and $warnings warning(s)"
fi

exit "$overall_status"
