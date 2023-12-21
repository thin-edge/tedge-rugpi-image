#!/bin/sh
set -eu
install -D -m 644 "${RECIPE_DIR}/files/tedge-firmware" -t /etc/sudoers.d/
install -D -m 644 "${RECIPE_DIR}/files/system.toml" -t /etc/tedge/
install -D -m 644 "${RECIPE_DIR}/files/firmware_update.rugpi.toml" -t /usr/share/tedge-workflows/
install -D -m 755 "${RECIPE_DIR}/files/rugpi_workflow.sh" -t /usr/bin/
install -D -m 755 "${RECIPE_DIR}/files/firmware-version" /usr/share/tedge-inventory/scripts.d/80_firmware

# auto rollback service incase if new agent is corrupt (only rely on tooling which is definitely there)
install -D -m 755 "${RECIPE_DIR}/files/firmware-auto-rollback" /usr/bin/firmware-auto-rollback
install -D -m 644 "${RECIPE_DIR}/files/firmware-auto-rollback.service" -t /usr/lib/systemd/system/
install -D -m 644 "${RECIPE_DIR}/files/firmware-auto-rollback.timer" -t /usr/lib/systemd/system/

if [ "${RECIPE_PARAM_AUTOROLLBACK}" = "true" ]; then
    systemctl enable firmware-auto-rollback.timer
fi

# Use symlink so that the workflow file can be updated within the image
ln -s /usr/share/tedge-workflows/firmware_update.rugpi.toml /etc/tedge/operations/firmware_update.toml
