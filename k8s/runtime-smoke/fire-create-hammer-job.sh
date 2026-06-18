#!/bin/sh
set -eu

API_HOST="${KUBERNETES_SERVICE_HOST:?missing KUBERNETES_SERVICE_HOST}"
API_PORT="${KUBERNETES_SERVICE_PORT_HTTPS:-${KUBERNETES_SERVICE_PORT:-443}}"
API="https://${API_HOST}:${API_PORT}"
TOKEN_PATH="/var/run/secrets/kubernetes.io/serviceaccount/token"
CA_PATH="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
JOB_PATH="${DOKKAEBI_HAMMER_JOB_PATH:-/config/hammer-job.json}"
RESPONSE_PATH="/tmp/fire-create-response.json"

if [ ! -r "$TOKEN_PATH" ]; then
  echo "fire_smoke_error=missing_service_account_token" >&2
  exit 65
fi

if [ ! -r "$CA_PATH" ]; then
  echo "fire_smoke_error=missing_service_account_ca" >&2
  exit 65
fi

if [ ! -r "$JOB_PATH" ]; then
  echo "fire_smoke_error=missing_hammer_job_payload" >&2
  exit 66
fi

TOKEN="$(cat "$TOKEN_PATH")"
STATUS="$(
  curl \
    --silent \
    --show-error \
    --output "$RESPONSE_PATH" \
    --write-out "%{http_code}" \
    --cacert "$CA_PATH" \
    --header "Authorization: Bearer $TOKEN" \
    --header "Content-Type: application/json" \
    --request POST \
    --data-binary "@$JOB_PATH" \
    "$API/apis/batch/v1/namespaces/dokkaebi-workers/jobs"
)"

cat "$RESPONSE_PATH"
echo
echo "fire_smoke_http_status=$STATUS"

if [ "$STATUS" != "201" ]; then
  echo "fire_smoke_error=unexpected_create_status" >&2
  exit 67
fi

echo "fire_smoke_status=created_approved_hammer_job"
