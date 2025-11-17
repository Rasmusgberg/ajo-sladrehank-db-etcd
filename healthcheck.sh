#!/bin/sh
# Simple health check for etcd

# Check if etcd is responding
if etcdctl endpoint health --endpoints=http://localhost:2379 2>&1 | grep -q "is healthy"; then
    exit 0
else
    exit 1
fi