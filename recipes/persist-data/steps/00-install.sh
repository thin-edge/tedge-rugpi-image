#!/bin/sh
set -eu
install -D -m 644 "${RECIPE_DIR}/files/data.toml" -t /etc/rugpi/state

# Create directory where backup files can be stored
mkdir -p /data
chmod 1777 /data
