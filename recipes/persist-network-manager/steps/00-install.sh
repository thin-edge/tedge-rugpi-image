#!/bin/sh
set -eu
install -D -m 644 "${RECIPE_DIR}/files/network-manager-config.toml" -t /etc/rugpi/state
