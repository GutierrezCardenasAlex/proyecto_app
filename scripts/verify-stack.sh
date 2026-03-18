#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

step() {
  echo
  echo "==> $1"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Falta el comando: $1" >&2
    exit 1
  }
}

check_container() {
  local service="$1"
  local state
  state="$(docker compose ps --status running --services | grep -x "$service" || true)"
  if [[ -z "$state" ]]; then
    echo "Servicio no corriendo: $service" >&2
    exit 1
  fi
  echo "$service OK"
}

check_health_from_gateway() {
  local label="$1"
  local url="$2"
  docker compose exec -T gateway-api node -e '
const url = process.argv[1];
fetch(url)
  .then(async (res) => {
    const body = await res.text();
    if (!res.ok) {
      console.error(`${res.status} ${body}`);
      process.exit(1);
    }
    console.log(body);
  })
  .catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
' "$url" >/dev/null
  echo "$label OK"
}

step "Validando dependencias"
require_cmd docker
require_cmd curl

step "Revisando contenedores"
docker compose ps
for service in \
  postgres \
  redis \
  rabbitmq \
  auth-service \
  driver-service \
  trip-service \
  dispatch-service \
  location-service \
  notification-service \
  admin-service \
  websocket-service \
  gateway-api
do
  check_container "$service"
done

step "Revisando health internos"
check_health_from_gateway "auth-service" "http://auth-service:3001/health"
check_health_from_gateway "driver-service" "http://driver-service:3002/health"
check_health_from_gateway "trip-service" "http://trip-service:3003/health"
check_health_from_gateway "dispatch-service" "http://dispatch-service:3004/health"
check_health_from_gateway "location-service" "http://location-service:3005/health"
check_health_from_gateway "notification-service" "http://notification-service:3006/health"
check_health_from_gateway "admin-service" "http://admin-service:3007/health"
check_health_from_gateway "websocket-service" "http://websocket-service:3008/health"

step "Revisando gateway"
curl -fsS http://localhost:3000/health >/dev/null
echo "gateway-api OK"

step "Revisando RabbitMQ management"
curl -fsS http://localhost:15672 >/dev/null && echo "rabbitmq management OK" || echo "rabbitmq management no responde"

echo
echo "Stack verificado correctamente."
