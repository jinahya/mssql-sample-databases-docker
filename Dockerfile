# syntax=docker/dockerfile:1

# Official SQL Server image tag (optionally pinned by digest). AdventureWorks2025.bak needs SQL Server 2025 or later.
ARG BASE_IMAGE=mcr.microsoft.com/mssql/server:2025-latest

FROM ${BASE_IMAGE}

# The backups and scripts are downloaded into ./downloads by scripts/fetch.sh before building.
# --chmod applies to the directories COPY creates as well, which need the x bit to be entered, hence 0555 throughout.
COPY --chmod=0555 downloads/AdventureWorks2025.bak downloads/WideWorldImporters-Standard.bak /opt/sample-databases/
COPY --chmod=0555 downloads/futon-manufacturing/ /opt/sample-databases/futon-manufacturing/
COPY --chmod=0555 entrypoint/ /opt/sample-databases/
# The sample databases are Microsoft's under the MIT License, whose notice must accompany every copy.
COPY --chmod=0444 downloads/sql-server-samples-license.txt /opt/sample-databases/LICENSE

ENV ACCEPT_EULA=Y

HEALTHCHECK --interval=5s --timeout=10s --start-period=30s --retries=60 CMD ["/opt/sample-databases/healthcheck.sh"]

ENTRYPOINT ["/opt/sample-databases/entrypoint.sh"]
CMD ["/opt/mssql/bin/sqlservr"]

LABEL org.opencontainers.image.title="SQL Server with the Microsoft sample databases" \
      org.opencontainers.image.description="Official SQL Server image that loads AdventureWorks, WideWorldImporters and FutonManufacturing on first start" \
      org.opencontainers.image.source="https://github.com/jinahya/mssql-sample-databases-docker" \
      org.opencontainers.image.url="https://github.com/microsoft/sql-server-samples/tree/master/samples/databases" \
      org.opencontainers.image.licenses="MIT AND LicenseRef-Microsoft-SQL-Server-EULA"
