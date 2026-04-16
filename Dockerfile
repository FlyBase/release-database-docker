FROM postgres:13-bookworm

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

COPY config/postgresql.conf /etc/postgresql/postgresql.conf
COPY config/pg_hba.conf /etc/postgresql/pg_hba.conf
COPY scripts/init/ /docker-entrypoint-initdb.d/

EXPOSE 5432

CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]
