#!/bin/sh
set -e
MAPPERS="c8y az aws"

is_mapper_connected() {
    CLOUD_MAPPER="$1"

    if [ -n "$(tedge config get "$CLOUD_MAPPER.url" 2>/dev/null)" ]; then
        tedge connect "$CLOUD_MAPPER" --test
    else
        # If the configuration is not configured, then treat the device as healthy
        echo "Mapper is not configured: $CLOUD_MAPPER" >&2
        return 0
    fi
}

for name in $MAPPERS; do
    is_mapper_connected "$name"
done
