# FlyBase Release Database (Docker)

Run a local copy of the [FlyBase](https://flybase.org) Chado PostgreSQL database
from the public release dumps.

This image is the same one used to host `chado.flybase.org`. Running it locally
gives you faster queries, no shared rate limits, and the freedom to use any
release version.

## Quick start

```bash
git clone https://github.com/FlyBase/release-database-docker.git
cd release-database-docker
docker compose up -d
```

The first start downloads the release dump (~16 GB compressed) and loads it
into PostgreSQL. **This takes several hours.** The database and the cached
dump live in bind-mounted host directories (`./data` and `./dump-cache` by
default), so `docker compose down` will not delete them — data only goes
away when you `rm` the host directories.

Disk usage peaks at ~180 GB during load (cached dump + database + WAL).
Steady-state with the cached dump retained is ~172 GB; `rm -rf dump-cache`
drops it to ~156 GB.

Once running, connect with:

```bash
psql -h localhost flybase flybase
```

(no password — `trust` auth on the `flybase` role)

## Configuration

| Env var | Default | What it does |
|---|---|---|
| `RELEASE` | `current` | Which release to load (e.g. `FB2026_01`, `FB2025_05`) |
| `RELEASE_FILE` | *(auto-detected)* | Override the dump filename if you know it |
| `HOST_PORT` | `5432` | Host port to bind PostgreSQL to |
| `DATA_DIR` | `./data` | Host path for the PostgreSQL data directory (bind mount) |
| `DUMP_DIR` | `./dump-cache` | Host path for the downloaded dump cache (bind mount) |

Example: load a specific older release on a non-default port:

```bash
RELEASE=FB2025_05 HOST_PORT=5433 docker compose up -d
```

## Refreshing for a new release

The data and dump cache are bind-mounted host directories, so you delete them
yourself before the next load:

```bash
docker compose down
rm -rf data dump-cache
RELEASE=FB2026_02 docker compose up -d
```

## Read-only access

The database is configured for strict read-only use. The `flybase` role:

- Has `SELECT` on all loaded Chado tables
- Cannot `INSERT`, `UPDATE`, `DELETE`, or `TRUNCATE` any table
- Cannot create temporary tables
- Cannot create new schemas
- Cannot create new databases

Connect as `postgres` (no password, localhost only) if you need to make local
changes for your own analysis.

## Tuning for smaller machines

The shipped `config/postgresql.conf` is tuned for a host with ~32 GB RAM.
On a laptop with less memory you may want to lower:

- `shared_buffers` (currently `8GB` → try `2GB`)
- `effective_cache_size` (currently `24GB` → try `4GB`)
- `work_mem` (currently `100MB` → try `32MB`)
- `maintenance_work_mem` (currently `2GB` → try `512MB`)

Edit `config/postgresql.conf` and rebuild: `docker compose up -d --build`.

## Notes

- The dump is loaded with `autovacuum` and `fsync` disabled because the data
  is static and reload-able from the public S3 location. This dramatically
  speeds the initial load.
- Connection limit is `max_connections = 20`. Raise it in
  `config/postgresql.conf` if you need more.
- Health status: `docker inspect --format '{{.State.Health.Status}}' flybase-chado`

## Help

Open an issue on this repo, or email FlyBase via the contact form at
<https://flybase.org/contact/email>.
