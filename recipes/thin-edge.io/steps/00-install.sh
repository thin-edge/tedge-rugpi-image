#!/bin/bash -e

# install thin-edge.io
curl -fsSL https://thin-edge.io/install.sh | sh -s -- --channel dev

# Install collectd
apt-get install -y -o DPkg::Options::=--force-confnew --no-install-recommends \
    mosquitto-clients \
    c8y-command-plugin \
    tedge-collectd-setup \
    tedge-monit-setup \
    tedge-inventory-plugin | tee -a "${RECIPE_DIR}/build.log"

# custom tedge configuration
tedge config set apt.name "(tedge|c8y|python|wget|vim|curl|apt|mosquitto|ssh|sudo).*"


# Enable network manager by default
systemctl enable NetworkManager || true

# Enable services by default to have sensible default settings once tedge is configured
systemctl enable tedge-agent
systemctl enable tedge-mapper-c8y
systemctl enable tedge-mapper-collectd
systemctl enable collectd

# Custom mosquitto configuration
install -D -m 644 "${RECIPE_DIR}/files/custom.conf" -t /etc/tedge/mosquitto-conf/

# Persist tedge configuration and related components (e.g. mosquitto)
install -D -m 644 "${RECIPE_DIR}/files/tedge-config.toml" -t /etc/rugpi/state
