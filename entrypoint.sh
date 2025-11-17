#!/bin/sh
# NOTE: We have REMOVED 'set -e' to allow the retry loop to work.

echo "=== etcd Container Starting on EC2 (Direct Docker) ==="

# Use EC2 instance private IP
IP="10.0.80.233"
echo "Using EC2 private IP: $IP"

# Data directory
DATA_DIR="/bitnami/etcd/data"
echo "Data directory: $DATA_DIR"

# Check if data directory exists and has data
CLUSTER_STATE="new"
if [ -d "$DATA_DIR/member" ]; then
    echo "Existing etcd data found in $DATA_DIR"
    echo "Setting cluster state to 'existing' to preserve data"
    CLUSTER_STATE="existing"
    
    echo "Data directory contents:"
    ls -lah "$DATA_DIR"
    du -sh "$DATA_DIR"
else
    echo "No existing data found, starting fresh cluster"
    CLUSTER_STATE="new"
fi

# Ensure data directory exists with correct permissions
mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"

echo "=== etcd Configuration ==="
echo "  Name: ajo-sladrehank-etcd"
echo "  IP Address: $IP"
echo "  Client URL: http://$IP:2379"
echo "  Peer URL: http://$IP:2380"
echo "  Data Directory: $DATA_DIR"
echo "  Cluster State: $CLUSTER_STATE"
echo "  Quota: 2GB"

echo "=== Starting etcd with 60s patch, defrag, and retry loop ==="

# This loop will retry if etcd fails
# The patch should make this loop unnecessary, but this makes it bulletproof.
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
  --auto-compaction-mode=periodic \
  --auto-compaction-retention=1h \
  --log-level="info" \
  --max-txn-ops=10000 \
  --max-request-bytes=10485760 \
  --experimental-bootstrap-defrag-threshold-megabytes=100
do
    echo "etcd failed to start (exit code $?). Retrying in 5 seconds..."
    sleep 5
done