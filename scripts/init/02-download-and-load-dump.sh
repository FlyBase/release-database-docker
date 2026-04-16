#!/usr/bin/env bash
# scripts/init/02-download-and-load-dump.sh
# Downloads the FlyBase Chado release dump from s3ftp.flybase.org and loads it
# into the flybase database. Runs once on a fresh data dir via initdb.d.
#
# Env vars:
#   RELEASE       - Release directory under /releases/ (default: current)
#   RELEASE_FILE  - Optional: skip index.html parsing, use this filename
#   DUMP_DIR      - Where to cache the downloaded dump (default: /tmp/dump)
#   S3FTP_BASE    - Base URL (default: https://s3ftp.flybase.org)

set -euo pipefail

RELEASE="${RELEASE:-current}"
DUMP_DIR="${DUMP_DIR:-/tmp/dump}"
S3FTP_BASE="${S3FTP_BASE:-https://s3ftp.flybase.org}"
S3FTP_URL="${S3FTP_BASE}/releases/${RELEASE}/psql"

mkdir -p "$DUMP_DIR"

# --- Resolve filename ---
if [[ -n "${RELEASE_FILE:-}" ]]; then
    FILENAME="$RELEASE_FILE"
    echo "[chado-load] Using RELEASE_FILE=$FILENAME"
else
    echo "[chado-load] Resolving dump filename from $S3FTP_URL/index.html"
    FILENAME=$(curl -fsSL "$S3FTP_URL/index.html" \
        | grep -oE 'FB[0-9_]+\.sql\.gz' \
        | head -1)
    if [[ -z "$FILENAME" ]]; then
        echo "[chado-load] ERROR: could not resolve dump filename for RELEASE=$RELEASE" >&2
        exit 1
    fi
    echo "[chado-load] Resolved filename: $FILENAME"
fi

DUMP_PATH="$DUMP_DIR/$FILENAME"

# --- Download (skip if already present) ---
if [[ -f "$DUMP_PATH" ]]; then
    echo "[chado-load] Dump already present at $DUMP_PATH, skipping download"
else
    echo "[chado-load] Downloading $FILENAME from $S3FTP_URL/"
    curl -fL --progress-bar -o "${DUMP_PATH}.tmp" "$S3FTP_URL/$FILENAME"
    mv "${DUMP_PATH}.tmp" "$DUMP_PATH"
    echo "[chado-load] Download complete: $(du -h "$DUMP_PATH" | cut -f1)"
fi

# --- Load into flybase database ---
echo "[chado-load] Loading $FILENAME into flybase database (this takes a while)..."
gunzip -c "$DUMP_PATH" | psql -v ON_ERROR_STOP=1 -U postgres -d flybase

# --- Vacuum for fresh stats ---
echo "[chado-load] Running vacuumdb -z on flybase..."
vacuumdb -z -U postgres flybase

# --- Sentinel: written ONLY after a clean load + vacuum.
# The healthcheck refuses to report healthy without this file. If the
# container is killed mid-load, the sentinel won't exist on next start,
# so a half-loaded volume can't masquerade as ready.
SENTINEL="${PGDATA}/.flybase-loaded"
echo "${RELEASE}/${FILENAME}" > "$SENTINEL"
echo "[chado-load] Sentinel written: $SENTINEL"

echo "[chado-load] Done. FlyBase Chado release loaded: $RELEASE/$FILENAME"
