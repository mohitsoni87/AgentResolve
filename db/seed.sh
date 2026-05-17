#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="${POSTGRES_CONTAINER:-agentresolve-postgres}"
DB_USER="${POSTGRES_USER:-agentresolve}"
DB_NAME="${POSTGRES_DB:-agentresolve}"

docker exec -i "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" < "$ROOT/db/seed.sql"

echo "Seed complete."
