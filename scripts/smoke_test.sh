#!/usr/bin/env bash
# Smoke test used by the CD pipeline after each environment deployment.
# Usage: smoke_test.sh <base_url>
set -euo pipefail

BASE_URL="${1:?Usage: smoke_test.sh <base_url>}"

echo "Smoke test against ${BASE_URL}"

status=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 15 "${BASE_URL}/")

if [ "${status}" != "200" ]; then
  echo "FAIL: ${BASE_URL}/ returned HTTP ${status} (expected 200)"
  exit 1
fi

echo "OK: ${BASE_URL}/ returned HTTP 200"
