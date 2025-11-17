FROM golang:1.22-alpine AS builder

RUN apk add --no-cache git make bash

WORKDIR /build
RUN git clone --branch v3.5.16 --depth 1 https://github.com/etcd-io/etcd.git
WORKDIR /build/etcd

# Patch InitialMmapSize from 10GB to 2GB
RUN BACKEND_FILE=$(find . -name "*.go" -type f -exec grep -l "InitialMmapSize.*1024.*1024.*1024" {} \; | head -1) && \
    echo "Found backend config in: $BACKEND_FILE" && \
    sed -i 's/10 \* 1024 \* 1024 \* 1024/2 * 1024 * 1024 * 1024/g' "$BACKEND_FILE"

# Patch config_linux.go to add time import and 60 second Timeout
RUN echo "=== Patching config_linux.go to add Timeout ===" && \
    sed -i 's|import (|import (\n\t"time"|' server/mvcc/backend/config_linux.go && \
    sed -i '/NoFreelistSync: true,/a\        Timeout:        60 * time.Second,' server/mvcc/backend/config_linux.go && \
    echo "=== Verifying patch ===" && \
    cat server/mvcc/backend/config_linux.go

# Build etcd
RUN make build && cd tools/etcd-dump-db && go build -o ../../bin/etcdutl . && cd ../..

FROM alpine:3.19
RUN apk add --no-cache ca-certificates curl jq
COPY --from=builder /build/etcd/bin/etcd /usr/local/bin/
COPY --from=builder /build/etcd/bin/etcdctl /usr/local/bin/
COPY --from=builder /build/etcd/bin/etcdutl /usr/local/bin/

COPY entrypoint.sh /tmp/entrypoint.sh
RUN chmod +x /tmp/entrypoint.sh

EXPOSE 2379 2380
ENTRYPOINT ["sh", "/tmp/entrypoint.sh"]
CMD ["etcd"]