#!/usr/bin/env bash
# scripts/healthcheck.sh
# Used by Docker HEALTHCHECK. Refuses healthy until:
#   1. the load-complete sentinel exists in PGDATA,
#   2. postgres accepts TCP connections (not just unix socket),
#   3. the flybase role can connect via TCP,
#   4. the public schema has the expected number of tables.

set -euo pipefail

PGDATA="${PGDATA:-/var/lib/postgresql/data}"
SENTINEL="${PGDATA}/.flybase-loaded"

# 1. Sentinel must exist (proves load + vacuum completed cleanly)
if [[ ! -f "$SENTINEL" ]]; then
    echo "Healthcheck: sentinel $SENTINEL missing — load not complete" >&2
    exit 1
fi

# 2. TCP readiness (not unix socket — that came up earlier during init)
pg_isready -h 127.0.0.1 -p 5432 -U postgres -d flybase >/dev/null || exit 1

# 3. flybase role can connect over TCP
psql -h 127.0.0.1 -U flybase -d flybase -c "SELECT 1" >/dev/null || exit 1

# 4. public schema has tables (defense in depth)
COUNT=$(psql -h 127.0.0.1 -tA -U postgres -d flybase -c \
    "SELECT count(*) FROM pg_tables WHERE schemaname='public'")
if [[ "$COUNT" -lt 100 ]]; then
    echo "Healthcheck: only $COUNT tables in public schema (expected ~196)" >&2
    exit 1
fi

exit 0
