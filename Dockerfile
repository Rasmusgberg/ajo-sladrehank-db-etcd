FROM golang:1.22-alpine AS builder

RUN apk add --no-cache git make bash

WORKDIR /build
RUN git clone --branch v3.5.16 --depth 1 https://github.com/etcd-io/etcd.git
WORKDIR /build/etcd

# Patch InitialMmapSize from 10GB to 2GB
RUN BACKEND_FILE=$(find . -name "*.go" -type f -exec grep -l "InitialMmapSize.*1024.*1024.*1024" {} \; | head -1) && \
    echo "Found backend config in: $BACKEND_FILE" && \
    sed -i 's/10 \* 1024 \* 1024 \* 1024/2 * 1024 * 1024 * 1024/g' "$BACKEND_FILE"

# Patch timeout - search entire codebase for bolt.Open
RUN echo "=== Patching bolt.Open timeout ===" && \
    find . -name "*.go" -type f -exec grep -l "bolt.Open" {} \; | while read f; do \
        echo "Patching file: $f"; \
        sed -i 's/Timeout:.*time\.Second \* 10/Timeout: time.Second * 60/g' "$f"; \
        sed -i 's/Timeout:.*10 \* time\.Second/Timeout: 60 * time.Second/g' "$f"; \
    done && \
    echo "=== Showing patched timeout values ===" && \
    find . -name "*.go" -exec grep -n "Timeout:.*60.*time\.Second" {} \; | head -10

# Show what we patched
RUN echo "=== Patched InitialMmapSize ===" && \
    grep -n "InitialMmapSize.*=" ./server/mvcc/backend/backend.go | head -3

# Build etcd
RUN make build

FROM alpine:3.19
RUN apk add --no-cache ca-certificates curl jq
COPY --from=builder /build/etcd/bin/etcd /usr/local/bin/
COPY --from=builder /build/etcd/bin/etcdctl /usr/local/bin/

COPY entrypoint.sh /tmp/entrypoint.sh
RUN chmod +x /tmp/entrypoint.sh

EXPOSE 2379 2380
ENTRYPOINT ["sh", "/tmp/entrypoint.sh"]
CMD ["etcd"]