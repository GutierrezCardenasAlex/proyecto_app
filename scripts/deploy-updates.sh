#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST_PATH="${PROJECT_ROOT}/services/gateway-api/src/app-updates.manifest.json"
DOWNLOADS_ROOT="${PROJECT_ROOT}/infra/downloads"
BASE_URL="${BASE_URL:-https://rapigo.cybernovatech.space}"
RESTART_MODE="${RESTART_MODE:-reload-nginx}"

PASSENGER_APK=""
PASSENGER_VERSION=""
PASSENGER_BUILD=""
PASSENGER_RELEASED_AT=""
PASSENGER_UPDATED_AT=""
PASSENGER_MANDATORY="false"

DRIVER_APK=""
DRIVER_VERSION=""
DRIVER_BUILD=""
DRIVER_RELEASED_AT=""
DRIVER_UPDATED_AT=""
DRIVER_MANDATORY="false"

SHOW_HELP="false"

usage() {
  cat <<'EOF'
Uso:
  ./scripts/deploy-updates.sh [opciones]

Opciones pasajero:
  --passenger-apk PATH
  --passenger-version VERSION
  --passenger-build BUILD
  --passenger-released-at ISO_DATE
  --passenger-updated-at ISO_DATE
  --passenger-mandatory true|false

Opciones conductor:
  --driver-apk PATH
  --driver-version VERSION
  --driver-build BUILD
  --driver-released-at ISO_DATE
  --driver-updated-at ISO_DATE
  --driver-mandatory true|false

Opciones generales:
  --base-url URL
  --restart-mode reload-nginx|restart-nginx|restart-gateway|restart-all|none
  --help

Ejemplo completo:
  ./scripts/deploy-updates.sh \
    --passenger-apk /root/builds/rapigo-passenger.apk \
    --passenger-version 1.0.1 \
    --passenger-build 2 \
    --passenger-released-at 2026-07-07T00:00:00Z \
    --driver-apk /root/builds/rapigo-driver-pro.apk \
    --driver-version 1.0.1 \
    --driver-build 2 \
    --driver-released-at 2026-07-07T00:00:00Z

Notas:
  - Puedes desplegar solo pasajero, solo conductor o ambos.
  - Si no envías updated-at, usa la fecha actual UTC.
  - Si no envías released-at, usa updated-at.
EOF
}

require_value() {
  local flag="$1"
  local value="${2:-}"
  if [[ -z "${value}" ]]; then
    echo "Falta valor para ${flag}" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --passenger-apk)
      require_value "$1" "${2:-}"
      PASSENGER_APK="$2"
      shift 2
      ;;
    --passenger-version)
      require_value "$1" "${2:-}"
      PASSENGER_VERSION="$2"
      shift 2
      ;;
    --passenger-build)
      require_value "$1" "${2:-}"
      PASSENGER_BUILD="$2"
      shift 2
      ;;
    --passenger-released-at)
      require_value "$1" "${2:-}"
      PASSENGER_RELEASED_AT="$2"
      shift 2
      ;;
    --passenger-updated-at)
      require_value "$1" "${2:-}"
      PASSENGER_UPDATED_AT="$2"
      shift 2
      ;;
    --passenger-mandatory)
      require_value "$1" "${2:-}"
      PASSENGER_MANDATORY="$2"
      shift 2
      ;;
    --driver-apk)
      require_value "$1" "${2:-}"
      DRIVER_APK="$2"
      shift 2
      ;;
    --driver-version)
      require_value "$1" "${2:-}"
      DRIVER_VERSION="$2"
      shift 2
      ;;
    --driver-build)
      require_value "$1" "${2:-}"
      DRIVER_BUILD="$2"
      shift 2
      ;;
    --driver-released-at)
      require_value "$1" "${2:-}"
      DRIVER_RELEASED_AT="$2"
      shift 2
      ;;
    --driver-updated-at)
      require_value "$1" "${2:-}"
      DRIVER_UPDATED_AT="$2"
      shift 2
      ;;
    --driver-mandatory)
      require_value "$1" "${2:-}"
      DRIVER_MANDATORY="$2"
      shift 2
      ;;
    --base-url)
      require_value "$1" "${2:-}"
      BASE_URL="$2"
      shift 2
      ;;
    --restart-mode)
      require_value "$1" "${2:-}"
      RESTART_MODE="$2"
      shift 2
      ;;
    --help|-h)
      SHOW_HELP="true"
      shift
      ;;
    *)
      echo "Opción no reconocida: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "${SHOW_HELP}" == "true" ]]; then
  usage
  exit 0
fi

if [[ -z "${PASSENGER_APK}" && -z "${DRIVER_APK}" ]]; then
  echo "Debes indicar al menos un APK: pasajero o conductor." >&2
  usage
  exit 1
fi

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

normalize_bool() {
  local raw="$1"
  case "${raw,,}" in
    true|1|yes|si|sí) echo "true" ;;
    false|0|no) echo "false" ;;
    *)
      echo "Valor booleano inválido: ${raw}" >&2
      exit 1
      ;;
  esac
}

validate_app_inputs() {
  local app_name="$1"
  local apk_path="$2"
  local version="$3"
  local build="$4"

  if [[ -n "${apk_path}" ]]; then
    [[ -f "${apk_path}" ]] || { echo "No existe el APK de ${app_name}: ${apk_path}" >&2; exit 1; }
    [[ -n "${version}" ]] || { echo "Falta --${app_name}-version" >&2; exit 1; }
    [[ -n "${build}" ]] || { echo "Falta --${app_name}-build" >&2; exit 1; }
    [[ "${build}" =~ ^[0-9]+$ ]] || { echo "Build inválido para ${app_name}: ${build}" >&2; exit 1; }
  fi
}

validate_app_inputs "passenger" "${PASSENGER_APK}" "${PASSENGER_VERSION}" "${PASSENGER_BUILD}"
validate_app_inputs "driver" "${DRIVER_APK}" "${DRIVER_VERSION}" "${DRIVER_BUILD}"

PASSENGER_MANDATORY="$(normalize_bool "${PASSENGER_MANDATORY}")"
DRIVER_MANDATORY="$(normalize_bool "${DRIVER_MANDATORY}")"

NOW_UTC="$(timestamp_utc)"
PASSENGER_UPDATED_AT="${PASSENGER_UPDATED_AT:-$NOW_UTC}"
DRIVER_UPDATED_AT="${DRIVER_UPDATED_AT:-$NOW_UTC}"
PASSENGER_RELEASED_AT="${PASSENGER_RELEASED_AT:-$PASSENGER_UPDATED_AT}"
DRIVER_RELEASED_AT="${DRIVER_RELEASED_AT:-$DRIVER_UPDATED_AT}"

copy_apk() {
  local source_apk="$1"
  local target_dir="$2"
  local target_name="$3"

  mkdir -p "${target_dir}"
  cp "${source_apk}" "${target_dir}/${target_name}"
}

if [[ -n "${PASSENGER_APK}" ]]; then
  copy_apk \
    "${PASSENGER_APK}" \
    "${DOWNLOADS_ROOT}/passenger/android/${PASSENGER_VERSION}" \
    "rapigo-passenger.apk"
fi

if [[ -n "${DRIVER_APK}" ]]; then
  copy_apk \
    "${DRIVER_APK}" \
    "${DOWNLOADS_ROOT}/driver/android/${DRIVER_VERSION}" \
    "rapigo-driver-pro.apk"
fi

MANIFEST_BACKUP="${MANIFEST_PATH}.bak.$(date -u +%Y%m%d%H%M%S)"
cp "${MANIFEST_PATH}" "${MANIFEST_BACKUP}"

export MANIFEST_PATH
export BASE_URL
export PASSENGER_APK
export PASSENGER_VERSION
export PASSENGER_BUILD
export PASSENGER_RELEASED_AT
export PASSENGER_UPDATED_AT
export PASSENGER_MANDATORY
export DRIVER_APK
export DRIVER_VERSION
export DRIVER_BUILD
export DRIVER_RELEASED_AT
export DRIVER_UPDATED_AT
export DRIVER_MANDATORY

node <<'EOF'
const fs = require("fs");

const manifestPath = process.env.MANIFEST_PATH;
const baseUrl = String(process.env.BASE_URL || "").replace(/\/+$/, "");

const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
manifest.apps ??= {};
manifest.apps.rapigo_passenger ??= {};
manifest.apps.rapigo_passenger.android ??= {};
manifest.apps.rapigo_driver_pro ??= {};
manifest.apps.rapigo_driver_pro.android ??= {};

function updatePassenger() {
  if (!process.env.PASSENGER_APK) return;
  manifest.apps.rapigo_passenger.android = {
    ...manifest.apps.rapigo_passenger.android,
    version: process.env.PASSENGER_VERSION,
    buildNumber: Number(process.env.PASSENGER_BUILD),
    releasedAt: process.env.PASSENGER_RELEASED_AT,
    updatedAt: process.env.PASSENGER_UPDATED_AT,
    mandatory: process.env.PASSENGER_MANDATORY === "true",
    title: "Actualizacion disponible",
    message: "Hay una nueva version de RAPIGO disponible para instalar.",
    apkUrl: `${baseUrl}/downloads/passenger/android/${process.env.PASSENGER_VERSION}/rapigo-passenger.apk`,
    notes: [
      "Mejoras de estabilidad",
      "Optimizacion de mapas",
      "Correcciones generales",
    ],
  };
}

function updateDriver() {
  if (!process.env.DRIVER_APK) return;
  manifest.apps.rapigo_driver_pro.android = {
    ...manifest.apps.rapigo_driver_pro.android,
    version: process.env.DRIVER_VERSION,
    buildNumber: Number(process.env.DRIVER_BUILD),
    releasedAt: process.env.DRIVER_RELEASED_AT,
    updatedAt: process.env.DRIVER_UPDATED_AT,
    mandatory: process.env.DRIVER_MANDATORY === "true",
    title: "Actualizacion disponible",
    message: "Hay una nueva version de RAPIGO PRO disponible para instalar.",
    apkUrl: `${baseUrl}/downloads/driver/android/${process.env.DRIVER_VERSION}/rapigo-driver-pro.apk`,
    notes: [
      "Mejoras de rendimiento",
      "Optimizacion offline",
      "Correcciones del flujo operativo",
    ],
  };
}

updatePassenger();
updateDriver();

fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
EOF

run_restart() {
  case "${RESTART_MODE}" in
    reload-nginx)
      docker compose exec nginx nginx -s reload
      ;;
    restart-nginx)
      docker compose restart nginx
      ;;
    restart-gateway)
      docker compose restart gateway-api
      docker compose exec nginx nginx -s reload
      ;;
    restart-all)
      docker compose restart gateway-api nginx
      ;;
    none)
      ;;
    *)
      echo "restart-mode inválido: ${RESTART_MODE}" >&2
      exit 1
      ;;
  esac
}

run_restart

echo ""
echo "Despliegue completado."
echo "Backup del manifest: ${MANIFEST_BACKUP}"
echo ""

if [[ -n "${PASSENGER_APK}" ]]; then
  echo "Pasajero:"
  echo "  APK: ${DOWNLOADS_ROOT}/passenger/android/${PASSENGER_VERSION}/rapigo-passenger.apk"
  echo "  URL: ${BASE_URL}/downloads/passenger/android/${PASSENGER_VERSION}/rapigo-passenger.apk"
  echo "  Manifest: ${BASE_URL}/api/app-updates/manifest/rapigo_passenger/android"
  echo ""
fi

if [[ -n "${DRIVER_APK}" ]]; then
  echo "Conductor:"
  echo "  APK: ${DOWNLOADS_ROOT}/driver/android/${DRIVER_VERSION}/rapigo-driver-pro.apk"
  echo "  URL: ${BASE_URL}/downloads/driver/android/${DRIVER_VERSION}/rapigo-driver-pro.apk"
  echo "  Manifest: ${BASE_URL}/api/app-updates/manifest/rapigo_driver_pro/android"
  echo ""
fi

echo "Verificación recomendada:"
echo "  curl -I ${BASE_URL}/health"
if [[ -n "${PASSENGER_APK}" ]]; then
  echo "  curl -I ${BASE_URL}/downloads/passenger/android/${PASSENGER_VERSION}/rapigo-passenger.apk"
  echo "  curl ${BASE_URL}/api/app-updates/manifest/rapigo_passenger/android"
fi
if [[ -n "${DRIVER_APK}" ]]; then
  echo "  curl -I ${BASE_URL}/downloads/driver/android/${DRIVER_VERSION}/rapigo-driver-pro.apk"
  echo "  curl ${BASE_URL}/api/app-updates/manifest/rapigo_driver_pro/android"
fi
