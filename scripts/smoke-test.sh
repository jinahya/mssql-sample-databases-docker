#!/usr/bin/env bash
# Usage: scripts/smoke-test.sh <image> [timeout-seconds]
# Starts the image, waits for it to report healthy, checks that its database has tables with rows, restarts it and
# checks that the database comes back online, then removes everything.
set -Eeuo pipefail

image=${1:?image reference}
timeout=${2:-900}
name="sql-server-samples-smoke-$$"
password='Smoke-test-1'

cleanup() { docker rm -f -v "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# wait_healthy <what>: fails when the container exits or the timeout passes first
wait_healthy() {
  local start=$(date +%s)
  until [ "$(docker inspect -f '{{.State.Health.Status}}' "$name")" = "healthy" ]; do
    if [ "$(docker inspect -f '{{.State.Running}}' "$name")" != "true" ]; then
      echo "smoke-test: container exited during $1" >&2
      docker logs "$name" 2>&1 | tail -50 >&2
      exit 1
    fi
    if (( $(date +%s) - start > timeout )); then
      echo "smoke-test: timed out during $1" >&2
      docker logs "$name" 2>&1 | tail -50 >&2
      exit 1
    fi
    sleep 5
  done
  echo "smoke-test: healthy after $1 in $(( $(date +%s) - start ))s"
}

docker run -d --name "$name" --platform linux/amd64 -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD="$password" "$image" >/dev/null
echo "smoke-test: started $name from $image, waiting up to ${timeout}s for the load"
wait_healthy load

# 2017 has only the old tools, which do not know -C (trust the server certificate)
tools=$(docker exec "$name" sh -c 'ls -d /opt/mssql-tools18 /opt/mssql-tools 2>/dev/null | head -1')
q() {
  docker exec "$name" "${tools}/bin/sqlcmd" $([ "$tools" = /opt/mssql-tools18 ] && echo -C) \
    -S localhost -U sa -P "$password" -b -h -1 -W -s '|' -d "$database" -Q "SET NOCOUNT ON; $1" | tr -d '\r'
}
database=$(docker exec "$name" sh -c '. /opt/sample-databases/database.env && echo "$SAMPLE_DATABASE_NAME"')
IFS='|' read -r compat tables rows < <(q "SELECT
  (SELECT compatibility_level FROM sys.databases WHERE name = DB_NAME()),
  (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0),
  (SELECT SUM(p.rows) FROM sys.partitions p JOIN sys.tables t ON t.object_id = p.object_id
    WHERE p.index_id IN (0, 1) AND t.is_ms_shipped = 0)")
echo "smoke-test: ${database}: compatibility level ${compat}, ${tables} tables, ${rows} rows"
[ "${tables:-0}" -gt 0 ] && [ "${rows:-0}" -gt 0 ] || { echo "smoke-test: ${database} is empty" >&2; exit 1; }

docker restart "$name" >/dev/null
wait_healthy restart
q "SELECT 1" >/dev/null || { echo "smoke-test: ${database} is not online after the restart" >&2; exit 1; }
echo "smoke-test: OK"
