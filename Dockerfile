# syntax=docker/dockerfile:1

# Official SQL Server image tag (optionally pinned by digest): mcr.microsoft.com/mssql/server:<version>-latest for the
# version scripts/fetch.sh staged the files for, as a backup restores only on its own version or later.
ARG BASE_IMAGE=mcr.microsoft.com/mssql/server:2025-latest

FROM ${BASE_IMAGE}

# One sample database's backup or scripts, staged into ./downloads/image by scripts/fetch.sh before building.
# --chmod applies to the directories COPY creates as well, which need the x bit to be entered, hence 0555 throughout.
COPY --chmod=0555 downloads/image/files/ /opt/sample-databases/files/
COPY --chmod=0555 entrypoint/ /opt/sample-databases/
# database.env names the database and its files for the loader. The sample databases are Microsoft's under the MIT
# License, whose notice must accompany every copy.
COPY --chmod=0444 downloads/image/database.env downloads/image/LICENSE /opt/sample-databases/

HEALTHCHECK --interval=5s --timeout=10s --start-period=30s --retries=60 CMD ["/opt/sample-databases/healthcheck.sh"]

ENTRYPOINT ["/opt/sample-databases/entrypoint.sh"]
CMD ["/opt/mssql/bin/sqlservr"]

LABEL org.opencontainers.image.title="SQL Server with a Microsoft sample database" \
      org.opencontainers.image.description="Official SQL Server image that loads one of Microsoft's sample databases on first start" \
      org.opencontainers.image.source="https://github.com/jinahya/sql-server-samples-docker" \
      org.opencontainers.image.url="https://github.com/microsoft/sql-server-samples/tree/master/samples/databases" \
      org.opencontainers.image.licenses="MIT AND LicenseRef-Microsoft-SQL-Server-EULA"
