#!/bin/sh
set -eu

mkdir -p /etc/health.d
chmod 755 /etc/health.d

install -D -m 755 "${RECIPE_DIR}/files/health.d/"* -t /etc/health.d/
install -D -m 755 "${RECIPE_DIR}/files/healthcheck.sh" -t /usr/bin/
