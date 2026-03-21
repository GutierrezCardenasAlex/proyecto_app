#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

DRIVERS=(
  "aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1"
  "aaaaaaa2-aaaa-aaaa-aaaa-aaaaaaaaaaa2"
  "aaaaaaa3-aaaa-aaaa-aaaa-aaaaaaaaaaa3"
  "aaaaaaa4-aaaa-aaaa-aaaa-aaaaaaaaaaa4"
  "aaaaaaa5-aaaa-aaaa-aaaa-aaaaaaaaaaa5"
)

BASE_LAT="-19.5836"
BASE_LNG="-65.7531"

post_location() {
  local driver_id="$1"
  local lat="$2"
  local lng="$3"

  docker compose exec -T location-service node -e "
fetch('http://location-service:3005/drivers', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    driverId: process.argv[1],
    lat: Number(process.argv[2]),
    lng: Number(process.argv[3]),
    heading: 90,
    speedKph: 28
  })
}).then(async (res) => {
  const body = await res.text();
  if (!res.ok) {
    console.error(body);
    process.exit(1);
  }
}).catch((error) => {
  console.error(error.message);
  process.exit(1);
});
" "$driver_id" "$lat" "$lng" >/dev/null
}

echo "==> Simulando ubicaciones de conductores demo"
echo "Ctrl+C para detener"

step=0
while true; do
  for i in "${!DRIVERS[@]}"; do
    driver="${DRIVERS[$i]}"
    lat=$(awk -v base="$BASE_LAT" -v step="$step" -v idx="$i" 'BEGIN { printf "%.6f", base + (idx * 0.0012) + (step % 5) * 0.00018 }')
    lng=$(awk -v base="$BASE_LNG" -v step="$step" -v idx="$i" 'BEGIN { printf "%.6f", base + (idx * 0.0011) - (step % 4) * 0.00015 }')
    post_location "$driver" "$lat" "$lng"
    echo "driver=$driver lat=$lat lng=$lng"
  done

  step=$((step + 1))
  sleep 5
done
