#!/usr/bin/env bash
# Smoke test used by the CD pipeline after each environment deployment.
# Le déploiement Coolify est asynchrone (le conteneur met quelques
# secondes à démarrer après le déclenchement) : on retente pendant
# jusqu'à 2 minutes avant de déclarer l'échec.
# Usage: smoke_test.sh <base_url>
set -uo pipefail

BASE_URL="${1:?Usage: smoke_test.sh <base_url>}"
MAX_ATTEMPTS=24
SLEEP_SECONDS=5

echo "Smoke test against ${BASE_URL}"

for attempt in $(seq 1 "${MAX_ATTEMPTS}"); do
  status=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 10 "${BASE_URL}/" 2>/dev/null)

  if [ "${status}" = "200" ]; then
    echo "OK: ${BASE_URL}/ returned HTTP 200 (attempt ${attempt}/${MAX_ATTEMPTS})"
    exit 0
  fi

  echo "Attempt ${attempt}/${MAX_ATTEMPTS}: HTTP ${status:-000}, retrying in ${SLEEP_SECONDS}s..."
  sleep "${SLEEP_SECONDS}"
done

echo "FAIL: ${BASE_URL}/ did not return HTTP 200 after ${MAX_ATTEMPTS} attempts"
exit 1
