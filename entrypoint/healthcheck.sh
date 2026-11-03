#!/usr/bin/env bash
# Healthy once the loader has finished and the server answers.
set -Eeuo pipefail

[ -f /var/opt/mssql/.sample-databases-loaded ]
# 2017 has only the old tools, which do not know -C (trust the server certificate)
if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then
  /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -b -Q "SELECT 1" >/dev/null
else
  /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -b -Q "SELECT 1" >/dev/null
fi
