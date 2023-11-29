#!/bin/sh
set -eu
install -D -m 644 "${RECIPE_DIR}/files/ctrl.toml" -t /etc/rugpi/
