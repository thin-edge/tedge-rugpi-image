#!/bin/sh
set -eu
install -D -m 644 "${RECIPE_DIR}/files/tedge-firmware" -t /etc/sudoers.d/
install -D -m 644 "${RECIPE_DIR}/files/system.toml" -t /etc/tedge/
install -D -m 644 "${RECIPE_DIR}/files/firmware_update.toml" -t /etc/tedge/operations/
install -D -m 755 "${RECIPE_DIR}/files/rugpi_workflow.sh" -t /usr/bin/
install -D -m 755 "${RECIPE_DIR}/files/firmware-version" -t /usr/share/tedge-inventory/scripts.d/80_c8y_Firmware
