#!/usr/bin/env bash
set -euo pipefail
CONTAINER=${PG_CONTAINER:-postgresql-pv9y-postgresql-1}
DB=${PGDATABASE:-AIDB}
USER=${PGUSER:-VizionAI}
exec docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U "$USER" -d "$DB" "$@"
