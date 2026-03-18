#!/usr/bin/env bash
set -euo pipefail

PHONE="${1:-+59170000000}"

echo "Solicitando OTP..."
OTP_RESPONSE="$(
  curl -fsS \
    -X POST http://localhost:3000/api/auth/otp/request \
    -H 'Content-Type: application/json' \
    -d "{
      \"phone\": \"$PHONE\",
      \"role\": \"passenger\",
      \"fullName\": \"Usuario Demo\"
    }"
)"

echo "$OTP_RESPONSE"
OTP="$(printf '%s' "$OTP_RESPONSE" | sed -n 's/.*"otp":"\([^"]*\)".*/\1/p')"

if [[ -z "$OTP" ]]; then
  echo "No se pudo extraer el OTP de la respuesta." >&2
  exit 1
fi

echo
echo "Verificando OTP..."
curl -fsS \
  -X POST http://localhost:3000/api/auth/otp/verify \
  -H 'Content-Type: application/json' \
  -d "{
    \"phone\": \"$PHONE\",
    \"otp\": \"$OTP\"
  }"

echo
