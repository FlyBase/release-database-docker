FROM postgres:13

# Tools used by the dump-load script
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Defaults for the postgres official entrypoint:
# POSTGRES_HOST_AUTH_METHOD=trust → no superuser password required
# POSTGRES_DB=postgres            → default db at initdb time
ENV POSTGRES_HOST_AUTH_METHOD=trust \
    POSTGRES_DB=postgres \
    PGDATA=/var/lib/postgresql/data

EXPOSE 5432
