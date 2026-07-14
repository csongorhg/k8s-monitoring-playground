#!/bin/bash
set -e

BUNDLE_PATH="$1"
shift
NODES=("$@")
DST="/usr/local/share/ca-certificates/netskope-cert.crt"

for node in "${NODES[@]}"; do
  echo "=== $node ==="
  docker cp "$BUNDLE_PATH" "$node:$DST"
  docker exec "$node" sh -c "update-ca-certificates"
done
