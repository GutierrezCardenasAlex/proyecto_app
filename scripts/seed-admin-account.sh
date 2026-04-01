#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Sembrando cuenta de central"
docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T postgres \
  psql -U "${POSTGRES_USER:-taxiya}" -d "${POSTGRES_DB:-taxiya}" \
  -f /dev/stdin < "$PROJECT_ROOT/infra/postgres/seed_admin_accounts.sql"

echo "==> Cuenta de central lista"
