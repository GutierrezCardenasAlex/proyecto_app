#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEPLOY_SCRIPT="${SCRIPT_DIR}/deploy-updates.sh"

BASE_URL="${BASE_URL:-https://rapigo.cybernovatech.space}"
RESTART_MODE="${RESTART_MODE:-reload-nginx}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
BUILD_ROOT="${BUILD_ROOT:-${PROJECT_ROOT}/build/releases}"
TARGET="${TARGET:-both}"
RELEASED_AT="${RELEASED_AT:-}"
UPDATED_AT="${UPDATED_AT:-}"
MANDATORY="${MANDATORY:-false}"
SKIP_PUB_GET="${SKIP_PUB_GET:-false}"
SKIP_DEPLOY="${SKIP_DEPLOY:-false}"

PASSENGER_BUILD_NAME=""
PASSENGER_BUILD_NUMBER=""
DRIVER_BUILD_NAME=""
DRIVER_BUILD_NUMBER=""

usage() {
  cat <<'EOF'
Uso:
  ./scripts/release.sh [opciones]

Opciones:
  --target passenger|driver|both
  --base-url URL
  --restart-mode reload-nginx|restart-nginx|restart-gateway|restart-all|none
  --flutter-bin PATH_O_COMANDO
  --build-root PATH
  --released-at ISO_DATE
  --updated-at ISO_DATE
  --mandatory true|false
  --skip-pub-get
  --skip-deploy

Overrides de version:
  --passenger-build-name VERSION
  --passenger-build-number BUILD
  --driver-build-name VERSION
  --driver-build-number BUILD

Ejemplos:
  ./scripts/release.sh

  ./scripts/release.sh \
    --target driver \
    --driver-build-name 1.0.2 \
    --driver-build-number 3 \
    --released-at 2026-07-08T00:00:00Z

Notas:
  - Por defecto construye pasajero y conductor.
  - Si no mandas version/build, los toma de cada pubspec.yaml.
  - Al final llama automaticamente a deploy-updates.sh.
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
    --target)
      require_value "$1" "${2:-}"
      TARGET="$2"
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
    --flutter-bin)
      require_value "$1" "${2:-}"
      FLUTTER_BIN="$2"
      shift 2
      ;;
    --build-root)
      require_value "$1" "${2:-}"
      BUILD_ROOT="$2"
      shift 2
      ;;
    --released-at)
      require_value "$1" "${2:-}"
      RELEASED_AT="$2"
      shift 2
      ;;
    --updated-at)
      require_value "$1" "${2:-}"
      UPDATED_AT="$2"
      shift 2
      ;;
    --mandatory)
      require_value "$1" "${2:-}"
      MANDATORY="$2"
      shift 2
      ;;
    --skip-pub-get)
      SKIP_PUB_GET="true"
      shift
      ;;
    --skip-deploy)
      SKIP_DEPLOY="true"
      shift
      ;;
    --passenger-build-name)
      require_value "$1" "${2:-}"
      PASSENGER_BUILD_NAME="$2"
      shift 2
      ;;
    --passenger-build-number)
      require_value "$1" "${2:-}"
      PASSENGER_BUILD_NUMBER="$2"
      shift 2
      ;;
    --driver-build-name)
      require_value "$1" "${2:-}"
      DRIVER_BUILD_NAME="$2"
      shift 2
      ;;
    --driver-build-number)
      require_value "$1" "${2:-}"
      DRIVER_BUILD_NUMBER="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Opción no reconocida: $1" >&2
      usage
      exit 1
      ;;
  esac
done

case "${TARGET}" in
  passenger|driver|both)
    ;;
  *)
    echo "Target inválido: ${TARGET}" >&2
    exit 1
    ;;
esac

command -v "${FLUTTER_BIN}" >/dev/null 2>&1 || {
  echo "No se encontro Flutter: ${FLUTTER_BIN}" >&2
  exit 1
}

[[ -x "${DEPLOY_SCRIPT}" || -f "${DEPLOY_SCRIPT}" ]] || {
  echo "No existe deploy-updates.sh en ${DEPLOY_SCRIPT}" >&2
  exit 1
}

read_version_from_pubspec() {
  local pubspec="$1"
  local version_line
  version_line="$(grep -E '^version:' "${pubspec}" | head -n 1 | sed 's/^version:[[:space:]]*//')"
  if [[ -z "${version_line}" ]]; then
    echo "No se pudo leer version desde ${pubspec}" >&2
    exit 1
  fi
  echo "${version_line}"
}

split_version_parts() {
  local version_line="$1"
  local name_part="${version_line%%+*}"
  local build_part="${version_line##*+}"
  echo "${name_part}|${build_part}"
}

prepare_app_versions() {
  local app_dir="$1"
  local build_name_var="$2"
  local build_number_var="$3"

  local current_name="${!build_name_var}"
  local current_number="${!build_number_var}"

  if [[ -n "${current_name}" && -n "${current_number}" ]]; then
    return
  fi

  local version_line
  version_line="$(read_version_from_pubspec "${app_dir}/pubspec.yaml")"
  local parsed
  parsed="$(split_version_parts "${version_line}")"
  local parsed_name="${parsed%%|*}"
  local parsed_number="${parsed##*|}"

  if [[ -z "${current_name}" ]]; then
    printf -v "${build_name_var}" '%s' "${parsed_name}"
  fi
  if [[ -z "${current_number}" ]]; then
    printf -v "${build_number_var}" '%s' "${parsed_number}"
  fi
}

run_flutter_build() {
  local app_dir="$1"
  local build_name="$2"
  local build_number="$3"

  pushd "${app_dir}" >/dev/null
  if [[ "${SKIP_PUB_GET}" != "true" ]]; then
    "${FLUTTER_BIN}" pub get
  fi
  "${FLUTTER_BIN}" build apk --release --build-name="${build_name}" --build-number="${build_number}"
  popd >/dev/null
}

copy_release_artifact() {
  local source_apk="$1"
  local target_path="$2"
  mkdir -p "$(dirname "${target_path}")"
  cp "${source_apk}" "${target_path}"
}

PASSENGER_APP_DIR="${PROJECT_ROOT}/mobile/rapigo_passenger"
DRIVER_APP_DIR="${PROJECT_ROOT}/mobile/rapigo_driver_pro"

if [[ "${TARGET}" == "passenger" || "${TARGET}" == "both" ]]; then
  prepare_app_versions "${PASSENGER_APP_DIR}" PASSENGER_BUILD_NAME PASSENGER_BUILD_NUMBER
fi

if [[ "${TARGET}" == "driver" || "${TARGET}" == "both" ]]; then
  prepare_app_versions "${DRIVER_APP_DIR}" DRIVER_BUILD_NAME DRIVER_BUILD_NUMBER
fi

PASSENGER_RELEASE_APK=""
DRIVER_RELEASE_APK=""

if [[ "${TARGET}" == "passenger" || "${TARGET}" == "both" ]]; then
  echo ""
  echo "Construyendo RAPIGO pasajero ${PASSENGER_BUILD_NAME}+${PASSENGER_BUILD_NUMBER}"
  run_flutter_build "${PASSENGER_APP_DIR}" "${PASSENGER_BUILD_NAME}" "${PASSENGER_BUILD_NUMBER}"
  PASSENGER_RELEASE_APK="${BUILD_ROOT}/passenger/${PASSENGER_BUILD_NAME}/rapigo-passenger.apk"
  copy_release_artifact \
    "${PASSENGER_APP_DIR}/build/app/outputs/flutter-apk/app-release.apk" \
    "${PASSENGER_RELEASE_APK}"
fi

if [[ "${TARGET}" == "driver" || "${TARGET}" == "both" ]]; then
  echo ""
  echo "Construyendo RAPIGO PRO conductor ${DRIVER_BUILD_NAME}+${DRIVER_BUILD_NUMBER}"
  run_flutter_build "${DRIVER_APP_DIR}" "${DRIVER_BUILD_NAME}" "${DRIVER_BUILD_NUMBER}"
  DRIVER_RELEASE_APK="${BUILD_ROOT}/driver/${DRIVER_BUILD_NAME}/rapigo-driver-pro.apk"
  copy_release_artifact \
    "${DRIVER_APP_DIR}/build/app/outputs/flutter-apk/app-release.apk" \
    "${DRIVER_RELEASE_APK}"
fi

if [[ "${SKIP_DEPLOY}" == "true" ]]; then
  echo ""
  echo "Build completado. Se omitió el despliegue."
  [[ -n "${PASSENGER_RELEASE_APK}" ]] && echo "Passenger APK: ${PASSENGER_RELEASE_APK}"
  [[ -n "${DRIVER_RELEASE_APK}" ]] && echo "Driver APK: ${DRIVER_RELEASE_APK}"
  exit 0
fi

DEPLOY_ARGS=(
  --base-url "${BASE_URL}"
  --restart-mode "${RESTART_MODE}"
)

if [[ -n "${RELEASED_AT}" ]]; then
  DEPLOY_ARGS+=(--passenger-released-at "${RELEASED_AT}" --driver-released-at "${RELEASED_AT}")
fi

if [[ -n "${UPDATED_AT}" ]]; then
  DEPLOY_ARGS+=(--passenger-updated-at "${UPDATED_AT}" --driver-updated-at "${UPDATED_AT}")
fi

if [[ "${TARGET}" == "passenger" || "${TARGET}" == "both" ]]; then
  DEPLOY_ARGS+=(
    --passenger-apk "${PASSENGER_RELEASE_APK}"
    --passenger-version "${PASSENGER_BUILD_NAME}"
    --passenger-build "${PASSENGER_BUILD_NUMBER}"
    --passenger-mandatory "${MANDATORY}"
  )
fi

if [[ "${TARGET}" == "driver" || "${TARGET}" == "both" ]]; then
  DEPLOY_ARGS+=(
    --driver-apk "${DRIVER_RELEASE_APK}"
    --driver-version "${DRIVER_BUILD_NAME}"
    --driver-build "${DRIVER_BUILD_NUMBER}"
    --driver-mandatory "${MANDATORY}"
  )
fi

echo ""
echo "Ejecutando despliegue..."
"${DEPLOY_SCRIPT}" "${DEPLOY_ARGS[@]}"
