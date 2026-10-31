#!/usr/bin/env bash
# Healthy once the loader has finished and the server answers.
set -Eeuo pipefail

[ -f /var/opt/mssql/.sample-databases-loaded ]
/opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -b -Q "SELECT 1" >/dev/null
