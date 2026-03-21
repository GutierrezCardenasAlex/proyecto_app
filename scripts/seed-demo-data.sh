#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "==> Sembrando drivers demo en PostgreSQL"
docker compose exec -T postgres psql -U taxiya -d taxiya < infra/postgres/seed_demo_drivers.sql

echo
echo "Drivers demo listos:"
echo "- 7b8f6c11-1f39-4d40-8a11-111111111111"
echo "- 7b8f6c22-1f39-4d40-8a22-222222222222"
echo "- 7b8f6c33-1f39-4d40-8a33-333333333333"
echo "- 7b8f6c44-1f39-4d40-8a44-444444444444"
echo "- 7b8f6c55-1f39-4d40-8a55-555555555555"
