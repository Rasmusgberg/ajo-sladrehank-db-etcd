#!/bin/sh

echo "=== etcd Container Starting on EC2 (Direct Docker) ==="

# --- Configuration ---
IP="10.0.80.233"
DATA_DIR="/bitnami/etcd/data"
ETCD_DB_FILE="$DATA_DIR/member/snap/db"

echo "Using EC2 private IP: $IP"
echo "Data directory: $DATA_DIR"

# --- Cluster State Check ---
CLUSTER_STATE="new"
if [ -d "$DATA_DIR/member" ]; then
    echo "Existing etcd data found in $DATA_DIR"
    echo "Setting cluster state to 'existing' to preserve data"
    CLUSTER_STATE="existing"
    
    echo "Data directory contents:"
    ls -lah "$DATA_DIR"
    du -sh "$DATA_DIR"

    # --- NEW: Pre-warm EBS Volume ---
    echo "Pre-warming EBS volume by reading etcd db file..."
    if [ -f "$ETCD_DB_FILE" ]; then
        # This reads the entire file and discards the output,
        # forcing EBS to load all the blocks.
        echo "Reading $ETCD_DB_FILE to pre-warm..."
        cat "$ETCD_DB_FILE" > /dev/null
        echo "Pre-warm complete."
    else
        echo "No existing db file found ($ETCD_DB_FILE), skipping pre-warm."
    fi
    # --- End Pre-warm ---

else
    echo "No existing data found, starting fresh cluster"
    CLUSTER_STATE="new"
fi

# Ensure data directory exists with correct permissions
mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"

# --- etcd Configuration ---
echo "=== etcd Configuration ==="
echo "  Name: ajo-sladrehank-etcd"
echo "  IP Address: $IP"
echo "  Client URL: http://$IP:2379"
echo "  Peer URL: http://$IP:2380"
echo "  Data Directory: $DATA_DIR"
echo "  Cluster State: $CLUSTER_STATE"
echo "  Quota: 2GB"

echo "=== Starting etcd with pre-warming and retry loop ==="

# --- Start etcd with Retry Loop ---
# Now that 'set -e' is gone, this loop will work as intended.
until /usr/local/bin/etcd \
  --name="ajo-sladrehank-etcd" \
  --data-dir="$DATA_DIR" \
  --initial-advertise-peer-urls="http://$IP:2380" \
  --listen-peer-urls="http://0.0.0.0:2380" \
  --advertise-client-urls="http://$IP:2379" \
  --listen-client-urls="http://0.0.0.0:2379" \
  --initial-cluster="ajo-sladrehank-etcd=http://$IP:2380" \
  --initial-cluster-token="ajo-sladrehank-cluster" \
  --initial-cluster-state="$CLUSTER_STATE" \
  --quota-backend-bytes=2147483648 \
  --log-level="info" \
  --max-txn-ops=10000 \
  --max-request-bytes=10485760
do
    # You should see this message in your logs now
    echo "etcd failed to start (exit code $?). Retrying in 5 seconds..."
    sleep 5
done