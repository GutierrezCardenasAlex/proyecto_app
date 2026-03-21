#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

DRIVERS=(
  "7b8f6c11-1f39-4d40-8a11-111111111111"
  "7b8f6c22-1f39-4d40-8a22-222222222222"
  "7b8f6c33-1f39-4d40-8a33-333333333333"
  "7b8f6c44-1f39-4d40-8a44-444444444444"
  "7b8f6c55-1f39-4d40-8a55-555555555555"
)

BASE_LAT="-19.5836"
BASE_LNG="-65.7531"

post_location() {
  local driver_id="$1"
  local lat="$2"
  local lng="$3"

  docker compose exec -T location-service node -e "
const [driverId, lat, lng] = process.argv.slice(1);
fetch('http://location-service:3005/drivers', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    driverId,
    lat: parseFloat(lat),
    lng: parseFloat(lng),
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
    lat=$(python3 -c "base=float('$BASE_LAT'); step=$step; idx=$i; print(f'{base + (idx * 0.0012) + ((step % 5) * 0.00018):.6f}')")
    lng=$(python3 -c "base=float('$BASE_LNG'); step=$step; idx=$i; print(f'{base + (idx * 0.0011) - ((step % 4) * 0.00015):.6f}')")
    post_location "$driver" "$lat" "$lng"
    echo "driver=$driver lat=$lat lng=$lng"
  done

  step=$((step + 1))
  sleep 5
done
