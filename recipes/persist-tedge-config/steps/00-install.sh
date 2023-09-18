#!/bin/sh
set -eu
install -D -m 644 "${RECIPE_DIR}/files/tedge-config.toml" -t /etc/rugpi/state
