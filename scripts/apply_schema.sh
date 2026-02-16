#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/psql_exec.sh < infra/sql/schema.sql
