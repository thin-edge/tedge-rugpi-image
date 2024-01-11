#!/bin/bash
set -e
echo "----------------------------------------------------------------------------------"
echo "Executing $0"
echo "----------------------------------------------------------------------------------"
echo "uname -a: $(uname -a)" | tee -a "${RECIPE_DIR}/build.log"
echo "uname -m: $(uname -m)" | tee -a "${RECIPE_DIR}/build.log"
echo

# install thin-edge.io
arch=$(uname -m)
case "$arch" in
    *armv7*)
        # Due to differences between the build process and the target device, the arch
        # used for installation needs to be forced to armv6.
        echo "Using armv6 workaround" | tee -a "${RECIPE_DIR}/build.log"
        curl -1sLf 'https://dl.cloudsmith.io/public/thinedge/community/gpg.2E65716592E5C6D4.key' | gpg --no-default-keyring --dearmor > /usr/share/keyrings/thinedge-community-archive-keyring.gpg
        "${RECIPE_DIR}/files/thin-edge.io.sh" --channel main --arch armv6 2>&1 | tee -a "${RECIPE_DIR}/build.log"
        ;;
    *)
        wget -O - thin-edge.io/install.sh | sh -s -- --channel main | tee -a "${RECIPE_DIR}/build.log"
        ;;
esac


# Install collectd
apt-get install -y -o DPkg::Options::=--force-confnew --no-install-recommends \
    mosquitto-clients \
    c8y-command-plugin \
    tedge-collectd-setup \
    tedge-monit-setup \
    tedge-inventory-plugin | tee -a "${RECIPE_DIR}/build.log"

# custom tedge configuration
tedge config set apt.name "(tedge|c8y|python|wget|vim|curl|apt|mosquitto|ssh|sudo).*"
tedge config set c8y.enable.firmware_update "true"

# Enable network manager by default
systemctl enable NetworkManager || true

# Enable services by default to have sensible default settings once tedge is configured
systemctl enable tedge-agent
systemctl enable tedge-mapper-c8y
systemctl enable tedge-mapper-collectd
systemctl enable collectd
systemctl disable c8y-firmware-plugin

# Custom mosquitto configuration
if ! grep -q '^pid_file' /etc/mosquitto/mosquitto.conf; then
    install -D -m 644 "${RECIPE_DIR}/files/custom.conf" -t /etc/tedge/mosquitto-conf/
fi

# Persist tedge configuration and related components (e.g. mosquitto)
install -D -m 644 "${RECIPE_DIR}/files/tedge-config.toml" -t /etc/rugpi/state

# Add default plugin configurations
install -D -m 644 -g tedge -o tedge "${RECIPE_DIR}/files/tedge-configuration-plugin.toml" -t /etc/tedge/plugins/
install -D -m 644 -g tedge -o tedge "${RECIPE_DIR}/files/tedge-log-plugin.toml" -t /etc/tedge/plugins/
