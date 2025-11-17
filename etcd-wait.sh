#!/bin/sh
set -e

DB_FILE="/bitnami/etcd/data/member/snap/db"
MAX_WAIT=120   # seconds to try waiting

echo "Waiting for etcd db file to become available: $DB_FILE"

# Ensure directory exists; etcd does not create it until first run
mkdir -p "$(dirname "$DB_FILE")"

SECONDS_WAITED=0
while true; do
    # Try to acquire a non-blocking flock on the db file
    if flock -n "$DB_FILE" true 2>/dev/null; then
        echo "DB file is ready. Proceeding."
        break
    fi

    echo "DB still locked or not ready... waited ${SECONDS_WAITED}s"
    sleep 2
    SECONDS_WAITED=$((SECONDS_WAITED+2))

    if [ "$SECONDS_WAITED" -ge "$MAX_WAIT" ]; then
        echo "ERROR: DB file did not become ready after ${MAX_WAIT}s"
        exit 1
    fi
done

# Now call your existing entrypoint
exec /tmp/entrypoint.sh "$@"
