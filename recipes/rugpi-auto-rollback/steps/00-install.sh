#!/bin/sh
set -eu

mkdir -p /etc/health.d
chmod 644 /etc/health.d

install -D -m 755 "${RECIPE_DIR}/files/health.d/"* -t /etc/health.d/
install -D -m 755 "${RECIPE_DIR}/files/healthcheck.sh" -t /usr/bin/
install -D -m 644 "${RECIPE_DIR}/files/rugpi-auto-rollback.service" -t /usr/lib/systemd/system/

systemctl enable rugpi-auto-rollback
