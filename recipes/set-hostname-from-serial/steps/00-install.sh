#!/bin/sh
set -eu

install -D -m 755 "${RECIPE_DIR}/files/set-hostname.sh" -t /usr/bin/
install -D -m 644 "${RECIPE_DIR}/files/startup-hostname.service" -t /usr/lib/systemd/system/

systemctl disable startup-hostname.service
