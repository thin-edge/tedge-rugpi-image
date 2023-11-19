#!/bin/sh
set -eu
install -D -m 644 "${RECIPE_DIR}/files/hostname.toml" -t /etc/rugpi/state/
install -D -m 755 "${RECIPE_DIR}/files/tedge-identity" -t /usr/bin/
install -D -m 755 "${RECIPE_DIR}/files/tedge-bootstrap" -t /usr/bin/

install -D -m 644 "${RECIPE_DIR}/files/tedge-bootstrap.service" -t /usr/lib/systemd/system/
systemctl enable tedge-bootstrap.service
