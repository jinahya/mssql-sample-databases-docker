#!/usr/bin/env bash
# Usage: scripts/smoke-test.sh <image> [timeout-seconds]
# Starts the image, waits for it to report healthy, checks the three databases, removes everything.
set -Eeuo pipefail

image=${1:?image reference}
timeout=${2:-900}
name="mssql-sample-databases-smoke-$$"
password='Smoke-test-1'

cleanup() { docker rm -f -v "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$name" --platform linux/amd64 -e MSSQL_SA_PASSWORD="$password" "$image" >/dev/null
echo "smoke-test: started $name from $image, waiting up to ${timeout}s for the load"

start=$(date +%s)
until [ "$(docker inspect -f '{{.State.Health.Status}}' "$name")" = "healthy" ]; do
  if [ "$(docker inspect -f '{{.State.Running}}' "$name")" != "true" ]; then
    echo "smoke-test: container exited during load" >&2
    docker logs "$name" 2>&1 | tail -50 >&2
    exit 1
  fi
  if (( $(date +%s) - start > timeout )); then
    echo "smoke-test: timed out" >&2
    docker logs "$name" 2>&1 | tail -50 >&2
    exit 1
  fi
  sleep 5
done
echo "smoke-test: healthy after $(( $(date +%s) - start ))s"

q() {
  docker exec "$name" /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$password" -b -h -1 -W \
    -Q "SET NOCOUNT ON; $1" | tr -d '[:space:]'
}
persons=$(q "SELECT count(*) FROM AdventureWorks.Person.Person")
orders=$(q "SELECT count(*) FROM WideWorldImporters.Sales.Orders")
items=$(q "SELECT count(*) FROM FutonManufacturing.dbo.Items")
echo "smoke-test: AdventureWorks.Person.Person=${persons} WideWorldImporters.Sales.Orders=${orders}" \
     "FutonManufacturing.dbo.Items=${items}"
[ "${persons:-0}" -gt 0 ] && [ "${orders:-0}" -gt 0 ] && [ "${items:-0}" -gt 0 ] \
  || { echo "smoke-test: a sample table is empty" >&2; exit 1; }
echo "smoke-test: OK"
