#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "==> Sembrando drivers demo en PostgreSQL"
docker compose exec -T postgres psql -U taxiya -d taxiya < infra/postgres/seed_demo_drivers.sql

echo
echo "Drivers demo listos:"
echo "- aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1"
echo "- aaaaaaa2-aaaa-aaaa-aaaa-aaaaaaaaaaa2"
echo "- aaaaaaa3-aaaa-aaaa-aaaa-aaaaaaaaaaa3"
echo "- aaaaaaa4-aaaa-aaaa-aaaa-aaaaaaaaaaa4"
echo "- aaaaaaa5-aaaa-aaaa-aaaa-aaaaaaaaaaa5"
